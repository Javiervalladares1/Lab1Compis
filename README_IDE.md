# IDE web de Compiscript

IDE local para escribir, compilar y ejecutar programas Compiscript.
Implementado únicamente con la librería estándar de Python (no requiere
Flask ni ninguna dependencia adicional).

## Cómo ejecutarlo

```bash
cd program
python3 ide/server.py          # http://localhost:8080
python3 ide/server.py 9000     # puerto alternativo
```

Abre `http://localhost:8080` en el navegador.

## Funcionalidad

- **Editor** con un programa de ejemplo precargado (factorial).
- **Compilar** (o `Cmd/Ctrl + Enter`): corre el pipeline completo
  (parser → semántica → TAC → MIPS).
  - Si hay errores, se listan con número de línea bajo el editor.
  - Si compila, los paneles muestran el **MIPS** y el **TAC** generados.
- **Compilar y ejecutar**: además ejecuta el `.asm` con `spim` y muestra
  la salida del programa en la pestaña *Ejecución*. Si `spim` no está
  instalado lo indica (y puedes ejecutar el `.asm` descargado en
  MARS/QtSPIM). Los programas con ciclos infinitos se cortan a los 15 s.
- **Descargar .asm**: guarda el assembly generado como `programa.asm`.

## Endpoints (para integración o pruebas)

| Método | Ruta | Cuerpo | Respuesta |
|---|---|---|---|
| GET | `/` | — | página del editor |
| POST | `/compile` | `{"source": "..."}` | `{ok, errors[], tac, mips}` |
| POST | `/run` | `{"source": "..."}` | igual + `output` de spim |

Ejemplo:

```bash
curl -s -X POST http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -d '{"source":"print(6*7);"}'
```

## Notas

- El servidor escucha solo en `127.0.0.1` (uso local).
- La ejecución usa un archivo temporal que se elimina al terminar.
