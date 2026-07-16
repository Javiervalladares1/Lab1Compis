.data
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
        addiu $sp, $sp, -4           # reservar frame (4 bytes)
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t0, 5
    sw $t0, 0($sp)                   # argumento 0
    jal func_factorial               # call func_factorial, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    sw $t0, -4($fp)                  # spill/write-back de temp
__main_epilogue:
        li $v0, 10                   # syscall exit: fin del programa
        syscall

    # ===== funcion factorial =====
func_factorial:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -32          # reservar frame (32 bytes)
        sw $s0, -24($fp)             # callee-saved $s0
        sw $s1, -28($fp)             # callee-saved $s1
        sw $s2, -32($fp)             # callee-saved $s2
    li $t0, 1
    move $s0, $t0                    # ans = 1
    lw $s1, 8($fp)                   # cargar n
    move $s2, $s1                    # i = n
    sw $s0, -4($fp)                  # spill/write-back de var
    sw $s2, -8($fp)                  # spill/write-back de var
L0_while:
    lw $s0, -8($fp)                  # cargar i
    li $t0, 1
    slt $t1, $t0, $s0                # t0 = i > 1
    sw $t1, -12($fp)                 # spill/write-back de temp
    beq $t1, $zero, L1_endwhile
    lw $s0, -4($fp)                  # cargar ans
    lw $s1, -8($fp)                  # cargar i
    mul $t0, $s0, $s1                # t1 = ans * i
    move $s0, $t0                    # ans = t1
    li $t1, 1
    subu $t2, $s1, $t1               # t2 = i - 1
    move $s1, $t2                    # i = t2
    sw $s0, -4($fp)                  # spill/write-back de var
    sw $s1, -8($fp)                  # spill/write-back de var
    sw $t0, -16($fp)                 # spill/write-back de temp
    sw $t2, -20($fp)                 # spill/write-back de temp
    j L0_while
L1_endwhile:
    lw $s0, -4($fp)                  # cargar ans
    move $a0, $s0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    move $v0, $s0                    # valor de retorno en $v0
    j __func_factorial_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_factorial_epilogue
__func_factorial_epilogue:
        lw $s0, -24($fp)             # restaurar $s0
        lw $s1, -28($fp)             # restaurar $s1
        lw $s2, -32($fp)             # restaurar $s2
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

