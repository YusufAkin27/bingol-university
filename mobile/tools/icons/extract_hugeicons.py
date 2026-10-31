#!/usr/bin/env python
"""hugeicons 4.4.0 paketinden yalniz kullanilan ikonlarin SVG verisini cikarir.

Kullanim:
  python -I -X utf8 mobile/tools/icons/extract_hugeicons.py            # pub.dev'den indirir
  python -I -X utf8 mobile/tools/icons/extract_hugeicons.py --src PATH # yerel stroke_rounded.dart

Girdi : icon_map.json (parse_doc_map.py ciktisi)
Cikti : hugeicons_subset.json  (committe tutulur; MIT, bkz. mobile/assets/licenses/hugeicons-MIT.txt)
        -> {"version":"4.4.0","icons":{"Home01":[["path",{"d":..,"strokeLinecap":..}],..]}}

Uygulama bu paketi KULLANMAZ; yalniz bu arac hatti okur.
"""
import io
import json
import os
import re
import sys
import tarfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = "4.4.0"
URL = "https://pub.dev/api/archives/hugeicons-%s.tar.gz" % VERSION
KEEP_ATTRS = {"d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "stroke", "strokeWidth",
              "strokeLinecap", "strokeLinejoin", "strokeMiterlimit", "strokeDasharray", "fill",
              "fillRule", "clipRule", "opacity", "transform"}


def load_source(src):
    if src:
        return open(src, encoding="utf8").read(), None
    data = urllib.request.urlopen(URL, timeout=120).read()
    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    dart = tf.extractfile("lib/styles/stroke_rounded.dart").read().decode("utf8")
    lic = tf.extractfile("LICENSE").read().decode("utf8")
    return dart, lic


def parse_icon(dart, name):
    m = re.search(r"static const List<List<dynamic>> strokeRounded%s = \[(.*?)\n  \];" % re.escape(name), dart, re.S)
    if not m:
        raise SystemExit("ikon bulunamadi: " + name)
    els = []
    for em in re.finditer(r"\[\s*'(\w+)',\s*\{(.*?)\}\s*\]", m.group(1), re.S):
        attrs = {}
        for k, v in re.findall(r"'(\w+)':\s*'([^']*)'", em.group(2)):
            if k in KEEP_ATTRS:
                attrs[k] = v
        els.append([em.group(1), attrs])
    return els


def main():
    src = None
    if "--src" in sys.argv:
        src = sys.argv[sys.argv.index("--src") + 1]
    mp = json.load(open(os.path.join(HERE, "icon_map.json"), encoding="utf8"))
    need = sorted(set(mp["glyphs"].values()))
    dart, lic = load_source(src)
    icons = {n: parse_icon(dart, n) for n in need}
    out = {"version": VERSION, "license": "MIT (c) Hugeicons; bkz. mobile/assets/licenses/hugeicons-MIT.txt", "icons": icons}
    with open(os.path.join(HERE, "hugeicons_subset.json"), "w", encoding="utf8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
        f.write("\n")
    if lic:
        print("LICENSE:\n" + lic)
    tags = {}
    for els in icons.values():
        for t, a in els:
            tags[t] = tags.get(t, 0) + 1
    print("icons=%d tags=%s" % (len(icons), tags))


if __name__ == "__main__":
    main()
