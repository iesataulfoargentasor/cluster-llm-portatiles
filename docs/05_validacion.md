# Validación y registro de resultados

## Evidencias disponibles

| Comprobación | Estado |
|---|---|
| Diagnóstico de un portátil del centro | Completado, tres informes del mismo equipo |
| Diagnóstico del segundo portátil | Pendiente |
| Sintaxis Bash y Python del paquete | Comprobada en el entorno de preparación |
| Lectura SSE del cliente de medición | Simulada, respuesta completa y truncada |
| Lógica de red | 12 pruebas simuladas superadas |
| IP fija y DHCP en Ubuntu real | Pendiente |
| Compilación CUDA en los equipos | Pendiente |
| Descarga y hash del archivo real | Pendiente en A |
| Carga distribuida, VRAM y velocidad | Pendiente |

Las simulaciones bloquean la ejecución de procesos externos y sustituyen NetworkManager y datos del sistema. Cubren IP de A/B, repetición, cambio de rol, recuperación de fallo, DHCP previo, perfil previo manual, DHCP ausente y reintento, perfil alterado, falta de estado, nombre alterado y rechazo en Windows. No reproducen el comportamiento completo de Ubuntu ni de NetworkManager.

Para repetir estas pruebas desde la raíz del repositorio, con Python 3:

```bash
python3 tests/test_red_simulada.py
```

## Qué debe demostrar la sesión en el centro

1. Los dos equipos cumplen los requisitos y compilan la misma revisión.
2. A y B se comunican por Ethernet con las IP previstas.
3. A detecta su CUDA local y la GPU RPC remota.
4. El registro de carga menciona memoria de modelo en ambas GPU.
5. La consulta devuelve una respuesta y se guarda un resultado JSON.
6. La prueba se repite sin modificar contexto, modelo ni condiciones.
7. Se detienen los servicios de prueba y se recupera DHCP.

## Ficha para copiar en una nueva sesión

```text
Fecha y responsable:
Commit de este repositorio:
Modelo, revisión y SHA-256:
Revisión de llama.cpp:
GPU / VRAM libre antes del arranque en A y B:
RAM y versión Ubuntu en A y B:
Controlador NVIDIA / CUDA Toolkit:
Ethernet y velocidad negociada en A y B:
Contexto: 4096 / 2048
Caché RPC: primera carga / reutilizada
Tiempo de carga del modelo (medido aparte):
VRAM ocupada en A / B tras cargar:
Consulta 1: primer texto / tiempo total / tokens por segundo:
Consulta 2: primer texto / tiempo total / tokens por segundo:
Consulta 3: primer texto / tiempo total / tokens por segundo:
Otros programas, temperatura, incidencias:
IP fija y vuelta a DHCP: resultado en A / B:
Conclusión y siguiente cambio propuesto:
```

Guarda `~/cluster_llm/resultados`, los registros de modelo de A y RPC de B, y `entorno_A.txt` / `entorno_B.txt`. Revisa consultas e identificadores antes de compartirlos. No rellenes campos pendientes con estimaciones.

Compara tiempo de carga, espera hasta el primer texto y velocidad de generación por separado. Si se quiere evaluar una mejora de velocidad frente a un solo equipo, primero hay que definir una configuración de referencia que realmente pueda ejecutarse en ese equipo y documentar cualquier uso de CPU.
