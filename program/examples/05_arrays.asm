.data
    S0: .asciiz "primera: "
    S1: .asciiz "longitud: "
    S2: .asciiz "modificada: "
    S3: .asciiz "matriz[1][0] = "
    S4: .asciiz "matriz[0][1] = "
    S5: .asciiz "suma = "
    S6: .asciiz "no deberia imprimirse"
    S7: .asciiz "capturado: "
    S8: .asciiz "el programa continua"
    S9: .asciiz "esto no debe imprimirse"
    g_notas: .word 0                 # global notas: integer[]
    g_matriz: .word 0                # global matriz: integer[][]
    g_suma: .word 0                  # global suma: integer
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
        addiu $sp, $sp, -156         # reservar frame (156 bytes)
        sw $s0, -152($fp)            # callee-saved $s0
        sw $s1, -156($fp)            # callee-saved $s1
    li $a0, 16                       # arreglo de 3
    li $v0, 9                        # sbrk
    syscall
    li $a1, 3
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t0 = nuevo arreglo
    li $t1, 0
    li $t2, 90
    sw $t0, -4($fp)                  # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[0] = 90
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 1
    li $t2, 85
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[1] = 85
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 2
    li $t2, 100
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[2] = 100
    lw $t0, -4($fp)                  # cargar t0
    move $s0, $t0                    # notas = t0
    li $t1, 0
    sw $s0, g_notas                  # spill/write-back de var
    move $a0, $t1
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t1 = notas[0]
    move $a0, $t0
    jal __itos                       # t2 = itos t1
    move $t1, $v0
    la $t2, S0
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t3 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_notas                  # cargar notas
    lw $t2, 0($s0)                   # t4 = len notas
    move $a0, $t2
    jal __itos                       # t5 = itos t4
    move $t4, $v0
    la $t5, S1
    move $a0, $t5
    move $a1, $t4
    jal __concat                     # t6 = concat
    move $t6, $v0
    move $a0, $t6
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t5, 1
    li $t7, 86
    sw $t0, -8($fp)                  # spill/write-back de temp
    sw $t1, -12($fp)                 # spill/write-back de temp
    sw $t2, -20($fp)                 # spill/write-back de temp
    sw $t3, -16($fp)                 # spill/write-back de temp
    sw $t4, -24($fp)                 # spill/write-back de temp
    sw $t6, -28($fp)                 # spill/write-back de temp
    move $a0, $t5
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t7, 4($a2)                   # notas[1] = 86
    lw $s0, g_notas                  # cargar notas
    li $t0, 1
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t7 = notas[1]
    move $a0, $t0
    jal __itos                       # t8 = itos t7
    move $t1, $v0
    la $t2, S2
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t9 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t2, $v0                    # t10 = nuevo arreglo
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t4, $v0                    # t11 = nuevo arreglo
    li $t5, 0
    li $t6, 1
    sw $t0, -32($fp)                 # spill/write-back de temp
    sw $t1, -36($fp)                 # spill/write-back de temp
    sw $t2, -44($fp)                 # spill/write-back de temp
    sw $t3, -40($fp)                 # spill/write-back de temp
    sw $t4, -48($fp)                 # spill/write-back de temp
    move $a0, $t5
    move $a1, $t4
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t6, 4($a2)                   # t11[0] = 1
    lw $t0, -48($fp)                 # cargar t11
    li $t1, 1
    li $t2, 2
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t11[1] = 2
    lw $t0, -44($fp)                 # cargar t10
    li $t1, 0
    lw $t2, -48($fp)                 # cargar t11
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t10[0] = t11
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t12 = nuevo arreglo
    li $t1, 0
    li $t2, 3
    sw $t0, -52($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t12[0] = 3
    lw $t0, -52($fp)                 # cargar t12
    li $t1, 1
    li $t2, 4
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t12[1] = 4
    lw $t0, -44($fp)                 # cargar t10
    li $t1, 1
    lw $t2, -52($fp)                 # cargar t12
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t10[1] = t12
    lw $t0, -44($fp)                 # cargar t10
    move $s0, $t0                    # matriz = t10
    li $t1, 1
    sw $s0, g_matriz                 # spill/write-back de var
    move $a0, $t1
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t13 = matriz[1]
    li $t1, 0
    sw $t0, -56($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t14 = t13[0]
    move $a0, $t0
    jal __itos                       # t15 = itos t14
    move $t1, $v0
    la $t2, S3
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t16 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_matriz                 # cargar matriz
    li $t2, 0
    sw $t0, -60($fp)                 # spill/write-back de temp
    sw $t1, -64($fp)                 # spill/write-back de temp
    sw $t3, -68($fp)                 # spill/write-back de temp
    move $a0, $t2
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t17 = matriz[0]
    li $t1, 1
    li $t2, 20
    sw $t0, -72($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t17[1] = 20
    lw $s0, g_matriz                 # cargar matriz
    li $t0, 0
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t18 = matriz[0]
    li $t1, 1
    sw $t0, -76($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t19 = t18[1]
    move $a0, $t0
    jal __itos                       # t20 = itos t19
    move $t1, $v0
    la $t2, S4
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t21 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t2, 0
    move $s0, $t2                    # suma = 0
    lw $s1, g_notas                  # cargar notas
    lw $t2, 0($s1)                   # t22 = len notas
    li $t4, 0
    move $t5, $t4                    # t23 = 0
    sw $s0, g_suma                   # spill/write-back de var
    sw $t0, -80($fp)                 # spill/write-back de temp
    sw $t1, -84($fp)                 # spill/write-back de temp
    sw $t2, -92($fp)                 # spill/write-back de temp
    sw $t3, -88($fp)                 # spill/write-back de temp
    sw $t5, -96($fp)                 # spill/write-back de temp
L0_foreach:
    lw $t0, -96($fp)                 # cargar t23
    lw $t1, -92($fp)                 # cargar t22
    slt $t2, $t0, $t1                # t24 = t23 < t22
    sw $t2, -100($fp)                # spill/write-back de temp
    beq $t2, $zero, L2_endforeach
    lw $s0, g_notas                  # cargar notas
    lw $t0, -96($fp)                 # cargar t23
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $s0, 4($a2)                   # n = notas[t23]
    lw $s1, g_suma                   # cargar suma
    addu $t0, $s1, $s0               # t25 = suma + n
    move $s1, $t0                    # suma = t25
    sw $s0, -104($fp)                # spill/write-back de var
    sw $s1, g_suma                   # spill/write-back de var
    sw $t0, -108($fp)                # spill/write-back de temp
L1_festep:
    lw $t0, -96($fp)                 # cargar t23
    li $t1, 1
    addu $t0, $t0, $t1               # t23 = t23 + 1
    sw $t0, -96($fp)                 # spill/write-back de temp
    j L0_foreach
L2_endforeach:
    lw $s0, g_suma                   # cargar suma
    move $a0, $s0
    jal __itos                       # t26 = itos suma
    move $t0, $v0
    la $t1, S5
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t27 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -112($fp)                # spill/write-back de temp
    sw $t2, -116($fp)                # spill/write-back de temp
    la $a0, L3_catch
    jal __try_push                   # try -> L3_catch
    lw $s0, g_notas                  # cargar notas
    li $t0, 10
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t28 = notas[10]
    move $s0, $t0                    # peligro = t28
    la $t1, S6
    move $a0, $t1
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s0, -124($fp)                # spill/write-back de var
    sw $t0, -120($fp)                # spill/write-back de temp
    jal __try_pop
    j L4_endtry
L3_catch:
    lw $s0, __err_msg                # mensaje del error capturado
    la $t0, S7
    move $a0, $t0
    move $a1, $s0
    jal __concat                     # t29 = concat
    move $t1, $v0
    move $a0, $t1
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s0, -128($fp)                # spill/write-back de var
    sw $t1, -132($fp)                # spill/write-back de temp
L4_endtry:
    la $a0, L5_catch
    jal __try_push                   # try -> L5_catch
    addiu $sp, $sp, -8               # espacio para 2 argumento(s)
    li $t0, 10
    sw $t0, 0($sp)                   # argumento 0
    li $t0, 0
    sw $t0, 4($sp)                   # argumento 1
    jal func_dividir                 # call func_dividir, 2
    addiu $sp, $sp, 8                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -136($fp)                # spill/write-back de temp
    jal __try_pop
    j L6_endtry
L5_catch:
    lw $s0, __err_msg                # mensaje del error capturado
    la $t0, S7
    move $a0, $t0
    move $a1, $s0
    jal __concat                     # t31 = concat
    move $t1, $v0
    move $a0, $t1
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s0, -140($fp)                # spill/write-back de var
    sw $t1, -144($fp)                # spill/write-back de temp
L6_endtry:
    la $t0, S8
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_notas                  # cargar notas
    li $t0, 99
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t32 = notas[99]
    move $a0, $t0
    li $v0, 1                        # syscall print_int
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    la $t1, S9
    move $a0, $t1
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -148($fp)                # spill/write-back de temp
__main_epilogue:
        lw $s0, -152($fp)            # restaurar $s0
        lw $s1, -156($fp)            # restaurar $s1
        li $v0, 10                   # syscall exit: fin del programa
        syscall

    # ===== funcion dividir =====
func_dividir:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -12          # reservar frame (12 bytes)
        sw $s0, -8($fp)              # callee-saved $s0
        sw $s1, -12($fp)             # callee-saved $s1
    lw $s0, 8($fp)                   # cargar a
    lw $s1, 12($fp)                  # cargar b
    bne $s1, $zero, __aux1_divok     # chequeo division entre cero
    la $a0, __msg_div0
    j __runtime_error
__aux1_divok:
    div $s0, $s1                     # a / b
    mflo $t0                         # t0 = cociente
    sw $t0, -4($fp)                  # spill/write-back de temp
    move $v0, $t0                    # valor de retorno en $v0
    j __func_dividir_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_dividir_epilogue
__func_dividir_epilogue:
        lw $s0, -8($fp)              # restaurar $s0
        lw $s1, -12($fp)             # restaurar $s1
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

