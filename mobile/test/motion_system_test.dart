import 'dart:async';

import 'package:bu_kampus/core/theme/bu_page_transitions.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hareket sistemi (docs/MOBILE_MOTION.md): süre/eğri/yay sabitleri, kademe üst sınırı, azaltılmış hareket,
/// BuFadeSlideIn / BuStateSwitcher / BuShake / BuPressable davranışı ve sayfa geçişi teması.
Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      theme: BuTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: c!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('sabitler', () {
    test('süre kademesi: micro 120, quick 200, standard 300, slow 450, page 400, dramatic 700', () {
      const d = BuMotion.durations;
      expect(d.micro.inMilliseconds, 120);
      expect(d.quick.inMilliseconds, 200);
      expect(d.standard.inMilliseconds, 300);
      expect(d.slow.inMilliseconds, 450);
      expect(d.page.inMilliseconds, 400);
      expect(d.dramatic.inMilliseconds, 700);
      expect(d.micro < d.quick && d.quick < d.standard && d.standard < d.slow && d.slow < d.dramatic, isTrue);
      // Hata sarsıntısı 300-400 ms aralığında; ambient döngü uzun.
      expect(d.shake.inMilliseconds, inInclusiveRange(300, 400));
      expect(d.ambient.inMilliseconds, greaterThan(1000));
    });

    test('çıkış süresi girişin %70\'i', () {
      expect(BuMotion.exit(BuMotion.durations.standard).inMilliseconds, 210);
      expect(BuMotion.exit(BuMotion.durations.page).inMilliseconds, 280);
      expect(BuMotion.exit(BuMotion.durations.standard) < BuMotion.durations.standard, isTrue);
    });

    test('eğriler 0 -> 0 ve 1 -> 1 uçlu; yerleşme eğrileri taşma bütçesi içinde', () {
      final all = <Curve>[
        BuMotion.curves.standard,
        BuMotion.curves.emphasized,
        BuMotion.curves.emphasizedDecelerate,
        BuMotion.curves.emphasizedAccelerate,
        BuMotion.curves.decelerate,
        BuMotion.curves.accelerate,
        BuMotion.curves.settle,
        BuMotion.curves.success,
      ];
      for (final c in all) {
        expect(c.transform(0), closeTo(0, 1e-9));
        expect(c.transform(1), closeTo(1, 1e-9));
      }
      double peak(Curve c) {
        var m = 0.0;
        for (var i = 0; i <= 200; i++) {
          m = m < c.transform(i / 200) ? c.transform(i / 200) : m;
        }
        return m - 1; // 0 = taşma yok
      }

      expect(peak(BuMotion.curves.settle), inInclusiveRange(0.02, 0.05)); // geri bildirim %2-5
      expect(peak(BuMotion.curves.success), inInclusiveRange(0.05, 0.10)); // başarı %5-10
      for (final c in [BuMotion.curves.standard, BuMotion.curves.emphasizedDecelerate, BuMotion.curves.decelerate, BuMotion.curves.accelerate]) {
        expect(peak(c), lessThanOrEqualTo(1e-9)); // hata/normal hareket taşmaz
      }
      expect(BuMotion.curves.linear, Curves.linear);
    });

    test('yay: tüm kademeler tanımlı; crisp kritik sönümlü (taşmasız)', () {
      const s = BuMotion.springs;
      expect(s.standard.stiffness, 300);
      expect(s.crisp.stiffness, greaterThanOrEqualTo(400));
      // Sönüm oranı = damping / (2 * sqrt(k * m)); <1 salınır.
      double ratio(SpringDescription d) => d.damping / (2 * _sqrt(d.stiffness * d.mass));
      expect(ratio(s.crisp), greaterThanOrEqualTo(0.99));
      expect(ratio(s.standard), inInclusiveRange(0.6, 0.8));
      expect(ratio(s.gentle), greaterThanOrEqualTo(0.99));
    });

    test('stagger: adım x indeks, üst sınır max ve toplam bütçe < 500 ms', () {
      expect(BuMotion.stagger(0), Duration.zero);
      expect(BuMotion.stagger(1), const Duration(milliseconds: 60));
      expect(BuMotion.stagger(3), const Duration(milliseconds: 180));
      // max=6: 6. indeksten sonrası aynı gecikmeyi alır (uzun listede gecikme büyümez).
      expect(BuMotion.stagger(6), const Duration(milliseconds: 360));
      expect(BuMotion.stagger(40), const Duration(milliseconds: 360));
      expect(BuMotion.stagger(-3), Duration.zero);
      expect(BuMotion.stagger(100, step: const Duration(milliseconds: 100), max: 20) <= BuMotion.staggerBudget, isTrue);
      expect(BuMotion.staggerBudget < const Duration(milliseconds: 500), isTrue);
    });

    test('eski adlar yeni kademeye takma ad; eski eğri adları korunur', () {
      expect(BuMotion.short, BuMotion.durations.quick);
      expect(BuMotion.medium, BuMotion.durations.standard);
      expect(BuMotion.long, BuMotion.durations.page);
      expect(BuMotion.standard, BuMotion.curves.standard);
    });
  });

  group('azaltılmış hareket', () {
    testWidgets('of: süre 0; fadeOf: kısa solma; loopsAllowed: döngü durur', (tester) async {
      late Duration of, fade;
      late bool loops;
      Widget probe() => Builder(builder: (c) {
            of = BuMotion.of(c, BuMotion.durations.slow);
            fade = BuMotion.fadeOf(c, BuMotion.durations.slow);
            loops = BuMotion.loopsAllowed(c);
            return const SizedBox();
          });
      await tester.pumpWidget(host(probe(), reduce: true));
      expect(of, Duration.zero);
      expect(fade, BuMotion.durations.reducedFade);
      expect(fade.inMilliseconds, lessThanOrEqualTo(120));
      expect(loops, isFalse);
      await tester.pumpWidget(host(probe()));
      expect(of, BuMotion.durations.slow);
      expect(fade, BuMotion.durations.slow);
      expect(loops, isTrue);
    });

    testWidgets('scrollTo: normalde animasyonla, azaltılmışta anında atlar', (tester) async {
      final c = ScrollController();
      late BuildContext ctx;
      Widget build(bool reduce) => host(
            SizedBox(
              height: 200,
              child: Builder(builder: (cc) {
                ctx = cc;
                return ListView(controller: c, children: [for (var i = 0; i < 40; i++) SizedBox(height: 50, child: Text('$i'))]);
              }),
            ),
            reduce: reduce,
          );
      await tester.pumpWidget(build(true));
      unawaited(BuMotion.scrollTo(ctx, c, 500));
      await tester.pump();
      expect(c.offset, 500); // tek karede
      await tester.pumpWidget(build(false));
      c.jumpTo(0);
      unawaited(BuMotion.scrollTo(ctx, c, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(c.offset, inExclusiveRange(0, 500));
      await tester.pumpAndSettle();
      expect(c.offset, 500);
    });
  });

  group('BuFadeSlideIn', () {
    Offset posOf(WidgetTester t) => t.getTopLeft(find.byKey(const ValueKey('c')));

    testWidgets('yükselerek ve solarak gelir; 300 ms içinde oturur', (tester) async {
      await tester.pumpWidget(host(const BuFadeSlideIn(child: SizedBox(key: ValueKey('c'), width: 40, height: 20))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = posOf(tester);
      final op = tester.widget<Opacity>(find.descendant(of: find.byType(BuFadeSlideIn), matching: find.byType(Opacity)));
      expect(op.opacity, inExclusiveRange(0, 1));
      await tester.pump(BuMotion.durations.standard);
      final end = posOf(tester);
      expect(mid.dy, greaterThan(end.dy)); // aşağıdan gelir
      expect(mid.dy - end.dy, lessThanOrEqualTo(12)); // en çok 12 dp
      expect(find.descendant(of: find.byType(BuFadeSlideIn), matching: find.byType(Opacity)), findsNothing);
    });

    testWidgets('kademe: indeks gecikme ekler (60 ms x indeks)', (tester) async {
      await tester.pumpWidget(host(const Column(children: [
        BuFadeSlideIn(index: 0, child: SizedBox(key: ValueKey('a'), width: 40, height: 10)),
        BuFadeSlideIn(index: 3, child: SizedBox(key: ValueKey('b'), width: 40, height: 10)),
      ])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      Opacity o(String k) => tester.widget<Opacity>(find.ancestor(of: find.byKey(ValueKey(k)), matching: find.byType(Opacity)).first);
      expect(o('a').opacity, greaterThan(0.3));
      expect(o('b').opacity, 0.0); // 180 ms gecikme henüz dolmadı
      await tester.pump(BuMotion.durations.standard + BuMotion.stagger(3));
    });

    testWidgets('azaltılmış hareket: kayma yok, yalnız kısa solma', (tester) async {
      await tester.pumpWidget(host(const BuFadeSlideIn(child: SizedBox(key: ValueKey('c'), width: 40, height: 20)), reduce: true));
      final start = posOf(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(posOf(tester), start); // konum değişmez
      await tester.pump(const Duration(milliseconds: 100));
      expect(posOf(tester), start);
      expect(find.descendant(of: find.byType(BuFadeSlideIn), matching: find.byType(Opacity)), findsNothing);
    });

    testWidgets('animate: false doğrudan çocuğu gösterir', (tester) async {
      await tester.pumpWidget(host(const BuFadeSlideIn(animate: false, child: SizedBox(width: 40, height: 20))));
      expect(find.descendant(of: find.byType(BuFadeSlideIn), matching: find.byType(Opacity)), findsNothing);
    });
  });

  group('BuStateSwitcher', () {
    Widget build(String state, {bool reduce = false}) => host(
          BuStateSwitcher(state: state, child: SizedBox(key: ValueKey('s-$state'), width: 40, height: 20)),
          reduce: reduce,
        );

    testWidgets('yükleniyor -> içerik: ikisi geçişte birlikte, sonra yalnız yeni (300 ms)', (tester) async {
      await tester.pumpWidget(build('load'));
      await tester.pumpWidget(build('ok'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('s-load')), findsOneWidget);
      expect(find.byKey(const ValueKey('s-ok')), findsOneWidget);
      await tester.pump(BuMotion.durations.standard);
      expect(find.byKey(const ValueKey('s-load')), findsNothing);
      expect(find.byKey(const ValueKey('s-ok')), findsOneWidget);
    });

    testWidgets('yalnız opaklık değil: gelen çocuk kısa bir yükselme alır', (tester) async {
      await tester.pumpWidget(build('load'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build('ok'));
      await tester.pump(const Duration(milliseconds: 30));
      final mid = tester.getTopLeft(find.byKey(const ValueKey('s-ok'))).dy;
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.byKey(const ValueKey('s-ok'))).dy;
      expect(mid, greaterThan(settled));
      expect(mid - settled, lessThanOrEqualTo(8));
    });

    testWidgets('azaltılmış hareket: 100 ms solma, kayma yok', (tester) async {
      await tester.pumpWidget(build('load', reduce: true));
      final y = tester.getTopLeft(find.byKey(const ValueKey('s-load'))).dy;
      await tester.pumpWidget(build('ok', reduce: true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getTopLeft(find.byKey(const ValueKey('s-ok'))).dy, y);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const ValueKey('s-load')), findsNothing);
    });
  });

  group('BuShake', () {
    Widget build(int n, {bool reduce = false}) =>
        host(BuShake(trigger: n, child: const SizedBox(key: ValueKey('c'), width: 40, height: 20)), reduce: reduce);

    testWidgets('ilk kurulumda sallanmaz; tetikte yatay salınır, 320 ms\'de durur, dikey/ölçek yok', (tester) async {
      await tester.pumpWidget(build(0));
      final home = tester.getTopLeft(find.byKey(const ValueKey('c')));
      await tester.pumpWidget(build(1));
      var minDx = 0.0, maxDx = 0.0;
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        final p = tester.getTopLeft(find.byKey(const ValueKey('c')));
        expect(p.dy, home.dy);
        minDx = minDx < p.dx - home.dx ? minDx : p.dx - home.dx;
        maxDx = maxDx > p.dx - home.dx ? maxDx : p.dx - home.dx;
      }
      expect(minDx, lessThan(-1)); // iki yöne de gider
      expect(maxDx, greaterThan(1));
      expect(maxDx.abs(), lessThanOrEqualTo(6.0001)); // hafif
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.byKey(const ValueKey('c'))), home);
    });

    test('salınım sayısı 2-3 ve genlik sönümlü', () {
      var crossings = 0;
      var prev = BuShake.offsetAt(0.001, 6);
      for (var i = 2; i <= 400; i++) {
        final v = BuShake.offsetAt(i / 400, 6);
        if (prev.sign != v.sign && v != 0) crossings++;
        prev = v;
      }
      // 2,5 tam salınım -> ~5 sıfır geçişi (yarım salınım başına bir).
      expect(crossings, inInclusiveRange(4, 6));
      expect(BuShake.offsetAt(1, 6).abs(), lessThan(1e-9));
      expect(BuShake.offsetAt(0.1, 6).abs(), lessThanOrEqualTo(6));
    });

    testWidgets('azaltılmış hareket: sallanmaz', (tester) async {
      await tester.pumpWidget(build(0, reduce: true));
      final home = tester.getTopLeft(find.byKey(const ValueKey('c')));
      await tester.pumpWidget(build(1, reduce: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(find.byKey(const ValueKey('c'))), home);
    });
  });

  group('BuPressable', () {
    testWidgets('basma 120 ms, bırakma 300 ms; azaltılmışta ölçek yok', (tester) async {
      AnimatedScale sc() => tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      await tester.pumpWidget(host(BuPressable(onTap: () {}, child: const SizedBox(width: 80, height: 48))));
      final g = await tester.startGesture(tester.getCenter(find.byType(BuPressable)));
      await tester.pump();
      expect(sc().scale, closeTo(0.97, 1e-9));
      expect(sc().duration, BuMotion.durations.micro);
      expect(sc().duration.inMilliseconds, lessThan(150)); // basma < 150 ms
      await g.up();
      await tester.pump();
      expect(sc().scale, 1.0);
      expect(sc().duration.inMilliseconds, inInclusiveRange(200, 300)); // yerleşme 200-300 ms
      expect(sc().curve, BuMotion.curves.settle);
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(BuPressable(onTap: () {}, child: const SizedBox(width: 80, height: 48)), reduce: true));
      final g2 = await tester.startGesture(tester.getCenter(find.byType(BuPressable)));
      await tester.pump();
      expect(sc().scale, 1.0);
      await g2.up();
    });

    testWidgets('kaydırma jesti (parmak slop\'u aşar) basılı durumu iptal eder', (tester) async {
      AnimatedScale sc() => tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      await tester.pumpWidget(host(BuPressable(onTap: () {}, child: const SizedBox(width: 80, height: 48))));
      final g = await tester.startGesture(tester.getCenter(find.byType(BuPressable)));
      await tester.pump();
      expect(sc().scale, closeTo(0.97, 1e-9));
      await g.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(sc().scale, 1.0);
      await g.up();
    });
  });

  group('BuPop', () {
    testWidgets('varsayılan tepe %10, hata değil başarı/rozet için; azaltılmışta oynamaz', (tester) async {
      double scaleOf() =>
          tester.widget<ScaleTransition>(find.descendant(of: find.byType(BuPop), matching: find.byType(ScaleTransition))).scale.value;
      Widget build(int n, {bool reduce = false}) =>
          host(BuPop(trigger: n, child: const SizedBox(width: 20, height: 20)), reduce: reduce);
      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(2));
      var peak = 1.0;
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        peak = peak > scaleOf() ? peak : scaleOf();
      }
      expect(peak, inInclusiveRange(1.08, 1.11));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(1, reduce: true));
      await tester.pumpWidget(build(2, reduce: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(scaleOf(), 1.0);
    });
  });

  group('sayfa geçişi teması', () {
    test('Android tahmini geri, iOS Cupertino (kenardan geri kaydırma korunur)', () {
      final b = BuPageTransitions.theme.builders;
      expect((b[TargetPlatform.android] as BuPageTransitionsBuilder).inner, isA<PredictiveBackPageTransitionsBuilder>());
      expect((b[TargetPlatform.iOS] as BuPageTransitionsBuilder).inner, isA<CupertinoPageTransitionsBuilder>());
    });

    test('ThemeData tek yerden bu temayı kullanır', () {
      expect(BuTheme.light().pageTransitionsTheme, BuPageTransitions.theme);
      expect(BuTheme.dark().pageTransitionsTheme, BuPageTransitions.theme);
    });

    testWidgets('azaltılmış hareketle sayfa geçişi kayma/ölçek katmanı eklemez', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        theme: BuTheme.light().copyWith(platform: TargetPlatform.iOS),
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!),
        home: const Scaffold(body: Text('ana')),
      ));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detay'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // iOS Cupertino geçişi olsaydı detay ekranın dışından kayarak gelirdi.
      expect(tester.getTopLeft(find.text('detay')).dx, lessThan(100));
      await tester.pumpAndSettle();
    });

    test('BuPageRoute: ileri 400 ms, geri 300 ms (çıkış girişten kısa)', () {
      final r = BuPageRoute<void>(builder: (_) => const SizedBox());
      expect(r.transitionDuration, BuMotion.durations.page);
      expect(r.reverseTransitionDuration < r.transitionDuration, isTrue);
    });
  });
}

double _sqrt(double x) {
  var g = x / 2;
  for (var i = 0; i < 30; i++) {
    g = (g + x / g) / 2;
  }
  return g;
}
