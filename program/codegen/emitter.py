"""Emisor de codigo assembly MIPS.

Acumula las secciones .data y .text como listas de lineas y produce el
archivo .asm final. La emision del cuerpo de cada funcion se hace en un
buffer separado, porque el prologo (tamano del frame, registros $s a
guardar) solo se conoce al terminar de traducir el cuerpo.
"""


class Emitter:
    def __init__(self):
        self.data_lines = []
        self.text_lines = []

    # ---- seccion .data -------------------------------------------------

    def data(self, line, comment=None):
        self.data_lines.append(self._fmt(line, comment))

    def data_label(self, label, directive, comment=None):
        self.data_lines.append(self._fmt(f"{label}: {directive}", comment))

    # ---- seccion .text -------------------------------------------------

    def text(self, line, comment=None):
        self.text_lines.append(self._fmt('    ' + line, comment))

    def label(self, name):
        self.text_lines.append(f"{name}:")

    def blank(self):
        self.text_lines.append('')

    def comment(self, text):
        self.text_lines.append(f"    # {text}")

    def raw(self, text):
        """Bloque de texto ya formateado (runtime embebido)."""
        self.text_lines.append(text)

    @staticmethod
    def _fmt(line, comment):
        if comment:
            return f"    {line:<32} # {comment}" if not line.endswith(':') \
                else f"{line:<36} # {comment}"
        return '    ' + line if not line.endswith(':') else line

    # ---- salida final ---------------------------------------------------

    def assemble(self):
        out = ['.data']
        out.extend(self.data_lines)
        out.append('')
        out.append('.text')
        out.append('.globl main')
        out.extend(self.text_lines)
        out.append('')
        return '\n'.join(out)


class FunctionBuffer:
    """Buffer de instrucciones del cuerpo de una funcion.

    Expone la misma interfaz de emision que Emitter (subset) para que el
    generador y el asignador de registros escriban sin saber si van al
    buffer o a la salida final.
    """

    def __init__(self):
        self.lines = []

    def text(self, line, comment=None):
        if comment:
            self.lines.append(f"    {line:<32} # {comment}")
        else:
            self.lines.append('    ' + line)

    def label(self, name):
        self.lines.append(f"{name}:")

    def comment(self, text):
        self.lines.append(f"    # {text}")
