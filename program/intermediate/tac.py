"""Representacion del Codigo de Tres Direcciones (TAC) de Compiscript.

Cada instruccion es un objeto con un `__str__` legible, de modo que el
TAC pueda imprimirse como texto (para depuracion, tests y el IDE) y a la
vez recorrerse como estructura para el backend MIPS.

Operandos posibles:
  Const(n)      constante entera (booleans son 0/1, null es 0)
  StrLit(label) literal string ya registrado en el pool de datos
  Var(symbol)   variable global/local/parametro (VariableSymbol)
  Temp(n)       temporal tN generado por el compilador
"""


class Const:
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return str(self.value)


class StrLit:
    def __init__(self, label, text):
        self.label = label
        self.text = text

    def __str__(self):
        return self.label


class Var:
    def __init__(self, symbol):
        self.symbol = symbol

    def __str__(self):
        return self.symbol.unique_name


class Temp:
    def __init__(self, n):
        self.n = n

    def __str__(self):
        return f"t{self.n}"


# ---------------------------------------------------------------------------
# instrucciones
# ---------------------------------------------------------------------------

class TacInstr:
    pass


class Comment(TacInstr):
    def __init__(self, text):
        self.text = text

    def __str__(self):
        return f"; {self.text}"


class Label(TacInstr):
    def __init__(self, name):
        self.name = name

    def __str__(self):
        return f"{self.name}:"


class Goto(TacInstr):
    def __init__(self, label):
        self.label = label

    def __str__(self):
        return f"goto {self.label}"


class IfTrue(TacInstr):
    def __init__(self, src, label):
        self.src = src
        self.label = label

    def __str__(self):
        return f"if {self.src} goto {self.label}"


class IfFalse(TacInstr):
    def __init__(self, src, label):
        self.src = src
        self.label = label

    def __str__(self):
        return f"ifFalse {self.src} goto {self.label}"


class BinOp(TacInstr):
    """dst = a op b  (op: + - * / % < <= > >= == !=)"""

    def __init__(self, op, dst, a, b):
        self.op = op
        self.dst = dst
        self.a = a
        self.b = b

    def __str__(self):
        return f"{self.dst} = {self.a} {self.op} {self.b}"


class UnaryOp(TacInstr):
    """dst = op a  (op: neg | not)"""

    def __init__(self, op, dst, a):
        self.op = op
        self.dst = dst
        self.a = a

    def __str__(self):
        sign = '-' if self.op == 'neg' else '!'
        return f"{self.dst} = {sign}{self.a}"


class Copy(TacInstr):
    def __init__(self, dst, src):
        self.dst = dst
        self.src = src

    def __str__(self):
        return f"{self.dst} = {self.src}"


class Param(TacInstr):
    def __init__(self, src):
        self.src = src

    def __str__(self):
        return f"param {self.src}"


class Call(TacInstr):
    def __init__(self, dst, func_label, nargs):
        self.dst = dst          # Temp o None si la funcion es void
        self.func_label = func_label
        self.nargs = nargs

    def __str__(self):
        call = f"call {self.func_label}, {self.nargs}"
        return f"{self.dst} = {call}" if self.dst is not None else call


class Return(TacInstr):
    def __init__(self, src=None):
        self.src = src

    def __str__(self):
        return f"return {self.src}" if self.src is not None else "return"


class Print(TacInstr):
    def __init__(self, src, kind):
        self.src = src
        self.kind = kind        # 'int' | 'str' | 'bool'

    def __str__(self):
        return f"print_{self.kind} {self.src}"


class NewArray(TacInstr):
    """dst = new array de `size` elementos (tamano en palabras + header)."""

    def __init__(self, dst, size):
        self.dst = dst
        self.size = size        # operando (usualmente Const)

    def __str__(self):
        return f"{self.dst} = newarray {self.size}"


class IndexLoad(TacInstr):
    def __init__(self, dst, arr, idx):
        self.dst = dst
        self.arr = arr
        self.idx = idx

    def __str__(self):
        return f"{self.dst} = {self.arr}[{self.idx}]"


class IndexStore(TacInstr):
    def __init__(self, arr, idx, src):
        self.arr = arr
        self.idx = idx
        self.src = src

    def __str__(self):
        return f"{self.arr}[{self.idx}] = {self.src}"


class ArrayLen(TacInstr):
    def __init__(self, dst, arr):
        self.dst = dst
        self.arr = arr

    def __str__(self):
        return f"{self.dst} = len {self.arr}"


class NewObject(TacInstr):
    def __init__(self, dst, class_name, size_bytes):
        self.dst = dst
        self.class_name = class_name
        self.size_bytes = size_bytes

    def __str__(self):
        return f"{self.dst} = new {self.class_name} ({self.size_bytes} bytes)"


class FieldLoad(TacInstr):
    def __init__(self, dst, obj, offset, fname):
        self.dst = dst
        self.obj = obj
        self.offset = offset
        self.fname = fname

    def __str__(self):
        return f"{self.dst} = {self.obj}.{self.fname}"


class FieldStore(TacInstr):
    def __init__(self, obj, offset, src, fname):
        self.obj = obj
        self.offset = offset
        self.src = src
        self.fname = fname

    def __str__(self):
        return f"{self.obj}.{self.fname} = {self.src}"


class Concat(TacInstr):
    def __init__(self, dst, a, b):
        self.dst = dst
        self.a = a
        self.b = b

    def __str__(self):
        return f"{self.dst} = concat {self.a}, {self.b}"


class IntToStr(TacInstr):
    def __init__(self, dst, a):
        self.dst = dst
        self.a = a

    def __str__(self):
        return f"{self.dst} = itos {self.a}"


class BoolToStr(TacInstr):
    def __init__(self, dst, a):
        self.dst = dst
        self.a = a

    def __str__(self):
        return f"{self.dst} = btos {self.a}"


class TryEnter(TacInstr):
    def __init__(self, catch_label):
        self.catch_label = catch_label

    def __str__(self):
        return f"try_enter {self.catch_label}"


class TryExit(TacInstr):
    def __str__(self):
        return "try_exit"


class CatchBind(TacInstr):
    """dst = mensaje del error de runtime capturado."""

    def __init__(self, dst):
        self.dst = dst

    def __str__(self):
        return f"{self.dst} = catch_message"


# ---------------------------------------------------------------------------
# contenedores
# ---------------------------------------------------------------------------

class TACFunction:
    def __init__(self, label, params, name=None):
        self.label = label          # etiqueta MIPS (p.ej. 'main', 'func_factorial')
        self.name = name or label   # nombre legible
        self.params = params        # lista de VariableSymbol en orden (this primero)
        self.instructions = []

    def emit(self, instr):
        self.instructions.append(instr)
        return instr

    def __str__(self):
        lines = [f"FUNCTION {self.name} ({', '.join(p.name for p in self.params)}):"]
        for ins in self.instructions:
            text = str(ins)
            indent = '' if isinstance(ins, Label) else '    '
            lines.append(indent + text)
        return '\n'.join(lines)


class TACProgram:
    def __init__(self):
        self.main = TACFunction('main', [], 'main')
        self.functions = []         # TACFunction adicionales
        self.strings = {}           # texto -> StrLit (pool de literales)
        self.globals = []           # VariableSymbol globales

    def all_functions(self):
        return [self.main] + self.functions

    def intern_string(self, text):
        if text not in self.strings:
            self.strings[text] = StrLit(f"S{len(self.strings)}", text)
        return self.strings[text]

    def __str__(self):
        return '\n\n'.join(str(f) for f in self.all_functions())
