#!/usr/bin/env python3
"""Red cableada del laboratorio: NetworkManager, Python 3 y ningun acceso web."""
import argparse
import datetime
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

SUBRED = ipaddress.ip_network("192.168.50.0/24")
IPS = {"A": "192.168.50.10/24", "B": "192.168.50.20/24"}
CARPETA = Path.home() / "cluster_llm" / "red"
ENTORNO = dict(os.environ, LC_ALL="C", LANG="C")


def ejecutar(args, aceptar_error=False):
    resultado = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, env=ENTORNO)
    if resultado.returncode and not aceptar_error:
        raise RuntimeError(resultado.stderr.strip() or resultado.stdout.strip()
                           or "El comando no se ha completado: " + args[0])
    return resultado


def nm(*args, cambiar=False, aceptar_error=False):
    orden = (["sudo", "-n"] if cambiar else []) + ["nmcli", "--colors", "no"]
    return ejecutar(orden + list(args), aceptar_error)


def valor(campo, *objeto):
    return nm("--escape", "no", "--get-values", campo, *objeto).stdout.strip()


def perfil_existe(identificador):
    return bool(identificador) and nm("connection", "show", "uuid", identificador,
                                     aceptar_error=True).returncode == 0


def propiedad(identificador, campo):
    return valor(campo, "connection", "show", "uuid", identificador)


def activo(interfaz):
    texto = valor("GENERAL.CON-UUID", "device", "show", interfaz)
    return texto if texto and texto != "--" else None


def guardar(ruta, datos):
    temporal = ruta.with_suffix(".tmp")
    with temporal.open("w", encoding="utf-8") as fichero:
        json.dump(datos, fichero, ensure_ascii=False, indent=2)
        fichero.write("\n")
        fichero.flush()
        os.fsync(fichero.fileno())
    temporal.replace(ruta)


def comprobar_interfaz(interfaz):
    if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,15}", interfaz):
        raise RuntimeError("Nombre de interfaz no valido.")
    dispositivo = Path("/sys/class/net") / interfaz
    if not dispositivo.exists() or not (dispositivo / "device").exists():
        raise RuntimeError(f"{interfaz} no es una interfaz fisica disponible. Consulta: nmcli device status")
    if valor("GENERAL.TYPE", "device", "show", interfaz) != "ethernet":
        raise RuntimeError("Selecciona una interfaz Ethernet, no Wi-Fi ni un puente.")
    if valor("GENERAL.NM-MANAGED", "device", "show", interfaz) != "yes":
        raise RuntimeError(f"NetworkManager no administra {interfaz}. No se ha cambiado su configuracion.")
    return Path("/etc/machine-id").read_text().strip()


def comprobar_solapamiento(interfaz):
    direcciones = json.loads(ejecutar(["ip", "-j", "-4", "address", "show"]).stdout)
    for dispositivo in direcciones:
        if dispositivo["ifname"] == interfaz:
            continue
        for dato in dispositivo.get("addr_info", []):
            red = ipaddress.ip_network(f'{dato["local"]}/{dato["prefixlen"]}', strict=False)
            if red.overlaps(SUBRED):
                raise RuntimeError(f"La subred {SUBRED} coincide con {dispositivo['ifname']}. "
                                   "Desconecta esa otra conexion antes de continuar.")
    rutas = json.loads(ejecutar(["ip", "-j", "-4", "route", "show", "table", "all"]).stdout)
    for ruta in rutas:
        destino = ruta.get("dst", "default")
        if destino == "default" or ruta.get("dev") == interfaz:
            continue
        if ipaddress.ip_network(destino, strict=False).overlaps(SUBRED):
            raise RuntimeError(f"Existe una ruta hacia {destino} por otra conexion. "
                               "Desconecta la VPN o conexion correspondiente antes de continuar.")


def subir(identificador, interfaz):
    print("Activando la conexion; puede tardar hasta 45 segundos...", flush=True)
    return nm("--wait", "45", "connection", "up", "uuid", identificador,
              "ifname", interfaz, cambiar=True, aceptar_error=True)


def comprobar_propiedad(datos, clave, nombre):
    identificador = datos.get(clave)
    if perfil_existe(identificador):
        if (propiedad(identificador, "connection.id") != datos[nombre]
                or propiedad(identificador, "connection.interface-name") != datos["interfaz"]
                or propiedad(identificador, "connection.type") != "802-3-ethernet"):
            raise RuntimeError("El perfil creado por el paquete ha cambiado de nombre, tipo o interfaz. "
                               "Revisa los perfiles de NetworkManager antes de continuar.")


def mostrar(interfaz):
    print(ejecutar(["ip", "-4", "-br", "address", "show", "dev", interfaz]).stdout.strip())


def configurar(rol, interfaz, ruta, datos, equipo):
    rol_instalado = Path.home() / "cluster_llm" / "ROL.txt"
    if rol_instalado.exists() and rol_instalado.read_text().strip() != rol:
        raise RuntimeError("El rol indicado no coincide con el utilizado en la instalacion.")
    comprobar_solapamiento(interfaz)
    try:
        enlace = (Path("/sys/class/net") / interfaz / "carrier").read_text().strip()
    except OSError:
        enlace = "0"
    if enlace != "1":
        raise RuntimeError("Conecta primero el cable al switch encendido.")
    if datos and datos["fase"] == "dhcp_pendiente":
        raise RuntimeError("Termina antes la restauracion: bash ./08_restaurar_dhcp.sh " + interfaz)
    if datos and datos["fase"] != "restaurado" and datos["rol"] != rol:
        raise RuntimeError("Este equipo ya tiene otro rol de red. Restaura DHCP antes de cambiarlo.")
    if not datos or datos["fase"] == "restaurado":
        anterior = activo(interfaz)
        datos = {
            "version": 1, "equipo": equipo, "interfaz": interfaz, "rol": rol,
            "fecha": datetime.datetime.now().isoformat(timespec="seconds"),
            "fase": "preparado", "anterior_uuid": anterior,
            "anterior_nombre": propiedad(anterior, "connection.id") if anterior else None,
            "anterior_metodo": propiedad(anterior, "ipv4.method") if anterior else None,
            "prueba_uuid": str(uuid.uuid4()), "prueba_nombre": f"Cluster-aislado-{rol}-{interfaz}",
        }
        # Se conservan los perfiles originales en NetworkManager y sus referencias aqui.
        guardar(ruta, datos)
    comprobar_propiedad(datos, "prueba_uuid", "prueba_nombre")
    if not perfil_existe(datos["prueba_uuid"]):
        nm("connection", "add", "type", "ethernet", "ifname", interfaz,
           "con-name", datos["prueba_nombre"], "connection.uuid", datos["prueba_uuid"],
           "connection.autoconnect", "no", "ipv4.method", "manual",
           "ipv4.addresses", IPS[rol], "ipv4.gateway", "", "ipv4.dns", "",
           "ipv4.never-default", "yes", "ipv4.dad-timeout", "1000",
           "ipv6.method", "disabled", cambiar=True)
    else:
        if (propiedad(datos["prueba_uuid"], "ipv4.addresses") != IPS[rol]
                or propiedad(datos["prueba_uuid"], "ipv4.method") != "manual"
                or propiedad(datos["prueba_uuid"], "connection.autoconnect") != "no"
                or propiedad(datos["prueba_uuid"], "ipv4.never-default") != "yes"
                or propiedad(datos["prueba_uuid"], "ipv6.method") != "disabled"
                or propiedad(datos["prueba_uuid"], "ipv4.gateway") not in ("", "--")
                or propiedad(datos["prueba_uuid"], "ipv4.dns") not in ("", "--")):
            raise RuntimeError("El perfil de prueba fue modificado. Ejecuta 08 antes de volver a configurarlo.")
    try:
        resultado = subir(datos["prueba_uuid"], interfaz)
        if resultado.returncode or activo(interfaz) != datos["prueba_uuid"]:
            raise RuntimeError(resultado.stderr.strip() or "No se pudo activar el perfil de prueba.")
        datos["fase"] = "aislado"
        guardar(ruta, datos)
    except (RuntimeError, OSError, KeyboardInterrupt):
        print("No se ha completado la activacion. Intentando recuperar la conexion anterior...", flush=True)
        if activo(interfaz) == datos["prueba_uuid"]:
            nm("--wait", "10", "connection", "down", "uuid", datos["prueba_uuid"],
               cambiar=True, aceptar_error=True)
        if perfil_existe(datos.get("anterior_uuid")):
            recuperacion = subir(datos["anterior_uuid"], interfaz)
            if recuperacion.returncode:
                print("La conexion anterior tampoco pudo activarse. Sus ajustes siguen guardados.")
        print("Puedes recuperar DHCP con: bash ./08_restaurar_dhcp.sh " + interfaz)
        raise
    print(f"\nPortatil {rol}: IP fija {IPS[rol]} en {interfaz}, sin puerta de enlace ni DNS.")
    print(f"Referencia del perfil anterior: {ruta}")
    mostrar(interfaz)
    print("Tras reiniciar, repite este comando para activar de nuevo la red de prueba.")


def restaurar(interfaz, ruta, datos):
    if not datos:
        raise RuntimeError("No hay una configuracion guardada para esta interfaz y usuario. "
                           "Utiliza el mismo usuario e interfaz del paso 07; no se ha cambiado la red.")
    comprobar_propiedad(datos, "prueba_uuid", "prueba_nombre")
    destino = datos.get("dhcp_uuid")
    if destino and not perfil_existe(destino):
        destino = None
    if not destino:
        anterior = datos.get("anterior_uuid")
        if perfil_existe(anterior) and propiedad(anterior, "ipv4.method") == "auto":
            destino = anterior
            datos["dhcp_creado"] = False
        else:
            destino = str(uuid.uuid4())
            datos["dhcp_creado"] = True
            datos["dhcp_nombre"] = "Cluster-DHCP-" + interfaz
        datos["dhcp_uuid"] = destino
        guardar(ruta, datos)
    if datos.get("dhcp_creado"):
        comprobar_propiedad(datos, "dhcp_uuid", "dhcp_nombre")
        if not perfil_existe(destino):
            nm("connection", "add", "type", "ethernet", "ifname", interfaz,
               "con-name", datos["dhcp_nombre"], "connection.uuid", destino,
               "connection.autoconnect", "yes", "ipv4.method", "auto",
               "ipv4.may-fail", "no", "ipv4.dhcp-timeout", "30",
               "ipv6.method", "auto", cambiar=True)
        print("Se utiliza un perfil DHCP separado. Los perfiles originales siguen conservados.")
    if propiedad(destino, "ipv4.method") != "auto":
        raise RuntimeError("El perfil de destino ha dejado de usar DHCP. Revisa su configuracion.")
    datos["fase"] = "dhcp_pendiente"
    guardar(ruta, datos)
    # Retirar expresamente el perfil de prueba, incluso si no hay servidor DHCP.
    if activo(interfaz) == datos["prueba_uuid"]:
        nm("--wait", "10", "connection", "down", "uuid", datos["prueba_uuid"], cambiar=True)
    if perfil_existe(datos["prueba_uuid"]):
        nm("connection", "delete", "uuid", datos["prueba_uuid"], cambiar=True)
    resultado = subir(destino, interfaz)
    direcciones = valor("IP4.ADDRESS", "device", "show", interfaz)
    if resultado.returncode or activo(interfaz) != destino or direcciones in ("", "--"):
        print("\nPerfil de IP fija de la prueba retirado. DHCP esta preparado, pero falta confirmar una IPv4.")
        if resultado.stderr.strip():
            print(resultado.stderr.strip())
        print("En el switch aislado esto es esperable: normalmente no hay servidor DHCP.")
        print("Conecta el cable a la red habitual y repite: bash ./08_restaurar_dhcp.sh " + interfaz)
        print("Si ya estas en esa red, revisa cable, acceso y posibles credenciales del centro.")
        mostrar(interfaz)
        return 2
    datos["fase"] = "restaurado"
    guardar(ruta, datos)
    print("\nConexion DHCP activa. Perfil fijo de la prueba eliminado.")
    mostrar(interfaz)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Configurar o retirar la red Ethernet aislada del cluster.")
    acciones = parser.add_subparsers(dest="accion", required=True)
    crear = acciones.add_parser("configurar", help="IP fija A o B en el switch aislado")
    crear.add_argument("rol", choices=("A", "B"))
    crear.add_argument("interfaz", nargs="?", default="eno1")
    volver = acciones.add_parser("dhcp", help="Retirar IP fija y activar DHCP")
    volver.add_argument("interfaz", nargs="?", default="eno1")
    args = parser.parse_args()
    if sys.platform != "linux":
        raise RuntimeError("Estos scripts se ejecutan en los portatiles Ubuntu del centro.")
    if os.geteuid() == 0:
        raise RuntimeError("Ejecuta el script como usuario normal, sin sudo delante.")
    if os.environ.get("SSH_CONNECTION") or os.environ.get("SSH_TTY"):
        raise RuntimeError("Ejecuta el script en una terminal local del portatil, no mediante SSH.")
    for herramienta in ("nmcli", "ip", "sudo"):
        if not shutil.which(herramienta):
            raise RuntimeError("Falta la herramienta " + herramienta + ". Prepara el equipo antes de aislarlo.")
    equipo = comprobar_interfaz(args.interfaz)
    os.umask(0o077)
    CARPETA.mkdir(parents=True, exist_ok=True)
    import fcntl
    # Una sola operacion de red del paquete a la vez por usuario.
    with (CARPETA / "operacion.lock").open("a") as bloqueo:
        try:
            fcntl.flock(bloqueo, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Ya hay otro script de red en marcha. Espera a que termine.")
        ruta = CARPETA / (args.interfaz + ".json")
        datos = json.loads(ruta.read_text(encoding="utf-8")) if ruta.exists() else None
        if datos:
            if (datos.get("version") != 1 or datos.get("equipo") != equipo
                    or datos.get("interfaz") != args.interfaz):
                raise RuntimeError("El registro de red no corresponde a este equipo o interfaz.")
            for clave in ("prueba_uuid", "anterior_uuid", "dhcp_uuid"):
                if datos.get(clave):
                    uuid.UUID(datos[clave])
            if datos["fase"] not in ("preparado", "aislado", "dhcp_pendiente", "restaurado"):
                raise RuntimeError("Estado de red guardado no reconocido.")
        print("Se modificara solo la conexion Ethernet " + args.interfaz + ".", flush=True)
        # La solicitud de sudo conserva su terminal para introducir la contrasena.
        subprocess.run(["sudo", "-v"], check=True)
        if args.accion == "configurar":
            configurar(args.rol, args.interfaz, ruta, datos, equipo)
            return 0
        return restaurar(args.interfaz, ruta, datos)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nOperacion interrumpida. Conserva ~/cluster_llm/red y repite el paso 08 para recuperar DHCP.", file=sys.stderr)
        sys.exit(130)
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("\nERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
