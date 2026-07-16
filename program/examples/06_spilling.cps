// Fuerza el spilling: la expresion mantiene vivos mas de 18 valores a la vez
// (los 10 registros $t + los 8 $s se agotan y getReg debe derramar al stack).
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

// ((a*b) + (c*d) + (e*f) + (g*h) + (i*j) + (a+j)*(b+i) + (c+h)*(d+g) + (e+f)*(f+e))
let r: integer = a*b + c*d + e*f + g*h + i*j
               + (a+j)*(b+i) + (c+h)*(d+g) + (e+f)*(f+e)
               + (a*b*c) + (d*e*f) + (g*h*i)
               + (a+b+c+d+e+f+g+h+i+j) * (j-i+h-g+f-e+d-c+b-a);
print("resultado = " + r);
// verificacion manual:
// 2+12+30+56+90 = 190; 11*11=121; 11*11=121; 11*11=121 -> 553
// 6 + 120 + 504 = 630 -> 1183
// 55 * 5 = 275 -> total 1458
