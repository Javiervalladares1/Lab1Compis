"""Verificacion contra el PDF "Ejecucion Esperada del Compilador".

El catedratico proporciona dos ejemplos de referencia (originalmente en
Decaf, con su TAC y su MIPS esperados). Estos tests compilan los mismos
programas en sintaxis Compiscript (examples/07 y 08) y validan:

  1. que el TAC tenga la forma esperada (saltos condicionales sobre la
     comparacion, labels de control, llamada a la funcion),
  2. que el MIPS contenga los elementos estructurales que muestra el
     PDF (.text/.globl/main, jal/jr $ra, manejo de $sp, slt, syscalls
     de print y exit, .data con .word 0),
  3. que la ejecucion en SPIM produzca el resultado correcto
     (factorial(5) = 120).
"""

import os

from conftest import compile_ok, run_mips, AsmChecker

EXAMPLES = os.path.join(os.path.dirname(__file__), '..', 'examples')


def _load(name):
    with open(os.path.join(EXAMPLES, name), encoding='utf-8') as f:
        return f.read()


def test_ejemplo1_if_tac_esperado():
    """El TAC del ejemplo if/else replica la forma del PDF:
    comparacion en temporal, salto ifFalse (Ifz), labels y goto."""
    r = compile_ok(_load('07_esperada_if.cps'))
    tac = r.tac_text
    assert 'var1 < var2' in tac          # _t0 = var1 < var2
    assert 'ifFalse' in tac              # Ifz _t0 Goto _L0
    assert 'goto' in tac                 # Goto _L1
    assert 'var3 * var3' in tac          # var3 = var3*var3


def test_ejemplo1_if_mips_y_ejecucion(tmp_path):
    """MIPS del ejemplo 1: slt para la comparacion, lw/sw de globales
    etiquetadas, exit syscall; ejecuta e imprime 0 (enteros inician en 0)."""
    r = compile_ok(_load('07_esperada_if.cps'))
    asm = r.mips_text
    AsmChecker(asm).assert_valid()
    assert 'slt ' in asm
    assert 'g_var1' in asm and 'g_var3' in asm
    assert '.word 0' in asm
    assert run_mips(asm, tmp_path) == ['0']


def test_ejemplo2_factorial_tac_esperado():
    """El TAC del factorial replica la forma del PDF: init de ans/i,
    label de while, comparacion, cuerpo, goto de regreso y return."""
    r = compile_ok(_load('08_esperada_factorial.cps'))
    tac = r.tac_text
    assert 'ans = 1' in tac
    assert 'i = n' in tac
    assert 'i > 1' in tac                # _t0 = 1 < i (misma comparacion)
    assert 'ifFalse' in tac
    assert 'ans * i' in tac
    assert 'i - 1' in tac
    assert 'call func_factorial, 1' in tac   # PushParam/LCall/PopParams
    assert 'return ans' in tac               # Return _t1


def test_ejemplo2_factorial_mips_estructura():
    """MIPS del factorial: todos los elementos que muestra el PDF."""
    r = compile_ok(_load('08_esperada_factorial.cps'))
    asm = r.mips_text
    AsmChecker(asm).assert_valid()
    assert '.globl main' in asm
    assert 'jal func_factorial' in asm       # jal factorial
    assert 'jr $ra' in asm                   # Jump to addr stored in $ra
    assert 'addiu $sp, $sp, -' in asm        # Adjust stack pointer
    assert 'sw $ra' in asm and 'lw $ra' in asm   # Save/Restore reg
    assert 'mul' in asm                      # mult/mflo del PDF
    assert 'li $v0, 1' in asm                # Print call
    assert 'li $v0, 10' in asm               # Exit
    assert 'move $v0' in asm                 # Return en $v0


def test_ejemplo2_factorial_ejecucion(tmp_path):
    """factorial(5) imprime 120, como la ejecucion esperada."""
    r = compile_ok(_load('08_esperada_factorial.cps'))
    assert run_mips(r.mips_text, tmp_path) == ['120']
