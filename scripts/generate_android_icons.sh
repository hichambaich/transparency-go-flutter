#!/bin/bash
set -e
cd android

python3 << 'INNEREOF'
from PIL import Image, ImageDraw
import os, shutil

src = Image.open('../assets/icon_source.png').convert("RGBA")
w, h = src.size

# تطبيق القناع الدائري
mask = Image.new('L', (w, h), 0)
draw = ImageDraw.Draw(mask)
margin = int(w * 0.05)
draw.ellipse([margin, margin, w-margin, h-margin], fill=255)
src.putalpha(mask)

bbox = src.getbbox()
cropped = src.crop(bbox) if bbox else src

res = 'app/src/main/res'
densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

def make_circular(size):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scaled = cropped.resize((size, size), Image.LANCZOS)
    canvas.paste(scaled, (0, 0), scaled)
    return canvas

for density, size in densities.items():
    d = os.path.join(res, f'mipmap-{density}')
    if os.path.exists(d): shutil.rmtree(d)
    os.makedirs(d, exist_ok=True)
    
    make_circular(size).save(os.path.join(d, 'ic_launcher.png'))
    make_circular(size).save(os.path.join(d, 'ic_launcher_round.png'))
    
    # Adaptive foreground (النسر الشفاف)
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = int(size * 0.80)
    content = cropped.resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    fg.paste(content, (off, off), content)
    fg.save(os.path.join(d, 'ic_launcher_foreground.png'))

anydpi = os.path.join(res, 'mipmap-anydpi-v26')
if os.path.exists(anydpi): shutil.rmtree(anydpi)
os.makedirs(anydpi, exist_ok=True)

for xml_name in ['ic_launcher.xml', 'ic_launcher_round.xml']:
    with open(os.path.join(anydpi, xml_name), 'w') as f:
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

print("✅ Android circular icons generated")
INNEREOF
