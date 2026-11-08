import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/shell/bukampus_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart' show p00Contrast;
import 'support/fake_app.dart';

/// Alt çubuk "Soft Glow Premium": ölçüler, cam malzeme, sekme geçişi, Paylaş düğmesi, Sohbet noktası, güvenli alan,
/// klavye, durum koruma, hızlı dokunuş, azaltılmış hareket, erişilebilirlik, renk sözleşmesi.
Widget _app(
  Widget nav, {
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
  bool rtl = false,
  double textScale = 1,
  bool reduceMotion = false,
  bool highContrast = false,
  Widget? body,
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
            child: Scaffold(body: body, bottomNavigationBar: nav),
          ),
        ),
      ),
      brightness: brightness,
      size: size,
    );

void main() {
  late ValueNotifier<int> badge;
  setUp(() => badge = ValueNotifier<int>(0));
  tearDown(() => badge.dispose());

  BukampusBottomNavigationBar nav({
    int index = 0,
    ValueChanged<int>? on,
    bool publish = true,
    bool glass = true,
    bool immersive = false,
    VoidCallback? onPublish,
  }) =>
      BukampusBottomNavigationBar(
        index: index,
        onChanged: on ?? (_) {},
        chatBadge: badge,
        onPublish: publish ? (onPublish ?? () {}) : null,
        glass: glass,
        immersive: immersive,
      );

  const settle = Duration(milliseconds: 400);

  group('olculer', () {
    for (final w in [320.0, 360.0, 390.0, 430.0]) {
      for (final br in Brightness.values) {
        testWidgets('${w.toInt()} dp ${br.name}: 68 dp kapsul, 16 dp yan bosluk, 58 dp dugme ortada ve ustten 8 dp tasar', (tester) async {
          final size = Size(w, 780);
          useScreen(tester, size);
          badge.value = 120;
          await tester.pumpWidget(_app(nav(index: 2), size: size, brightness: br));
          await tester.pump(settle);
          expect(tester.takeException(), isNull);
          final bar = tester.getRect(find.byKey(const ValueKey('nav-pill')));
          expect(bar.height, closeTo(68, .5));
          expect(bar.left, closeTo(16, .5));
          expect(bar.right, closeTo(w - 16, .5));
          final plus = tester.getRect(find.byKey(const ValueKey('nav-publish')));
          expect(plus.width, closeTo(58, .5));
          expect(plus.height, closeTo(58, .5));
          expect(plus.center.dx, closeTo(w / 2, .5), reason: 'barin merkezinde');
          expect(bar.top - plus.top, closeTo(8, .5), reason: 'barin ustunden 8 dp tasar');
          // Bes oge dengeli: sekme merkezleri esit aralikli, orta bosluk Paylas ile ayni eksende.
          final xs = [0, 1, 2, 4].map((i) => tester.getCenter(find.byKey(ValueKey('nav-$i'))).dx).toList();
          final step = (bar.width - 16) / 5;
          expect(xs[1] - xs[0], closeTo(step, .6));
          expect(xs[2] - xs[1], closeTo(2 * step, .6));
          expect(xs[3] - xs[2], closeTo(step, .6));
          expect(xs[0] + xs[3], closeTo(w, 1), reason: 'simetrik');
          for (final i in [0, 1, 2, 4]) {
            final s = tester.getSize(find.byKey(ValueKey('nav-$i')));
            expect(s.width >= 44 && s.height >= 48, isTrue, reason: 'dokunma hedefi $i $s');
          }
        });
      }
    }

    testWidgets('simge 28.8 dp (24 x 1,2), Paylas ici + 30 dp; ayni simge ailesi', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      for (final i in [0, 1, 2, 4]) {
        final icon = tester.widget<Icon>(find.descendant(of: find.byKey(ValueKey('nav-$i')), matching: find.byType(Icon)));
        expect(icon.size, 28.8);
        expect(icon.icon!.fontFamily, 'BuIcons');
      }
      final plusIcon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('nav-publish')), matching: find.byType(Icon)));
      expect(plusIcon.size, 30);
    });

    testWidgets('Paylas yokken 5 sekme yan yana, tasma yok (320)', (tester) async {
      const size = Size(320, 640);
      useScreen(tester, size);
      await tester.pumpWidget(_app(nav(publish: false), size: size));
      await tester.pump(settle);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('nav-publish')), findsNothing);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('nav-$i')), findsOneWidget);
      }
    });

    testWidgets('RTL 320: tasma yok, Paylas merkezde, Ana Sayfa sagda', (tester) async {
      const size = Size(320, 640);
      useScreen(tester, size);
      await tester.pumpWidget(_app(nav(), size: size, rtl: true, textScale: 1.3));
      await tester.pump(settle);
      expect(tester.takeException(), isNull);
      expect(tester.getCenter(find.byKey(const ValueKey('nav-publish'))).dx, closeTo(160, .5));
      expect(tester.getCenter(find.byKey(const ValueKey('nav-0'))).dx, greaterThan(tester.getCenter(find.byKey(const ValueKey('nav-4'))).dx));
    });
  });

  group('guvenli alan ve klavye', () {
    for (final bottom in [0.0, 24.0, 34.0]) {
      testWidgets('alt guvenli alan $bottom: kapsulun alti ekran dibinden 10 + $bottom dp yukarida', (tester) async {
        useScreen(tester, kPhoneMedium);
        tester.view.padding = FakeViewPadding(bottom: bottom);
        tester.view.viewPadding = FakeViewPadding(bottom: bottom);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(_app(nav()));
        await tester.pump(settle);
        final bar = tester.getRect(find.byKey(const ValueKey('nav-pill')));
        expect(kPhoneMedium.height - bar.bottom, closeTo(10 + bottom, .5));
      });
    }

    testWidgets('klavye acilinca cubuk gizlenir, kapaninca geri gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-pill')), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-pill')), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-pill')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('malzeme', () {
    testWidgets('cam: BackdropFilter yalniz cubuk alaninda (ClipRRect 34), opak yedekte yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      final pill = find.byKey(const ValueKey('nav-pill'));
      final bf = find.descendant(of: pill, matching: find.byType(BackdropFilter));
      expect(bf, findsOneWidget);
      expect(tester.getRect(bf), tester.getRect(pill));
      final clip = tester.widget<ClipRRect>(find.descendant(of: pill, matching: find.byType(ClipRRect)));
      expect(clip.borderRadius, BorderRadius.circular(34));
      expect(find.byType(RepaintBoundary), findsWidgets);

      await tester.pumpWidget(_app(nav(glass: false)));
      await tester.pump(settle);
      expect(find.descendant(of: pill, matching: find.byType(BackdropFilter)), findsNothing);
      await tester.pumpWidget(_app(nav(), highContrast: true));
      await tester.pump(settle);
      expect(find.descendant(of: pill, matching: find.byType(BackdropFilter)), findsNothing);
    });

    testWidgets('kenarlik 0.8 dp, belirtec renginde', (tester) async {
      useScreen(tester, kPhoneMedium);
      for (final br in Brightness.values) {
        await tester.pumpWidget(_app(nav(), brightness: br));
        await tester.pump(settle);
        final pill = find.byKey(const ValueKey('nav-pill'));
        final box = tester
            .widgetList<DecoratedBox>(find.descendant(of: pill, matching: find.byType(DecoratedBox)))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.border != null);
        final side = (box.border! as Border).top;
        final t = br == Brightness.dark ? BuTokens.dark : BuTokens.light;
        expect(side.width, .8);
        expect(side.color, t.navBorder);
      }
    });

    testWidgets('immersive (Reels): acik temada bile koyu palet', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav(immersive: true)));
      await tester.pump(settle);
      final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('nav-1')), matching: find.byType(Icon)));
      expect(icon.color, BuTokens.dark.navIconIdle);
    });
  });

  group('sekme gecisi', () {
    testWidgets('Ana Sayfa -> Kesfet -> Sohbet -> Profil -> Ana Sayfa: renk, kayan zemin, 1.05 olcek', (tester) async {
      useScreen(tester, kPhoneMedium);
      var idx = 0;
      final got = <int>[];
      await tester.pumpWidget(StatefulBuilder(
          builder: (c, set) => _app(nav(
                index: idx,
                on: (i) {
                  got.add(i);
                  set(() => idx = i);
                },
              ))));
      await tester.pump(settle);
      const t = BuTokens.light;
      Color colorOf(int i) => tester.widget<Icon>(find.descendant(of: find.byKey(ValueKey('nav-$i')), matching: find.byType(Icon))).color!;
      expect(colorOf(0), t.navAccent);
      expect(colorOf(1), t.navIconIdle);
      for (final i in [1, 2, 4, 0]) {
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final to = tester.getCenter(find.byKey(ValueKey('nav-$i'))).dx;
        expect((tester.getCenter(find.byKey(const ValueKey('nav-indicator'))).dx - to).abs(), greaterThan(0), reason: 'kayiyor ($i)');
        await tester.pump(const Duration(milliseconds: 260));
        expect(tester.getCenter(find.byKey(const ValueKey('nav-indicator'))).dx, closeTo(to, 1));
        expect(colorOf(i), t.navAccent);
        final scale = tester.widget<AnimatedScale>(find.ancestor(of: find.descendant(of: find.byKey(ValueKey('nav-$i')), matching: find.byType(Icon)), matching: find.byType(AnimatedScale)).first);
        expect(scale.scale, 1.05);
        expect(scale.curve, Curves.easeOutCubic);
        expect(scale.duration.inMilliseconds, inInclusiveRange(180, 240));
      }
      expect(got, [1, 2, 4, 0]);
    });

    testWidgets('yalniz aktif sekmede vurgu cizgisi ve kayan zemin var', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav(index: 1)));
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-indicator')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-underline')), findsOneWidget);
    });

    testWidgets('hizli art arda 10 dokunus: sirayla bildirilir, istisna yok, zemin son sekmede', (tester) async {
      useScreen(tester, kPhoneMedium);
      var idx = 0;
      final got = <int>[];
      await tester.pumpWidget(StatefulBuilder(
          builder: (c, set) => _app(nav(
                index: idx,
                on: (i) {
                  got.add(i);
                  set(() => idx = i);
                },
              ))));
      await tester.pump(settle);
      const seq = [1, 2, 4, 0, 2, 1, 4, 2, 0, 1];
      for (final i in seq) {
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(settle);
      expect(got, seq);
      expect(tester.takeException(), isNull);
      expect(tester.getCenter(find.byKey(const ValueKey('nav-indicator'))).dx, closeTo(tester.getCenter(find.byKey(const ValueKey('nav-1'))).dx, 1));
    });

    testWidgets('sekme durumu korunur: Paylas dugmesi State yeniden kurulmaz, IndexedStack kaydirmasi kalir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final ctrl = ScrollController();
      addTearDown(ctrl.dispose);
      var idx = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (c, set) => _app(
          nav(index: idx, on: (i) => set(() => idx = i)),
          body: IndexedStack(index: idx, children: [
            ListView(controller: ctrl, children: [for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('satir $i'))]),
            const Center(child: Text('kesfet')),
            const Center(child: Text('sohbet')),
            const Center(child: Text('kulupler')),
            const Center(child: Text('profil')),
          ]),
        ),
      ));
      await tester.pump(settle);
      final stateBefore = tester.state(find.byType(PremiumCreateButton));
      ctrl.jumpTo(420);
      await tester.pump();
      for (final i in [1, 2, 4, 0]) {
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await tester.pump(settle);
      }
      expect(ctrl.offset, 420);
      expect(identical(tester.state(find.byType(PremiumCreateButton)), stateBefore), isTrue);
    });

    testWidgets('azaltilmis hareket: kayan zemin aninda yerine gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      var idx = 0;
      await tester.pumpWidget(StatefulBuilder(builder: (c, set) => _app(nav(index: idx, on: (i) => set(() => idx = i)), reduceMotion: true)));
      await tester.pump(settle);
      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getCenter(find.byKey(const ValueKey('nav-indicator'))).dx, closeTo(tester.getCenter(find.byKey(const ValueKey('nav-4'))).dx, 1));
      final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('nav-4')), matching: find.byType(Icon)));
      expect(icon.color, BuTokens.light.navAccent);
    });
  });

  group('Paylas dugmesi', () {
    testWidgets('dokununca onPublish cagrilir (sekme secilmez), orta titresim; basili 0.95, birakinca 1', (tester) async {
      useScreen(tester, kPhoneMedium);
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      var published = 0;
      final selected = <int>[];
      await tester.pumpWidget(_app(nav(on: selected.add, onPublish: () => published++)));
      await tester.pump(settle);
      final plus = find.byKey(const ValueKey('nav-publish'));
      double scale() => tester.widget<AnimatedScale>(find.ancestor(of: plus, matching: find.byType(AnimatedScale)).first).scale;
      final g = await tester.startGesture(tester.getCenter(plus));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale(), .95);
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scale(), 1);
      expect(published, 1);
      expect(selected, isEmpty);
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));
    });

    testWidgets('kirmizi daire, beyaz +, onerilen golge (kirmizi %22, blur 18, spread 1, offset 0,4)', (tester) async {
      useScreen(tester, kPhoneMedium);
      for (final br in Brightness.values) {
        await tester.pumpWidget(_app(nav(), brightness: br));
        await tester.pump(settle);
        final deco = tester.widget<DecoratedBox>(find.byKey(const ValueKey('nav-publish'))).decoration as BoxDecoration;
        final t = br == Brightness.dark ? BuTokens.dark : BuTokens.light;
        expect(deco.shape, BoxShape.circle);
        expect(deco.color, t.navAccent);
        final sh = deco.boxShadow!.single;
        expect(sh.blurRadius, 18);
        expect(sh.spreadRadius, 1);
        expect(sh.offset, const Offset(0, 4));
        expect(sh.color.a, closeTo(.22, .01));
        final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('nav-publish')), matching: find.byType(Icon)));
        expect(icon.color, t.onMedia);
      }
    });
  });

  group('Sohbet noktasi', () {
    testWidgets('okunmamis sayaca bagli: 0 iken yok, > 0 iken var, yeniden 0 iken kaybolur', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-dot')), findsNothing);
      badge.value = 4;
      await tester.pump();
      await tester.pump(settle);
      expect(find.byKey(const ValueKey('nav-dot')), findsOneWidget);
      final dot = tester.widget<Container>(find.byKey(const ValueKey('nav-dot')));
      expect((dot.decoration! as BoxDecoration).color, BuTokens.light.navAccentHi);
      expect(tester.getSize(find.byKey(const ValueKey('nav-dot'))).width, lessThan(12));
      badge.value = 0;
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-dot')), findsNothing);
    });
  });

  group('erisilebilirlik', () {
    testWidgets('semantics: sekme dugmeleri, secili durum, okunmamis etiketi, Paylas dugmesi', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      badge.value = 5;
      await tester.pumpWidget(_app(nav(index: 1)));
      await tester.pump(settle);
      final sel = tester.getSemantics(find.byKey(const ValueKey('nav-1')));
      expect(sel.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(sel.flagsCollection.isButton, isTrue);
      expect(tester.getSemantics(find.byKey(const ValueKey('nav-2'))).label, 'Sohbet, 5 okunmamış');
      expect(find.bySemanticsLabel('Ana Sayfa'), findsWidgets);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, isNotEmpty);
      h.dispose();
    });

    testWidgets('etiket metni cizilmez (kullanici karari 2026-11-08); erisilebilirlik etiketi kalir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(nav()));
      await tester.pump(settle);
      for (final l in ['Ana Sayfa', 'Keşfet', 'Sohbet', 'Profil']) {
        expect(find.text(l), findsNothing, reason: l);
        expect(find.bySemanticsLabel(RegExp(l)), findsWidgets, reason: l);
      }
      handle.dispose();
    });
  });

  group('renk sozlesmesi', () {
    for (final dark in [false, true]) {
      final t = dark ? BuTokens.dark : BuTokens.light;
      test('${dark ? "koyu" : "acik"}: belirtilen onaltilik degerler', () {
        expect(t.navAccent, const Color(0xFF09090B)); // kirmizi YOK (kullanici karari 2026-11-07, WhatsApp)
        // Alt cubuk iki temada da beyaz (kullanici karari 2026-11-07): kirmizi parlama yok, hafif gri golge.
        expect(t.navBorder, const Color(0x14000000));
        // Cam yari saydam (kullanici karari 2026-11-08: alttaki renkler gorunsun); pasif renkler okunurluk icin koyulastirildi.
        expect(t.navGlass, const Color(0x8CFFFFFF));
        expect(t.navTextIdle, const Color(0xFF18181B));
        expect(t.navIconIdle, const Color(0xFF18181B));
        expect(t.navBase, const Color(0xFFFFFFFF));
        expect(t.navAccentHi, const Color(0xFF09090B));
      });
      test('${dark ? "koyu" : "acik"}: cam ustunde pasif simge >= 3, pasif yazi >= 4.5, aktif >= 3', () {
        final glass = Color.alphaBlend(t.navGlass, dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
        expect(p00Contrast(t.navIconIdle, glass), greaterThanOrEqualTo(3));
        expect(p00Contrast(t.navTextIdle, glass), greaterThanOrEqualTo(4.5));
        expect(p00Contrast(t.navAccent, glass), greaterThanOrEqualTo(3));
        expect(p00Contrast(t.onMedia, t.navAccent), greaterThanOrEqualTo(3));
      });
    }
  });

  test('kirmizi nav belirtecleri yalniz alt cubukta kullanilir (baska dosyada nav* kirmizi yok)', () {
    const allowed = {
      'lib/core/theme.dart',
      'lib/features/shell/bukampus_bottom_navigation_bar.dart',
    };
    final pattern = RegExp(r'\bnav(Accent|AccentHi|Glow|Border|Glass|IconIdle|TextIdle|Base)\b');
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final p = f.path.replaceAll(r'\', '/');
      if (allowed.contains(p)) continue;
      if (pattern.hasMatch(f.readAsStringSync())) bad.add(p);
    }
    expect(bad, isEmpty);
  });
}
