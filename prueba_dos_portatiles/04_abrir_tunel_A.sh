#!/usr/bin/env bash
# Uso: bash ./04_abrir_tunel_A.sh usuario_de_B@IPv4_de_B
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/comun.sh"
comprobar_usuario
exigir_rol A
exigir_compilacion
[[ "$#" -eq 1 ]] || fallar 'Uso: bash ./04_abrir_tunel_A.sh usuario_de_B@IPv4_de_B'
destino="$1"
[[ "$destino" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*@([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fallar 'Indica el usuario normal de B y su direccion IPv4 Ethernet, unidos con @.'
ip_b="${destino#*@}"
python3 - "$ip_b" <<'PY'
import ipaddress, json, pathlib, subprocess, sys
ip = ipaddress.IPv4Address(sys.argv[1])
if ip.is_loopback or ip.is_unspecified or ip.is_multicast:
    sys.exit('Utiliza la direccion Ethernet de B, no localhost.')
route = json.loads(subprocess.check_output(['ip', '-j', 'route', 'get', str(ip)]))[0]
dev = route.get('dev', '')
if not dev or dev == 'lo' or (pathlib.Path('/sys/class/net') / dev / 'wireless').exists():
    sys.exit('La ruta hacia B no utiliza Ethernet. Revisa el cable y la direccion introducida.')
print(f'Conexion hacia B por la interfaz {dev}, IP de origen {route.get("prefsrc", "no indicada")}.')
PY
exigir_puerto_libre 50052
printf '\nComprobando la version instalada en B. Puede pedir su contrasena.\n'
datos="$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=ask \
    -o HostKeyAlgorithms=ssh-ed25519 "$destino" \
    'cat "$HOME/cluster_llm/BUILD_COMMIT.txt" && cat "$HOME/cluster_llm/ROL.txt"')"
[[ "$datos" == "$LLAMA_COMMIT"$'\nB' ]] || fallar 'B debe tener el rol B y exactamente la misma revision de llama.cpp.'
printf '\nAbriendo el tunel. Puede pedir de nuevo la contrasena de B.\n'
printf 'Deja esta terminal abierta aunque no aparezca mas texto. Usa otra terminal de A para el paso 05.\n'
exec ssh -N -T -o ConnectTimeout=10 -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=ask -o HostKeyAlgorithms=ssh-ed25519 \
    -o ServerAliveInterval=20 -o ServerAliveCountMax=3 \
    -L 127.0.0.1:50052:127.0.0.1:50052 "$destino"
