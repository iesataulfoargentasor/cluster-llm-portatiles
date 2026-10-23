#!/usr/bin/env bash
# Opcional: bash ./05_iniciar_modelo_A.sh 2048  (contexto reducido)
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
exigir_rol A
exigir_compilacion
[[ "$#" -le 1 ]] || fallar 'Uso: bash ./05_iniciar_modelo_A.sh [4096|2048]'
contexto="${1:-4096}"
[[ "$contexto" == 4096 || "$contexto" == 2048 ]] || fallar 'Usa 4096 (normal) o 2048 (menos memoria).'
registrar modelo_A
comprobar_gpu
comprobar_vram_libre
[[ -f "$MODELO" && -f "$MODELO.sha256.ok" ]] || fallar 'Primero ejecuta 02_descargar_modelo_A.sh.'
[[ "$(stat -c '%s' "$MODELO")" == "$MODEL_BYTES" && "$(cat "$MODELO.sha256.ok")" == "$MODEL_SHA256" ]] || fallar 'Repite 02_descargar_modelo_A.sh para comprobar el modelo.'
exigir_puerto_libre 8080

printf '\nBuscando la GPU local y la GPU remota a traves del tunel...\n'
dispositivos="$(timeout 45s "$BIN/llama-cli" --rpc 127.0.0.1:50052 --list-devices 2>&1)" || {
    printf '%s\n' "$dispositivos"
    fallar 'No se pudo consultar RPC. Comprueba que siguen abiertos los pasos 03 en B y 04 en A.'
}
printf '%s\n' "$dispositivos"
grep -qE '^[[:space:]]*CUDA0:' <<< "$dispositivos" || fallar 'No aparece la GPU CUDA local.'
grep -qE '^[[:space:]]*RPC0:.*127\.0\.0\.1:50052' <<< "$dispositivos" || fallar 'No aparece la GPU RPC0 remota.'

printf '\nCargando el modelo en las dos GPU. La primera carga por Gigabit puede tardar varios minutos.\n'
printf 'Cuando el servidor este listo, abre en A: http://127.0.0.1:8080\n'
printf 'Contexto: %s. Una conversacion. Reparto por capas 1:1.\n' "$contexto"
printf 'Deja esta terminal abierta. Para detener el modelo, pulsa Ctrl+C.\n'
exec "$BIN/llama-server" \
    --model "$MODELO" --alias qwen3-14b-cluster \
    --rpc 127.0.0.1:50052 --device CUDA0,RPC0 \
    --gpu-layers 99 --split-mode layer --tensor-split 1,1 --fit off \
    --ctx-size "$contexto" --parallel 1 --batch-size 256 --ubatch-size 128 \
    --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
    --jinja --chat-template-kwargs '{"enable_thinking":false}' \
    --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0 --presence-penalty 1.5 \
    --host 127.0.0.1 --port 8080 --metrics --perf
