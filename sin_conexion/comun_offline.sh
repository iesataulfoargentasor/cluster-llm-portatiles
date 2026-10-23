#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 022
SCRIPTS_OFFLINE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RAIZ_KIT="$(cd -- "$SCRIPTS_OFFLINE/.." && pwd)"
source "$RAIZ_KIT/prueba_dos_portatiles/comun.sh"
source "$SCRIPTS_OFFLINE/funciones_seguras.sh"
# APT accede al repositorio privado con Sandbox::User=root.
PAQUETES=(build-essential cmake ninja-build git curl ca-certificates libssl-dev
    python3 openssh-client openssh-server ethtool pciutils cuda-toolkit-12-8)
ubuntu_compatible() {
    comprobar_usuario
    source /etc/os-release
    [[ "$ID" == ubuntu && "$VERSION_ID" == 22.04 && "$(uname -m)" == x86_64 ]] || fallar 'Se requiere Ubuntu 22.04 x86_64.'
}
comprobar_kit() {
    [[ -f "$RAIZ_KIT/KIT_COMPLETO.txt" && -f "$RAIZ_KIT/SHA256SUMS" ]] || fallar 'Kit incompleto: primero prepara las descargas con Internet.'
    [[ "$(cat "$RAIZ_KIT/REVISION_LLAMA.txt")" == "$LLAMA_COMMIT" ]] || fallar 'El kit no corresponde a esta revision.'
    printf 'Verificando el kit completo; leer el modelo de 9 GB puede tardar...\n'
    (cd "$RAIZ_KIT" && sha256sum --check --quiet SHA256SUMS) || fallar 'El pendrive o la copia no supera la comprobacion SHA-256.'
}
