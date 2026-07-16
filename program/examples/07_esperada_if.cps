// Ejemplo 1 del PDF "Ejecucion Esperada del Compilador" (TAC2 de Decaf),
// traducido a sintaxis Compiscript. En Decaf los enteros inician en 0.
let var1: integer;
let var2: integer;
let var3: integer;

if (var1 < var2) {
  var3 = var1;
} else {
  var3 = var2;
}

var3 = var3 * var3;
print(var3);
