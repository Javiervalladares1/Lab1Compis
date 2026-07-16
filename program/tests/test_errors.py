"""Casos FALLIDOS: errores sintacticos y semanticos.

Valida que el compilador rechace programas invalidos con mensajes
claros y NUNCA genere MIPS para ellos.
"""

from compiler import compile_source


def compile_expect_errors(src):
    result = compile_source(src)
    assert not result.success, "el programa invalido compilo sin errores"
    assert result.mips_text is None, "no debe generarse MIPS con errores"
    return result


# ---- errores sintacticos -------------------------------------------------

def test_error_sintactico_parentesis():
    """Parentesis sin cerrar produce error sintactico con linea."""
    r = compile_expect_errors('print("hola";')
    assert r.syntax_errors
    assert 'linea 1' in r.syntax_errors[0]


def test_error_sintactico_statement_incompleto():
    """Declaracion sin punto y coma es rechazada."""
    r = compile_expect_errors('let x: integer = 5\nprint(x);')
    assert r.syntax_errors


def test_error_sintactico_no_genera_semanticos():
    """Con errores sintacticos no se ejecutan las fases siguientes."""
    r = compile_expect_errors('function {}')
    assert r.syntax_errors and not r.semantic_errors


# ---- errores semanticos ---------------------------------------------------

def test_variable_no_declarada():
    r = compile_expect_errors('print(x);')
    assert any('no ha sido declarada' in e for e in r.semantic_errors)


def test_reasignar_constante():
    r = compile_expect_errors('const PI: integer = 314; PI = 3;')
    assert any('constante' in e for e in r.semantic_errors)


def test_tipos_incompatibles_asignacion():
    r = compile_expect_errors('let x: integer = "texto";')
    assert any("'string'" in e for e in r.semantic_errors)


def test_suma_de_booleanos():
    r = compile_expect_errors('let x: integer = 1 + true;')
    assert any('integer' in e for e in r.semantic_errors)


def test_condicion_no_booleana():
    r = compile_expect_errors('if (5) { print(1); }')
    assert any('boolean' in e for e in r.semantic_errors)


def test_break_fuera_de_ciclo():
    r = compile_expect_errors('break;')
    assert any('break' in e for e in r.semantic_errors)


def test_return_fuera_de_funcion():
    r = compile_expect_errors('return 5;')
    assert any('return' in e for e in r.semantic_errors)


def test_aridad_de_funcion():
    r = compile_expect_errors(
        'function f(a: integer): integer { return a; } f(1, 2);')
    assert any('argumento' in e for e in r.semantic_errors)


def test_tipo_de_retorno():
    r = compile_expect_errors(
        'function f(): integer { return "texto"; }')
    assert any('return' in e for e in r.semantic_errors)


def test_clase_inexistente():
    r = compile_expect_errors('let d: Dog = new Dog();')
    assert any('Dog' in e for e in r.semantic_errors)


def test_campo_inexistente():
    r = compile_expect_errors(
        'class A { let x: integer; } let a: A = new A(); print(a.y);')
    assert any("'y'" in e for e in r.semantic_errors)


def test_indice_no_entero():
    r = compile_expect_errors('let a: integer[] = [1]; print(a[true]);')
    assert any('indice' in e for e in r.semantic_errors)


def test_variable_duplicada():
    r = compile_expect_errors('let x: integer = 1; let x: integer = 2;')
    assert any('ya fue declarado' in e for e in r.semantic_errors)


def test_this_fuera_de_clase():
    r = compile_expect_errors('print(this.x);')
    assert any('this' in e for e in r.semantic_errors)


def test_closure_con_captura_documentada():
    """Limitacion documentada: una funcion anidada no puede capturar
    locales de la funcion externa; el error debe explicarlo."""
    r = compile_expect_errors('''
function externa(): integer {
  let local: integer = 1;
  function interna(): integer { return local; }
  return interna();
}
''')
    assert any('closure' in e for e in r.semantic_errors)
