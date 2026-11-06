"""BU Kampus marka varliklarini iki kaynak logodan uretir (Pillow; yeni bagimlilik yok).

Kullanim (repo kokunden):  python -I -X utf8 mobile/tool/make_brand_assets.py

Kaynaklar (kalici): brand/source/dark_logo.png (siyah zemin, beyaz BU) ve brand/source/light_logo.png (beyaz zemin, siyah BU),
ikisi de 1254x1254 RGB. Zeminli kaynaklardan sadece parlakliktan sesli (anti-alias) alfa cikarilir; JPEG gurultusu
esiklenir. Uretilenler:

  mobile/assets/branding/        logo_dark.png (beyaz glif), logo_light.png (siyah glif), icon_1024.png, adaptive_*.png
  mobile/android/app/src/main/res  mipmap ic_launcher, drawable ic_launcher_foreground/monochrome, ic_stat_bu,
                                   splash_icon(+_dark), splash_logo(+_dark)
  mobile/ios/Runner/Assets.xcassets AppIcon (acik/koyu/tinted, tek boyut) + LaunchImage (acik/koyu)
  mobile/branding/store          play-store-512.png, feature-graphic-1024x500.png

Uygulama ici tema duyarliligi: lib/widgets/bu_widgets.dart -> BuLogo (koyu tema logo_dark, acik tema logo_light).
"""
import json
import os
import sys
import time

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MOBILE = os.path.join(ROOT, 'mobile')
SRC = os.path.join(ROOT, 'brand', 'source')
ASSETS = os.path.join(MOBILE, 'assets', 'branding')
RES = os.path.join(MOBILE, 'android', 'app', 'src', 'main', 'res')
XC = os.path.join(MOBILE, 'ios', 'Runner', 'Assets.xcassets')
STORE = os.path.join(MOBILE, 'branding', 'store')

LIGHT_BG = (255, 255, 255)
DARK_BG = (9, 9, 11)


def out(path, im):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # OneDrive/AV bazen yazim sirasinda dosyayi kisa sure kilitler (EINVAL): yeniden dene
    for attempt in range(8):
        try:
            im.save(path, optimize=True)
            break
        except OSError:
            if attempt == 7:
                raise
            time.sleep(0.5)
    print('yazildi', os.path.relpath(path, ROOT), im.size, im.mode)


def lum(path):
    return Image.open(path).convert('L')


def alpha_from(path, glyph_is_white):
    """Zeminli logodan 0-255 kapsama alfasi (L kanali; yumusak esik)."""
    l = lum(path)
    px = sorted(l.tobytes())
    lo, hi = px[int(len(px) * 0.02)], px[int(len(px) * 0.98)]
    ink, bg = (hi, lo) if glyph_is_white else (lo, hi)
    span = float(ink - bg)

    def f(v):
        n = (v - bg) / span
        n = (n - 0.06) / 0.88  # gurultu esigi + doygunluk
        return max(0, min(255, int(round(n * 255))))

    return Image.eval(l, lambda v: 0) if span == 0 else Image.frombytes('L', l.size, bytes(f(v) for v in l.tobytes()))


def glyph(alpha, color, width):
    """Alfa maskesini glif sinirlarina kirpar, `width` px genislige indirir; tek renkli RGBA dondurur."""
    bb = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    a = alpha.crop(bb)
    h = round(a.height * width / a.width)
    a = a.resize((width, h), Image.LANCZOS)
    im = Image.new('RGBA', a.size, color + (0,))
    im.putalpha(a)
    return im


def on_canvas(im, w, h, bg=None):
    """Glifi (w x h) tuvale ortalar; bg yoksa seffaf."""
    c = Image.new('RGBA', (w, h), (bg + (255,)) if bg else (0, 0, 0, 0))
    c.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
    return c


def main():
    dark_src = os.path.join(SRC, 'dark_logo.png')
    light_src = os.path.join(SRC, 'light_logo.png')
    a_dark = alpha_from(dark_src, glyph_is_white=True)    # beyaz glif
    a_light = alpha_from(light_src, glyph_is_white=False)  # siyah glif
    WHITE, BLACK = (255, 255, 255), (0, 0, 0)

    def g(theme, width):
        return glyph(a_dark, WHITE, width) if theme == 'dark' else glyph(a_light, BLACK, width)

    def gp(theme, width):
        """g() ile ayni, ama acik/koyu ayni tuval olcusunde (tema degisince logo oynamaz)."""
        h = max(g('dark', width).height, g('light', width).height)
        return on_canvas(g(theme, width), width, h)

    # ---- Flutter ici: tema duyarli seffaf glif (iki tema ayni tuval olcusu: gecis zipla yapmaz) ----
    W = 640
    gd, gl = g('dark', W), g('light', W)
    H = max(gd.height, gl.height)
    out(os.path.join(ASSETS, 'logo_dark.png'), on_canvas(gd, W, H))
    out(os.path.join(ASSETS, 'logo_light.png'), on_canvas(gl, W, H))

    # ---- Ana simge (1024): light_logo, alfasiz ----
    icon = Image.open(light_src).convert('RGB').resize((1024, 1024), Image.LANCZOS)
    out(os.path.join(ASSETS, 'icon_1024.png'), icon)

    # ---- flutter_launcher_icons kaynaklari: 108 dp tuvalinde 54 dp glif (guvenli daire icinde) ----
    def adaptive(canvas, glyph_frac):
        return on_canvas(g('light', round(canvas * glyph_frac)), canvas, canvas)

    out(os.path.join(ASSETS, 'adaptive_foreground.png'), adaptive(1024, 0.50))
    out(os.path.join(ASSETS, 'adaptive_monochrome.png'), adaptive(1024, 0.50))

    # ---- Android ----
    for d, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        out(os.path.join(RES, f'mipmap-{d}', 'ic_launcher.png'), icon.resize((px, px), Image.LANCZOS))
    for d, mult in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        canvas = round(108 * mult)
        # adaptive xml 16% ic bosluk koyar: drawable 72 dp'de cizilir -> 54 dp glif = PNG tuvalinin %75'i
        fg = on_canvas(g('light', round(canvas * 0.75)), canvas, canvas)
        out(os.path.join(RES, f'drawable-{d}', 'ic_launcher_foreground.png'), fg)
        out(os.path.join(RES, f'drawable-{d}', 'ic_launcher_monochrome.png'), fg)
        st = round(24 * mult)
        out(os.path.join(RES, f'drawable-{d}', 'ic_stat_bu.png'), on_canvas(g('dark', round(st * 0.94)), st, st))
    # Android 12+ acilis ikonu: 288 dp tuval (xxxhdpi = 1152 px), glif 144 dp
    for name, theme in (('splash_icon', 'light'), ('splash_icon_dark', 'dark')):
        out(os.path.join(RES, 'drawable-xxxhdpi', f'{name}.png'), on_canvas(g(theme, 576), 1152, 1152))
    # Android 12 oncesi / pencere arka plani: 120 dp glif (xxhdpi'da 360 px)
    for name, theme in (('splash_logo', 'light'), ('splash_logo_dark', 'dark')):
        out(os.path.join(RES, 'drawable-xxhdpi', f'{name}.png'), gp(theme, 360))

    # ---- iOS AppIcon: tek boyut (Xcode 14+); acik = light_logo, koyu = dark_logo, tinted = gri tonlu dark_logo ----
    ic = os.path.join(XC, 'AppIcon.appiconset')
    for f in os.listdir(ic):
        os.remove(os.path.join(ic, f))
    dark_icon = Image.open(dark_src).convert('RGB').resize((1024, 1024), Image.LANCZOS)
    tinted = dark_icon.convert('L').convert('RGB')
    out(os.path.join(ic, 'AppIcon-1024.png'), icon)
    out(os.path.join(ic, 'AppIcon-1024-dark.png'), dark_icon)
    out(os.path.join(ic, 'AppIcon-1024-tinted.png'), tinted)
    contents = {
        'images': [
            {'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
            {'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'filename': 'AppIcon-1024-dark.png',
             'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
            {'appearances': [{'appearance': 'luminosity', 'value': 'tinted'}], 'filename': 'AppIcon-1024-tinted.png',
             'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        ],
        'info': {'author': 'xcode', 'version': 1},
    }
    write_json(os.path.join(ic, 'Contents.json'), contents)

    # ---- iOS LaunchImage (acik: siyah glif, koyu: beyaz glif; 120 pt) + zemin renk kumesi ----
    li = os.path.join(XC, 'LaunchImage.imageset')
    imgs = []
    heights = {}
    for scale in (1, 2, 3):
        for theme, suffix in (('light', ''), ('dark', 'Dark')):
            fname = f'LaunchImage{suffix}{"" if scale == 1 else f"@{scale}x"}.png'
            im = gp(theme, 120 * scale)
            heights[scale] = im.height
            out(os.path.join(li, fname), im)
            e = {'idiom': 'universal', 'filename': fname, 'scale': f'{scale}x'}
            if theme == 'dark':
                e['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
            imgs.append(e)
    write_json(os.path.join(li, 'Contents.json'), {'images': imgs, 'info': {'version': 1, 'author': 'xcode'}})
    cs = os.path.join(XC, 'LaunchBackground.colorset')

    def col(rgb):
        return {'color-space': 'srgb', 'components': {'red': f'{rgb[0] / 255:.3f}', 'green': f'{rgb[1] / 255:.3f}',
                                                      'blue': f'{rgb[2] / 255:.3f}', 'alpha': '1.000'}}

    write_json(os.path.join(cs, 'Contents.json'), {
        'colors': [
            {'color': col(LIGHT_BG), 'idiom': 'universal'},
            {'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'color': col(DARK_BG), 'idiom': 'universal'},
        ],
        'info': {'version': 1, 'author': 'xcode'}})
    print('LaunchImage 1x yukseklik:', heights[1])

    # ---- Magaza ----
    out(os.path.join(STORE, 'play-store-512.png'), icon.resize((512, 512), Image.LANCZOS))
    out(os.path.join(STORE, 'feature-graphic-1024x500.png'), feature_graphic(g))


def feature_graphic(g):
    w, h = 1024, 500
    im = Image.new('RGBA', (w, h), DARK_BG + (255,))
    mark = g('dark', 300)
    im.alpha_composite(mark, (92, (h - mark.height) // 2))
    d = ImageDraw.Draw(im)
    fonts = os.path.join(MOBILE, 'assets', 'fonts')
    big = ImageFont.truetype(os.path.join(fonts, 'Inter-Bold.ttf'), 76)
    small = ImageFont.truetype(os.path.join(fonts, 'Inter-Medium.ttf'), 26)
    x = 452
    d.text((x, 196), 'BÜ Kampüs', font=big, fill=(255, 255, 255, 255))
    # harf aralikli alt yazi
    cx = x + 3
    for ch in 'BİNGÖL ÜNİVERSİTESİ':
        d.text((cx, 296), ch, font=small, fill=(161, 161, 170, 255))
        cx += d.textlength(ch, font=small) + 4
    return im.convert('RGB')


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('yazildi', os.path.relpath(path, ROOT))


if __name__ == '__main__':
    sys.exit(main())
