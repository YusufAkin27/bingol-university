"""Ortak geometri: Hugeicons SVG ogelerini dolu kontura cevirir (skia-pathops).

Bagimlilik:  pip install skia-pathops fonttools pillow
Tum islemler 24x24 SVG izgarasinda yapilir; font birimine cevirme build_icons.py'de.
"""
import json
import os
import re

from fontTools.svgLib.path import parse_path
import pathops
from pathops import FillType, LineCap, LineJoin, Path, PathOp

HERE = os.path.dirname(os.path.abspath(__file__))
STROKE_WIDTH = 1.75   # tum ikonlarda tek kalinlik (belge: Lucide 2.0'a en yakin gorsel agirlik)
CUT_WIDTH = 2.0       # dolu glifte ic ayrintiyi oyan cizgi kalinligi
MITER_LIMIT = 4.0     # SVG varsayilani
STROKE_RES = 100.0    # Skia stroker offset egrilerini kaba (kuadratik) yaklasiklar; 100x buyutup stroke et (hata ~%0.03), geri olcekle

# Dolu (filled) glif tarifleri: fill = doldurulan kapali ogeler (cizgisiyle birlikte),
# cut = dolgudan OYULAN ogeler (ic ayrinti), cutfill = oyulurken icini de bosaltilanlar.
FILLED_RECIPES = {
    "heart": {"fill": [0]},
    "star": {"fill": [0]},
    "bookmark": {"fill": [0]},
    "bell": {"fill": [1]},
    "home": {"fill": [0]},
    "chat": {"fill": [0], "cut": [1]},
    "users": {"fill": [0, 1]},
    "discover": {"fill": [0], "cut": [1, 2], "cutfill": [1]},
    "circleCheck": {"fill": [0], "cut": [1]},
    "circleAlert": {"fill": [0], "cut": [1, 2]},
    "triangleAlert": {"fill": [0], "cut": [1, 2]},
    "play": {"fill": [0]},
    "pause": {"fill": [0, 1]},
}

_CAPS = {"butt": LineCap.BUTT_CAP, "round": LineCap.ROUND_CAP, "square": LineCap.SQUARE_CAP}
_JOINS = {"miter": LineJoin.MITER_JOIN, "round": LineJoin.ROUND_JOIN, "bevel": LineJoin.BEVEL_JOIN}


def load_json(name):
    with open(os.path.join(HERE, name), encoding="utf8") as f:
        return json.load(f)


def _num(a, k, d=0.0):
    return float(a.get(k, d))


def element_geometry(tag, a):
    """Ogenin cizgi yolunu (stroke edilmemis) Path olarak dondurur."""
    p = Path()
    if tag == "path":
        parse_path(a["d"], p.getPen())
    elif tag == "circle":
        cx, cy, r = _num(a, "cx"), _num(a, "cy"), _num(a, "r")
        d = "M%g %gA%g %g 0 1 0 %g %gA%g %g 0 1 0 %g %gZ" % (cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy)
        parse_path(d, p.getPen())
    elif tag == "ellipse":
        cx, cy, rx, ry = _num(a, "cx"), _num(a, "cy"), _num(a, "rx"), _num(a, "ry")
        d = "M%g %gA%g %g 0 1 0 %g %gA%g %g 0 1 0 %g %gZ" % (cx - rx, cy, rx, ry, cx + rx, cy, rx, ry, cx - rx, cy)
        parse_path(d, p.getPen())
    elif tag == "rect":
        x, y, w, h = _num(a, "x"), _num(a, "y"), _num(a, "width"), _num(a, "height")
        rx = _num(a, "rx", _num(a, "ry", 0))
        if rx > 0:
            d = ("M%g %gH%gA%g %g 0 0 1 %g %gV%gA%g %g 0 0 1 %g %gH%gA%g %g 0 0 1 %g %gV%gA%g %g 0 0 1 %g %gZ"
                 % (x + rx, y, x + w - rx, rx, rx, x + w, y + rx, y + h - rx, rx, rx, x + w - rx, y + h,
                    x + rx, rx, rx, x, y + h - rx, y + rx, rx, rx, x + rx, y))
        else:
            d = "M%g %gH%gV%gH%gZ" % (x, y, x + w, y + h, x)
        parse_path(d, p.getPen())
    else:
        raise ValueError("desteklenmeyen oge: " + tag)
    if "transform" in a:
        raise ValueError("transform desteklenmiyor")
    if "strokeDasharray" in a:
        raise ValueError("strokeDasharray desteklenmiyor")
    return p


def _clone(p):
    q = Path()
    q.addPath(p)
    q.fillType = p.fillType
    return q


def stroke_region(tag, a, width=STROKE_WIDTH, force_round=False):
    """Ogenin cizgisinin dolu konturlari (LISTE). Alt yollar ayri ayri stroke edilir: Skia PathOps,
    cok alt yollu tek stroke ciktisini birlestirirken parca kaybedebiliyor (UserCog'da gorulen hata)."""
    g = element_geometry(tag, a)
    cap = LineCap.ROUND_CAP if force_round else _CAPS[a.get("strokeLinecap", "butt")]
    join = LineJoin.ROUND_JOIN if force_round else _JOINS[a.get("strokeLinejoin", "miter")]
    miter = float(a.get("strokeMiterlimit", MITER_LIMIT))
    out = []
    for c in g.contours:
        q = Path()
        q.addPath(c.transform(STROKE_RES, 0, 0, STROKE_RES))
        q.stroke(width * STROKE_RES, cap, join, miter)
        q.convertConicsToQuads(0.05)  # TrueType icin kuadratik
        r = Path()
        r.addPath(q.transform(1.0 / STROKE_RES, 0, 0, 1.0 / STROKE_RES))
        r.fillType = FillType.WINDING
        out.append(r)
    return out


def _close_subpaths(d):
    """Dolgu icin acik alt yollari kapat (SVG dolgusu da dolayli kapatir)."""
    segs = re.findall(r"[Mm][^Mm]*", d)
    return "".join(x.rstrip() if x.rstrip()[-1] in "zZ" else x.rstrip() + "Z" for x in segs) or d


def fill_region(tag, a, evenodd=None):
    if tag == "path":
        a = dict(a, d=_close_subpaths(a["d"]))
    p = element_geometry(tag, a)
    eo = (a.get("fillRule") == "evenodd") if evenodd is None else evenodd
    p.fillType = FillType.EVEN_ODD if eo else FillType.WINDING
    return p


def has_stroke(a):
    return a.get("stroke", "none") != "none"


def has_fill(a):
    return a.get("fill", "none") not in ("none", "")


def _safe_simplify(p, min_ratio=0.5):
    """(yol, tamam). simplify; Skia PathOps cok yakin/dejenere parcali yollarda (SquareArrowOutUpRight
    oku) hata verir ya da sessizce parca siler. Alan makul degilse ya da hata olursa yolu oldugu gibi
    birakir (tamam=False; nonzero dolgu ortusen konturlari zaten dogru boyar)."""
    q = _clone(p)
    try:
        q.simplify(fix_winding=True)
    except Exception:
        return _clone(p), False
    if abs(p.area) > 1e-6 and abs(q.area) < min_ratio * abs(p.area):
        return _clone(p), False
    return q, True


def _canonical(p):
    """Dis kontur yonunu tum parcalarda ayni yap (alan > 0)."""
    q = _clone(p)
    q.fillType = FillType.WINDING
    if q.area < 0:
        q.reverse()
    return q


def _flatten(parts):
    """Parcalari tek yolda toplar, ortusmeyi mumkunse temizler (nonzero birlesim).
    NOT: OpBuilder ile cok operandli UNION, butt-cap ucu halka ile kesistiginde parca kaybediyor
    (Share08'de gorulen hata); normallestir + concat + simplify dogrulandi. Parcalardan biri
    simplify edilemezse birlesim de simplify EDILMEZ (kayip riski); TrueType nonzero ortusmeyi destekler."""
    cat = Path()
    all_ok = True
    for p in parts:
        q, ok = _safe_simplify(p)
        all_ok = all_ok and ok
        cat.addPath(_canonical(q))
    cat.fillType = FillType.WINDING
    if not all_ok:
        return cat
    q, ok = _safe_simplify(cat, min_ratio=0.7)
    return q if ok else cat


def _combine(parts, subtract=()):
    r = _flatten(parts)
    if subtract:
        r = pathops.op(r, _flatten(subtract), PathOp.DIFFERENCE, fix_winding=True)  # yalniz dolu glif tarifleri
    return r


def stroke_glyph(elements):
    """Cizgi stili: her oge kendi cap/join'i ile stroke edilir (+ fill: currentColor ogeleri)."""
    parts = []
    for tag, a in elements:
        if has_fill(a):
            parts.append(fill_region(tag, a))
        if has_stroke(a):
            parts.extend(stroke_region(tag, a))
    return _combine(parts)


def filled_glyph(elements, recipe):
    """Dolu stil: recipe['fill'] ogeleri doldurulur (+cizgi), recipe['cut'] ogeleri oyulur."""
    fill = set(recipe.get("fill", []))
    cut = set(recipe.get("cut", []))
    cutfill = set(recipe.get("cutfill", []))
    parts, sub = [], []
    for i, (tag, a) in enumerate(elements):
        if i in cut:
            if i in cutfill:
                sub.append(fill_region(tag, a, evenodd=False))
            sub.extend(stroke_region(tag, a, width=CUT_WIDTH, force_round=True))
            continue
        if i in fill:
            parts.append(fill_region(tag, a, evenodd=False))
        if has_stroke(a):
            parts.extend(stroke_region(tag, a))
        elif has_fill(a):
            parts.append(fill_region(tag, a))
    return _combine(parts, sub)


def reference_svg(elements, recipe=None, color="#000", bg=None, size=24, stroke_width=STROKE_WIDTH):
    """Ayni ikonun bagimsiz (resvg ile cizilecek) SVG'si: dogrulama referansi."""
    fill = set((recipe or {}).get("fill", []))
    cut = set((recipe or {}).get("cut", []))
    cutfill = set((recipe or {}).get("cutfill", []))

    def attr(a, extra):
        out = []
        for k, v in a.items():
            if k in ("stroke", "strokeWidth", "fill"):
                continue
            out.append('%s="%s"' % (re.sub(r"([A-Z])", lambda m: "-" + m.group(1).lower(), k), v))
        return " ".join(out + extra)

    body = []
    for i, (tag, a) in enumerate(elements):
        if i in cut:
            continue
        ex = []
        ex.append('fill="%s"' % color if (i in fill or has_fill(a)) else 'fill="none"')
        if i in fill and "fillRule" in a:
            pass
        if has_stroke(a):
            ex += ['stroke="%s"' % color, 'stroke-width="%s"' % stroke_width]
        body.append("<%s %s/>" % (tag, attr(a, ex)))
    for i, (tag, a) in enumerate(elements):
        if i not in cut:
            continue
        a2 = dict(a)
        a2["strokeLinecap"] = "round"
        a2["strokeLinejoin"] = "round"
        white = bg or "#fff"
        ex = ['fill="%s"' % white if i in cutfill else 'fill="none"', 'stroke="%s"' % white, 'stroke-width="%s"' % CUT_WIDTH]
        body.append("<%s %s/>" % (tag, attr(a2, ex)))
    inner = "".join(body)
    back = '<rect width="24" height="24" fill="%s"/>' % bg if bg else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24">%s%s</svg>'
            % (size, size, back, inner))
