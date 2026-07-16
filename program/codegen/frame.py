"""Manejo del stack frame (registro de activacion) de cada funcion.

Convencion de llamadas de Compiscript (documentada en
README_CODEGEN_IMPLEMENTATION.md):

    direcciones altas
    +----------------------+
    |  argumento n-1       |  $fp + 8 + 4*(n-1)
    |  ...                 |
    |  argumento 0         |  $fp + 8        <- el llamador los empuja
    +----------------------+
    |  $ra guardado        |  $fp + 4
    |  $fp del llamador    |  $fp + 0        <- $fp apunta aqui
    +----------------------+
    |  local/temp 1        |  $fp - 4
    |  local/temp 2        |  $fp - 8
    |  ... (frame_size)    |
    +----------------------+ <- $sp
    direcciones bajas

- El LLAMADOR: empuja los argumentos (arg0 queda en la direccion mas
  baja), hace `jal`, y al retornar libera los argumentos.
- El LLAMADO: guarda $ra y $fp, establece su $fp, reserva su frame,
  y guarda los registros $s que vaya a usar. El valor de retorno viaja
  en $v0. Retorna con `jr $ra`.

Toda variable local, parametro y temporal tiene una "home location" en
memoria (slot del frame o etiqueta global). Esto hace el spilling
trivial y garantiza corrupcion cero entre llamadas: antes de cada
llamada o salto se escriben los valores sucios a su home.
"""

from intermediate.tac import Var, Temp


class Frame:
    def __init__(self, func):
        self.func = func
        self.param_offsets = {}     # id(symbol) -> offset positivo desde $fp
        self.local_offsets = {}     # clave de valor -> offset negativo desde $fp
        self.size = 0               # bytes reservados bajo $fp
        for i, p in enumerate(func.params):
            self.param_offsets[id(p)] = 8 + 4 * i

    @staticmethod
    def value_key(operand):
        """Clave hashable y estable para un operando con home en memoria."""
        if isinstance(operand, Temp):
            return ('temp', operand.n)
        if isinstance(operand, Var):
            return ('var', id(operand.symbol))
        raise ValueError(f"operando sin home: {operand}")

    def alloc_slot(self, key):
        """Reserva (una sola vez) un slot de 4 bytes en el frame."""
        if key not in self.local_offsets:
            self.size += 4
            self.local_offsets[key] = -self.size
        return self.local_offsets[key]

    def home_of(self, operand):
        """Devuelve la ubicacion en memoria de un operando.

        Retorna ('frame', offset) para locales/params/temporales, o
        ('global', label) para variables globales.
        """
        if isinstance(operand, Var):
            sym = operand.symbol
            if sym.kind == 'global':
                return ('global', f"g_{sym.unique_name}")
            if sym.kind == 'param' and id(sym) in self.param_offsets:
                return ('frame', self.param_offsets[id(sym)])
            return ('frame', self.alloc_slot(self.value_key(operand)))
        if isinstance(operand, Temp):
            return ('frame', self.alloc_slot(self.value_key(operand)))
        raise ValueError(f"operando sin home: {operand}")
