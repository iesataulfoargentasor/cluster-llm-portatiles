#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun_offline.sh"
ubuntu_compatible
[[ "$#" -eq 0 ]] || fallar 'Este script no necesita argumentos.'
exigir_rol A
exigir_compilacion
registrar importar_modelo_offline
origen="$RAIZ_KIT/modelo/$MODEL_NAME"
[[ -f "$origen" ]] || fallar 'No se encuentra el modelo del kit.'
[[ "$(stat -c '%s' "$origen")" == "$MODEL_BYTES" && "$(sha256sum "$origen" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]] || fallar 'El modelo del kit no supera la comprobacion oficial.'
exec 9> "$TRABAJO/descarga_modelo.lock"
flock -n 9 || fallar 'Otra operacion esta utilizando el modelo.'
if [[ ! -f "$MODELO" ]]; then
    # Copia a disco local: no ejecutar la inferencia leyendo los pesos del USB.
    cp -- "$origen" "$MODELO.offline.part"
    [[ "$(sha256sum "$MODELO.offline.part" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]] || fallar 'La copia local no supera la comprobacion.'
    mv "$MODELO.offline.part" "$MODELO"
fi
[[ "$(sha256sum "$MODELO" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]] || fallar 'El modelo local existente no coincide. Conservalo con otro nombre antes de repetir.'
printf '%s\n' "$MODEL_SHA256" > "$MODELO.sha256.ok"
printf 'Modelo importado y verificado: %s\n' "$MODELO"
