import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/icons/bu_icon_helpers.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// `bu_icons.dart` içindeki font glifi sabitleri (ad -> kod noktası).
Map<String, int> _glyphs() {
  final src = File('lib/core/icons/bu_icons.dart').readAsStringSync();
  final re = RegExp(r"static const IconData (\w+) = IconData\(0x([0-9a-f]+), fontFamily: 'BuIcons'\);");
  return {for (final m in re.allMatches(src)) m.group(1)!: int.parse(m.group(2)!, radix: 16)};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final glyphs = _glyphs();
  final map = jsonDecode(File('tools/icons/icon_map.json').readAsStringSync()) as Map<String, dynamic>;

  group('BuIcons sabitleri', () {
    test('en az 182 glif ve her kod noktası benzersiz, özel kullanım alanında', () {
      expect(glyphs.length, greaterThanOrEqualTo(182));
      expect(glyphs.values.toSet().length, glyphs.length, reason: 'kod noktaları benzersiz olmalı');
      for (final cp in glyphs.values) {
        expect(cp, inInclusiveRange(0xe000, 0xf8ff));
      }
    });

    test('yazı tipi dosyası ve pubspec kaydı var', () {
      final font = File('assets/fonts/BuIcons.ttf');
      expect(font.existsSync(), isTrue);
      expect(font.lengthSync(), greaterThan(10000));
      final pub = File('pubspec.yaml').readAsStringSync();
      expect(pub, contains('family: BuIcons'));
      expect(pub, contains('assets/fonts/BuIcons.ttf'));
      expect(pub, contains('assets/licenses/hugeicons-MIT.txt'));
      expect(File('assets/licenses/hugeicons-MIT.txt').readAsStringSync(), contains('MIT License'));
      // hugeicons paketi uygulama bağımlılığı OLMAMALI (yalnız araç hattı)
      expect(RegExp(r'^\s*hugeicons\s*:', multiLine: true).hasMatch(pub), isFalse);
    });

    test('eşleme belgesindeki 192 kaynak (167 Lucide + 25 Material) karşılık buluyor', () {
      final lucide = map['lucide'] as Map<String, dynamic>;
      final material = map['material'] as Map<String, dynamic>;
      final keep = (map['lucide_keep'] as List).cast<String>();
      expect(lucide.length, 167);
      expect(material.length, 25);
      final src = File('lib/core/icons/bu_icons.dart').readAsStringSync();
      var resolved = 0;
      for (final name in lucide.keys) {
        if (keep.contains(name)) {
          expect(src, contains('static const IconData $name = LucideIcons.$name;'), reason: 'karşılıksız $name Lucide e işaret etmeli');
        } else {
          expect(glyphs.containsKey(name), isTrue, reason: 'Lucide $name için BuIcons.$name yok');
        }
        resolved++;
      }
      for (final e in material.entries) {
        final bu = (e.value as Map<String, dynamic>)['bu'] as String;
        expect(glyphs.containsKey(bu), isTrue, reason: 'Material ${e.key} -> BuIcons.$bu yok');
        resolved++;
      }
      expect(resolved, 192);
    });

    test('dolu glifler tanımlı ve çizgi tabanlarıyla eşleşiyor', () {
      final filled = (map['filled'] as List).cast<String>();
      expect(filled.length, 13);
      for (final base in filled) {
        expect(glyphs.containsKey(base), isTrue, reason: base);
        expect(glyphs.containsKey('${base}Filled'), isTrue, reason: '${base}Filled');
        expect(glyphs[base], isNot(glyphs['${base}Filled']));
      }
    });

    test('lib/ içinde doğrudan LucideIcons.* ya da Material Icons.* kullanılmaz (tek kapı: BuIcons)', () {
      final bad = <String>[];
      final re = RegExp(r'(?<![A-Za-z0-9_])(LucideIcons|Icons)\.\w+');
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final path = f.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart') || path.contains('/core/icons/')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          final m = re.firstMatch(line);
          if (m != null) bad.add('$path:${i + 1}: ${m.group(0)}');
        }
      }
      expect(bad, isEmpty, reason: 'Yeni ikon BuIcons a eklenir (mobile/tools/icons/README.md)');
    });

    test('karşılıksız iki ikon Lucide kalır', () {
      expect(BuIcons.delete, LucideIcons.delete);
      expect(BuIcons.keyboard, LucideIcons.keyboard);
      expect(BuIcons.home.fontFamily, 'BuIcons');
      expect(BuIcons.home.matchTextDirection, isFalse);
    });
  });

  group('yön yardımcıları', () {
    testWidgets('RTL de geri/ileri ve chevron aynalanır, diğerleri aynen kalır', (tester) async {
      late BuildContext ltr, rtl;
      await tester.pumpWidget(Column(children: [
        Directionality(textDirection: TextDirection.ltr, child: Builder(builder: (c) { ltr = c; return const SizedBox(); })),
        Directionality(textDirection: TextDirection.rtl, child: Builder(builder: (c) { rtl = c; return const SizedBox(); })),
      ]));
      expect(buIconDirection(ltr, BuIcons.arrowLeft), BuIcons.arrowLeft);
      expect(buIconDirection(rtl, BuIcons.arrowLeft), BuIcons.arrowRight);
      expect(buIconDirection(rtl, BuIcons.chevronRight), BuIcons.chevronLeft);
      expect(buIconDirection(rtl, BuIcons.chevronLeft), BuIcons.chevronRight);
      expect(buIconDirection(rtl, LucideIcons.chevronRight), LucideIcons.chevronLeft);
      expect(buIconDirection(rtl, BuIcons.search), BuIcons.search);
    });
  });

  group('glif çizimi', () {
    testWidgets('her glif 24 dp de boş değil ve kutuda ortalı çizilir', (tester) async {
      final data = await rootBundle.load('assets/fonts/BuIcons.ttf');
      final loader = FontLoader('BuIcons')..addFont(Future.value(data));
      await loader.load();

      final names = glyphs.keys.toList()..sort();
      final keys = {for (final n in names) n: GlobalKey()};
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(children: [
          for (final n in names)
            RepaintBoundary(
              key: keys[n],
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  // ignore: non_const_argument_for_const_parameter
                  child: Icon(IconData(glyphs[n]!, fontFamily: 'BuIcons'), size: 24, color: const Color(0xFF000000)),
                ),
              ),
            ),
        ]),
      ));
      await tester.pump();

      final bad = <String>[];
      var minInk = 1 << 30;
      await tester.runAsync(() async {
        for (final n in names) {
          final boundary = keys[n]!.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await boundary.toImage(pixelRatio: 4);
          final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final w = img.width, h = img.height;
          var ink = 0, x0 = w, x1 = -1, y0 = h, y1 = -1;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              if (bd.getUint8((y * w + x) * 4) < 128) {
                ink++;
                if (x < x0) x0 = x;
                if (x > x1) x1 = x;
                if (y < y0) y0 = y;
                if (y > y1) y1 = y;
              }
            }
          }
          if (ink < minInk) minInk = ink;
          // 96x96 px kutuda yeterli mürekkep (24 dp x4); ortalama sapma <= 3 dp (12 px)
          if (ink < 150) {
            bad.add('$n boş/çok az ink=$ink');
            continue;
          }
          final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
          if ((cx - w / 2).abs() > 12 || (cy - h / 2).abs() > 12) bad.add('$n ortalı değil ($cx,$cy)');
          if (x0 <= 0 || y0 <= 0 || x1 >= w - 1 || y1 >= h - 1) bad.add('$n kutuya taşıyor');
        }
      });
      expect(bad, isEmpty);
      expect(minInk, greaterThan(150));
    });
  });
}
