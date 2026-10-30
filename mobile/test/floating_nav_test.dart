import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _labels = ['Ana Sayfa', 'Keşfet', 'Sohbet', 'Kulüpler', 'Profil'];

Widget _nav(int idx, void Function(int) on, ValueNotifier<int> badge, Size size, Brightness br) => buildApp(
      Scaffold(bottomNavigationBar: FloatingNav(index: idx, onChanged: on, chatBadge: badge)),
      brightness: br,
      size: size,
    );

void main() {
  testWidgets('5 ikon, gorunur etiketler, Semantics etiketleri var', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(Icon), findsNWidgets(5));
    for (final l in _labels) {
      expect(find.text(l), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(l)), findsWidgets);
    }
    h.dispose();
  });

  testWidgets('dokunma dogru indeksle onChanged cagirir', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    final got = <int>[];
    await tester.pumpWidget(_nav(0, got.add, badge, kPhoneMedium, Brightness.light));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(_labels[i]));
      await tester.pump();
    }
    expect(got, [0, 1, 2, 3, 4]);
    h.dispose();
  });

  testWidgets('rozet gorunur ve kaybolur; 99 ustu 99+', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    expect(find.byKey(const ValueKey('nav-badge')), findsNothing);
    badge.value = 7;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('7'), findsOneWidget);
    badge.value = 150;
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
    badge.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('nav-badge')), findsNothing);
  });

  testWidgets('secili sekme sohbetse rozet gizlenir (zaten acik)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(5);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(2, (_) {}, badge, kPhoneMedium, Brightness.light));
    await tester.pump(const Duration(milliseconds: 400));
    final scale = tester.widget<AnimatedScale>(find
        .ancestor(of: find.byKey(const ValueKey('nav-badge')), matching: find.byType(AnimatedScale))
        .first);
    expect(scale.scale, 0);
  });

  testWidgets('M3 NavigationBar: secili indeks onChanged ile izlenir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(StatefulBuilder(
      builder: (c, set) => _nav(_idx, (i) => set(() => _idx = i), badge, kPhoneMedium, Brightness.light),
    ));
    for (final i in [3, 1, 4, 0]) {
      await tester.tap(find.text(_labels[i]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, i, reason: 'sekme $i');
    }
  });

  for (final size in kPhoneSizes) {
    for (final br in Brightness.values) {
      testWidgets('tasma yok ${size.width.toInt()} ${br.name}', (tester) async {
        useScreen(tester, size);
        final badge = ValueNotifier<int>(150);
        addTearDown(badge.dispose);
        await tester.pumpWidget(_nav(2, (_) {}, badge, size, br));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // dokunma hedefi >= 48 dp
        for (var i = 0; i < 5; i++) {
          final sz = tester.getSize(find.byKey(ValueKey('nav-$i')));
          expect(sz.width >= 48 && sz.height >= 48, isTrue, reason: 'sekme $i $sz');
        }
      });
    }
  }

  for (final br in [Brightness.light, Brightness.dark]) {
    for (final rtl in [false, true]) {
      testWidgets('320 dp ${br.name} ${rtl ? "rtl" : "ltr"}: tasma yok, 68 dp yukseklik (yuzen hap)', (tester) async {
        const small = Size(320, 640);
        useScreen(tester, small);
        final badge = ValueNotifier<int>(120);
        addTearDown(badge.dispose);
        await tester.pumpWidget(buildApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(bottomNavigationBar: FloatingNav(index: 3, onChanged: (_) {}, chatBadge: badge)),
          ),
          brightness: br,
          size: small,
        ));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(NavigationBar)).height, closeTo(FloatingNav.height, 1.5));
      });
    }
  }
}

int _idx = 0;
