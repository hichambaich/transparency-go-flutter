# -*- coding: utf-8 -*-
import json, time, re, sys
from deep_translator import GoogleTranslator

with open('assets/translations/en.json') as f: en = json.load(f)
with open('assets/translations/fr.json') as f: fr = json.load(f)

SKIP_PREFIXES = ['_meta.', 'lang.', 'events.', 'status.', 'misc.period_', 'evt.']
SKIP_EXACT = {'app.title', 'app.edition', 'misc.api_key_label', 'misc.label_label'}

SKIP_VALUES = {
    'Binance', 'Telegram', 'Email', 'API', 'API Key', 'Secret Key', 'Label',
    'PNL', 'DCA', 'BNB', 'BTC', 'USDT', 'USD', 'SPOT', 'TP', 'SL', 'DD',
    'Performance', 'Support', 'Capital', 'Min', 'Max', 'Total', 'Info',
    'Online', 'Stats', 'Journal', 'Positions',
    'RUNNING', 'SUSPENDED', 'ACTIVE', 'DETERIORATING',
    'BUY', 'SELL', 'DEPOSIT', 'WITHDRAW', 'BNB TOPUP', 'BNB FEE',
    'SMARTWALLET', 'SMART SOLUTIONS.PY', 'SaaS EDITION',
    'Default', 'Beta', 'SaaS',
}

PH_RE = re.compile(r'\{[^}]+\}')
URL_RE = re.compile(r'https?://')
EMAIL_RE = re.compile(r'[\w.]+@[\w.]+')

def protect(s):
    phs = []
    def sub(m):
        phs.append(m.group(0))
        return f'___PH{len(phs)-1}___'
    return PH_RE.sub(sub, s), phs

def restore(s, phs):
    for i, p in enumerate(phs):
        s = s.replace(f'___PH{i}___', p)
    return s

def should_skip(key, val):
    if key in SKIP_EXACT: return True
    for p in SKIP_PREFIXES:
        if key.startswith(p): return True
    if val in SKIP_VALUES: return True
    if not re.search(r'[a-zA-Z]', val): return True
    if len(val) < 3: return True
    if URL_RE.search(val): return True
    if EMAIL_RE.search(val): return True
    if re.match(r'^[A-Z\s\d]+$', val): return True
    return False

def walk(en_d, fr_d, prefix=''):
    for k, v in en_d.items():
        key = f'{prefix}.{k}' if prefix else k
        if isinstance(v, dict):
            if isinstance(fr_d.get(k), dict):
                yield from walk(v, fr_d[k], key)
        else:
            fr_v = fr_d.get(k) if isinstance(fr_d, dict) else None
            if fr_v == v and not should_skip(key, v):
                yield key, v

def set_path(d, path, value):
    parts = path.split('.')
    for p in parts[:-1]:
        d = d.setdefault(p, {})
    d[parts[-1]] = value

items = list(walk(en, fr))
total = len(items)
print(f'Translating {total} items (EN to FR)...', flush=True)

tr = GoogleTranslator(source='en', target='fr')
ok = 0; fail = 0

for i, (key, val) in enumerate(items):
    protected, phs = protect(val)
    result = None
    for attempt in range(3):
        try:
            result = tr.translate(protected)
            break
        except Exception as e:
            if attempt < 2: time.sleep(2)
            else: print(f'  X {key}: {e}', flush=True)
    if result and result != protected:
        final = restore(result, phs)
        set_path(fr, key, final)
        ok += 1
        if (i+1) % 10 == 0:
            print(f'  [{i+1}/{total}] OK {key}: {final[:50]}', flush=True)
            with open('assets/translations/fr.json', 'w', encoding='utf-8') as f:
                json.dump(fr, f, indent=4, ensure_ascii=False)
    else:
        fail += 1
    time.sleep(0.4)

with open('assets/translations/fr.json', 'w', encoding='utf-8') as f:
    json.dump(fr, f, indent=4, ensure_ascii=False)

print(f'DONE: translated={ok}, failed={fail}, total={total}', flush=True)
