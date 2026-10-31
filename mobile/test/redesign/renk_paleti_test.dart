import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// RENK-1: tek, küçük palet (marka + mavi/su mavisi/yeşil/amber + nötr). Bu dosya paletin sözleşmesidir:
/// tüm metin/zemin çiftleri WCAG AA, aileler tutarlı, koda sihirli renk sızmaz. Belge: docs/design/RENK_ENVANTERI.md.
void main() {
  final themes = <String, BuTokens>{'acik': BuTokens.light, 'koyu': BuTokens.dark};

  group('kontrast (WCAG AA) - tum belirtec ciftleri', () {
    for (final e in themes.entries) {
      final t = e.value;
      test('${e.key}: metin ciftleri >= 4.5', () {
        // (yazi, zemin): her zemin ailesi icin gercekte kullanilan yazi renkleri.
        final pairs = <String, (Color, Color)>{
          'ink/bg': (t.ink, t.bg),
          'ink/sf': (t.ink, t.sf),
          'ink/sf2': (t.ink, t.sf2),
          'ink/sf3': (t.ink, t.sf3),
          'mut/bg': (t.mut, t.bg),
          'mut/sf': (t.mut, t.sf),
          'mut/sf2': (t.mut, t.sf2),
          'mut/sf3': (t.mut, t.sf3),
          'onPr/pr': (t.onPr, t.pr),
          'onSoft/soft': (t.onSoft, t.soft),
          'pr/bg': (t.pr, t.bg),
          'pr/sf': (t.pr, t.sf),
          'pr/sf2': (t.pr, t.sf2),
          'pr/sf3': (t.pr, t.sf3),
          'ok/sf': (t.ok, t.sf),
          'ok/bg': (t.ok, t.bg),
          'ok/okSoft': (t.ok, t.okSoft),
          'onOkSoft/okSoft': (t.onOkSoft, t.okSoft),
          'danger/sf': (t.danger, t.sf),
          'danger/bg': (t.danger, t.bg),
          'danger/sf3': (t.danger, t.sf3),
          'danger/dangerSoft': (t.danger, t.dangerSoft),
          'warn/sf': (t.warn, t.sf),
          'warn/bg': (t.warn, t.bg),
          'warn/warnSoft': (t.warn, t.warnSoft),
          'onWarnSoft/warnSoft': (t.onWarnSoft, t.warnSoft),
          'info/sf': (t.info, t.sf),
          'info/bg': (t.info, t.bg),
          'info/infoSoft': (t.info, t.infoSoft),
          'onInfoSoft/infoSoft': (t.onInfoSoft, t.infoSoft),
          'aqua/sf': (t.aqua, t.sf),
          'aqua/bg': (t.aqua, t.bg),
          'aqua/aquaSoft': (t.aqua, t.aquaSoft),
          'onAquaSoft/aquaSoft': (t.onAquaSoft, t.aquaSoft),
          'onNav/nav': (t.onNav, t.nav),
          'onMedia/h1 (hero)': (t.onMedia, t.h1),
          'onMedia/h2 (hero)': (t.onMedia, t.h2),
        };
        pairs.forEach((k, v) => expect(p00Contrast(v.$1, v.$2), greaterThanOrEqualTo(4.5), reason: '${e.key} $k'));
      });

      test('${e.key}: kategori (tint) ciftleri >= 4.5, 6 adet, hepsi farkli', () {
        expect(t.tints.length, 6);
        for (var i = 0; i < t.tints.length; i++) {
          expect(p00Contrast(t.tints[i].fg, t.tints[i].bg), greaterThanOrEqualTo(4.5), reason: 'tint $i');
          // Zemin kartin ustunde de okunur kalmali (yumusak zemin, sf uzerine yerlesir).
          expect(p00Contrast(t.tints[i].fg, t.sf), greaterThanOrEqualTo(4.5), reason: 'tint $i fg / sf');
        }
        expect({for (final x in t.tints) x.bg.toARGB32()}.length, 6);
      });

      test('${e.key}: metin olmayan ogeler (halka, cerceve, anahtar izi) >= 3', () {
        for (final c in {'mut': t.mut, 'pr': t.pr, 'info': t.info, 'aqua': t.aqua, 'ok': t.ok, 'danger': t.danger}.entries) {
          expect(p00Contrast(c.value, t.sf), greaterThanOrEqualTo(3), reason: '${e.key} ${c.key}/sf');
        }
      });

      test('${e.key}: kontrol cercevesi (giris alani, secilmemis halka) bdStrong >= 3 tum yuzeylerde (A6-02)', () {
        for (final z in {'bg': t.bg, 'sf': t.sf, 'sf2': t.sf2, 'sf3': t.sf3}.entries) {
          expect(p00Contrast(t.bdStrong, z.value), greaterThanOrEqualTo(3), reason: '${e.key} bdStrong/${z.key}');
        }
      });

      test('${e.key}: secili cip stili tek: soft zemin + onSoft yazi >= 4.5, cerceve gorunur', () {
        expect(p00Contrast(t.onSoft, t.soft), greaterThanOrEqualTo(4.5));
        final border = Color.alphaBlend(t.selectedBorder, t.sf);
        expect(p00Contrast(border, t.sf), greaterThan(1.3));
      });

      test('${e.key}: ders renkleri (akademik) tinti uzerinde >= 4.5', () {
        for (final k in courseColorKeys) {
          final base = courseColor(k);
          final dark = e.key == 'koyu';
          final bg = Color.alphaBlend(base.withValues(alpha: dark ? .22 : .11), t.sf);
          final fg = dark ? Color.lerp(base, t.onMedia, .5)! : base;
          expect(p00Contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '${e.key} ders rengi $k');
        }
      });
    }
  });

  group('aileler', () {
    test('tints indeksleri anlamli ailelere baglidir (BuTintId)', () {
      for (final t in themes.values) {
        expect(t.tints[BuTintId.brand].bg, t.soft);
        expect(t.tints[BuTintId.brand].fg, t.onSoft);
        expect(t.tints[BuTintId.blue].bg, t.infoSoft);
        expect(t.tints[BuTintId.blue].fg, t.onInfoSoft);
        expect(t.tints[BuTintId.green].bg, t.okSoft);
        expect(t.tints[BuTintId.green].fg, t.onOkSoft);
        expect(t.tints[BuTintId.amber].bg, t.warnSoft);
        expect(t.tints[BuTintId.amber].fg, t.onWarnSoft);
        expect(t.tints[BuTintId.aqua].bg, t.aquaSoft);
        expect(t.tints[BuTintId.aqua].fg, t.onAquaSoft);
      }
    });

    double hue(Color c) => HSLColor.fromColor(c).hue;
    double sat(Color c) => HSLColor.fromColor(c).saturation;

    test('mor/pembe/turkuaz-yesil karisimi yok: tum renklerin tonu izinli araliklarda', () {
      // Kirmizi/turuncu [0,45] ve [330,360], amber/sari [30,50], yesil [130,165], su mavisi [185,200], mavi [205,225].
      bool ok(double h) => (h <= 50) || (h >= 340) || (h >= 130 && h <= 165) || (h >= 183 && h <= 232);
      for (final e in themes.entries) {
        final t = e.value;
        final named = <String, Color>{
          'pr': t.pr, 'soft': t.soft, 'onSoft': t.onSoft, 'danger': t.danger, 'dangerSoft': t.dangerSoft,
          'ok': t.ok, 'okSoft': t.okSoft, 'onOkSoft': t.onOkSoft, 'warn': t.warn, 'warnSoft': t.warnSoft,
          'info': t.info, 'infoSoft': t.infoSoft, 'onInfoSoft': t.onInfoSoft,
          'aqua': t.aqua, 'aquaSoft': t.aquaSoft, 'onAquaSoft': t.onAquaSoft,
        };
        named.forEach((k, c) {
          if (sat(c) < .08) return; // notr
          expect(ok(hue(c)), isTrue, reason: '${e.key} $k ton ${hue(c).toStringAsFixed(0)} izinli ailelerde degil');
        });
        for (var i = 0; i < t.tints.length; i++) {
          for (final c in [t.tints[i].bg, t.tints[i].fg]) {
            if (sat(c) < .08) continue;
            expect(ok(hue(c)), isTrue, reason: '${e.key} tint $i ton ${hue(c).toStringAsFixed(0)}');
          }
        }
      }
    });

    test('danger marka kirmizisindan ayirt edilir (ton fark >= 10 derece)', () {
      for (final e in themes.entries) {
        final t = e.value;
        double d = (HSLColor.fromColor(t.pr).hue - HSLColor.fromColor(t.danger).hue).abs();
        if (d > 180) d = 360 - d;
        expect(d, greaterThanOrEqualTo(10), reason: e.key);
      }
    });

    test('yuzeyler notr ve doygunluk dusuk (bg/sf/sf2/bd), koyu tema saf siyah degil', () {
      for (final t in themes.values) {
        for (final c in [t.bg, t.sf, t.sf2, t.sf3, t.bd]) {
          expect(sat(c), lessThan(.3)); // HSL doygunlugu: acik sicak notrler ~.2-.25 cikar, kromatik degil
        }
      }
      expect(BuTokens.dark.bg.computeLuminance(), greaterThan(0.005));
    });

    test('hero gradyani cok hafif (iki ucun parlakligi neredeyse esit)', () {
      for (final t in themes.values) {
        expect((t.h1.computeLuminance() - t.h2.computeLuminance()).abs(), lessThan(.04));
      }
    });

    test('lerp/copyWith yeni alanlari tasir', () {
      final m = BuTokens.light.lerp(BuTokens.dark, 1);
      expect(m.info, BuTokens.dark.info);
      expect(m.aquaSoft, BuTokens.dark.aquaSoft);
      expect(m.dangerSoft, BuTokens.dark.dangerSoft);
      expect(BuTokens.light.copyWith(info: Colors.green).info, Colors.green);
      expect(BuTokens.light.copyWith().onAquaSoft, BuTokens.light.onAquaSoft);
    });
  });

  group('koda sihirli renk sizmaz (lib/ taramasi)', () {
    // Renk literali yalnizca bu dosyalarda serbest: belirtec kaynagi, baglamsiz painter paleti, ders renkleri,
    // sabit golge ve bos baslangic degeri.
    const colorLiteralAllow = {
      'lib/core/theme.dart',
      'lib/widgets/bu_default_avatar.dart',
      'lib/features/academic/academic_models.dart',
      'lib/features/chat/sohbety_widgets.dart',
      'lib/features/chat/media_preview_page.dart',
    };
    // Colors.white/black yalniz baglamsiz painter'da (avatar parlamasi).
    const colorsConstAllow = {'lib/widgets/bu_default_avatar.dart'};

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('Color(0x..) yalniz izinli dosyalarda', () {
      final bad = <String>[];
      for (final f in files) {
        final p = f.path.replaceAll('\\', '/');
        if (colorLiteralAllow.contains(p)) continue;
        final src = f.readAsStringSync();
        if (RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)').hasMatch(src)) bad.add(p);
      }
      expect(bad, isEmpty, reason: 'Color(0x..) yerine context.bu belirtecleri kullanin: $bad');
    });

    test('Colors.white/black/red/... yok (transparent haric)', () {
      final bad = <String>[];
      final re = RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)[a-zA-Z]+');
      for (final f in files) {
        final p = f.path.replaceAll('\\', '/');
        if (colorsConstAllow.contains(p)) continue;
        final src = f.readAsStringSync();
        final m = re.allMatches(src).map((x) => x.group(0)).toSet();
        if (m.isNotEmpty) bad.add('$p $m');
      }
      expect(bad, isEmpty, reason: '$bad');
    });

    test('tema aciklama/koyu yuzeyleri: saf siyah/beyaz arkaplan token yok', () {
      expect(BuTokens.dark.bg, isNot(const Color(0xFF000000)));
      expect(BuTokens.dark.sf, isNot(const Color(0xFF000000)));
    });
  });
}
