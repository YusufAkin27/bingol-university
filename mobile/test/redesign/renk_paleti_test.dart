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
          'campusClub': (t.onCampusClubSoft, t.campusClubSoft),
          'ink/bg': (t.ink, t.bg),
          'ink/sf': (t.ink, t.sf),
          'ink/sf2': (t.ink, t.sf2),
          'ink/sf3': (t.ink, t.sf3),
          'mut/bg': (t.mut, t.bg),
          'mut/sf': (t.mut, t.sf),
          'mut/sf2': (t.mut, t.sf2),
          'mut/sf3': (t.mut, t.sf3),
          'onPr/prPressed': (t.onPr, t.prPressed),
          'onSoft/soft': (t.onSoft, t.soft),
          'prPressed/bg': (t.prPressed, t.bg),
          'prPressed/sf': (t.prPressed, t.sf),
          'prPressed/sf2': (t.prPressed, t.sf2),
          'prPressed/sf3': (t.prPressed, t.sf3),
          'ok/sf': (t.ok, t.sf),
          'ok/bg': (t.ok, t.bg),
          'onOkSoft/okSoft': (t.onOkSoft, t.okSoft),
          'danger/sf': (t.danger, t.sf),
          'danger/bg': (t.danger, t.bg),
          'danger/sf3': (t.danger, t.sf3),
          'warn/sf': (t.warn, t.sf),
          'warn/bg': (t.warn, t.bg),
          'onWarnSoft/warnSoft': (t.onWarnSoft, t.warnSoft),
          'info/sf': (t.info, t.sf),
          'info/bg': (t.info, t.bg),
          'onInfoSoft/infoSoft': (t.onInfoSoft, t.infoSoft),
          'aqua/sf': (t.aqua, t.sf),
          'aqua/bg': (t.aqua, t.bg),
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

  group('aileler (PREMIUM MONOCHROME)', () {
    double sat(Color c) => HSLColor.fromColor(c).saturation;
    double hue(Color c) => HSLColor.fromColor(c).hue;

    test('Premium Black degerleri brief ile birebir', () {
      final t = BuTokens.dark;
      expect(t.bg.toARGB32(), 0xFF09090B);
      expect(t.sf.toARGB32(), 0xFF141416);
      expect(t.sf2.toARGB32(), 0xFF1C1C1F);
      expect(t.sf3.toARGB32(), 0xFF252528);
      expect(t.ink.toARGB32(), 0xFFFAFAFA);
      expect(t.mut.toARGB32(), 0xFFA1A1AA);
      expect(t.mutSoft.toARGB32(), 0xFF71717A);
      expect(t.bd.toARGB32(), 0xFF303034);
      expect(t.bdSubtle.toARGB32(), 0xFF242427);
      expect(t.pr.toARGB32(), 0xFFFAFAFA); // birincil dugme beyaz
      expect(t.onPr.toARGB32(), 0xFF09090B); // yazi siyah
    });

    test('Premium White degerleri brief ile birebir', () {
      final t = BuTokens.light;
      expect(t.bg.toARGB32(), 0xFFFFFFFF);
      expect(t.sf.toARGB32(), 0xFFFAFAFA);
      expect(t.sf2.toARGB32(), 0xFFF4F4F5);
      expect(t.ink.toARGB32(), 0xFF09090B);
      expect(t.mut.toARGB32(), 0xFF52525B);
      expect(t.bd.toARGB32(), 0xFFE4E4E7);
      expect(t.pr.toARGB32(), 0xFF09090B); // birincil dugme siyah
      expect(t.onPr.toARGB32(), 0xFFFFFFFF); // yazi beyaz
    });

    test('marka kirmizisi arayuzde yok: pr/prText/soft/onSoft/yuzeyler/tintler notr (doygunluk dusuk)', () {
      for (final e in themes.entries) {
        final t = e.value;
        final neutral = <String, Color>{
          'pr': t.pr, 'onPr': t.onPr, 'prText': t.prText, 'soft': t.soft, 'onSoft': t.onSoft, 'bg': t.bg, 'sf': t.sf,
          'sf2': t.sf2, 'sf3': t.sf3, 'ink': t.ink, 'mut': t.mut, 'mutSoft': t.mutSoft, 'bd': t.bd, 'bdSubtle': t.bdSubtle,
          'bdStrong': t.bdStrong, 'nav': t.nav, 'aqua': t.aqua, 'aquaSoft': t.aquaSoft, 'onAquaSoft': t.onAquaSoft,
          'h1': t.h1, 'h2': t.h2,
        };
        neutral.forEach((k, c) => expect(sat(c), lessThan(.12), reason: '${e.key} $k notr olmali'));
        for (var i = 0; i < t.tints.length; i++) {
          expect(sat(t.tints[i].bg), lessThan(.12), reason: '${e.key} tint $i bg');
          expect(sat(t.tints[i].fg), lessThan(.12), reason: '${e.key} tint $i fg');
        }
      }
    });

    test('kalan renkler yalniz anlamsal: danger/heart kirmizi, ok yesil, warn amber, info mavi', () {
      bool red(Color c) => hue(c) <= 12 || hue(c) >= 345;
      for (final t in themes.values) {
        expect(red(t.danger), isTrue);
        expect(red(t.heart), isTrue);
        expect(red(t.dangerSoft), isTrue);
        expect(hue(t.ok), inInclusiveRange(120, 165));
        expect(hue(t.warn), inInclusiveRange(25, 50));
        expect(hue(t.info), inInclusiveRange(205, 225));
        expect(t.danger, isNot(t.pr));
      }
    });

    test('yuzey ladder: bg < sf < sf2 < sf3 (koyu), saf siyah degil; acikta sf/sf2 beyazdan ince ayrisir', () {
      final d = BuTokens.dark;
      expect(d.bg.computeLuminance(), lessThan(d.sf.computeLuminance()));
      expect(d.sf.computeLuminance(), lessThan(d.sf2.computeLuminance()));
      expect(d.sf2.computeLuminance(), lessThan(d.sf3.computeLuminance()));
      expect(d.bg, isNot(const Color(0xFF000000)));
      final l = BuTokens.light;
      expect(l.bg.computeLuminance(), greaterThan(l.sf.computeLuminance()));
      expect(l.sf.computeLuminance(), greaterThan(l.sf2.computeLuminance()));
    });

    test('iki tema bagimsiz: acik tema koyunun yalniz tersi degil (yuzeyler/ayrac/danger/ok farkli, siyah yalniz pr)', () {
      final l = BuTokens.light, d = BuTokens.dark;
      // Acik temada buyuk siyah alan yok: hero/yuzey belirteclerinden hicbiri (h1 haric, yalniz splash/yer tutucu) siyah degil.
      for (final c in [l.bg, l.sf, l.sf2, l.sf3, l.soft, l.nav]) {
        expect(c.computeLuminance(), greaterThan(.85));
      }
      expect(l.pr.computeLuminance(), lessThan(.02)); // siyah yalniz birincil dugme/secili durum
      expect(l.bdSubtle, isNot(d.bdSubtle));
      expect(l.danger, isNot(d.danger));
      expect(l.ok, isNot(d.ok));
    });

    test('tints nötr 6 adet, indeksler gecerli (BuTintId)', () {
      for (final t in themes.values) {
        expect(t.tints.length, 6);
        expect(t.tint(BuTintId.slate), t.tints[BuTintId.slate]);
        expect(t.tint(7), t.tints[1]);
      }
    });

    test('hero gradyani yok (iki ucun parlakligi esit)', () {
      for (final t in themes.values) {
        expect(t.h1, t.h2);
      }
    });

    test('lerp/copyWith yeni alanlari tasir', () {
      final m = BuTokens.light.lerp(BuTokens.dark, 1);
      expect(m.info, BuTokens.dark.info);
      expect(m.heart, BuTokens.dark.heart);
      expect(m.dangerSoft, BuTokens.dark.dangerSoft);
      expect(BuTokens.light.copyWith(info: Colors.green).info, Colors.green);
      expect(BuTokens.light.copyWith(heart: Colors.pink).heart, Colors.pink);
      expect(BuTokens.light.copyWith().onAquaSoft, BuTokens.light.onAquaSoft);
    });
  });
  group('koda sihirli renk sizmaz (lib/ taramasi)', () {
    // Renk literali yalnizca bu dosyalarda serbest: belirtec kaynagi, ders renkleri,
    // sabit golge ve bos baslangic degeri.
    const colorLiteralAllow = {
      'lib/core/theme.dart',
      'lib/features/academic/academic_models.dart',
      // Google marka kurallari: zorunlu sabit renkler (resmi G logosu/dugme renkleri; ayri sinif, yorumlu).
      'lib/features/auth/widgets/oauth_buttons.dart',
    };
    // Colors.white/black hicbir dosyada serbest degil.
    const colorsConstAllow = <String>{};

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
