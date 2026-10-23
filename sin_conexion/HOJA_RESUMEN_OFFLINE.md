# Hoja resumen: instalación y prueba sin Internet

Ubuntu 22.04 LTS, RTX 3060 Laptop de 6 GiB, roles A y B. Esta hoja sustituye los pasos de instalación conectada de la hoja original. Lee primero la guía offline para requisitos, espacio y recuperación de errores. No ejecutes los scripts completos con sudo.

## 1 Preparador Ubuntu con Internet (puede ser A o B)

Extrae el ZIP actualizado en la Carpeta personal. Debe existir `~/cluster-llm-portatiles/sin_conexion`.

```bash
cd "$HOME/cluster-llm-portatiles/sin_conexion"
bash ./01_preparar_kit_con_internet.sh
```

Espera KIT PREPARADO. Copia la carpeta completa `~/kit_cluster_sin_internet` al pendrive y después a la Carpeta personal de A y B. Si el preparador es uno de ellos, usa su carpeta ya generada. No mezcles versiones. El ZIP pequeño por sí solo no permite instalar sin Internet.

## 2 A y B: comprobar la copia; después desconectar Internet

```bash
cd "$HOME/kit_cluster_sin_internet"
sha256sum --check --quiet SHA256SUMS
```

No continúes si aparecen errores. Desconecta Internet para validar la instalación offline.

## 3 Instalar en A

```bash
cd "$HOME/kit_cluster_sin_internet/sin_conexion"
bash ./02_instalar_sin_internet.sh A
bash ./03_importar_modelo_A.sh
```

## 4 Instalar en B

```bash
cd "$HOME/kit_cluster_sin_internet/sin_conexion"
bash ./02_instalar_sin_internet.sh B
```

## 5 Switch aislado: orden de terminales

Conecta ambos al switch aislado. Desactiva Wi-Fi/VPN. En cada terminal nueva de A o B:

```bash
cd "$HOME/kit_cluster_sin_internet/prueba_dos_portatiles"
```

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


Sustituye USUARIO_B por el usuario anotado y comprueba la huella SSH. Si Ethernet no es eno1, añade la interfaz real a 07 y 08. Deja B1, A1 y A2 abiertos durante la prueba.

## 6 Terminar y volver a DHCP (ambos)

Pulsa Ctrl+C en A2, después A1 y B1. Conecta Ethernet a la red habitual con DHCP. En ambos:

```bash
cd "$HOME/kit_cluster_sin_internet/prueba_dos_portatiles"
bash ./08_restaurar_dhcp.sh
```

Guarda los registros. Restablece Wi-Fi/VPN según proceda. La siguiente sesión empieza en el paso 5; no es necesario reinstalar. La instalación y la inferencia reales en los equipos del centro siguen pendientes de validación.
