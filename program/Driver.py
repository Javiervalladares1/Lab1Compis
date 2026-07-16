"""Punto de entrada del compilador de Compiscript.

Uso:
    python3 Driver.py programa.cps               # compila a programa.asm
    python3 Driver.py programa.cps -o salida.asm # nombre de salida explicito
    python3 Driver.py programa.cps --tac         # muestra el TAC generado
    python3 Driver.py programa.cps --run         # compila y ejecuta en spim
    python3 Driver.py programa.cps --quiet       # solo errores (sin resumen)
"""

import os
import shutil
import subprocess
import sys

from compiler import compile_file


def main(argv):
    # separar el valor de -o ANTES de decidir cual es el archivo fuente,
    # para que `Driver.py -o salida.asm programa.cps` tambien funcione
    out_path = None
    rest = list(argv[1:])
    if '-o' in rest:
        idx = rest.index('-o')
        if idx + 1 >= len(rest):
            print("error: falta el nombre de archivo despues de -o")
            return 2
        out_path = rest[idx + 1]
        del rest[idx:idx + 2]

    args = [a for a in rest if not a.startswith('-')]
    flags = [a for a in rest if a.startswith('-')]
    if not args:
        print(__doc__)
        return 2
    source_path = args[0]
    if not os.path.exists(source_path):
        print(f"error: no existe el archivo '{source_path}'")
        return 2
    if out_path is None:
        out_path = os.path.splitext(source_path)[0] + '.asm'

    result = compile_file(source_path)

    if result.syntax_errors:
        print("Errores sintacticos:")
        for e in result.syntax_errors:
            print("  " + e)
        return 1
    if result.semantic_errors:
        print("Errores semanticos:")
        for e in result.semantic_errors:
            print("  " + e)
        return 1

    if '--tac' in flags:
        print("===== TAC =====")
        print(result.tac_text)
        print()

    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(result.mips_text)

    if '--quiet' not in flags:
        print(f"OK: MIPS generado en {out_path}")

    if '--run' in flags:
        spim = shutil.which('spim')
        if spim is None:
            print("aviso: spim no esta instalado; ejecute el .asm en MARS/QtSPIM")
            return 0
        print("===== ejecucion (spim) =====")
        proc = subprocess.run([spim, '-file', out_path],
                              capture_output=True, text=True)
        # spim imprime 5 lineas de cabecera (version, licencia, exception.s)
        lines = proc.stdout.splitlines()
        start = 0
        for i, line in enumerate(lines):
            if 'exceptions.s' in line or line.startswith('Loaded:'):
                start = i + 1
                break
        print('\n'.join(lines[start:]))
        if proc.stderr:
            print(proc.stderr, file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
