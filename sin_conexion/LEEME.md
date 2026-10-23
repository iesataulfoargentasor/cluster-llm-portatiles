# Instalación desde pendrive sin Internet

Esta ruta prepara los archivos en **un portátil Ubuntu 22.04 con Internet** y permite instalarlos después, sin conexión, en A y B. El kit se genera en Ubuntu; el ZIP pequeño de GitHub contiene instrucciones y scripts, pero no incluye los gigabytes de dependencias ni el modelo.

**Estado:** scripts revisados, sintaxis comprobada y decisiones de descarga, extracción y protección del controlador probadas con datos pequeños y comandos simulados. Pendiente ejecutar la preparación, la instalación APT y la compilación en Ubuntu real. La descarga completa no se ha realizado en el portátil personal Windows.

## Revisión antes de utilizar los portátiles (23 de octubre de 2026)

- Una descarga parcial que ya está completa se verifica y se aprovecha sin volver a pedir datos al servidor. Los archivos corruptos o demasiado grandes se rechazan y se conservan para su revisión.
- Las fuentes se extraen primero en una carpeta temporal. Si se interrumpe la extracción, se puede repetir: la carpeta definitiva todavía no existe. Las carpetas con sufijo `.extraccion.*` que hayan quedado de intentos fallidos se conservan; pueden retirarse manualmente tras comprobar una instalación correcta.
- La simulación APT bloquea cambios en el controlador NVIDIA, sus bibliotecas y paquetes del kernel, y rechaza un plan ausente. El toolkit CUDA sí está permitido.
- Si falla la generación o verificación del inventario, se retira la marca de kit completo al salir del script.
- Se han ejecutado 26 pruebas automatizadas: 14 de la ruta offline (incluida la sintaxis de todos los scripts) y 12 de la configuración de red simulada. No se han ejecutado APT, CUDA ni cambios de red reales durante esta revisión.

Estas pruebas no sustituyen la instalación en Ubuntu: todavía hay que comprobar que las dependencias descargadas resuelvan el estado concreto de A y B y que la compilación detecte sus GPU. Conserva acceso a Internet durante la preparación y no des por validado el kit hasta completar una instalación con la conexión desconectada.

## Requisitos y espacio

- Preparador y destinos: Ubuntu 22.04 x86_64, usuario con sudo. Los destinos deben ser Ubuntu Desktop con NetworkManager operativo.
- En A y B, `nvidia-smi` debe funcionar. El controlador debe ser 570.26 o posterior; el observado es 580.173.02. Se requiere capacidad CUDA 8.6. El kit instala toolkit, no controladores ni kernel.
- Se recomienda un pendrive de **64 GB**, exFAT o ext4. FAT32 no admite el GGUF de unos 9 GB. No se formatea ningún disco automáticamente. Comprueba el tamaño final del kit antes de copiarlo.
- En el preparador: al menos 35 GiB libres adicionales a las descargas existentes. En los destinos: espacio para copiar el kit y al menos 30 GiB adicionales para instalación, compilación y modelo local de A.
- Los dos equipos deben partir de instalaciones compatibles. Paquetes retenidos, PPAs, versiones más nuevas o sistemas dañados pueden requerir adaptar el kit. Llevar dependencias completas no garantiza resolver cualquier estado previo.

## Qué contiene el kit grande

| Carpeta o archivo | Contenido |
|---|---|
| `debs` y `Packages` | Repositorio local de paquetes Ubuntu y CUDA Toolkit 12.8 |
| `fuentes/llama.cpp.tar.gz` | Código de la revisión fijada |
| `fuentes/interfaz_chat.tar.gz` | Recursos del chat previamente descargados |
| `modelo` | Qwen3-14B Q4_K_M, tamaño y SHA-256 oficiales comprobados |
| `prueba_dos_portatiles` | Scripts de arranque, red y medición |
| `sin_conexion` | Preparación, instalación offline y esta guía |
| `SHA256SUMS` | Huellas para detectar descargas o copias incompletas |
| `KIT_COMPLETO.txt` | Marca de preparación finalizada |

Los paquetes proceden de Ubuntu Jammy, Jammy Updates, Jammy Security y el repositorio NVIDIA para Ubuntu 22.04. Durante la preparación, APT resuelve las dependencias con un estado de instalación vacío, exclusivamente para descargar: así no omite las que ya existen en el preparador. No se reemplaza el estado real de paquetes del sistema.

La interfaz del chat se obtiene con el script oficial de llama.cpp, que verifica su hash. Puede recurrir a la versión `latest` si no existe el recurso del tag solicitado. El kit congela lo descargado mediante sus huellas e incluye el registro `fuentes/descarga_ui.txt`; dos kits preparados en fechas distintas podrían tener recursos web diferentes. Usa el mismo kit para A y B.

## 1 Preparar con Internet

Descarga el repositorio actualizado en el portátil Ubuntu elegido. Estas instrucciones suponen que está en `~/cluster-llm-portatiles`. Si descargaste un ZIP de GitHub, renombra su carpeta extraída para que coincida. Si ya lo clonaste y no tienes cambios locales, puedes actualizarlo con `git -C "$HOME/cluster-llm-portatiles" pull --ff-only`.

Ejecuta desde una terminal local, sin sudo delante:

```bash
cd "$HOME/cluster-llm-portatiles/sin_conexion"
bash ./01_preparar_kit_con_internet.sh
```

El preparador instala utilidades de descarga y empaquetado, y añade el keyring/repositorio de NVIDIA. Descarga los paquetes y CUDA; no instala CUDA ni cambia el controlador. No hace falta asignarle un rol A o B para preparar.

La descarga puede tardar. No copies el kit hasta ver **KIT PREPARADO**. La carpeta resultante será `~/kit_cluster_sin_internet`. El script muestra su tamaño. Si se corta la descarga, repite el mismo comando: reutiliza la caché y reanuda el GGUF. Si un archivo completo falla por hash, consérvalo con otro nombre antes de volver a descargarlo.

La carpeta `~/.cache/cluster_preparacion_offline` es auxiliar y no se lleva al pendrive. El kit grande sí debe copiarse entero.

## 2 Copiar y comprobar el pendrive

Usa Archivos de Ubuntu para copiar `kit_cluster_sin_internet` al USB. Expúlsalo de forma segura al terminar. No combines carpetas de kits distintos.

En cada portátil de destino copia esa carpeta a la Carpeta personal. Debe quedar exactamente en `~/kit_cluster_sin_internet`. No ejecutes los instaladores directamente desde el USB.

Comprueba la copia:

```bash
cd "$HOME/kit_cluster_sin_internet"
sha256sum --check --quiet SHA256SUMS
```

Si no muestra errores y termina correctamente, las huellas coinciden. Leer el modelo de 9 GB puede tardar varios minutos. Si hay errores, vuelve a copiar y no instales. Si el preparador será también A o B, puede usar su kit ya generado sin copiarlo sobre sí mismo.

## 3 Instalar sin Internet

Desconecta Internet antes de esta comprobación real. Los instaladores usan un repositorio `file:` separado y APT con `--no-download`; conservan la configuración habitual de repositorios. La compilación desactiva la descarga de UI y utiliza los recursos incluidos.

**En A:**

```bash
cd "$HOME/kit_cluster_sin_internet/sin_conexion"
bash ./02_instalar_sin_internet.sh A
```

**En B:**

```bash
cd "$HOME/kit_cluster_sin_internet/sin_conexion"
bash ./02_instalar_sin_internet.sh B
```

Espera **INSTALACION SIN INTERNET TERMINADA** en ambos. El script comprueba los hashes, muestra un plan de paquetes, instala desde el disco local, compila cuatro tareas simultáneas y exige detectar CUDA0. B instala y arranca SSH. Se rechazan eliminaciones de paquetes y se detiene si el plan propone paquetes de controlador o kernel identificados por el filtro.

No hay una actualización general del sistema, pero APT puede actualizar bibliotecas necesarias para satisfacer los paquetes del kit. Si no puede resolver dependencias, conserva el registro y revisa el estado de ese equipo con Internet disponible en el preparador; no uses `--force-depends`, no añadas repositorios improvisados ni elimines paquetes al azar.

La instalación se guarda en `~/cluster_llm`, con fuentes en `llama.cpp-offline-620d2225cc43`. Los scripts actualizados reconocen `FUENTE_OFFLINE.txt`. Mantén el mismo usuario. No mezcles el instalador online 01 con esta ruta offline.

## 4 Importar el modelo solamente en A

```bash
cd "$HOME/kit_cluster_sin_internet/sin_conexion"
bash ./03_importar_modelo_A.sh
```

Se verifica el GGUF del kit, se copia a `~/cluster_llm/modelos` y se comprueba de nuevo. B no necesita importar el GGUF: recibirá sus tensores de A. La copia del kit en B contiene el modelo porque se distribuye un kit idéntico, aunque B no lo utiliza directamente.

## 5 Probar en el switch aislado

La preparación offline sustituye **01_instalar.sh** y **02_descargar_modelo_A.sh** de la guía original. No los ejecutes en esta ruta. A partir de aquí se utilizan los scripts 03 a 08 habituales, **desde la copia incluida en el kit**.

En cada nueva terminal:

```bash
cd "$HOME/kit_cluster_sin_internet/prueba_dos_portatiles"
```

Conecta los dos equipos al switch separado de la red habitual y desactiva Wi-Fi/VPN durante la prueba aislada.

| Orden | Equipo y terminal | Comando o acción |
|---|---|---|
| 1 | A | `bash ./07_configurar_red_aislada.sh A` |
| 2 | B | `bash ./07_configurar_red_aislada.sh B` |
| 3 | B | `whoami` y `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` |
| 4 | A | `ping -c 3 192.168.50.20` |
| 5 | B1 | `bash ./03_iniciar_rpc_B.sh` y dejar abierto |
| 6 | A1 | `bash ./04_abrir_tunel_A.sh USUARIO_B@192.168.50.20` y dejar abierto |
| 7 | A2 nueva | `bash ./05_iniciar_modelo_A.sh` y dejar abierto |
| 8 | Navegador en A | Esperar servidor listo y abrir `http://127.0.0.1:8080` |
| 9 | A3 nueva | `bash ./06_probar_A.sh` |
| 10 | Terminal extra en ambos | `watch -n 1 nvidia-smi` |

Sustituye USUARIO_B por el usuario real anotado. Compara la huella SSH antes de aceptarla. Si la interfaz Ethernet no es eno1, añade su nombre a 07, por ejemplo `bash ./07_configurar_red_aislada.sh B enp3s0`. Consulta la guía completa incluida para cortafuegos, falta de VRAM y errores de RPC. Los pasos online de esa guía quedan sustituidos por los de este documento.

## 6 Finalizar

1. Ctrl+C en A2 (modelo), después A1 (túnel) y B1 (RPC).
2. Conecta Ethernet a la red habitual con DHCP.
3. Desde la carpeta `prueba_dos_portatiles` del kit, ejecuta `bash ./08_restaurar_dhcp.sh` en ambos. Si usaste otra interfaz, añádela también a 08.
4. Si continúa en el switch aislado, DHCP puede quedar pendiente: conecta a la red habitual y repite.
5. Guarda registros y mediciones; restaura Wi-Fi, VPN y suspensión según tus preferencias.

En una sesión posterior no se reinstala ni se copia de nuevo el modelo. Se repite la sección 5. Conserva el kit para reinstalar dependencias y conserva `~/cluster_llm/red` para recuperar la configuración.

## Alcance y fuentes

Las huellas garantizan coherencia de las copias, no sustituyen la confianza en el equipo que prepara el kit. El repositorio local se declara confiable únicamente para las invocaciones de APT del instalador; no se modifica la confianza global de los repositorios habituales.

El PDF general incluido describe la primera ruta con Internet durante la instalación. **Para este kit, esta guía es la referencia de preparación e instalación.** El resto del manual sigue sirviendo como contexto, diagnóstico y explicación del clúster.

- [Guía oficial de CUDA 12.8](https://docs.nvidia.com/cuda/archive/12.8.1/cuda-installation-guide-linux/index.html).
- [Recursos web de llama.cpp en la revisión fijada](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/scripts/ui-assets.cmake).
- [Gestión de software sin conexión en Ubuntu](https://help.ubuntu.com/community/InstallingSoftware).
