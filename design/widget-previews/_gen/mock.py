import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONT = os.path.join(ROOT, '..', '..', 'mobile', 'assets', 'fonts', 'Inter-Regular.ttf')
S = 2  # 1 pt = 2 px
PW, PH = 393, 852

def wallpaper(w, h, dark):
    top, bot = ((38, 40, 56), (8, 8, 12)) if dark else ((214, 222, 240), (246, 238, 232))
    im = Image.new('RGB', (w, h))
    px = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        px.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    glow = Image.new('RGB', (w, h), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    gc = (70, 74, 110) if dark else (255, 255, 255)
    g.ellipse([-w // 3, h // 5, w, h * 3 // 4], fill=gc)
    glow = glow.filter(ImageFilter.GaussianBlur(w // 3))
    return Image.blend(im, Image.composite(glow, im, glow.convert('L')), 0.35)

def put(canvas, wimg, x, y, r, dark):
    w = wimg.resize((int(wimg.width * S / 3), int(wimg.height * S / 3)), Image.LANCZOS)
    sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x, y + 6, x + w.width, y + w.height + 6], r * S, fill=(0, 0, 0, 90 if dark else 50))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(sh)
    canvas.alpha_composite(w, (x, y))

def status(d, W, dark, android):
    f = ImageFont.truetype(FONT, 15 * S)
    col = (250, 250, 250) if dark else (9, 9, 11)
    d.text((32 * S if not android else 24 * S, 16 * S), '10:12', font=f, fill=col)
    # sinyal / pil
    bx = W - 56 * S
    d.rounded_rectangle([bx, 20 * S, bx + 26 * S, 31 * S], 3 * S, outline=col, width=2)
    d.rounded_rectangle([bx + 3 * S, 23 * S, bx + 19 * S, 28 * S], 1 * S, fill=col)
    for i in range(4):
        d.rectangle([bx - 36 * S + i * 5 * S, 31 * S - (4 + i * 2) * S, bx - 36 * S + i * 5 * S + 3 * S, 31 * S], fill=col)

def home(slug, plat, theme):
    dark = theme == 'dark'
    W, H = PW * S, PH * S
    canvas = wallpaper(W, H, dark).convert('RGBA')
    d = ImageDraw.Draw(canvas)
    status(d, W, dark, plat == 'android')
    ld = lambda n: Image.open(os.path.join(ROOT, slug, f'{plat}-{n}-{theme}.png')).convert('RGBA')
    if plat == 'ios':
        med, sm, r = ld('medium'), ld('small'), 22
        x0 = int((PW - 338) / 2 * S)
        put(canvas, med, x0, 130 * S, r, dark)
        put(canvas, sm, x0, (130 + 158 + 22) * S, r, dark)
        put(canvas, sm, x0 + (158 + 22) * S, (130 + 158 + 22) * S, r, dark)
    else:
        med, sm, r = ld('4x2'), ld('2x2'), 28
        x0 = int((PW - 350) / 2 * S)
        put(canvas, med, x0, 120 * S, r, dark)
        put(canvas, sm, x0, (120 + 170 + 16) * S, r, dark)
        put(canvas, sm, x0 + (170 + 10) * S, (120 + 170 + 16) * S, r, dark)
    # cihaz cercevesi
    pad = 22
    out = Image.new('RGBA', (W + pad * 2, H + pad * 2), (0, 0, 0, 0))
    od = ImageDraw.Draw(out)
    rad = (55 if plat == 'ios' else 40) * S
    od.rounded_rectangle([0, 0, out.width - 1, out.height - 1], rad + pad, fill=(24, 24, 27) if dark else (200, 200, 205))
    mask = Image.new('L', canvas.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], rad, fill=255)
    out.paste(canvas, (pad, pad), mask)
    od = ImageDraw.Draw(out)
    if plat == 'ios':
        od.rounded_rectangle([out.width // 2 - 60 * S, pad + 11 * S, out.width // 2 + 60 * S, pad + 11 * S + 34 * S], 17 * S, fill=(0, 0, 0))
    else:
        cx, cy = out.width // 2, pad + 22 * S
        od.ellipse([cx - 9 * S, cy - 9 * S, cx + 9 * S, cy + 9 * S], fill=(0, 0, 0))
    out.save(os.path.join(ROOT, slug, f'home-{plat}-{theme}.png'), optimize=True)

for slug in sys.argv[1:]:
    for plat in ('ios', 'android'):
        for theme in ('light', 'dark'):
            home(slug, plat, theme)
