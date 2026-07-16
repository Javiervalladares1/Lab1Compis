"""Asignacion de registros: la funcion getReg() de Compiscript.

Estrategia (descriptores de registros y de direcciones, seccion 8.6 de
Aho et al., adaptada a asignacion local por bloque basico):

  - Pools de registros:
      $t0-$t9  preferidos para TEMPORALES de expresiones (caller-saved)
      $s0-$s7  preferidos para VARIABLES con nombre (callee-saved; la
               funcion que los usa los guarda/restaura en su prologo/
               epilogo). Si el pool preferido se agota se usa el otro.
  - Tablas (descriptores):
      val_to_reg : clave de valor -> registro que lo contiene
      reg_to_val : registro -> clave de valor
      dirty      : registros cuyo valor NO esta escrito en su home
      lru        : contador de uso para elegir victima
  - Toda variable/temporal tiene una "home location" en memoria (slot
    del frame o etiqueta global), lo que hace el spilling siempre
    posible y correcto.
  - getReg():
      1. si el valor ya esta en un registro -> reutilizarlo (0 codigo);
      2. si hay un registro libre en el pool preferido (o en el otro) ->
         asignarlo;
      3. si no, elegir una VICTIMA por LRU entre los registros no
         bloqueados, hacer spilling (sw a su home solo si esta dirty)
         y reutilizar el registro.
  - Los registros bloqueados (lock) son los operandos de la instruccion
    en curso: nunca se eligen como victima.
  - En fronteras de bloque basico (etiquetas, saltos, llamadas y
    retornos) se hace flush: los valores dirty se escriben a su home y
    los descriptores se vacian. Es la estrategia conservadora clasica:
    prioriza correccion sobre optimizacion (los valores viven en
    memoria entre bloques, y los registros se reconstruyen bajo
    demanda dentro de cada bloque).
"""

from intermediate.tac import Const, StrLit, Var, Temp
from codegen.frame import Frame

TEMP_POOL = [f"$t{i}" for i in range(10)]
SAVED_POOL = [f"$s{i}" for i in range(8)]


class RegisterAllocator:
    def __init__(self, frame, out):
        self.frame = frame
        self.out = out              # buffer de emision de la funcion
        self.val_to_reg = {}
        self.reg_to_val = {}
        self.dirty = set()
        self.locked = set()
        self.lru = {}
        self._tick = 0
        self.used_saved = set()     # registros $s tocados (para prologo)
        self._home_cache = {}       # clave de valor -> home ('frame'/'global')

    # ------------------------------------------------------------------
    # nucleo: getReg
    # ------------------------------------------------------------------

    def _touch(self, reg):
        self._tick += 1
        self.lru[reg] = self._tick

    def _preferred_pools(self, operand):
        if isinstance(operand, Var):
            return SAVED_POOL, TEMP_POOL
        return TEMP_POOL, SAVED_POOL

    def get_reg(self, operand):
        """getReg(): devuelve un registro para `operand` sin cargar nada.

        Aplica los tres casos: valor ya en registro, registro libre,
        o spilling de una victima LRU.
        """
        key = self._key_or_none(operand)
        # caso 1: ya esta en un registro
        if key is not None and key in self.val_to_reg:
            reg = self.val_to_reg[key]
            self._touch(reg)
            return reg
        # caso 2: registro libre (pool preferido primero)
        primary, secondary = self._preferred_pools(operand)
        for pool in (primary, secondary):
            for reg in pool:
                if reg not in self.reg_to_val and reg not in self.locked:
                    return self._bind(reg, key)
        # caso 3: spilling de la victima menos recientemente usada
        victim = self._pick_victim()
        self._spill(victim)
        return self._bind(victim, key)

    def _key_or_none(self, operand):
        if isinstance(operand, (Var, Temp)):
            return Frame.value_key(operand)
        return None  # constantes y literales no se rastrean

    def _bind(self, reg, key):
        if reg in SAVED_POOL:
            self.used_saved.add(reg)
        old = self.reg_to_val.pop(reg, None)
        if old is not None:
            self.val_to_reg.pop(old, None)
        if key is not None:
            self.reg_to_val[reg] = key
            self.val_to_reg[key] = reg
        self._touch(reg)
        return reg

    def _pick_victim(self):
        candidates = [r for r in self.reg_to_val if r not in self.locked]
        if not candidates:
            raise RuntimeError("getReg: no hay registros disponibles "
                               "(demasiados operandos bloqueados)")
        return min(candidates, key=lambda r: self.lru.get(r, 0))

    def _spill(self, reg):
        """Escribe la victima a su home si esta dirty y la desasocia."""
        key = self.reg_to_val.get(reg)
        if key is None:
            return
        if reg in self.dirty:
            self._store_home(reg, key)
            self.dirty.discard(reg)
        del self.reg_to_val[reg]
        del self.val_to_reg[key]

    # ------------------------------------------------------------------
    # cargas y almacenamientos a la home location
    # ------------------------------------------------------------------

    @property
    def _homes(self):
        return self._home_cache

    def _remember_home(self, operand):
        key = Frame.value_key(operand)
        if key not in self._homes:
            self._homes[key] = self.frame.home_of(operand)
        return key

    def _store_home(self, reg, key):
        kind, loc = self._homes[key]
        where = f"{loc}($fp)" if kind == 'frame' else loc
        self.out.text(f"sw {reg}, {where}", f"spill/write-back de {key[0]}")

    # ------------------------------------------------------------------
    # interfaz para el generador
    # ------------------------------------------------------------------

    def read(self, operand):
        """Devuelve un registro que CONTIENE el valor del operando.

        CONTRATO para el generador: si la instruccion tiene mas de un
        operando, cada registro devuelto debe bloquearse (lock) antes
        de pedir el siguiente. Las constantes y literales no quedan
        asociados en las tablas (no tienen home), de modo que su unico
        resguardo contra ser reutilizados dentro de la misma
        instruccion es precisamente ese lock.
        """
        if isinstance(operand, Const):
            reg = self.get_reg(operand)
            self.out.text(f"li {reg}, {operand.value}")
            return reg
        if isinstance(operand, StrLit):
            reg = self.get_reg(operand)
            self.out.text(f"la {reg}, {operand.label}")
            return reg
        key = self._remember_home(operand)
        had_it = key in self.val_to_reg
        reg = self.get_reg(operand)
        if not had_it:
            kind, loc = self._homes[key]
            where = f"{loc}($fp)" if kind == 'frame' else loc
            self.out.text(f"lw {reg}, {where}", f"cargar {operand}")
        return reg

    def write(self, operand):
        """Devuelve un registro DESTINO asociado al operando (sin cargar)."""
        self._remember_home(operand)
        reg = self.get_reg(operand)
        key = Frame.value_key(operand)
        # get_reg pudo reutilizar un registro que contenia otra cosa
        if self.reg_to_val.get(reg) != key:
            self._bind(reg, key)
        self.dirty.add(reg)
        return reg

    def mark_dirty(self, reg):
        self.dirty.add(reg)

    def lock(self, *regs):
        self.locked.update(regs)

    def unlock_all(self):
        self.locked.clear()

    def invalidate(self, operand):
        """Olvida el binding de un valor sin escribirlo (p. ej. tras
        asignarle directamente en memoria)."""
        key = self._key_or_none(operand)
        if key is not None and key in self.val_to_reg:
            reg = self.val_to_reg.pop(key)
            self.reg_to_val.pop(reg, None)
            self.dirty.discard(reg)

    def flush(self, comment='fin de bloque basico'):
        """Write-back de todos los valores dirty y limpieza de tablas.

        Se invoca en fronteras de bloque basico: antes de etiquetas,
        saltos, llamadas, retornos e instrucciones que pueden lanzar
        errores de runtime (para que la memoria siempre sea consistente
        si un try/catch desvia el control).
        """
        for reg in sorted(self.dirty & set(self.reg_to_val)):
            key = self.reg_to_val[reg]
            self._store_home(reg, key)
        self.dirty.clear()
        self.reg_to_val.clear()
        self.val_to_reg.clear()
        self.locked.clear()
