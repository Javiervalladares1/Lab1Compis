.data
    S0: .asciiz "resultado = "
    g_a: .word 0                     # global a: integer
    g_b: .word 0                     # global b: integer
    g_c: .word 0                     # global c: integer
    g_d: .word 0                     # global d: integer
    g_e: .word 0                     # global e: integer
    g_f: .word 0                     # global f: integer
    g_g: .word 0                     # global g: integer
    g_h: .word 0                     # global h: integer
    g_i: .word 0                     # global i: integer
    g_j: .word 0                     # global j: integer
    g_r: .word 0                     # global r: integer
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
        addiu $sp, $sp, -240         # reservar frame (240 bytes)
        sw $s0, -212($fp)            # callee-saved $s0
        sw $s1, -216($fp)            # callee-saved $s1
        sw $s2, -220($fp)            # callee-saved $s2
        sw $s3, -224($fp)            # callee-saved $s3
        sw $s4, -228($fp)            # callee-saved $s4
        sw $s5, -232($fp)            # callee-saved $s5
        sw $s6, -236($fp)            # callee-saved $s6
        sw $s7, -240($fp)            # callee-saved $s7
    li $t0, 1
    move $s0, $t0                    # a = 1
    li $t0, 2
    move $s1, $t0                    # b = 2
    li $t0, 3
    move $s2, $t0                    # c = 3
    li $t0, 4
    move $s3, $t0                    # d = 4
    li $t0, 5
    move $s4, $t0                    # e = 5
    li $t0, 6
    move $s5, $t0                    # f = 6
    li $t0, 7
    move $s6, $t0                    # g = 7
    li $t0, 8
    move $s7, $t0                    # h = 8
    li $t0, 9
    move $t1, $t0                    # i = 9
    li $t0, 10
    move $t2, $t0                    # j = 10
    mul $t0, $s0, $s1                # t0 = a * b
    mul $t3, $s2, $s3                # t1 = c * d
    addu $t4, $t0, $t3               # t2 = t0 + t1
    mul $t5, $s4, $s5                # t3 = e * f
    addu $t6, $t4, $t5               # t4 = t2 + t3
    mul $t7, $s6, $s7                # t5 = g * h
    addu $t8, $t6, $t7               # t6 = t4 + t5
    mul $t9, $t1, $t2                # t7 = i * j
    sw $s0, g_a                      # spill/write-back de var
    addu $s0, $t8, $t9               # t8 = t6 + t7
    sw $s1, g_b                      # spill/write-back de var
    lw $s1, g_a                      # cargar a
    sw $s2, g_c                      # spill/write-back de var
    addu $s2, $s1, $t2               # t9 = a + j
    sw $s3, g_d                      # spill/write-back de var
    lw $s3, g_b                      # cargar b
    sw $t0, -4($fp)                  # spill/write-back de temp
    addu $t0, $s3, $t1               # t10 = b + i
    sw $t3, -8($fp)                  # spill/write-back de temp
    mul $t3, $s2, $t0                # t11 = t9 * t10
    sw $s4, g_e                      # spill/write-back de var
    addu $s4, $s0, $t3               # t12 = t8 + t11
    sw $s5, g_f                      # spill/write-back de var
    lw $s5, g_c                      # cargar c
    sw $t4, -12($fp)                 # spill/write-back de temp
    addu $t4, $s5, $s7               # t13 = c + h
    sw $t5, -16($fp)                 # spill/write-back de temp
    lw $t5, g_d                      # cargar d
    sw $t6, -20($fp)                 # spill/write-back de temp
    addu $t6, $t5, $s6               # t14 = d + g
    sw $t7, -24($fp)                 # spill/write-back de temp
    mul $t7, $t4, $t6                # t15 = t13 * t14
    sw $t8, -28($fp)                 # spill/write-back de temp
    addu $t8, $s4, $t7               # t16 = t12 + t15
    sw $t9, -32($fp)                 # spill/write-back de temp
    lw $t9, g_e                      # cargar e
    lw $s1, g_f                      # cargar f
    sw $t2, g_j                      # spill/write-back de var
    addu $t2, $t9, $s1               # t17 = e + f
    addu $s3, $s1, $t9               # t18 = f + e
    sw $t1, g_i                      # spill/write-back de var
    mul $t1, $t2, $s3                # t19 = t17 * t18
    sw $s2, -40($fp)                 # spill/write-back de temp
    addu $s2, $t8, $t1               # t20 = t16 + t19
    sw $t0, -44($fp)                 # spill/write-back de temp
    lw $t0, g_a                      # cargar a
    sw $s0, -36($fp)                 # spill/write-back de temp
    lw $s0, g_b                      # cargar b
    sw $t3, -48($fp)                 # spill/write-back de temp
    mul $t3, $t0, $s0                # t21 = a * b
    sw $s7, g_h                      # spill/write-back de var
    mul $s7, $t3, $s5                # t22 = t21 * c
    addu $t5, $s2, $s7               # t23 = t20 + t22
    sw $s6, g_g                      # spill/write-back de var
    lw $s6, g_d                      # cargar d
    sw $t4, -56($fp)                 # spill/write-back de temp
    mul $t4, $s6, $t9                # t24 = d * e
    sw $t6, -60($fp)                 # spill/write-back de temp
    mul $t6, $t4, $s1                # t25 = t24 * f
    sw $s4, -52($fp)                 # spill/write-back de temp
    addu $s4, $t5, $t6               # t26 = t23 + t25
    sw $t7, -64($fp)                 # spill/write-back de temp
    lw $t7, g_g                      # cargar g
    sw $t2, -72($fp)                 # spill/write-back de temp
    lw $t2, g_h                      # cargar h
    sw $s3, -76($fp)                 # spill/write-back de temp
    mul $s3, $t7, $t2                # t27 = g * h
    sw $t8, -68($fp)                 # spill/write-back de temp
    lw $t8, g_i                      # cargar i
    sw $t1, -80($fp)                 # spill/write-back de temp
    mul $t1, $s3, $t8                # t28 = t27 * i
    addu $t0, $s4, $t1               # t29 = t26 + t28
    lw $s0, g_a                      # cargar a
    sw $t3, -88($fp)                 # spill/write-back de temp
    lw $t3, g_b                      # cargar b
    addu $s5, $s0, $t3               # t30 = a + b
    sw $s2, -84($fp)                 # spill/write-back de temp
    lw $s2, g_c                      # cargar c
    sw $s7, -92($fp)                 # spill/write-back de temp
    addu $s7, $s5, $s2               # t31 = t30 + c
    addu $t9, $s7, $s6               # t32 = t31 + d
    sw $t4, -100($fp)                # spill/write-back de temp
    lw $t4, g_e                      # cargar e
    addu $s1, $t9, $t4               # t33 = t32 + e
    sw $t5, -96($fp)                 # spill/write-back de temp
    lw $t5, g_f                      # cargar f
    sw $t6, -104($fp)                # spill/write-back de temp
    addu $t6, $s1, $t5               # t34 = t33 + f
    addu $t2, $t6, $t7               # t35 = t34 + g
    sw $s3, -112($fp)                # spill/write-back de temp
    lw $s3, g_h                      # cargar h
    addu $t8, $t2, $s3               # t36 = t35 + h
    sw $s4, -108($fp)                # spill/write-back de temp
    lw $s4, g_i                      # cargar i
    sw $t1, -116($fp)                # spill/write-back de temp
    addu $t1, $t8, $s4               # t37 = t36 + i
    sw $t0, -120($fp)                # spill/write-back de temp
    lw $t0, g_j                      # cargar j
    addu $s0, $t1, $t0               # t38 = t37 + j
    subu $t3, $t0, $s4               # t39 = j - i
    sw $s5, -124($fp)                # spill/write-back de temp
    addu $s5, $t3, $s3               # t40 = t39 + h
    subu $s2, $s5, $t7               # t41 = t40 - g
    sw $s7, -128($fp)                # spill/write-back de temp
    addu $s7, $s2, $t5               # t42 = t41 + f
    subu $s6, $s7, $t4               # t43 = t42 - e
    sw $t9, -132($fp)                # spill/write-back de temp
    lw $t9, g_d                      # cargar d
    sw $s1, -136($fp)                # spill/write-back de temp
    addu $s1, $s6, $t9               # t44 = t43 + d
    sw $t6, -140($fp)                # spill/write-back de temp
    lw $t6, g_c                      # cargar c
    sw $t2, -144($fp)                # spill/write-back de temp
    subu $t2, $s1, $t6               # t45 = t44 - c
    sw $t8, -148($fp)                # spill/write-back de temp
    lw $t8, g_b                      # cargar b
    sw $t1, -152($fp)                # spill/write-back de temp
    addu $t1, $t2, $t8               # t46 = t45 + b
    sw $s0, -156($fp)                # spill/write-back de temp
    lw $s0, g_a                      # cargar a
    subu $t0, $t1, $s0               # t47 = t46 - a
    lw $s4, -156($fp)                # cargar t38
    sw $t3, -160($fp)                # spill/write-back de temp
    mul $t3, $s4, $t0                # t48 = t38 * t47
    lw $s3, -120($fp)                # cargar t29
    sw $s5, -164($fp)                # spill/write-back de temp
    addu $s5, $s3, $t3               # t49 = t29 + t48
    move $t7, $s5                    # r = t49
    move $a0, $t7
    jal __itos                       # t50 = itos r
    sw $s2, -168($fp)                # spill/write-back de temp
    move $s2, $v0
    la $t5, S0
    move $a0, $t5
    move $a1, $s2
    jal __concat                     # t51 = concat
    sw $s7, -172($fp)                # spill/write-back de temp
    move $s7, $v0
    move $a0, $s7
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s1, -180($fp)                # spill/write-back de temp
    sw $s2, -204($fp)                # spill/write-back de temp
    sw $s5, -200($fp)                # spill/write-back de temp
    sw $s6, -176($fp)                # spill/write-back de temp
    sw $s7, -208($fp)                # spill/write-back de temp
    sw $t0, -192($fp)                # spill/write-back de temp
    sw $t1, -188($fp)                # spill/write-back de temp
    sw $t2, -184($fp)                # spill/write-back de temp
    sw $t3, -196($fp)                # spill/write-back de temp
    sw $t7, g_r                      # spill/write-back de var
__main_epilogue:
        lw $s0, -212($fp)            # restaurar $s0
        lw $s1, -216($fp)            # restaurar $s1
        lw $s2, -220($fp)            # restaurar $s2
        lw $s3, -224($fp)            # restaurar $s3
        lw $s4, -228($fp)            # restaurar $s4
        lw $s5, -232($fp)            # restaurar $s5
        lw $s6, -236($fp)            # restaurar $s6
        lw $s7, -240($fp)            # restaurar $s7
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

