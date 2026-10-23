#!/usr/bin/env bash
# Uso: bash ./07_configurar_red_aislada.sh A [interfaz]
#      bash ./07_configurar_red_aislada.sh B [interfaz]
set -Eeuo pipefail
PAQUETE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$PAQUETE/red_cluster.py" configurar "$@"
