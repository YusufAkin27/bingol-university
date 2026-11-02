#!/usr/bin/env python
"""docs/design/IKON_HUGEICONS.md bolum 6 eslemesini icon_map.json'a cevirir.

Kullanim:  python -I -X utf8 mobile/tools/icons/parse_doc_map.py
Cikti:     mobile/tools/icons/icon_map.json  (committe tutulur; arac hatti bunu okur)

Anlamsal ad kurali:
  * Lucide ad ayni kalir (LucideIcons.chevronRight -> BuIcons.chevronRight).
  * Material adlari MATERIAL_NAMES ile anlamsal ada eslenir (asagida).
  * Dolu glifler FILLED listesindedir (<ad>Filled).
Karsiliksiz (zayif) ikonlar Lucide'de kalir: LUCIDE_KEEP.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "..", "..", "docs", "design", "IKON_HUGEICONS.md"))
OUT = os.path.join(HERE, "icon_map.json")

# Karsiligi olmayan ikonlar: BuIcons'ta Lucide'e isaret eder (tek kapi).
LUCIDE_KEEP = ["delete", "keyboard"]

# Material -> anlamsal BuIcons adi (Lucide'de karsiligi olmayanlar yeni ad alir).
MATERIAL_NAMES = {
    "check_rounded": "check",
    "favorite": "heartFilled",
    "play_arrow_rounded": "playFilled",
    "bookmark": "bookmarkFilled",
    "favorite_border": "heart",
    "more_horiz": "ellipsis",
    "add": "plus",
    "chat_bubble_outline_rounded": "chat",
    "chat_bubble_rounded": "chatFilled",
    "check_circle": "circleCheckFilled",
    "check_circle_rounded": "circleCheckFilled",
    "construction": "wrench",
    "error": "circleAlertFilled",
    "explore_outlined": "discover",
    "explore_rounded": "discoverFilled",
    "home_outlined": "home",
    "home_rounded": "homeFilled",
    "image_outlined": "image",
    "info_outline": "info",
    "pause_rounded": "pauseFilled",
    "people_outline_rounded": "users",
    "people_rounded": "usersFilled",
    "star_outline_rounded": "star",
    "star_rounded": "starFilled",
    "warning_rounded": "triangleAlertFilled",
}

# Belgedeki 167+25 eslemenin disinda sonradan eklenen ikonlar (BuIcons adi -> Hugeicons adi).
# Kampus haritasi (CAMPUS-MOB): harita, konum, katman, yurume, rota, kategori simgeleri.
EXTRA_GLYPHS = {
    "map": "Map",
    "locateFixed": "LocateFixed",
    "layers": "Layers01",
    "footprints": "Footprints",
    "navigation": "Navigation03",
    "cornerUpRight": "CornerUpRight",
    "parking": "ParkingAreaSquare",
    "car": "Car01",
    "flaskConical": "FlaskConical",
    "dumbbell": "Dumbbell01",
}

# Dolu (filled) glif: taban ad -> uretim tarifi build_icons.py icinde (FILLED_RECIPES).
FILLED = [
    "heart", "star", "bookmark", "bell", "home", "chat", "users",
    "discover", "circleCheck", "circleAlert", "triangleAlert", "play", "pause",
]


def cells(line):
    parts = [c.strip() for c in line.strip().strip("|").split("|")]
    return parts


def main():
    text = open(DOC, encoding="utf8").read()
    lucide = {}
    material = {}
    section = None
    for line in text.splitlines():
        if line.startswith("### 6.1"):
            section = "L"
        elif line.startswith("### 6.2"):
            section = "M"
        elif line.startswith("### 6.3") or line.startswith("## 7"):
            section = None
        if section and line.startswith("|") and "`strokeRounded" in line:
            c = cells(line)
            src = c[1].strip("`")
            huge = re.search(r"strokeRounded(\w+)", c[5]).group(1)
            conf = c[6]
            if section == "L":
                name = src.split(".", 1)[1]
                lucide[name] = {"huge": huge, "conf": conf, "uses": int(c[2])}
            else:
                name = src.split(".", 1)[1]
                material[name] = {"huge": huge, "conf": conf, "uses": int(c[2]), "bu": MATERIAL_NAMES[name]}
    missing = [m for m in MATERIAL_NAMES if m not in material]
    if missing or len(lucide) != 167 or len(material) != 25:
        sys.exit("beklenmeyen sayilar: lucide=%d material=%d eksik=%s" % (len(lucide), len(material), missing))

    glyphs = {}  # BuIcons adi -> hugeicons adi (stroke)
    for n, v in lucide.items():
        if n in LUCIDE_KEEP:
            continue
        glyphs[n] = v["huge"]
    for n, v in material.items():
        bu = v["bu"]
        base = bu[:-len("Filled")] if bu.endswith("Filled") else bu
        glyphs.setdefault(base, v["huge"])  # dolu ad icin de cizgi tabani gerekir
    glyphs.update(EXTRA_GLYPHS)
    # Dolu hallerin tabani glyphs'te olmali
    for f in FILLED:
        if f not in glyphs:
            sys.exit("dolu taban yok: " + f)

    out = {
        "hugeicons_version": "4.4.0",
        "lucide_keep": LUCIDE_KEEP,
        "filled": FILLED,
        "glyphs": dict(sorted(glyphs.items())),
        "lucide": lucide,
        "material": material,
    }
    with open(OUT, "w", encoding="utf8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=True, indent=1, sort_keys=False)
        f.write("\n")
    print("glyphs=%d lucide=%d material=%d filled=%d -> %s" % (len(glyphs), len(lucide), len(material), len(FILLED), OUT))


if __name__ == "__main__":
    main()
