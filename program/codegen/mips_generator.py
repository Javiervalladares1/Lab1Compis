"""Generador de codigo MIPS a partir del TAC de Compiscript.

Traduce cada instruccion TAC a una secuencia de instrucciones MIPS
reales (sin depender de pseudoinstrucciones exoticas), usando:

  - RegisterAllocator (getReg) para asignar $t/$s con spilling,
  - Frame para el layout del registro de activacion,
  - el runtime embebido (runtime.py) para strings, prints y errores.

Puntos delicados (comentados en el codigo):
  - Los operandos de cada instruccion se BLOQUEAN mientras se asignan
    los demas, para que getReg no elija como victima un registro que
    la propia instruccion esta usando.
  - Antes de saltos, etiquetas, llamadas y retornos se hace flush del
    asignador (write-back de valores sucios): los valores viven en
    memoria entre bloques basicos.
  - Las instrucciones que pueden lanzar errores de runtime (indices y
    division) hacen flush ANTES de la operacion, para que un salto al
    handler de try/catch encuentre la memoria consistente.
  - Las comparaciones se implementan con slt/sltu/sltiu y xori, que son
    instrucciones reales aceptadas por SPIM y MARS por igual.
"""

from intermediate import tac
from codegen.emitter import Emitter, FunctionBuffer
from codegen.frame import Frame
from codegen.register_allocator import RegisterAllocator
from codegen.runtime import RUNTIME_DATA, RUNTIME_TEXT


class MIPSGenerator:
    def __init__(self, tac_program):
        self.program = tac_program
        self.emitter = Emitter()
        self.aux_counter = 0        # etiquetas auxiliares (div0, etc.)
        self.out = None             # FunctionBuffer actual
        self.alloc = None           # RegisterAllocator actual
        self.frame = None           # Frame actual
        self.pending_params = []    # operandos param acumulados hasta el call

    # ------------------------------------------------------------------

    def new_aux_label(self, hint):
        self.aux_counter += 1
        return f"__aux{self.aux_counter}_{hint}"

    def generate(self):
        self.emit_data_section()
        for func in self.program.all_functions():
            self.gen_function(func)
        self.emitter.raw(RUNTIME_TEXT)
        return self.emitter.assemble()

    def emit_data_section(self):
        em = self.emitter
        for text, lit in self.program.strings.items():
            escaped = text.replace('\\', '\\\\')
            em.data_label(lit.label, f'.asciiz "{escaped}"')
        for sym in self.program.globals:
            em.data_label(f"g_{sym.unique_name}", '.word 0',
                          f"global {sym.name}: {sym.type}")
        for label, directive in RUNTIME_DATA:
            em.data_label(label, directive)

    # ------------------------------------------------------------------
    # funciones: prologo / cuerpo / epilogo
    # ------------------------------------------------------------------

    def gen_function(self, func):
        self.frame = Frame(func)
        self.out = FunctionBuffer()
        self.alloc = RegisterAllocator(self.frame, self.out)
        self.pending_params = []
        self.current_func = func
        self.epilogue_label = f"__{func.label}_epilogue"

        for instr in func.instructions:
            self.gen_instr(instr)
        self.alloc.flush('fin de funcion')

        em = self.emitter
        em.blank()
        em.comment(f"===== funcion {func.name} =====")
        em.label(func.label)
        # prologo: guardar $ra y $fp del llamador, establecer nuevo frame
        em.text('addiu $sp, $sp, -8', 'prologo: espacio para $ra y $fp')
        em.text('sw $ra, 4($sp)', 'guardar direccion de retorno')
        em.text('sw $fp, 0($sp)', 'guardar $fp del llamador')
        em.text('move $fp, $sp', 'nuevo frame pointer')
        # reservar slots de locales/temporales + slots para $s usados
        saved_regs = sorted(self.alloc.used_saved)
        saved_slots = {}
        for reg in saved_regs:
            self.frame.size += 4
            saved_slots[reg] = -self.frame.size
        if self.frame.size > 0:
            em.text(f"addiu $sp, $sp, -{self.frame.size}",
                    f"reservar frame ({self.frame.size} bytes)")
        for reg, off in saved_slots.items():
            em.text(f"sw {reg}, {off}($fp)", f"callee-saved {reg}")
        # cuerpo
        for line in self.out.lines:
            em.text_lines.append(line)
        # epilogo
        em.label(self.epilogue_label)
        for reg, off in saved_slots.items():
            em.text(f"lw {reg}, {off}($fp)", f"restaurar {reg}")
        if func.label == 'main':
            em.text('li $v0, 10', 'syscall exit: fin del programa')
            em.text('syscall')
        else:
            em.text('move $sp, $fp', 'liberar frame')
            em.text('lw $fp, 0($sp)', 'restaurar $fp del llamador')
            em.text('lw $ra, 4($sp)', 'restaurar direccion de retorno')
            em.text('addiu $sp, $sp, 8')
            em.text('jr $ra', 'retorno al llamador')

    # ------------------------------------------------------------------
    # despacho por tipo de instruccion TAC
    # ------------------------------------------------------------------

    def gen_instr(self, instr):
        method = getattr(self, 'gen_' + type(instr).__name__)
        method(instr)

    def gen_Comment(self, instr):
        self.out.comment(instr.text)

    def gen_Label(self, instr):
        # frontera de bloque basico: la memoria debe quedar consistente
        self.alloc.flush(f"antes de etiqueta {instr.name}")
        self.out.label(instr.name)

    def gen_Goto(self, instr):
        self.alloc.flush('antes de goto')
        self.out.text(f"j {instr.label}")

    def gen_IfTrue(self, instr):
        reg = self.alloc.read(instr.src)
        self.alloc.lock(reg)
        # flush no destruye el contenido fisico de los registros: solo
        # escribe los valores sucios a memoria y limpia las tablas, por
        # lo que `reg` sigue siendo valido para el branch.
        self.alloc.flush('antes de branch')
        self.out.text(f"bne {reg}, $zero, {instr.label}")

    def gen_IfFalse(self, instr):
        reg = self.alloc.read(instr.src)
        self.alloc.lock(reg)
        self.alloc.flush('antes de branch')
        self.out.text(f"beq {reg}, $zero, {instr.label}")

    def gen_Copy(self, instr):
        rs = self.alloc.read(instr.src)
        self.alloc.lock(rs)
        rd = self.alloc.write(instr.dst)
        if rd != rs:
            self.out.text(f"move {rd}, {rs}", f"{instr.dst} = {instr.src}")
        self.alloc.unlock_all()

    def gen_UnaryOp(self, instr):
        rs = self.alloc.read(instr.a)
        self.alloc.lock(rs)
        rd = self.alloc.write(instr.dst)
        if instr.op == 'neg':
            self.out.text(f"subu {rd}, $zero, {rs}", f"{instr.dst} = -{instr.a}")
        else:  # not logico sobre booleanos 0/1
            self.out.text(f"xori {rd}, {rs}, 1", f"{instr.dst} = !{instr.a}")
        self.alloc.unlock_all()

    ARITH = {'+': 'addu', '-': 'subu', '*': 'mul'}

    def gen_BinOp(self, instr):
        if instr.op in ('/', '%'):
            return self.gen_division(instr)
        ra = self.alloc.read(instr.a)
        self.alloc.lock(ra)
        rb = self.alloc.read(instr.b)
        self.alloc.lock(rb)
        rd = self.alloc.write(instr.dst)
        op = instr.op
        cm = f"{instr.dst} = {instr.a} {op} {instr.b}"
        if op in self.ARITH:
            self.out.text(f"{self.ARITH[op]} {rd}, {ra}, {rb}", cm)
        elif op == '<':
            self.out.text(f"slt {rd}, {ra}, {rb}", cm)
        elif op == '>':
            self.out.text(f"slt {rd}, {rb}, {ra}", cm)
        elif op == '<=':
            self.out.text(f"slt {rd}, {rb}, {ra}", cm)
            self.out.text(f"xori {rd}, {rd}, 1")
        elif op == '>=':
            self.out.text(f"slt {rd}, {ra}, {rb}", cm)
            self.out.text(f"xori {rd}, {rd}, 1")
        elif op == '==':
            self.out.text(f"subu {rd}, {ra}, {rb}", cm)
            self.out.text(f"sltiu {rd}, {rd}, 1")
        elif op == '!=':
            self.out.text(f"subu {rd}, {ra}, {rb}", cm)
            self.out.text(f"sltu {rd}, $zero, {rd}")
        else:
            raise ValueError(f"operador TAC desconocido: {op}")
        self.alloc.unlock_all()

    def gen_division(self, instr):
        ra = self.alloc.read(instr.a)
        self.alloc.lock(ra)
        rb = self.alloc.read(instr.b)
        self.alloc.lock(rb)
        # la division puede lanzar error de runtime: flush para que un
        # posible salto al catch encuentre la memoria consistente
        self.alloc.flush('division puede fallar')
        ok = self.new_aux_label('divok')
        self.out.text(f"bne {rb}, $zero, {ok}", 'chequeo division entre cero')
        self.out.text('la $a0, __msg_div0')
        self.out.text('j __runtime_error')
        self.out.label(ok)
        self.out.text(f"div {ra}, {rb}", f"{instr.a} / {instr.b}")
        rd = self.alloc.write(instr.dst)
        if instr.op == '/':
            self.out.text(f"mflo {rd}", f"{instr.dst} = cociente")
        else:
            self.out.text(f"mfhi {rd}", f"{instr.dst} = residuo")
        self.alloc.unlock_all()

    # ---- llamadas ------------------------------------------------------

    def gen_Param(self, instr):
        # los param se acumulan y se empujan todos juntos en el call:
        # el TAC garantiza que los param de una llamada son contiguos
        self.pending_params.append(instr.src)

    def gen_Call(self, instr):
        params = self.pending_params
        self.pending_params = []
        n = len(params)
        # cargar cada argumento en un registro y guardarlo en su slot
        if n > 0:
            self.out.text(f"addiu $sp, $sp, -{4 * n}",
                          f"espacio para {n} argumento(s)")
            for i, p in enumerate(params):
                reg = self.alloc.read(p)
                self.out.text(f"sw {reg}, {4 * i}($sp)", f"argumento {i}")
        # convencion: TODO valor vivo vuelve a su home antes de llamar
        # ($t son caller-saved y el callee puede pisar cualquier cosa)
        self.alloc.flush('antes de llamada')
        self.out.text(f"jal {instr.func_label}",
                      f"call {instr.func_label}, {n}")
        if n > 0:
            self.out.text(f"addiu $sp, $sp, {4 * n}", 'liberar argumentos')
        if instr.dst is not None:
            rd = self.alloc.write(instr.dst)
            self.out.text(f"move {rd}, $v0", 'valor de retorno')
            self.alloc.unlock_all()

    def gen_Return(self, instr):
        if instr.src is not None:
            reg = self.alloc.read(instr.src)
            self.alloc.lock(reg)
            self.alloc.flush('antes de return')
            if reg != '$v0':
                self.out.text(f"move $v0, {reg}", 'valor de retorno en $v0')
        else:
            self.alloc.flush('antes de return')
        self.out.text(f"j {self.epilogue_label}")

    # ---- print ----------------------------------------------------------

    def gen_Print(self, instr):
        reg = self.alloc.read(instr.src)
        self.out.text(f"move $a0, {reg}")
        if instr.kind == 'int':
            self.out.text('li $v0, 1', 'syscall print_int')
            self.out.text('syscall')
        elif instr.kind == 'str':
            self.out.text('li $v0, 4', 'syscall print_string')
            self.out.text('syscall')
        else:  # bool -> "true" / "false"
            self.out.text('jal __print_bool')
        self.out.text('la $a0, __nl', 'salto de linea')
        self.out.text('li $v0, 4')
        self.out.text('syscall')

    # ---- arreglos --------------------------------------------------------

    def gen_NewArray(self, instr):
        # layout: [longitud][elem 0][elem 1]... ; sbrk entrega memoria en 0
        if isinstance(instr.size, tac.Const):
            total = 4 + 4 * instr.size.value
            self.out.text(f"li $a0, {total}", f"arreglo de {instr.size.value}")
            self.out.text('li $v0, 9', 'sbrk')
            self.out.text('syscall')
            self.out.text(f"li $a1, {instr.size.value}")
        else:
            rs = self.alloc.read(instr.size)
            self.out.text(f"move $a1, {rs}", 'longitud')
            self.out.text('sll $a0, $a1, 2')
            self.out.text('addiu $a0, $a0, 4', 'bytes = 4 + 4*n')
            self.out.text('li $v0, 9', 'sbrk')
            self.out.text('syscall')
        self.out.text('sw $a1, 0($v0)', 'guardar longitud en el header')
        rd = self.alloc.write(instr.dst)
        self.out.text(f"move {rd}, $v0", f"{instr.dst} = nuevo arreglo")
        self.alloc.unlock_all()

    def _index_addr(self, arr_reg, idx_reg):
        """Deja en $a2 la direccion del elemento (tras bounds check)."""
        self.out.text(f"move $a0, {idx_reg}")
        self.out.text(f"move $a1, {arr_reg}")
        self.out.text('jal __bounds_check', 'valida 0 <= idx < len')
        self.out.text('sll $a2, $a0, 2')
        self.out.text('addu $a2, $a2, $a1')

    def gen_IndexLoad(self, instr):
        ra = self.alloc.read(instr.arr)
        self.alloc.lock(ra)
        ri = self.alloc.read(instr.idx)
        self.alloc.lock(ri)
        # el acceso puede lanzar error: memoria consistente antes del salto
        self.alloc.flush('acceso a arreglo puede fallar')
        self._index_addr(ra, ri)
        rd = self.alloc.write(instr.dst)
        self.out.text(f"lw {rd}, 4($a2)", f"{instr.dst} = {instr.arr}[{instr.idx}]")
        self.alloc.unlock_all()

    def gen_IndexStore(self, instr):
        ra = self.alloc.read(instr.arr)
        self.alloc.lock(ra)
        ri = self.alloc.read(instr.idx)
        self.alloc.lock(ri)
        rs = self.alloc.read(instr.src)
        self.alloc.lock(rs)
        self.alloc.flush('acceso a arreglo puede fallar')
        self._index_addr(ra, ri)
        self.out.text(f"sw {rs}, 4($a2)", f"{instr.arr}[{instr.idx}] = {instr.src}")
        self.alloc.unlock_all()

    def gen_ArrayLen(self, instr):
        ra = self.alloc.read(instr.arr)
        self.alloc.lock(ra)
        rd = self.alloc.write(instr.dst)
        self.out.text(f"lw {rd}, 0({ra})", f"{instr.dst} = len {instr.arr}")
        self.alloc.unlock_all()

    # ---- objetos ----------------------------------------------------------

    def gen_NewObject(self, instr):
        self.out.text(f"li $a0, {instr.size_bytes}",
                      f"new {instr.class_name}")
        self.out.text('li $v0, 9', 'sbrk (memoria inicializada en 0)')
        self.out.text('syscall')
        rd = self.alloc.write(instr.dst)
        self.out.text(f"move {rd}, $v0")
        self.alloc.unlock_all()

    def gen_FieldLoad(self, instr):
        ro = self.alloc.read(instr.obj)
        self.alloc.lock(ro)
        rd = self.alloc.write(instr.dst)
        self.out.text(f"lw {rd}, {instr.offset}({ro})",
                      f"{instr.dst} = {instr.obj}.{instr.fname}")
        self.alloc.unlock_all()

    def gen_FieldStore(self, instr):
        ro = self.alloc.read(instr.obj)
        self.alloc.lock(ro)
        rs = self.alloc.read(instr.src)
        self.alloc.lock(rs)
        self.out.text(f"sw {rs}, {instr.offset}({ro})",
                      f"{instr.obj}.{instr.fname} = {instr.src}")
        self.alloc.unlock_all()

    # ---- strings -----------------------------------------------------------

    def _runtime_binary(self, instr, helper, comment):
        ra = self.alloc.read(instr.a)
        self.alloc.lock(ra)
        rb = self.alloc.read(instr.b)
        self.alloc.lock(rb)
        self.out.text(f"move $a0, {ra}")
        self.out.text(f"move $a1, {rb}")
        self.out.text(f"jal {helper}", comment)
        rd = self.alloc.write(instr.dst)
        self.out.text(f"move {rd}, $v0")
        self.alloc.unlock_all()

    def gen_Concat(self, instr):
        # __concat preserva $t/$s: no se necesita flush
        self._runtime_binary(instr, '__concat',
                             f"{instr.dst} = concat")

    def _runtime_unary(self, instr, helper, comment):
        ra = self.alloc.read(instr.a)
        self.alloc.lock(ra)
        self.out.text(f"move $a0, {ra}")
        self.out.text(f"jal {helper}", comment)
        rd = self.alloc.write(instr.dst)
        self.out.text(f"move {rd}, $v0")
        self.alloc.unlock_all()

    def gen_IntToStr(self, instr):
        self._runtime_unary(instr, '__itos', f"{instr.dst} = itos {instr.a}")

    def gen_BoolToStr(self, instr):
        self._runtime_unary(instr, '__btos', f"{instr.dst} = btos {instr.a}")

    # ---- try / catch ---------------------------------------------------------

    def gen_TryEnter(self, instr):
        self.alloc.flush('estado consistente al entrar al try')
        self.out.text(f"la $a0, {instr.catch_label}")
        self.out.text('jal __try_push', f"try -> {instr.catch_label}")

    def gen_TryExit(self, instr):
        self.alloc.flush('salida normal del try')
        self.out.text('jal __try_pop')

    def gen_CatchBind(self, instr):
        rd = self.alloc.write(instr.dst)
        self.out.text(f"lw {rd}, __err_msg", 'mensaje del error capturado')
        self.alloc.unlock_all()
