"""Casos limite ejecutados en SPIM.

Programas que combinan caracteristicas de formas no triviales:
hoisting, recursion mutua, try/catch anidado, encadenamientos de
objetos, interaccion switch/ciclos, y semantica de division con
negativos. Complementan a test_execution.py como red de regresion.
"""

from conftest import run_source


def test_global_inicializada_con_llamada_adelantada(tmp_path):
    """Las funciones se pre-registran (hoisting): una global puede
    inicializarse llamando a una funcion declarada mas abajo."""
    out = run_source('''
let x: integer = doble(21);
print(x);
function doble(n: integer): integer { return n * 2; }
''', tmp_path)
    assert out == ['42']


def test_funciones_anidadas_con_hoisting_local(tmp_path):
    """Funciones anidadas pueden llamarse entre si (sin captura de locales)."""
    out = run_source('''
function externa(): integer {
  function a(): integer { return b() + 1; }
  function b(): integer { return 10; }
  return a();
}
print(externa());
''', tmp_path)
    assert out == ['11']


def test_while_true_con_break(tmp_path):
    out = run_source('''
let i: integer = 0;
while (true) {
  i = i + 1;
  if (i == 3) { break; }
}
print(i);
''', tmp_path)
    assert out == ['3']


def test_try_catch_anidado(tmp_path):
    """Un error dentro del catch interno lo captura el try externo."""
    out = run_source('''
let a: integer[] = [1];
try {
  try {
    print(a[9]);
  } catch (e1) {
    print("interno: " + e1);
    print(a[8]);
  }
} catch (e2) {
  print("externo: " + e2);
}
print("fin");
''', tmp_path)
    assert out == ['interno: indice fuera de rango',
                   'externo: indice fuera de rango', 'fin']


def test_encadenamiento_campo_metodo(tmp_path):
    """obj.campo.metodo(): un campo de tipo clase se puede encadenar."""
    out = run_source('''
class Motor {
  let potencia: integer;
  function constructor(p: integer) { this.potencia = p; }
  function describir(): string { return "motor de " + this.potencia; }
}
class Carro {
  let motor: Motor;
  function constructor(p: integer) { this.motor = new Motor(p); }
}
let c: Carro = new Carro(300);
print(c.motor.describir());
print(c.motor.potencia);
''', tmp_path)
    assert out == ['motor de 300', '300']


def test_metodo_llamando_metodos_via_this(tmp_path):
    out = run_source('''
class Contador {
  let valor: integer;
  function constructor() { this.valor = 0; }
  function incrementar() { this.valor = this.valor + 1; }
  function doble(): integer { return this.valor * 2; }
  function incrementarYDoblar(): integer {
    this.incrementar();
    return this.doble();
  }
}
let c: Contador = new Contador();
c.incrementar();
c.incrementar();
print(c.incrementarYDoblar());
print(c.valor);
''', tmp_path)
    assert out == ['6', '3']


def test_arreglo_de_strings_con_foreach(tmp_path):
    out = run_source('''
let nombres: string[] = ["ana", "beto"];
foreach (n in nombres) { print("hola " + n); }
''', tmp_path)
    assert out == ['hola ana', 'hola beto']


def test_break_de_switch_no_rompe_el_ciclo(tmp_path):
    """Dentro de un ciclo, el break de un switch sale del switch pero
    el ciclo continua."""
    out = run_source('''
for (let i: integer = 0; i < 3; i = i + 1) {
  switch (i) {
    case 0:
      print("cero");
      break;
    case 1:
      print("uno");
      break;
    default:
      print("otro");
  }
}
print("termina");
''', tmp_path)
    assert out == ['cero', 'uno', 'otro', 'termina']


def test_division_y_modulo_con_negativos(tmp_path):
    """MIPS trunca hacia cero: -7/2 = -3 y -7%2 = -1."""
    out = run_source('''
print((0 - 7) / 2);
print((0 - 7) % 2);
''', tmp_path)
    assert out == ['-3', '-1']


def test_recursion_mutua(tmp_path):
    out = run_source('''
function esPar(n: integer): boolean {
  if (n == 0) { return true; }
  return esImpar(n - 1);
}
function esImpar(n: integer): boolean {
  if (n == 0) { return false; }
  return esPar(n - 1);
}
print(esPar(10));
print(esImpar(7));
''', tmp_path)
    assert out == ['true', 'true']


def test_subtipado_pasar_subclase_como_parametro(tmp_path):
    """Un Perro es asignable a un parametro de tipo Animal."""
    out = run_source('''
class Animal {
  let nombre: string;
  function constructor(n: string) { this.nombre = n; }
}
class Perro : Animal { }
function saluda(a: Animal): string { return "hola " + a.nombre; }
let p: Perro = new Perro("Rex");
print(saluda(p));
''', tmp_path)
    assert out == ['hola Rex']


def test_do_while_con_continue(tmp_path):
    """continue en do-while salta a la evaluacion de la condicion."""
    out = run_source('''
let i: integer = 0;
do {
  i = i + 1;
  if (i == 2) { continue; }
  print(i);
} while (i < 4);
''', tmp_path)
    assert out == ['1', '3', '4']


def test_llamada_en_condicion_de_if(tmp_path):
    out = run_source('''
function mayor(a: integer, b: integer): integer {
  return a > b ? a : b;
}
if (mayor(3, 8) == 8) { print("bien"); }
''', tmp_path)
    assert out == ['bien']
