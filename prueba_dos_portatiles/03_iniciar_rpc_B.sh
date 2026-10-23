#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
exigir_rol B
exigir_compilacion
registrar rpc_B
comprobar_gpu
comprobar_vram_libre
systemctl is-active --quiet ssh || fallar 'Arranca SSH en B con: sudo systemctl start ssh'
exigir_puerto_libre 50052
export LLAMA_CACHE="$TRABAJO/cache-rpc"
mkdir -p -- "$LLAMA_CACHE"
printf '\nRPC preparado para recibir conexiones mediante SSH en 127.0.0.1:50052.\n'
printf 'Deja esta terminal abierta. Para detenerlo, pulsa Ctrl+C.\n'
exec "$BIN/ggml-rpc-server" --host 127.0.0.1 --port 50052 --device CUDA0 --cache
