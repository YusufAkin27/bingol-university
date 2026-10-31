#!/usr/bin/env python3
"""App Store metin uzunluk denetimi: docs/ios-store/store_{tr,en,ar}.md icindeki baslik altindaki ilk kod blogu.
Kullanim (repo kokunden): python -I -X utf8 scripts/ios/check-store-lengths.py
Sinirlar: ad 30, alt baslik 30, tanitim 170, anahtar kelime 100, aciklama 4000, yenilikler 4000.
Anahtar kelimelerde virgul dahil karakter sayilir. Cikis kodu 1 = sinir asimi."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LIMITS = [
    ('ad', 30, ('Uygulama adı', 'App name', 'اسم التطبيق')),
    ('alt baslik', 30, ('Alt başlık', 'Subtitle', 'العنوان الفرعي')),
    ('tanitim', 170, ('Tanıtım metni', 'Promotional text', 'النص الترويجي')),
    ('anahtar kelime', 100, ('Anahtar kelimeler', 'Keywords', 'الكلمات المفتاحية')),
    ('aciklama', 4000, ('Açıklama', 'Description', 'الوصف')),
    ('yenilikler', 4000, ('Yenilikler', "What's New", 'الجديد')),
]
fail = 0
for lang in ('tr', 'en', 'ar'):
    path = os.path.join(ROOT, 'docs', 'ios-store', f'store_{lang}.md')
    text = open(path, encoding='utf-8').read()
    for label, limit, names in LIMITS:
        m = None
        for n in names:
            m = re.search(r'^## ' + re.escape(n) + r'[^\n]*\n+```\n(.*?)\n```', text, re.S | re.M)
            if m:
                break
        if not m:
            print(f'[HATA] {lang}: "{label}" bolumu bulunamadi')
            fail += 1
            continue
        n_chars = len(m.group(1))
        status = 'OK  ' if n_chars <= limit else 'HATA'
        if n_chars > limit:
            fail += 1
        print(f'[{status}] {lang} {label}: {n_chars}/{limit}')
sys.exit(1 if fail else 0)
