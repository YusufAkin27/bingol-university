#!/usr/bin/env python3
"""Widget Galerisi onizlemesi icin ornek icerik: design/widget-previews/examples/tr/*.json dosyalarini
mobile/ios/BUWidgets/BuSampleData.swift icine gomer (kucultulmus JSON, Swift ham dizge). Saat sabit:
6 Kasim 2026 Cuma 10:00 (Istanbul) = BuSampleData.sampleNow.
Kullanim: python -I -X utf8 scripts/ios/gen-widget-samples.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
EX = os.path.join(ROOT, 'design', 'widget-previews', 'examples', 'tr')
OUT = os.path.join(ROOT, 'mobile', 'ios', 'BUWidgets', 'BuSampleData.swift')
SLUGS = ['menu', 'timetable', 'events', 'announcements', 'poll', 'quickaccess', 'social']


def mini(name):
    with open(os.path.join(EX, name + '.json'), 'r', encoding='utf-8') as f:
        d = json.load(f)
    s = json.dumps(d, ensure_ascii=False, separators=(',', ':'))
    assert '"#' not in s and '\\' not in s.replace('\\u', ''), name
    return s


lines = [
    '// BuSampleData.swift  --  URETILMISTIR: scripts/ios/gen-widget-samples.py (elle DUZENLEMEYIN).',
    '// Widget Galerisi / placeholder ornek icerigi = tasarimdaki ornek (examples/tr). Gercek kullanici verisi DEGIL.',
    '',
    'import Foundation',
    '',
    'enum BuSampleData {',
    '    /// 6 Kasim 2026 Cuma 10:00 +03:00',
    '    static let sampleNow: Date = Date(timeIntervalSince1970: 1793948400)',
    '',
    '    static let meta = #"""',
    mini('meta'),
    '"""#',
]
for s in SLUGS:
    lines += ['', '    static let %s = #"""' % s, mini(s), '"""#']
lines.append('}')
with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')
print('yazildi:', OUT)
