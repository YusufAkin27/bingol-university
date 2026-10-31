#!/usr/bin/env python
"""2. FAZ: LucideIcons.<ad> ve Icons.<ad> kullanimlarini BuIcons.<anlamsal>'a cevirir.

Kullanim (repo kokunden):
  python -I -X utf8 mobile/tools/icons/migrate_usages.py --dry-run          # yalniz rapor (varsayilan)
  python -I -X utf8 mobile/tools/icons/migrate_usages.py --apply            # dosyalari yazar (2. faz)
  secenekler: --root mobile --json rapor.json

Kurallar
  * LucideIcons.<ad>  -> BuIcons.<ad>   (karsiliksiz delete/keyboard dahil: BuIcons Lucide'e isaret eder)
  * Icons.<material>  -> BuIcons.<bu>   (icon_map.json "material" tablosu)
  * Eslemesi olmayan ad DEGISMEZ ve raporda "atlanan" olarak listelenir.
  * `IconData` tipi AYNI kalir (BuIcons sabitleri IconData); 73 dosyada tip degisikligi YOKTUR.
  * Degisen dosyada BuIcons kullaniliyorsa bu_icons.dart importu eklenir; LucideIcons kalmadiysa
    lucide_icons_flutter importu silinir (bu_icons.dart kendisi hala Lucide'i iceri alir).
  * lib/core/icons/ altindaki dosyalar ve bu_widgets.dart'taki buDirIcon eslesmeleri de mekanik degisir.

Rapor siniflari
  icon_call   : Icon(LucideIcons.x ...) / Icon(buDirIcon(context, LucideIcons.x) ...)
  param       : icon: LucideIcons.x, liste/harita degeri, ucluk (IconData tasiyan baska yer)
  compare     : == / != karsilastirmasi (buDirIcon vb.)
  test_finder : find.byIcon(...)
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
LUCIDE_RE = re.compile(r"(?<![A-Za-z0-9_])LucideIcons\.(\w+)")
MATERIAL_RE = re.compile(r"(?<![A-Za-z0-9_])Icons\.(\w+)")
IMPORT_LUCIDE = re.compile(r"^import\s+'package:lucide_icons_flutter/[^']*';\s*\n", re.M)
IMPORT_BU = "import 'package:bu_kampus/core/icons/bu_icons.dart';\n"
SKIP_DIRS = {"build", ".dart_tool", "tools", ".git", "node_modules"}


def classify(line, start, end):
    before, after = line[:start], line[end:]
    if "byIcon" in before[-40:]:
        return "test_finder"
    if re.search(r"(==|!=)\s*$", before) or re.match(r"\s*(==|!=)", after):
        return "compare"
    if re.search(r"Icon\(\s*(?:buDirIcon\([^,()]*,\s*)?$", before):
        return "icon_call"
    return "param"


def collect(root):
    files = []
    for sub in ("lib", "test"):
        base = os.path.join(root, sub)
        for dp, dn, fn in os.walk(base):
            dn[:] = [d for d in dn if d not in SKIP_DIRS]
            for f in fn:
                full = os.path.join(dp, f)
                norm = full.replace("\\", "/")
                # BuIcons'un kendi dosyalari ve testi Lucide'e BILEREK baglidir; yeniden yazilirsa kendine isaret eder
                if f.endswith(".dart") and "/core/icons/" not in norm and not norm.endswith("/bu_icons_test.dart"):
                    files.append(full)
    return sorted(files)


def main():
    apply_ = "--apply" in sys.argv
    root = "mobile"
    if "--root" in sys.argv:
        root = sys.argv[sys.argv.index("--root") + 1]
    jpath = sys.argv[sys.argv.index("--json") + 1] if "--json" in sys.argv else None
    mp = json.load(open(os.path.join(HERE, "icon_map.json"), encoding="utf8"))
    lucide_ok = set(mp["lucide"])
    material = {k: v["bu"] for k, v in mp["material"].items()}

    stats = {"files_scanned": 0, "files_changed": 0, "lucide_repl": 0, "material_repl": 0}
    cls = Counter()
    cls_by_area = {"lib": Counter(), "test": Counter()}
    skipped_lucide = Counter()
    skipped_material = Counter()
    keep_uses = Counter()
    material_manual = defaultdict(list)
    icondata_files = set()
    small = []
    import_add, import_drop = [], []
    via_bu = 0
    changed_files = {"lib": 0, "test": 0}
    per_file = {}

    for path in collect(root):
        stats["files_scanned"] += 1
        text = open(path, encoding="utf8", newline="").read()
        area = "test" if os.sep + "test" + os.sep in path.replace(root, "", 1) or path.replace("\\", "/").startswith(root + "/test/") else "lib"
        if re.search(r"\bIconData\b", text):
            icondata_files.add(path)
        new_lines = []
        n_repl = 0
        has_bu_after = "BuIcons." in text
        lucide_left = False
        for ln, line in enumerate(text.split("\n")):
            def sub_l(m):
                nonlocal n_repl, lucide_left
                name = m.group(1)
                if name not in lucide_ok:
                    skipped_lucide[name] += 1
                    lucide_left = True
                    return m.group(0)
                c = classify(line, m.start(), m.end())
                cls[c] += 1
                cls_by_area[area][c] += 1
                if name in mp["lucide_keep"]:
                    keep_uses[name] += 1
                n_repl += 1
                stats["lucide_repl"] += 1
                return "BuIcons." + name

            def sub_m(m):
                nonlocal n_repl
                name = m.group(1)
                if name not in material:
                    skipped_material[name] += 1
                    return m.group(0)
                c = classify(line, m.start(), m.end())
                cls[c] += 1
                cls_by_area[area][c] += 1
                n_repl += 1
                stats["material_repl"] += 1
                if material[name].endswith("Filled") or name in ("chat_bubble_outline_rounded", "explore_outlined", "home_outlined", "people_outline_rounded"):
                    material_manual[path].append((ln + 1, name, material[name]))
                return "BuIcons." + material[name]

            l2 = LUCIDE_RE.sub(sub_l, line)
            l2 = MATERIAL_RE.sub(sub_m, l2)
            new_lines.append(l2)
            for m in re.finditer(r"Icon\([^;]*?size:\s*(\d+(?:\.\d+)?)", line):
                if float(m.group(1)) < 14 and ("LucideIcons." in line or "Icons." in line):
                    small.append((path, ln + 1, float(m.group(1))))
        if n_repl == 0:
            continue
        new_text = "\n".join(new_lines)
        # import duzenleme: widgets/bu.dart (2. fazda BuIcons'u da ihrac edecek) varsa import gerekmez
        norm = path.replace("\\", "/")
        if "bu_icons.dart" not in new_text and "BuIcons." in new_text and not norm.endswith("/core/icons/bu_icons.dart"):
            if re.search(r"import\s+'(?:[^']*/)?bu\.dart'", new_text):
                via_bu += 1
            else:
                idx = [m.end() for m in re.finditer(r"^import\s+[^\n]*\n", new_text, re.M)]
                if norm.startswith(root + "/lib/"):
                    rel = os.path.relpath(os.path.join(root, "lib", "core", "icons", "bu_icons.dart"), os.path.dirname(path)).replace("\\", "/")
                    imp = "import '%s';\n" % rel
                else:
                    imp = IMPORT_BU
                if idx:
                    new_text = new_text[:idx[-1]] + imp + new_text[idx[-1]:]
                import_add.append(path)
        if not LUCIDE_RE.search(new_text) and IMPORT_LUCIDE.search(new_text) and not path.replace("\\", "/").endswith("/core/icons/bu_icons.dart"):
            new_text = IMPORT_LUCIDE.sub("", new_text)
            import_drop.append(path)
        stats["files_changed"] += 1
        changed_files[area] += 1
        per_file[path] = n_repl
        if apply_:
            with open(path, "w", encoding="utf8", newline="") as f:
                f.write(new_text)

    # rapor
    print("MOD:", "UYGULA (--apply)" if apply_ else "KURU CALISTIRMA (dosyalar DEGISMEZ)")
    print("taranan dosya   :", stats["files_scanned"])
    print("degisecek dosya :", stats["files_changed"], "(lib %d, test %d)" % (changed_files["lib"], changed_files["test"]))
    print("degisim         : LucideIcons %d + Icons %d = %d" % (stats["lucide_repl"], stats["material_repl"], stats["lucide_repl"] + stats["material_repl"]))
    print("siniflar        :", dict(cls), " | lib:", dict(cls_by_area["lib"]), " test:", dict(cls_by_area["test"]))
    print("IconData gecen dosya (tip DEGISMEZ):", len(icondata_files))
    print("bu.dart ihraci ile gelecek (import yok):", via_bu, " | import eklenecek:", len(import_add), " lucide importu silinecek:", len(import_drop))
    print("Lucide'de kalan karsiliksiz kullanim (BuIcons uzerinden):", dict(keep_uses))
    print("ATLANAN LucideIcons (eslemede yok):", dict(skipped_lucide) or "yok")
    print("ATLANAN Icons.* (eslemede yok):", dict(skipped_material) or "yok")
    print("elle gozden gecirilecek Material (dolu/alt bar) yerler:")
    for p, items in material_manual.items():
        for ln, n, bu in items:
            print("  %s:%d  Icons.%s -> BuIcons.%s" % (p.replace("\\", "/"), ln, n, bu))
    print("14 dp altindaki ikon boyutu (Lucide/Material, ince cizgi riski):", len(small))
    for p, ln, s in small[:15]:
        print("  %s:%d size=%g" % (p.replace("\\", "/"), ln, s))
    if jpath:
        json.dump({"stats": stats, "classes": dict(cls), "skipped_lucide": dict(skipped_lucide), "skipped_material": dict(skipped_material),
                   "per_file": per_file}, open(jpath, "w", encoding="utf8"), indent=1)


if __name__ == "__main__":
    main()
