# Hardware identificado y requisitos del prototipo

## Datos comprobados en un equipo

Síntesis de tres informes del mismo portátil, usando el último para el detalle de Ethernet. No representan tres nodos distintos.

| Elemento | Dato observado | Consecuencia |
|---|---|---|
| Sistema | Ubuntu 22.04.5 LTS | El instalador exige Ubuntu 22.04 x86_64 |
| CPU | Intel Core i7-12700H | Coordinación y tareas auxiliares |
| RAM | 32518660 kB de MemTotal, unos 31 GiB utilizables | Equipo de RAM nominal 32 GB |
| GPU | NVIDIA RTX 3060 Laptop | Backend CUDA |
| VRAM | 6144 MiB, 6 GiB | Presupuesto de memoria limitado |
| Controlador | 580.173.02 | Se conserva el controlador existente |
| Ethernet | 1000 Mb/s, Full Duplex | Límite práctico de la comunicación entre nodos |
| Interfaz | eno1 | Valor por defecto en los scripts de red |
| Modos del adaptador | 10, 100 y 1000 Mb/s | Un switch más rápido por sí solo no aumenta su enlace |

## Confirmar el segundo equipo

Conecta Ethernet al switch y ejecuta, desde la carpeta `herramientas` del repositorio:

```bash
bash ./recopilar_datos_cluster.sh
```

El informe queda en `~/informes_cluster`. Si falta `ethtool`, instálalo con Internet y repite la recopilación, como indica el script. Comprueba además `nvidia-smi` en los dos equipos antes de instalar. Los informes contienen nombres de equipo y datos de interfaces: revísalos antes de publicarlos.

## Memoria y espacio

Dos GPU iguales sumarían 12 GiB de VRAM nominal, distribuida entre dos dispositivos. El GGUF elegido ocupa 9.001.752.960 bytes en disco. Queda por comprobar el margen para caché de contexto, buffers, escritorio y otros procesos; el tamaño del archivo no representa todo el consumo de ejecución.

Los scripts requieren al menos 5000 MiB de VRAM libre por equipo antes del arranque. El contexto inicial es 4096; la guía ofrece 2048 si falta memoria. No se presupone que cuatro GPU de 6 GiB permitan cualquier modelo de 24 GiB: también necesitan memoria adicional y comunicación.

Reserva preferiblemente 40 GB de disco libres por portátil; el instalador exige al menos 30 GiB. A guarda el GGUF y B puede conservar caché de tensores. Mantén cargadores conectados y evita suspensión durante la sesión.

## Identificación local

Anota para cada nodo su etiqueta A o B, usuario de Ubuntu, interfaz Ethernet y espacio libre. No copies el estado `~/cluster_llm/red` entre máquinas. El segundo portátil debe documentarse antes de tratarlo como idéntico al primero.
