"""Generador de Codigo de Tres Direcciones (TAC) para Compiscript.

Recorre el arbol sintactico ya validado por el analisis semantico y
produce un TACProgram. Consume las anotaciones del SemanticChecker
(tipos de expresiones y simbolos resueltos) para no repetir la logica
de resolucion de nombres ni de tipos.

Decisiones de diseno importantes:
  - Los argumentos de una llamada se evaluan por completo ANTES de
    emitir sus `param`, de modo que las instrucciones param de una
    llamada nunca se intercalan con las de otra (llamadas anidadas).
  - && y || generan codigo de corto circuito con saltos.
  - La concatenacion de strings y las conversiones int/bool -> string
    son instrucciones TAC explicitas que el backend traduce a llamadas
    al runtime.
  - El switch usa semantica de fallthrough (como C): los case caen al
    siguiente salvo que haya break.
"""

from CompiscriptParser import CompiscriptParser
from intermediate import tac
from semantic.symbols import is_array, elem_type
from CompiscriptVisitor import CompiscriptVisitor


class TACGenerator(CompiscriptVisitor):

    def __init__(self, checker):
        self.checker = checker
        self.program = tac.TACProgram()
        self.current = self.program.main
        self.temp_counter = 0
        self.label_counter = 0
        self.break_stack = []       # etiquetas destino de break
        self.continue_stack = []    # etiquetas destino de continue
        self.current_this = None    # VariableSymbol de this en metodos

    # ------------------------------------------------------------------
    # utilidades
    # ------------------------------------------------------------------

    def new_temp(self):
        t = tac.Temp(self.temp_counter)
        self.temp_counter += 1
        return t

    def new_label(self, hint=''):
        name = f"L{self.label_counter}" + (f"_{hint}" if hint else '')
        self.label_counter += 1
        return name

    def emit(self, instr):
        return self.current.emit(instr)

    def type_of(self, ctx):
        return self.checker.expr_type.get(id(ctx))

    def default_value(self, var_type):
        """Valor inicial por omision para variables sin inicializador."""
        if var_type == 'string':
            return self.program.intern_string("")
        return tac.Const(0)  # integer 0, boolean false, referencias null

    def as_string_operand(self, operand, operand_type):
        """Convierte un operando a string (para concatenacion)."""
        if operand_type == 'string':
            return operand
        dst = self.new_temp()
        if operand_type == 'boolean':
            self.emit(tac.BoolToStr(dst, operand))
        else:
            self.emit(tac.IntToStr(dst, operand))
        return dst

    # ------------------------------------------------------------------
    # programa y sentencias
    # ------------------------------------------------------------------

    def visitProgram(self, ctx):
        for st in ctx.statement():
            self.visit(st)
        return self.program

    def visitBlock(self, ctx):
        for st in ctx.statement():
            self.visit(st)

    def visitVariableDeclaration(self, ctx):
        sym = self.checker.var_of[id(ctx)]
        if sym.kind == 'global' and sym not in self.program.globals:
            self.program.globals.append(sym)
        if ctx.initializer() is not None:
            value = self.visit(ctx.initializer().expression())
        else:
            value = self.default_value(sym.type)
        self.emit(tac.Copy(tac.Var(sym), value))

    def visitConstantDeclaration(self, ctx):
        sym = self.checker.var_of[id(ctx)]
        if sym.kind == 'global' and sym not in self.program.globals:
            self.program.globals.append(sym)
        value = self.visit(ctx.expression())
        self.emit(tac.Copy(tac.Var(sym), value))

    def visitAssignment(self, ctx):
        exprs = ctx.expression()
        if ctx.Identifier() is not None and len(exprs) == 1:
            sym = self.checker.var_of.get(id(ctx))
            value = self.visit(exprs[0])
            if sym is not None:
                self.emit(tac.Copy(tac.Var(sym), value))
        else:
            target = self.checker.lhs_target.get(id(ctx))
            obj = self.visit(exprs[0])
            value = self.visit(exprs[1])
            if target is not None and target[0] == 'field':
                _, cls, fname = target
                self.emit(tac.FieldStore(obj, cls.field_offsets[fname], value, fname))

    def visitExpressionStatement(self, ctx):
        self.visit(ctx.expression())

    def visitPrintStatement(self, ctx):
        value = self.visit(ctx.expression())
        t = self.type_of(ctx.expression())
        kind = {'integer': 'int', 'boolean': 'bool'}.get(t, 'str')
        self.emit(tac.Print(value, kind))

    def visitIfStatement(self, ctx):
        cond = self.visit(ctx.expression())
        if ctx.block(1) is not None:
            l_else = self.new_label('else')
            l_end = self.new_label('endif')
            self.emit(tac.IfFalse(cond, l_else))
            self.visit(ctx.block(0))
            self.emit(tac.Goto(l_end))
            self.emit(tac.Label(l_else))
            self.visit(ctx.block(1))
            self.emit(tac.Label(l_end))
        else:
            l_end = self.new_label('endif')
            self.emit(tac.IfFalse(cond, l_end))
            self.visit(ctx.block(0))
            self.emit(tac.Label(l_end))

    def visitWhileStatement(self, ctx):
        l_cond = self.new_label('while')
        l_end = self.new_label('endwhile')
        self.emit(tac.Label(l_cond))
        cond = self.visit(ctx.expression())
        self.emit(tac.IfFalse(cond, l_end))
        self.break_stack.append(l_end)
        self.continue_stack.append(l_cond)
        self.visit(ctx.block())
        self.break_stack.pop()
        self.continue_stack.pop()
        self.emit(tac.Goto(l_cond))
        self.emit(tac.Label(l_end))

    def visitDoWhileStatement(self, ctx):
        l_body = self.new_label('do')
        l_cond = self.new_label('docond')
        l_end = self.new_label('enddo')
        self.emit(tac.Label(l_body))
        self.break_stack.append(l_end)
        self.continue_stack.append(l_cond)
        self.visit(ctx.block())
        self.break_stack.pop()
        self.continue_stack.pop()
        self.emit(tac.Label(l_cond))
        cond = self.visit(ctx.expression())
        self.emit(tac.IfTrue(cond, l_body))
        self.emit(tac.Label(l_end))

    def visitForStatement(self, ctx):
        if ctx.variableDeclaration() is not None:
            self.visit(ctx.variableDeclaration())
        elif ctx.assignment() is not None:
            self.visit(ctx.assignment())
        cond_ctx, update_ctx = self.checker.for_parts(ctx)
        l_cond = self.new_label('for')
        l_step = self.new_label('forstep')
        l_end = self.new_label('endfor')
        self.emit(tac.Label(l_cond))
        if cond_ctx is not None:
            cond = self.visit(cond_ctx)
            self.emit(tac.IfFalse(cond, l_end))
        self.break_stack.append(l_end)
        self.continue_stack.append(l_step)
        self.visit(ctx.block())
        self.break_stack.pop()
        self.continue_stack.pop()
        self.emit(tac.Label(l_step))
        if update_ctx is not None:
            self.visit(update_ctx)
        self.emit(tac.Goto(l_cond))
        self.emit(tac.Label(l_end))

    def visitForeachStatement(self, ctx):
        item_sym = self.checker.var_of[id(ctx)]
        arr = self.visit(ctx.expression())
        length = self.new_temp()
        self.emit(tac.ArrayLen(length, arr))
        idx = self.new_temp()
        self.emit(tac.Copy(idx, tac.Const(0)))
        l_cond = self.new_label('foreach')
        l_step = self.new_label('festep')
        l_end = self.new_label('endforeach')
        self.emit(tac.Label(l_cond))
        in_range = self.new_temp()
        self.emit(tac.BinOp('<', in_range, idx, length))
        self.emit(tac.IfFalse(in_range, l_end))
        self.emit(tac.IndexLoad(tac.Var(item_sym), arr, idx))
        self.break_stack.append(l_end)
        self.continue_stack.append(l_step)
        self.visit(ctx.block())
        self.break_stack.pop()
        self.continue_stack.pop()
        self.emit(tac.Label(l_step))
        self.emit(tac.BinOp('+', idx, idx, tac.Const(1)))
        self.emit(tac.Goto(l_cond))
        self.emit(tac.Label(l_end))

    def visitBreakStatement(self, ctx):
        if self.break_stack:
            self.emit(tac.Goto(self.break_stack[-1]))

    def visitContinueStatement(self, ctx):
        if self.continue_stack:
            self.emit(tac.Goto(self.continue_stack[-1]))

    def visitReturnStatement(self, ctx):
        if ctx.expression() is not None:
            value = self.visit(ctx.expression())
            self.emit(tac.Return(value))
        else:
            self.emit(tac.Return())

    def visitTryCatchStatement(self, ctx):
        err_sym = self.checker.var_of[id(ctx)]
        l_catch = self.new_label('catch')
        l_end = self.new_label('endtry')
        self.emit(tac.TryEnter(l_catch))
        self.visit(ctx.block(0))
        self.emit(tac.TryExit())
        self.emit(tac.Goto(l_end))
        self.emit(tac.Label(l_catch))
        self.emit(tac.CatchBind(tac.Var(err_sym)))
        self.visit(ctx.block(1))
        self.emit(tac.Label(l_end))

    def visitSwitchStatement(self, ctx):
        subject = self.visit(ctx.expression())
        # asegurar que el sujeto quede en un temporal estable
        subj = self.new_temp()
        self.emit(tac.Copy(subj, subject))
        cases = ctx.switchCase()
        case_labels = [self.new_label(f'case{i}') for i in range(len(cases))]
        l_default = self.new_label('default') if ctx.defaultCase() else None
        l_end = self.new_label('endswitch')
        # despacho: comparar el sujeto contra cada case en orden
        for case, label in zip(cases, case_labels):
            case_val = self.visit(case.expression())
            cond = self.new_temp()
            self.emit(tac.BinOp('==', cond, subj, case_val))
            self.emit(tac.IfTrue(cond, label))
        self.emit(tac.Goto(l_default if l_default else l_end))
        # cuerpos con fallthrough (break sale del switch)
        self.break_stack.append(l_end)
        for case, label in zip(cases, case_labels):
            self.emit(tac.Label(label))
            for st in case.statement():
                self.visit(st)
        if l_default:
            self.emit(tac.Label(l_default))
            for st in ctx.defaultCase().statement():
                self.visit(st)
        self.break_stack.pop()
        self.emit(tac.Label(l_end))

    # ------------------------------------------------------------------
    # funciones y clases
    # ------------------------------------------------------------------

    def visitFunctionDeclaration(self, ctx):
        fsym = self.checker.func_of[id(ctx)]
        params = list(fsym.params)
        this_sym = self.checker.this_of.get(id(ctx))
        if this_sym is not None:
            params = [this_sym] + params
        func = tac.TACFunction(fsym.label, params, fsym.name)
        self.program.functions.append(func)

        outer_func = self.current
        outer_temps = self.temp_counter
        outer_this = self.current_this
        self.current = func
        self.temp_counter = 0
        self.current_this = this_sym
        self.visit(ctx.block())
        # garantia de retorno: si el flujo llega al final, retornar 0/void
        self.emit(tac.Return(tac.Const(0)) if fsym.return_type != 'void'
                  else tac.Return())
        self.current = outer_func
        self.temp_counter = outer_temps
        self.current_this = outer_this

    def visitClassDeclaration(self, ctx):
        for member in ctx.classMember():
            decl = member.getChild(0)
            if isinstance(decl, CompiscriptParser.FunctionDeclarationContext):
                self.visit(decl)

    # ------------------------------------------------------------------
    # expresiones (devuelven un operando TAC)
    # ------------------------------------------------------------------

    def visitExpression(self, ctx):
        return self.visit(ctx.assignmentExpr())

    def visitExprNoAssign(self, ctx):
        return self.visit(ctx.conditionalExpr())

    def visitAssignExpr(self, ctx):
        target = self.checker.lhs_target.get(id(ctx))
        if target is None:
            return self.visit(ctx.assignmentExpr())
        if target[0] == 'var':
            value = self.visit(ctx.assignmentExpr())
            self.emit(tac.Copy(tac.Var(target[1]), value))
            return tac.Var(target[1])
        if target[0] == 'index':
            arr, idx = self.eval_lhs_base_and_index(ctx.lhs)
            value = self.visit(ctx.assignmentExpr())
            self.emit(tac.IndexStore(arr, idx, value))
            return value
        # target[0] == 'field'
        _, cls, fname, _ = target
        obj = self.eval_lhs_base(ctx.lhs)
        value = self.visit(ctx.assignmentExpr())
        self.emit(tac.FieldStore(obj, cls.field_offsets[fname], value, fname))
        return value

    def visitPropertyAssignExpr(self, ctx):
        obj = self.visit(ctx.lhs)
        value = self.visit(ctx.assignmentExpr())
        target = self.checker.lhs_target.get(id(ctx))
        if target is not None and target[0] == 'field':
            _, cls, fname = target
            self.emit(tac.FieldStore(obj, cls.field_offsets[fname], value, fname))
        return value

    def visitTernaryExpr(self, ctx):
        if ctx.expression(0) is None:
            return self.visit(ctx.logicalOrExpr())
        cond = self.visit(ctx.logicalOrExpr())
        result = self.new_temp()
        l_false = self.new_label('terF')
        l_end = self.new_label('terEnd')
        self.emit(tac.IfFalse(cond, l_false))
        value_true = self.visit(ctx.expression(0))
        self.emit(tac.Copy(result, value_true))
        self.emit(tac.Goto(l_end))
        self.emit(tac.Label(l_false))
        value_false = self.visit(ctx.expression(1))
        self.emit(tac.Copy(result, value_false))
        self.emit(tac.Label(l_end))
        return result

    def visitLogicalOrExpr(self, ctx):
        operands = ctx.logicalAndExpr()
        result = self.visit(operands[0])
        for i in range(1, len(operands)):
            # corto circuito: si el lado izquierdo es true no se evalua el derecho
            acc = self.new_temp()
            l_true = self.new_label('orT')
            l_end = self.new_label('orEnd')
            self.emit(tac.IfTrue(result, l_true))
            right = self.visit(operands[i])
            self.emit(tac.Copy(acc, right))
            self.emit(tac.Goto(l_end))
            self.emit(tac.Label(l_true))
            self.emit(tac.Copy(acc, tac.Const(1)))
            self.emit(tac.Label(l_end))
            result = acc
        return result

    def visitLogicalAndExpr(self, ctx):
        operands = ctx.equalityExpr()
        result = self.visit(operands[0])
        for i in range(1, len(operands)):
            # corto circuito: si el lado izquierdo es false no se evalua el derecho
            acc = self.new_temp()
            l_false = self.new_label('andF')
            l_end = self.new_label('andEnd')
            self.emit(tac.IfFalse(result, l_false))
            right = self.visit(operands[i])
            self.emit(tac.Copy(acc, right))
            self.emit(tac.Goto(l_end))
            self.emit(tac.Label(l_false))
            self.emit(tac.Copy(acc, tac.Const(0)))
            self.emit(tac.Label(l_end))
            result = acc
        return result

    def binary_chain(self, ctx, operands):
        result = self.visit(operands[0])
        for i in range(1, len(operands)):
            op = ctx.getChild(2 * i - 1).getText()
            right = self.visit(operands[i])
            dst = self.new_temp()
            self.emit(tac.BinOp(op, dst, result, right))
            result = dst
        return result

    def visitEqualityExpr(self, ctx):
        return self.binary_chain(ctx, ctx.relationalExpr())

    def visitRelationalExpr(self, ctx):
        return self.binary_chain(ctx, ctx.additiveExpr())

    def visitAdditiveExpr(self, ctx):
        operands = ctx.multiplicativeExpr()
        result = self.visit(operands[0])
        result_type = self.type_of(operands[0])
        for i in range(1, len(operands)):
            op = ctx.getChild(2 * i - 1).getText()
            right = self.visit(operands[i])
            right_type = self.type_of(operands[i])
            if op == '+' and (result_type == 'string' or right_type == 'string'):
                left_str = self.as_string_operand(result, result_type)
                right_str = self.as_string_operand(right, right_type)
                dst = self.new_temp()
                self.emit(tac.Concat(dst, left_str, right_str))
                result = dst
                result_type = 'string'
            else:
                dst = self.new_temp()
                self.emit(tac.BinOp(op, dst, result, right))
                result = dst
                result_type = 'integer'
        return result

    def visitMultiplicativeExpr(self, ctx):
        return self.binary_chain(ctx, ctx.unaryExpr())

    def visitUnaryExpr(self, ctx):
        if ctx.unaryExpr() is not None:
            op = ctx.getChild(0).getText()
            inner = self.visit(ctx.unaryExpr())
            dst = self.new_temp()
            self.emit(tac.UnaryOp('neg' if op == '-' else 'not', dst, inner))
            return dst
        return self.visit(ctx.primaryExpr())

    def visitPrimaryExpr(self, ctx):
        if ctx.literalExpr() is not None:
            return self.visit(ctx.literalExpr())
        if ctx.leftHandSide() is not None:
            return self.visit(ctx.leftHandSide())
        return self.visit(ctx.expression())

    def visitLiteralExpr(self, ctx):
        if ctx.arrayLiteral() is not None:
            return self.visit(ctx.arrayLiteral())
        text = ctx.getText()
        if text == 'null':
            return tac.Const(0)
        if text == 'true':
            return tac.Const(1)
        if text == 'false':
            return tac.Const(0)
        if text.startswith('"'):
            return self.program.intern_string(text[1:-1])
        return tac.Const(int(text))

    def visitArrayLiteral(self, ctx):
        exprs = ctx.expression()
        arr = self.new_temp()
        self.emit(tac.NewArray(arr, tac.Const(len(exprs))))
        for i, e in enumerate(exprs):
            value = self.visit(e)
            self.emit(tac.IndexStore(arr, tac.Const(i), value))
        return arr

    # ---- leftHandSide ------------------------------------------------

    def eval_atom(self, atom):
        if isinstance(atom, CompiscriptParser.IdentifierExprContext):
            sym = self.checker.var_of.get(id(atom))
            return tac.Var(sym) if sym is not None else None
        if isinstance(atom, CompiscriptParser.ThisExprContext):
            return tac.Var(self.current_this) if self.current_this else None
        if isinstance(atom, CompiscriptParser.NewExprContext):
            return self.eval_new(atom)
        return None

    def eval_new(self, ctx):
        cls = self.checker.class_of.get(id(ctx))
        if cls is None:
            return tac.Const(0)
        obj = self.new_temp()
        self.emit(tac.NewObject(obj, cls.name, max(cls.size_bytes, 4)))
        ctor = cls.lookup_method('constructor')
        if ctor is not None:
            args = [obj]
            if ctx.arguments() is not None:
                args += [self.visit(a) for a in ctx.arguments().expression()]
            for a in args:
                self.emit(tac.Param(a))
            self.emit(tac.Call(None, ctor.label, len(args)))
        return obj

    def eval_suffix_chain(self, ctx, upto=None):
        """Evalua primaryAtom seguido de los primeros `upto` sufijos."""
        suffixes = ctx.suffixOp()
        if upto is None:
            upto = len(suffixes)
        current = self.eval_atom(ctx.primaryAtom())
        pending_receiver = None
        for i in range(upto):
            suf = suffixes[i]
            info = self.checker.suffix_info.get(id(suf))
            if info is None:
                continue
            if info[0] == 'call':
                fsym = info[1]
                # evaluar TODOS los argumentos antes de emitir los param
                args = []
                if fsym.owner_class is not None:
                    receiver = pending_receiver if pending_receiver is not None else current
                    args.append(receiver)
                    pending_receiver = None
                if suf.arguments() is not None:
                    args += [self.visit(a) for a in suf.arguments().expression()]
                for a in args:
                    self.emit(tac.Param(a))
                dst = self.new_temp() if fsym.return_type != 'void' else None
                self.emit(tac.Call(dst, fsym.label, len(args)))
                current = dst
            elif info[0] == 'index':
                idx = self.visit(suf.expression())
                dst = self.new_temp()
                self.emit(tac.IndexLoad(dst, current, idx))
                current = dst
            elif info[0] == 'arraylen':
                dst = self.new_temp()
                self.emit(tac.ArrayLen(dst, current))
                current = dst
            elif info[0] == 'method':
                pending_receiver = current  # la llamada llega en el siguiente sufijo
            elif info[0] == 'field':
                _, cls, fname, _ = info
                dst = self.new_temp()
                self.emit(tac.FieldLoad(dst, current, cls.field_offsets[fname], fname))
                current = dst
        return current

    def eval_lhs_base(self, lhs_ctx):
        """Evalua un leftHandSide hasta ANTES de su ultimo sufijo."""
        return self.eval_suffix_chain(lhs_ctx, upto=len(lhs_ctx.suffixOp()) - 1)

    def eval_lhs_base_and_index(self, lhs_ctx):
        arr = self.eval_lhs_base(lhs_ctx)
        idx = self.visit(lhs_ctx.suffixOp()[-1].expression())
        return arr, idx

    def visitLeftHandSide(self, ctx):
        return self.eval_suffix_chain(ctx)
