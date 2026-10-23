"""Pruebas sin procesos externos: NetworkManager y sysfs simulados."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('red', ROOT / 'prueba_dos_portatiles/red_cluster.py')
red = importlib.util.module_from_spec(spec)
spec.loader.exec_module(red)

class RedSimulada:
    def __init__(self, metodo='auto'):
        self.perfiles = {'original': {'connection.id': 'Habitual', 'connection.type': '802-3-ethernet',
            'connection.interface-name': 'eno1', 'ipv4.method': metodo}}
        self.original = copy.deepcopy(self.perfiles['original'])
        self.activo = 'original'
        self.fallar = False
        self.ordenes = []
    def nm(self, *args, cambiar=False, aceptar_error=False):
        self.ordenes.append(args)
        a = list(args)
        if a[0] == '--wait': a = a[2:]
        if a[:2] == ['connection', 'add']:
            p = dict(zip(a[2::2], a[3::2]))
            p['connection.id'] = p['con-name']
            p['connection.type'] = '802-3-ethernet'
            p['connection.interface-name'] = p['ifname']
            self.perfiles[p['connection.uuid']] = p
        elif a[:2] == ['connection', 'down']: self.activo = None
        elif a[:2] == ['connection', 'delete']: del self.perfiles[a[3]]
        else: raise AssertionError('Orden inesperada: ' + str(a))
        return SimpleNamespace(returncode=0, stdout='', stderr='')
    def subir(self, identificador, interfaz):
        if self.fallar and identificador != 'original':
            return SimpleNamespace(returncode=4, stderr='Fallo simulado')
        self.activo = identificador
        return SimpleNamespace(returncode=0, stderr='')

class Pruebas(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent)
        self.ruta = Path(self.tmp.name) / 'estado.json'
        self.sim = RedSimulada()
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.tmp.cleanup)
        self.addCleanup(self.stack.close)
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        # Barrera: cualquier intento de ejecutar un proceso real hace fallar la prueba.
        self.stack.enter_context(patch.object(red.subprocess, 'run', side_effect=AssertionError('Proceso real prohibido')))
        for nombre, funcion in {
            'nm': self.sim.nm, 'perfil_existe': lambda u: u in self.sim.perfiles,
            'propiedad': lambda u,k: self.sim.perfiles[u].get(k, ''),
            'activo': lambda i: self.sim.activo, 'subir': self.sim.subir,
            'mostrar': lambda i: None, 'comprobar_solapamiento': lambda i: None,
            'valor': lambda *a: '10.0.0.5/24',
        }.items(): self.stack.enter_context(patch.object(red, nombre, funcion))
        original_read = Path.read_text
        self.stack.enter_context(patch.object(Path, 'read_text', lambda p,*a,**k:
            '1' if str(p).endswith('carrier') else original_read(p,*a,**k)))
        self.stack.enter_context(patch.object(Path, 'home', return_value=Path(self.tmp.name)))
    def configurar(self, rol='A', datos=None):
        red.configurar(rol, 'eno1', self.ruta, datos, 'maquina')
        return json.loads(self.ruta.read_text())
    def test_a(self):
        d=self.configurar(); self.assertEqual(self.sim.perfiles[d['prueba_uuid']]['ipv4.addresses'], '192.168.50.10/24')
        self.assertEqual(self.sim.perfiles['original'], self.sim.original)
    def test_b(self):
        d=self.configurar('B'); self.assertEqual(self.sim.perfiles[d['prueba_uuid']]['ipv4.addresses'], '192.168.50.20/24')
    def test_repeticion(self):
        d=self.configurar(); e=self.configurar(datos=d)
        self.assertEqual(d['prueba_uuid'],e['prueba_uuid']); self.assertEqual(len(self.sim.perfiles),2)
    def test_rol_distinto(self):
        d=self.configurar()
        with self.assertRaises(RuntimeError): self.configurar('B',d)
    def test_recuperacion_fallo(self):
        self.sim.fallar=True
        with self.assertRaises(RuntimeError): self.configurar()
        self.assertEqual(self.sim.activo,'original')
    def test_dhcp_original(self):
        d=self.configurar(); self.assertEqual(red.restaurar('eno1',self.ruta,d),0)
        self.assertEqual(self.sim.activo,'original'); self.assertEqual(len(self.sim.perfiles),1)
        self.assertEqual(self.sim.perfiles['original'],self.sim.original)
        self.assertEqual(red.restaurar('eno1',self.ruta,d),0)
    def test_anterior_manual(self):
        self.sim.perfiles['original']['ipv4.method']='manual'
        d=self.configurar(); self.assertEqual(red.restaurar('eno1',self.ruta,d),0)
        self.assertEqual(self.sim.perfiles['original']['ipv4.method'],'manual')
        self.assertEqual(self.sim.perfiles[self.sim.activo]['ipv4.method'],'auto')
    def test_sin_dhcp_y_reintento(self):
        self.sim.perfiles['original']['ipv4.method']='manual'
        d=self.configurar(); self.sim.fallar=True
        self.assertEqual(red.restaurar('eno1',self.ruta,d),2)
        self.assertNotIn(d['prueba_uuid'],self.sim.perfiles)
        destino=d['dhcp_uuid']; self.sim.fallar=False
        self.assertEqual(red.restaurar('eno1',self.ruta,d),0)
        self.assertEqual(d['dhcp_uuid'],destino)
    def test_perfil_alterado(self):
        d=self.configurar(); self.sim.perfiles[d['prueba_uuid']]['ipv4.gateway']='192.168.50.1'
        with self.assertRaises(RuntimeError): self.configurar(datos=d)
    def test_sin_estado(self):
        with self.assertRaises(RuntimeError): red.restaurar('eno1',self.ruta,None)
        self.assertEqual(self.sim.ordenes,[])
    def test_nombre_cambiado(self):
        d=self.configurar(); self.sim.perfiles[d['prueba_uuid']]['connection.id']='Otro'
        with self.assertRaises(RuntimeError): red.restaurar('eno1',self.ruta,d)
        self.assertIn(d['prueba_uuid'],self.sim.perfiles)
    def test_guardia_windows(self):
        with patch.object(red.sys,'platform','win32'), patch.object(red.sys,'argv',['red','dhcp']):
            with self.assertRaisesRegex(RuntimeError,'Ubuntu'): red.main()

if __name__ == '__main__': unittest.main(verbosity=2)
