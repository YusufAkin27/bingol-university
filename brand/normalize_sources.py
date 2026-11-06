"""Kullanicinin yukledigi dark_logo.png / light_logo.png kaynaklarini normallestirir.

Kullanim (repo kokunden):  python -I -X utf8 brand/normalize_sources.py

Girdi : repo kokundeki dark_logo.png ve light_logo.png (yuvarlak koseli kare "app simgesi" tarzi logolar; kose disi
        zemin tersi renkte: dark_logo'da beyaz, light_logo'da siyah).
Cikti : brand/source/dark_logo.png ve light_logo.png = TAM KARE (kose disi, karonun kendi rengiyle doldurulmus), yani
        siyah zeminde beyaz glif / beyaz zeminde siyah glif. Boylece parlakliktan alfa ureten tum marka betikleri
        (mobile/tool/make_brand_assets.py, web/scripts/build-brand.py) koselerden etkilenmez; iOS/Android simgeleri
        tam kenara kadar doludur. Ozgun dosyalar brand/source/original_*.png olarak saklanir.
"""
import os
import shutil
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'brand', 'source')
os.makedirs(SRC, exist_ok=True)


def normalize(name):
    root_p = os.path.join(ROOT, name)
    keep_p = os.path.join(SRC, 'original_' + name)
    if os.path.exists(root_p):
        shutil.copyfile(root_p, keep_p)
        in_p = root_p
    elif os.path.exists(keep_p):
        in_p = keep_p
    else:
        sys.exit(f'{name} bulunamadi (repo koku ya da brand/source/original_{name})')
    rgb = Image.open(in_p).convert('RGB')
    gray = rgb.convert('L')
    w, h = rgb.size
    # Kose rengi (dis zemin) ve karo rengi: kose pikseli ile merkezden uzak, glifsiz bir nokta
    outside = gray.getpixel((2, 2))
    tile_dark = outside > 128  # kose beyazsa karo koyu
    # Dis bolgeyi 4 koseden taşırarak bul (karoyla ayni renkli glif karoya degmez, sizmaz)
    mask_src = rgb.copy()
    marker = (1, 254, 3)  # gri tonlu kaynakta bulunmayan renk: yalnizca tasan bolge bu renge boyanir
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(mask_src, seed, marker, thresh=90)
    r, g, b_ = mask_src.split()
    mask = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v == 1 else 0),
                                                    g.point(lambda v: 255 if v == 254 else 0)),
                               b_.point(lambda v: 255 if v == 3 else 0))
    # Kenar tonlarini da kapsa (anti-alias / JPEG gurultusu): birkac piksel genislet
    mask = mask.filter(ImageFilter.MaxFilter(9))
    # Karo rengi: yatay orta cizginin kenara yakin (glif disi) bolgesinden
    tile_px = gray.getpixel((int(w * 0.5), int(h * 0.94)))
    fill = (9, 9, 11) if tile_dark else (255, 255, 255)
    # Karonun gercek tonuna yakin dolgu: saf siyah/beyaza yaslanir (zemin tek ton olsun)
    solid = Image.new('RGB', (w, h), fill)
    out = Image.composite(solid, rgb, mask)
    # Karo ici zemini de tek tona sabitle (JPEG lekeleri): glif disinda esikle
    g2 = out.convert('L')
    if tile_dark:
        g2 = g2.point(lambda v: 0 if v <= 40 else (255 if v >= 215 else round((v - 40) * 255 / 175)))
        out = Image.merge('RGB', (g2, g2, g2))
        out = ImageChops.lighter(out, Image.new('RGB', (w, h), (9, 9, 11)))
    else:
        g2 = g2.point(lambda v: 0 if v <= 40 else (255 if v >= 215 else round((v - 40) * 255 / 175)))
        out = Image.merge('RGB', (g2, g2, g2))
    # Kenar serit (12 px): karo kenarinda kalan tek piksel lekeleri temizler (glif sinirlari kirpilirken sapitmasin)
    d = ImageDraw.Draw(out)
    fillc = out.getpixel((w // 2, h - 40))
    for box in ((0, 0, w, 11), (0, h - 12, w, h), (0, 0, 11, h), (w - 12, 0, w, h)):
        d.rectangle(box, fill=fillc)
    dest = os.path.join(SRC, name)
    out.save(dest, optimize=True)
    print(f'{name}: kose={outside} karo={tile_px} -> {os.path.relpath(dest, ROOT)} ({os.path.getsize(dest)/1024:.0f} KB)')


for n in ('dark_logo.png', 'light_logo.png'):
    normalize(n)
