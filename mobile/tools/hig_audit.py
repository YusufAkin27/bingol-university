#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HIG denetim betigi (salt-okunur): mobile/lib altini tarar, sayilari ve en kotu ornekleri uretir.

Calistirma (mobile/ icinden ya da herhangi bir yerden):
    python -I -X utf8 mobile/tools/hig_audit.py            # ozet tablo (ASCII)
    python -I -X utf8 mobile/tools/hig_audit.py --json out.json
    python -I -X utf8 mobile/tools/hig_audit.py --only contrast,color,font,spacing

Olcumler (docs/MOBILE_HIG_AUDIT.md ile ayni harf kodlari):
  contrast  (a) BuTokens renk ciftlerinin WCAG kontrasti (acik + koyu)
  taptarget (b-statik) 44 dp alti dokunma hedefi suphelileri
  color     (d) Color(0x..) / Colors.* dogrudan kullanimi (context.bu disi)
  font      (d) sabit fontSize (< 11, token disi)
  spacing   (d) EdgeInsets / SizedBox boslugu 4'un kati degil
  a11y      (e) tooltip'siz IconButton, etiketsiz Image, yalniz-simge dokunma
  states    (f) yukleniyor/bos/hata/bakim durumu eksik ekranlar
  forms     (g) klavye/safe area/autofill eksikleri
  rtl       (h-statik) sabit left/right kullanimi
  dark      (i) acik/koyu cift eksikleri
  tone      (j) metin tonu ornekleme (ARB)

Kod DUZELTMEZ; yalniz okur. Cikti ASCII'dir (Windows konsolunda guvenli).
"""
from __future__ import annotations

import argparse
import bisect
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # mobile/
LIB = ROOT / "lib"

THEME_DEF_FILES = {
    "lib/core/theme.dart",
    "lib/core/typography.dart",
}
THEME_DEF_PREFIXES = ("lib/core/theme/",)
SKIP_PREFIXES = ("lib/l10n/",)
GENERATED_HINT = "ÜRETİLMİŞ DOSYA"

# BuScale (lib/core/typography.dart): izinli yazi boyutlari
BU_SCALE = {22.0, 18.0, 16.0, 15.0, 14.0, 12.5, 11.5}
MIN_FONT = 11.0


def asc(s: str) -> str:
    return s.encode("ascii", "replace").decode("ascii")


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


# --------------------------------------------------------------------------- kaynak yardimcilari
class Src:
    def __init__(self, path: Path):
        self.path = path
        self.rel = rel(path)
        self.text = path.read_text(encoding="utf-8", errors="replace")
        self.starts = [0]
        for m in re.finditer(r"\n", self.text):
            self.starts.append(m.end())
        self._masked = None

    def line(self, idx: int) -> int:
        return bisect.bisect_right(self.starts, idx)

    def line_text(self, ln: int) -> str:
        a = self.starts[ln - 1]
        b = self.starts[ln] - 1 if ln < len(self.starts) else len(self.text)
        return self.text[a:b].strip()

    @property
    def masked(self) -> str:
        """Yorumlari ve dize iceriklerini bosluga ceviren kopya (indeksler korunur)."""
        if self._masked is None:
            self._masked = mask_source(self.text)
        return self._masked


def mask_source(t: str) -> str:
    """// ve /* */ yorumlarini, dize LITERALLERININ icerigini (cift/tek tirnak) bosluklarla kapatir."""
    out = list(t)
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        nxt = t[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            j = t.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif c == "/" and nxt == "*":
            j = t.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if t[k] != "\n":
                    out[k] = " "
            i = j
        elif c in ("'", '"'):
            q = c
            triple = t[i : i + 3] == q * 3
            raw = i > 0 and t[i - 1] == "r"
            j = i + (3 if triple else 1)
            while j < n:
                if not raw and t[j] == "\\":
                    j += 2
                    continue
                if triple and t[j : j + 3] == q * 3:
                    j += 3
                    break
                if not triple and t[j] == q:
                    j += 1
                    break
                if not triple and t[j] == "\n":
                    break
                j += 1
            for k in range(i + 1, max(i + 1, j - 1)):
                if t[k] != "\n":
                    out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


def call_args(masked: str, open_idx: int) -> tuple[str, int]:
    """open_idx '(' konumudur; dengeli parantez icindeki metni ve kapanis indeksini dondurur."""
    depth, i, n = 0, open_idx, len(masked)
    while i < n:
        c = masked[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return masked[open_idx + 1 : i], i
        i += 1
    return masked[open_idx + 1 :], n


def lib_sources(include_theme: bool = False) -> list[Src]:
    out = []
    for p in sorted(LIB.rglob("*.dart")):
        r = rel(p)
        if any(r.startswith(s) for s in SKIP_PREFIXES):
            continue
        s = Src(p)
        if GENERATED_HINT in s.text[:400]:
            continue
        if not include_theme and (r in THEME_DEF_FILES or r.startswith(THEME_DEF_PREFIXES)):
            continue
        out.append(s)
    return out


def severity_by_count(n: int, hi: int, mid: int) -> str:
    return "Yuksek" if n >= hi else ("Orta" if n >= mid else "Dusuk")


class Finding:
    def __init__(self, src: Src, idx: int, note: str = ""):
        self.file = src.rel
        self.line = src.line(idx)
        self.text = asc(src.line_text(self.line))[:140]
        self.note = note

    def d(self):
        return {"file": self.file, "line": self.line, "text": self.text, "note": self.note}


def summarize(findings: list[Finding], top_files: int = 15, examples: int = 10) -> dict:
    by_file = Counter(f.file for f in findings)
    return {
        "total": len(findings),
        "files": len(by_file),
        "top_files": by_file.most_common(top_files),
        "examples": [f.d() for f in findings[:examples]],
        "_all": findings,
    }


# --------------------------------------------------------------------------- (a) kontrast
def parse_color(h: str) -> tuple[int, int, int, float]:
    h = h.lstrip("#")
    if len(h) == 8:
        a = int(h[0:2], 16) / 255.0
        h = h[2:]
    else:
        a = 1.0
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a


def lin(c: int) -> float:
    s = c / 255.0
    return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4


def lum(rgb) -> float:
    r, g, b = rgb[:3]
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def blend(fg, bg, a):
    return tuple(round(fg[i] * a + bg[i] * (1 - a)) for i in range(3))


def ratio(a, b) -> float:
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def parse_tokens() -> dict:
    t = (LIB / "core/theme.dart").read_text(encoding="utf-8")
    # varsayilanlar (kurucu)
    ctor = t[t.index("const BuTokens({") : t.index("});", t.index("const BuTokens({"))]
    defaults = {m.group(1): m.group(2) for m in re.finditer(r"this\.(\w+)\s*=\s*const Color\(0x([0-9A-Fa-f]{8})\)", ctor)}

    def block(name):
        i = t.index(f"static const {name} = BuTokens(")
        j = t.index("\n  );", i)
        return t[i:j]

    res = {}
    for theme in ("light", "dark"):
        b = block(theme)
        vals = {m.group(1): m.group(2) for m in re.finditer(r"(\w+):\s*Color\(0x([0-9A-Fa-f]{8})\)", b)}
        merged = dict(defaults)
        merged.update(vals)
        res[theme] = {"explicit": set(vals), "colors": {k: parse_color(v) for k, v in merged.items()}}
    # tints
    tints = {}
    for theme, name in (("light", "_tintsLight"), ("dark", "_tintsDark")):
        i = t.index(f"static const {name}")
        j = t.index("];", i)
        pairs = re.findall(r"BuTint\(Color\(0x([0-9A-Fa-f]{8})\),\s*Color\(0x([0-9A-Fa-f]{8})\)\)", t[i:j])
        tints[theme] = [(parse_color(a), parse_color(b)) for a, b in pairs]
    return {"themes": res, "tints": tints, "defaults": set(defaults)}


TINT_NAMES = ["marka", "mavi", "yesil", "amber", "su mavisi", "notr"]

# (ad, on-plan, zemin, tur) tur: T = metin 4.5:1, L = buyuk metin/ikon/UI 3:1
PAIRS = [
    ("ink / bg", "ink", "bg", "T"),
    ("ink / sf", "ink", "sf", "T"),
    ("ink / sf2", "ink", "sf2", "T"),
    ("ink / sf3 (sheet/dialog)", "ink", "sf3", "T"),
    ("mut / bg", "mut", "bg", "T"),
    ("mut / sf", "mut", "sf", "T"),
    ("mut / sf2", "mut", "sf2", "T"),
    ("mut / sf3", "mut", "sf3", "T"),
    ("pr / bg (baglanti)", "pr", "bg", "T"),
    ("pr / sf (baglanti)", "pr", "sf", "T"),
    ("onPr / pr (birincil dugme)", "onPr", "pr", "T"),
    ("onSoft / soft", "onSoft", "soft", "T"),
    ("pr / soft", "pr", "soft", "T"),
    ("onNav / nav (alt gezinme)", "onNav", "nav", "T"),
    ("onMedia / h1 (hero; BuHeroCard yazisi onMedia)", "onMedia", "h1", "T"),
    ("onMedia / h2 (hero)", "onMedia", "h2", "T"),
    ("ok / bg", "ok", "bg", "T"),
    ("ok / sf", "ok", "sf", "T"),
    ("onOkSoft / okSoft", "onOkSoft", "okSoft", "T"),
    ("danger / bg", "danger", "bg", "T"),
    ("danger / sf", "danger", "sf", "T"),
    ("danger / dangerSoft", "danger", "dangerSoft", "T"),
    ("info / bg", "info", "bg", "T"),
    ("info / sf", "info", "sf", "T"),
    ("onInfoSoft / infoSoft", "onInfoSoft", "infoSoft", "T"),
    ("aqua / bg", "aqua", "bg", "T"),
    ("onAquaSoft / aquaSoft", "onAquaSoft", "aquaSoft", "T"),
    ("warn / bg", "warn", "bg", "T"),
    ("warn / sf", "warn", "sf", "T"),
    ("onWarnSoft / warnSoft", "onWarnSoft", "warnSoft", "T"),
    ("qrInk / qrPaper", "qrInk", "qrPaper", "T"),
    ("bdStrong / bg (kontrol cercevesi)", "bdStrong", "bg", "L"),
    ("bdStrong / sf (kontrol cercevesi)", "bdStrong", "sf", "L"),
    ("pr / bg (ikon, buyuk metin)", "pr", "bg", "L"),
    ("ok / okSoft (simge)", "ok", "okSoft", "L"),
    ("danger / sf (simge)", "danger", "sf", "L"),
    ("warn / warnSoft (simge)", "warn", "warnSoft", "L"),
    ("info / infoSoft (simge)", "info", "infoSoft", "L"),
    ("aqua / aquaSoft (simge)", "aqua", "aquaSoft", "L"),
    ("bd / bg (karti ayiran cizgi, bilgi)", "bd", "bg", "I"),
    ("bd / sf (karti ayiran cizgi, bilgi)", "bd", "sf", "I"),
]


def measure_contrast() -> dict:
    tk = parse_tokens()
    rows, fails = [], []
    for name, fgk, bgk, kind in PAIRS:
        row = {"pair": name, "kind": kind}
        for theme in ("light", "dark"):
            c = tk["themes"][theme]["colors"]
            r = ratio(c[fgk], c[bgk])
            need = 4.5 if kind == "T" else 3.0 if kind == "L" else 0
            row[theme] = round(r, 2)
            row[theme + "_ok"] = (r >= need) if need else None
            row[theme + "_aaa"] = r >= 7.0
            if need and r < need:
                fails.append({"pair": name, "theme": theme, "ratio": round(r, 2), "need": need})
        rows.append(row)
    # tint cifti (metin 4.5)
    for theme in ("light", "dark"):
        for i, (bg, fg) in enumerate(tk["tints"][theme]):
            r = ratio(fg, bg)
            rows.append(
                {
                    "pair": f"tint[{i}] {TINT_NAMES[i]} fg/bg",
                    "kind": "T",
                    "_theme": theme,
                    theme: round(r, 2),
                    theme + "_ok": r >= 4.5,
                    theme + "_aaa": r >= 7.0,
                }
            )
            if r < 4.5:
                fails.append({"pair": f"tint[{i}] {TINT_NAMES[i]}", "theme": theme, "ratio": round(r, 2), "need": 4.5})
    # tint satirlarini birlestir
    merged, tint_rows = [], {}
    for r in rows:
        if r["pair"].startswith("tint["):
            m = tint_rows.setdefault(r["pair"], {"pair": r["pair"], "kind": "T"})
            for k, v in r.items():
                if k not in ("pair", "kind", "_theme"):
                    m[k] = v
        else:
            merged.append(r)
    merged.extend(tint_rows.values())
    # onMedia scrim uzerinde (alfa .4 / .55 / .7), en kotu zemin: beyaz fotograf
    c = tk["themes"]["light"]["colors"]
    media = []
    for a in (0.35, 0.5, 0.6):
        under = blend(c["scrim"], (255, 255, 255), a)
        media.append({"scrim_alpha": a, "on_white_photo": round(ratio(c["onMedia"], under), 2)})
    # gri: secili cerceve (pr alfa .45) soft zeminde
    sel = blend(c["pr"], c["soft"], 0.45)
    sel_light = round(ratio(sel, c["soft"]), 2)
    total_text = [r for r in merged if r["kind"] == "T"]
    total_l = [r for r in merged if r["kind"] == "L"]

    def passed(r, th):
        return r.get(th + "_ok") is True

    summary = {
        "text_pairs": len(total_text),
        "text_pass_light": sum(passed(r, "light") for r in total_text),
        "text_pass_dark": sum(passed(r, "dark") for r in total_text),
        "ui_pairs": len(total_l),
        "ui_pass_light": sum(passed(r, "light") for r in total_l),
        "ui_pass_dark": sum(passed(r, "dark") for r in total_l),
        "aaa_text_light": sum(1 for r in total_text if r.get("light_aaa")),
        "aaa_text_dark": sum(1 for r in total_text if r.get("dark_aaa")),
        "fails": fails,
        "media_scrim": media,
        "selected_border_light": sel_light,
    }
    return {"rows": merged, "summary": summary, "tokens": tk}


# --------------------------------------------------------------------------- (b-statik) dokunma hedefi
TAPPABLE = re.compile(r"\b(IconButton|BuIconButton|InkWell|GestureDetector|BuPressable|IconButton\.(?:filled|filledTonal|outlined))\s*\(")
NUM = r"(\d+(?:\.\d+)?)"


def measure_taptarget(srcs) -> dict:
    out = []
    seen = set()
    for s in srcs:
        m = s.masked
        for mm in TAPPABLE.finditer(m):
            args, _ = call_args(m, mm.end() - 1)
            if not re.search(r"\bonTap\s*:\s*(?!null)|onPressed\s*:\s*(?!null)|onLongPress", args):
                continue
            if re.search(r"BuTouchTarget|minSize|BuSize\.touch|minimumSize|minHeight:\s*(4[4-9]|[5-9]\d)", args):
                continue
            for sb in re.finditer(r"SizedBox\s*\(([^()]*)\)", args):
                inner = sb.group(1)
                w = re.search(r"width\s*:\s*" + NUM, inner)
                h = re.search(r"height\s*:\s*" + NUM, inner)
                dims = [float(x.group(1)) for x in (w, h) if x]
                if dims and min(dims) < 44 and "Icon" in args:
                    key = (s.rel, s.line(mm.start()))
                    if key not in seen:
                        seen.add(key)
                        out.append(Finding(s, mm.start(), f"{mm.group(1)} + SizedBox {int(min(dims))}"))
                    break
        # tema/stil ile kuculme
        for pat, note in (
            (r"tapTargetSize\s*:\s*MaterialTapTargetSize\.shrinkWrap", "tapTargetSize=shrinkWrap"),
            (r"VisualDensity\.(?:compact|minimumDensity)", "VisualDensity.compact"),
            (r"minimumSize\s*:\s*(?:const\s+)?Size(?:\.fromHeight)?\(\s*" + NUM + r"\s*(?:,\s*" + NUM + r")?\s*\)", "minimumSize<44"),
            (r"constraints\s*:\s*(?:const\s+)?BoxConstraints\([^()]*?(?:minWidth|minHeight)\s*:\s*" + NUM, "constraints<44"),
        ):
            for mm in re.finditer(pat, m):
                if note in ("minimumSize<44", "constraints<44"):
                    nums = [float(x) for x in re.findall(NUM, mm.group(0)) if x]
                    if not nums or min(nums) >= 44:
                        continue
                out.append(Finding(s, mm.start(), note))
    return summarize(out)


# --------------------------------------------------------------------------- (d) renk
def measure_color(srcs) -> dict:
    direct, colors_cls = [], []
    for s in srcs:
        m = s.masked
        for mm in re.finditer(r"\bColor\(\s*0x[0-9A-Fa-f]{6,8}\s*\)|\bColor\.from(?:ARGB|RGBO)\(", s.text):
            ln = s.line(mm.start())
            # yorum satiri mi?
            if s.line_text(ln).startswith("//"):
                continue
            direct.append(Finding(s, mm.start(), "Color(0x..)"))
        for mm in re.finditer(r"\bColors\.(?!transparent\b)(\w+)", m):
            colors_cls.append(Finding(s, mm.start(), "Colors." + mm.group(1)))
    # Colors.* kirilimi
    kinds = Counter(f.note for f in colors_cls)
    return {
        "color_literal": summarize(direct),
        "colors_class": summarize(colors_cls),
        "colors_kinds": kinds.most_common(12),
    }


# --------------------------------------------------------------------------- (d) font
def measure_font(srcs) -> dict:
    below, off_scale, total, scaled_ok = [], [], 0, 0
    for s in srcs:
        for mm in re.finditer(r"\bfontSize\s*:\s*" + NUM + r"(?![\w.])", s.masked):
            v = float(mm.group(1))
            total += 1
            if v < MIN_FONT:
                below.append(Finding(s, mm.start(), f"fontSize {v:g}"))
            elif v not in BU_SCALE:
                off_scale.append(Finding(s, mm.start(), f"fontSize {v:g}"))
            else:
                scaled_ok += 1
    thin = []
    for s in srcs:
        for mm in re.finditer(r"FontWeight\.(?:w[123]00|thin|extraLight|light)\b", s.masked):
            thin.append(Finding(s, mm.start(), "ince agirlik (HIG: Regular ve ustu)"))
    vals = Counter()
    for f in off_scale + below:
        vals[f.note] += 1
    return {
        "total_literals": total,
        "below_min": summarize(below),
        "off_scale": summarize(off_scale),
        "thin_weights": summarize(thin),
        "on_scale_literals": scaled_ok,
        "off_values": vals.most_common(12),
    }


# --------------------------------------------------------------------------- (d) bosluk
INSET_CALL = re.compile(r"\bEdgeInsets(?:Directional)?\s*\.\s*(all|symmetric|only|fromSTEB|fromLTRB)\s*\(")
ALLOWED_SPACING = {0.0, 2.0, 6.0}  # BuSpace.xxs=2, BuGap h6/w6


def _spacing_viol(v: float) -> str:
    if v % 4 == 0:
        return ""
    if v in ALLOWED_SPACING:
        return "lenient"  # 4'un kati degil ama olcekte var
    return "strict"


def measure_spacing(srcs) -> dict:
    strict, lenient, total_vals, total_calls = [], [], 0, 0
    box_strict, box_total = [], 0
    for s in srcs:
        m = s.masked
        for mm in INSET_CALL.finditer(m):
            args, _ = call_args(m, mm.end() - 1)
            total_calls += 1
            for x in re.finditer(r"(?<![\w.])" + NUM + r"(?![\w.])", args):
                v = float(x.group(1))
                total_vals += 1
                k = _spacing_viol(v)
                if k == "strict":
                    strict.append(Finding(s, mm.start(), f"{mm.group(1)} {v:g}"))
                    break
                if k == "lenient":
                    lenient.append(Finding(s, mm.start(), f"{mm.group(1)} {v:g}"))
        for mm in re.finditer(r"\bSizedBox\s*\(\s*(width|height)\s*:\s*" + NUM + r"\s*(?:,\s*)?\)", m):
            box_total += 1
            v = float(mm.group(2))
            k = _spacing_viol(v)
            if k == "strict":
                box_strict.append(Finding(s, mm.start(), f"SizedBox {mm.group(1)} {v:g}"))
    return {
        "inset_calls": total_calls,
        "inset_values": total_vals,
        "inset_strict": summarize(strict),
        "inset_lenient_ok_in_scale": len(lenient),
        "spacer_total": box_total,
        "spacer_strict": summarize(box_strict),
    }


# --------------------------------------------------------------------------- (e) a11y
ICON_BTN = re.compile(r"\b(IconButton|BuIconButton|IconButton\.(?:filled|filledTonal|outlined)|FloatingActionButton(?:\.\w+)?)\s*\(")
IMG = re.compile(r"\bImage\s*\.\s*(asset|network|file|memory)\s*\(|\bImage\s*\(")
TAPPERS = re.compile(r"\b(InkWell|GestureDetector|BuPressable)\s*\(")


def measure_a11y(srcs) -> dict:
    no_tip, no_img, icon_only = [], [], []
    icon_btn_total = 0
    for s in srcs:
        m = s.masked
        for mm in ICON_BTN.finditer(m):
            args, _ = call_args(m, mm.end() - 1)
            icon_btn_total += 1
            if not re.search(r"\btooltip\s*:|semanticLabel|\blabel\s*:", args):
                no_tip.append(Finding(s, mm.start(), mm.group(1)))
        for mm in IMG.finditer(m):
            args, _ = call_args(m, mm.end() - 1)
            # Image(image: ...) sarmalayicilari dahil; excludeFromSemantics/semanticLabel yoksa suphe
            if not re.search(r"semanticLabel|excludeFromSemantics", args):
                no_img.append(Finding(s, mm.start(), "Image " + (mm.group(1) or "")))
        for mm in TAPPERS.finditer(m):
            args, _ = call_args(m, mm.end() - 1)
            if not re.search(r"\bonTap\s*:\s*(?!null)", args):
                continue
            if re.search(r"\bIcon\s*\(|BuIcons\.", args) and not re.search(r"\bText\s*\(|Semantics|semanticLabel|tooltip|label\s*:", args):
                icon_only.append(Finding(s, mm.start(), mm.group(1) + " yalniz simge"))
    return {
        "icon_buttons_total": icon_btn_total,
        "no_tooltip": summarize(no_tip),
        "image_no_semantics": summarize(no_img),
        "icon_only_tappable": summarize(icon_only),
    }


# --------------------------------------------------------------------------- (f) durumlar
# Yukleme amacli GET (yalniz POST/PUT/DELETE yapan formlar "agli ekran" sayilmaz)
NET = re.compile(r"\bapi\.(?:get|getSwr|getResponse|list|timetable|peekCache)\(|FutureBuilder|StreamBuilder|\b_?load\w*\(|\bfetch\w*\(|PagedList|ProfilePagedList")
LISTISH = re.compile(r"ListView|SliverList|GridView|SliverGrid|itemBuilder|MasonryGrid|PagedList|ProfilePagedList")
LOADING = re.compile(r"BuSkeleton|Skeleton|BuPageScaffold|LoadingView|CircularProgressIndicator|BuViewState\.loading|ProgressIndicator|_loading\b|isLoading|loading\s*:|Shimmer|BuRefresh|_busy|_submitting|_sending|_saving|_working|_pending|_checking|_verifying|busy:")
EMPTY = re.compile(r"BuEmptyState|EmptyView|BuViewState\.empty|\b[A-Z]\w*Empty\w*\s*\(|\bEmpty\w*\(|\bl\.\w*[Ee]mpty\w*|\bloc\.\w*[Ee]mpty\w*|emptyState|NoResults|\bnoResults?\b")
ERROR = re.compile(r"BuErrorState|ErrorView|BuViewState\.error|ErrorState|_error\b|errorView|ErrorBox|ApiException|\bcatch\b|\bfailed\b|\boffline\b|BuOfflineBanner|error\s*:")
MAINT = re.compile(r"maintenance|BuViewState\.maintenance|Maintenance|bakim|bakım")
SCREEN_FILE = re.compile(r"(_page|_tab|_screen|_view)\.dart$")


def measure_states(srcs) -> dict:
    rows = []
    # kullanici yuzlu ekranlar: Scaffold/Page sinifi
    for s in srcs:
        if not SCREEN_FILE.search(s.rel):
            continue
        t = s.masked
        if not re.search(r"extends\s+State(?:less|ful)Widget", t):
            continue
        net = bool(NET.search(t))
        listish = bool(LISTISH.search(t))
        has = {
            "loading": bool(LOADING.search(t)),
            "empty": bool(EMPTY.search(t)),
            "error": bool(ERROR.search(t)),
            "maint": bool(MAINT.search(t)),
        }
        rows.append({"file": s.rel, "net": net, "listish": listish, **has, "lines": len(s.starts)})
    net_rows = [r for r in rows if r["net"]]
    missing = []
    for r in net_rows:
        need = ("loading", "empty", "error") if r["listish"] else ("loading", "error")
        lacks = [k for k in need if not r[k]]
        if lacks:
            missing.append({"file": r["file"], "lacks": lacks, "lines": r["lines"]})
    # bakim: haber/menu/ana sayfa icin gerekli (scraper kaynakli)
    maint_needed = [r for r in net_rows if re.search(r"/(news|menu|home)/", r["file"]) and not r["maint"]]
    return {
        "screens": len(rows),
        "net_screens": len(net_rows),
        "missing": missing,
        "maint_missing": [r["file"] for r in maint_needed],
        "all_state_ok": len(net_rows) - len(missing),
    }


# --------------------------------------------------------------------------- (g) formlar
FIELD = re.compile(r"\b(TextField|TextFormField|RefTextField|RefPasswordField|AkadTextField|AcadTextField|SohbetyField)\s*\(")


def measure_forms(srcs) -> dict:
    fields_total, no_kbd, no_autofill, no_action = 0, [], [], []
    no_inset, scaffold_noresize, no_safe = [], [], []
    form_files = []
    for s in srcs:
        m = s.masked
        fs = list(FIELD.finditer(m))
        if not fs:
            continue
        form_files.append(s.rel)
        for mm in fs:
            args, _ = call_args(m, mm.end() - 1)
            fields_total += 1
            if "keyboardType" not in args:
                no_kbd.append(Finding(s, mm.start(), mm.group(1)))
            if "autofillHints" not in args and mm.group(1) != "SohbetyField":
                no_autofill.append(Finding(s, mm.start(), mm.group(1)))
            if "textInputAction" not in args:
                no_action.append(Finding(s, mm.start(), mm.group(1)))
        if re.search(r"resizeToAvoidBottomInset\s*:\s*false", m):
            scaffold_noresize.append(Finding(s, re.search(r"resizeToAvoidBottomInset\s*:\s*false", m).start(), "resizeToAvoidBottomInset:false"))
        if not re.search(r"viewInsets|BuPageScaffold|SingleChildScrollView|ListView|CustomScrollView|Scrollable|resizeToAvoid|ScrollView|Scaffold|BuSheet|DraggableScrollableSheet", m):
            no_inset.append(Finding(s, 0, "klavye kaydirma/inset yok"))
        if not re.search(r"SafeArea|MediaQuery\.(?:paddingOf|viewPaddingOf|of\(context\)\.padding)|viewPadding|BuPageScaffold|Scaffold|BuSheet|bottomNavigationBar|padding\.bottom|paddingOf", m):
            no_safe.append(Finding(s, 0, "SafeArea/padding yok"))
    return {
        "form_files": len(form_files),
        "fields_total": fields_total,
        "no_keyboardType": summarize(no_kbd),
        "no_autofillHints": summarize(no_autofill),
        "no_textInputAction": summarize(no_action),
        "resize_false": summarize(scaffold_noresize),
        "no_scroll_inset": summarize(no_inset),
        "no_safe_area": summarize(no_safe),
    }


# --------------------------------------------------------------------------- (h) RTL statik
def measure_rtl(srcs) -> dict:
    pats = [
        (r"\bEdgeInsets\s*\.\s*(?:fromLTRB|only)\s*\([^()]*\b(?:left|right)\s*:|\bEdgeInsets\s*\.\s*fromLTRB\s*\(", "EdgeInsets left/right"),
        (r"\bPositioned\s*\([^()]*\b(?:left|right)\s*:", "Positioned left/right"),
        (r"\bAlignment\s*\.\s*(?:centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b", "Alignment sol/sag"),
        (r"\bTextAlign\s*\.\s*(?:left|right)\b", "TextAlign.left/right"),
        (r"\bBorderRadius\s*\.\s*horizontal\s*\(|\bBorderRadius\s*\.\s*only\s*\([^()]*\b(?:topLeft|topRight|bottomLeft|bottomRight)\b", "BorderRadius sol/sag"),
        (r"\bBorder\s*\(\s*(?:left|right)\s*:|\bBorder\s*\.\s*only\s*\([^()]*\b(?:left|right)\s*:", "Border left/right"),
        (r"\bCrossAxisAlignment\.(?:start|end)\b", None),  # RTL'de dogru; sayma
    ]
    res = defaultdict(list)
    for s in srcs:
        m = s.masked
        for pat, label in pats:
            if label is None:
                continue
            for mm in re.finditer(pat, m):
                res[label].append(Finding(s, mm.start(), label))
    allf = [f for v in res.values() for f in v]
    return {"by_kind": {k: len(v) for k, v in res.items()}, "all": summarize(allf)}


# --------------------------------------------------------------------------- (i) koyu tema
def measure_dark(tokens) -> dict:
    light = tokens["themes"]["light"]
    dark = tokens["themes"]["dark"]
    intentional = {"onMedia", "scrim", "qrInk", "qrPaper"}
    fallback = []
    for k in sorted(dark["colors"]):
        if k in intentional:
            continue
        if k not in dark["explicit"] and k not in ("sf3",) or (k == "sf3" and k not in dark["explicit"]):
            fallback.append(k)
    same = [k for k, v in dark["colors"].items() if k in light["colors"] and v == light["colors"][k] and k not in intentional]
    return {"dark_uses_default": fallback, "dark_same_as_light": same}


def measure_dark_usage(srcs) -> dict:
    """Tema disi dogrudan BuTokens.light/dark kullanimi + brightness uc-lu ifadeleri."""
    direct, ternary = [], []
    for s in srcs:
        for mm in re.finditer(r"\bBuTokens\.(light|dark)\b", s.masked):
            direct.append(Finding(s, mm.start(), "BuTokens." + mm.group(1)))
        for mm in re.finditer(r"(?:isDark|dark|brightness\s*==\s*Brightness\.dark)\s*\?\s*(?:const\s+)?Color\(", s.text):
            ternary.append(Finding(s, mm.start(), "koyu? Color(..)"))
    return {"direct_tokens": summarize(direct), "brightness_ternary_color": summarize(ternary)}


# --------------------------------------------------------------------------- (j) ton
VAGUE = {"tamam": "OK/Tamam", "evet": "Evet", "hayır": "Hayir", "hayir": "Hayir", "ok": "OK", "peki": "Peki", "devam": "Devam (belirsiz)", "kapat": "Kapat", "iptal": "Iptal", "vazgeç": "Vazgec"}
TECH = re.compile(r"exception|null|stack|http\s?\d|\b5\d\d\b|\b4\d\d\b|error code|hata kodu|timeout|socket|json", re.I)
BLAME = re.compile(r"geçersiz|yanlış|hatalı giriş|başarısız oldu", re.I)


def measure_tone() -> dict:
    p = LIB / "l10n" / "app_tr.arb"
    data = json.loads(p.read_text(encoding="utf-8"))
    items = {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}
    vague_btn = []
    for k, v in items.items():
        key = k.lower()
        if re.search(r"(btn|button|action|cta|confirm|ok|yes|no|cancel|label)", key) and v.strip().lower().rstrip("!.") in VAGUE:
            vague_btn.append((k, v))
    err_keys = {k: v for k, v in items.items() if re.search(r"(error|err|fail|invalid|hata)", k, re.I)}
    tech_msgs = [(k, v) for k, v in err_keys.items() if TECH.search(v)]
    blame_msgs = [(k, v) for k, v in err_keys.items() if BLAME.search(v)]
    exclam = [(k, v) for k, v in items.items() if v.count("!") >= 2]
    caps = [(k, v) for k, v in items.items() if re.search(r"\b[A-ZÇĞİÖŞÜ]{5,}\b", v) and len(v) < 60 and not re.search(r"(KVKK|QR|BÜ|FAQ|SMS|PDF|NFC|OTP|WIFI|EMAIL)", v)]
    too_long_btn = []
    for k, v in items.items():
        if re.search(r"(btn|button|cta)", k, re.I) and len(v.split()) > 3:
            too_long_btn.append((k, v))
    # ornek: 40 hata mesaji (deterministik: her 6. anahtar)
    ek = sorted(err_keys)
    sample = [(k, err_keys[k]) for k in ek[:: max(1, len(ek) // 25)]][:25]
    return {
        "arb_keys": len(items),
        "error_like_keys": len(err_keys),
        "vague_button_labels": vague_btn,
        "tech_in_errors": tech_msgs,
        "blame_in_errors": blame_msgs,
        "multi_exclaim": exclam[:15],
        "all_caps": caps[:15],
        "long_button_labels": too_long_btn[:15],
        "error_sample": sample,
    }


def dialog_labels(srcs) -> dict:
    """Koddaki dogrudan metin etiketleri: Tamam/Evet/Hayir kullanimi (BuDialogAction/BuButton label)."""
    out = []
    for s in srcs:
        for mm in re.finditer(r"""(?:BuDialogAction|BuButton|TextButton|FilledButton|OutlinedButton)\s*\([^()]*?(?:label|text|child)\s*:\s*(?:const\s+)?(?:Text\()?\s*['"](Tamam|Evet|Hayır|Peki|OK)['"]""", s.text, re.S):
            out.append(Finding(s, mm.start(), mm.group(1)))
    return summarize(out)


# --------------------------------------------------------------------------- paket eslemesi
def package_of(rel_path: str) -> str:
    r = rel_path
    if r.startswith(("lib/core/push/", "lib/core/notify/")):
        return "P8"  # bildirim altyapisi (baska ajanlarin dosyalari: sonra)
    if r == "lib/core/app_gate.dart":
        return "P2"  # acilis kapisi (giris/sistem durumlari)
    if r.startswith(("lib/widgets/", "lib/core/", "lib/main.dart")):
        return "P1"
    f = r.split("/")
    feat = f[2] if len(f) > 2 and f[1] == "features" else ""
    name = f[-1]
    if feat == "profile" and name.startswith("settings"):
        return "P2"
    if feat in ("auth", "legal", "system"):
        return "P2"
    if feat in ("home", "discover", "search", "posts", "shell", "media_crop"):
        return "P3"
    if feat in ("news", "menu", "academic"):
        return "P4"
    if feat == "chat":
        return "P5"
    if feat in ("clubs", "events", "polls"):
        return "P6"
    if feat in ("profile", "support", "follow", "platform"):
        return "P7"
    if feat == "notifications":
        return "P8"
    return "P?"


def by_package(findings) -> dict:
    c = Counter(package_of(f.file) for f in findings)
    return dict(sorted(c.items()))


# --------------------------------------------------------------------------- calistir
def public(d):
    if isinstance(d, dict):
        return {k: public(v) for k, v in d.items() if k != "_all"}
    if isinstance(d, (list, tuple)):
        return [public(x) for x in d]
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="sonucu JSON olarak yaz")
    ap.add_argument("--only", help="virgullu: contrast,taptarget,color,font,spacing,a11y,states,forms,rtl,dark,tone")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None

    def want(k):
        return only is None or k in only

    srcs = lib_sources()
    R = {"lib_files": len(srcs), "lib_lines": sum(len(s.starts) for s in srcs)}
    pk = {}

    if want("contrast") or want("dark"):
        c = measure_contrast()
        R["contrast"] = {"rows": c["rows"], "summary": c["summary"]}
        R["dark"] = measure_dark(c["tokens"])
    if want("dark"):
        R["dark_usage"] = measure_dark_usage(srcs)
    if want("taptarget"):
        R["taptarget"] = measure_taptarget(srcs)
        pk["taptarget"] = by_package(R["taptarget"]["_all"])
    if want("color"):
        R["color"] = measure_color(srcs)
        pk["color_literal"] = by_package(R["color"]["color_literal"]["_all"])
        pk["colors_class"] = by_package(R["color"]["colors_class"]["_all"])
    if want("font"):
        R["font"] = measure_font(srcs)
        pk["font_below_min"] = by_package(R["font"]["below_min"]["_all"])
        pk["font_off_scale"] = by_package(R["font"]["off_scale"]["_all"])
    if want("spacing"):
        R["spacing"] = measure_spacing(srcs)
        pk["inset_strict"] = by_package(R["spacing"]["inset_strict"]["_all"])
        pk["spacer_strict"] = by_package(R["spacing"]["spacer_strict"]["_all"])
    if want("a11y"):
        R["a11y"] = measure_a11y(srcs)
        pk["no_tooltip"] = by_package(R["a11y"]["no_tooltip"]["_all"])
        pk["image_no_semantics"] = by_package(R["a11y"]["image_no_semantics"]["_all"])
        pk["icon_only_tappable"] = by_package(R["a11y"]["icon_only_tappable"]["_all"])
    if want("states"):
        R["states"] = measure_states(srcs)
        R["states"]["missing_by_package"] = dict(Counter(package_of(x["file"]) for x in R["states"]["missing"]))
    if want("forms"):
        R["forms"] = measure_forms(srcs)
        pk["no_keyboardType"] = by_package(R["forms"]["no_keyboardType"]["_all"])
        pk["no_autofillHints"] = by_package(R["forms"]["no_autofillHints"]["_all"])
        pk["no_textInputAction"] = by_package(R["forms"]["no_textInputAction"]["_all"])
    if want("rtl"):
        R["rtl"] = measure_rtl(srcs)
        pk["rtl"] = by_package(R["rtl"]["all"]["_all"])
    if want("tone"):
        R["tone"] = measure_tone()
        R["tone"]["code_vague_buttons"] = dialog_labels(srcs)
    R["by_package"] = pk

    if a.json:
        Path(a.json).write_text(json.dumps(public(R), ensure_ascii=True, indent=1), encoding="utf-8")
    if not a.quiet:
        report(R)


def report(R):
    p = lambda *x: print(asc(" ".join(str(i) for i in x)))
    p(f"HIG denetimi: {R['lib_files']} dosya, {R['lib_lines']} satir (lib/, tema tanimi ve uretilmis dosyalar haric)")
    if "contrast" in R:
        s = R["contrast"]["summary"]
        p("\n[a] KONTRAST (WCAG 2.x)")
        p(f"  metin cifti: {s['text_pairs']}  acik gecen {s['text_pass_light']}  koyu gecen {s['text_pass_dark']}")
        p(f"  UI/ikon cifti: {s['ui_pairs']}  acik gecen {s['ui_pass_light']}  koyu gecen {s['ui_pass_dark']}")
        p(f"  AAA(7:1) metin: acik {s['aaa_text_light']}  koyu {s['aaa_text_dark']}")
        for f in s["fails"]:
            p(f"  KALAN: {f['pair']} [{f['theme']}] {f['ratio']}:1 < {f['need']}")
        for r in R["contrast"]["rows"]:
            p(f"  {r['pair']:<42} {r['kind']}  acik={r.get('light','-')}  koyu={r.get('dark','-')}")
    if "taptarget" in R:
        t = R["taptarget"]
        p(f"\n[b-statik] 44 dp alti dokunma suphesi: {t['total']} ({t['files']} dosya)")
        for e in t["examples"]:
            p(f"  {e['file']}:{e['line']}  {e['note']}  | {e['text']}")
    if "color" in R:
        c = R["color"]
        p(f"\n[d] Color(0x..) dogrudan: {c['color_literal']['total']} ({c['color_literal']['files']} dosya)")
        p(f"    Colors.* (transparent haric): {c['colors_class']['total']}  turler: {c['colors_kinds'][:6]}")
        for f, n in c["color_literal"]["top_files"][:10]:
            p(f"    {n:4d} {f}")
    if "font" in R:
        f = R["font"]
        p(f"\n[d] fontSize literal: {f['total_literals']}  <11: {f['below_min']['total']}  token disi (>=11): {f['off_scale']['total']}")
        p(f"    sik degerler: {f['off_values'][:8]}")
    if "spacing" in R:
        s = R["spacing"]
        p(f"\n[d] EdgeInsets cagri {s['inset_calls']} deger {s['inset_values']}: 4'un kati degil (olcek disi) {s['inset_strict']['total']}; SizedBox {s['spacer_strict']['total']}/{s['spacer_total']}")
    if "a11y" in R:
        a = R["a11y"]
        p(f"\n[e] IconButton toplam {a['icon_buttons_total']}  tooltip'siz {a['no_tooltip']['total']}  etiketsiz Image {a['image_no_semantics']['total']}  yalniz-simge dokunma {a['icon_only_tappable']['total']}")
    if "states" in R:
        s = R["states"]
        p(f"\n[f] ekran dosyasi {s['screens']}  agli {s['net_screens']}  tam durumlu {s['all_state_ok']}  eksik {len(s['missing'])}  bakim eksik {len(s['maint_missing'])}")
    if "forms" in R:
        f = R["forms"]
        p(f"\n[g] form dosyasi {f['form_files']}  alan {f['fields_total']}  keyboardType'siz {f['no_keyboardType']['total']}  autofill'siz {f['no_autofillHints']['total']}  textInputAction'siz {f['no_textInputAction']['total']}  resize:false {f['resize_false']['total']}")
    if "rtl" in R:
        p(f"\n[h-statik] sabit sol/sag: {R['rtl']['all']['total']}  {R['rtl']['by_kind']}")
    if "dark" in R:
        p(f"\n[i] koyu temada varsayilana (acik) dusen alanlar: {R['dark']['dark_uses_default']}")
        if "dark_usage" in R:
            p(f"    BuTokens.light/dark dogrudan: {R['dark_usage']['direct_tokens']['total']}  koyu? Color(..): {R['dark_usage']['brightness_ternary_color']['total']}")
    if "tone" in R:
        t = R["tone"]
        p(f"\n[j] ARB anahtar {t['arb_keys']}  hata benzeri {t['error_like_keys']}  belirsiz dugme {len(t['vague_button_labels'])}  teknik hata {len(t['tech_in_errors'])}  suclayici {len(t['blame_in_errors'])}")
    if R.get("by_package"):
        p("\nPAKETE GORE:")
        for k, v in R["by_package"].items():
            p(f"  {k:<20} {v}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="ascii", errors="replace") if hasattr(sys.stdout, "reconfigure") else None
    main()
