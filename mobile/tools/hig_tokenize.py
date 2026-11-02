#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HIG jeton donusturucu (kod-donusturucu / codemod). GORUNUMU DEGISTIRMEZ: eski literal degerleri esdeger jetonlara baglar.
Esleme tablosu: docs/MOBILE_HIG_AUDIT.md bolum 14 ("P1 jeton esleme tablosu").

Yaptiklari:
  font   fontSize: 13        -> fontSize: BuScale.s13       (11, 12, 13, 13.5, 17, 19, 20, 26, 28, 88)
  space  SizedBox(height:10) -> BuGap.h10                   (10, 14); optik degerler -> SizedBox(height: BuOptical.n3)
         EdgeInsets*(.., 10) -> BuSpace.s10 / BuOptical.nN  (yalniz EdgeInsets/EdgeInsetsDirectional cagrilari ici)
  rtl    EdgeInsets.fromLTRB -> EdgeInsetsDirectional.fromSTEB; EdgeInsets.only(left/right) -> Directional.only(start/end);
         Positioned(left/right) -> PositionedDirectional(start/end)
  align  (--align) Alignment.centerLeft -> AlignmentDirectional.centerStart ... (gradyan/RTL anlami degisir, gozle bakin)

Kullanim (mobile/ icinden; varsayilan KURU CALISMA, yalniz sayar):
  python -I -X utf8 tools/hig_tokenize.py lib/features/news lib/features/menu
  python -I -X utf8 tools/hig_tokenize.py --write lib/features/news
  secenekler: --only font,space,rtl  --align  --write

Sonra: `dart analyze` (RTL donusumu `EdgeInsets` tipli alanlari kirabilir: elle `EdgeInsetsDirectional`/`EdgeInsetsGeometry`
yapin), `python -I -X utf8 tools/hig_audit.py` ve ilgili testler. Atlananlar (jetonsuz tek kullanimlik degerler, 10 sp, 4'un
kati olmayan nadir degerler) betik tarafindan DEGISTIRILMEZ; denetim raporunda kalir, elle karar verilir.
Bu betik hig_audit.py'nin maskeleme/parantez yardimcilarini kullanir (yorum ve dizeler dokunulmaz).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hig_audit as ha  # noqa: E402

ROOT = ha.ROOT

FONT = {"11": "s11", "12": "s12", "13": "s13", "13.5": "s135", "17": "s17", "19": "s19", "20": "s20", "26": "s26", "28": "s28", "88": "s88"}
GAP = {"10", "14"}
SPACE = {"10": "BuSpace.s10", "14": "BuSpace.s14"}
OPTICAL = {v: f"BuOptical.n{v}" for v in ("1", "3", "5", "7", "9", "13", "15", "17", "18", "22", "25", "26")}
ALIGN = {
    "centerLeft": "centerStart",
    "centerRight": "centerEnd",
    "topLeft": "topStart",
    "topRight": "topEnd",
    "bottomLeft": "bottomStart",
    "bottomRight": "bottomEnd",
}
NUM = r"(\d+(?:\.\d+)?)"


def norm(v: str) -> str:
    return v[:-2] if v.endswith(".0") else v


def top_level(args: str, pat: str):
    """args icinde yalniz en dis duzeydeki (parantez/koseli/suslu derinligi 0) eslesmeler."""
    depth, out, i = 0, [], 0
    regex = re.compile(pat)
    while i < len(args):
        c = args[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0:
            mm = regex.match(args, i)
            if mm and (i == 0 or not (args[i - 1].isalnum() or args[i - 1] in "_.")):
                out.append(mm)
                i = mm.end()
                continue
        i += 1
    return out


def apply_edits(text: str, edits: list[tuple[int, int, str]]) -> str:
    out, last = [], 0
    for a, b, r in sorted(edits):
        if a < last:
            continue  # ic ice binen kopya: ilki kazanir
        out.append(text[last:a])
        out.append(r)
        last = b
    out.append(text[last:])
    return "".join(out)


def transform(text: str, only: set[str], align: bool) -> tuple[str, dict, set[str]]:
    m = ha.mask_source(text)
    edits: list[tuple[int, int, str]] = []
    cnt = {"font": 0, "gap": 0, "inset": 0, "rtl": 0, "align": 0}
    needs: set[str] = set()

    if "font" in only:
        for mm in re.finditer(r"\bfontSize\s*:\s*" + NUM + r"(?![\w.])", m):
            tok = FONT.get(norm(mm.group(1)))
            if tok:
                edits.append((mm.start(1), mm.end(1), f"BuScale.{tok}"))
                cnt["font"] += 1
                needs.add("typography")

    if "space" in only:
        for mm in re.finditer(r"(?:\bconst\s+)?\bSizedBox\s*\(\s*(width|height)\s*:\s*" + NUM + r"\s*,?\s*\)", m):
            v = norm(mm.group(2))
            axis = mm.group(1)
            if v in GAP:
                edits.append((mm.start(), mm.end(), f"BuGap.{axis[0]}{v}"))
                cnt["gap"] += 1
                needs.add("space")
            elif v in OPTICAL:
                edits.append((mm.start(2), mm.end(2), OPTICAL[v]))
                cnt["gap"] += 1
                needs.add("space")

    for mm in re.finditer(r"\bEdgeInsets(Directional)?\s*\.\s*(all|symmetric|only|fromSTEB|fromLTRB)\s*\(", m):
        args, close = ha.call_args(m, mm.end() - 1)
        a0 = mm.end()
        directional, ctor = bool(mm.group(1)), mm.group(2)
        if "space" in only:
            for x in re.finditer(r"(?:(?<=[(,:])|^)(\s*)" + NUM + r"(?=\s*[,)]|\s*$)", args):
                v = norm(x.group(2))
                tok = SPACE.get(v) or OPTICAL.get(v)
                if tok:
                    edits.append((a0 + x.start(2), a0 + x.end(2), tok))
                    cnt["inset"] += 1
                    needs.add("space")
        if "rtl" in only and not directional:
            if ctor == "fromLTRB":
                edits.append((mm.start(), mm.end() - 1, "EdgeInsetsDirectional.fromSTEB"))
                cnt["rtl"] += 1
            elif ctor == "only" and re.search(r"\b(left|right)\s*:", args):
                edits.append((mm.start(), mm.end() - 1, "EdgeInsetsDirectional.only"))
                for x in re.finditer(r"\b(left|right)(\s*:)", args):
                    edits.append((a0 + x.start(1), a0 + x.end(1), "start" if x.group(1) == "left" else "end"))
                cnt["rtl"] += 1

    if "rtl" in only:
        for mm in re.finditer(r"\bPositioned\s*\(", m):
            args, _ = ha.call_args(m, mm.end() - 1)
            a0 = mm.end()
            if top_level(args, r"(left|right)\s*:"):
                edits.append((mm.start(), mm.end() - 1, "PositionedDirectional"))
                for x in top_level(args, r"(left|right)(\s*:)"):
                    edits.append((a0 + x.start(1), a0 + x.end(1), "start" if x.group(1) == "left" else "end"))
                cnt["rtl"] += 1

    if align:
        for mm in re.finditer(r"\bAlignment\.(" + "|".join(ALIGN) + r")\b", m):
            edits.append((mm.start(), mm.end(), f"AlignmentDirectional.{ALIGN[mm.group(1)]}"))
            cnt["align"] += 1

    return apply_edits(text, edits), cnt, needs


def rel_import(file: Path, target: str) -> str:
    """lib/ altindaki hedefe gore goreli import yolu (hedef: lib/ icinden yol, orn. core/typography.dart)."""
    base = file.parent.relative_to(ROOT / "lib")
    depth = len(base.parts)
    return "../" * depth + target if depth else target


def ensure_imports(text: str, file: Path, needs: set[str]) -> str:
    imps = re.findall(r"^import\s+['\"]([^'\"]+)['\"]", text, re.M)

    def has(*names: str) -> bool:
        return any(i == n or i.endswith("/" + n) for i in imps for n in names)

    add = []
    if "typography" in needs and not has("typography.dart", "bu_design.dart", "bu.dart"):
        add.append(rel_import(file, "core/typography.dart"))
    if "space" in needs and not has("bu_space.dart", "bu_design.dart", "bu.dart"):
        add.append(rel_import(file, "core/theme/bu_space.dart"))
    if not add:
        return text
    lines = text.split("\n")
    last = max((i for i, l in enumerate(lines) if l.startswith("import ")), default=-1)
    ins = [f"import '{p}';" for p in add]
    lines[last + 1 : last + 1] = ins
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--only", default="font,space,rtl")
    ap.add_argument("--align", action="store_true")
    a = ap.parse_args()
    only = set(a.only.split(","))
    files: list[Path] = []
    for p in a.paths:
        pp = (Path.cwd() / p).resolve()
        files += sorted(pp.rglob("*.dart")) if pp.is_dir() else [pp]
    total = {"font": 0, "gap": 0, "inset": 0, "rtl": 0, "align": 0}
    changed = 0
    for f in files:
        r = f.relative_to(ROOT).as_posix()
        if r.startswith(ha.SKIP_PREFIXES) or r in ha.THEME_DEF_FILES or r.startswith(ha.THEME_DEF_PREFIXES):
            continue
        text = f.read_text(encoding="utf-8")
        if ha.GENERATED_HINT in text[:400]:
            continue
        new, cnt, needs = transform(text, only, a.align)
        if new == text:
            continue
        new = ensure_imports(new, f, needs)
        changed += 1
        for k, v in cnt.items():
            total[k] += v
        print(ha.asc(f"{r}: " + " ".join(f"{k}={v}" for k, v in cnt.items() if v)))
        if a.write:
            f.write_text(new, encoding="utf-8", newline="\n")
    print(f"{'YAZILDI' if a.write else 'KURU CALISMA'}: {changed} dosya, {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
