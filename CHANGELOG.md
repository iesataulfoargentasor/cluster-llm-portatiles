# Cambios del proyecto

## Preparación de un kit de instalación sin Internet

- Nueva ruta en `sin_conexion`: preparación en Ubuntu 22.04 conectado, instalación local A/B e importación del modelo en A.
- Descarga de dependencias con un estado APT vacío para incluir también las ya instaladas en el preparador.
- Fuentes y recursos del chat incorporados; compilación offline con descargas de UI desactivadas.
- Repositorio APT local, comprobación SHA-256 y conservación del controlador existente.
- Guía independiente en Markdown y HTML. El PDF general mantiene la primera ruta de instalación con Internet.
- Pendiente validar esta nueva ruta en Ubuntu real. Los modelos y paquetes grandes no se publican en GitHub.

## Paquete para pendrive

- ZIP con manual PDF, hoja resumen, guías, scripts y herramienta de diagnóstico.
- Nota de inicio e inventario SHA-256 de los archivos incluidos.
- Empaquetador reproducible en `herramientas/preparar_zip.py`.
- Los pesos y dependencias siguen descargándose durante la preparación con Internet.

## Manual PDF para consulta sin Internet

- Manual de 34 páginas con índice enlazado y seis esquemas incrustados.
- Doce capítulos: contexto, hardware, arquitectura, comandos, guía completa, validación, ampliación, fuentes y anexos técnicos.
- Basado en la revisión documental f962ba4, edición del 23 de octubre de 2026.
- Diagramas largos distribuidos en dos tramos consecutivos para facilitar la lectura.
- Enlaces de visualización y descarga añadidos a la portada del repositorio.

## Primera edición documental

- Contexto docente, diagnóstico de hardware y decisiones de arquitectura.
- Prototipo de dos equipos con scripts 01 a 08, guía y hoja imprimible.
- Registro explícito de pruebas simuladas y trabajo pendiente en Ubuntu real.
- Esquemas de arquitectura, secuencia de consulta y futura ampliación a cuatro.
- Ficha de resultados y pautas para adaptar el proyecto a otros equipos.

Esta edición no incorpora mediciones reales de inferencia distribuida.
