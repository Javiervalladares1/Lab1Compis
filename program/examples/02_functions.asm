.data
    S0: .asciiz "fib(10) = "
    S1: .asciiz "factorial(6) = "
    S2: .asciiz "suma3 anidada = "
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
        addiu $sp, $sp, -48          # reservar frame (48 bytes)
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t0, 10
    sw $t0, 0($sp)                   # argumento 0
    jal func_fib                     # call func_fib, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $a0, $t0
    jal __itos                       # t1 = itos t0
    move $t1, $v0
    la $t2, S0
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t2 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t2, 6
    sw $t2, 0($sp)                   # argumento 0
    sw $t0, -4($fp)                  # spill/write-back de temp
    sw $t1, -8($fp)                  # spill/write-back de temp
    sw $t3, -12($fp)                 # spill/write-back de temp
    jal func_factorial               # call func_factorial, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $a0, $t0
    jal __itos                       # t4 = itos t3
    move $t1, $v0
    la $t2, S1
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t5 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t2, 5
    sw $t2, 0($sp)                   # argumento 0
    sw $t0, -16($fp)                 # spill/write-back de temp
    sw $t1, -20($fp)                 # spill/write-back de temp
    sw $t3, -24($fp)                 # spill/write-back de temp
    jal func_fib                     # call func_fib, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t1, 3
    sw $t1, 0($sp)                   # argumento 0
    sw $t0, -28($fp)                 # spill/write-back de temp
    jal func_factorial               # call func_factorial, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    addiu $sp, $sp, -12              # espacio para 3 argumento(s)
    li $t1, 1
    sw $t1, 0($sp)                   # argumento 0
    li $t1, 2
    sw $t1, 4($sp)                   # argumento 1
    li $t1, 3
    sw $t1, 8($sp)                   # argumento 2
    sw $t0, -32($fp)                 # spill/write-back de temp
    jal func_suma3                   # call func_suma3, 3
    addiu $sp, $sp, 12               # liberar argumentos
    move $t0, $v0                    # valor de retorno
    addiu $sp, $sp, -12              # espacio para 3 argumento(s)
    lw $t1, -28($fp)                 # cargar t6
    sw $t1, 0($sp)                   # argumento 0
    lw $t2, -32($fp)                 # cargar t7
    sw $t2, 4($sp)                   # argumento 1
    sw $t0, 8($sp)                   # argumento 2
    sw $t0, -36($fp)                 # spill/write-back de temp
    jal func_suma3                   # call func_suma3, 3
    addiu $sp, $sp, 12               # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $a0, $t0
    jal __itos                       # t10 = itos t9
    move $t1, $v0
    la $t2, S2
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t11 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -40($fp)                 # spill/write-back de temp
    sw $t1, -44($fp)                 # spill/write-back de temp
    sw $t3, -48($fp)                 # spill/write-back de temp
__main_epilogue:
        li $v0, 10                   # syscall exit: fin del programa
        syscall

    # ===== funcion fib =====
func_fib:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -28          # reservar frame (28 bytes)
        sw $s0, -28($fp)             # callee-saved $s0
    lw $s0, 8($fp)                   # cargar n
    li $t0, 1
    slt $t1, $t0, $s0                # t0 = n <= 1
    xori $t1, $t1, 1
    sw $t1, -4($fp)                  # spill/write-back de temp
    beq $t1, $zero, L0_endif
    lw $s0, 8($fp)                   # cargar n
    move $v0, $s0                    # valor de retorno en $v0
    j __func_fib_epilogue
L0_endif:
    lw $s0, 8($fp)                   # cargar n
    li $t0, 1
    subu $t1, $s0, $t0               # t1 = n - 1
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    sw $t1, 0($sp)                   # argumento 0
    sw $t1, -8($fp)                  # spill/write-back de temp
    jal func_fib                     # call func_fib, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    lw $s0, 8($fp)                   # cargar n
    li $t1, 2
    subu $t2, $s0, $t1               # t3 = n - 2
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    sw $t2, 0($sp)                   # argumento 0
    sw $t0, -12($fp)                 # spill/write-back de temp
    sw $t2, -16($fp)                 # spill/write-back de temp
    jal func_fib                     # call func_fib, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    lw $t1, -12($fp)                 # cargar t2
    addu $t2, $t1, $t0               # t5 = t2 + t4
    sw $t0, -20($fp)                 # spill/write-back de temp
    sw $t2, -24($fp)                 # spill/write-back de temp
    move $v0, $t2                    # valor de retorno en $v0
    j __func_fib_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_fib_epilogue
__func_fib_epilogue:
        lw $s0, -28($fp)             # restaurar $s0
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion factorial =====
func_factorial:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -20          # reservar frame (20 bytes)
        sw $s0, -20($fp)             # callee-saved $s0
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 1
    slt $t1, $t0, $s0                # t0 = n_1 <= 1
    xori $t1, $t1, 1
    sw $t1, -4($fp)                  # spill/write-back de temp
    beq $t1, $zero, L1_endif
    li $t0, 1
    move $v0, $t0                    # valor de retorno en $v0
    j __func_factorial_epilogue
L1_endif:
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 1
    subu $t1, $s0, $t0               # t1 = n_1 - 1
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    sw $t1, 0($sp)                   # argumento 0
    sw $t1, -8($fp)                  # spill/write-back de temp
    jal func_factorial               # call func_factorial, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    lw $s0, 8($fp)                   # cargar n_1
    mul $t1, $s0, $t0                # t3 = n_1 * t2
    sw $t0, -12($fp)                 # spill/write-back de temp
    sw $t1, -16($fp)                 # spill/write-back de temp
    move $v0, $t1                    # valor de retorno en $v0
    j __func_factorial_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_factorial_epilogue
__func_factorial_epilogue:
        lw $s0, -20($fp)             # restaurar $s0
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion suma3 =====
func_suma3:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -20          # reservar frame (20 bytes)
        sw $s0, -12($fp)             # callee-saved $s0
        sw $s1, -16($fp)             # callee-saved $s1
        sw $s2, -20($fp)             # callee-saved $s2
    lw $s0, 8($fp)                   # cargar a
    lw $s1, 12($fp)                  # cargar b
    addu $t0, $s0, $s1               # t0 = a + b
    lw $s2, 16($fp)                  # cargar c
    addu $t1, $t0, $s2               # t1 = t0 + c
    sw $t0, -4($fp)                  # spill/write-back de temp
    sw $t1, -8($fp)                  # spill/write-back de temp
    move $v0, $t1                    # valor de retorno en $v0
    j __func_suma3_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_suma3_epilogue
__func_suma3_epilogue:
        lw $s0, -12($fp)             # restaurar $s0
        lw $s1, -16($fp)             # restaurar $s1
        lw $s2, -20($fp)             # restaurar $s2
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

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

