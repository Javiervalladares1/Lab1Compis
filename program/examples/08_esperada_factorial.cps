// Ejemplo 2 del PDF "Ejecucion Esperada del Compilador" (Factorial de
// Decaf), traducido a sintaxis Compiscript: factorial iterativo con
// while, print del resultado y llamada desde el nivel principal.
function factorial(n: integer): integer {
  let ans: integer = 1;
  let i: integer = n;
  while (i > 1) {
    ans = ans * i;
    i = i - 1;
  }
  print(ans);
  return ans;
}

factorial(5);
