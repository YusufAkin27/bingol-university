# -*- coding: utf-8 -*-
"""Bildirim kategori karolari (Android buyuk simge): yuvarlak yumusak zemin + BuIcons glifi.
Kaynak: assets/fonts/BuIcons.ttf (Hugeicons, MIT). Cikti: assets/notif/tile_<ad>.png (192x192, saydam arka plan).
Calistirma: python -I -X utf8 tools/notif/build_notif_tiles.py  (mobile/ klasorunden). Pillow gerekir."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "assets", "fonts", "BuIcons.ttf")
OUT = os.path.join(ROOT, "assets", "notif")
SIZE = 192
SS = 4  # asiri ornekleme (kenar yumusatma)

# ton: (zemin, glif)
TONES = {
    "red": ("#FDE3E1", "#C4281C"),
    "indigo": ("#E3E7FF", "#3A47B5"),
    "green": ("#DDF5E6", "#1D7A47"),
    "navy": ("#E6E9F2", "#1B2540"),
    "amber": ("#FFF0D6", "#A8620A"),
}
# ad: (glif kod noktasi, ton)
TILES = {
    "event": (0xE017, "indigo"),          # calendarDays
    "event_soon": (0xE032, "red"),        # clock
    "event_update": (0xE016, "indigo"),   # calendarClock
    "event_ok": (0xE015, "green"),        # calendarCheck
    "event_cancel": (0xE019, "red"),      # calendarX
    "announcement": (0xE069, "red"),      # megaphone
    "dept": (0xE095, "navy"),             # squareTerminal
    "academic": (0xE04A, "indigo"),       # graduationCap
    "news": (0xE071, "navy"),             # newspaper
    "exam": (0xE030, "indigo"),           # clipboardCheck
    "class": (0xE000, "indigo"),          # alarmClock
    "homework": (0xE072, "amber"),        # notebookPen
    "menu": (0xE0AB, "amber"),            # utensils
    "poll": (0xE0AF, "indigo"),           # vote
    "like": (0xE050, "red"),              # heartFilled
    "follow": (0xE0A6, "indigo"),         # userPlus
    "follow_ok": (0xE0A3, "green"),       # userCheck
    "device": (0xE092, "red"),            # smartphone
    "password": (0xE064, "red"),          # lockKeyhole
    "twofa": (0xE08F, "indigo"),          # shieldCheck
    "session": (0xE066, "red"),           # logOut
    "support": (0xE04E, "indigo"),        # headset
    "generic": (0xE00C, "navy"),          # bell
}


def render(name, code, tone):
    bg, fg = TONES[tone]
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, big - 1, big - 1), fill=bg)
    font = ImageFont.truetype(FONT, int(big * 0.52))
    ch = chr(code)
    l, t, r, b = d.textbbox((0, 0), ch, font=font)
    d.text(((big - (r - l)) / 2 - l, (big - (b - t)) / 2 - t), ch, font=font, fill=fg)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, "tile_%s.png" % name), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (code, tone) in TILES.items():
        render(name, code, tone)
    print("ok", len(TILES))


if __name__ == "__main__":
    main()
