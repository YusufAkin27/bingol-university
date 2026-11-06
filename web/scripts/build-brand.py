# BÜ Kampüs web marka varlıkları üreticisi (yeni siyah-beyaz logo).
# Kaynak: repo kökündeki dark_logo.png (siyah zemin, beyaz glif) ve light_logo.png (beyaz zemin, siyah glif).
# Kökteki PNG'ler yoksa web/public/brand/square-*.png kaynak alınır.
# Kullanım (repo kökünden): python -I -X utf8 web/scripts/build-brand.py
# Üretir: web/public/{favicon*,icon-*,apple-touch-icon,og}.png, favicon.ico, web/public/brand/*, web/src/assets/brand/mark-*.png
import os
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PUB = os.path.join(ROOT, 'web', 'public')
BRAND = os.path.join(PUB, 'brand')
ASSETS = os.path.join(ROOT, 'web', 'src', 'assets', 'brand')
os.makedirs(BRAND, exist_ok=True)
os.makedirs(ASSETS, exist_ok=True)

BLACK = (9, 9, 11)
WHITE = (255, 255, 255)


def src(name):
    p = os.path.join(ROOT, name)
    if not os.path.exists(p):
        # kök dosyalar silinmişse temizlenmiş 1024 kare sürümden yeniden üretilir
        p = os.path.join(BRAND, 'square-' + name.split('_')[0] + '.png')
    return Image.open(p).convert('L')


def curve(v):
    # JPEG gürültüsünü bastırır: 40 altı 0, 215 üstü 255, arası doğrusal (kenar yumuşatma kalır)
    return 0 if v <= 40 else (255 if v >= 215 else round((v - 40) * 255 / 175))


def glyph(gray, ink, invert):
    """Parlaklık -> alfa; ink renkli şeffaf zeminli glif."""
    alpha = ImageChops.invert(gray) if invert else gray
    # kenar yumuşatması korunur; gürültüyü kırpmak için hafif eşikleme
    alpha = alpha.point(curve)
    img = Image.new('RGBA', gray.size, ink + (0,))
    img.putalpha(alpha)
    return img


def crop_mark(img, pad=0):
    bbox = img.getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox()
    c = img.crop(bbox)
    if pad:
        out = Image.new('RGBA', (c.width + 2 * pad, c.height + 2 * pad), (0, 0, 0, 0))
        out.paste(c, (pad, pad))
        return out
    return c


def fit_width(img, w):
    h = round(img.height * w / img.width)
    return img.resize((w, h), Image.LANCZOS)


def save_png(img, path, colors=None):
    if colors:
        img = img.quantize(colors=colors, method=Image.FASTOCTREE) if img.mode == 'RGB' else img
    img.save(path, optimize=True)
    print(f'{os.path.relpath(path, ROOT)}  {img.size}  {os.path.getsize(path)/1024:.1f} KB')


light_gray = src('light_logo.png')
dark_gray = src('dark_logo.png')
mark_light = crop_mark(glyph(light_gray, BLACK, invert=True))   # siyah glif (açık zemin için)
mark_dark = crop_mark(glyph(dark_gray, WHITE, invert=False))    # beyaz glif (koyu zemin için)

# 1) Logo bileşeni görselleri (hashli, paketlenir): 192 genişlik (2x retina için 36-44 px yükseklik yeter)
for name, m in (('light', mark_light), ('dark', mark_dark)):
    save_png(fit_width(m, 192), os.path.join(ASSETS, f'mark-{name}.png'))
    save_png(fit_width(m, 512), os.path.join(BRAND, f'mark-{name}.png'))

# 2) Marka sayfası indirmeleri: tam kare (özgün) logolar, 1024
for name, g in (('light', light_gray), ('dark', dark_gray)):
    sq = g.resize((1024, 1024), Image.LANCZOS)
    sq = sq.point(curve)
    # 8 bit gri PNG: küçük dosya
    save_png(sq, os.path.join(BRAND, f'square-{name}.png'))

# 3) Sekme ikonları
def tile(size, bg, m, scale=0.62):
    img = Image.new('RGBA', (size, size), bg + (255,))
    w = round(size * scale)
    mm = fit_width(m, w)
    img.alpha_composite(mm, ((size - mm.width) // 2, (size - mm.height) // 2))
    return img


for name, bg, m in (('light', (255, 255, 255), mark_light), ('dark', (9, 9, 11), mark_dark)):
    save_png(tile(64, bg, m, 0.82).convert('RGB'), os.path.join(PUB, f'favicon-{name}.png'))

fav = tile(48, (255, 255, 255), mark_light, 0.82).convert('RGB')
fav.save(os.path.join(PUB, 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48)])
print('favicon.ico', os.path.getsize(os.path.join(PUB, 'favicon.ico')))

save_png(tile(180, (255, 255, 255), mark_light, 0.72).convert('RGB'), os.path.join(PUB, 'apple-touch-icon.png'))
save_png(tile(192, (255, 255, 255), mark_light, 0.72).convert('RGB'), os.path.join(PUB, 'icon-192.png'))
save_png(tile(512, (255, 255, 255), mark_light, 0.72).convert('RGB'), os.path.join(PUB, 'icon-512.png'))
# maskable: güvenli alan (orta %80 dairesi) içinde kalsın -> glif genişliği %50
save_png(tile(512, (255, 255, 255), mark_light, 0.5).convert('RGB'), os.path.join(PUB, 'icon-maskable-512.png'))

# 4) og.png 1200x630: koyu zemin, beyaz logo + metin
W, H = 1200, 630
og = Image.new('RGB', (W, H), BLACK)
mm = fit_width(mark_dark, 300)
og_rgba = og.convert('RGBA')
cx = 140
og_rgba.alpha_composite(mm, (cx, (H - mm.height) // 2))
d = ImageDraw.Draw(og_rgba)


def font(size, bold=True):
    for p in ('C:/Windows/Fonts/arialbd.ttf', 'C:/Windows/Fonts/segoeuib.ttf', 'C:/Windows/Fonts/arial.ttf'):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


tx = cx + mm.width + 70
d.text((tx, 232), 'BÜ Kampüs', font=font(84), fill=WHITE)
d.text((tx, 340), 'Bingöl Üniversitesi', font=font(40), fill=(200, 200, 206))
d.text((tx, 396), 'Duyurular · Yemek · Etkinlikler', font=font(30), fill=(150, 150, 158))
save_png(og_rgba.convert('RGB').quantize(colors=64, method=Image.FASTOCTREE), os.path.join(PUB, 'og.png'))
