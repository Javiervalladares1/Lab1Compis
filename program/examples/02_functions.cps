function fib(n: integer): integer {
  if (n <= 1) { return n; }
  return fib(n - 1) + fib(n - 2);
}

function factorial(n: integer): integer {
  if (n <= 1) { return 1; }
  return n * factorial(n - 1);
}

function suma3(a: integer, b: integer, c: integer): integer {
  return a + b + c;
}

print("fib(10) = " + fib(10));
print("factorial(6) = " + factorial(6));
print("suma3 anidada = " + suma3(fib(5), factorial(3), suma3(1, 2, 3)));
