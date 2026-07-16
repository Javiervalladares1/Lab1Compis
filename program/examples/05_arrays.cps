let notas: integer[] = [90, 85, 100];
print("primera: " + notas[0]);
print("longitud: " + notas.length);
notas[1] = 86;
print("modificada: " + notas[1]);

let matriz: integer[][] = [[1, 2], [3, 4]];
print("matriz[1][0] = " + matriz[1][0]);
matriz[0][1] = 20;
print("matriz[0][1] = " + matriz[0][1]);

let suma: integer = 0;
foreach (n in notas) {
  suma = suma + n;
}
print("suma = " + suma);

// try/catch: indice fuera de rango
try {
  let peligro: integer = notas[10];
  print("no deberia imprimirse");
} catch (err) {
  print("capturado: " + err);
}

// try/catch: division entre cero dentro de una funcion llamada desde el try
function dividir(a: integer, b: integer): integer {
  return a / b;
}
try {
  print(dividir(10, 0));
} catch (err) {
  print("capturado: " + err);
}
print("el programa continua");

// error sin try: aborta con mensaje
print(notas[99]);
print("esto no debe imprimirse");
