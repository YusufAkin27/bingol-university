import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/widgets/bu_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart' show p00Contrast;
import 'support/fake_app.dart';

/// Alt çubuk "Liquid Glass" malzemesi: cam/opak yedek, kapsül kayışı, sürükleme, erişilebilirlik, karşıtlık sözleşmesi.
Widget _app(
  Widget nav, {
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
  bool rtl = false,
  double textScale = 1,
  bool reduceMotion = false,
  bool highContrast = false,
}) =>
    buildApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
            highContrast: highContrast,
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(bottomNavigationBar: nav),
          ),
        ),
      ),
      brightness: brightness,
      size: size,
    );

void main() {
  late ValueNotifier<int> badge;
  setUp(() => badge = ValueNotifier<int>(3));
  tearDown(() => badge.dispose());

  FloatingNav nav({int index = 0, ValueChanged<int>? on, bool publish = true, bool glass = true, bool immersive = false}) => FloatingNav(
        index: index,
        onChanged: on ?? (_) {},
        chatBadge: badge,
        onPublish: publish ? () {} : null,
        glass: glass,
        immersive: immersive,
      );

  group('malzeme', () {
    testWidgets('cam: BackdropFilter + kapsul var; opak yedekte ikisi de yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(BackdropFilter)), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-indicator')), findsOneWidget);

      for (final fallback in <String, Widget>{
        'glass:false': _app(nav(glass: false)),
        'animasyonlari azalt': _app(nav(), reduceMotion: true),
        'yuksek karsitlik': _app(nav(), highContrast: true),
      }.entries) {
        await tester.pumpWidget(fallback.value);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.descendant(of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(BackdropFilter)), findsNothing,
            reason: '${fallback.key}: bulaniklik yok');
        expect(find.byKey(const ValueKey('nav-indicator')), findsNothing, reason: '${fallback.key}: kapsul yok');
        expect(tester.widget<BuGlassBar>(find.byKey(const ValueKey('nav-pill'))).opaque, isTrue);
      }
    });

    testWidgets('bulaniklik sigma 18-28 araliginda ve yalniz cubuk alanina sinirli (ClipRRect)', (tester) async {
      expect(BuGlass.blurSigma, inInclusiveRange(18, 28));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      final bar = tester.getRect(find.byKey(const ValueKey('nav-pill')));
      final blur = tester.getRect(find.descendant(of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(BackdropFilter)));
      expect(blur, bar);
      expect(find.descendant(of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(ClipRRect)), findsOneWidget);
      expect(bar.height, closeTo(FloatingNav.height, .5));
    });

    testWidgets('immersive (Reels): koyu cam, acik temada bile', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav(immersive: true)));
      await tester.pump(const Duration(milliseconds: 400));
      final bar = tester.widget<BuGlassBar>(find.byKey(const ValueKey('nav-pill')));
      expect(bar.dark, isTrue);
      expect(bar.opaque, isFalse);
    });
  });

  group('kapsul hareketi', () {
    testWidgets('secili sekmeye oturur; dokununca yay egrisiyle kayar (anlik degil), sonra tam yerine gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      var idx = 0;
      await tester.pumpWidget(StatefulBuilder(builder: (c, set) => _app(nav(index: idx, on: (i) => set(() => idx = i)))));
      await tester.pump(const Duration(milliseconds: 400));
      final cap = find.byKey(const ValueKey('nav-indicator'));
      expect(tester.getCenter(cap).dx, closeTo(tester.getCenter(find.byKey(const ValueKey('nav-0'))).dx, 1.5));
      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final mid = tester.getCenter(cap).dx;
      final from = tester.getCenter(find.byKey(const ValueKey('nav-0'))).dx;
      final to = tester.getCenter(find.byKey(const ValueKey('nav-4'))).dx;
      expect(mid, greaterThan(from + 4), reason: 'kayiyor');
      expect(mid, lessThan(to), reason: 'henuz varmadi');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(cap).dx, closeTo(to, 1.5));
    });

    testWidgets('basili tutunca kapsul esner (yatay ~1.14, dikey ~1.08), birakinca doner', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(const Duration(milliseconds: 400));
      final cap = find.byKey(const ValueKey('nav-indicator'));
      final base = tester.getSize(cap);
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('nav-0'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(cap), base, reason: 'yerleşim boyutu değişmez; esneme Transform ile');
      final m = tester.widget<Transform>(find.ancestor(of: cap, matching: find.byType(Transform)).first).transform;
      expect(m.storage[0], closeTo(1.14, .02));
      expect(m.storage[5], closeTo(1.08, .02));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final m2 = tester.widget<Transform>(find.ancestor(of: cap, matching: find.byType(Transform)).first).transform;
      expect(m2.storage[0], closeTo(1, .01));
    });

    testWidgets('"+" uzerine basmak kapsulu esnetmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(const Duration(milliseconds: 400));
      final cap = find.byKey(const ValueKey('nav-indicator'));
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('nav-publish'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final m = tester.widget<Transform>(find.ancestor(of: cap, matching: find.byType(Transform)).first).transform;
      expect(m.storage[0], closeTo(1, .01));
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    for (final rtl in [false, true]) {
      testWidgets('surukle: kapsul parmagi izler, birakinca en yakin sekmeyi secer (${rtl ? "rtl" : "ltr"})', (tester) async {
        useScreen(tester, kPhoneMedium);
        final got = <int>[];
        await tester.pumpWidget(_app(nav(on: got.add), rtl: rtl));
        await tester.pump(const Duration(milliseconds: 400));
        final cap = find.byKey(const ValueKey('nav-indicator'));
        final start = tester.getCenter(find.byKey(const ValueKey('nav-0')));
        final target = tester.getCenter(find.byKey(const ValueKey('nav-4')));
        final g = await tester.startGesture(start);
        final steps = 12;
        for (var i = 1; i <= steps; i++) {
          await g.moveBy(Offset((target.dx - start.dx) / steps, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Sürüklerken kapsül hedef sekmenin üstünde (anlık izleme) ve seçim henüz yapılmadı.
        expect(tester.getCenter(cap).dx, closeTo(target.dx, 6));
        expect(got, isEmpty);
        await g.up();
        await tester.pump(const Duration(milliseconds: 50));
        expect(got, [4]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('yetersiz surukleme sekmeyi degistirmez (ayni sekmeye doner)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final got = <int>[];
      await tester.pumpWidget(_app(nav(on: got.add)));
      await tester.pump(const Duration(milliseconds: 400));
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('nav-0'))));
      await g.moveBy(const Offset(26, 0)); // kaydırma eşiğini aşar ama hâlâ Ana Sayfa'ya en yakın
      await tester.pump(const Duration(milliseconds: 16));
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(got.where((i) => i != 0), isEmpty);
    });
  });

  group('yerlesim ve erisilebilirlik', () {
    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final br in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} dp ${br.name} ${rtl ? "ar/rtl" : "tr"} yazi 1.3: tasma yok, kapsul secili hucrede', (tester) async {
            useScreen(tester, size);
            await tester.pumpWidget(_app(nav(index: 2), size: size, brightness: br, rtl: rtl, textScale: 1.3));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            final cap = tester.getCenter(find.byKey(const ValueKey('nav-indicator')));
            final cell = tester.getCenter(find.byKey(const ValueKey('nav-2')));
            expect((cap.dx - cell.dx).abs(), lessThan(1.5));
            final bar = tester.getRect(find.byKey(const ValueKey('nav-pill')));
            expect(bar.left, greaterThanOrEqualTo(0));
            expect(bar.right, lessThanOrEqualTo(size.width));
            // Kapsül çubuğun içinde.
            final capRect = tester.getRect(find.byKey(const ValueKey('nav-indicator')));
            expect(capRect.top, greaterThanOrEqualTo(bar.top));
            expect(capRect.bottom, lessThanOrEqualTo(bar.bottom));
          });
        }
      }
    }

    testWidgets('Paylas dugmesi >= 48 dp, semantics dugme, beyaz/siyah zemin cam ustunde de pr/onPr', (tester) async {
      final h = tester.ensureSemantics();
      for (final br in Brightness.values) {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(_app(nav(), brightness: br));
        await tester.pump(const Duration(milliseconds: 400));
        final size = tester.getSize(find.byKey(const ValueKey('nav-publish')));
        expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$size');
        final deco = tester.widget<DecoratedBox>(find.byKey(const ValueKey('nav-publish'))).decoration as BoxDecoration;
        final t = br == Brightness.dark ? BuTokens.dark : BuTokens.light;
        expect(deco.color, t.pr);
        final tip = tester.widget<Tooltip>(find.ancestor(of: find.byKey(const ValueKey('nav-publish')), matching: find.byType(Tooltip)));
        expect(tip.message, isNotEmpty);
        final sem = tester.widget<Semantics>(find.ancestor(of: find.byType(Tooltip), matching: find.byType(Semantics)).first);
        expect(sem.properties.button, isTrue);
        expect(sem.properties.label, tip.message);
        expect(p00Contrast(t.onPr, t.pr), greaterThanOrEqualTo(7));
      }
      h.dispose();
    });

    testWidgets('semantics: sekme dugmeleri, secili durum, dokunma hedefi >= 44x48; kapsul semantiksiz', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav(index: 1)));
      await tester.pump(const Duration(milliseconds: 400));
      final sel = tester.getSemantics(find.byKey(const ValueKey('nav-1')));
      expect(sel.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(sel.flagsCollection.isButton, isTrue);
      for (final i in [0, 1, 2, 4]) {
        final s = tester.getSize(find.byKey(ValueKey('nav-$i')));
        expect(s.width >= 44 && s.height >= 48, isTrue, reason: 'sekme $i $s');
      }
      expect(find.bySemanticsLabel('Ana Sayfa'), findsWidgets);
      h.dispose();
    });
  });

  group('karsitlik sozlesmesi (WCAG): cam arkasi ne olursa olsun', () {
    // Bulanıklaştırılmış arka plan en kötü durumda siyah, orta gri ya da beyazdır; dolgu üstüne biner.
    const backs = {'siyah': Color(0xFF000000), 'gri': Color(0xFF808080), 'beyaz': Color(0xFFFFFFFF)};
    for (final dark in [false, true]) {
      final t = dark ? BuTokens.dark : BuTokens.light;
      for (final b in backs.entries) {
        for (final bottom in [false, true]) {
          test('${dark ? "koyu" : "acik"} / arka ${b.key} / ${bottom ? "alt" : "ust"} kenar: aktif >= 4.5, pasif >= 3', () {
            Color glass;
            if (dark) {
              glass = Color.alphaBlend(t.bg.withValues(alpha: BuGlass.darkBaseAlpha), b.value);
              glass = Color.alphaBlend(t.onMedia.withValues(alpha: bottom ? BuGlass.darkTintBottom : BuGlass.darkTintTop), glass);
            } else {
              glass = Color.alphaBlend(t.onMedia.withValues(alpha: bottom ? BuGlass.lightTintBottom : BuGlass.lightTintTop), b.value);
            }
            final active = t.ink;
            final passive = Color.alphaBlend(t.ink.withValues(alpha: dark ? .78 : .64), glass);
            expect(p00Contrast(active, glass), greaterThanOrEqualTo(4.5), reason: 'aktif simge');
            expect(p00Contrast(passive, glass), greaterThanOrEqualTo(3), reason: 'pasif simge');
          });
        }
      }
    }
  });
}
