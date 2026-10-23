#!/usr/bin/env bash
# En cada equipo, desde la copia LOCAL del kit: bash ./02_instalar_sin_internet.sh A|B
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun_offline.sh"
ubuntu_compatible
[[ "$#" -eq 1 && "$1" =~ ^[AB]$ ]] || fallar 'Uso: bash ./02_instalar_sin_internet.sh A  (o B)'
ROL="$1"
preparar_carpetas
exec 9> "$TRABAJO/instalacion_offline.lock"
flock -n 9 || fallar 'Ya hay otra instalacion offline en marcha para este usuario.'
[[ "$RAIZ_KIT" == "$HOME/kit_cluster_sin_internet" ]] || fallar 'Copia el kit completo a ~/kit_cluster_sin_internet antes de instalar.'
[[ "$RAIZ_KIT" != *[[:space:]]* ]] || fallar 'La ruta del kit no debe contener espacios.'
if [[ -f "$TRABAJO/ROL.txt" ]]; then
    [[ "$(cat "$TRABAJO/ROL.txt")" == "$ROL" ]] || fallar 'Este usuario ya tiene asignado otro rol.'
fi
registrar "instalacion_offline_$ROL"
comprobar_gpu
driver="$(nvidia-smi -i 0 --query-gpu=driver_version --format=csv,noheader | tr -d '[:space:]')"
dpkg --compare-versions "$driver" ge 570.26 || fallar 'El controlador NVIDIA debe funcionar y ser 570.26 o posterior. El kit no lo instala.'
capacidad="$(nvidia-smi -i 0 --query-gpu=compute_cap --format=csv,noheader | tr -d '[:space:]')"
[[ "$capacidad" == 8.6 ]] || fallar 'Este kit compila para capacidad CUDA 8.6 (RTX 3060 Laptop).'
libre="$(df -Pk "$TRABAJO" | awk 'NR==2 {print $4}')"
(( libre >= 30 * 1024 * 1024 )) || fallar 'Reserva 30 GiB libres ADICIONALES al kit copiado.'
comprobar_kit

APT_LOCAL="$TRABAJO/apt_sin_internet"
mkdir -p "$APT_LOCAL/lists/partial"
printf 'deb [trusted=yes] file:%s ./\n' "$RAIZ_KIT" > "$APT_LOCAL/local.list"
APT=(-o "Dir::Etc::sourcelist=$APT_LOCAL/local.list" -o 'Dir::Etc::sourceparts=-'
     -o "Dir::State::lists=$APT_LOCAL/lists" -o "Dir::Cache::archives=$RAIZ_KIT/debs/"
     -o 'APT::Sandbox::User=root' -o 'Acquire::Languages=none'
     -o 'APT::Keep-Downloaded-Packages=true')
# Solo un repositorio file:, sin modificar los repositorios habituales del equipo.
sudo apt-get "${APT[@]}" update
INSTALAR=()
for paquete in "${PAQUETES[@]}"; do
    [[ "$ROL" != A || "$paquete" != openssh-server ]] || continue
    INSTALAR+=("$paquete")
done
sudo apt-get "${APT[@]}" --no-download --no-remove --no-install-recommends -s install "${INSTALAR[@]}" \
    | tee "$APT_LOCAL/plan.txt"
if grep -E '^Inst (nvidia-driver-|nvidia-dkms-|linux-image-|linux-modules-nvidia-)' "$APT_LOCAL/plan.txt"; then
    fallar 'El plan afectaria al controlador o kernel. No se aplica: revisa los registros.'
fi
sudo apt-get "${APT[@]}" --no-download --no-remove --no-install-recommends -y install "${INSTALAR[@]}"
"$CUDA_RAIZ/bin/nvcc" --version

# Ruta separada para no sobrescribir fuentes de una instalacion anterior.
FUENTE_OFFLINE="$TRABAJO/llama.cpp-offline-${LLAMA_COMMIT:0:12}"
if [[ -e "$FUENTE_OFFLINE" ]]; then
    [[ -f "$FUENTE_OFFLINE/ORIGEN_KIT.txt" && "$(cat "$FUENTE_OFFLINE/ORIGEN_KIT.txt")" == "$LLAMA_COMMIT" ]] || fallar 'La carpeta de fuentes offline ya existe sin identificacion. Conserva esa carpeta con otro nombre.'
else
    mkdir "$FUENTE_OFFLINE"
    tar -xzf "$RAIZ_KIT/fuentes/llama.cpp.tar.gz" --no-same-owner -C "$FUENTE_OFFLINE"
    mkdir -p "$FUENTE_OFFLINE/tools/ui/dist"
    tar -xzf "$RAIZ_KIT/fuentes/interfaz_chat.tar.gz" --no-same-owner -C "$FUENTE_OFFLINE/tools/ui/dist"
    printf '%s\n' "$LLAMA_COMMIT" > "$FUENTE_OFFLINE/ORIGEN_KIT.txt"
fi
[[ -f "$FUENTE_OFFLINE/tools/ui/dist/index.html" ]] || fallar 'Faltan los recursos del chat.'
cmake -S "$FUENTE_OFFLINE" -B "$FUENTE_OFFLINE/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_COMPILER="$CUDA_RAIZ/bin/nvcc" \
    -DCUDAToolkit_ROOT="$CUDA_RAIZ" -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DGGML_CUDA=ON -DGGML_RPC=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_APP=OFF \
    -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_BUILD_UI=OFF \
    -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DLLAMA_BUILD_COMMIT="$LLAMA_COMMIT"
cmake --build "$FUENTE_OFFLINE/build" --parallel 4 --target llama-server llama-cli ggml-rpc-server
"$FUENTE_OFFLINE/build/bin/llama-cli" --list-devices 2>&1 | tee "$TRABAJO/dispositivos_offline.txt"
grep -q CUDA0 "$TRABAJO/dispositivos_offline.txt" || fallar 'No se detecta CUDA0.'

# Los scripts 03-06 leen esta ruta solo despues de completar la compilacion.
printf '%s\n' "$FUENTE_OFFLINE" > "$TRABAJO/FUENTE_OFFLINE.txt"
printf '%s\n' "$LLAMA_COMMIT" > "$TRABAJO/BUILD_COMMIT.txt"
printf '%s\n' "$ROL" > "$TRABAJO/ROL.txt"
{
    date -Is
    printf 'Rol: %s\nRevision: %s\nInstalacion: kit sin Internet\n' "$ROL" "$LLAMA_COMMIT"
    "$FUENTE_OFFLINE/build/bin/llama-cli" --version
    "$CUDA_RAIZ/bin/nvcc" --version
    nvidia-smi -i 0 --query-gpu=name,memory.total,driver_version --format=csv
} > "$TRABAJO/entorno_$ROL.txt" 2>&1
if [[ "$ROL" == B ]]; then
    sudo systemctl start ssh
    systemctl is-active --quiet ssh || fallar 'No se pudo arrancar SSH.'
    printf 'Usuario de B: %s\n' "$(id -un)"
    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
fi
printf '\nINSTALACION SIN INTERNET TERMINADA EN %s.\n' "$ROL"
printf 'Utiliza los scripts de ~/kit_cluster_sin_internet/prueba_dos_portatiles.\n'
[[ "$ROL" != A ]] || printf 'En A, importa ahora el modelo con 03_importar_modelo_A.sh.\n'
