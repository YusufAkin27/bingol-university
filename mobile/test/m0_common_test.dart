import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// M0 (tur 2): ortak parcalar - haptics, BuPressable basili opakligi, BuHero yaricap gecisi, BuChipRow kaydirma/solma.
Widget host(Widget child, {bool reduce = false, TextDirection dir = TextDirection.ltr, Size? size}) => MaterialApp(
      theme: BuTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: Directionality(textDirection: dir, child: c!),
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('BuHaptics', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
        return null;
      });
    });
    tearDown(() {
      BuHaptics.enabled = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('selection/light/medium platform kanalina gider', () async {
      BuHaptics.selection();
      BuHaptics.light();
      BuHaptics.medium();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact']);
    });

    test('buHaptic(none) sessiz, enabled=false sessiz', () async {
      buHaptic(BuHaptic.none);
      BuHaptics.enabled = false;
      BuHaptics.medium();
      buHaptic(BuHaptic.light);
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    });

    test('islemci olmasa da hata firlatmaz', () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      expect(BuHaptics.selection, returnsNormally);
    });
  });

  group('BuPressable', () {
    double opacityOf(WidgetTester t) => t.widget<AnimatedOpacity>(find.descendant(of: find.byType(BuPressable), matching: find.byType(AnimatedOpacity))).opacity;
    double scaleOf(WidgetTester t) => t.widget<AnimatedScale>(find.descendant(of: find.byType(BuPressable), matching: find.byType(AnimatedScale))).scale;

    testWidgets('basilinca olcek .97 + opaklik .92, birakinca geri; ara karede gecis', (t) async {
      await t.pumpWidget(host(const BuPressable(child: SizedBox(width: 100, height: 60))));
      expect(opacityOf(t), 1);
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(opacityOf(t), closeTo(.92, 1e-9));
      expect(scaleOf(t), closeTo(.97, 1e-9));
      await t.pump(const Duration(milliseconds: 60));
      final mid = t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
      expect(mid.duration, const Duration(milliseconds: 100));
      await g.up();
      await t.pump();
      expect(opacityOf(t), 1);
      expect(scaleOf(t), 1);
      await t.pumpAndSettle();
    });

    testWidgets('animasyonlari azalt: olcek ve opaklik uygulanmaz', (t) async {
      await t.pumpWidget(host(const BuPressable(child: SizedBox(width: 100, height: 60)), reduce: true));
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(opacityOf(t), 1);
      expect(scaleOf(t), 1);
      await g.up();
    });

    testWidgets('kaydirma esigi asilinca geri doner', (t) async {
      await t.pumpWidget(host(const BuPressable(child: SizedBox(width: 200, height: 60))));
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      await g.moveBy(const Offset(40, 0));
      await t.pump();
      expect(opacityOf(t), 1);
      await g.up();
    });

    testWidgets('onTap + semantik dugme + pressedOpacity ozellestirilebilir', (t) async {
      var n = 0;
      await t.pumpWidget(host(BuPressable(pressedOpacity: .8, onTap: () => n++, semanticLabel: 'Ac', child: const SizedBox(width: 100, height: 60))));
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(opacityOf(t), closeTo(.8, 1e-9));
      await g.up();
      expect(n, 1);
      expect(find.bySemanticsLabel('Ac'), findsOneWidget);
      await t.pumpAndSettle();
    });
  });

  group('BuHero', () {
    test('tagOf benzersiz bicim', () => expect(BuHero.tagOf('news', 12), 'bu-hero-news-12'));

    Widget app({bool reduce = false}) => MaterialApp(
          theme: BuTheme.light(),
          builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: c!),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: BuHero(tag: 'x', radius: 0, child: SizedBox(key: ValueKey('detail'), width: 300, height: 300, child: ColoredBox(color: Colors.transparent))),
                    ),
                  )),
                  child: const SizedBox(
                    width: 80,
                    height: 80,
                    child: BuHero(tag: 'x', radius: 16, child: SizedBox.expand(key: ValueKey('card'), child: ColoredBox(color: Colors.transparent))),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('ucus sirasinda koseler 16 -> 0 arasinda gecer, bitince detay', (t) async {
      await t.pumpWidget(app());
      await t.tap(find.byKey(const ValueKey('card')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      final clips = t.widgetList<ClipRRect>(find.byType(ClipRRect)).map((c) => (c.borderRadius as BorderRadius).topLeft.x).toList();
      // Ucus kirpmasi: 0 ile 16 arasinda ara deger bulunur.
      expect(clips.any((r) => r > 0.01 && r < 15.99), isTrue, reason: '$clips');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail')), findsOneWidget);
    });

    testWidgets('animasyonlari azalt: ucus ara kare olmadan biter', (t) async {
      await t.pumpWidget(app(reduce: true));
      await t.tap(find.byKey(const ValueKey('card')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail')), findsOneWidget);
    });
  });

  group('BuPageRoute kind', () {
    for (final k in BuRouteKind.values) {
      for (final reduce in [false, true]) {
        testWidgets('$k reduce=$reduce: ara karede sayfa var, sonunda yerinde', (t) async {
          await t.pumpWidget(MaterialApp(
            theme: BuTheme.light(),
            builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: c!),
            home: Builder(
                builder: (ctx) => TextButton(
                    onPressed: () => Navigator.of(ctx).push(BuPageRoute<void>(kind: k, builder: (_) => const Scaffold(body: Align(alignment: Alignment.topLeft, child: Text('detay'))))),
                    child: const Text('git'))),
          ));
          await t.tap(find.text('git'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 100));
          expect(find.text('detay'), findsOneWidget);
          await t.pumpAndSettle();
          final end = t.getTopLeft(find.text('detay'));
          expect(end.dx, closeTo(0, 24));
          expect(end.dy, closeTo(0, 24));
        });
      }
    }
  });

  group('BuChipRow', () {
    final labels = List.generate(14, (i) => 'Kategori $i');

    testWidgets('secili cip gorunur kalir: sona secilince kaydirir', (t) async {
      var sel = 0;
      late StateSetter set;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, s) {
        set = s;
        return BuChipRow(labels: labels, selected: sel, onSelected: (_) {});
      })));
      await t.pumpAndSettle();
      final sc = t.state<ScrollableState>(find.byType(Scrollable));
      expect(sc.position.pixels, 0);
      set(() => sel = 12);
      await t.pumpAndSettle();
      expect(sc.position.pixels, greaterThan(100));
      final r = t.getRect(find.text('Kategori 12'));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(800));
    });

    testWidgets('tasan satirda sonda solma maskesi, kisa satirda yok', (t) async {
      await t.pumpWidget(host(BuChipRow(labels: labels, selected: 0, onSelected: (_) {})));
      await t.pumpAndSettle();
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pumpWidget(host(BuChipRow(labels: const ['a', 'b'], selected: 0, onSelected: (_) {})));
      await t.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('dokunma secimi bildirir, 48 dp yukseklik, anlamsal secili', (t) async {
      int? got;
      await t.pumpWidget(host(BuChipRow(labels: labels, selected: 1, onSelected: (i) => got = i)));
      await t.pumpAndSettle();
      await t.tap(find.text('Kategori 2'));
      expect(got, 2);
      expect(t.getSize(find.byType(BuChipRow)).height, 48);
    });

    testWidgets('RTL ve reduce-motion: kaydirma anında', (t) async {
      var sel = 0;
      late StateSetter set;
      await t.pumpWidget(host(
        StatefulBuilder(builder: (c, s) {
          set = s;
          return BuChipRow(labels: labels, selected: sel, onSelected: (_) {});
        }),
        reduce: true,
        dir: TextDirection.rtl,
      ));
      await t.pumpAndSettle();
      set(() => sel = 12);
      await t.pump();
      await t.pump();
      final sc = t.state<ScrollableState>(find.byType(Scrollable));
      expect(sc.position.pixels, greaterThan(100));
    });
  });

  group('BuButton busy gecisi', () {
    testWidgets('etiket -> cember 150 ms fade, genislik (tam genislik) sabit; azalt: aninda', (t) async {
      Widget b(bool busy) => host(SizedBox(width: 300, child: BuButton(label: 'Gonder', busy: busy, onPressed: () {})));
      await t.pumpWidget(b(false));
      final w0 = t.getSize(find.byType(BuButton)).width;
      await t.pumpWidget(b(true));
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text('Gonder'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(t.getSize(find.byType(BuButton)).width, w0);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Gonder'), findsNothing);
      expect(t.getSize(find.byType(BuButton)).width, w0);
      expect(find.bySemanticsLabel('Gonder'), findsWidgets);
    });

    testWidgets('azalt: etiket aninda gider', (t) async {
      await t.pumpWidget(host(BuButton(label: 'Gonder', onPressed: () {}), reduce: true));
      await t.pumpWidget(host(BuButton(label: 'Gonder', busy: true, onPressed: () {}), reduce: true));
      await t.pump();
      expect(find.text('Gonder'), findsNothing);
    });
  });

  group('BuNumberStyle / BuScrollBehavior / BuRefreshIndicator', () {
    test('tabular rakam bir kez eklenir, mevcut ozellikler korunur', () {
      final s = const TextStyle(fontSize: 14).tabular;
      expect(s.fontFeatures!.length, 1);
      expect(s.tabular.fontFeatures!.length, 1);
      expect(const TextStyle(fontFeatures: [FontFeature.slashedZero()]).tabular.fontFeatures!.length, 2);
    });

    testWidgets('kaydirma fizigi platforma gore', (t) async {
      late BuildContext ctx;
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        await t.pumpWidget(MaterialApp(
          scrollBehavior: const BuScrollBehavior(),
          theme: BuTheme.light().copyWith(platform: p),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ));
        await t.pumpAndSettle();
        final phys = const BuScrollBehavior().getScrollPhysics(ctx);
        expect(phys, p == TargetPlatform.iOS ? isA<BouncingScrollPhysics>() : isA<ClampingScrollPhysics>());
      }
    });

    testWidgets('yenile: asagi cekip birakinca onRefresh calisir', (t) async {
      var n = 0;
      await t.pumpWidget(host(SizedBox(
        height: 400,
        child: BuRefreshIndicator(
          onRefresh: () async => n++,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 100, child: Text('a'))]),
        ),
      )));
      await t.fling(find.text('a'), const Offset(0, 300), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(n, 1);
    });
  });
}
