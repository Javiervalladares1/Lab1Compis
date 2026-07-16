# Compiscript — Compilador completo a MIPS

Video: https://youtu.be/QF9qG9zIWbk

Compilador del lenguaje **Compiscript** (subset inspirado en TypeScript, definido
por el curso Construcción de Compiladores, UVG) que genera **código MIPS
ejecutable** en un simulador educativo (SPIM / QtSPIM / MARS).

```
fuente .cps ──► Lexer/Parser (ANTLR) ──► Análisis semántico ──► TAC ──► MIPS (.asm)
```

## Estructura del proyecto

```
Proyecto Compiscript/
├── Dockerfile                    # entorno oficial del curso (ANTLR + Python)
├── requirements.txt              # antlr4-python3-runtime==4.13.1
├── README.md                     # este documento
├── README_CODEGEN_IMPLEMENTATION.md  # convención de llamadas, stack, getReg
├── README_IDE.md                 # cómo usar el IDE web
└── program/
    ├── Compiscript.g4            # gramática oficial (sin modificaciones)
    ├── Driver.py                 # punto de entrada CLI del compilador
    ├── compiler.py               # orquestador del pipeline completo
    ├── semantic/                 # fase 2: símbolos, ámbitos y tipos
    │   ├── symbols.py            #   VariableSymbol, FunctionSymbol, ClassSymbol, Scope
    │   └── checker.py            #   SemanticChecker (visitor con anotaciones)
    ├── intermediate/             # fase 3: código intermedio
    │   ├── tac.py                #   instrucciones TAC (cuádruplos) y TACProgram
    │   └── tac_generator.py      #   visitor árbol → TAC
    ├── codegen/                  # fase 4: backend MIPS
    │   ├── mips_generator.py     #   traducción TAC → MIPS
    │   ├── register_allocator.py #   getReg(): asignación de $t/$s con spilling
    │   ├── frame.py              #   stack frames y home locations
    │   ├── emitter.py            #   emisión y ensamblado del .asm
    │   └── runtime.py            #   runtime MIPS (strings, errores, try/catch)
    ├── ide/                      # IDE web (sin dependencias externas)
    │   ├── server.py
    │   └── static/index.html
    ├── examples/                 # programas .cps de ejemplo con su .asm
    ├── tests/                    # batería pytest (80 tests)
    └── program.cps               # programa oficial del curso (corre completo)
```

## Requisitos

- **Python 3.10+** con `antlr4-python3-runtime==4.13.1` (`pip install -r requirements.txt`)
- **Java** (solo para regenerar el lexer/parser con ANTLR)
- **SPIM** (`brew install spim`) o **MARS/QtSPIM** para ejecutar el `.asm`
- Alternativamente: **Docker** con la imagen oficial del curso (ver abajo)

## Uso rápido

```bash
cd program

# 1. (solo una vez) generar lexer/parser desde la gramática
java -jar ../antlr-4.13.1-complete.jar -Dlanguage=Python3 -visitor Compiscript.g4

# 2. compilar un programa
python3 Driver.py examples/02_functions.cps          # genera examples/02_functions.asm
python3 Driver.py program.cps --tac                  # además muestra el TAC
python3 Driver.py program.cps --run                  # compila y ejecuta en spim

# 3. correr la batería de tests (80 tests, incluye ejecución real en spim)
python3 -m pytest tests/

# 4. levantar el IDE web
python3 ide/server.py            # → http://localhost:8080
```

### Con Docker (flujo oficial del curso)

```bash
docker build --rm . -t csp-image && docker run --rm -ti -v "$(pwd)/program":/program csp-image

# dentro del contenedor:
antlr -Dlanguage=Python3 -visitor Compiscript.g4
python3 Driver.py program.cps            # genera program.asm
```

El `.asm` generado es texto portable: se ejecuta fuera del contenedor con
SPIM, QtSPIM o MARS (el contenedor del curso no incluye simulador MIPS).

## Las cuatro fases

1. **Léxico/Sintáctico** — ANTLR 4.13.1 con la gramática oficial
   `Compiscript.g4` (sin modificaciones). Los errores se reportan con línea
   y columna y detienen el pipeline.
2. **Semántico** (`semantic/`) — tabla de símbolos con ámbitos anidados,
   sistema de tipos (`integer`, `boolean`, `string`, `null`, arrays, clases
   con herencia y subtipado), verificación de funciones (aridad, tipos,
   return), constantes, `break`/`continue`, `this`, y resolución estática
   de campos y métodos. Deja **anotaciones** (tipos y símbolos resueltos)
   que consumen las fases siguientes.
3. **TAC** (`intermediate/`) — cuádruplos clásicos: `t1 = a + b`,
   `ifFalse t goto L`, `param x` / `call f, n` / `return x`, más
   instrucciones para arrays, objetos, strings y try/catch. Corto
   circuito para `&&`/`||`. Visible con `--tac` o en el IDE.
4. **MIPS** (`codegen/`) — ver
   [README_CODEGEN_IMPLEMENTATION.md](README_CODEGEN_IMPLEMENTATION.md):
   convención de llamadas con `$fp`/`$sp`/`$ra`/`$v0`, `getReg()` con
   spilling LRU, runtime embebido para strings y errores.

## Qué soporta (verificado con tests de ejecución real)

Tipos primitivos y literales; `let`/`var`/`const`; aritmética con
precedencia; comparaciones; lógicos con **corto circuito**; ternario;
`if/else`, `while`, `do-while`, `for`, `foreach`, `break`/`continue`,
`switch/case/default` (con fallthrough estilo C); funciones con
parámetros, `return`, **llamadas anidadas y recursión**; arrays con
verificación de índices en runtime, arrays anidados y `.length`;
**clases** con campos, constructor, métodos, `this`, herencia y
sobreescritura; `new`; acceso y asignación de propiedades;
**try/catch** de errores de runtime (índice fuera de rango, división
entre cero, referencia null) con unwinding real del stack; `print` de
enteros, strings y booleanos; **concatenación** `string + integer/boolean`.

## Limitaciones conocidas (documentadas, no silenciosas)

| Limitación | Comportamiento |
|---|---|
| Closures con captura | Error semántico explícito: una función anidada no puede leer locales de su función externa (sí puede usar globales y llamarse). |
| `let d = null;` sin tipo | Error semántico explícito: no se infiere un tipo desde `null`; declare `let d: MiClase = null;`. |
| Despacho de métodos | Estático por tipo declarado (sin vtables). La sobreescritura se resuelve en compilación. |
| `==` entre strings | Compara referencias, no contenido. |
| Campos de clase | Requieren anotación de tipo y sin inicializador (asignar en el constructor). |
| Funciones como valores | No soportado (solo llamada directa). |
| `switch` | Fallthrough estilo C; use `break` para salir. |
| Memoria | `sbrk` solo crece: no hay recolector de basura. |
| `itos` | El valor extremo −2147483648 no se convierte correctamente a string. |

## Ejemplos

En `program/examples/` hay ocho programas `.cps` con su `.asm` generado:
`01_hello` (prints y aritmética), `02_functions` (recursión y llamadas
anidadas), `03_control` (todo el control de flujo), `04_classes`
(herencia y `this`), `05_arrays` (arrays, foreach, try/catch),
`06_spilling` (fuerza el spilling de registros), y `07_esperada_if` /
`08_esperada_factorial`: los **dos ejemplos de referencia del PDF
"Ejecución Esperada del Compilador"** traducidos a Compiscript, cuyos
TAC, estructura MIPS y resultado de ejecución (`factorial(5)` → `120`)
se validan elemento por elemento en `tests/test_ejecucion_esperada.py`.

Todos se validan con: `python3 -m pytest tests/` (80 tests: casos
exitosos y casos límite ejecutados en SPIM comparando salida exacta,
casos fallidos sintácticos y semánticos, y validación estructural del
assembly generado).
