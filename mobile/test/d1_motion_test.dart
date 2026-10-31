import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D1: ortak hareket sistemi (BuMotion jetonları, BuSwapIn, BuCountUp, BuPop, BuMotionStyles + mevcut
/// BuStaggerItem / BuPressable davranış güvenceleri).
Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      theme: BuTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: c!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('jetonlar', () {
    test('süre kademesi hızlı < normal < yavaş ve makul aralıkta', () {
      expect(BuMotion.short.inMilliseconds, inInclusiveRange(120, 160));
      expect(BuMotion.medium.inMilliseconds, inInclusiveRange(220, 280));
      expect(BuMotion.long.inMilliseconds, inInclusiveRange(300, 400));
      expect(BuMotion.short < BuMotion.medium, isTrue);
      expect(BuMotion.medium < BuMotion.long, isTrue);
      expect(BuMotion.stagger.inMilliseconds, inInclusiveRange(30, 40));
    });

    test('eğriler 0 -> 0, 1 -> 1 uçlu ve giriş çıkıştan farklı', () {
      for (final c in [BuMotion.standard, BuMotion.emphasizedDecelerate, BuMotion.emphasizedAccelerate]) {
        expect(c.transform(0), closeTo(0, 1e-9));
        expect(c.transform(1), closeTo(1, 1e-9));
      }
      // Giriş eğrisi başta hızlı (yavaşlayan), çıkış eğrisi başta yavaş (hızlanan).
      expect(BuMotion.emphasizedDecelerate.transform(.25), greaterThan(BuMotion.emphasizedAccelerate.transform(.25)));
    });

    testWidgets('animasyonları azalt açıkken süre 0, kapalıyken aynen', (tester) async {
      late Duration reduced, normal;
      await tester.pumpWidget(host(Builder(builder: (c) {
        reduced = BuMotion.of(c);
        return const SizedBox();
      }), reduce: true));
      await tester.pumpWidget(host(Builder(builder: (c) {
        normal = BuMotion.of(c, BuMotion.long);
        return const SizedBox();
      })));
      expect(reduced, Duration.zero);
      expect(normal, BuMotion.long);
    });
  });

  group('BuSwapIn', () {
    testWidgets('yükleme bitince iskelet solar, içerik gelir', (tester) async {
      Widget build(bool loading) => host(BuSwapIn(
            loading: loading,
            skeleton: const SizedBox(key: ValueKey('sk'), width: 50, height: 20),
            child: const SizedBox(key: ValueKey('ct'), width: 50, height: 20),
          ));
      await tester.pumpWidget(build(true));
      expect(find.byKey(const ValueKey('sk')), findsOneWidget);
      expect(find.byKey(const ValueKey('ct')), findsNothing);
      await tester.pumpWidget(build(false));
      await tester.pump(BuMotion.medium ~/ 2);
      // Geçiş ortasında ikisi birlikte bulunur.
      expect(find.byKey(const ValueKey('sk')), findsOneWidget);
      expect(find.byKey(const ValueKey('ct')), findsOneWidget);
      await tester.pump(BuMotion.medium);
      expect(find.byKey(const ValueKey('sk')), findsNothing);
      expect(find.byKey(const ValueKey('ct')), findsOneWidget);
    });

    testWidgets('animasyonları azalt: anında içerik', (tester) async {
      Widget build(bool loading) => host(
          BuSwapIn(
            loading: loading,
            skeleton: const SizedBox(key: ValueKey('sk'), width: 50, height: 20),
            child: const SizedBox(key: ValueKey('ct'), width: 50, height: 20),
          ),
          reduce: true);
      await tester.pumpWidget(build(true));
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(find.byKey(const ValueKey('sk')), findsNothing);
      expect(find.byKey(const ValueKey('ct')), findsOneWidget);
    });
  });

  group('BuCountUp', () {
    testWidgets('ilk görünümde 0\'dan sayar, sonunda değerde durur', (tester) async {
      await tester.pumpWidget(host(const BuCountUp(value: 120)));
      expect(find.text('0'), findsOneWidget);
      await tester.pump(BuMotion.long ~/ 2);
      final mid = int.parse((tester.widget<Text>(find.byType(Text)).data)!);
      expect(mid, inExclusiveRange(0, 120));
      await tester.pump(BuMotion.long);
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('animasyonları azalt: anında son değer; ekran okuyucu son değeri okur', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const BuCountUp(value: 42), reduce: true));
      expect(find.text('42'), findsOneWidget);
      expect(find.bySemanticsLabel('42'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('animateFirst false: ilk karede doğrudan değer; sonra değişince sayar', (tester) async {
      await tester.pumpWidget(host(const BuCountUp(value: 10, animateFirst: false)));
      expect(find.text('10'), findsOneWidget);
      await tester.pumpWidget(host(const BuCountUp(value: 50, animateFirst: false)));
      await tester.pump(BuMotion.long ~/ 3);
      final v = int.parse((tester.widget<Text>(find.byType(Text)).data)!);
      expect(v, inExclusiveRange(10, 50));
      await tester.pump(BuMotion.long);
      expect(find.text('50'), findsOneWidget);
    });
  });

  group('BuPop', () {
    double scaleOf(WidgetTester t) => t.widget<ScaleTransition>(find.descendant(of: find.byType(BuPop), matching: find.byType(ScaleTransition))).scale.value;

    testWidgets('ilk kurulumda oynamaz; tetik değişince büyüyüp döner', (tester) async {
      Widget build(int n) => host(BuPop(trigger: n, child: const SizedBox(width: 20, height: 20)));
      await tester.pumpWidget(build(1));
      expect(scaleOf(tester), 1.0);
      await tester.pumpWidget(build(2));
      await tester.pump(BuMotion.medium * .4);
      expect(scaleOf(tester), greaterThan(1.05));
      await tester.pump(BuMotion.medium);
      expect(scaleOf(tester), closeTo(1.0, 1e-6));
    });

    testWidgets('aynı tetikte oynamaz; animasyonları azalt açıkken hiç oynamaz', (tester) async {
      await tester.pumpWidget(host(const BuPop(trigger: 1, child: SizedBox(width: 20, height: 20))));
      await tester.pumpWidget(host(const BuPop(trigger: 1, child: SizedBox(width: 20, height: 20))));
      await tester.pump(BuMotion.short);
      expect(scaleOf(tester), 1.0);

      await tester.pumpWidget(host(const BuPop(trigger: 1, child: SizedBox(width: 20, height: 20)), reduce: true));
      await tester.pumpWidget(host(const BuPop(trigger: 2, child: SizedBox(width: 20, height: 20)), reduce: true));
      await tester.pump(BuMotion.short);
      expect(scaleOf(tester), 1.0);
    });
  });

  group('aşamalı giriş (mevcut BuStaggerItem)', () {
    testWidgets('yalnız ilk görünürde oynar; kapsam içinde yeniden kurulunca oynamaz; 8. öğeden sonrası anında', (tester) async {
      Widget list(bool show) => host(BuStaggerScope(
            child: Column(children: [
              if (show) ...[
                for (var i = 0; i < 10; i++) BuStaggerItem(index: i, child: SizedBox(key: ValueKey('i$i'), height: 4, width: 4)),
              ],
            ]),
          ));
      int fades() => tester.widgetList(find.descendant(of: find.byType(BuStaggerItem), matching: find.byType(FadeTransition))).length;

      await tester.pumpWidget(list(true));
      expect(fades(), 8); // en çok ilk 8
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(list(false));
      await tester.pumpWidget(list(true)); // kaydırıp geri gelme benzetimi
      expect(fades(), 0);
    });

    testWidgets('animasyonları azalt: hiç geçiş katmanı yok', (tester) async {
      await tester.pumpWidget(host(const BuStaggerItem(index: 0, child: SizedBox(width: 4, height: 4)), reduce: true));
      expect(find.descendant(of: find.byType(BuStaggerItem), matching: find.byType(FadeTransition)), findsNothing);
    });
  });

  group('BuPressable', () {
    testWidgets('dokunma çalışır, anlamsal düğme, çocuğun boyutunu değiştirmez', (tester) async {
      final handle = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(host(BuPressable(
        onTap: () => n++,
        semanticLabel: 'Kaydet',
        child: const SizedBox(key: ValueKey('c'), width: 120, height: 48),
      )));
      expect(tester.getSize(find.byKey(const ValueKey('c'))), const Size(120, 48));
      expect(tester.getSemantics(find.bySemanticsLabel('Kaydet')), matchesSemantics(label: 'Kaydet', isButton: true, hasTapAction: true, hasEnabledState: true, isEnabled: true, isFocusable: false));
      await tester.tap(find.byType(BuPressable));
      expect(n, 1);
      handle.dispose();
    });

    testWidgets('basılıyken 0.97 küçülür, bırakınca geri döner; azaltmada küçülmez', (tester) async {
      double scale(WidgetTester t) => t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      await tester.pumpWidget(host(BuPressable(onTap: () {}, child: const SizedBox(width: 80, height: 48))));
      final g = await tester.startGesture(tester.getCenter(find.byType(SizedBox).last));
      await tester.pump();
      expect(scale(tester), closeTo(.97, 1e-9));
      await g.up();
      await tester.pump();
      expect(scale(tester), 1.0);

      await tester.pumpWidget(host(BuPressable(onTap: () {}, child: const SizedBox(width: 80, height: 48)), reduce: true));
      final g2 = await tester.startGesture(tester.getCenter(find.byType(SizedBox).last));
      await tester.pump();
      expect(scale(tester), 1.0);
      await g2.up();
    });
  });

  group('BuMotionStyles', () {
    testWidgets('eğri ve süreler; azaltmada süre 0', (tester) async {
      late AnimationStyle sheet, dialog, toast;
      Widget probe() => Builder(builder: (c) {
            sheet = BuMotionStyles.sheet(c);
            dialog = BuMotionStyles.dialog(c);
            toast = BuMotionStyles.toast(c);
            return const SizedBox();
          });
      await tester.pumpWidget(host(probe()));
      expect(sheet.duration, BuMotion.medium);
      expect(sheet.reverseDuration, BuMotion.short);
      expect(sheet.curve, BuMotion.emphasizedDecelerate);
      expect(sheet.reverseCurve, BuMotion.emphasizedAccelerate);
      expect(dialog.curve, BuMotion.emphasizedDecelerate);
      expect(toast.duration, BuMotion.medium);

      await tester.pumpWidget(host(probe(), reduce: true));
      expect(sheet.duration, Duration.zero);
      expect(dialog.duration, Duration.zero);
      expect(toast.reverseDuration, Duration.zero);
    });

    testWidgets('BuSheet ve BuDialog.confirm açılır/kapanır; azaltmada tek karede', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(host(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }), reduce: true));

      BuSheet.show<void>(ctx, title: 'Başlık', builder: (_) => const Text('gövde'));
      await tester.pump();
      await tester.pump();
      expect(find.text('gövde'), findsOneWidget);
      Navigator.of(ctx, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expect(find.text('gövde'), findsNothing);

      BuDialog.confirm(ctx, title: 'Emin misin', confirmLabel: 'Evet', cancelLabel: 'Hayır');
      await tester.pump();
      await tester.pump();
      expect(find.text('Emin misin'), findsOneWidget);
      await tester.tap(find.text('Evet'));
      await tester.pumpAndSettle();
      expect(find.text('Emin misin'), findsNothing);

      BuToast.show(ctx, 'Kaydedildi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Kaydedildi'), findsOneWidget);
    });
  });
}
