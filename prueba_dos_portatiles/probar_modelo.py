#!/usr/bin/env python3
"""Una consulta breve al servidor local. Guarda respuesta y tiempos observados."""
import datetime as dt
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

BASE = 'http://127.0.0.1:8080'
# El servidor es local; evitar que variables de proxy del centro desvien la consulta.
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def main():
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    try:
        with opener.open(BASE + '/health', timeout=5) as response:
            health = json.load(response)
    except (urllib.error.URLError, TimeoutError) as exc:
        raise SystemExit('El servidor aun no esta listo. Revisa la terminal del paso 05 y repite cuando termine la carga. ' + str(exc))
    if health.get('status') != 'ok':
        raise SystemExit('Estado del servidor: ' + str(health))
    prompt = 'Explica en espanol, en unas 120 palabras, que es la inferencia distribuida y para que sirve repartir un modelo entre dos GPU. /no_think'
    payload = {
        'model': 'qwen3-14b-cluster',
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 256,
        'temperature': 0.7,
        'stream': True,
        'stream_options': {'include_usage': True},
        'cache_prompt': False,
        'chat_template_kwargs': {'enable_thinking': False},
    }
    request = urllib.request.Request(BASE + '/v1/chat/completions',
                                     data=json.dumps(payload).encode(),
                                     headers={'Content-Type': 'application/json'})
    started = time.perf_counter()
    first = None
    parts, events = [], []
    done = False
    print('Consultando el modelo...\n', flush=True)
    try:
        with opener.open(request, timeout=600) as response:
            for raw in response:
                line = raw.decode('utf-8').strip()
                if not line.startswith('data:'):
                    continue
                data = line[5:].strip()
                if data == '[DONE]':
                    done = True
                    break
                event = json.loads(data)
                events.append(event)
                if 'error' in event:
                    raise RuntimeError(str(event['error']))
                for choice in event.get('choices', []):
                    text = choice.get('delta', {}).get('content')
                    if text:
                        if first is None:
                            first = time.perf_counter() - started
                        parts.append(text)
                        print(text, end='', flush=True)
    except (urllib.error.URLError, TimeoutError, ValueError, RuntimeError) as exc:
        raise SystemExit('\nLa consulta fallo: ' + str(exc))
    elapsed = time.perf_counter() - started
    if not done or not parts:
        raise SystemExit('\nLa respuesta termino sin completarse o sin texto. Revisa el registro de A.')
    timings = next((e['timings'] for e in reversed(events) if e.get('timings')), {})
    usage = next((e['usage'] for e in reversed(events) if e.get('usage')), {})
    finish = next((c.get('finish_reason') for e in reversed(events) for c in e.get('choices', []) if c.get('finish_reason')), None)
    result = {
        'fecha': dt.datetime.now().astimezone().isoformat(),
        'modelo': payload['model'], 'pregunta': prompt,
        'respuesta': ''.join(parts), 'primer_texto_segundos': first,
        'total_segundos': elapsed, 'timings_servidor': timings,
        'uso_tokens': usage, 'fin': finish,
        'nota': 'Primer texto medido desde el cliente. No incluye el arranque del modelo. Una consulta breve no constituye un benchmark completo.',
        'eventos': events,
    }
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    dest = out / f'prueba_{stamp}.json'
    dest.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\n\nPrimer texto: {first:.2f} s. Tiempo total de consulta: {elapsed:.2f} s.')
    speed = timings.get('predicted_per_second')
    print(f'Generacion segun el servidor: {speed:.2f} tokens/s.' if isinstance(speed, (float, int)) else 'La respuesta no incluye tokens/s; consulta el registro del servidor.')
    if finish == 'length':
        print('La respuesta ha alcanzado el limite de 256 tokens de esta prueba.')
    print(f'Resultado guardado en: {dest}')

if __name__ == '__main__':
    main()
