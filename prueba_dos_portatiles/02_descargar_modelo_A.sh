#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
exigir_rol A
registrar descarga_modelo
exec 9> "$TRABAJO/descarga_modelo.lock"
flock -n 9 || fallar 'Ya hay otra descarga o comprobacion del modelo en marcha.'

verificar() {
    [[ "$(stat -c '%s' "$1")" == "$MODEL_BYTES" ]] || return 1
    [[ "$(sha256sum "$1" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]]
}
if [[ -f "$MODELO" ]]; then
    printf 'Comprobando el modelo existente (9 GB)...\n'
    verificar "$MODELO" || fallar 'El modelo existente no coincide con la huella oficial. Conserva el archivo y revisa la guia.'
else
    parcial="$MODELO.part"
    if [[ -f "$parcial" && "$(stat -c '%s' "$parcial")" == "$MODEL_BYTES" ]]; then
        printf 'Se ha encontrado una descarga completa pendiente de comprobacion.\n'
    else
        url="https://huggingface.co/$MODEL_REPO/resolve/$MODEL_REVISION/$MODEL_NAME"
        printf 'Descargando 9 GB. Se puede reanudar repitiendo este script.\n'
        curl --fail --location --retry 5 --connect-timeout 30 \
            --proto '=https' --proto-redir '=https' \
            --continue-at - --output "$parcial" "$url"
    fi
    printf '\nComprobando tamano y SHA-256...\n'
    verificar "$parcial" || fallar 'La descarga no supera la comprobacion. Se conserva el archivo .part para revisarlo.'
    mv -- "$parcial" "$MODELO"
fi
printf '%s\n' "$MODEL_SHA256" > "$MODELO.sha256.ok"
printf '\nModelo verificado: %s\n' "$MODELO"
