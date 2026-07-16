"""Analisis semantico de Compiscript.

Recorre el arbol sintactico con el patron Visitor y:
  - construye tablas de simbolos con ambitos anidados,
  - verifica tipos en declaraciones, asignaciones y expresiones,
  - resuelve funciones, metodos, campos y clases,
  - acumula errores con numero de linea (no se detiene en el primero),
  - deja anotaciones (tipos y simbolos resueltos) que consume el
    generador de TAC, para no duplicar la logica de resolucion.

Anotaciones expuestas:
  expr_type[id(ctx)]    tipo estatico de cada expresion
  var_of[id(ctx)]       VariableSymbol resuelto (decls, identificadores, foreach, catch)
  func_of[id(ctx)]      FunctionSymbol resuelto (declaraciones y llamadas)
  class_of[id(ctx)]     ClassSymbol (declaraciones de clase y new)
  suffix_info[id(ctx)]  significado de cada sufijo de leftHandSide
  lhs_target[id(ctx)]   descripcion del destino de una asignacion
"""

from CompiscriptParser import CompiscriptParser
from CompiscriptVisitor import CompiscriptVisitor
from semantic.symbols import (Scope, VariableSymbol, FunctionSymbol,
                              ClassSymbol, is_array, elem_type, is_reference)

PRINTABLE = ('integer', 'boolean', 'string')


class SemanticError(Exception):
    pass


class SemanticChecker(CompiscriptVisitor):

    def __init__(self):
        self.errors = []
        self.global_scope = Scope(kind='global')
        self.scope = self.global_scope
        self.classes = {}            # nombre -> ClassSymbol
        self.current_function = None  # FunctionSymbol de la funcion en analisis
        self.current_class = None     # ClassSymbol si estamos dentro de una clase
        self.loop_depth = 0
        self.switch_depth = 0
        self._name_counter = {}

        # anotaciones para el generador de TAC
        self.expr_type = {}
        self.var_of = {}
        self.func_of = {}
        self.class_of = {}
        self.suffix_info = {}
        self.lhs_target = {}
        self.this_of = {}    # id(functionDeclarationCtx) -> VariableSymbol de 'this'

    # ------------------------------------------------------------------
    # utilidades
    # ------------------------------------------------------------------

    def error(self, ctx, message):
        line = ctx.start.line if ctx is not None else '?'
        self.errors.append(f"linea {line}: {message}")

    def unique_name(self, base):
        n = self._name_counter.get(base, 0)
        self._name_counter[base] = n + 1
        return base if n == 0 else f"{base}_{n}"

    def push_scope(self, kind='block'):
        self.scope = Scope(self.scope, kind)
        return self.scope

    def pop_scope(self):
        self.scope = self.scope.parent

    def declare_var(self, ctx, name, var_type, is_const=False):
        kind = 'global' if self.scope is self.global_scope else 'local'
        sym = VariableSymbol(name, var_type, is_const, kind)
        sym.unique_name = self.unique_name(name)
        if not self.scope.declare(sym):
            self.error(ctx, f"'{name}' ya fue declarado en este ambito")
        return sym

    def resolve_var(self, ctx, name):
        # cross_function=False: sin captura de locales de funciones externas
        sym = self.scope.resolve(name, cross_function=False)
        if sym is None and self.scope.resolve(name) is not None:
            self.error(ctx, f"'{name}' es una variable local de una funcion externa: "
                            "Compiscript no soporta closures con captura")
            return None
        return sym

    def set_type(self, ctx, t):
        self.expr_type[id(ctx)] = t
        return t

    def type_exists(self, t):
        base = t
        while is_array(base):
            base = elem_type(base)
        return base in ('integer', 'boolean', 'string') or base in self.classes

    def is_subclass(self, sub, sup):
        cls = self.classes.get(sub)
        while cls is not None:
            if cls.name == sup:
                return True
            cls = cls.parent
        return False

    def assignable(self, dst, src):
        """Determina si un valor de tipo src puede asignarse a un destino dst."""
        if dst is None or src is None:
            return True  # ya se reporto un error previo; evitar cascada
        if dst == src:
            return True
        if src == 'null' and is_reference(dst):
            return True
        if dst in self.classes and src in self.classes and self.is_subclass(src, dst):
            return True
        return False

    def read_type(self, type_ctx):
        """Convierte un nodo `type` de la gramatica en un tipo string."""
        base = type_ctx.baseType().getText()
        suffix = '[]' * ((type_ctx.getChildCount() - 1) // 2)
        t = base + suffix
        if not self.type_exists(t):
            self.error(type_ctx, f"el tipo '{t}' no existe")
        return t

    # ------------------------------------------------------------------
    # pre-registro (hoisting) de funciones y clases
    # ------------------------------------------------------------------

    def hoist_statements(self, statements, owner_prefix=''):
        """Registra firmas de funciones y clases antes de revisar cuerpos,
        para permitir referencias adelantadas y recursion mutua."""
        for st in statements:
            child = st.getChild(0) if isinstance(st, CompiscriptParser.StatementContext) else st
            if isinstance(child, CompiscriptParser.ClassDeclarationContext):
                self.hoist_class(child)
        for st in statements:
            child = st.getChild(0) if isinstance(st, CompiscriptParser.StatementContext) else st
            if isinstance(child, CompiscriptParser.FunctionDeclarationContext):
                self.hoist_function(child, owner_prefix)
            elif isinstance(child, CompiscriptParser.ClassDeclarationContext):
                self.hoist_class_members(child)

    def function_signature(self, ctx, label, owner_class=None):
        params = []
        if ctx.parameters() is not None:
            for p in ctx.parameters().parameter():
                pname = p.Identifier().getText()
                ptype = self.read_type(p.type_()) if p.type_() is not None else 'integer'
                if p.type_() is None:
                    self.error(p, f"el parametro '{pname}' debe declarar su tipo")
                psym = VariableSymbol(pname, ptype, kind='param')
                params.append(psym)
        ret = self.read_type(ctx.type_()) if ctx.type_() is not None else 'void'
        return FunctionSymbol(ctx.Identifier().getText(), params, ret, label, owner_class)

    def hoist_function(self, ctx, owner_prefix=''):
        name = ctx.Identifier().getText()
        label = f"{owner_prefix}{name}" if owner_prefix else name
        fsym = self.function_signature(ctx, self.unique_name('func_' + label))
        if not self.scope.declare(fsym):
            self.error(ctx, f"'{name}' ya fue declarado en este ambito")
        self.func_of[id(ctx)] = fsym

    def hoist_class(self, ctx):
        name = ctx.Identifier(0).getText()
        if name in self.classes:
            self.error(ctx, f"la clase '{name}' ya fue declarada")
            return
        cls = ClassSymbol(name)
        self.classes[name] = cls
        self.class_of[id(ctx)] = cls

    def hoist_class_members(self, ctx):
        name = ctx.Identifier(0).getText()
        cls = self.classes.get(name)
        if cls is None:
            return
        if ctx.Identifier(1) is not None:
            parent_name = ctx.Identifier(1).getText()
            parent = self.classes.get(parent_name)
            if parent is None:
                self.error(ctx, f"la clase padre '{parent_name}' no existe")
            else:
                cls.parent = parent
        for member in ctx.classMember():
            decl = member.getChild(0)
            if isinstance(decl, CompiscriptParser.FunctionDeclarationContext):
                mname = decl.Identifier().getText()
                fsym = self.function_signature(
                    decl, f"m_{name}_{mname}", owner_class=cls)
                if mname in cls.methods:
                    self.error(decl, f"el metodo '{mname}' ya existe en '{name}'")
                cls.methods[mname] = fsym
                self.func_of[id(decl)] = fsym
            elif isinstance(decl, CompiscriptParser.VariableDeclarationContext):
                fname = decl.Identifier().getText()
                if decl.typeAnnotation() is None:
                    self.error(decl, f"el campo '{fname}' debe declarar su tipo")
                    ftype = 'integer'
                else:
                    ftype = self.read_type(decl.typeAnnotation().type_())
                if decl.initializer() is not None:
                    self.error(decl, "no se soportan inicializadores en campos de clase "
                                     "(asignelos en el constructor)")
                if fname in cls.fields:
                    self.error(decl, f"el campo '{fname}' ya existe en '{name}'")
                cls.fields[fname] = ftype
            else:
                self.error(decl, "las clases no pueden contener constantes")

    # ------------------------------------------------------------------
    # programa y sentencias
    # ------------------------------------------------------------------

    def visitProgram(self, ctx):
        self.hoist_statements(ctx.statement())
        for st in ctx.statement():
            self.visit(st)
        for cls in self.classes.values():
            cls.compute_layout()
        return self.errors

    def visitBlock(self, ctx):
        self.push_scope('block')
        self.hoist_statements(ctx.statement())
        for st in ctx.statement():
            self.visit(st)
        self.pop_scope()

    def visitVariableDeclaration(self, ctx):
        name = ctx.Identifier().getText()
        declared = None
        if ctx.typeAnnotation() is not None:
            declared = self.read_type(ctx.typeAnnotation().type_())
        init_type = None
        if ctx.initializer() is not None:
            init_type = self.visit(ctx.initializer().expression())
        if declared is None:
            if init_type is None:
                self.error(ctx, f"'{name}' necesita tipo o inicializador para inferirlo")
                declared = 'integer'
            elif init_type == 'null':
                self.error(ctx, f"no se puede inferir el tipo de '{name}' desde null; "
                                "declare el tipo explicitamente")
                declared = 'integer'
            elif init_type == 'void':
                self.error(ctx, f"'{name}' no puede inicializarse con una funcion void")
                declared = 'integer'
            else:
                declared = init_type
        elif init_type is not None and not self.assignable(declared, init_type):
            self.error(ctx, f"no se puede asignar '{init_type}' a '{name}' "
                            f"de tipo '{declared}'")
        sym = self.declare_var(ctx, name, declared)
        self.var_of[id(ctx)] = sym

    def visitConstantDeclaration(self, ctx):
        name = ctx.Identifier().getText()
        declared = None
        if ctx.typeAnnotation() is not None:
            declared = self.read_type(ctx.typeAnnotation().type_())
        init_type = self.visit(ctx.expression())
        if declared is None:
            declared = init_type if init_type not in (None, 'null', 'void') else 'integer'
        elif not self.assignable(declared, init_type):
            self.error(ctx, f"no se puede asignar '{init_type}' a la constante "
                            f"'{name}' de tipo '{declared}'")
        sym = self.declare_var(ctx, name, declared, is_const=True)
        self.var_of[id(ctx)] = sym

    def visitAssignment(self, ctx):
        exprs = ctx.expression()
        if ctx.Identifier() is not None and len(exprs) == 1:
            # Identifier '=' expression ';'
            name = ctx.Identifier().getText()
            sym = self.resolve_var(ctx, name)
            value_type = self.visit(exprs[0])
            if sym is None:
                self.error(ctx, f"la variable '{name}' no ha sido declarada")
                return
            if not isinstance(sym, VariableSymbol):
                self.error(ctx, f"'{name}' no es una variable asignable")
                return
            if sym.is_const:
                self.error(ctx, f"no se puede reasignar la constante '{name}'")
            if not self.assignable(sym.type, value_type):
                self.error(ctx, f"no se puede asignar '{value_type}' a '{name}' "
                                f"de tipo '{sym.type}'")
            self.var_of[id(ctx)] = sym
            self.lhs_target[id(ctx)] = ('var', sym)
        else:
            # expression '.' Identifier '=' expression ';'
            obj_type = self.visit(exprs[0])
            fname = ctx.Identifier().getText()
            value_type = self.visit(exprs[1])
            self.check_field_store(ctx, obj_type, fname, value_type)

    def check_field_store(self, ctx, obj_type, fname, value_type):
        if obj_type in self.classes:
            cls = self.classes[obj_type]
            ftype = cls.lookup_field(fname)
            if ftype is None:
                self.error(ctx, f"la clase '{obj_type}' no tiene un campo '{fname}'")
                return
            if not self.assignable(ftype, value_type):
                self.error(ctx, f"no se puede asignar '{value_type}' al campo "
                                f"'{fname}' de tipo '{ftype}'")
            cls.compute_layout()
            self.lhs_target[id(ctx)] = ('field', cls, fname)
        elif obj_type is not None:
            self.error(ctx, f"el tipo '{obj_type}' no tiene campos asignables")

    def visitExpressionStatement(self, ctx):
        self.visit(ctx.expression())

    def visitPrintStatement(self, ctx):
        t = self.visit(ctx.expression())
        if t is not None and t not in PRINTABLE:
            self.error(ctx, f"print no soporta valores de tipo '{t}'")

    def check_condition(self, expr_ctx, construct):
        t = self.visit(expr_ctx)
        if t is not None and t != 'boolean':
            self.error(expr_ctx, f"la condicion de '{construct}' debe ser boolean, "
                                 f"no '{t}'")

    def visitIfStatement(self, ctx):
        self.check_condition(ctx.expression(), 'if')
        for b in ctx.block():
            self.visit(b)

    def visitWhileStatement(self, ctx):
        self.check_condition(ctx.expression(), 'while')
        self.loop_depth += 1
        self.visit(ctx.block())
        self.loop_depth -= 1

    def visitDoWhileStatement(self, ctx):
        self.loop_depth += 1
        self.visit(ctx.block())
        self.loop_depth -= 1
        self.check_condition(ctx.expression(), 'do-while')

    def for_parts(self, ctx):
        """Separa condicion y actualizacion de un for usando la posicion
        de los ';' entre los hijos (ambas expresiones son opcionales)."""
        cond = update = None
        exprs = list(ctx.expression())
        if len(exprs) == 2:
            cond, update = exprs
        elif len(exprs) == 1:
            # el for tiene forma: 'for' '(' init cond? ';' update? ')' block
            # localizamos el ';' que separa cond de update
            children = [ctx.getChild(i) for i in range(ctx.getChildCount())]
            expr_ctx = exprs[0]
            idx = children.index(expr_ctx)
            # si despues de la expresion viene ';', era la condicion
            if idx + 1 < len(children) and children[idx + 1].getText() == ';':
                cond = expr_ctx
            else:
                update = expr_ctx
        return cond, update

    def visitForStatement(self, ctx):
        self.push_scope('block')  # el init (let i...) vive en el ambito del for
        if ctx.variableDeclaration() is not None:
            self.visit(ctx.variableDeclaration())
        elif ctx.assignment() is not None:
            self.visit(ctx.assignment())
        cond, update = self.for_parts(ctx)
        if cond is not None:
            self.check_condition(cond, 'for')
        if update is not None:
            self.visit(update)
        self.loop_depth += 1
        self.visit(ctx.block())
        self.loop_depth -= 1
        self.pop_scope()

    def visitForeachStatement(self, ctx):
        arr_type = self.visit(ctx.expression())
        item_type = 'integer'
        if arr_type is not None and not is_array(arr_type):
            self.error(ctx, f"foreach requiere un arreglo, no '{arr_type}'")
        elif arr_type is not None:
            item_type = elem_type(arr_type)
        self.push_scope('block')
        item = self.declare_var(ctx, ctx.Identifier().getText(), item_type)
        self.var_of[id(ctx)] = item
        self.loop_depth += 1
        self.visit(ctx.block())
        self.loop_depth -= 1
        self.pop_scope()

    def visitBreakStatement(self, ctx):
        if self.loop_depth == 0 and self.switch_depth == 0:
            self.error(ctx, "break solo puede usarse dentro de un ciclo o switch")

    def visitContinueStatement(self, ctx):
        if self.loop_depth == 0:
            self.error(ctx, "continue solo puede usarse dentro de un ciclo")

    def visitReturnStatement(self, ctx):
        if self.current_function is None:
            self.error(ctx, "return solo puede usarse dentro de una funcion")
            if ctx.expression() is not None:
                self.visit(ctx.expression())
            return
        expected = self.current_function.return_type
        if ctx.expression() is not None:
            actual = self.visit(ctx.expression())
            if expected == 'void':
                self.error(ctx, f"la funcion '{self.current_function.name}' es void "
                                "y no puede retornar un valor")
            elif not self.assignable(expected, actual):
                self.error(ctx, f"return de tipo '{actual}' en funcion que "
                                f"retorna '{expected}'")
        elif expected != 'void':
            self.error(ctx, f"la funcion '{self.current_function.name}' debe "
                            f"retornar un valor de tipo '{expected}'")

    def visitTryCatchStatement(self, ctx):
        self.visit(ctx.block(0))
        self.push_scope('block')
        err = self.declare_var(ctx, ctx.Identifier().getText(), 'string')
        self.var_of[id(ctx)] = err
        self.visit(ctx.block(1))
        self.pop_scope()

    def visitSwitchStatement(self, ctx):
        subject_type = self.visit(ctx.expression())
        self.switch_depth += 1
        for case in ctx.switchCase():
            case_type = self.visit(case.expression())
            if (subject_type is not None and case_type is not None
                    and subject_type != case_type):
                self.error(case, f"case de tipo '{case_type}' incompatible con el "
                                 f"switch de tipo '{subject_type}'")
            for st in case.statement():
                self.visit(st)
        if ctx.defaultCase() is not None:
            for st in ctx.defaultCase().statement():
                self.visit(st)
        self.switch_depth -= 1

    # ------------------------------------------------------------------
    # funciones y clases
    # ------------------------------------------------------------------

    def visitFunctionDeclaration(self, ctx):
        fsym = self.func_of.get(id(ctx))
        if fsym is None:  # funcion anidada no pre-registrada (hoisting local)
            label = self.unique_name('func_' + ctx.Identifier().getText())
            fsym = self.function_signature(ctx, label)
            if not self.scope.declare(fsym):
                self.error(ctx, f"'{fsym.name}' ya fue declarado en este ambito")
            self.func_of[id(ctx)] = fsym

        outer_function = self.current_function
        self.current_function = fsym
        self.push_scope('function')
        if fsym.owner_class is not None:
            this_sym = VariableSymbol('this', fsym.owner_class.name, kind='param')
            self.scope.declare(this_sym)
            self.this_of[id(ctx)] = this_sym
        for p in fsym.params:
            p.unique_name = self.unique_name(p.name)
            if not self.scope.declare(p):
                self.error(ctx, f"parametro duplicado '{p.name}'")
        # el cuerpo comparte el ambito de los parametros
        self.hoist_statements(ctx.block().statement(),
                              owner_prefix=fsym.label + '__')
        for st in ctx.block().statement():
            self.visit(st)
        self.pop_scope()
        self.current_function = outer_function

    def visitClassDeclaration(self, ctx):
        cls = self.class_of.get(id(ctx))
        if cls is None:
            return
        outer_class = self.current_class
        self.current_class = cls
        cls.compute_layout()
        for member in ctx.classMember():
            decl = member.getChild(0)
            if isinstance(decl, CompiscriptParser.FunctionDeclarationContext):
                self.visit(decl)
        self.current_class = outer_class

    # ------------------------------------------------------------------
    # expresiones
    # ------------------------------------------------------------------

    def visitExpression(self, ctx):
        return self.set_type(ctx, self.visit(ctx.assignmentExpr()))

    def visitExprNoAssign(self, ctx):
        return self.set_type(ctx, self.visit(ctx.conditionalExpr()))

    def analyze_lhs_target(self, lhs_ctx):
        """Clasifica el destino de una asignacion cuyo lado izquierdo es un
        leftHandSide: variable simple, elemento de arreglo o campo."""
        suffixes = lhs_ctx.suffixOp()
        atom = lhs_ctx.primaryAtom()
        if not suffixes:
            if not isinstance(atom, CompiscriptParser.IdentifierExprContext):
                self.error(lhs_ctx, "destino de asignacion invalido")
                return None
            name = atom.Identifier().getText()
            sym = self.resolve_var(lhs_ctx, name)
            if sym is None or not isinstance(sym, VariableSymbol):
                self.error(lhs_ctx, f"la variable '{name}' no ha sido declarada")
                return None
            if sym.is_const:
                self.error(lhs_ctx, f"no se puede reasignar la constante '{name}'")
            self.var_of[id(lhs_ctx)] = sym
            return ('var', sym)
        # con sufijos: evaluar la base (todo menos el ultimo sufijo)
        base_type = self.lhs_chain_type(lhs_ctx, upto=len(suffixes) - 1)
        last = suffixes[-1]
        if isinstance(last, CompiscriptParser.IndexExprContext):
            idx_type = self.visit(last.expression())
            if idx_type is not None and idx_type != 'integer':
                self.error(last, f"el indice debe ser integer, no '{idx_type}'")
            if base_type is not None and not is_array(base_type):
                self.error(last, f"solo se puede indexar arreglos, no '{base_type}'")
                return None
            et = elem_type(base_type) if base_type else 'integer'
            return ('index', et)
        if isinstance(last, CompiscriptParser.PropertyAccessExprContext):
            fname = last.Identifier().getText()
            if base_type in self.classes:
                cls = self.classes[base_type]
                ftype = cls.lookup_field(fname)
                if ftype is None:
                    self.error(last, f"la clase '{base_type}' no tiene campo '{fname}'")
                    return None
                cls.compute_layout()
                return ('field', cls, fname, ftype)
            self.error(last, f"el tipo '{base_type}' no tiene campos")
            return None
        self.error(lhs_ctx, "destino de asignacion invalido")
        return None

    def visitAssignExpr(self, ctx):
        target = self.analyze_lhs_target(ctx.lhs)
        value_type = self.visit(ctx.assignmentExpr())
        if target is not None:
            self.lhs_target[id(ctx)] = target
            if target[0] == 'var' and not self.assignable(target[1].type, value_type):
                self.error(ctx, f"no se puede asignar '{value_type}' a "
                                f"'{target[1].name}' de tipo '{target[1].type}'")
            elif target[0] == 'index' and not self.assignable(target[1], value_type):
                self.error(ctx, f"no se puede asignar '{value_type}' a un elemento "
                                f"de tipo '{target[1]}'")
            elif target[0] == 'field' and not self.assignable(target[3], value_type):
                self.error(ctx, f"no se puede asignar '{value_type}' al campo "
                                f"'{target[2]}' de tipo '{target[3]}'")
        return self.set_type(ctx, value_type)

    def visitPropertyAssignExpr(self, ctx):
        obj_type = self.visit(ctx.lhs)
        fname = ctx.Identifier().getText()
        value_type = self.visit(ctx.assignmentExpr())
        self.check_field_store(ctx, obj_type, fname, value_type)
        return self.set_type(ctx, value_type)

    def visitTernaryExpr(self, ctx):
        cond_type = self.visit(ctx.logicalOrExpr())
        if ctx.expression(0) is None:
            return self.set_type(ctx, cond_type)
        if cond_type is not None and cond_type != 'boolean':
            self.error(ctx, f"la condicion del operador ternario debe ser boolean, "
                            f"no '{cond_type}'")
        t_true = self.visit(ctx.expression(0))
        t_false = self.visit(ctx.expression(1))
        if t_true == t_false:
            result = t_true
        elif t_true == 'null' and is_reference(t_false):
            result = t_false
        elif t_false == 'null' and is_reference(t_true):
            result = t_true
        else:
            self.error(ctx, f"las ramas del ternario tienen tipos incompatibles "
                            f"('{t_true}' y '{t_false}')")
            result = t_true
        return self.set_type(ctx, result)

    def visit_binary_chain(self, ctx, operands, check):
        """Cadenas asociativas por la izquierda: e1 op e2 op e3 ..."""
        result = self.visit(operands[0])
        for i in range(1, len(operands)):
            op = ctx.getChild(2 * i - 1).getText()
            right = self.visit(operands[i])
            result = check(ctx, op, result, right)
        return self.set_type(ctx, result)

    def visitLogicalOrExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.logicalAndExpr(), self.check_logical)

    def visitLogicalAndExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.equalityExpr(), self.check_logical)

    def check_logical(self, ctx, op, left, right):
        for side in (left, right):
            if side is not None and side != 'boolean':
                self.error(ctx, f"'{op}' requiere operandos boolean, no '{side}'")
        return 'boolean'

    def visitEqualityExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.relationalExpr(), self.check_equality)

    def check_equality(self, ctx, op, left, right):
        if left is None or right is None:
            return 'boolean'
        ok = (left == right
              or (left == 'null' and is_reference(right))
              or (right == 'null' and is_reference(left))
              or (left in self.classes and right in self.classes
                  and (self.is_subclass(left, right) or self.is_subclass(right, left))))
        if not ok:
            self.error(ctx, f"'{op}' entre tipos incompatibles ('{left}' y '{right}')")
        return 'boolean'

    def visitRelationalExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.additiveExpr(), self.check_relational)

    def check_relational(self, ctx, op, left, right):
        for side in (left, right):
            if side is not None and side != 'integer':
                self.error(ctx, f"'{op}' requiere operandos integer, no '{side}'")
        return 'boolean'

    def visitAdditiveExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.multiplicativeExpr(), self.check_additive)

    def check_additive(self, ctx, op, left, right):
        if op == '+' and (left == 'string' or right == 'string'):
            # concatenacion: el otro lado puede ser integer/boolean/string
            for side in (left, right):
                if side is not None and side not in PRINTABLE:
                    self.error(ctx, f"no se puede concatenar un valor de tipo '{side}'")
            return 'string'
        for side in (left, right):
            if side is not None and side != 'integer':
                self.error(ctx, f"'{op}' requiere operandos integer, no '{side}'")
        return 'integer'

    def visitMultiplicativeExpr(self, ctx):
        return self.visit_binary_chain(ctx, ctx.unaryExpr(), self.check_multiplicative)

    def check_multiplicative(self, ctx, op, left, right):
        for side in (left, right):
            if side is not None and side != 'integer':
                self.error(ctx, f"'{op}' requiere operandos integer, no '{side}'")
        return 'integer'

    def visitUnaryExpr(self, ctx):
        if ctx.unaryExpr() is not None:
            op = ctx.getChild(0).getText()
            inner = self.visit(ctx.unaryExpr())
            if op == '-':
                if inner is not None and inner != 'integer':
                    self.error(ctx, f"'-' unario requiere integer, no '{inner}'")
                return self.set_type(ctx, 'integer')
            if inner is not None and inner != 'boolean':
                self.error(ctx, f"'!' requiere boolean, no '{inner}'")
            return self.set_type(ctx, 'boolean')
        return self.set_type(ctx, self.visit(ctx.primaryExpr()))

    def visitPrimaryExpr(self, ctx):
        if ctx.literalExpr() is not None:
            return self.set_type(ctx, self.visit(ctx.literalExpr()))
        if ctx.leftHandSide() is not None:
            return self.set_type(ctx, self.visit(ctx.leftHandSide()))
        return self.set_type(ctx, self.visit(ctx.expression()))

    def visitLiteralExpr(self, ctx):
        text = ctx.getText()
        if ctx.arrayLiteral() is not None:
            return self.set_type(ctx, self.visit(ctx.arrayLiteral()))
        if text == 'null':
            return self.set_type(ctx, 'null')
        if text in ('true', 'false'):
            return self.set_type(ctx, 'boolean')
        if text.startswith('"'):
            return self.set_type(ctx, 'string')
        return self.set_type(ctx, 'integer')

    def visitArrayLiteral(self, ctx):
        exprs = ctx.expression()
        if not exprs:
            self.error(ctx, "no se puede inferir el tipo de un arreglo vacio")
            return self.set_type(ctx, 'integer[]')
        first = self.visit(exprs[0])
        for e in exprs[1:]:
            t = self.visit(e)
            if first is not None and t is not None and t != first:
                self.error(e, f"elementos de arreglo con tipos mezclados "
                              f"('{first}' y '{t}')")
        return self.set_type(ctx, (first or 'integer') + '[]')

    # ---- leftHandSide: atomo + cadena de sufijos ----------------------

    def lhs_chain_type(self, ctx, upto=None):
        """Calcula el tipo del atomo seguido de los primeros `upto` sufijos,
        anotando cada sufijo con la informacion que necesita el TAC."""
        suffixes = ctx.suffixOp()
        if upto is None:
            upto = len(suffixes)
        atom = ctx.primaryAtom()
        current = self.visit(atom)
        pending_method = None  # (ClassSymbol, FunctionSymbol) esperando llamada

        # caso especial: identificador que nombra una funcion global
        atom_func = None
        if isinstance(atom, CompiscriptParser.IdentifierExprContext):
            name = atom.Identifier().getText()
            sym = self.scope.resolve(name)
            if isinstance(sym, FunctionSymbol):
                atom_func = sym

        for i in range(upto):
            suf = suffixes[i]
            if isinstance(suf, CompiscriptParser.CallExprContext):
                args = suf.arguments().expression() if suf.arguments() else []
                arg_types = [self.visit(a) for a in args]
                if pending_method is not None:
                    fsym = pending_method
                    pending_method = None
                elif i == 0 and atom_func is not None:
                    fsym = atom_func
                else:
                    self.error(suf, "esta expresion no es invocable")
                    current = None
                    continue
                self.check_call_args(suf, fsym, arg_types)
                self.suffix_info[id(suf)] = ('call', fsym)
                current = fsym.return_type
            elif isinstance(suf, CompiscriptParser.IndexExprContext):
                idx_type = self.visit(suf.expression())
                if idx_type is not None and idx_type != 'integer':
                    self.error(suf, f"el indice debe ser integer, no '{idx_type}'")
                if current is not None and not is_array(current):
                    self.error(suf, f"solo se puede indexar arreglos, no '{current}'")
                    current = None
                else:
                    current = elem_type(current) if current else None
                self.suffix_info[id(suf)] = ('index',)
            elif isinstance(suf, CompiscriptParser.PropertyAccessExprContext):
                fname = suf.Identifier().getText()
                if current is not None and is_array(current) and fname == 'length':
                    self.suffix_info[id(suf)] = ('arraylen',)
                    current = 'integer'
                elif current in self.classes:
                    cls = self.classes[current]
                    ftype = cls.lookup_field(fname)
                    method = cls.lookup_method(fname)
                    is_call_next = (i + 1 < len(suffixes) and isinstance(
                        suffixes[i + 1], CompiscriptParser.CallExprContext))
                    if is_call_next and method is not None:
                        pending_method = method
                        self.suffix_info[id(suf)] = ('method', cls, method)
                        current = None  # el tipo lo define la llamada siguiente
                    elif ftype is not None:
                        cls.compute_layout()
                        self.suffix_info[id(suf)] = ('field', cls, fname, ftype)
                        current = ftype
                    else:
                        self.error(suf, f"la clase '{current}' no tiene un miembro "
                                        f"'{fname}'")
                        current = None
                elif current is not None:
                    self.error(suf, f"el tipo '{current}' no tiene propiedades")
                    current = None
            self.set_type(suf, current)
        return current

    def check_call_args(self, ctx, fsym, arg_types):
        if len(arg_types) != fsym.arity:
            self.error(ctx, f"'{fsym.name}' espera {fsym.arity} argumento(s) "
                            f"y recibio {len(arg_types)}")
            return
        for p, a in zip(fsym.params, arg_types):
            if not self.assignable(p.type, a):
                self.error(ctx, f"argumento '{p.name}' de '{fsym.name}' espera "
                                f"'{p.type}' y recibio '{a}'")

    def visitLeftHandSide(self, ctx):
        result = self.lhs_chain_type(ctx)
        # identificador solo (sin sufijos) que nombra una funcion: error de uso
        if (not ctx.suffixOp()
                and isinstance(ctx.primaryAtom(), CompiscriptParser.IdentifierExprContext)):
            name = ctx.primaryAtom().Identifier().getText()
            sym = self.scope.resolve(name)
            if isinstance(sym, FunctionSymbol):
                self.error(ctx, f"'{name}' es una funcion; las funciones no son "
                                "valores en Compiscript (llamela con parentesis)")
                result = None
        return self.set_type(ctx, result)

    def visitIdentifierExpr(self, ctx):
        name = ctx.Identifier().getText()
        sym = self.resolve_var(ctx, name)
        if isinstance(sym, VariableSymbol):
            self.var_of[id(ctx)] = sym
            return self.set_type(ctx, sym.type)
        if isinstance(sym, FunctionSymbol):
            return self.set_type(ctx, None)  # se resuelve en la llamada
        if self.scope.resolve(name) is None:
            self.error(ctx, f"la variable '{name}' no ha sido declarada")
        return self.set_type(ctx, None)

    def visitNewExpr(self, ctx):
        cname = ctx.Identifier().getText()
        args = ctx.arguments().expression() if ctx.arguments() else []
        arg_types = [self.visit(a) for a in args]
        cls = self.classes.get(cname)
        if cls is None:
            self.error(ctx, f"la clase '{cname}' no existe")
            return self.set_type(ctx, None)
        ctor = cls.lookup_method('constructor')
        if ctor is not None:
            self.check_call_args(ctx, ctor, arg_types)
        elif arg_types:
            self.error(ctx, f"la clase '{cname}' no tiene constructor pero "
                            f"recibio {len(arg_types)} argumento(s)")
        self.class_of[id(ctx)] = cls
        return self.set_type(ctx, cname)

    def visitThisExpr(self, ctx):
        if self.current_class is None or self.current_function is None \
                or self.current_function.owner_class is None:
            self.error(ctx, "'this' solo puede usarse dentro de metodos de clase")
            return self.set_type(ctx, None)
        return self.set_type(ctx, self.current_class.name)
