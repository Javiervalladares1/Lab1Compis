"""Validacion del TAC generado y de la estructura del .asm.

Estos tests NO requieren simulador: verifican la representacion
intermedia y las propiedades estructurales del assembly (secciones,
labels, saltos, registros validos).
"""

from conftest import compile_ok, AsmChecker


# ---- TAC -------------------------------------------------------------------

def test_tac_params_contiguos_en_llamadas_anidadas():
    """Los `param` de una llamada nunca se intercalan con los de otra:
    los argumentos se evaluan por completo antes de emitirlos."""
    r = compile_ok('''
function f(a: integer, b: integer): integer { return a + b; }
function g(x: integer): integer { return x; }
print(f(g(1), g(2)));
''')
    lines = [l.strip() for l in r.tac_text.splitlines()]
    # entre un "param" y su "call" solo puede haber otros "param"
    for i, line in enumerate(lines):
        if line.startswith('param'):
            j = i + 1
            while lines[j].startswith('param'):
                j += 1
            assert 'call' in lines[j], f"param sin call contiguo: {lines[i:j+1]}"


def test_tac_corto_circuito():
    """&& y || generan saltos (corto circuito), no operaciones binarias."""
    r = compile_ok('''
let a: boolean = true;
let b: boolean = false;
let c: boolean = a && b;
let d: boolean = a || b;
''')
    assert 'ifFalse' in r.tac_text, 'falta el salto del corto circuito de &&'
    assert 'if ' in r.tac_text, 'falta el salto del corto circuito de ||'


def test_tac_deteccion_de_recursion():
    """Una funcion recursiva se llama a si misma dentro de su cuerpo."""
    r = compile_ok('''
function fact(n: integer): integer {
  if (n <= 1) { return 1; }
  return n * fact(n - 1);
}
print(fact(5));
''')
    tac = r.tac_text
    body = tac[tac.index('FUNCTION fact'):]
    assert 'call func_fact' in body, 'la recursion no genera call a si misma'


def test_tac_concatenacion_convierte_enteros():
    """'texto' + entero genera itos + concat en el TAC."""
    r = compile_ok('print("x = " + 42);')
    assert 'itos' in r.tac_text
    assert 'concat' in r.tac_text


# ---- estructura del .asm ---------------------------------------------------

def test_asm_estructura_minima():
    """Programa minimo: secciones, main, syscall de salida."""
    r = compile_ok('print(1);')
    AsmChecker(r.mips_text).assert_valid()


def test_asm_estructura_programa_grande():
    """El programa oficial del curso genera .asm estructuralmente valido."""
    import os
    path = os.path.join(os.path.dirname(__file__), '..', 'program.cps')
    with open(path, encoding='utf-8') as f:
        r = compile_ok(f.read())
    AsmChecker(r.mips_text).assert_valid()


def test_asm_strings_en_data():
    """Los literales string quedan como .asciiz en .data."""
    r = compile_ok('print("hola mundo");')
    assert '.asciiz "hola mundo"' in r.mips_text


def test_asm_globales_en_data():
    """Las variables globales tienen etiqueta g_* en .data."""
    r = compile_ok('let contador: integer = 5; print(contador);')
    assert 'g_contador: .word 0' in r.mips_text


def test_asm_prologo_y_epilogo():
    """Toda funcion guarda/restaura $ra y $fp y retorna con jr $ra."""
    r = compile_ok('''
function f(x: integer): integer { return x + 1; }
print(f(1));
''')
    asm = r.mips_text
    assert 'sw $ra, 4($sp)' in asm, 'falta guardar $ra'
    assert 'sw $fp, 0($sp)' in asm, 'falta guardar $fp'
    assert 'move $fp, $sp' in asm, 'falta establecer $fp'
    assert 'jr $ra' in asm, 'falta el retorno jr $ra'
    assert 'jal func_f' in asm, 'falta la llamada jal'


def test_asm_spilling_emitido():
    """Con mas valores vivos que registros, getReg emite spills (sw)."""
    vars_decl = '\n'.join(f'let v{i}: integer = {i};' for i in range(10))
    # expresion gigante: mantiene vivos ~20 valores intermedios
    products = ' + '.join(f'(v{i} + v{(i+1) % 10}) * (v{(i+2) % 10} + v{(i+3) % 10})'
                          for i in range(10))
    r = compile_ok(f'{vars_decl}\nlet total: integer = {products};\nprint(total);')
    assert 'spill/write-back' in r.mips_text, 'no se emitio ningun spill'
    AsmChecker(r.mips_text).assert_valid()


def test_asm_division_con_chequeo():
    """La division emite chequeo de division entre cero."""
    r = compile_ok('let a: integer = 10; print(a / 2);')
    assert '__msg_div0' in r.mips_text
    assert 'mflo' in r.mips_text


def test_asm_modulo_usa_mfhi():
    r = compile_ok('let a: integer = 10; print(a % 3);')
    assert 'mfhi' in r.mips_text


def test_asm_acceso_arreglo_con_bounds_check():
    r = compile_ok('let a: integer[] = [1, 2]; print(a[0]);')
    assert '__bounds_check' in r.mips_text


def test_asm_sin_labels_duplicados_con_muchos_ifs():
    """Muchas estructuras de control no producen labels repetidos."""
    src = '\n'.join(
        f'if ({i} < {i+1}) {{ print({i}); }} else {{ print(0); }}'
        for i in range(30))
    r = compile_ok(src)
    AsmChecker(r.mips_text).assert_valid()
