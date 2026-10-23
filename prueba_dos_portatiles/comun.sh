#!/usr/bin/env bash
# Biblioteca compartida. Ejecutar los scripts numerados, no este archivo.
set -Eeuo pipefail
export LC_ALL=C
umask 077
PAQUETE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$PAQUETE/versiones.env"
TRABAJO="$HOME/cluster_llm"
FUENTE="$TRABAJO/llama.cpp-${LLAMA_COMMIT:0:12}"
if [[ -f "$TRABAJO/FUENTE_OFFLINE.txt" ]]; then
    fuente_offline="$(cat "$TRABAJO/FUENTE_OFFLINE.txt")"
    [[ "$fuente_offline" == "$TRABAJO/llama.cpp-offline-${LLAMA_COMMIT:0:12}" ]] || { printf 'Ruta offline inesperada. Revisa FUENTE_OFFLINE.txt.\n' >&2; exit 1; }
    FUENTE="$fuente_offline"
fi
BIN="$FUENTE/build/bin"
MODELO="$TRABAJO/modelos/$MODEL_NAME"
CUDA_RAIZ='/usr/local/cuda-12.8'
export CUDA_VISIBLE_DEVICES=0
export PATH="$CUDA_RAIZ/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_RAIZ/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

fallar() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "\nEl paso se ha detenido en %s, linea %s. Revisa el error anterior.\n" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR

comprobar_usuario() {
    [[ "$(uname -s)" == Linux ]] || fallar 'Ejecuta este archivo en el portatil Ubuntu.'
    [[ "$EUID" -ne 0 ]] || fallar 'Ejecuta bash ./script.sh como usuario normal, sin sudo delante.'
}
preparar_carpetas() {
    mkdir -p -- "$TRABAJO/logs" "$TRABAJO/modelos" "$TRABAJO/descargas" "$TRABAJO/resultados"
}
registrar() {
    preparar_carpetas
    LOG="$TRABAJO/logs/${1}_$(date +%Y%m%d_%H%M%S)_$$.log"
    exec > >(tee -a "$LOG") 2>&1
    printf 'Registro: %s\n' "$LOG"
}
exigir_rol() {
    [[ -f "$TRABAJO/ROL.txt" ]] || fallar 'Primero ejecuta 01_instalar.sh A o 01_instalar.sh B.'
    [[ "$(cat "$TRABAJO/ROL.txt")" == "$1" ]] || fallar "Este paso corresponde al portatil $1."
}
exigir_compilacion() {
    [[ -f "$TRABAJO/BUILD_COMMIT.txt" ]] || fallar 'Falta completar 01_instalar.sh.'
    [[ "$(cat "$TRABAJO/BUILD_COMMIT.txt")" == "$LLAMA_COMMIT" ]] || fallar 'La compilacion pertenece a otra version.'
    [[ -x "$BIN/llama-server" && -x "$BIN/ggml-rpc-server" ]] || fallar 'Faltan los ejecutables. Repite la instalacion.'
}
comprobar_gpu() {
    command -v nvidia-smi >/dev/null || fallar 'Falta nvidia-smi. Revisar el controlador NVIDIA antes de continuar.'
    nvidia-smi -i 0 --query-gpu=name,memory.total,memory.free,driver_version --format=csv
}
comprobar_vram_libre() {
    local libre
    libre="$(nvidia-smi -i 0 --query-gpu=memory.free --format=csv,noheader,nounits | tr -d '[:space:]')"
    [[ "$libre" =~ ^[0-9]+$ ]] || fallar 'No se pudo consultar la VRAM libre.'
    [[ "$libre" -ge 5000 ]] || fallar "Solo hay $libre MiB libres. Cierra LM Studio, Ollama u otras aplicaciones que usen NVIDIA y repite."
}
exigir_puerto_libre() {
    python3 - "$1" <<'PY'
import socket, sys
with socket.socket() as s:
    try:
        s.bind(('127.0.0.1', int(sys.argv[1])))
    except OSError as exc:
        sys.exit(f'El puerto local {sys.argv[1]} esta ocupado: {exc}. Cierra el proceso anterior antes de repetir.')
PY
}
