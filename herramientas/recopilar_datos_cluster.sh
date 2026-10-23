#!/usr/bin/env bash
# Ejecutar en cada portatil Ubuntu con: bash recopilar_datos_cluster.sh
# Guarda el informe en ~/informes_cluster/. No necesita ejecutarse con sudo.

set -u
export LC_ALL=C
umask 077

if [ "$(uname -s)" != "Linux" ]; then
    printf 'Ejecuta este script en el portatil con Ubuntu que quieras evaluar.\n' >&2
    exit 1
fi

directorio="$HOME/informes_cluster"
equipo="$(hostname)"
equipo="$(printf '%s' "$equipo" | tr -c 'A-Za-z0-9._-' '_')"
fecha="$(date +%Y%m%d_%H%M%S)"

if ! mkdir -p -- "$directorio"; then
    printf 'No se pudo crear la carpeta de informes: %s\n' "$directorio" >&2
    exit 1
fi

informe="$(mktemp --suffix=.txt "$directorio/informe_${equipo}_${fecha}_XXXXXX")" || exit 1

{
    printf '=== INFORME PARA CLUSTER DE INFERENCIA LOCAL ===\n'
    printf 'Equipo: %s\n' "$(hostname)"
    printf 'Fecha: %s\n' "$(date -Is)"
    printf 'Kernel: %s\n' "$(uname -r)"
    if [ -r /etc/os-release ]; then
        grep '^PRETTY_NAME=' /etc/os-release
    fi

    printf '\n=== PROCESADOR ===\n'
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | grep -E '^Architecture:|^CPU\(s\):|^Model name:|^Thread\(s\) per core:|^Core\(s\) per socket:|^Socket\(s\):'
    else
        grep -m 1 'model name' /proc/cpuinfo
    fi

    printf '\n=== MEMORIA RAM ===\n'
    free -h
    printf '\nMemoria total indicada por Linux:\n'
    grep '^MemTotal:' /proc/meminfo

    printf '\n=== TARJETAS GRAFICAS Y CONTROLADORES ===\n'
    if command -v lspci >/dev/null 2>&1; then
        lspci -nnk | grep -Ei -A 3 'VGA compatible controller|3D controller|Display controller'
    else
        printf 'No esta disponible lspci. Para obtener este dato: sudo apt install pciutils\n'
    fi

    printf '\n=== NVIDIA: MODELO, VRAM Y VERSION DEL CONTROLADOR ===\n'
    if command -v nvidia-smi >/dev/null 2>&1; then
        timeout 20s nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
        resultado=$?
        if [ "$resultado" -ne 0 ]; then
            printf 'nvidia-smi no pudo completar la consulta (codigo %s).\n' "$resultado"
        fi
    else
        printf 'nvidia-smi no esta disponible. Esto no permite descartar que exista una GPU NVIDIA.\n'
        printf 'Si la GPU es de otro fabricante, identificarla en la seccion anterior.\n'
    fi

    printf '\n=== INTERFACES DE RED ===\n'
    ip -br link

    printf '\n=== ADAPTADORES ETHERNET FISICOS ===\n'
    encontrados=0
    for ruta in /sys/class/net/*; do
        [ -e "$ruta/device" ] || continue
        [ ! -d "$ruta/wireless" ] || continue
        [ ! -e "$ruta/phy80211" ] || continue
        [ "$(cat "$ruta/type" 2>/dev/null)" = "1" ] || continue

        encontrados=$((encontrados + 1))
        interfaz="${ruta##*/}"
        printf '\n--- Interfaz: %s ---\n' "$interfaz"
        printf 'Estado: %s\n' "$(cat "$ruta/operstate" 2>/dev/null)"

        velocidad="$(cat "$ruta/speed" 2>/dev/null)" || velocidad=""
        if [[ "$velocidad" =~ ^[0-9]+$ ]] && [ "$velocidad" -gt 0 ]; then
            printf 'Velocidad negociada indicada por Linux: %s Mb/s\n' "$velocidad"
        else
            printf 'Velocidad negociada no disponible. Comprobar cable, switch y estado del enlace.\n'
        fi

        if command -v ethtool >/dev/null 2>&1; then
            printf '\nCapacidades del adaptador y estado del enlace:\n'
            ethtool "$interfaz"
        else
            printf 'Falta ethtool para consultar las velocidades admitidas y mas detalles.\n'
            printf 'Instalar con: sudo apt update && sudo apt install ethtool\n'
            printf 'Despues, volver a ejecutar este script.\n'
        fi
    done

    if [ "$encontrados" -eq 0 ]; then
        printf 'No se han detectado adaptadores Ethernet fisicos.\n'
        printf 'Si se utiliza un adaptador USB, conectarlo y repetir el informe.\n'
    fi

    printf '\n=== FIN DEL INFORME ===\n'
} > "$informe" 2>&1

printf '\nInforme guardado en:\n%s\n' "$informe"
printf '\nPuedes copiar este archivo de texto y adjuntarlo en el chat.\n'

if ! command -v ethtool >/dev/null 2>&1; then
    printf '\nPara completar las capacidades de Ethernet, instala ethtool y repite el script:\n'
    printf 'sudo apt update && sudo apt install ethtool\n'
fi
