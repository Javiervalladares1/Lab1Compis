"""Casos EXITOSOS ejecutados de verdad en el simulador SPIM.

Cada test compila un programa Compiscript, lo corre en spim y compara
la salida exacta. Si spim no esta instalado, estos tests se saltan
(la validacion estructural de test_tac_and_asm.py corre siempre).
"""

from conftest import run_source


def test_programa_minimo(tmp_path):
    """El programa mas pequeno posible termina sin imprimir nada."""
    assert run_source('', tmp_path) == []


def test_print_entero(tmp_path):
    assert run_source('print(42);', tmp_path) == ['42']


def test_print_string(tmp_path):
    assert run_source('print("hola mundo");', tmp_path) == ['hola mundo']


def test_print_booleanos(tmp_path):
    out = run_source('print(true); print(false);', tmp_path)
    assert out == ['true', 'false']


def test_print_entero_negativo(tmp_path):
    out = run_source('print(-7); print(0 - 15); print(0);', tmp_path)
    assert out == ['-7', '-15', '0']


def test_declaracion_y_asignacion(tmp_path):
    out = run_source('''
let x: integer = 10;
var y: integer;
y = x;
x = 99;
print(x);
print(y);
const Z: integer = 5;
print(Z);
''', tmp_path)
    assert out == ['99', '10', '5']


def test_aritmetica_y_precedencia(tmp_path):
    """* y / atan mas fuerte que + y -; parentesis agrupan."""
    out = run_source('''
print(2 + 3 * 4);
print((2 + 3) * 4);
print(20 - 6 / 2);
print(7 % 3);
print(-(3 + 4));
''', tmp_path)
    assert out == ['14', '20', '17', '1', '-7']


def test_comparaciones(tmp_path):
    out = run_source('''
print(3 < 5);
print(5 <= 5);
print(3 > 5);
print(5 >= 6);
print(4 == 4);
print(4 != 4);
''', tmp_path)
    assert out == ['true', 'true', 'false', 'false', 'true', 'false']


def test_logicos_y_corto_circuito(tmp_path):
    """El corto circuito NO evalua el lado derecho: la funcion con
    efecto (print) no debe ejecutarse."""
    out = run_source('''
function efecto(): boolean {
  print("efecto ejecutado");
  return true;
}
print(false && efecto());
print(true || efecto());
print(!true);
''', tmp_path)
    assert out == ['false', 'true', 'false']


def test_if_else(tmp_path):
    out = run_source('''
let x: integer = 10;
if (x > 5) { print("mayor"); } else { print("menor"); }
if (x < 5) { print("si"); } else { print("no"); }
if (x == 10) { print("exacto"); }
''', tmp_path)
    assert out == ['mayor', 'no', 'exacto']


def test_while(tmp_path):
    out = run_source('''
let i: integer = 0;
while (i < 3) { print(i); i = i + 1; }
''', tmp_path)
    assert out == ['0', '1', '2']


def test_do_while(tmp_path):
    """do-while ejecuta el cuerpo al menos una vez."""
    out = run_source('''
let i: integer = 5;
do { print(i); i = i + 1; } while (i < 3);
''', tmp_path)
    assert out == ['5']


def test_for_con_break_y_continue(tmp_path):
    out = run_source('''
for (let i: integer = 0; i < 10; i = i + 1) {
  if (i == 1) { continue; }
  if (i == 4) { break; }
  print(i);
}
''', tmp_path)
    assert out == ['0', '2', '3']


def test_funcion_sin_parametros(tmp_path):
    out = run_source('''
function saluda(): string { return "hola"; }
print(saluda());
''', tmp_path)
    assert out == ['hola']


def test_funcion_con_parametros(tmp_path):
    out = run_source('''
function resta(a: integer, b: integer): integer { return a - b; }
print(resta(10, 4));
print(resta(4, 10));
''', tmp_path)
    assert out == ['6', '-6']


def test_funcion_void_y_return_temprano(tmp_path):
    out = run_source('''
function clasifica(n: integer) {
  if (n < 0) { print("negativo"); return; }
  print("no negativo");
}
clasifica(0 - 3);
clasifica(3);
''', tmp_path)
    assert out == ['negativo', 'no negativo']


def test_llamadas_anidadas(tmp_path):
    """f(g(x), h(y)): los argumentos con llamadas no se pisan entre si."""
    out = run_source('''
function doble(x: integer): integer { return x * 2; }
function triple(x: integer): integer { return x * 3; }
function suma(a: integer, b: integer): integer { return a + b; }
print(suma(doble(5), triple(10)));
print(doble(doble(doble(2))));
''', tmp_path)
    assert out == ['40', '16']


def test_recursion(tmp_path):
    out = run_source('''
function factorial(n: integer): integer {
  if (n <= 1) { return 1; }
  return n * factorial(n - 1);
}
function fib(n: integer): integer {
  if (n <= 1) { return n; }
  return fib(n - 1) + fib(n - 2);
}
print(factorial(7));
print(fib(12));
''', tmp_path)
    assert out == ['5040', '144']


def test_muchos_temporales_fuerza_getreg(tmp_path):
    """Expresion con decenas de valores vivos: getReg debe derramar y
    restaurar sin corromper ningun valor (resultado verificado a mano)."""
    out = run_source('''
let a: integer = 1;
let b: integer = 2;
let c: integer = 3;
let d: integer = 4;
let e: integer = 5;
let f: integer = 6;
let g: integer = 7;
let h: integer = 8;
let i: integer = 9;
let j: integer = 10;
let r: integer = a*b + c*d + e*f + g*h + i*j
               + (a+j)*(b+i) + (c+h)*(d+g) + (e+f)*(f+e)
               + (a*b*c) + (d*e*f) + (g*h*i)
               + (a+b+c+d+e+f+g+h+i+j) * (j-i+h-g+f-e+d-c+b-a);
print(r);
''', tmp_path)
    assert out == ['1458']


def test_concatenacion_strings(tmp_path):
    out = run_source('''
let nombre: string = "mundo";
print("hola " + nombre);
print("n = " + 42);
print("b = " + true);
print(1 + 2 + " y " + 3 + 4);
''', tmp_path)
    # "1 + 2" se evalua como entero (3) antes de tocar el string
    assert out == ['hola mundo', 'n = 42', 'b = true', '3 y 34']


def test_arreglos(tmp_path):
    out = run_source('''
let a: integer[] = [10, 20, 30];
print(a[0]);
print(a[2]);
a[1] = 99;
print(a[1]);
print(a.length);
let m: integer[][] = [[1, 2], [3, 4]];
print(m[1][1]);
''', tmp_path)
    assert out == ['10', '30', '99', '3', '4']


def test_foreach(tmp_path):
    out = run_source('''
let datos: integer[] = [5, 10, 15];
let suma: integer = 0;
foreach (d in datos) {
  suma = suma + d;
  print(d);
}
print("suma " + suma);
''', tmp_path)
    assert out == ['5', '10', '15', 'suma 30']


def test_switch(tmp_path):
    """case con break sale; sin break hay fallthrough (documentado)."""
    out = run_source('''
let x: integer = 1;
switch (x) {
  case 1:
    print("uno");
    break;
  case 2:
    print("dos");
  default:
    print("defecto");
}
switch (x + 1) {
  case 2:
    print("dos");
  default:
    print("cae al default");
}
''', tmp_path)
    assert out == ['uno', 'dos', 'cae al default']


def test_ternario(tmp_path):
    out = run_source('''
let edad: integer = 20;
print(edad >= 18 ? "adulto" : "menor");
print(edad < 18 ? "menor" : "adulto");
''', tmp_path)
    assert out == ['adulto', 'adulto']


def test_try_catch_indice(tmp_path):
    out = run_source('''
let a: integer[] = [1, 2, 3];
try {
  print(a[10]);
  print("no llega");
} catch (err) {
  print("error: " + err);
}
print("continua");
''', tmp_path)
    assert out == ['error: indice fuera de rango', 'continua']


def test_try_catch_division_en_funcion(tmp_path):
    """El error ocurre DENTRO de una funcion llamada desde el try: el
    unwinding debe restaurar $sp/$fp y saltar al catch del llamador."""
    out = run_source('''
function dividir(a: integer, b: integer): integer { return a / b; }
try {
  print(dividir(10, 0));
} catch (err) {
  print("capturado: " + err);
}
print("vivo");
''', tmp_path)
    assert out == ['capturado: division entre cero', 'vivo']


def test_error_runtime_sin_catch_aborta(tmp_path):
    """Sin try/catch el programa imprime el error y termina."""
    out = run_source('''
let a: integer[] = [1];
print("antes");
print(a[5]);
print("nunca");
''', tmp_path)
    assert out == ['antes', 'Runtime error: indice fuera de rango']


def test_clases_herencia_this(tmp_path):
    out = run_source('''
class Animal {
  let nombre: string;
  function constructor(nombre: string) { this.nombre = nombre; }
  function hablar(): string { return this.nombre + " hace ruido"; }
}
class Perro : Animal {
  function hablar(): string { return this.nombre + " ladra"; }
}
let a: Animal = new Animal("Gato");
let p: Perro = new Perro("Rex");
print(a.hablar());
print(p.hablar());
p.nombre = "Toby";
print(p.nombre);
''', tmp_path)
    assert out == ['Gato hace ruido', 'Rex ladra', 'Toby']


def test_ambitos_de_bloque(tmp_path):
    """Una variable de bloque interno sombrea a la externa sin destruirla."""
    out = run_source('''
let x: integer = 1;
{
  let x: integer = 2;
  print(x);
}
print(x);
''', tmp_path)
    assert out == ['2', '1']


def test_programa_oficial_del_curso(tmp_path):
    """El program.cps oficial del curso corre completo con la salida
    esperada (validacion de integracion de todas las fases)."""
    import os
    path = os.path.join(os.path.dirname(__file__), '..', 'program.cps')
    with open(path, encoding='utf-8') as f:
        out = run_source(f.read(), tmp_path)
    assert out == [
        '5 + 1 = 6',
        'Greater than 5',
        'Result is now 10',
        'Result is now 9',
        'Result is now 8',
        'Loop index: 0',
        'Loop index: 1',
        'Loop index: 2',
        'Number: 1',
        'Number: 2',
        'Number: 4',
        'Number: 5',
        "It's seven",
        "It's six",
        'Something else',
        'Caught an error: indice fuera de rango',
        'Rex barks.',
        'First number: 1',
        'Multiples of 2: 2, 4',
        'Program finished.',
    ]
