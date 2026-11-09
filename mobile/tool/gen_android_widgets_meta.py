#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Android widget meta: AppWidgetProviderInfo xml, picker onizlemeleri, logo, metinler, alici siniflari, manifest parcasi.

Calistirma: python -I -X utf8 mobile/tool/gen_android_widgets_meta.py
Onizleme kaynagi: design/widget-previews/<slug>/android-<boyut>-<light|dark>.png (tasarimla ayni). Bu surec
res/drawable-nodpi (acik) ve res/drawable-night-nodpi (koyu) altina 2x WebP yazar.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RES = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res')
KT = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'kotlin', 'edu', 'bingol', 'bu_kampus', 'widgets')
PREV = os.path.join(ROOT, 'design', 'widget-previews')

SLUGS = [
    # slug, Sinif oneki, tr, en, ar etiket, tr, en, ar aciklama
    ('menu', 'Menu', ('Yemek Menüsü', "Today's Menu", 'قائمة الطعام'),
     ('Günün yemek menüsü', "Today's cafeteria menu", 'قائمة طعام اليوم')),
    ('timetable', 'Timetable', ('Ders Programım', 'My Timetable', 'جدول دروسي'),
     ('Sıradaki ders ve bugünün programı', 'Your next class and today\'s schedule', 'حصتك القادمة وجدول اليوم')),
    ('events', 'Events', ('Yaklaşan Etkinlikler', 'Upcoming Events', 'الفعاليات القادمة'),
     ('Kulüplerin yaklaşan etkinlikleri', 'Upcoming club events', 'فعاليات الأندية القادمة')),
    ('announcements', 'Announcements', ('Kampüs Duyuruları', 'Campus Announcements', 'إعلانات الحرم الجامعي'),
     ('Son kampüs duyuruları', 'Latest campus announcements', 'آخر إعلانات الحرم الجامعي')),
    ('poll', 'Poll', ('Günün Anketi', 'Poll of the Day', 'استطلاع اليوم'),
     ('Günün anketi ve sonuçlar', 'Today\'s poll and results', 'استطلاع اليوم ونتائجه')),
    ('quickaccess', 'QuickAccess', ('Hızlı Erişim', 'Quick Access', 'وصول سريع'),
     ('Sık kullanılan ekranlara kısayollar', 'Shortcuts to frequent screens', 'اختصارات للشاشات المتكررة')),
    ('social', 'Social', ('Sosyal Özet', 'Social Summary', 'ملخص اجتماعي'),
     ('Mesaj, bildirim ve beğeni sayıları', 'Message, notification and like counts', 'أعداد الرسائل والإشعارات والإعجابات')),
    ('exams', 'Exams', ('Yaklaşan Sınavlar', 'Upcoming Exams', 'الامتحانات القادمة'),
     ('Yaklaşan sınavların ve tarihleri', 'Your upcoming exams and dates', 'امتحاناتك القادمة وتواريخها')),
    ('academic', 'Academic', ('Akademik Takvim', 'Academic Calendar', 'التقويم الأكاديمي'),
     ('Yaklaşan önemli akademik tarihler', 'Upcoming key academic dates', 'المواعيد الأكاديمية المهمة القادمة')),
]
# Yeni widget'lar duyuru ile ayni cizimi paylasir; secici onizlemesi su an duyuru gorselidir (kendi tasarimi gelince
# design/widget-previews/<slug>/android-*.png konur ve buradan kalkar).
PREVIEW_ALIAS = {'exams': 'announcements', 'academic': 'announcements'}
SIZES = [('2x2', 2, 2, '2x2', ''), ('4x2', 4, 2, '4x2', '4x2'), ('4x4', 4, 4, '4x4', '4x4')]
MIN = {2: 110, 4: 250}


def write(path, text, root=RES):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text if text.endswith('\n') else text + '\n')


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('&', '&amp;').replace('<', '&lt;')


def logos():
    for src, dst in (('logo_light.png', 'drawable-nodpi'), ('logo_dark.png', 'drawable-night-nodpi')):
        im = Image.open(os.path.join(ROOT, 'mobile', 'assets', 'branding', src)).convert('RGBA')
        im = im.resize((120, int(round(120 * im.height / im.width))), Image.LANCZOS)
        out = os.path.join(RES, dst)
        os.makedirs(out, exist_ok=True)
        im.save(os.path.join(out, 'bw_logo.png'), optimize=True)


def previews():
    total = 0
    for slug, *_ in SLUGS:
        for size, *_ in SIZES:
            for theme, dst in (('light', 'drawable-nodpi'), ('dark', 'drawable-night-nodpi')):
                src = os.path.join(PREV, PREVIEW_ALIAS.get(slug, slug), 'android-%s-%s.png' % (size, theme))
                im = Image.open(src).convert('RGBA')
                w, h = im.size
                im = im.resize((w * 2 // 3, h * 2 // 3), Image.LANCZOS)  # 3x -> 2x
                out = os.path.join(RES, dst)
                os.makedirs(out, exist_ok=True)
                fn = os.path.join(out, 'bw_prev_%s_%s.webp' % (slug, size.replace('x', 'x')))
                im.save(fn, 'WEBP', quality=88, method=6)
                total += os.path.getsize(fn)
    print('onizleme toplam KB:', total // 1024)


def infos():
    for slug, cls, labels, descs in SLUGS:
        for size, cw, ch, suffix, _ in SIZES:
            minw, minh = MIN[cw], MIN[ch]
            write('xml/bw_%s_%s_info.xml' % (slug, size), '''<?xml version="1.0" encoding="utf-8"?>
<!-- Uretilmis: mobile/tool/gen_android_widgets_meta.py -->
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="%ddp"
    android:minHeight="%ddp"
    android:targetCellWidth="%d"
    android:targetCellHeight="%d"
    android:minResizeWidth="110dp"
    android:minResizeHeight="110dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/bw_loading"
    android:previewImage="@drawable/bw_prev_%s_%s"
    android:description="@string/bw_desc_%s"
    android:widgetCategory="home_screen" />''' % (minw, minh, cw, ch, slug, size, slug))


def strings():
    for lang, folder in ((0, 'values'), (1, 'values-en'), (2, 'values-ar')):
        lines = ['<?xml version="1.0" encoding="utf-8"?>', '<!-- Uretilmis: mobile/tool/gen_android_widgets_meta.py. Widget secici etiketleri/aciklamalari; icerik metinleri snapshot ile gelir. -->', '<resources>']
        for slug, cls, labels, descs in SLUGS:
            lines.append('    <string name="bw_label_%s">%s</string>' % (slug, esc(labels[lang])))
            lines.append('    <string name="bw_desc_%s">%s</string>' % (slug, esc(descs[lang])))
        so = [('Giriş yap', "BÜ Kampüs'ü aç"), ('Sign in', 'Open BÜ Kampüs'), ('تسجيل الدخول', 'افتح BÜ Kampüs')][lang]
        lines.append('    <string name="bw_signed_out_title">%s</string>' % esc(so[0]))
        lines.append('    <string name="bw_signed_out_sub">%s</string>' % esc(so[1]))
        lines.append('</resources>')
        write('%s/widget_strings.xml' % folder, '\n'.join(lines))


def receivers():
    lines = ['package edu.bingol.bu_kampus.widgets', '',
             '// Uretilmis: mobile/tool/gen_android_widgets_meta.py. Her slug icin 3 saglayici (2x2 / 4x2 / 4x4);',
             '// sozlesme adi (<Slug>WidgetReceiver) 2x2 saglayicidir. Hepsi ayni cizim koduyla calisir (BuWidgetReceiver).', '']
    for slug, cls, labels, descs in SLUGS:
        for size, cw, ch, _, suffix in SIZES:
            name = '%sWidget%sReceiver' % (cls, suffix)
            lines.append('class %s : BuWidgetReceiver(WidgetSlug.%s, SizeClass.%s)' % (name, slug.upper(), {'2x2':'SMALL','4x2':'MEDIUM','4x4':'LARGE'}[size]))
    lines += ['', '/** Slug -> tum saglayici siniflari (guncelleme hepsine gider). */', 'object WidgetProviders {',
              '    val bySlug: Map<WidgetSlug, List<Class<*>>> = mapOf(']
    for slug, cls, labels, descs in SLUGS:
        names = ', '.join('%sWidget%sReceiver::class.java' % (cls, sfx) for _, _, _, _, sfx in SIZES)
        lines.append('        WidgetSlug.%s to listOf(%s),' % (slug.upper(), names))
    lines += ['    )', '}']
    write('WidgetReceivers.kt', '\n'.join(lines), root=KT)
    man = ['        <!-- Ana ekran widget\'lari (uretilmis: mobile/tool/gen_android_widgets_meta.py): 9 widget x 3 boyut. -->']
    for slug, cls, labels, descs in SLUGS:
        for size, cw, ch, _, suffix in SIZES:
            name = '%sWidget%sReceiver' % (cls, suffix)
            man.append('''        <receiver android:name=".widgets.%s" android:exported="false" android:label="@string/bw_label_%s">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/bw_%s_%s_info"/>
        </receiver>''' % (name, slug, slug, size))
    write('widget_manifest_fragment.txt', '\n'.join(man), root=os.path.join(ROOT, 'mobile', 'tool'))


if __name__ == '__main__':
    logos()
    if '--no-previews' not in sys.argv:
        previews()
    infos()
    strings()
    receivers()
    print('meta done')
