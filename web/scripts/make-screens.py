"""Emulator ekran goruntulerini site telefon maketleri icin hazirlar (Pillow).

Kullanim (repo kokunden):  python -I -X utf8 web/scripts/make-screens.py <girdi_klasoru>

Girdi : Android emulatoru ekran goruntuleri (1080x2400). Asagidaki ESLEME tablosu dosya adlarini ekran adina baglar.
Islem : ust sistem durum cubugu ve alt hareket cubugu kirpilir (maket kendi iOS durum cubugunu/Home gostergesini cizer),
        iPhone 15 Pro ekran oranina (1179x2556) sigdirilir (yukseklige gore olceklenir, yanlardan ortalanarak kirpilir).
Cikti : web/public/site/screens/<ad>-<light|dark>.png (optimize, palet) + .webp (kucuk)

Not: yalnizca uygulamanin kendi ekranlari kullanilir; baska kullanicilarin icerigi (Kesfet/Reels gonderileri, fotograflar,
kisi adlari) siteye KONMAZ (KVKK/mahremiyet).
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'web', 'public', 'site', 'screens')

TOP, BOTTOM = 120, 64            # 1080x2400 kaynakta kirpilacak sistem cubuklari (px)
W, H = 1179, 2556                # iPhone 15 Pro ekran (piksel)

DARK = {'home': '14_home', 'menu': '15_menu', 'clubs': '16_clubs', 'events': '17_events', 'news': '18_news',
        'profile': '22_profile', 'settings': '24_settings'}
LIGHT = {'home': '27_home_light', 'menu': '28_menu_light', 'clubs': '29_clubs_light', 'events': '30_events_light',
         'news': '31_news_light', 'profile': '26_profile_light', 'settings': '25_settings_light'}


def prep(path):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    im = im.crop((0, TOP, w, h - BOTTOM))
    scale = H / im.height
    im = im.resize((round(im.width * scale), H), Image.LANCZOS)
    left = (im.width - W) // 2
    return im.crop((left, 0, left + W, H))


def main(src):
    os.makedirs(OUT, exist_ok=True)
    for theme, table in (('dark', DARK), ('light', LIGHT)):
        for name, f in table.items():
            p = os.path.join(src, f + '.png')
            if not os.path.exists(p):
                print('YOK', p)
                continue
            im = prep(p)
            base = os.path.join(OUT, f'{name}-{theme}')
            im.save(base + '.webp', 'WEBP', quality=86, method=6)
            im.quantize(colors=192, method=Image.FASTOCTREE, dither=Image.FLOYDSTEINBERG).save(base + '.png', optimize=True)
            print(f'{name}-{theme}: webp {os.path.getsize(base + ".webp") // 1024} KB, png {os.path.getsize(base + ".png") // 1024} KB')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else r'C:\bu_dsg\_emu_shots')
