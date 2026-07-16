.data
    S0: .asciiz "Hello, Compiscript!"
    S1: .asciiz "5 + 1 = "
    S2: .asciiz "Greater than 5"
    S3: .asciiz "5 or less"
    S4: .asciiz "Result is now "
    S5: .asciiz "Loop index: "
    S6: .asciiz "Number: "
    S7: .asciiz "It's seven"
    S8: .asciiz "It's six"
    S9: .asciiz "Something else"
    S10: .asciiz "Risky access: "
    S11: .asciiz "Caught an error: "
    S12: .asciiz " makes a sound."
    S13: .asciiz " barks."
    S14: .asciiz "Rex"
    S15: .asciiz "First number: "
    S16: .asciiz "Multiples of 2: "
    S17: .asciiz ", "
    S18: .asciiz "Program finished."
    g_PI: .word 0                    # global PI: integer
    g_greeting: .word 0              # global greeting: string
    g_flag: .word 0                  # global flag: boolean
    g_numbers: .word 0               # global numbers: integer[]
    g_matrix: .word 0                # global matrix: integer[][]
    g_addFive: .word 0               # global addFive: integer
    g_dog: .word 0                   # global dog: Dog
    g_first: .word 0                 # global first: integer
    g_multiples: .word 0             # global multiples: integer[]
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
        addiu $sp, $sp, -208         # reservar frame (208 bytes)
        sw $s0, -200($fp)            # callee-saved $s0
        sw $s1, -204($fp)            # callee-saved $s1
        sw $s2, -208($fp)            # callee-saved $s2
    li $t0, 314
    move $s0, $t0                    # PI = 314
    la $t0, S0
    move $s1, $t0                    # greeting = S0
    li $t0, 0
    move $s2, $t0                    # flag = 0
    li $a0, 24                       # arreglo de 5
    li $v0, 9                        # sbrk
    syscall
    li $a1, 5
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t0 = nuevo arreglo
    li $t1, 0
    li $t2, 1
    sw $s0, g_PI                     # spill/write-back de var
    sw $s1, g_greeting               # spill/write-back de var
    sw $s2, g_flag                   # spill/write-back de var
    sw $t0, -4($fp)                  # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[0] = 1
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 1
    li $t2, 2
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[1] = 2
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 2
    li $t2, 3
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[2] = 3
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 3
    li $t2, 4
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[3] = 4
    lw $t0, -4($fp)                  # cargar t0
    li $t1, 4
    li $t2, 5
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[4] = 5
    lw $t0, -4($fp)                  # cargar t0
    move $s0, $t0                    # numbers = t0
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t1, $v0                    # t1 = nuevo arreglo
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t2, $v0                    # t2 = nuevo arreglo
    li $t3, 0
    li $t4, 1
    sw $s0, g_numbers                # spill/write-back de var
    sw $t1, -8($fp)                  # spill/write-back de temp
    sw $t2, -12($fp)                 # spill/write-back de temp
    move $a0, $t3
    move $a1, $t2
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t4, 4($a2)                   # t2[0] = 1
    lw $t0, -12($fp)                 # cargar t2
    li $t1, 1
    li $t2, 2
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t2[1] = 2
    lw $t0, -8($fp)                  # cargar t1
    li $t1, 0
    lw $t2, -12($fp)                 # cargar t2
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t1[0] = t2
    li $a0, 12                       # arreglo de 2
    li $v0, 9                        # sbrk
    syscall
    li $a1, 2
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t3 = nuevo arreglo
    li $t1, 0
    li $t2, 3
    sw $t0, -16($fp)                 # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t3[0] = 3
    lw $t0, -16($fp)                 # cargar t3
    li $t1, 1
    li $t2, 4
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t3[1] = 4
    lw $t0, -8($fp)                  # cargar t1
    li $t1, 1
    lw $t2, -16($fp)                 # cargar t3
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t1[1] = t3
    lw $t0, -8($fp)                  # cargar t1
    move $s0, $t0                    # matrix = t1
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t1, 5
    sw $t1, 0($sp)                   # argumento 0
    sw $s0, g_matrix                 # spill/write-back de var
    jal func_makeAdder               # call func_makeAdder, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $s0, $t0                    # addFive = t4
    move $a0, $s0
    jal __itos                       # t5 = itos addFive
    move $t1, $v0
    la $t2, S1
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t6 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t2, 5
    slt $t4, $t2, $s0                # t7 = addFive > 5
    sw $s0, g_addFive                # spill/write-back de var
    sw $t0, -20($fp)                 # spill/write-back de temp
    sw $t1, -24($fp)                 # spill/write-back de temp
    sw $t3, -28($fp)                 # spill/write-back de temp
    sw $t4, -32($fp)                 # spill/write-back de temp
    beq $t4, $zero, L0_else
    la $t0, S2
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    j L1_endif
L0_else:
    la $t0, S3
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L1_endif:
L2_while:
    lw $s0, g_addFive                # cargar addFive
    li $t0, 10
    slt $t1, $s0, $t0                # t8 = addFive < 10
    sw $t1, -36($fp)                 # spill/write-back de temp
    beq $t1, $zero, L3_endwhile
    lw $s0, g_addFive                # cargar addFive
    li $t0, 1
    addu $t1, $s0, $t0               # t9 = addFive + 1
    move $s0, $t1                    # addFive = t9
    sw $s0, g_addFive                # spill/write-back de var
    sw $t1, -40($fp)                 # spill/write-back de temp
    j L2_while
L3_endwhile:
L4_do:
    lw $s0, g_addFive                # cargar addFive
    move $a0, $s0
    jal __itos                       # t10 = itos addFive
    move $t0, $v0
    la $t1, S4
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t11 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t1, 1
    subu $t3, $s0, $t1               # t12 = addFive - 1
    move $s0, $t3                    # addFive = t12
    sw $s0, g_addFive                # spill/write-back de var
    sw $t0, -44($fp)                 # spill/write-back de temp
    sw $t2, -48($fp)                 # spill/write-back de temp
    sw $t3, -52($fp)                 # spill/write-back de temp
L5_docond:
    lw $s0, g_addFive                # cargar addFive
    li $t0, 7
    slt $t1, $t0, $s0                # t13 = addFive > 7
    sw $t1, -56($fp)                 # spill/write-back de temp
    bne $t1, $zero, L4_do
L6_enddo:
    li $t0, 0
    move $s0, $t0                    # i = 0
    sw $s0, -60($fp)                 # spill/write-back de var
L7_for:
    lw $s0, -60($fp)                 # cargar i
    li $t0, 3
    slt $t1, $s0, $t0                # t14 = i < 3
    sw $t1, -64($fp)                 # spill/write-back de temp
    beq $t1, $zero, L9_endfor
    lw $s0, -60($fp)                 # cargar i
    move $a0, $s0
    jal __itos                       # t15 = itos i
    move $t0, $v0
    la $t1, S5
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t16 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -68($fp)                 # spill/write-back de temp
    sw $t2, -72($fp)                 # spill/write-back de temp
L8_forstep:
    lw $s0, -60($fp)                 # cargar i
    li $t0, 1
    addu $t1, $s0, $t0               # t17 = i + 1
    move $s0, $t1                    # i = t17
    sw $s0, -60($fp)                 # spill/write-back de var
    sw $t1, -76($fp)                 # spill/write-back de temp
    j L7_for
L9_endfor:
    lw $s0, g_numbers                # cargar numbers
    lw $t0, 0($s0)                   # t18 = len numbers
    li $t1, 0
    move $t2, $t1                    # t19 = 0
    sw $t0, -80($fp)                 # spill/write-back de temp
    sw $t2, -84($fp)                 # spill/write-back de temp
L10_foreach:
    lw $t0, -84($fp)                 # cargar t19
    lw $t1, -80($fp)                 # cargar t18
    slt $t2, $t0, $t1                # t20 = t19 < t18
    sw $t2, -88($fp)                 # spill/write-back de temp
    beq $t2, $zero, L12_endforeach
    lw $s0, g_numbers                # cargar numbers
    lw $t0, -84($fp)                 # cargar t19
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $s0, 4($a2)                   # n = numbers[t19]
    li $t0, 3
    subu $t1, $s0, $t0               # t21 = n == 3
    sltiu $t1, $t1, 1
    sw $s0, -92($fp)                 # spill/write-back de var
    sw $t1, -96($fp)                 # spill/write-back de temp
    beq $t1, $zero, L13_endif
    j L11_festep
L13_endif:
    lw $s0, -92($fp)                 # cargar n
    move $a0, $s0
    jal __itos                       # t22 = itos n
    move $t0, $v0
    la $t1, S6
    move $a0, $t1
    move $a1, $t0
    jal __concat                     # t23 = concat
    move $t2, $v0
    move $a0, $t2
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    li $t1, 4
    slt $t3, $t1, $s0                # t24 = n > 4
    sw $t0, -100($fp)                # spill/write-back de temp
    sw $t2, -104($fp)                # spill/write-back de temp
    sw $t3, -108($fp)                # spill/write-back de temp
    beq $t3, $zero, L14_endif
    j L12_endforeach
L14_endif:
L11_festep:
    lw $t0, -84($fp)                 # cargar t19
    li $t1, 1
    addu $t0, $t0, $t1               # t19 = t19 + 1
    sw $t0, -84($fp)                 # spill/write-back de temp
    j L10_foreach
L12_endforeach:
    lw $s0, g_addFive                # cargar addFive
    move $t0, $s0                    # t25 = addFive
    li $t1, 7
    subu $t2, $t0, $t1               # t26 = t25 == 7
    sltiu $t2, $t2, 1
    sw $t0, -112($fp)                # spill/write-back de temp
    sw $t2, -116($fp)                # spill/write-back de temp
    bne $t2, $zero, L15_case0
    lw $t0, -112($fp)                # cargar t25
    li $t1, 6
    subu $t2, $t0, $t1               # t27 = t25 == 6
    sltiu $t2, $t2, 1
    sw $t2, -120($fp)                # spill/write-back de temp
    bne $t2, $zero, L16_case1
    j L17_default
L15_case0:
    la $t0, S7
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L16_case1:
    la $t0, S8
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L17_default:
    la $t0, S9
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
L18_endswitch:
    la $a0, L19_catch
    jal __try_push                   # try -> L19_catch
    lw $s0, g_numbers                # cargar numbers
    li $t0, 10
    move $a0, $t0
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t28 = numbers[10]
    move $s0, $t0                    # risky = t28
    move $a0, $s0
    jal __itos                       # t29 = itos risky
    move $t1, $v0
    la $t2, S10
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t30 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $s0, -128($fp)                # spill/write-back de var
    sw $t0, -124($fp)                # spill/write-back de temp
    sw $t1, -132($fp)                # spill/write-back de temp
    sw $t3, -136($fp)                # spill/write-back de temp
    jal __try_pop
    j L20_endtry
L19_catch:
    lw $s0, __err_msg                # mensaje del error capturado
    la $t0, S11
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
L20_endtry:
    li $a0, 4                        # new Dog
    li $v0, 9                        # sbrk (memoria inicializada en 0)
    syscall
    move $t0, $v0
    addiu $sp, $sp, -8               # espacio para 2 argumento(s)
    sw $t0, 0($sp)                   # argumento 0
    la $t1, S14
    sw $t1, 4($sp)                   # argumento 1
    sw $t0, -148($fp)                # spill/write-back de temp
    jal m_Animal_constructor         # call m_Animal_constructor, 2
    addiu $sp, $sp, 8                # liberar argumentos
    lw $t0, -148($fp)                # cargar t32
    move $s0, $t0                    # dog = t32
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    sw $s0, 0($sp)                   # argumento 0
    sw $s0, g_dog                    # spill/write-back de var
    jal m_Dog_speak                  # call m_Dog_speak, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $a0, $t0
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    lw $s0, g_numbers                # cargar numbers
    li $t1, 0
    sw $t0, -152($fp)                # spill/write-back de temp
    move $a0, $t1
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t34 = numbers[0]
    move $s0, $t0                    # first = t34
    move $a0, $s0
    jal __itos                       # t35 = itos first
    move $t1, $v0
    la $t2, S15
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t36 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    li $t2, 2
    sw $t2, 0($sp)                   # argumento 0
    sw $s0, g_first                  # spill/write-back de var
    sw $t0, -156($fp)                # spill/write-back de temp
    sw $t1, -160($fp)                # spill/write-back de temp
    sw $t3, -164($fp)                # spill/write-back de temp
    jal func_getMultiples            # call func_getMultiples, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    move $s0, $t0                    # multiples = t37
    li $t1, 0
    sw $s0, g_multiples              # spill/write-back de var
    sw $t0, -168($fp)                # spill/write-back de temp
    move $a0, $t1
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t38 = multiples[0]
    move $a0, $t0
    jal __itos                       # t39 = itos t38
    move $t1, $v0
    la $t2, S16
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t40 = concat
    move $t3, $v0
    la $t2, S17
    move $a0, $t3
    move $a1, $t2
    jal __concat                     # t41 = concat
    move $t4, $v0
    lw $s0, g_multiples              # cargar multiples
    li $t2, 1
    sw $t0, -172($fp)                # spill/write-back de temp
    sw $t1, -176($fp)                # spill/write-back de temp
    sw $t3, -180($fp)                # spill/write-back de temp
    sw $t4, -184($fp)                # spill/write-back de temp
    move $a0, $t2
    move $a1, $s0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    lw $t0, 4($a2)                   # t42 = multiples[1]
    move $a0, $t0
    jal __itos                       # t43 = itos t42
    move $t1, $v0
    lw $t2, -184($fp)                # cargar t41
    move $a0, $t2
    move $a1, $t1
    jal __concat                     # t44 = concat
    move $t3, $v0
    move $a0, $t3
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    la $t4, S18
    move $a0, $t4
    li $v0, 4                        # syscall print_string
    syscall
    la $a0, __nl                     # salto de linea
    li $v0, 4
    syscall
    sw $t0, -188($fp)                # spill/write-back de temp
    sw $t1, -192($fp)                # spill/write-back de temp
    sw $t3, -196($fp)                # spill/write-back de temp
__main_epilogue:
        lw $s0, -200($fp)            # restaurar $s0
        lw $s1, -204($fp)            # restaurar $s1
        lw $s2, -208($fp)            # restaurar $s2
        li $v0, 10                   # syscall exit: fin del programa
        syscall

    # ===== funcion makeAdder =====
func_makeAdder:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -8           # reservar frame (8 bytes)
        sw $s0, -8($fp)              # callee-saved $s0
    lw $s0, 8($fp)                   # cargar x
    li $t0, 1
    addu $t1, $s0, $t0               # t0 = x + 1
    sw $t1, -4($fp)                  # spill/write-back de temp
    move $v0, $t1                    # valor de retorno en $v0
    j __func_makeAdder_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_makeAdder_epilogue
__func_makeAdder_epilogue:
        lw $s0, -8($fp)              # restaurar $s0
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion constructor =====
m_Animal_constructor:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -8           # reservar frame (8 bytes)
        sw $s0, -4($fp)              # callee-saved $s0
        sw $s1, -8($fp)              # callee-saved $s1
    lw $s0, 8($fp)                   # cargar this
    lw $s1, 12($fp)                  # cargar name
    sw $s1, 0($s0)                   # this.name = name
    j __m_Animal_constructor_epilogue
__m_Animal_constructor_epilogue:
        lw $s0, -4($fp)              # restaurar $s0
        lw $s1, -8($fp)              # restaurar $s1
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion speak =====
m_Animal_speak:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -12          # reservar frame (12 bytes)
        sw $s0, -12($fp)             # callee-saved $s0
    lw $s0, 8($fp)                   # cargar this
    lw $t0, 0($s0)                   # t0 = this.name
    la $t1, S12
    move $a0, $t0
    move $a1, $t1
    jal __concat                     # t1 = concat
    move $t2, $v0
    sw $t0, -4($fp)                  # spill/write-back de temp
    sw $t2, -8($fp)                  # spill/write-back de temp
    move $v0, $t2                    # valor de retorno en $v0
    j __m_Animal_speak_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __m_Animal_speak_epilogue
__m_Animal_speak_epilogue:
        lw $s0, -12($fp)             # restaurar $s0
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion speak =====
m_Dog_speak:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -12          # reservar frame (12 bytes)
        sw $s0, -12($fp)             # callee-saved $s0
    lw $s0, 8($fp)                   # cargar this
    lw $t0, 0($s0)                   # t0 = this.name
    la $t1, S13
    move $a0, $t0
    move $a1, $t1
    jal __concat                     # t1 = concat
    move $t2, $v0
    sw $t0, -4($fp)                  # spill/write-back de temp
    sw $t2, -8($fp)                  # spill/write-back de temp
    move $v0, $t2                    # valor de retorno en $v0
    j __m_Dog_speak_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __m_Dog_speak_epilogue
__m_Dog_speak_epilogue:
        lw $s0, -12($fp)             # restaurar $s0
        move $sp, $fp                # liberar frame
        lw $fp, 0($sp)               # restaurar $fp del llamador
        lw $ra, 4($sp)               # restaurar direccion de retorno
        addiu $sp, $sp, 8
        jr $ra                       # retorno al llamador

    # ===== funcion getMultiples =====
func_getMultiples:
        addiu $sp, $sp, -8           # prologo: espacio para $ra y $fp
        sw $ra, 4($sp)               # guardar direccion de retorno
        sw $fp, 0($sp)               # guardar $fp del llamador
        move $fp, $sp                # nuevo frame pointer
        addiu $sp, $sp, -32          # reservar frame (32 bytes)
        sw $s0, -32($fp)             # callee-saved $s0
    li $a0, 24                       # arreglo de 5
    li $v0, 9                        # sbrk
    syscall
    li $a1, 5
    sw $a1, 0($v0)                   # guardar longitud en el header
    move $t0, $v0                    # t0 = nuevo arreglo
    lw $s0, 8($fp)                   # cargar n_1
    li $t1, 1
    mul $t2, $s0, $t1                # t1 = n_1 * 1
    li $t1, 0
    sw $t0, -4($fp)                  # spill/write-back de temp
    sw $t2, -8($fp)                  # spill/write-back de temp
    move $a0, $t1
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t2, 4($a2)                   # t0[0] = t1
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 2
    mul $t1, $s0, $t0                # t2 = n_1 * 2
    lw $t0, -4($fp)                  # cargar t0
    li $t2, 1
    sw $t1, -12($fp)                 # spill/write-back de temp
    move $a0, $t2
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t1, 4($a2)                   # t0[1] = t2
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 3
    mul $t1, $s0, $t0                # t3 = n_1 * 3
    lw $t0, -4($fp)                  # cargar t0
    li $t2, 2
    sw $t1, -16($fp)                 # spill/write-back de temp
    move $a0, $t2
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t1, 4($a2)                   # t0[2] = t3
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 4
    mul $t1, $s0, $t0                # t4 = n_1 * 4
    lw $t0, -4($fp)                  # cargar t0
    li $t2, 3
    sw $t1, -20($fp)                 # spill/write-back de temp
    move $a0, $t2
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t1, 4($a2)                   # t0[3] = t4
    lw $s0, 8($fp)                   # cargar n_1
    li $t0, 5
    mul $t1, $s0, $t0                # t5 = n_1 * 5
    lw $t0, -4($fp)                  # cargar t0
    li $t2, 4
    sw $t1, -24($fp)                 # spill/write-back de temp
    move $a0, $t2
    move $a1, $t0
    jal __bounds_check               # valida 0 <= idx < len
    sll $a2, $a0, 2
    addu $a2, $a2, $a1
    sw $t1, 4($a2)                   # t0[4] = t5
    lw $t0, -4($fp)                  # cargar t0
    move $s0, $t0                    # result = t0
    sw $s0, -28($fp)                 # spill/write-back de var
    move $v0, $s0                    # valor de retorno en $v0
    j __func_getMultiples_epilogue
    li $t0, 0
    move $v0, $t0                    # valor de retorno en $v0
    j __func_getMultiples_epilogue
__func_getMultiples_epilogue:
        lw $s0, -32($fp)             # restaurar $s0
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
    lw $s0, 8($fp)                   # cargar n_2
    li $t0, 1
    slt $t1, $t0, $s0                # t0 = n_2 <= 1
    xori $t1, $t1, 1
    sw $t1, -4($fp)                  # spill/write-back de temp
    beq $t1, $zero, L21_endif
    li $t0, 1
    move $v0, $t0                    # valor de retorno en $v0
    j __func_factorial_epilogue
L21_endif:
    lw $s0, 8($fp)                   # cargar n_2
    li $t0, 1
    subu $t1, $s0, $t0               # t1 = n_2 - 1
    addiu $sp, $sp, -4               # espacio para 1 argumento(s)
    sw $t1, 0($sp)                   # argumento 0
    sw $t1, -8($fp)                  # spill/write-back de temp
    jal func_factorial               # call func_factorial, 1
    addiu $sp, $sp, 4                # liberar argumentos
    move $t0, $v0                    # valor de retorno
    lw $s0, 8($fp)                   # cargar n_2
    mul $t1, $s0, $t0                # t3 = n_2 * t2
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

