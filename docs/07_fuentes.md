# Fuentes y versiones

## Material del proyecto

- Conversación de diseño: necesidad de modelos locales, diagnóstico, prototipo, uso aislado y retorno a DHCP.
- Tres informes del mismo portátil, fechados el 23 de octubre de 2026. Se publica su síntesis técnica, conservando los originales fuera del repositorio.
- Artículo Word aportado como referencia: “How to run ONE LLM model across different machines”. No se redistribuye su contenido ni se le atribuyen pruebas de este hardware.
- Scripts, guía y comprobaciones conservados en `prueba_dos_portatiles`.

## Referencias primarias

- [llama.cpp v0.7.0](https://github.com/ggml-org/llama.cpp/releases/tag/v0.7.0).
- [RPC en la revisión elegida](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/tools/rpc/README.md).
- [Servidor de llama.cpp en esa revisión](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/tools/server/README.md).
- [CUDA 12.8 para Linux](https://docs.nvidia.com/cuda/archive/12.8.1/cuda-installation-guide-linux/index.html).
- [Qwen3-14B GGUF en la revisión elegida](https://huggingface.co/Qwen/Qwen3-14B-GGUF/tree/530227a7d994db8eca5ab5ced2fb692b614357fd).
- [NetworkManager nmcli](https://networkmanager.dev/docs/api/latest/nmcli.html).
- [NetworkManager IPv4](https://networkmanager.dev/docs/api/latest/settings-ipv4.html).

Las referencias de llama.cpp y del modelo están fijadas a revisiones. Las de NetworkManager describen su documentación actual: la ejecución real debe comprobarse en Ubuntu 22.04. Las dependencias descargadas conservan sus licencias y condiciones originales.

## Reproducibilidad

El archivo `prueba_dos_portatiles/versiones.env` es la referencia de versión y hash del modelo. Guarda también el commit de este repositorio en cada sesión. Actualizar llama.cpp en un solo equipo puede romper la correspondencia de RPC; cualquier actualización debe probarse en todos los nodos y acompañarse de nuevos resultados.
