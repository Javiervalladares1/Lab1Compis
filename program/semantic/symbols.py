"""Tablas de simbolos y tipos para Compiscript.

Los tipos se representan como strings simples:
  'integer', 'boolean', 'string', 'null', 'void'
  arrays:  'integer[]', 'string[][]', ...
  clases:  el nombre de la clase, p. ej. 'Animal'
"""

PRIMITIVES = ('integer', 'boolean', 'string')


def is_array(t):
    return t is not None and t.endswith('[]')


def elem_type(t):
    return t[:-2]


def is_reference(t):
    """Tipos que se representan como punteros en tiempo de ejecucion."""
    return t == 'string' or is_array(t) or (t is not None and t not in PRIMITIVES
                                            and t not in ('null', 'void', 'integer', 'boolean'))


class VariableSymbol:
    """Variable, constante o parametro."""

    def __init__(self, name, var_type, is_const=False, kind='local'):
        self.name = name
        self.type = var_type
        self.is_const = is_const
        self.kind = kind            # 'global' | 'local' | 'param'
        self.unique_name = name     # se vuelve unico al registrarse en el checker

    def __repr__(self):
        return f"Var({self.name}: {self.type}, {self.kind})"


class FunctionSymbol:
    def __init__(self, name, params, return_type, label, owner_class=None):
        self.name = name
        self.params = params            # lista de VariableSymbol kind='param'
        self.return_type = return_type  # 'void' si no declara tipo
        self.label = label              # etiqueta/nombre unico para codegen
        self.owner_class = owner_class  # ClassSymbol si es metodo

    @property
    def arity(self):
        return len(self.params)

    def __repr__(self):
        return f"Func({self.name}/{self.arity} -> {self.return_type})"


class ClassSymbol:
    def __init__(self, name, parent=None):
        self.name = name
        self.parent = parent            # ClassSymbol o None
        self.fields = {}                # nombre -> tipo (solo campos propios)
        self.methods = {}               # nombre -> FunctionSymbol (solo propios)
        self.field_offsets = {}         # nombre -> offset en bytes (incluye heredados)
        self.size_bytes = 0             # tamano total de instancia
        self._layout_done = False

    def compute_layout(self):
        """Asigna offsets a los campos: primero los heredados, luego los propios.

        Idempotente: el layout se calcula una sola vez, aunque el checker
        lo invoque en varios puntos (accesos a campos, fin del programa).
        """
        if self._layout_done:
            return
        self._layout_done = True
        offset = 0
        if self.parent is not None:
            self.parent.compute_layout()
            self.field_offsets.update(self.parent.field_offsets)
            offset = self.parent.size_bytes
        for fname in self.fields:
            if fname not in self.field_offsets:
                self.field_offsets[fname] = offset
                offset += 4
        self.size_bytes = offset

    def lookup_field(self, name):
        """Busca el tipo de un campo en la clase o sus ancestros."""
        cls = self
        while cls is not None:
            if name in cls.fields:
                return cls.fields[name]
            cls = cls.parent
        return None

    def lookup_method(self, name):
        """Busca un metodo en la clase o sus ancestros (despacho estatico)."""
        cls = self
        while cls is not None:
            if name in cls.methods:
                return cls.methods[name]
            cls = cls.parent
        return None

    def __repr__(self):
        return f"Class({self.name})"


class Scope:
    """Ambito lexico. kind: 'global' | 'function' | 'block' | 'class'."""

    def __init__(self, parent=None, kind='block'):
        self.parent = parent
        self.kind = kind
        self.symbols = {}

    def declare(self, symbol):
        """Declara un simbolo. Devuelve False si ya existe en este ambito."""
        if symbol.name in self.symbols:
            return False
        self.symbols[symbol.name] = symbol
        return True

    def resolve(self, name, cross_function=True):
        """Busca un nombre hacia arriba.

        Si cross_function es False, la busqueda de variables se detiene en la
        frontera de la funcion actual (solo continua hacia el ambito global):
        Compiscript no soporta closures con captura de variables locales
        externas, de modo que una funcion anidada solo ve sus propios
        simbolos y los globales.
        """
        scope = self
        crossed_function = False
        while scope is not None:
            if name in scope.symbols:
                sym = scope.symbols[name]
                if (not cross_function and crossed_function
                        and scope.kind != 'global'
                        and isinstance(sym, VariableSymbol)):
                    return None  # variable local de una funcion externa: invisible
                return sym
            if scope.kind == 'function':
                crossed_function = True
            scope = scope.parent
        return None
