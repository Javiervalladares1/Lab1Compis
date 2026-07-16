"""Pipeline completo del compilador de Compiscript.

    fuente .cps -> lexer/parser (ANTLR) -> analisis semantico
                -> TAC -> MIPS (.asm)

Este modulo expone `compile_source`, que ejecuta todas las fases y
devuelve un CompilationResult con los errores o los artefactos
generados. Lo consumen Driver.py (CLI), el IDE web y los tests.
"""

from antlr4 import InputStream, CommonTokenStream
from antlr4.error.ErrorListener import ErrorListener

from CompiscriptLexer import CompiscriptLexer
from CompiscriptParser import CompiscriptParser
from semantic.checker import SemanticChecker
from intermediate.tac_generator import TACGenerator
from codegen.mips_generator import MIPSGenerator


class _CollectingErrorListener(ErrorListener):
    """Acumula los errores sintacticos en lugar de imprimirlos."""

    def __init__(self):
        self.errors = []

    def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
        self.errors.append(f"linea {line}:{column} {msg}")


class CompilationResult:
    def __init__(self):
        self.syntax_errors = []
        self.semantic_errors = []
        self.tac_text = None
        self.mips_text = None
        self.tac_program = None

    @property
    def success(self):
        return not self.syntax_errors and not self.semantic_errors

    @property
    def all_errors(self):
        return self.syntax_errors + self.semantic_errors


def compile_source(source):
    """Compila codigo fuente Compiscript. Devuelve CompilationResult."""
    result = CompilationResult()

    # fase 1: analisis lexico y sintactico
    listener = _CollectingErrorListener()
    lexer = CompiscriptLexer(InputStream(source))
    lexer.removeErrorListeners()
    lexer.addErrorListener(listener)
    parser = CompiscriptParser(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(listener)
    tree = parser.program()
    if listener.errors:
        result.syntax_errors = listener.errors
        return result

    # fase 2: analisis semantico (sistema de tipos, ambitos, resolucion)
    checker = SemanticChecker()
    checker.visit(tree)
    if checker.errors:
        result.semantic_errors = checker.errors
        return result

    # fase 3: codigo intermedio (TAC)
    tac_gen = TACGenerator(checker)
    tac_program = tac_gen.visit(tree)
    result.tac_program = tac_program
    result.tac_text = str(tac_program)

    # fase 4: codigo final (MIPS)
    mips_gen = MIPSGenerator(tac_program)
    result.mips_text = mips_gen.generate()
    return result


def compile_file(path):
    with open(path, encoding='utf-8') as f:
        return compile_source(f.read())
