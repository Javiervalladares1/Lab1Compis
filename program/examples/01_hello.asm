.data
    S0: .asciiz "Hola Compiscript"
    S1: .asciiz "x = "
    g_x: .word 0                     # global x: integer
    g_y: .word 0                     # global y: integer
    __nl: .asciiz "\n"
    __true_str: .asciiz "true"
    __false_str: .asciiz "false"
    __rte_prefix: .asciiz "Runtime error: "
    __msg_bounds: .asciiz "indice fuera de rango"
    __msg_div0: .asciiz "division entre cero"
    __msg_null: .asciiz "referencia null"
    __err_msg: .word 0
    __handler_stack: .space 384
    __handler_sp: .word 0

.text
.globl main

    # ===== funcion main =====
main:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -40          # reservar frame (40 bytes)
        sw $s0, -36($fp)             # callee-saved $s0
        sw $s1, -40($fp)             # callee-saved $s1
    la $t0, S0
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t0, 42
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t0, 1
    move $a0, $t0
    jal __print_bool
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t0, 10
    move $s0, $t0                    # x = 10
    li $t0, 4
    move $s1, $t0                    # y = 4
    li $t0, 2
    mul $t1, $s1, $t0                # t0 = y * 2
    addu $t0, $s0, $t1               # t1 = x + t0
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    subu $t2, $s0, $s1               # t2 = x - y
    move $a0, $t2
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s0, g_x                      # spill/write-back de var
    sw $s1, g_y                      # spill/write-back de var
    sw $t0, -8($fp)                  # spill/write-back de temp
    sw $t1, -4($fp)                  # spill/write-back de temp
    sw $t2, -12($fp)                 # spill/write-back de temp
    bne $s1, $zero, __aux1_divok     # chequeo division entre cero
    la $a0, __msg_div0
    j __runtime_error
__aux1_divok:
    div $s0, $s1                     # x / y
    mflo $t0                         # t3 = cociente
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_x                      # cargar x
    lw $s1, g_y                      # cargar y
    sw $t0, -16($fp)                 # spill/write-back de temp
    bne $s1, $zero, __aux2_divok     # chequeo division entre cero
    la $a0, __msg_div0
    j __runtime_error
__aux2_divok:
    div $s0, $s1                     # x / y
    mfhi $t0                         # t4 = residuo
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_x                      # cargar x
    lw $s1, g_y                      # cargar y
    slt $t1, $s1, $s0                # t5 = x > y
    move $a0, $t1
    jal __print_bool
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    move $a0, $s0
    jal __itos                       # t6 = itos x
    move $t2, $v0
    la $t3, S1
    move $a0, $t3
    move $a1, $t2
    jal __concat                     # t7 = concat
    move $t4, $v0
    move $a0, $t4
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -20($fp)                 # spill/write-back de temp
    sw $t1, -24($fp)                 # spill/write-back de temp
    sw $t2, -28($fp)                 # spill/write-back de temp
    sw $t4, -32($fp)                 # spill/write-back de temp
__main_epilogue:
        lw $s0, -36($fp)             # restaurar $s0
        lw $s1, -40($fp)             # restaurar $s1
        li $v0, 10                   # syscall exit: fin del programa
        syscall

# ===========================================================================
# Runtime de Compiscript
# Contrato: las rutinas solo usan $a0-$a3, $v0, $v1; preservan $t* y $s*.
# ===========================================================================

# ---- __concat: $v0 = nueva string $a0 ++ $a1 ------------------------------
__concat:
    move  $a2, $a0                   # medir len($a0)
__cc_len1:
    lbu   $v0, 0($a2)
    beq   $v0, $zero, __cc_len1_done
    addiu $a2, $a2, 1
    j     __cc_len1
__cc_len1_done:
    subu  $a2, $a2, $a0              # $a2 = len1
    move  $a3, $a1                   # medir len($a1)
__cc_len2:
    lbu   $v0, 0($a3)
    beq   $v0, $zero, __cc_len2_done
    addiu $a3, $a3, 1
    j     __cc_len2
__cc_len2_done:
    subu  $a3, $a3, $a1              # $a3 = len2
    addiu $sp, $sp, -8               # sbrk destruye $a0: salvar punteros
    sw    $a0, 0($sp)
    sw    $a1, 4($sp)
    addu  $a0, $a2, $a3
    addiu $a0, $a0, 1                # total = len1 + len2 + terminador
    li    $v0, 9                     # sbrk
    syscall
    lw    $a0, 0($sp)
    lw    $a1, 4($sp)
    addiu $sp, $sp, 8
    move  $v1, $v0                   # $v1 = cursor destino ($v0 = retorno)
__cc_copy1:
    lbu   $a2, 0($a0)
    beq   $a2, $zero, __cc_copy2
    sb    $a2, 0($v1)
    addiu $a0, $a0, 1
    addiu $v1, $v1, 1
    j     __cc_copy1
__cc_copy2:
    lbu   $a2, 0($a1)
    sb    $a2, 0($v1)                # copia incluso el 0 final
    beq   $a2, $zero, __cc_done
    addiu $a1, $a1, 1
    addiu $v1, $v1, 1
    j     __cc_copy2
__cc_done:
    jr    $ra

# ---- __itos: $v0 = representacion string del entero $a0 -------------------
__itos:
    move  $a1, $a0                   # $a1 = n
    li    $a0, 12                    # buffer para 32 bits con signo + NUL
    li    $v0, 9                     # sbrk
    syscall
    addiu $a2, $v0, 11               # escribir digitos desde el final
    sb    $zero, 0($a2)
    slt   $a3, $a1, $zero            # $a3 = 1 si n es negativo
    beq   $a3, $zero, __it_abs_ok
    subu  $a1, $zero, $a1
__it_abs_ok:
    bne   $a1, $zero, __it_loop
    addiu $a2, $a2, -1               # caso especial: n == 0
    li    $v1, 48                    # '0'
    sb    $v1, 0($a2)
    j     __it_sign
__it_loop:
    beq   $a1, $zero, __it_sign
    li    $v1, 10
    div   $a1, $v1                   # LO = cociente, HI = residuo
    mfhi  $v1
    mflo  $a1
    addiu $v1, $v1, 48               # residuo -> caracter
    addiu $a2, $a2, -1
    sb    $v1, 0($a2)
    j     __it_loop
__it_sign:
    beq   $a3, $zero, __it_done
    addiu $a2, $a2, -1
    li    $v1, 45                    # '-'
    sb    $v1, 0($a2)
__it_done:
    move  $v0, $a2
    jr    $ra

# ---- __btos: $v0 = "true" / "false" segun $a0 -----------------------------
__btos:
    beq   $a0, $zero, __bt_false
    la    $v0, __true_str
    jr    $ra
__bt_false:
    la    $v0, __false_str
    jr    $ra

# ---- __print_bool: imprime "true"/"false" ---------------------------------
__print_bool:
    bne   $a0, $zero, __pb_true
    la    $a0, __false_str
    j     __pb_print
__pb_true:
    la    $a0, __true_str
__pb_print:
    li    $v0, 4
    syscall
    jr    $ra

# ---- __bounds_check: valida 0 <= $a0 < len($a1); $a1 != null --------------
__bounds_check:
    beq   $a1, $zero, __bc_null
    lw    $a2, 0($a1)                # longitud en el header del arreglo
    slt   $a3, $a0, $zero
    bne   $a3, $zero, __bc_fail
    slt   $a3, $a0, $a2
    beq   $a3, $zero, __bc_fail
    jr    $ra
__bc_null:
    la    $a0, __msg_null
    j     __runtime_error
__bc_fail:
    la    $a0, __msg_bounds
    j     __runtime_error

# ---- __try_push: registra handler [etiqueta=$a0, $sp, $fp] ----------------
__try_push:
    lw    $a1, __handler_sp
    la    $a2, __handler_stack
    addu  $a2, $a2, $a1
    sw    $a0, 0($a2)
    sw    $sp, 4($a2)
    sw    $fp, 8($a2)
    addiu $a1, $a1, 12
    sw    $a1, __handler_sp
    jr    $ra

# ---- __try_pop: descarta el handler mas reciente --------------------------
__try_pop:
    lw    $a1, __handler_sp
    addiu $a1, $a1, -12
    sw    $a1, __handler_sp
    jr    $ra

# ---- __runtime_error: $a0 = mensaje. NO retorna ---------------------------
# Si hay un try activo: unwind ($sp/$fp del try) y salto al catch.
# Si no lo hay: imprime "Runtime error: <msg>" y termina el programa.
__runtime_error:
    lw    $a1, __handler_sp
    beq   $a1, $zero, __re_abort
    addiu $a1, $a1, -12              # pop del handler
    sw    $a1, __handler_sp
    la    $a2, __handler_stack
    addu  $a2, $a2, $a1
    sw    $a0, __err_msg             # mensaje disponible para catch(err)
    lw    $sp, 4($a2)                # unwind: restaurar pila del try
    lw    $fp, 8($a2)
    lw    $a3, 0($a2)
    jr    $a3                        # saltar a la etiqueta catch
__re_abort:
    move  $a3, $a0
    la    $a0, __rte_prefix
    li    $v0, 4
    syscall
    move  $a0, $a3
    li    $v0, 4
    syscall
    la    $a0, __nl
    li    $v0, 4
    syscall
    li    $v0, 10                    # exit
    syscall

