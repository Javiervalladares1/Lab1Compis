"""IDE web de Compiscript.

Servidor local sin dependencias externas (solo libreria estandar):

    python3 ide/server.py            # abre en http://localhost:8080
    python3 ide/server.py 9000       # puerto alternativo

Endpoints:
    GET  /            pagina del editor
    POST /compile     JSON {source} -> {ok, errors, tac, mips}
    POST /run         igual que /compile pero ademas ejecuta en spim
                      (si esta instalado) y devuelve {output}
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from http.server import HTTPServer, BaseHTTPRequestHandler

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from compiler import compile_source  # noqa: E402

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')


def compile_payload(source, run=False):
    result = compile_source(source)
    payload = {
        'ok': result.success,
        'errors': result.all_errors,
        'tac': result.tac_text or '',
        'mips': result.mips_text or '',
        'output': None,
    }
    if run and result.success:
        spim = shutil.which('spim')
        if spim is None:
            payload['output'] = '(spim no esta instalado en esta maquina)'
        else:
            with tempfile.NamedTemporaryFile(
                    'w', suffix='.asm', delete=False, encoding='utf-8') as f:
                f.write(result.mips_text)
                asm_path = f.name
            try:
                proc = subprocess.run([spim, '-file', asm_path],
                                      capture_output=True, text=True, timeout=15)
                lines = [ln for ln in proc.stdout.splitlines()
                         if not ln.startswith('Loaded:')]
                payload['output'] = '\n'.join(lines)
            except subprocess.TimeoutExpired:
                payload['output'] = '(tiempo de ejecucion excedido: posible ciclo infinito)'
            finally:
                os.unlink(asm_path)
    return payload


class IDEHandler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        pass  # silenciar el log por peticion

    def _send(self, code, content_type, body):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ('/', '/index.html'):
            with open(os.path.join(STATIC_DIR, 'index.html'), 'rb') as f:
                self._send(200, 'text/html; charset=utf-8', f.read())
        else:
            self._send(404, 'text/plain', b'not found')

    def do_POST(self):
        if self.path not in ('/compile', '/run'):
            self._send(404, 'text/plain', b'not found')
            return
        length = int(self.headers.get('Content-Length', 0))
        try:
            data = json.loads(self.rfile.read(length))
            source = data.get('source', '')
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._send(400, 'text/plain', b'bad request')
            return
        payload = compile_payload(source, run=(self.path == '/run'))
        body = json.dumps(payload).encode('utf-8')
        self._send(200, 'application/json; charset=utf-8', body)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = HTTPServer(('127.0.0.1', port), IDEHandler)
    print(f"IDE de Compiscript corriendo en http://localhost:{port}")
    print("Ctrl+C para detener")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nIDE detenido")


if __name__ == '__main__':
    main()
