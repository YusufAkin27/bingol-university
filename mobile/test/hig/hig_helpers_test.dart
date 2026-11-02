// HIG-P1: ortak yardimcilarin ve jetonlarin testleri (dokunma alani >= 48, semantik ad, yon duyarliligi, kalin yazi,
// jeton degerleri, metin sozlugu). Gorunumun degismedigini jeton degerleriyle ve boyut olcumleriyle dogrular.
import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../redesign/p00_support.dart';

void main() {
  group('BuTouchTarget', () {
    testWidgets('44x44 gorunur kutu 48x48 hedefe buyur, cocuk boyutu ayni kalir', (tester) async {
      const key = ValueKey('inner');
      await tester.pumpWidget(p00App(const Align(
        alignment: Alignment.topLeft,
        child: BuTouchTarget(child: SizedBox(key: key, width: 44, height: 44)),
      )));
      expect(tester.getSize(find.byType(BuTouchTarget)), const Size(48, 48));
      expect(tester.getSize(find.byKey(key)), const Size(44, 44));
    });

    testWidgets('48 dp ve uzeri kutuyu buyutmez', (tester) async {
      await tester.pumpWidget(p00App(const Align(
        alignment: Alignment.topLeft,
        child: BuTouchTarget(child: SizedBox(width: 120, height: 56)),
      )));
      expect(tester.getSize(find.byType(BuTouchTarget)), const Size(120, 56));
    });

    testWidgets('axis: vertical yalniz yuksekligi buyutur (genislik degismez)', (tester) async {
      await tester.pumpWidget(p00App(const Align(
        alignment: Alignment.topLeft,
        child: BuTouchTarget(axis: Axis.vertical, child: SizedBox(width: 30, height: 34)),
      )));
      expect(tester.getSize(find.byType(BuTouchTarget)), const Size(30, 48));
    });

    testWidgets('sinirli yukseklikli ust kutuda gereginden fazla uzamaz', (tester) async {
      await tester.pumpWidget(p00App(const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 200,
          child: Row(children: [BuTouchTarget(child: SizedBox(width: 20, height: 20))]),
        ),
      )));
      expect(tester.getSize(find.byType(BuTouchTarget)), const Size(48, 48));
    });

    testWidgets('dis BuPressable hedefin tamamini yakalar (kenar boslugundan dokunma)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(p00App(Align(
        alignment: Alignment.topLeft,
        child: BuPressable(
          onTap: () => taps++,
          child: const BuTouchTarget(child: SizedBox(key: ValueKey('v'), width: 24, height: 24)),
        ),
      )));
      final r = tester.getRect(find.byType(BuTouchTarget));
      await tester.tapAt(r.topLeft + const Offset(2, 2)); // 24 dp kutunun disinda, 48 dp hedefin icinde
      expect(taps, 1);
    });
  });

  group('BuIconButton', () {
    testWidgets('tooltip semantik ad olur ve dokunma hedefi >= 48 dp (Android + etiket kilavuzu)', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(p00App(Center(child: BuIconButton(icon: BuIcons.search, tooltip: 'Ara', onTap: () {}))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Ara'), findsWidgets);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });

    testWidgets('gorsel boyut 40 dp kalir (gorunum degismez)', (tester) async {
      await tester.pumpWidget(p00App(Center(child: BuIconButton(icon: BuIcons.search, tooltip: 'Ara', onTap: () {}))));
      await tester.pump(const Duration(milliseconds: 300));
      final sizes = tester.widgetList<SizedBox>(find.descendant(of: find.byType(BuIconButton), matching: find.byType(SizedBox)));
      expect(sizes.any((s) => s.width == 40 && s.height == 40), isTrue);
      expect(sizes.any((s) => s.width == 48 && s.height == 48), isTrue);
    });
  });

  group('BuImage', () {
    test('decorative: semanticLabel yok (ekran okuyucudan gizli)', () {
      const img = BuImage.decorative(null);
      expect(img.semanticLabel, isNull);
      const labeled = BuImage(null, semanticLabel: 'Kapak');
      expect(labeled.semanticLabel, 'Kapak');
    });
  });

  group('BuInsets (yon duyarli)', () {
    test('steb/start/end/hv/h/v dogru degerleri uretir', () {
      expect(BuInsets.steb(1, 2, 3, 4), const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4));
      expect(BuInsets.start(8), const EdgeInsetsDirectional.only(start: 8));
      expect(BuInsets.end(8), const EdgeInsetsDirectional.only(end: 8));
      expect(BuInsets.hv(4, 6), const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 6));
    });

    test('LTR ve RTL cozumleme: start soldan/sagdan', () {
      final a = BuInsets.steb(20, 0, 4, 0);
      expect(a.resolve(TextDirection.ltr), const EdgeInsets.fromLTRB(20, 0, 4, 0));
      expect(a.resolve(TextDirection.rtl), const EdgeInsets.fromLTRB(4, 0, 20, 0));
    });
  });

  group('BuBold (MediaQuery.boldText)', () {
    testWidgets('Text, boldText acikken kalin yazilir; kapaliyken degismez', (tester) async {
      Future<FontWeight?> weightOf(bool bold) async {
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(boldText: bold),
          child: const Directionality(textDirection: TextDirection.ltr, child: Text('abc', style: BuType.body)),
        ));
        return tester.renderObject<RenderParagraph>(find.text('abc')).text.style?.fontWeight;
      }

      expect(await weightOf(false), FontWeight.w400);
      expect(await weightOf(true), FontWeight.bold);
    });

    testWidgets('BuBold.weight/style: ayar acikken 700 altini bold yapar, 700 ustunu korur', (tester) async {
      late BuildContext ctx;
      Future<void> pump(bool bold) => tester.pumpWidget(MediaQuery(
            data: MediaQueryData(boldText: bold),
            child: Builder(builder: (c) {
              ctx = c;
              return const SizedBox();
            }),
          ));
      await pump(false);
      expect(BuBold.of(ctx), isFalse);
      expect(BuBold.weight(ctx, FontWeight.w400), FontWeight.w400);
      expect(identical(BuBold.style(ctx, BuType.body), BuType.body), isTrue);
      await pump(true);
      expect(BuBold.of(ctx), isTrue);
      expect(BuBold.weight(ctx, FontWeight.w400), FontWeight.bold);
      expect(BuBold.weight(ctx, FontWeight.w800), FontWeight.w800);
      expect(BuBold.style(ctx, BuType.body).fontWeight, FontWeight.bold);
    });
  });

  group('Jetonlar (gecis degerleri = eski literal degerler: gorunum degismez)', () {
    test('BuSpace 10 ve 14, BuGap karsiliklari', () {
      expect(BuSpace.s10, 10);
      expect(BuSpace.s14, 14);
      expect(BuGap.h10.height, 10);
      expect(BuGap.h14.height, 14);
      expect(BuGap.w10.width, 10);
      expect(BuGap.w14.width, 14);
    });

    test('BuOptical eski optik degerlerle ayni', () {
      expect(
        [
          BuOptical.n1, BuOptical.n3, BuOptical.n5, BuOptical.n7, BuOptical.n9, BuOptical.n13, //
          BuOptical.n15, BuOptical.n17, BuOptical.n18, BuOptical.n22, BuOptical.n25, BuOptical.n26,
        ],
        [1, 3, 5, 7, 9, 13, 15, 17, 18, 22, 25, 26],
      );
    });

    test('BuScale gecis jetonlari eski fontSize degerleriyle ayni ve 11 sp tabaninin altina inmez', () {
      final v = [
        BuScale.s11, BuScale.s12, BuScale.s13, BuScale.s135, BuScale.s17, //
        BuScale.s19, BuScale.s20, BuScale.s26, BuScale.s28, BuScale.s88,
      ];
      expect(v, [11, 12, 13, 13.5, 17, 19, 20, 26, 28, 88]);
      expect(v.every((e) => e >= 11), isTrue);
    });

    test('BuSize.fieldMin = 48 (metin alani alt siniri)', () {
      expect(BuSize.fieldMin, 48);
      expect(BuSize.fieldMin, BuSize.touch);
    });

    test('avatar paleti: 6 degisken, eski degerler korunur', () {
      expect(BuAvatarPalette.variants.length, 6);
      expect(BuAvatarPalette.variants.first.top, const Color(0xFFF2A094));
      expect(BuAvatarPalette.variants.last.bottom, const Color(0xFF1F4E96));
      expect(BuAvatarPalette.silhouette, const Color(0xFFFFFFFF));
    });

    test('ders renkleri ve golge jetonu eski degerlerle ayni', () {
      expect(BuCourseColors.red, const Color(0xFFBC3A2D));
      expect(BuCourseColors.neutral, const Color(0xFF5C5A56));
      expect(BuColors.inkShadow25, const Color(0x40171E33));
    });
  });

  group('Metin sozlugu', () {
    Map<String, dynamic> arb(String lang) =>
        json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

    test('ortak (common*) Turkce metinlerde "Tekrar dene" ve tek basina "Tamam" yok; yeniden deneme tek bicim', () {
      final tr = arb('tr');
      expect(tr['commonRetry'], 'Yeniden dene');
      expect(tr['commonRetryShort'], 'Yeniden dene');
      for (final e in tr.entries.where((e) => e.key.startsWith('common') && e.value is String)) {
        final s = e.value as String;
        expect(s.contains('Tekrar dene'), isFalse, reason: e.key);
        expect(s.trim() == 'Tamam', isFalse, reason: e.key);
      }
    });
  });
}
