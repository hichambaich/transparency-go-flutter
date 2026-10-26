#!/bin/bash
set -e
cd android
python3 << 'INNEREOF'
from PIL import Image
import os

src = Image.open('../assets/icon_source.png').convert("RGBA")
res = 'app/src/main/res'
densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

for density, size in densities.items():
    d = os.path.join(res, f'mipmap-{density}')
    os.makedirs(d, exist_ok=True)
    src.resize((size, size), Image.LANCZOS).save(os.path.join(d, 'ic_launcher.png'))

for density, size in densities.items():
    d = os.path.join(res, f'mipmap-{density}')
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    csize = int(size * 66 / 108)
    content = src.resize((csize, csize), Image.LANCZOS)
    off = (size - csize) // 2
    fg.paste(content, (off, off), content)
    fg.save(os.path.join(d, 'ic_launcher_foreground.png'))

anydpi = os.path.join(res, 'mipmap-anydpi-v26')
os.makedirs(anydpi, exist_ok=True)
with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n')
    f.write('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n')
    f.write('    <background android:drawable="@color/ic_launcher_background" />\n')
    f.write('    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n')
    f.write('</adaptive-icon>\n')

values = os.path.join(res, 'values')
os.makedirs(values, exist_ok=True)
colors = os.path.join(values, 'colors.xml')
content = ''
if os.path.exists(colors):
    with open(colors) as fh: content = fh.read()
if 'ic_launcher_background' not in content:
    if not content.strip():
        content = '<?xml version="1.0" encoding="utf-8"?>\n<resources></resources>'
    content = content.replace('</resources>', '    <color name="ic_launcher_background">#080d14</color>\n</resources>')
    with open(colors, 'w') as fh: fh.write(content)
print("Android icons generated")
INNEREOF
