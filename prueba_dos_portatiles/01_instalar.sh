#!/usr/bin/env bash
# En A: bash ./01_instalar.sh A     En B: bash ./01_instalar.sh B
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
[[ ! -f "$TRABAJO/FUENTE_OFFLINE.txt" ]] || fallar 'Este usuario utiliza una instalacion offline. Usa sin_conexion/02_instalar_sin_internet.sh para mantenerla; no mezcles los dos instaladores.'
ROL="${1:-}"
[[ "$#" -eq 1 && "$ROL" =~ ^[AB]$ ]] || fallar 'Uso: bash ./01_instalar.sh A  (o B)'
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 22.04 && "$(uname -m)" == x86_64 ]] || fallar 'Este paquete esta preparado para Ubuntu 22.04 x86_64.'
if [[ -f "$TRABAJO/ROL.txt" ]]; then
    [[ "$(cat "$TRABAJO/ROL.txt")" == "$ROL" ]] || fallar 'Este usuario ya tiene asignado el otro rol. Consulta la guia antes de cambiarlo.'
fi
registrar "instalacion_$ROL"
comprobar_gpu
controlador="$(nvidia-smi -i 0 --query-gpu=driver_version --format=csv,noheader | tr -d '[:space:]')"
dpkg --compare-versions "$controlador" ge 570.26 || fallar 'Se requiere un controlador compatible con CUDA 12.8 (570.26 o posterior). El equipo informado usa 580.173.02.'
capacidad="$(nvidia-smi -i 0 --query-gpu=compute_cap --format=csv,noheader | tr -d '[:space:]')"
[[ "$capacidad" == 8.6 ]] || fallar "La GPU detectada tiene capacidad CUDA $capacidad. Este paquete compila para las RTX 3060 Laptop (8.6)."
espacio_kib="$(df -Pk "$TRABAJO" | awk 'NR==2 {print $4}')"
if (( espacio_kib < 30 * 1024 * 1024 )); then
    fallar 'Reserva al menos 30 GiB libres en la particion de tu carpeta personal. Se recomiendan 40 GB.'
fi

printf '\nInstalando herramientas de compilacion y CUDA Toolkit 12.8.\n'
sudo apt-get update
sudo apt-get install -y --no-install-recommends build-essential cmake ninja-build git curl ca-certificates libssl-dev python3 openssh-client ethtool pciutils
if [[ ! -x "$CUDA_RAIZ/bin/nvcc" ]]; then
    llave="$TRABAJO/descargas/cuda-keyring_1.1-1_all.deb"
    curl --fail --location --retry 3 --connect-timeout 30 \
        --proto '=https' --proto-redir '=https' \
        'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb' \
        --output "$llave"
    sudo dpkg -i "$llave"
    sudo apt-get update
    # Este paquete incluye el toolkit, no el metapaquete que instala controladores.
    sudo apt-get install -y --no-install-recommends cuda-toolkit-12-8
fi
"$CUDA_RAIZ/bin/nvcc" --version

if [[ "$ROL" == B ]]; then
    sudo apt-get install -y --no-install-recommends openssh-server
    sudo systemctl start ssh
    systemctl is-active --quiet ssh || fallar 'El servicio SSH no ha arrancado.'
fi

if [[ ! -e "$FUENTE" ]]; then
    git clone --depth 1 --branch "$LLAMA_TAG" 'https://github.com/ggml-org/llama.cpp.git' "$FUENTE"
fi
[[ -d "$FUENTE/.git" ]] || fallar "La carpeta $FUENTE existe y no contiene el repositorio esperado."
[[ "$(git -C "$FUENTE" rev-parse HEAD)" == "$LLAMA_COMMIT" ]] || fallar 'La revision descargada no coincide con la fijada en versiones.env.'
[[ -z "$(git -C "$FUENTE" status --porcelain --untracked-files=no)" ]] || fallar 'Hay cambios en el codigo fuente de llama.cpp. Revisarlos antes de compilar.'

printf '\nCompilando la misma revision para ambos portatiles.\n'
cmake -S "$FUENTE" -B "$FUENTE/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="$CUDA_RAIZ/bin/nvcc" \
    -DCUDAToolkit_ROOT="$CUDA_RAIZ" \
    -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DGGML_CUDA=ON -DGGML_RPC=ON \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_APP=OFF
cmake --build "$FUENTE/build" --parallel 4 --target llama-server llama-cli ggml-rpc-server

dispositivos="$("$BIN/llama-cli" --list-devices 2>&1)"
printf '%s\n' "$dispositivos"
grep -q 'CUDA0' <<< "$dispositivos" || fallar 'La compilacion no ha detectado CUDA0.'
printf '%s\n' "$LLAMA_COMMIT" > "$TRABAJO/BUILD_COMMIT.txt"
printf '%s\n' "$ROL" > "$TRABAJO/ROL.txt"
{
    date -Is
    printf 'Rol: %s\nRevision: %s\n' "$ROL" "$LLAMA_COMMIT"
    "$BIN/llama-cli" --version
    "$CUDA_RAIZ/bin/nvcc" --version
    nvidia-smi -i 0 --query-gpu=name,memory.total,driver_version --format=csv
} > "$TRABAJO/entorno_$ROL.txt" 2>&1
printf '\nInstalacion terminada en el portatil %s.\n' "$ROL"
if [[ "$ROL" == B ]]; then
    printf '\nUsuario para SSH: %s\n' "$(id -un)"
    ip -4 -br address
    printf '\nHuella de la clave SSH de este equipo (comparar en A la primera vez):\n'
    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
fi
