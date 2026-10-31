#!/usr/bin/env python
"""Hugeicons glif verisinden BuIcons.ttf + bu_icons.dart uretir.

Kullanim (repo kokunden):
  python -I -X utf8 mobile/tools/icons/build_icons.py [--scale 1.0]

Girdi : icon_map.json, hugeicons_subset.json, icon_codepoints.json (ekleme-yalniz kod noktasi kaydi)
Cikti : mobile/assets/fonts/BuIcons.ttf        (em 24 birim ızgara -> 2400 upm, ascent=em, descent=0)
        mobile/lib/core/icons/bu_icons.dart    (BuIcons sabitleri, ANLAMSAL adlar)
        icon_codepoints.json                   (yeni adlar icin sonraki bos kod noktasi)

Yontem: her SVG ogesi skia-pathops ile stroke edilir (cizgi kalinligi 1.75, element basina cap/join),
birlestirilir, y ekseni cevrilir, kubik -> kuadratik (cu2qu) cevrilip TrueType glif yazilir.
Dolu glifler (<ad>Filled) FILLED_RECIPES'e gore uretilir (bkz. bu_icon_lib.py).
"""
import json
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.areaPen import AreaPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.reverseContourPen import ReverseContourPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I kipinde betik dizini yolda degildir
import bu_icon_lib as lib  # noqa: E402

HERE = lib.HERE
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
FONT_OUT = os.path.join(ROOT, "mobile", "assets", "fonts", "BuIcons.ttf")
DART_OUT = os.path.join(ROOT, "mobile", "lib", "core", "icons", "bu_icons.dart")
UPM = 2400            # 100 birim = 1 px (24 px izgara)
CU2QU_ERR = 0.6       # birim (0.006 px)
FIRST_CP = 0xE000


def build_glyph(path, scale):
    """pathops Path (24x24, y asagi) -> TrueType glif (UPM, y yukari, dis kontur saat yonunde)."""
    k = UPM / 24.0 * scale
    off = UPM * (1 - scale) / 2.0
    xf = (k, 0, 0, -k, off, UPM - off)
    rec = RecordingPen()
    path.draw(TransformPen(rec, xf))
    ap = AreaPen(None)
    rec.replay(ap)
    reverse = ap.value > 0  # y yukari ve pozitif alan = saat yonunun tersi -> ters cevir
    tt = TTGlyphPen(None)
    target = ReverseContourPen(tt) if reverse else tt
    rec.replay(Cu2QuPen(target, CU2QU_ERR, reverse_direction=False))
    return tt.glyph()


def main():
    scale = 1.0
    if "--scale" in sys.argv:
        scale = float(sys.argv[sys.argv.index("--scale") + 1])
    mp = lib.load_json("icon_map.json")
    sub = lib.load_json("hugeicons_subset.json")["icons"]
    cp_file = os.path.join(HERE, "icon_codepoints.json")
    cps = json.load(open(cp_file, encoding="utf8")) if os.path.exists(cp_file) else {}

    # glif listesi: ad -> (path, kaynak aciklamasi)
    glyphs = {}
    for name, huge in mp["glyphs"].items():
        glyphs[name] = (lib.stroke_glyph(sub[huge]), huge)
    for base in mp["filled"]:
        huge = mp["glyphs"][base]
        glyphs[base + "Filled"] = (lib.filled_glyph(sub[huge], lib.FILLED_RECIPES[base]), huge + " (dolu)")

    names = sorted(glyphs)
    used = set(cps.values())
    nxt = FIRST_CP
    for n in names:
        if n not in cps:
            while nxt in used:
                nxt += 1
            cps[n] = nxt
            used.add(nxt)
    with open(cp_file, "w", encoding="utf8", newline="\n") as f:
        json.dump(dict(sorted(cps.items())), f, indent=1)
        f.write("\n")

    # --- font ---
    order = [".notdef"] + names
    glyf = {".notdef": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (UPM, 0)}
    empty = []
    for n in names:
        g = build_glyph(glyphs[n][0], scale)
        glyf[n] = g
        if g.numberOfContours == 0:
            empty.append(n)
    if empty:
        sys.exit("bos glif: %s" % empty)
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cps[n]: n for n in names})
    fb.setupGlyf(glyf)
    for n in names:
        g = glyf[n]
        g.recalcBounds(fb.font["glyf"])
        metrics[n] = (UPM, int(round(g.xMin)))
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=UPM, descent=0, lineGap=0)
    fb.setupNameTable({"familyName": "BuIcons", "styleName": "Regular",
                       "uniqueFontIdentifier": "BuIcons-Regular;hugeicons-4.4.0",
                       "fullName": "BuIcons Regular", "psName": "BuIcons-Regular", "version": "Version 1.000",
                       "copyright": "Glyph outlines derived from Hugeicons 4.4.0 (MIT), Copyright (c) 2024 Halal Labs / Hugeicons"})
    fb.setupOS2(sTypoAscender=UPM, sTypoDescender=0, sTypoLineGap=0, usWinAscent=UPM, usWinDescent=0,
                sxHeight=UPM // 2, sCapHeight=UPM, fsType=0, achVendID="BU  ", usWeightClass=400)
    fb.setupPost(keepGlyphNames=True)
    os.makedirs(os.path.dirname(FONT_OUT), exist_ok=True)
    fb.save(FONT_OUT)

    # --- dart ---
    lucide_keep = mp["lucide_keep"]
    lines = []
    lines.append("// ÜRETİLMİŞ DOSYA: elle düzenlemeyin. Kaynak: mobile/tools/icons/build_icons.py")
    lines.append("// Glifler Hugeicons 4.4.0 (MIT, bkz. assets/licenses/hugeicons-MIT.txt) verisinden üretilmiş")
    lines.append("// BuIcons.ttf yazı tipindedir; çalışma zamanında SVG ayrıştırması YOKTUR (Lucide ile aynı maliyet).")
    lines.append("import 'package:flutter/widgets.dart';")
    lines.append("import 'package:lucide_icons_flutter/lucide_icons.dart';")
    lines.append("")
    lines.append("/// Uygulamanın tek ikon kapısı. Anlamsal ad (Lucide adından türetildi) -> Hugeicons glifi.")
    lines.append("/// Dolu hâller `<ad>Filled`. Hugeicons'ta karşılığı olmayan iki ikon Lucide'de kalır.")
    lines.append("abstract final class BuIcons {")
    lines.append("  /// Yazı tipi ailesi (pubspec.yaml `fonts:` ile aynı olmalı).")
    lines.append("  static const String fontFamily = 'BuIcons';")
    lines.append("")
    lu = mp["lucide"]
    mat = mp["material"]
    for n in names:
        notes = [glyphs[n][1]]
        if n in lu:
            notes.append("Lucide " + n)
        mats = sorted(m for m, v in mat.items() if v["bu"] == n)
        if mats:
            notes.append("Material " + ", ".join(mats))
        lines.append("  /// Hugeicons %s" % "; ".join(notes))
        lines.append("  static const IconData %s = IconData(0x%04x, fontFamily: 'BuIcons');" % (n, cps[n]))
    lines.append("")
    lines.append("  // Hugeicons ücretsiz kümesinde karşılığı olmayanlar: Lucide'de kalır (tek kapı).")
    for n in lucide_keep:
        lines.append("  static const IconData %s = LucideIcons.%s;" % (n, n))
    lines.append("}")
    lines.append("")
    os.makedirs(os.path.dirname(DART_OUT), exist_ok=True)
    with open(DART_OUT, "w", encoding="utf8", newline="\n") as f:
        f.write("\n".join(lines))
    print("glif=%d font=%s (%d bayt) dart=%s scale=%g" % (len(names), FONT_OUT, os.path.getsize(FONT_OUT), DART_OUT, scale))


if __name__ == "__main__":
    main()
