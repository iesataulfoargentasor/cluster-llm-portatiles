#!/usr/bin/env bash
# Uso: bash ./08_restaurar_dhcp.sh [interfaz]
# Ejecutar con el mismo usuario que utilizo el paso 07.
set -Eeuo pipefail
PAQUETE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$PAQUETE/red_cluster.py" dhcp "$@"
