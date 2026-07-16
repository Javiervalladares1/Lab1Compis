class Animal {
  let nombre: string;
  let patas: integer;

  function constructor(nombre: string, patas: integer) {
    this.nombre = nombre;
    this.patas = patas;
  }

  function hablar(): string {
    return this.nombre + " hace ruido";
  }

  function describir(): string {
    return this.nombre + " tiene " + this.patas + " patas";
  }
}

class Perro : Animal {
  function hablar(): string {
    return this.nombre + " ladra";
  }
}

let a: Animal = new Animal("Gato", 4);
print(a.hablar());
print(a.describir());

let p: Perro = new Perro("Rex", 4);
print(p.hablar());
print(p.describir());
print("nombre directo: " + p.nombre);

p.nombre = "Toby";
print(p.hablar());
