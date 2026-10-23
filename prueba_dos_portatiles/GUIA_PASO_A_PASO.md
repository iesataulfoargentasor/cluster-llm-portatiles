# Prueba de Qwen3 entre dos portátiles Ubuntu

Esta guía permite repartir Qwen3-14B Q4_K_M entre dos portátiles con Ubuntu 22.04, NVIDIA RTX 3060 Laptop de 6 GB, 32 GB de RAM y Ethernet Gigabit. El portátil **A coordina el modelo y muestra el chat**. El portátil **B aporta su GPU**. Ambos calculan partes del mismo modelo.

La configuración inicial utiliza 4096 tokens de contexto, una conversación, caché de contexto Q8 y reparto por capas. La capacidad prevista debe confirmarse en los equipos: todavía no hay una medición real de velocidad ni una ejecución de este paquete en esos portátiles.

## 1. Qué necesitas y qué instala el paquete

- Dos portátiles con la configuración anterior. Solo tenemos un informe de hardware; comprueba también el segundo con `nvidia-smi` antes de instalar.
- Usuario normal con permisos de `sudo` en cada equipo. Los nombres de usuario pueden ser distintos.
- Cargadores conectados, tapas abiertas y suspensión automática desactivada temporalmente durante la prueba desde Configuración → Energía. Restaura después tu preferencia habitual.
- Cable Ethernet desde cada portátil al switch. La prueba usa la dirección cableada de B.
- Internet durante la instalación y la descarga inicial. Después se puede trabajar sin Internet.
- Recomendación de 40 GB libres en cada equipo para herramientas, compilación, modelo o caché. El instalador pide al menos 30 GiB libres al empezar.

Los scripts guardan sus archivos en `~/cluster_llm`. Instalan herramientas de compilación y, si falta, CUDA Toolkit 12.8 desde el repositorio oficial NVIDIA. Utilizan el controlador NVIDIA que ya existe; el equipo informado tiene 580.173.02. B incorpora el servidor OpenSSH. La instalación de paquetes puede pedir la contraseña de sudo.

Ejecuta los scripts con `bash`, como usuario normal. No pongas `sudo` delante del script completo. Los pasos que necesitan privilegios ya lo solicitan internamente.

**Versiones fijadas:** llama.cpp v0.7.0, revisión `620d2225cc436ab0b001e3200e590e3b286ef9ab`; CUDA Toolkit 12.8; modelo oficial Qwen3-14B Q4_K_M, revisión `530227a7d994db8eca5ab5ced2fb692b614357fd`. `versiones.env` contiene también el tamaño y la huella SHA-256 del modelo. Copia el mismo paquete a los dos equipos.

## 2. Copiar el paquete e identificar A y B

Descomprime el ZIP. Copia la carpeta completa `prueba_dos_portatiles` a la Carpeta personal de cada portátil. Deben quedar juntos los archivos numerados del 01 al 08, `comun.sh`, `versiones.env`, `probar_modelo.py` y `red_cluster.py`.

En todas las terminales que abras para estos pasos, entra primero en esa carpeta:

```bash
cd "$HOME/prueba_dos_portatiles"
```

Anota qué portátil será A y cuál será B. Puedes poner una etiqueta física. Mantén el mismo usuario de Ubuntu durante toda la prueba en cada portátil: los archivos se guardan en su carpeta personal.

| Equipo | Función | Qué mantendrás abierto durante la prueba |
|---|---|---|
| A coordinador | GPU local, modelo y chat | Terminal del túnel, terminal del modelo y navegador |
| B remoto | GPU remota | Terminal de RPC |

## 3. Instalar en ambos equipos

**En A**, con Internet:

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./01_instalar.sh A
```

**En B**, con Internet:

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./01_instalar.sh B
```

Puedes instalar en ambos a la vez. La descarga del toolkit y la compilación pueden tardar. El proceso utiliza cuatro tareas de compilación para moderar el consumo de RAM. Si se interrumpe, repite el mismo comando: reutiliza los archivos descargados y el directorio de compilación.

**Resultado esperado:** el listado final incluye `CUDA0` y aparece “Instalacion terminada”. Si falla un paso, el script se detiene y señala el registro correspondiente. No continúes hasta completar la instalación en ambos.

En B, el instalador muestra el usuario, las direcciones de red y la huella de su clave SSH. Conserva estos datos. Ubuntu 22.04 utiliza el servicio `ssh`.

## 4. Descargar el modelo únicamente en A

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./02_descargar_modelo_A.sh
```

La descarga es de **9.001.752.960 bytes**, aproximadamente 9 GB decimales. El archivo final queda en `~/cluster_llm/modelos/Qwen3-14B-Q4_K_M.gguf`. Al terminar, el script comprueba su tamaño y SHA-256. Si la conexión se corta, repite el comando para reanudar la descarga.

B recibirá del coordinador los pesos que necesita y podrá conservarlos en una caché local. No descargues una segunda copia completa del GGUF en B.

## 5. Comprobar las direcciones Ethernet

En ambos portátiles, ejecuta:

```bash
ip -4 -br address
```

En el equipo informado, Ethernet es `eno1`. Anota la IPv4 de esa interfaz en A y B, sin el sufijo `/24` u otro prefijo. No utilices la dirección de `wlp...`, `docker0` o `lo`.

En B también puedes recuperar el usuario y la huella SSH:

```bash
whoami
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Ejemplo ilustrativo: A tiene `192.168.50.10`, B tiene `192.168.50.20` y el usuario de B es `alumno`. Sustituye estos datos por los reales. Los dos equipos deben poder comunicarse por la red cableada del laboratorio.

Si el switch está aislado y no hay servidor DHCP, ejecuta ahora el script 07 siguiendo el apartado 13, después de terminar las descargas. Después vuelve al paso 6. Un switch por sí solo normalmente no asigna direcciones IP.

## 6. Arrancar la GPU remota en B

**En una terminal de B:**

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./03_iniciar_rpc_B.sh
```

**Resultado esperado:** aparecen la RTX 3060, `CUDA0` y el endpoint `127.0.0.1:50052`. El programa queda esperando. Deja la terminal abierta.

RPC escucha exclusivamente dentro de B. La comunicación desde A llegará mediante SSH. No abras el puerto 50052 en el cortafuegos ni cambies la dirección a `0.0.0.0` para esta prueba. RPC sigue siendo experimental; utiliza el entorno de laboratorio y consultas de prueba.

## 7. Abrir el túnel desde A hacia B

**En la primera terminal de A**, usa el usuario y la IPv4 Ethernet reales de B. Por ejemplo:

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./04_abrir_tunel_A.sh alumno@192.168.50.20
```

La primera vez SSH mostrará una huella. Compárala con la que muestra B; si coincide, acepta escribiendo `yes`. Introduce la contraseña del usuario de B. Es normal que no se vea nada al escribirla.

El script comprueba la versión de llama.cpp de B y después abre el túnel; puede pedir la contraseña una segunda vez. Cuando quede abierto puede no mostrar más texto. **Mantén esta terminal abierta y utiliza otra para el paso siguiente.**

El tráfico sigue este recorrido: A → SSH por Ethernet → B → servicio RPC local de B. El cifrado de SSH añade cierto trabajo; las mediciones corresponden a este montaje concreto.

Si SSH no conecta, en B comprueba `sudo systemctl status ssh`. Si el servicio está parado, ejecuta `sudo systemctl start ssh`.

Si el cortafuegos UFW de B está activo y bloquea SSH, permite únicamente la IP de A. Ejemplo, sustituyendo la dirección por la real:

```bash
sudo ufw status
sudo ufw allow from 192.168.50.10 to any port 22 proto tcp
```

La regla solo es necesaria si el cortafuegos está bloqueando el acceso. No desactives el cortafuegos. Si hay filtrado de red del centro, debe permitir SSH de A a B.

## 8. Arrancar el modelo en A

**En una segunda terminal de A:**

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./05_iniciar_modelo_A.sh
```

El script exige que aparezcan la GPU CUDA local y el dispositivo RPC remoto antes de cargar el modelo. Usa 4096 tokens de contexto, una conversación y reparto 1:1 por capas. Solicita que todas las capas que se pueden descargar a GPU se repartan entre ambas; desactiva el ajuste automático para que un cambio silencioso a CPU no altere la prueba.

**Espera a que termine la carga y el servidor esté listo.** La primera carga tiene que transferir pesos a B y puede tardar varios minutos. Durante ese periodo la página puede mostrar que el modelo se está cargando. Mantén también abiertas las terminales de los pasos 6 y 7.

Abre en el navegador de **A**:

```text
http://127.0.0.1:8080
```

Escribe una consulta breve en español. El razonamiento prolongado se desactiva para esta prueba inicial. El chat escucha solo dentro de A; esa misma dirección en B no abre el chat de A.

## 9. Confirmar que participan las dos GPU

En una terminal adicional de **cada portátil**, ejecuta:

```bash
watch -n 1 nvidia-smi
```

Al terminar la carga debes ver varios GB de VRAM ocupados en ambas GPU. Mientras se genera una respuesta puede aumentar la actividad en momentos distintos: el reparto por capas implica dependencias entre los cálculos. No es necesario que ambas indiquen 100 % de uso simultáneamente.

Revisa también el registro de arranque de A: debe mencionar buffers del modelo en CUDA local y RPC, y las capas descargadas a GPU. La presencia de algún buffer CPU o memoria mapeada, por sí sola, no significa que toda la inferencia se esté ejecutando en CPU.

Para abandonar `watch`, pulsa Ctrl+C; esto no detiene el modelo.

## 10. Ejecutar una consulta con medición

**En una tercera terminal de A**, cuando el servidor esté listo:

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./06_probar_A.sh
```

Envía una consulta breve, muestra la respuesta y guarda un JSON en `~/cluster_llm/resultados`. Recoge:

- Tiempo desde el envío hasta el primer texto recibido por el cliente.
- Tiempo total de la consulta, sin incluir el arranque del modelo.
- Tokens por segundo comunicados por el servidor, si están presentes.
- Texto de la respuesta, uso de tokens y motivo de finalización.

La salida está limitada a 256 tokens. Si alcanza ese límite, se indica en pantalla. Una consulta breve comprueba el funcionamiento; para comparar rendimiento conviene repetirla tres veces con la misma configuración y conservar todos los resultados. No uses el chat simultáneamente mientras mides.

La primera carga del modelo, el tiempo hasta el primer texto y la velocidad de generación son medidas distintas. Un resultado favorable en una consulta corta no garantiza lo mismo con documentos largos o varios usuarios.

## 11. Detener y volver a arrancar

Detén en este orden, pulsando Ctrl+C en la terminal correspondiente:

1. **A:** servidor del modelo, paso 05.
2. **A:** túnel SSH, paso 04.
3. **B:** servidor RPC, paso 03.

Si utilizaste las IP fijas del apartado 13, ejecuta ahora el script 08 en cada portátil para volver a DHCP. Hazlo desde una terminal local, después de detener los tres procesos anteriores.

Para volver a utilizarlo otro día, conecta ambos portátiles al switch aislado, repite 07 en cada uno y después los pasos 03, 04 y 05, en ese orden. Repite 06 si quieres otra medición. La instalación y la descarga se conservan. Si utilizas una red que ya asigna IP por DHCP, basta con comprobar las direcciones y arrancar 03, 04 y 05.

El servicio SSH instalado en B puede seguir activo. Si se instaló únicamente para esta prueba y nadie más lo utiliza, puedes pararlo con `sudo systemctl stop ssh`. Para la siguiente sesión arráncalo con `sudo systemctl start ssh`. No pares SSH si el centro lo utiliza para administrar ese equipo.

Si añadiste la regla UFW de ejemplo y ya no la necesitas, elimínala con la misma IP que utilizaste:

```bash
sudo ufw delete allow from 192.168.50.10 to any port 22 proto tcp
```

## 12. Problemas habituales

| Mensaje o síntoma | Qué hacer |
|---|---|
| `nvidia-smi` falla | Resolver primero el controlador NVIDIA. No ejecutar la instalación con una GPU que no se detecta. |
| El segundo equipo no tiene una RTX de capacidad CUDA 8.6 | Detenerse y revisar su informe. Este paquete está compilado para el hardware identificado. |
| Error al instalar paquetes | Revisar Internet, espacio y repositorios. Conservar el registro; no cambiar controladores ni repositorios al azar. |
| Compilación finalizada por falta de memoria | Cerrar aplicaciones y repetir. Se puede cambiar `--parallel 4` por `--parallel 2` en el instalador. |
| `Permission denied` al conectar por SSH | Comprobar usuario y contraseña de B. Si el centro exige claves SSH, usar las credenciales permitidas por su configuración. |
| SSH muestra que ha cambiado la clave del equipo | Verificar la IP y la huella en B. No desactivar la comprobación de claves. |
| `Connection refused` en RPC | Mantener abierto 03 en B y 04 en A. Revisar que 03 no haya terminado con error. |
| Puerto 50052 o 8080 ocupado | Cerrar la terminal de la ejecución anterior o identificar el proceso con `ss -ltnp`. Los scripts no matan procesos automáticamente. |
| No aparece la GPU RPC | Comprobar túnel, servicio de B y misma versión. Conservar las salidas de ambos equipos. |
| Menos de 5000 MiB de VRAM libres | Cerrar otras aplicaciones que utilicen NVIDIA. Consultar los procesos en `nvidia-smi`. |
| `out of memory` al cargar | Detener A, reiniciar RPC en B si se cerró, y volver a iniciar A con contexto reducido como se indica debajo. |
| El modelo carga pero va lento | Medir primero; revisar uso de GPU, conexión Gigabit, temperatura, cargadores y aplicaciones concurrentes. |
| Huella SHA-256 incorrecta | Conservar el archivo para revisar. Si repites desde cero, renombra solo ese GGUF o su `.part`; no borres carpetas del proyecto. |
| Una descarga parcial no se puede reanudar | Renombrar el `.part` afectado y repetir 02 para iniciar una descarga nueva, con espacio suficiente. |
| El script 07 no encuentra `eno1` | Consultar `nmcli device status` y pasar el nombre de la interfaz Ethernet como segundo argumento, después de A o B. |
| La subred coincide con otra conexión | Desconectar temporalmente la Wi-Fi o VPN indicada. No modificar Docker ni otras redes sin identificar el conflicto. |
| El script 08 deja DHCP pendiente | Conectar a una red con servidor DHCP y repetir 08. Un switch aislado normalmente no ofrece ese servicio. |
| El script 08 no encuentra la configuración guardada | Usar el mismo usuario y la misma interfaz que en 07. Conservar `~/cluster_llm/red`; el script no modifica perfiles sin ese registro. |
| `$'\r'` o errores al principio del script | Volver a extraer el ZIP original. Los archivos se entregan con saltos de línea Linux; algunos editores de Windows pueden cambiarlos. |

Para reducir la memoria de contexto, detén el modelo de A y ejecuta:

```bash
bash ./05_iniciar_modelo_A.sh 2048
```

Si sigue fallando con ambas GPU libres, guarda los registros antes de modificar el reparto o enviar capas a CPU: ese cambio alteraría lo que estamos midiendo.

## 13. Switch aislado sin servidor DHCP

Este apartado utiliza los scripts 07 y 08 incluidos en el paquete. Termina antes la instalación y la descarga con Internet. Ambos scripts funcionan sin Internet y utilizan NetworkManager, presente normalmente en Ubuntu Desktop, y Python 3.

**Preparar el cableado:** conecta los dos portátiles a un switch encendido y separado de la red del centro. Desactiva temporalmente Wi-Fi y VPN desde Ubuntu si quieres que los equipos queden aislados también por esas conexiones. Los scripts actúan únicamente sobre la interfaz Ethernet indicada.

Ejecuta los comandos desde el teclado de cada portátil, con tu usuario habitual y sin `sudo` delante. El script pedirá la contraseña cuando la necesite. Rechaza su ejecución dentro de una sesión SSH para evitar cortar esa sesión.

**En A:**

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./07_configurar_red_aislada.sh A
```

**En B:**

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./07_configurar_red_aislada.sh B
```

Por defecto usan `eno1`, la interfaz del equipo informado. Si el segundo portátil tiene otro nombre, consúltalo con `nmcli device status` y añade ese nombre. Ejemplo: `bash ./07_configurar_red_aislada.sh B enp3s0`. Debe ser una interfaz física de tipo Ethernet administrada por NetworkManager.

La configuración queda así:

| Campo | Portátil A | Portátil B |
|---|---|---|
| Dirección | `192.168.50.10` | `192.168.50.20` |
| Máscara | `255.255.255.0` | `255.255.255.0` |
| Puerta de enlace | Vacía | Vacía |
| DNS | Vacío | Vacío |

El script crea un perfil de prueba separado y conserva los perfiles anteriores en NetworkManager. Guarda la referencia del perfil que estaba activo y el estado de la operación en `~/cluster_llm/red/eno1.json` (el nombre cambia si utilizas otra interfaz). No borres esa carpeta ni la copies de un portátil al otro. El registro no es una copia completa de los perfiles: estos siguen guardados en NetworkManager.

Antes de aplicar la IP, comprueba conflictos con subredes de otras interfaces y solicita a NetworkManager detectar una dirección duplicada en el cable. Estas comprobaciones no garantizan que el switch esté físicamente aislado: asegúrate del cableado. Si falla la activación, intenta recuperar el perfil que estaba activo.

**Comprobar la comunicación desde A:**

```bash
ping -c 3 192.168.50.20
```

Si no responde, comprueba cable, IP y cortafuegos; algunos cortafuegos pueden filtrar ping aunque SSH funcione. Continúa en el paso 6 y utiliza `192.168.50.20` para B. El usuario de SSH será el usuario real de B.

**Volver a DHCP al terminar, en ambos portátiles:**

1. Detén modelo, túnel y RPC como indica el apartado 11.
2. Conecta el cable Ethernet a la red habitual que disponga de DHCP.
3. Ejecuta el siguiente comando en una terminal local de cada portátil:

```bash
cd "$HOME/prueba_dos_portatiles"
bash ./08_restaurar_dhcp.sh
```

Si utilizaste otra interfaz, indícala también aquí: `bash ./08_restaurar_dhcp.sh enp3s0`.

El script retira el perfil de IP fija de la prueba y vuelve a activar el perfil anterior si usaba DHCP. Si antes utilizabas una IP manual o no había perfil activo, crea un perfil DHCP independiente y conserva el anterior. Una red con autenticación especial puede requerir seleccionar el perfil habitual desde Configuración → Red; el script no configura credenciales del centro.

**Si ejecutas 08 todavía en el switch aislado:** retira el perfil fijo y prepara DHCP, pero probablemente no obtendrá dirección. Puede tardar hasta 45 segundos y terminar con un aviso de DHCP pendiente (código de salida 2). Conecta después a la red habitual y repite exactamente el comando 08. El mensaje “Conexión DHCP activa” solo aparece cuando la activación termina y hay una IPv4 en la interfaz; no acredita acceso a Internet.

Puedes repetir 07 con el mismo rol y 08 sin acumular perfiles de prueba. Tras reiniciar un portátil, vuelve a ejecutar 07 para activar sus IP de laboratorio: ese perfil tiene la conexión automática desactivada. Al terminar, vuelve a activar Wi-Fi o VPN si las habías desactivado.

## 14. Qué resultados conservar del laboratorio

Copia desde **A** la carpeta `~/cluster_llm/resultados`, el último registro `modelo_A_...log` y `~/cluster_llm/entorno_A.txt`. Desde **B**, copia el último `rpc_B_...log` y `~/cluster_llm/entorno_B.txt`. Los registros están en `~/cluster_llm/logs`.

Anota en la ficha de resultados si utilizaste contexto 4096 o 2048 y si había otros programas abiertos. Los registros pueden contener consultas: para esta primera práctica utiliza texto de ejemplo.

## Referencias y alcance de la comprobación

- [Versión fijada de llama.cpp](https://github.com/ggml-org/llama.cpp/releases/tag/v0.7.0).
- [RPC en la revisión utilizada](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/tools/rpc/README.md).
- [Opciones de llama-server en esa revisión](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/tools/server/README.md).
- [CUDA 12.8 para Linux](https://docs.nvidia.com/cuda/archive/12.8.1/cuda-installation-guide-linux/index.html).
- [Modelo oficial y revisión fijada](https://huggingface.co/Qwen/Qwen3-14B-GGUF/tree/530227a7d994db8eca5ab5ced2fb692b614357fd).
- [NetworkManager: gestión de perfiles con nmcli](https://networkmanager.dev/docs/api/latest/nmcli.html).
- [NetworkManager: IP manual, DHCP y detección de direcciones duplicadas](https://networkmanager.dev/docs/api/latest/settings-ipv4.html).

La preparación se basa en el informe del portátil de referencia y en documentación y código oficiales. Las comprobaciones locales del paquete se describen en `COMPROBACIONES.txt`. La instalación real, el reparto en las RTX 3060 y el rendimiento por Ethernet se comprobarán al ejecutar estos pasos en el centro.
