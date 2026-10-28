"""i18n dosyalari arasinda cift anahtar bulur (basename sirasi ilk dosyayi kazandirir, digeri golgelenir).

Kullanim: python -I -X utf8 scripts/i18n-dupkeys.py [backend/src/main/resources/i18n]
Cift varsa cikis kodu 1. Ayni kontrol I18nMessagesIntegrityTest.noDuplicateKeysAcrossFiles icinde de var.
"""
import collections
import glob
import os
import re
import sys

d = sys.argv[1] if len(sys.argv) > 1 else 'backend/src/main/resources/i18n'
by = collections.defaultdict(lambda: collections.defaultdict(list))
for f in sorted(glob.glob(os.path.join(d, '*.properties'))):
    name = os.path.basename(f)[:-len('.properties')]
    m = re.match(r'^(.*?)(_en|_ar)?$', name)
    base, suf = m.group(1), m.group(2) or ''
    with open(f, encoding='utf-8') as fh:
        for line in fh:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            by[suf][k.strip()].append((base, v.strip()))

total = 0
for suf in sorted(by):
    for k, lst in sorted(by[suf].items()):
        if len(lst) > 1:
            total += 1
            print('[%s] %s' % (suf or 'tr', k))
            for base, v in lst:
                print('    %s = %s' % (base, v[:80]))
print('CIFT ANAHTAR:', total)
sys.exit(1 if total else 0)
