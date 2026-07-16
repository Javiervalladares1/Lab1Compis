.data
    S0: .asciiz "while "
    S1: .asciiz "do "
    S2: .asciiz "for "
    S3: .asciiz "nota "
    S4: .asciiz "uno"
    S5: .asciiz "dos"
    S6: .asciiz "tres (fallthrough)"
    S7: .asciiz "otro"
    S8: .asciiz "par"
    S9: .asciiz "impar"
    g_i: .word 0                     # global i: integer
    g_notas: .word 0                 # global notas: integer[]
    g_opcion: .word 0                # global opcion: integer
    g_a: .word 0                     # global a: integer
    g_par: .word 0                   # global par: boolean
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
        sw $s0, -156($fp)            # callee-saved $s0
    li $t0, 0
    move $s0, $t0                    # i = 0
    sw $s0, g_i                      # spill/write-back de var
L0_while:
    lw $s0, g_i                      # cargar i
    li $t0, 3
    slt $t1, $s0, $t0                # t0 = i < 3
    sw $t1, -4($fp)                  # spill/write-back de temp
    beq $t1, $zero, L1_endwhile
    lw $s0, g_i                      # cargar i
    move $a0, $s0
    jal __itos                       # t1 = itos i
    move $t0, $v0
    la $t1, S0
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t2 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t1, 1
    addu $t3, $s0, $t1               # t3 = i + 1
    move $s0, $t3                    # i = t3
    sw $s0, g_i                      # spill/write-back de var
    sw $t0, -8($fp)                  # spill/write-back de temp
    sw $t2, -12($fp)                 # spill/write-back de temp
    sw $t3, -16($fp)                 # spill/write-back de temp
    j L0_while
L1_endwhile:
L2_do:
    lw $s0, g_i                      # cargar i
    move $a0, $s0
    jal __itos                       # t4 = itos i
    move $t0, $v0
    la $t1, S1
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t5 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t1, 1
    subu $t3, $s0, $t1               # t6 = i - 1
    move $s0, $t3                    # i = t6
    sw $s0, g_i                      # spill/write-back de var
    sw $t0, -20($fp)                 # spill/write-back de temp
    sw $t2, -24($fp)                 # spill/write-back de temp
    sw $t3, -28($fp)                 # spill/write-back de temp
L3_docond:
    lw $s0, g_i                      # cargar i
    li $t0, 1
    slt $t1, $t0, $s0                # t7 = i > 1
    sw $t1, -32($fp)                 # spill/write-back de temp
    bne $t1, $zero, L2_do
L4_enddo:
    li $t0, 0
    move $s0, $t0                    # j = 0
    sw $s0, -36($fp)                 # spill/write-back de var
L5_for:
    lw $s0, -36($fp)                 # cargar j
    li $t0, 10
    slt $t1, $s0, $t0                # t8 = j < 10
    sw $t1, -40($fp)                 # spill/write-back de temp
    beq $t1, $zero, L7_endfor
    lw $s0, -36($fp)                 # cargar j
    li $t0, 2
    subu $t1, $s0, $t0               # t9 = j == 2
    sltiu $t1, $t1, 1
    sw $t1, -44($fp)                 # spill/write-back de temp
    beq $t1, $zero, L8_endif
    j L6_forstep
L8_endif:
    lw $s0, -36($fp)                 # cargar j
    li $t0, 5
    subu $t1, $s0, $t0               # t10 = j == 5
    sltiu $t1, $t1, 1
    sw $t1, -48($fp)                 # spill/write-back de temp
    beq $t1, $zero, L9_endif
    j L7_endfor
L9_endif:
    lw $s0, -36($fp)                 # cargar j
    move $a0, $s0
    jal __itos                       # t11 = itos j
    move $t0, $v0
    la $t1, S2
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t12 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -52($fp)                 # spill/write-back de temp
    sw $t2, -56($fp)                 # spill/write-back de temp
L6_forstep:
    lw $s0, -36($fp)                 # cargar j
    li $t0, 1
    addu $t1, $s0, $t0               # t13 = j + 1
    move $s0, $t1                    # j = t13
    sw $s0, -36($fp)                 # spill/write-back de var
    sw $t1, -60($fp)                 # spill/write-back de temp
    j L5_for
L7_endfor:
    li $a0, 20                       # arreglo de 4
    li $v0, 9                        # sbrk
    syscall
    li $a1, 4
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t14 = nuevo arreglo
    li $t1, 0
    li $t2, 90
    sw $t0, -64($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t14[0] = 90
    lw $t0, -64($fp)                 # cargar t14
    li $t1, 1
    li $t2, 61
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t14[1] = 61
    lw $t0, -64($fp)                 # cargar t14
    li $t1, 2
    li $t2, 100
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t14[2] = 100
    lw $t0, -64($fp)                 # cargar t14
    li $t1, 3
    li $t2, 45
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t14[3] = 45
    lw $t0, -64($fp)                 # cargar t14
    move $s0, $t0                    # notas = t14
    lw $t1, 0($s0)                   # t15 = len notas
    li $t2, 0
    move $t3, $t2                    # t16 = 0
    sw $s0, g_notas                  # spill/write-back de var
    sw $t1, -68($fp)                 # spill/write-back de temp
    sw $t3, -72($fp)                 # spill/write-back de temp
L10_foreach:
    lw $t0, -72($fp)                 # cargar t16
    lw $t1, -68($fp)                 # cargar t15
    slt $t2, $t0, $t1                # t17 = t16 < t15
    sw $t2, -76($fp)                 # spill/write-back de temp
    beq $t2, $zero, L12_endforeach
    lw $s0, g_notas                  # cargar notas
    lw $t0, -72($fp)                 # cargar t16
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $s0, 4($a2)                   # n = notas[t16]
    li $t0, 60
    slt $t1, $s0, $t0                # t18 = n < 60
    sw $s0, -80($fp)                 # spill/write-back de var
    sw $t1, -84($fp)                 # spill/write-back de temp
    beq $t1, $zero, L13_endif
    j L11_festep
L13_endif:
    lw $s0, -80($fp)                 # cargar n
    move $a0, $s0
    jal __itos                       # t19 = itos n
    move $t0, $v0
    la $t1, S3
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t20 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -88($fp)                 # spill/write-back de temp
    sw $t2, -92($fp)                 # spill/write-back de temp
L11_festep:
    lw $t0, -72($fp)                 # cargar t16
    li $t1, 1
    addu $t0, $t0, $t1               # t16 = t16 + 1
    sw $t0, -72($fp)                 # spill/write-back de temp
    j L10_foreach
L12_endforeach:
    li $t0, 2
    move $s0, $t0                    # opcion = 2
    move $t0, $s0                    # t21 = opcion
    li $t1, 1
    subu $t2, $t0, $t1               # t22 = t21 == 1
    sltiu $t2, $t2, 1
    sw $s0, g_opcion                 # spill/write-back de var
    sw $t0, -96($fp)                 # spill/write-back de temp
    sw $t2, -100($fp)                # spill/write-back de temp
    bne $t2, $zero, L14_case0
    lw $t0, -96($fp)                 # cargar t21
    li $t1, 2
    subu $t2, $t0, $t1               # t23 = t21 == 2
    sltiu $t2, $t2, 1
    sw $t2, -104($fp)                # spill/write-back de temp
    bne $t2, $zero, L15_case1
    lw $t0, -96($fp)                 # cargar t21
    li $t1, 3
    subu $t2, $t0, $t1               # t24 = t21 == 3
    sltiu $t2, $t2, 1
    sw $t2, -108($fp)                # spill/write-back de temp
    bne $t2, $zero, L16_case2
    j L17_default
L14_case0:
    la $t0, S4
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    j L18_endswitch
L15_case1:
    la $t0, S5
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L16_case2:
    la $t0, S6
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    j L18_endswitch
L17_default:
    la $t0, S7
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L18_endswitch:
    li $t0, 7
    move $s0, $t0                    # a = 7
    li $t0, 2
    sw $s0, g_a                      # spill/write-back de var
    bne $t0, $zero, __aux1_divok     # chequeo division entre cero
    la $a0, __msg_div0
    j __runtime_error
__aux1_divok:
    div $s0, $t0                     # a / 2
    mfhi $t0                         # t25 = residuo
    li $t1, 0
    subu $t2, $t0, $t1               # t26 = t25 == 0
    sltiu $t2, $t2, 1
    move $s0, $t2                    # par = t26
    sw $s0, g_par                    # spill/write-back de var
    sw $t0, -112($fp)                # spill/write-back de temp
    sw $t2, -116($fp)                # spill/write-back de temp
    beq $s0, $zero, L19_terF
    la $t0, S8
    move $t1, $t0                    # t27 = S8
    sw $t1, -120($fp)                # spill/write-back de temp
    j L20_terEnd
L19_terF:
    la $t0, S9
    move $t1, $t0                    # t27 = S9
    sw $t1, -120($fp)                # spill/write-back de temp
L20_terEnd:
    lw $t0, -120($fp)                # cargar t27
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_a                      # cargar a
    li $t1, 5
    slt $t2, $t1, $s0                # t28 = a > 5
    sw $t2, -124($fp)                # spill/write-back de temp
    beq $t2, $zero, L21_andF
    lw $s0, g_a                      # cargar a
    li $t0, 10
    slt $t1, $s0, $t0                # t30 = a < 10
    move $t0, $t1                    # t29 = t30
    sw $t0, -132($fp)                # spill/write-back de temp
    sw $t1, -128($fp)                # spill/write-back de temp
    j L22_andEnd
L21_andF:
    li $t0, 0
    move $t1, $t0                    # t29 = 0
    sw $t1, -132($fp)                # spill/write-back de temp
L22_andEnd:
    lw $t0, -132($fp)                # cargar t29
    move $a0, $t0
    jal __print_bool
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_a                      # cargar a
    li $t1, 5
    slt $t2, $s0, $t1                # t31 = a < 5
    sw $t2, -136($fp)                # spill/write-back de temp
    bne $t2, $zero, L23_orT
    lw $s0, g_a                      # cargar a
    li $t0, 7
    subu $t1, $s0, $t0               # t33 = a == 7
    sltiu $t1, $t1, 1
    move $t0, $t1                    # t32 = t33
    sw $t0, -144($fp)                # spill/write-back de temp
    sw $t1, -140($fp)                # spill/write-back de temp
    j L24_orEnd
L23_orT:
    li $t0, 1
    move $t1, $t0                    # t32 = 1
    sw $t1, -144($fp)                # spill/write-back de temp
L24_orEnd:
    lw $t0, -144($fp)                # cargar t32
    move $a0, $t0
    jal __print_bool
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_a                      # cargar a
    li $t1, 7
    subu $t2, $s0, $t1               # t34 = a == 7
    sltiu $t2, $t2, 1
    xori $t1, $t2, 1                 # t35 = !t34
    move $a0, $t1
    jal __print_bool
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t1, -152($fp)                # spill/write-back de temp
    sw $t2, -148($fp)                # spill/write-back de temp
__main_epilogue:
        lw $s0, -156($fp)            # restaurar $s0
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

