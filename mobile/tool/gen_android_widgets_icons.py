#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Android ana ekran widget'lari: Lucide SVG -> vector drawable (res/drawable/ic_w_*.xml).

Calistirma: python -I -X utf8 mobile/tool/gen_android_widgets_icons.py
Kaynak: design/widget-previews/*/stitch/html icindeki Lucide cizimleri (vurus 1.5, round). Ikon rengi XML'de
ImageView tint ile verilir (bu_widget_* renkleri), bu yuzden cizim beyaz.
"""
import math
import os
import re

OUT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res', 'drawable')

ICONS = {
    'vote': '<path d="m9 12 2 2 4-4"/><path d="M5 7c0-1.1.9-2 2-2h10a2 2 0 0 1 2 2v12H5V7Z"/><path d="M22 19H2"/>',
    'utensils': '<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
    'calendar-clock': '<path d="M21 7.5V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3.5M16 2v4M8 2v4M3 10h5"/><circle cx="16" cy="16" r="6"/><path d="M16 14v2l1 1"/>',
    'ticket': '<path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M13 5v2M13 17v2M13 11v2"/>',
    'users': '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
    'message-circle': '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
    'qr-code': '<rect x="3" y="3" width="5" height="5" rx="1"/><rect x="16" y="3" width="5" height="5" rx="1"/><rect x="3" y="16" width="5" height="5" rx="1"/><path d="M21 16h-3a2 2 0 0 0-2 2v3M21 21v.01M12 7v3a2 2 0 0 1-2 2H7M3 12h.01M12 3h.01M12 16v.01M16 12h1M21 12v.01M12 21v-1"/>',
    'newspaper': '<path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/><path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z"/>',
    'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'bell': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    'heart': '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>',
    'lock': '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'chevron-right': '<path d="m9 18 6-6-6-6"/>',
    'message-square': '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2Z"/>',
    'circle-check': '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    'calendar': '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    'clock': '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    'map-pin': '<path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
    'megaphone': '<path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>',
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    'moon': '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    'flame': '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.4-.5-2-1-3-1.1-2.1-.2-4 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.2.4-2.4 1-3 0 1.4 1 2.5 2.5 2.5Z"/>',
}


def f(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return s if s else '0'


def attrs(s):
    return dict(re.findall(r'([a-z-]+)="([^"]*)"', s))


def shape_to_path(tag, a):
    if tag == 'path':
        return a['d']
    if tag == 'circle':
        cx, cy, r = float(a['cx']), float(a['cy']), float(a['r'])
        return 'M%s,%s a%s,%s 0 1,0 %s,0 a%s,%s 0 1,0 %s,0' % (f(cx - r), f(cy), f(r), f(r), f(2 * r), f(r), f(r), f(-2 * r))
    if tag == 'rect':
        x, y, w, h = (float(a[k]) for k in ('x', 'y', 'width', 'height'))
        r = float(a.get('rx', 0))
        if r == 0:
            return 'M%s,%s h%s v%s h%s z' % (f(x), f(y), f(w), f(h), f(-w))
        return ('M%s,%s h%s a%s,%s 0 0 1 %s,%s v%s a%s,%s 0 0 1 %s,%s h%s a%s,%s 0 0 1 %s,%s v%s a%s,%s 0 0 1 %s,%s z' % (
            f(x + r), f(y), f(w - 2 * r), f(r), f(r), f(r), f(r), f(h - 2 * r), f(r), f(r), f(-r), f(r),
            f(-(w - 2 * r)), f(r), f(r), f(-r), f(-r), f(-(h - 2 * r)), f(r), f(r), f(r), f(-r)))
    raise ValueError(tag)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, inner in ICONS.items():
        paths = [shape_to_path(m.group(1), attrs(m.group(2))) for m in re.finditer(r'<(path|circle|rect)\b([^>]*)/>', inner)]
        mirror = 'true' if name == 'chevron-right' else 'false'
        lines = ['<?xml version="1.0" encoding="utf-8"?>',
                 '<!-- Lucide: %s (uretilmis: mobile/tool/gen_android_widgets_icons.py). Renk ImageView tint ile verilir. -->' % name,
                 '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
                 '    android:width="24dp"', '    android:height="24dp"',
                 '    android:viewportWidth="24"', '    android:viewportHeight="24"',
                 '    android:autoMirrored="%s">' % mirror]
        for p in paths:
            lines += ['    <path', '        android:pathData="%s"' % p, '        android:strokeColor="#FFFFFFFF"',
                      '        android:strokeWidth="1.5"', '        android:strokeLineCap="round"',
                      '        android:strokeLineJoin="round"/>']
        lines.append('</vector>')
        fn = os.path.join(OUT, 'ic_w_%s.xml' % name.replace('-', '_'))
        with open(fn, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('\n'.join(lines) + '\n')
    print('icons:', len(ICONS))


if __name__ == '__main__':
    main()
