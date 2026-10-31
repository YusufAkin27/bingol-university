#!/usr/bin/env python
"""BuIcons.ttf glif kalitesini bagimsiz referansla karsilastirir ve kontrol tahtalari uretir.

On kosul (bir kez):  cd mobile/tools/icons && npm install --no-package-lock   (resvg, yalniz gelistirme)
                     pip install numpy pillow fonttools skia-pathops
Kullanim (repo kokunden):
  python -I -X utf8 mobile/tools/icons/verify_icons.py [--boards C:/bu_design/icons]

Referans: ayni Hugeicons SVG'si (stroke 1.75, element cap/join) resvg ile cizilir.
Aday    : BuIcons.ttf glifi PIL/FreeType ile cizilir.
Karsilastirma 8x ust ornekle, kutu filtresiyle 16/20/24 px'e indirilerek yapilir (Flutter/Skia
yazi tipini ipucusuz ve alt piksel konumlu cizer; 8x ust ornek bunu yaklasik taklit eder),
ayrica 96 px dogrudan karsilastirilir (geometri hatasi: delik/bosluk/kalinlik sapmasi).
Cikti: metrik ozeti (stdout + work/verify_report.json) ve boards/migrate_kontrol_*.png
"""
import functools
import json
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I kipinde betik dizini yolda degildir
import bu_icon_lib as lib  # noqa: E402

HERE = lib.HERE
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
FONT = os.path.join(ROOT, "mobile", "assets", "fonts", "BuIcons.ttf")
WORK = os.path.join(HERE, "work")
SS = 8
SIZES = (16, 20, 24)
LUCIDE_TTF = "C:/pubcache/hosted/pub.dev/lucide_icons_flutter-4.0.1/assets/lucide.ttf"
LUCIDE_DART = "C:/pubcache/hosted/pub.dev/lucide_icons_flutter-4.0.1/lib/lucide_icons.dart"
# BuTokens (core/theme.dart) acik tema
C_BG, C_INK, C_MUT, C_PR, C_SOFT = (247, 245, 242), (23, 30, 51), (92, 90, 86), (192, 57, 43), (251, 233, 230)


def label_font(size):
    for p in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


@functools.lru_cache(maxsize=None)
def _font(path, px):
    return ImageFont.truetype(path, px)


def font_cov(font_path, cp, px):
    """Glifin kapsama dizisi (0..1), ordaki px x px kutuda; taban cizgisi kutu altinda."""
    f = _font(font_path, px)
    im = Image.new("L", (px, px), 255)
    ImageDraw.Draw(im).text((0, px), chr(cp), font=f, fill=0, anchor="ls")
    return 1.0 - np.asarray(im, dtype=np.float32) / 255.0


def png_cov(path):
    return 1.0 - np.asarray(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def box_down(a, k):
    h, w = a.shape
    return a.reshape(h // k, k, w // k, k).mean(axis=(1, 3))


def to_img(cov, scale=1, color=(0, 0, 0), bg=(255, 255, 255)):
    h, w = cov.shape
    rgb = np.empty((h, w, 3), dtype=np.float32)
    for i in range(3):
        rgb[..., i] = bg[i] * (1 - cov) + color[i] * cov
    im = Image.fromarray(rgb.clip(0, 255).astype(np.uint8))
    return im.resize((w * scale, h * scale), Image.NEAREST) if scale != 1 else im


def build_jobs(names, mp, sub, cps):
    os.makedirs(WORK, exist_ok=True)
    jobs = []
    for n in names:
        if n.endswith("Filled") and n[:-6] in mp["filled"]:
            base = n[:-6]
            els = sub[mp["glyphs"][base]]
            rec = lib.FILLED_RECIPES[base]
        else:
            els = sub[mp["glyphs"][n]]
            rec = None
        for size in tuple(s * SS for s in SIZES):
            svg = lib.reference_svg(els, rec, bg="#fff", size=size)
            jobs.append({"svg": svg, "size": size, "out": os.path.join(WORK, "ref_%s_%d.png" % (n, size))})
    return jobs


def lucide_codepoints():
    cps = {}
    if not os.path.exists(LUCIDE_DART):
        return cps
    s = open(LUCIDE_DART, encoding="utf8").read()
    for m in re.finditer(r"static const IconData (\w+) = const IconData\((\d+),\s*fontFamily: 'Lucide',", s):
        cps[m.group(1)] = int(m.group(2))
    return cps


def main():
    boards = "C:/bu_design/icons"
    if "--boards" in sys.argv:
        boards = sys.argv[sys.argv.index("--boards") + 1]
    os.makedirs(boards, exist_ok=True)
    mp = lib.load_json("icon_map.json")
    sub = lib.load_json("hugeicons_subset.json")["icons"]
    cps = lib.load_json("icon_codepoints.json")
    names = sorted(cps)

    jobs = build_jobs(names, mp, sub, cps)
    jf = os.path.join(WORK, "jobs.json")
    json.dump(jobs, open(jf, "w", encoding="utf8"))
    if "--force" not in sys.argv:
        jobs = [j for j in jobs if not os.path.exists(j["out"])]  # tarif degistiyse --force
        json.dump(jobs, open(jf, "w", encoding="utf8"))
    if jobs:
        subprocess.check_call(["node", os.path.join(HERE, "render_ref.mjs"), jf], cwd=HERE)

    rep = {}
    cache = {}
    for n in names:
        r96 = png_cov(os.path.join(WORK, "ref_%s_%d.png" % (n, 24 * SS)))  # 192 px: 24 dp @8x
        f96 = font_cov(FONT, cps[n], 24 * SS)
        inter = np.minimum(r96 > 0.5, f96 > 0.5).sum()
        union = np.maximum(r96 > 0.5, f96 > 0.5).sum()
        d = {"iou": float(inter / max(union, 1)), "ink": float(f96.sum() / max(r96.sum(), 1e-6)),
             "empty": bool(f96.sum() < 5)}
        for s in SIZES:
            r = box_down(png_cov(os.path.join(WORK, "ref_%s_%d.png" % (n, s * SS))), SS)
            f = box_down(font_cov(FONT, cps[n], s * SS), SS)
            d["mad%d" % s] = float(np.abs(r - f).mean())
            d["max%d" % s] = float(np.abs(r - f).max())
            d["ink%d" % s] = float(f.sum() / max(r.sum(), 1e-6))
            cache[(n, s)] = (r, f)
        rep[n] = d
    json.dump(rep, open(os.path.join(WORK, "verify_report.json"), "w", encoding="utf8"), indent=1)

    # ozet
    def worst(key, k=6, rev=False):
        return sorted(rep, key=lambda n: rep[n][key], reverse=not rev)[:k]
    iou = [rep[n]["iou"] for n in names]
    print("glif=%d  IoU@192: min=%.4f ortalama=%.4f" % (len(names), min(iou), sum(iou) / len(iou)))
    for key in ("mad16", "mad20", "mad24"):
        v = [rep[n][key] for n in names]
        print("%s ortalama=%.5f en kotu=%.5f (%s)" % (key, sum(v) / len(v), max(v), worst(key, 1)[0]))
    ink = [rep[n]["ink16"] for n in names]
    print("ink16 (font/referans) min=%.3f max=%.3f" % (min(ink), max(ink)))
    print("en dusuk IoU@192:", [(n, round(rep[n]["iou"], 4)) for n in worst("iou", 6, rev=True)])
    print("en kotu mad16 :", [(n, round(rep[n]["mad16"], 4)) for n in worst("mad16", 6)])
    bad = [n for n in names if rep[n]["empty"] or rep[n]["iou"] < 0.93 or not (0.95 < rep[n]["ink"] < 1.05) or rep[n]["mad24"] > 0.03]
    print(("ESIK DISI: %s" % (bad,)) if bad else "ESIK DISI: yok")

    # tahta 1..N: referans | font | fark (24 px, 4x) + 16 px (4x) ikililer
    lf = label_font(12)
    lf2 = label_font(10)
    per_col, cols = 14, 2
    rowh, colw = 104, 640
    pages = [names[i:i + per_col * cols] for i in range(0, len(names), per_col * cols)]
    for pi, page in enumerate(pages):
        img = Image.new("RGB", (colw * cols, rowh * per_col + 28), (255, 255, 255))
        dr = ImageDraw.Draw(img)
        dr.text((6, 6), "BuIcons kontrol %d/%d  |  sütunlar: referans SVG(24) | font(24) | fark x4 | ref(16) | font(16)  (hepsi 4x yakınlaştırma)" % (pi + 1, len(pages)), fill=(0, 0, 0), font=lf)
        for i, n in enumerate(page):
            cx, cy = (i // per_col) * colw, 28 + (i % per_col) * rowh
            dr.text((cx + 6, cy + 30), n, fill=(0, 0, 0), font=lf)
            dr.text((cx + 6, cy + 48), "iou %.3f ink %.2f" % (rep[n]["iou"], rep[n]["ink24"]), fill=(90, 90, 90), font=lf2)
            r24, f24 = cache[(n, 24)]
            r16, f16 = cache[(n, 16)]
            img.paste(to_img(r24, 4), (cx + 150, cy + 4))
            img.paste(to_img(f24, 4), (cx + 256, cy + 4))
            diff = np.abs(r24 - f24) * 4
            img.paste(to_img(diff.clip(0, 1), 4, color=(200, 0, 0)), (cx + 362, cy + 4))
            img.paste(to_img(r16, 4), (cx + 468, cy + 20))
            img.paste(to_img(f16, 4), (cx + 538, cy + 20))
        img.save(os.path.join(boards, "migrate_kontrol_%02d_referans_font.png" % (pi + 1)))

    # Lucide ile agirlik/boyut karsilastirmasi
    lcp = lucide_codepoints()
    common = [n for n in names if n in lcp and not n.endswith("Filled")]
    ratios = []
    ratios_ink = []
    items = []
    # Lucide em = 1000, bizimki 2400: PIL px'e gore olcekler, ayni px kutuda karsilastirilir
    def bbox(cov):
        ys, xs = np.where(cov > 0.5)
        return (xs.max() - xs.min() + 1, ys.max() - ys.min() + 1) if len(xs) else (0, 0)
    for n in common:
        l = font_cov(LUCIDE_TTF, lcp[n], 192)
        b = font_cov(FONT, cps[n], 192)
        lw, lh = bbox(l)
        bw, bh = bbox(b)
        if lw and bw:
            ratios.append(((bw * bh) ** 0.5) / ((lw * lh) ** 0.5))
            ratios_ink.append(b.sum() / max(l.sum(), 1e-6))
    ratios = np.array(ratios)
    ratios_ink = np.array(ratios_ink)
    print("Lucide'e gore sınırlayıcı kutu oranı (BuIcons/Lucide, geometrik ort): medyan=%.3f p10=%.3f p90=%.3f" % (np.median(ratios), np.percentile(ratios, 10), np.percentile(ratios, 90)))
    print("Lucide'e gore mürekkep oranı: medyan=%.3f p10=%.3f p90=%.3f" % (np.median(ratios_ink), np.percentile(ratios_ink, 10), np.percentile(ratios_ink, 90)))

    per_row = 4
    cellw, cellh = 330, 62
    chunk = 44
    for ci in range(0, len(common), chunk * per_row // per_row * 1):
        sel = common[ci:ci + chunk]
        rows = (len(sel) + per_row - 1) // per_row
        img = Image.new("RGB", (cellw * per_row, rows * cellh + 26), (255, 255, 255))
        dr = ImageDraw.Draw(img)
        dr.text((6, 5), "Lucide | BuIcons  (24 px ve 16 px, 2x yakınlaştırma; her ad: Lucide solda, Hugeicons-fontu sağda)", fill=(0, 0, 0), font=lf)
        for i, n in enumerate(sel):
            cx, cy = (i % per_row) * cellw, 26 + (i // per_row) * cellh
            dr.text((cx + 4, cy + 22), n[:14], fill=(0, 0, 0), font=lf2)
            x = cx + 100
            for s in (24, 16):
                lc = box_down(font_cov(LUCIDE_TTF, lcp[n], s * SS), SS)
                bc = box_down(font_cov(FONT, cps[n], s * SS), SS)
                img.paste(to_img(lc, 2), (x, cy + 6))
                img.paste(to_img(bc, 2), (x + s * 2 + 4, cy + 6))
                x += s * 4 + 16
        img.save(os.path.join(boards, "migrate_kontrol_lucide_karsilastirma_%d.png" % (ci // chunk + 1)))

    # dolu hal tahtasi + alt bar
    filled = [n for n in names if n.endswith("Filled")]
    cell = 150
    img = Image.new("RGB", (cell * 7, 3 * 130 + 30), (255, 255, 255))
    dr = ImageDraw.Draw(img)
    dr.text((6, 6), "Dolu glifler (üst: çizgi, alt: dolu; 48 px, 24 px, 16 px)", fill=(0, 0, 0), font=lf)
    for i, n in enumerate(filled):
        base = n[:-6]
        cx, cy = (i % 7) * cell, 30 + (i // 7) * 130
        dr.text((cx + 6, cy + 2), n, fill=(0, 0, 0), font=lf2)
        for j, nm in enumerate((base, n)):
            y = cy + 18 + j * 54
            img.paste(to_img(box_down(font_cov(FONT, cps[nm], 48 * SS), SS), 1), (cx + 6, y))
            img.paste(to_img(box_down(font_cov(FONT, cps[nm], 24 * SS), SS), 1), (cx + 62, y + 12))
            img.paste(to_img(box_down(font_cov(FONT, cps[nm], 16 * SS), SS), 1), (cx + 94, y + 16))
    img.save(os.path.join(boards, "migrate_kontrol_dolu_haller.png"))

    # alt bar etkin/pasif (BuTokens acik + koyu), 22 dp
    tabs = [("home", "homeFilled"), ("discover", "discoverFilled"), ("chat", "chatFilled"), ("users", "usersFilled"), ("bell", "bellFilled")]
    W = 6 * 140
    img = Image.new("RGB", (W, 330), C_BG)
    dr = ImageDraw.Draw(img)
    dr.text((6, 6), "Alt bar önerisi: pasif (mut) | etkin: (a) yalnız renk+hap, (b) dolu glif+hap   (22 dp @3x)", fill=C_INK, font=lf)
    def glyph_img(nm, color, px):
        cov = box_down(font_cov(FONT, cps[nm], px * SS), SS)
        return cov
    rows = [("pasif", lambda o, f: (o, C_MUT, None)), ("etkin: renk + hap", lambda o, f: (o, C_PR, C_SOFT)), ("etkin: dolu + hap", lambda o, f: (f, C_PR, C_SOFT))]
    for ri, (title, fn) in enumerate(rows):
        y = 40 + ri * 96
        dr.text((6, y + 30), title, fill=C_INK, font=lf2)
        for ti, (o, f) in enumerate(tabs):
            nm, color, pill = fn(o, f)
            cx = 130 + ti * 100
            gx, gy = cx, y + 10  # glif 66x66 px (22 dp @3x)
            if pill:
                dr.rounded_rectangle((gx - 12, gy - 6, gx + 78, gy + 72), radius=39, fill=pill)
            cov = glyph_img(nm, color, 66)
            mask = Image.fromarray((cov * 255).astype(np.uint8))
            img.paste(Image.new("RGB", mask.size, color), (gx, gy), mask)
    img.save(os.path.join(boards, "migrate_kontrol_alt_bar.png"))
    print("tahtalar ->", boards)


if __name__ == "__main__":
    main()
