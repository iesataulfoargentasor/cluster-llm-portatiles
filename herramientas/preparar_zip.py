#!/usr/bin/env python3
"""Empaquetar archivos del proyecto; no instala ni ejecuta scripts del laboratorio."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SALIDA = ROOT / 'distribucion' / 'prueba_dos_portatiles.zip'
BASE = 'prueba_dos_portatiles/'
inicio = '''EMPEZAR AQUI - PAQUETE PARA EL PENDRIVE

Proyecto: https://github.com/iesataulfoargentasor/cluster-llm-portatiles
Equipos: dos portatiles Ubuntu 22.04 LTS del centro; roles A y B.

1. Copia este ZIP al pendrive y llevalo a ambos equipos.
2. Extraelo en la Carpeta personal de cada usuario de Ubuntu.
   La carpeta debe quedar en ~/prueba_dos_portatiles, sin otra carpeta
   prueba_dos_portatiles dentro. Conserva con otro nombre cualquier copia
   anterior antes de extraer, para no mezclar versiones.
3. Abre manual-cluster-llm-portatiles.pdf para consultar todo el proceso.
   HOJA_RESUMEN.html contiene el orden de comandos para A y B y se puede
   abrir en el navegador sin Internet e imprimir a doble cara.
4. Abre una terminal local y entra en el paquete:

   cd "$HOME/prueba_dos_portatiles"

5. Sigue la hoja resumen. Orden general:
   - Con Internet: 01 en A y B; despues 02 solamente en A.
   - Switch aislado: 07 en ambos; 03 en B; 04 y 05 en A; prueba 06 en A.
   - Al terminar: parar modelo, tunel y RPC; volver a la red habitual;
     ejecutar 08 en ambos para recuperar DHCP.

No ejecutes los scripts completos con sudo. Mantén el mismo usuario de
Ubuntu durante la prueba. No los ejecutes directamente desde el pendrive.
Si Ethernet no se llama eno1, sigue las instrucciones de la guia para
indicar su nombre al ejecutar 07 y 08.

El paquete incluye PDF, hoja resumen, guia completa, scripts 01 a 08,
archivos auxiliares y herramienta de recopilacion de hardware.
MANIFIESTO.json contiene el inventario y las huellas SHA-256 de los archivos.

IMPORTANTE: el ZIP NO contiene los pesos del modelo, CUDA, controladores
ni dependencias instaladas. Completa la instalacion y la descarga con
Internet ANTES de pasar al switch aislado. El script 02 descarga y verifica
el modelo, de unos 9 GB. La documentacion si funciona sin Internet.

La ejecucion real del prototipo en el centro sigue pendiente. Los informes
originales, las consultas y los registros privados no se incluyen.
'''

def main():
    archivos = {p.name: p.read_bytes() for p in (ROOT / 'prueba_dos_portatiles').iterdir() if p.is_file()}
    archivos['manual-cluster-llm-portatiles.pdf'] = (ROOT / 'output/pdf/manual-cluster-llm-portatiles.pdf').read_bytes()
    archivos['00_EMPEZAR_AQUI.txt'] = inicio.encode('utf-8')
    for name in ('recopilar_datos_cluster.sh', 'INSTRUCCIONES.txt'):
        archivos['herramientas/' + name] = (ROOT / 'herramientas' / name).read_bytes()
    for name in archivos:
        if Path(name).suffix in ('.sh', '.py', '.env', '.md', '.txt', '.html'):
            archivos[name] = archivos[name].decode('utf-8-sig').replace('\r\n', '\n').encode('utf-8')
    revision = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    inventario = {'revision_base_del_repositorio': revision,
                  'nota': 'Huellas de todos los archivos del paquete salvo este manifiesto.',
                  'archivos': {n: {'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()} for n,b in sorted(archivos.items())}}
    archivos['MANIFIESTO.json'] = (json.dumps(inventario, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    SALIDA.parent.mkdir(exist_ok=True)
    temporal = SALIDA.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporal, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in sorted(archivos.items()):
            info = zipfile.ZipInfo(BASE + name)
            info.date_time = (2026, 10, 23, 0, 0, 0)
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    # Integridad del contenedor y correspondencia exacta con los archivos fuente.
    with zipfile.ZipFile(temporal) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {BASE+n for n in archivos}
        for name, data in archivos.items():
            assert z.read(BASE+name) == data
    temporal.replace(SALIDA)
    print(json.dumps({'zip':str(SALIDA),'archivos':len(archivos),'bytes':SALIDA.stat().st_size}, ensure_ascii=False))

if __name__ == '__main__':
    main()
