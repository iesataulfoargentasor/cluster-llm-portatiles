"""Pruebas sin sudo, APT, CUDA, red ni cambios de configuracion del equipo.

Ejecutar: python3 -m unittest discover -s tests -p test_offline_simulado.py -v
Requiere Bash; en Windows admite Git Bash. Todos los datos son temporales.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash') if os.name != 'nt' else r'C:\Program Files\Git\bin\bash.exe'


class Offline(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='cluster-offline-')
        self.addCleanup(self.tmp.cleanup)
        self.p = Path(self.tmp.name)
        shutil.copyfile(ROOT/'sin_conexion/funciones_seguras.sh', self.p/'funciones.sh')
        self.prefix = '''set -Eeuo pipefail
source ./funciones.sh
fallar() { echo "$*" >&2; exit 23; }
# Nunca ejecutar estas operaciones en las pruebas.
sudo() { echo OPERACION_PROHIBIDA >&2; exit 99; }
apt-get() { exit 99; }
curl() { printf 'llamada' >> curl.log; printf abc > modelo.part; }
MODEL_BYTES=3
MODEL_SHA256=''' + hashlib.sha256(b'abc').hexdigest() + '\n'

    def run_bash(self, code, ok=True):
        (self.p/'caso.sh').write_text(self.prefix+code, encoding='utf-8', newline='\n')
        result = subprocess.run([BASH, '--noprofile', '--norc', 'caso.sh'], cwd=self.p,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode == 0, ok, result.stdout+result.stderr)
        self.assertNotIn('OPERACION_PROHIBIDA', result.stderr)
        return result

    def test_descarga_nueva(self):
        self.run_bash('descargar_modelo modelo https://invalid.example/modelo')
        self.assertEqual((self.p/'modelo').read_bytes(), b'abc')
        self.assertTrue((self.p/'curl.log').exists())

    def test_descarga_parcial(self):
        (self.p/'modelo.part').write_bytes(b'a')
        self.run_bash('descargar_modelo modelo URL')
        self.assertTrue((self.p/'curl.log').exists())

    def test_parcial_completo_no_descarga(self):
        (self.p/'modelo.part').write_bytes(b'abc')
        self.run_bash('descargar_modelo modelo URL')
        self.assertFalse((self.p/'curl.log').exists())
        self.assertTrue((self.p/'modelo').exists())

    def test_parcial_corrupto(self):
        (self.p/'modelo.part').write_bytes(b'xyz')
        self.run_bash('descargar_modelo modelo URL', ok=False)
        self.assertFalse((self.p/'modelo').exists())

    def test_parcial_excesivo(self):
        (self.p/'modelo.part').write_bytes(b'abcd')
        self.run_bash('descargar_modelo modelo URL', ok=False)
        self.assertFalse((self.p/'curl.log').exists())

    def test_modelo_existente(self):
        (self.p/'modelo').write_bytes(b'abc')
        self.run_bash('descargar_modelo modelo URL')
        self.assertFalse((self.p/'curl.log').exists())

    def test_modelo_existente_corrupto(self):
        (self.p/'modelo').write_bytes(b'xyz')
        self.run_bash('descargar_modelo modelo URL', ok=False)

    def test_plan_toolkit_permitido(self):
        (self.p/'plan').write_text('Inst cuda-toolkit-12-8 (12.8)\nInst cmake (3.22)\n')
        self.run_bash('validar_plan_apt plan')

    def test_plan_ausente(self):
        self.run_bash('validar_plan_apt no_existe', ok=False)

    def test_planes_protegidos(self):
        for package in ['nvidia-driver-580', 'libnvidia-compute-580:amd64',
                        'nvidia-kernel-common-580', 'cuda-drivers', 'linux-generic',
                        'linux-image-6.8', 'dkms', 'xserver-xorg-video-nvidia-580']:
            with self.subTest(package=package):
                (self.p/'plan').write_text(f'Inst {package} (1.0)\n')
                self.run_bash('validar_plan_apt plan', ok=False)

    def test_extraccion_correcta_y_repeticion(self):
        self.run_bash('''
RAIZ_KIT="$PWD"
LLAMA_COMMIT=revision
mkdir -p fuentes entrada ui
echo fuente > entrada/CMakeLists.txt
echo chat > ui/index.html
tar -czf fuentes/llama.cpp.tar.gz -C entrada .
tar -czf fuentes/interfaz_chat.tar.gz -C ui .
extraer_fuentes "$PWD/salida"
extraer_fuentes "$PWD/salida"
test -s salida/tools/ui/dist/index.html
''')

    def test_extraccion_fallida_no_publica_destino(self):
        self.run_bash('''
RAIZ_KIT="$PWD"
LLAMA_COMMIT=revision
mkdir fuentes
echo roto > fuentes/llama.cpp.tar.gz
extraer_fuentes "$PWD/salida"
''', ok=False)
        self.assertFalse((self.p/'salida').exists())

    def test_carpeta_ajena_se_conserva(self):
        (self.p/'salida').mkdir()
        (self.p/'salida/datos').write_text('conservar')
        self.run_bash('LLAMA_COMMIT=revision; extraer_fuentes "$PWD/salida"', ok=False)
        self.assertEqual((self.p/'salida/datos').read_text(), 'conservar')

    def test_sintaxis_todos_los_scripts(self):
        files = sorted(ROOT.rglob('*.sh')) + sorted(ROOT.rglob('*.env'))
        self.assertGreater(len(files), 10)
        for path in files:
            with self.subTest(file=str(path.relative_to(ROOT))):
                # Copia normalizada: Git aplica LF al descargar en Ubuntu.
                (self.p/'sintaxis.sh').write_text(path.read_text(encoding='utf-8'),
                                                encoding='utf-8', newline='\n')
                result = subprocess.run([BASH, '-n', 'sintaxis.sh'], cwd=self.p,
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
