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
  testWidgets('5 ikon, etiket metni yok, Semantics etiketleri var', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    expect(find.byType(Icon), findsNWidgets(5));
    for (final l in _labels) {
      expect(find.text(l), findsNothing);
      expect(find.bySemanticsLabel(l), findsOneWidget);
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
      await tester.tap(find.bySemanticsLabel(_labels[i]));
      await tester.pump();
    }
    expect(got, [0, 1, 2, 3, 4]);
    h.dispose();
  });

  testWidgets('rozet gorunur ve kaybolur', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 0);
    badge.value = 7;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(), 1);
    expect(find.text('7'), findsOneWidget);
    badge.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(), 0);
  });

  testWidgets('animasyon bitince hap secili sekmenin altinda', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(StatefulBuilder(
      builder: (c, set) => _nav(_idx, (i) => set(() => _idx = i), badge, kPhoneMedium, Brightness.light),
    ));
    for (final i in [3, 1, 4, 0]) {
      await tester.tap(find.bySemanticsLabel(_labels[i]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final pill = tester.getCenter(find.byKey(const ValueKey('nav-pill'))).dx;
      final icon = tester.getCenter(find.byType(Icon).at(i)).dx;
      expect((pill - icon).abs() < 1.0, isTrue, reason: 'sekme $i');
    }
    h.dispose();
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
        // dokunma hedefi >= 44 dp
        expect(tester.getSize(find.byType(GestureDetector).first).width >= 44, isTrue);
      });
    }
  }
}

int _idx = 0;
