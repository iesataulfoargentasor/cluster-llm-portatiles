#!/usr/bin/env bash
# Funciones sin efectos al cargarse; tambien utilizadas por las pruebas simuladas.
verificar_modelo() {
    [[ -f "$1" && "$(stat -c '%s' "$1")" == "$MODEL_BYTES" &&
       "$(sha256sum "$1" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]]
}

descargar_modelo() {
    local destino="$1" url="$2" tamano=0
    if [[ -f "$destino" ]]; then
        verificar_modelo "$destino" || fallar 'Modelo existente con hash o tamano incorrecto.'
        return
    fi
    if [[ -f "$destino.part" ]]; then tamano="$(stat -c '%s' "$destino.part")"; fi
    (( tamano <= MODEL_BYTES )) || fallar 'El archivo parcial es demasiado grande. Conservalo con otro nombre y repite.'
    # Si la descarga termino antes de la interrupcion, no solicitar un rango fuera del archivo.
    if (( tamano < MODEL_BYTES )); then
        curl --fail --location --retry 5 --connect-timeout 30 --proto '=https' --proto-redir '=https' \
            --continue-at - --output "$destino.part" "$url"
    fi
    verificar_modelo "$destino.part" || fallar 'Modelo parcial con hash o tamano incorrecto. Conservalo con otro nombre y repite.'
    mv -- "$destino.part" "$destino"
}

validar_plan_apt() {
    [[ -s "$1" ]] || fallar 'No se ha generado un plan APT legible. No se instala.'
    # Incluye bibliotecas del controlador, firmware, DKMS y metapaquetes del kernel.
    if grep -E '^(Inst|Remv) (nvidia-|libnvidia-|cuda-drivers|linux-|dkms([ :]|$)|xserver-xorg-video-nvidia-)' "$1"; then
        fallar 'El plan afectaria al controlador o kernel. No se aplica: revisa los registros.'
    fi
}

extraer_fuentes() {
    local destino="$1" temporal
    if [[ -e "$destino" ]]; then
        [[ -f "$destino/ORIGEN_KIT.txt" && "$(cat "$destino/ORIGEN_KIT.txt")" == "$LLAMA_COMMIT" ]] ||
            fallar 'La carpeta de fuentes offline ya existe sin identificacion. Conservala con otro nombre.'
        return
    fi
    temporal="$(mktemp -d "${destino}.extraccion.XXXXXX")"
    # Una interrupcion conserva solo una carpeta temporal; el siguiente intento puede continuar.
    tar -xzf "$RAIZ_KIT/fuentes/llama.cpp.tar.gz" --no-same-owner -C "$temporal"
    mkdir -p "$temporal/tools/ui/dist"
    tar -xzf "$RAIZ_KIT/fuentes/interfaz_chat.tar.gz" --no-same-owner -C "$temporal/tools/ui/dist"
    [[ -s "$temporal/tools/ui/dist/index.html" ]] || fallar 'Faltan los recursos del chat.'
    printf '%s\n' "$LLAMA_COMMIT" > "$temporal/ORIGEN_KIT.txt"
    mv -- "$temporal" "$destino"
}
