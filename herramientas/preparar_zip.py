#!/usr/bin/env python3
"""Empaquetar archivos del proyecto; no instala ni ejecuta scripts del laboratorio."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SALIDA = ROOT / 'distribucion' / 'prueba_dos_portatiles.zip'
BASE = 'cluster-llm-portatiles/'
inicio = """EMPEZAR AQUI - DOCUMENTACION Y SCRIPTS ACTUALIZADOS

1. Extrae este ZIP en la Carpeta personal del Ubuntu preparador.
   Debe quedar ~/cluster-llm-portatiles. Conserva cualquier copia anterior
   con otro nombre para no mezclar versiones.
2. Abre output/pdf/manual-cluster-llm-portatiles.pdf.
3. Para instalar SIN INTERNET: lee sin_conexion/LEEME.html y consulta
   sin_conexion/HOJA_RESUMEN_OFFLINE.html (imprimible).
   Con Internet en el Ubuntu preparador ejecuta:

   cd "$HOME/cluster-llm-portatiles/sin_conexion"
   bash ./01_preparar_kit_con_internet.sh

4. Espera KIT PREPARADO. Copia ~/kit_cluster_sin_internet ENTERO al USB
   y despues a la Carpeta personal de A y B. Sigue la hoja offline.
5. Si prefieres INSTALACION CON INTERNET en ambos, copia solamente la
   subcarpeta prueba_dos_portatiles a ~/prueba_dos_portatiles y sigue
   su GUIA_PASO_A_PASO y HOJA_RESUMEN.html. No mezcles instaladores.

El ZIP incluye PDF, esquemas, scripts corregidos, guias, ambas hojas
resumen y herramienta de diagnostico. MANIFIESTO.json enumera sus hashes.
NO incluye el modelo de unos 9 GB ni los paquetes CUDA/Ubuntu. Estos se
descargan al preparar el kit grande en Ubuntu 22.04 conectado.
Recomendado: pendrive 64 GB exFAT/ext4; FAT32 no admite el GGUF.
No ejecutes los scripts completos con sudo ni directamente desde el USB.
La instalacion APT/CUDA y la inferencia reales siguen pendientes de
validacion en los portatiles. Se han superado 26 pruebas simuladas.

Proyecto: https://github.com/iesataulfoargentasor/cluster-llm-portatiles
"""

def main():
    archivos = {}
    for carpeta in ('prueba_dos_portatiles', 'sin_conexion', 'docs'):
        for p in (ROOT / carpeta).iterdir():
            if p.is_file():
                archivos[p.relative_to(ROOT).as_posix()] = p.read_bytes()
    archivos['output/pdf/manual-cluster-llm-portatiles.pdf'] = (ROOT / 'output/pdf/manual-cluster-llm-portatiles.pdf').read_bytes()
    archivos['00_EMPEZAR_AQUI.txt'] = inicio.encode('utf-8')
    archivos['README.md'] = (ROOT / 'README.md').read_bytes()
    archivos['CHANGELOG.md'] = (ROOT / 'CHANGELOG.md').read_bytes()
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
