#!/usr/bin/env bash
# Ejecutar en un Ubuntu 22.04 conectado. No instala CUDA ni cambia el controlador.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun_offline.sh"
ubuntu_compatible
[[ "$#" -eq 0 ]] || fallar 'Uso: bash ./01_preparar_kit_con_internet.sh'
KIT="$HOME/kit_cluster_sin_internet"
CACHE="$HOME/.cache/cluster_preparacion_offline"
[[ "$KIT" != "$RAIZ_KIT" ]] || fallar 'Prepara desde la copia del repositorio, no desde el kit terminado.'
if [[ -d "$KIT" && ! -f "$KIT/REVISION_LLAMA.txt" ]]; then
    fallar 'Ya existe ~/kit_cluster_sin_internet sin identificacion. Renombralo antes de continuar.'
fi
if [[ -f "$KIT/REVISION_LLAMA.txt" ]]; then
    [[ "$(cat "$KIT/REVISION_LLAMA.txt")" == "$LLAMA_COMMIT" ]] || fallar 'Existe un kit de otra revision. Conserva esa carpeta con otro nombre.'
fi
mkdir -p "$KIT" "$CACHE"
libre="$(df -Pk "$KIT" | awk 'NR==2 {print $4}')"
(( libre >= 35 * 1024 * 1024 )) || fallar 'Reserva 35 GiB libres para preparar el kit, ademas de los archivos ya descargados.'
exec 9> "$CACHE/preparacion.lock"
flock -n 9 || fallar 'Ya hay otra preparacion en marcha.'
printf '%s\n' "$LLAMA_COMMIT" > "$KIT/REVISION_LLAMA.txt"
# Un kit interrumpido deja de declararse completo.
if [[ -f "$KIT/KIT_COMPLETO.txt" ]]; then mv "$KIT/KIT_COMPLETO.txt" "$CACHE/estado_anterior.txt"; fi
mkdir -p "$KIT/debs/partial" "$KIT/modelo" "$KIT/fuentes" "$KIT/prueba_dos_portatiles" "$KIT/sin_conexion"
cp "$RAIZ_KIT/prueba_dos_portatiles/"*.sh "$RAIZ_KIT/prueba_dos_portatiles/"*.py "$RAIZ_KIT/prueba_dos_portatiles/"*.env "$KIT/prueba_dos_portatiles/"
for extension in md html txt; do
    for archivo in "$RAIZ_KIT/prueba_dos_portatiles/"*."$extension"; do
        [[ ! -f "$archivo" ]] || cp "$archivo" "$KIT/prueba_dos_portatiles/"
    done
done
cp "$SCRIPTS_OFFLINE/"*.sh "$SCRIPTS_OFFLINE/"*.md "$KIT/sin_conexion/"
for archivo in "$SCRIPTS_OFFLINE/"*.html; do [[ ! -f "$archivo" ]] || cp "$archivo" "$KIT/sin_conexion/"; done
pdf="$RAIZ_KIT/output/pdf/manual-cluster-llm-portatiles.pdf"
[[ ! -f "$pdf" ]] || cp "$pdf" "$KIT/"

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl git cmake dpkg-dev
curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
    'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb' \
    --output "$CACHE/cuda-keyring.deb"
sudo dpkg -i "$CACHE/cuda-keyring.deb"

# Fuentes explicitas: Ubuntu Jammy y toolkit NVIDIA. No utilizar PPAs del preparador.
cat > "$CACHE/kit.sources.list" <<'SOURCES'
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb [arch=amd64 signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /
SOURCES
mkdir -p "$CACHE/lists/partial"
APT=(-o "Dir::Etc::sourcelist=$CACHE/kit.sources.list" -o 'Dir::Etc::sourceparts=-'
     -o "Dir::State::lists=$CACHE/lists" -o "Dir::Cache::archives=$KIT/debs/"
     -o 'APT::Sandbox::User=root' -o 'Acquire::Languages=none')
sudo apt-get "${APT[@]}" update
# Estado vacio SOLO para el resolvedor de descargas. No se modifica /var/lib/dpkg/status.
# Asi se obtienen tambien dependencias ya instaladas en el preparador.
: > "$CACHE/status-vacio"
sudo apt-get "${APT[@]}" -o "Dir::State::status=$CACHE/status-vacio" \
    -o "Dir::State::extended_states=$CACHE/extended_states" \
    --download-only --no-install-recommends -y install "${PAQUETES[@]}"
(cd "$KIT" && dpkg-scanpackages debs /dev/null > Packages)

FUENTE_KIT="$CACHE/llama-$LLAMA_COMMIT"
if [[ ! -d "$FUENTE_KIT" ]]; then
    git clone --depth 1 --branch "$LLAMA_TAG" https://github.com/ggml-org/llama.cpp.git "$FUENTE_KIT"
fi
[[ "$(git -C "$FUENTE_KIT" rev-parse HEAD)" == "$LLAMA_COMMIT" ]] || fallar 'Revision inesperada de llama.cpp.'
[[ -z "$(git -C "$FUENTE_KIT" status --porcelain --untracked-files=no)" ]] || fallar 'Las fuentes contienen cambios; conserva esa cache y revisa antes de seguir.'
git -C "$FUENTE_KIT" archive --format=tar.gz HEAD > "$KIT/fuentes/llama.cpp.tar.gz"

# El servidor necesita tambien los recursos del chat. El script oficial obtiene
# los assets y verifica su hash; se congelan dentro del kit para ambos equipos.
mkdir -p "$CACHE/ui"
cmake -DUI_SOURCE_DIR="$FUENTE_KIT/tools/ui" -DUI_BINARY_DIR="$CACHE/ui" \
    -DLLAMA_SOURCE_DIR="$FUENTE_KIT" -DHF_BUCKET=ggml-org/llama-ui \
    -DHF_VERSION="$LLAMA_TAG" -DHF_ENABLED=ON -DBUILD_UI=OFF -DLLAMA_UI_GZIP=ON \
    -P "$FUENTE_KIT/scripts/ui-assets.cmake" 2>&1 | tee "$KIT/fuentes/descarga_ui.txt"
[[ -f "$CACHE/ui/dist/index.html" ]] || fallar 'Falta la interfaz del chat. No se puede cerrar el kit.'
tar -czf "$KIT/fuentes/interfaz_chat.tar.gz" -C "$CACHE/ui/dist" .

MODELO_USB="$KIT/modelo/$MODEL_NAME"
if [[ ! -f "$MODELO_USB" ]]; then
    curl --fail --location --retry 5 --connect-timeout 30 --proto '=https' --proto-redir '=https' \
        --continue-at - --output "$MODELO_USB.part" \
        "https://huggingface.co/$MODEL_REPO/resolve/$MODEL_REVISION/$MODEL_NAME"
    [[ "$(stat -c '%s' "$MODELO_USB.part")" == "$MODEL_BYTES" ]] || fallar 'Tamano de modelo incorrecto.'
    [[ "$(sha256sum "$MODELO_USB.part" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]] || fallar 'Hash de modelo incorrecto.'
    mv "$MODELO_USB.part" "$MODELO_USB"
fi
[[ "$(sha256sum "$MODELO_USB" | cut -d ' ' -f 1)" == "$MODEL_SHA256" ]] || fallar 'Modelo existente con hash incorrecto.'
printf 'Kit preparado el %s. Ubuntu 22.04 amd64. No incluye controlador NVIDIA.\n' "$(date -Is)" > "$KIT/KIT_COMPLETO.txt"
(cd "$KIT" && find debs modelo fuentes prueba_dos_portatiles sin_conexion -type f ! -name lock -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$KIT" && sha256sum Packages REVISION_LLAMA.txt KIT_COMPLETO.txt >> SHA256SUMS
    if [[ -f manual-cluster-llm-portatiles.pdf ]]; then sha256sum manual-cluster-llm-portatiles.pdf >> SHA256SUMS; fi
    sha256sum --check --quiet SHA256SUMS)
printf '\nKIT PREPARADO: %s\n' "$KIT"
du -sh "$KIT"
printf 'Copia la carpeta completa al pendrive. Lee sin_conexion/LEEME.md.\n'
