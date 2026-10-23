#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
exigir_rol A
preparar_carpetas
exec python3 "$PAQUETE/probar_modelo.py" "$TRABAJO/resultados"
