"""Infraestructura compartida de la bateria de tests.

- `compile_ok(src)`: compila fuente y exige exito; devuelve el resultado.
- `run_mips(asm)`: ejecuta el .asm en spim y devuelve stdout limpio.
  Los tests de ejecucion se saltan automaticamente si spim no esta
  instalado (la validacion estructural del .asm corre siempre).
- `AsmChecker`: validaciones estructurales del assembly generado
  (secciones, labels duplicados, saltos a labels inexistentes,
  registros invalidos).
"""

import os
import re
import shutil
import subprocess
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from compiler import compile_source  # noqa: E402

SPIM = shutil.which('spim')

VALID_REGISTERS = {
    '$zero', '$at', '$v0', '$v1', '$a0', '$a1', '$a2', '$a3',
    '$t0', '$t1', '$t2', '$t3', '$t4', '$t5', '$t6', '$t7', '$t8', '$t9',
    '$s0', '$s1', '$s2', '$s3', '$s4', '$s5', '$s6', '$s7',
    '$k0', '$k1', '$gp', '$sp', '$fp', '$ra',
}


def compile_ok(src):
    result = compile_source(src)
    assert result.success, f"la compilacion fallo: {result.all_errors}"
    assert result.mips_text, "no se genero MIPS"
    return result


def run_mips(asm_text, tmp_path):
    """Ejecuta el assembly en spim y devuelve las lineas de salida."""
    if SPIM is None:
        pytest.skip('spim no esta instalado')
    asm_file = tmp_path / 'out.asm'
    asm_file.write_text(asm_text, encoding='utf-8')
    proc = subprocess.run([SPIM, '-file', str(asm_file)],
                          capture_output=True, text=True, timeout=30)
    lines = proc.stdout.splitlines()
    # descartar la cabecera de spim ("Loaded: .../exceptions.s")
    body = [ln for ln in lines if not ln.startswith('Loaded:')]
    return body


def run_source(src, tmp_path):
    """Compila y ejecuta, devolviendo la salida como lista de lineas."""
    return run_mips(compile_ok(src).mips_text, tmp_path)


class AsmChecker:
    """Validaciones estructurales sobre el texto de un .asm generado."""

    BRANCH_RE = re.compile(
        r'^\s*(?:j|jal|b|beq|bne|beqz|bnez|blez|bgtz|bltz|bgez)\s+(.*)$')
    LABEL_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*):')
    REG_RE = re.compile(r'\$[a-z0-9]+')

    def __init__(self, asm_text):
        self.text = asm_text
        self.lines = asm_text.splitlines()

    def code_lines(self):
        for line in self.lines:
            code = line.split('#', 1)[0].rstrip()
            if code.strip():
                yield code

    def labels(self):
        found = []
        for code in self.code_lines():
            m = self.LABEL_RE.match(code)
            if m:
                found.append(m.group(1))
        return found

    def jump_targets(self):
        targets = set()
        for code in self.code_lines():
            m = self.BRANCH_RE.match(code.strip())
            if m:
                operands = [p.strip() for p in m.group(1).split(',')]
                last = operands[-1]
                # jr $ra / saltos por registro no tienen etiqueta destino
                if last and not last.startswith('$') and not last[0].isdigit():
                    targets.add(last)
        return targets

    def registers_used(self):
        regs = set()
        for code in self.code_lines():
            if self.LABEL_RE.match(code):
                code = code.split(':', 1)[1]
            for m in self.REG_RE.finditer(code):
                regs.add(m.group(0))
        return regs

    # ---- validaciones -------------------------------------------------

    def assert_valid(self):
        assert '.data' in self.text, 'falta la seccion .data'
        assert '.text' in self.text, 'falta la seccion .text'
        assert '.globl main' in self.text, 'falta .globl main'
        labels = self.labels()
        assert 'main' in labels, 'falta la etiqueta main'
        assert 'li $v0, 10' in self.text, 'falta el syscall de salida'
        dupes = {l for l in labels if labels.count(l) > 1}
        assert not dupes, f'labels duplicados: {dupes}'
        missing = self.jump_targets() - set(labels)
        assert not missing, f'saltos a labels inexistentes: {missing}'
        bad_regs = self.registers_used() - VALID_REGISTERS
        assert not bad_regs, f'registros inexistentes: {bad_regs}'
