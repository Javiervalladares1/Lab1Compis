// while
let i: integer = 0;
while (i < 3) {
  print("while " + i);
  i = i + 1;
}

// do-while
do {
  print("do " + i);
  i = i - 1;
} while (i > 1);

// for con break y continue
for (let j: integer = 0; j < 10; j = j + 1) {
  if (j == 2) { continue; }
  if (j == 5) { break; }
  print("for " + j);
}

// foreach sobre arreglo
let notas: integer[] = [90, 61, 100, 45];
foreach (n in notas) {
  if (n < 60) { continue; }
  print("nota " + n);
}

// switch con fallthrough y break
let opcion: integer = 2;
switch (opcion) {
  case 1:
    print("uno");
    break;
  case 2:
    print("dos");
  case 3:
    print("tres (fallthrough)");
    break;
  default:
    print("otro");
}

// ternario y logicos con corto circuito
let a: integer = 7;
let par: boolean = a % 2 == 0;
print(par ? "par" : "impar");
print(a > 5 && a < 10);
print(a < 5 || a == 7);
print(!(a == 7));
