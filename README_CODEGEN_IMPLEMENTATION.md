# Generación de código MIPS — Documento de diseño

Este documento explica la arquitectura del backend: la convención de
llamadas, el manejo del stack, el diseño de `getReg()` y la traducción
de cada instrucción TAC. El código correspondiente vive en
`program/codegen/`.

## 1. Convención de llamadas (calling convention)

Uniforme para todas las funciones, métodos y `main`. Definida en
`frame.py` y `mips_generator.py`.

### Roles de registros

| Registro | Rol |
|---|---|
| `$v0` | Valor de retorno (y número de syscall) |
| `$a0–$a3` | Argumentos **del runtime interno** y syscalls (no de funciones de usuario) |
| `$t0–$t9` | Temporales caller-saved, administrados por `getReg()` |
| `$s0–$s7` | Callee-saved: cada función guarda/restaura los que usa |
| `$sp` | Puntero de pila |
| `$fp` | Frame pointer (base fija del registro de activación) |
| `$ra` | Dirección de retorno |

Los argumentos de funciones de usuario **viajan por el stack** (no por
`$a0–$a3`): el modelo es más simple, uniforme para cualquier aridad y
soporta recursión y llamadas anidadas por construcción.

### Layout del registro de activación

```
direcciones altas
+----------------------+
|  argumento n-1       |  $fp + 8 + 4*(n-1)
|  ...                 |
|  argumento 0         |  $fp + 8          empujados por el LLAMADOR
+----------------------+
|  $ra guardado        |  $fp + 4
|  $fp del llamador    |  $fp + 0          <- $fp apunta aquí
+----------------------+
|  $s guardados        |
|  locales/temporales  |  $fp - 4, -8, ... (frame de tamaño fijo)
+----------------------+ <- $sp
direcciones bajas
```

### Secuencia de llamada (caller)

```mips
addiu $sp, $sp, -4*n        # espacio para n argumentos
sw    $tX, 0($sp)           # argumento 0 (izquierda a derecha)
sw    $tY, 4($sp)           # argumento 1 ...
# flush: todo valor vivo vuelve a su home (los $t son caller-saved)
jal   func_f                # salta y guarda $ra
addiu $sp, $sp, 4*n         # el llamador libera los argumentos
move  $tZ, $v0              # valor de retorno
```

### Prólogo / epílogo (callee)

```mips
func_f:
    addiu $sp, $sp, -8      # prólogo
    sw    $ra, 4($sp)       # guardar dirección de retorno
    sw    $fp, 0($sp)       # guardar $fp del llamador
    move  $fp, $sp          # nuevo frame pointer
    addiu $sp, $sp, -K      # reservar locales/temporales/$s usados
    sw    $sX, -o($fp)      # callee-saved que la función usará
    ...cuerpo...
__func_f_epilogue:
    lw    $sX, -o($fp)      # restaurar $s
    move  $sp, $fp          # liberar frame
    lw    $fp, 0($sp)       # restaurar $fp del llamador
    lw    $ra, 4($sp)       # restaurar $ra
    addiu $sp, $sp, 8
    jr    $ra               # retorno
```

`main` comparte el mismo prólogo pero termina con `li $v0, 10; syscall`
(exit) en lugar de `jr $ra`.

**Por qué esto preserva valores vivos entre llamadas:** antes de cada
`jal` el asignador hace *flush* (escribe los registros sucios a su
*home location* en memoria). Después de la llamada los valores se
recargan bajo demanda. Como cada frame es propio y `$fp/$ra` se
guardan siempre, las llamadas anidadas y la recursión (`fib`,
`factorial` en los tests) funcionan sin estado compartido.

Los métodos de clase reciben `this` como argumento 0 implícito
(los demás argumentos se corren una posición).

## 2. getReg() — asignación de registros (`register_allocator.py`)

Basado en los descriptores de registros/direcciones de Aho et al.
(sección 8.6), como asignación **local por bloque básico**:

- **Tablas**: `val_to_reg` (valor→registro), `reg_to_val`
  (registro→valor), `dirty` (registros cuyo valor no está escrito en
  memoria), `lru` (contador de uso para elegir víctima).
- **Home locations**: todo valor (local, parámetro, temporal, global)
  tiene una ubicación fija en memoria (slot del frame o etiqueta
  `g_*` en `.data`). Esto garantiza que **siempre** se puede derramar.
- **Pools**: `$t0–$t9` preferidos para temporales de expresión;
  `$s0–$s7` preferidos para variables con nombre. Si el pool preferido
  se agota, se usa el otro. Los `$s` usados se guardan/restauran en el
  prólogo/epílogo (callee-saved).
- **Algoritmo** (`get_reg`):
  1. valor ya en un registro → reutilizarlo (cero instrucciones);
  2. registro libre → asignarlo;
  3. sin libres → **víctima LRU** entre los no bloqueados; si está
     `dirty` se emite `sw` a su home (spilling) y se reutiliza.
- **Bloqueo (lock)**: los operandos de la instrucción en curso se
  bloquean para que no sean elegidos como víctimas de sí mismos.
- **Flush** en fronteras de bloque básico (etiquetas, saltos,
  llamadas, retornos): write-back de valores sucios y limpieza de
  tablas. Estrategia conservadora: correcta sin análisis de vida.
  Nota: el flush escribe a memoria pero no destruye el contenido
  físico del registro, por lo que un branch puede usar el registro de
  su condición inmediatamente después del flush.
- **Instrucciones que pueden fallar** (división, accesos a arrays)
  hacen flush *antes* de la operación: si el error salta al handler de
  un `try/catch`, la memoria queda consistente.

El test `test_muchos_temporales_fuerza_getreg` agota los 18 registros
y verifica (con resultado calculado a mano) que el spilling no
corrompe ningún valor.

## 3. Traducción TAC → MIPS (`mips_generator.py`)

| TAC | MIPS emitido |
|---|---|
| `x = const` | `li $r, const` (+ write-back diferido) |
| `x = y` | `move $rx, $ry` |
| `t = a + b` / `-` / `*` | `addu` / `subu` / `mul $rt, $ra, $rb` |
| `t = a / b` | chequeo `bne $rb, $zero` → `div $ra, $rb; mflo $rt` |
| `t = a % b` | ídem con `mfhi` |
| `t = a < b` | `slt $rt, $ra, $rb` |
| `t = a > b` | `slt $rt, $rb, $ra` |
| `t = a <= b` | `slt $rt, $rb, $ra; xori $rt, $rt, 1` |
| `t = a >= b` | `slt $rt, $ra, $rb; xori $rt, $rt, 1` |
| `t = a == b` | `subu $rt, $ra, $rb; sltiu $rt, $rt, 1` |
| `t = a != b` | `subu $rt, $ra, $rb; sltu $rt, $zero, $rt` |
| `t = -a` | `subu $rt, $zero, $ra` |
| `t = !a` | `xori $rt, $ra, 1` |
| `label L` | flush + `L:` |
| `goto L` | flush + `j L` |
| `if t goto L` | flush + `bne $rt, $zero, L` |
| `ifFalse t goto L` | flush + `beq $rt, $zero, L` |
| `param x` | se acumula; se empuja al stack en el `call` |
| `t = call f, n` | pushes + flush + `jal f` + pop + `move $rt, $v0` |
| `return x` | `$v0 ← x` + `j <epílogo>` |
| `print_int x` | `move $a0; li $v0, 1; syscall` + newline |
| `print_str x` | `li $v0, 4; syscall` + newline |
| `print_bool x` | `jal __print_bool` ("true"/"false") + newline |
| `t = newarray n` | `sbrk(4+4n)` (syscall 9), longitud en header |
| `t = a[i]` | `jal __bounds_check` + `lw $rt, 4($a2)` |
| `a[i] = x` | ídem + `sw` |
| `t = len a` | `lw $rt, 0($ra)` |
| `t = new C` | `sbrk(size)` + llamada al constructor con `this` |
| `t = o.campo` | `lw $rt, offset($ro)` (offset calculado en semántica) |
| `o.campo = x` | `sw $rx, offset($ro)` |
| `t = concat a, b` | `jal __concat` (sbrk + copia) |
| `t = itos a` | `jal __itos` |
| `try_enter L` | `jal __try_push` (guarda etiqueta, `$sp`, `$fp`) |
| `try_exit` | `jal __try_pop` |

Solo se usan comparaciones con `slt/sltu/sltiu + xori` (instrucciones
reales) para máxima compatibilidad entre SPIM y MARS.

### Runtime embebido (`runtime.py`)

Rutinas MIPS incluidas en cada `.asm`: `__concat`, `__itos`, `__btos`,
`__print_bool`, `__bounds_check`, `__try_push/__try_pop`,
`__runtime_error`. **Contrato**: solo usan `$a0–$a3, $v0, $v1`, nunca
tocan `$t*/$s*` del llamador.

**try/catch**: pila de handlers en `.data` (32 niveles). Cada entrada
guarda `[etiqueta catch, $sp, $fp]`. Ante un error de runtime,
`__runtime_error` hace **unwinding real**: restaura `$sp/$fp` del
momento del `try` y salta al catch — incluso si el error ocurrió
varias llamadas más adentro (verificado en
`test_try_catch_division_en_funcion`). Sin handler activo, imprime
`Runtime error: <mensaje>` y termina.

### Representación de datos

- `integer`/`boolean`: palabra de 32 bits (bool = 0/1).
- `string`: puntero a ASCIIZ (literales en `.data`, dinámicas en heap).
- `array`: puntero a `[longitud][e0][e1]...` en heap.
- objeto: puntero a bloque de campos (offsets resueltos en semántica;
  los campos heredados van primero, mismo offset que en la clase padre).
- Globales: etiquetas `g_*` en `.data`; locales/params/temps: slots del
  frame.

## 4. Decisiones y trade-offs

- **Corrección sobre optimización**: la asignación es local por bloque
  con flush conservador. Un optimizador global (liveness inter-bloque,
  coloreo) reduciría cargas/almacenamientos, pero este diseño es
  verificable y nunca reutiliza registros de forma incorrecta.
- **Argumentos por stack** en lugar de `$a0–$a3`: elimina casos
  especiales de aridad > 4 y hace la recursión trivialmente correcta.
  Los `$a*` quedan reservados para el runtime y syscalls, evitando
  interferencias con el asignador.
- **Despacho estático de métodos**: sin vtables. `p.hablar()` se
  resuelve buscando `hablar` desde la clase declarada de `p` hacia
  arriba. Cubre la herencia y sobreescritura del programa oficial del
  curso; el despacho dinámico queda documentado como trabajo futuro.
