import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Ana sayfa "Bugun kampuste": satira uzun basinca on izleme acilir; normal tik davranisi ayni kalir.

FakeBackend _be() => FakeBackend()
  ..on('/menu/today', {
    'date': '2026-01-01',
    'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav'],
    'dishes': [
      {'name': 'Mercimek çorbası', 'kcal': 160},
      {'name': 'Orman kebabı', 'kcal': 380},
      {'name': 'Pilav', 'kcal': 250},
    ],
    'totalKcal': 790,
    'kcalComplete': true,
  })
  ..on('/events/featured', null);

Future<void> _pump(WidgetTester tester) async {
  useScreen(tester, const Size(390, 1200));
  await tester.pumpWidget(buildApp(
      Scaffold(body: HomeTab(session: makeSession(_be()), onOpenTab: (i, {newsType}) {})),
      size: const Size(390, 1200)));
  await settle(tester, const Duration(seconds: 2));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('ogle yemegi satirina uzun basinca tam menu + toplam kalori on izlemesi acilir, kapanir', (tester) async {
    await _pump(tester);
    await tester.longPress(find.textContaining('Mercimek').first);
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('homeTodayPeek')), findsOneWidget);
    final peek = find.byKey(const ValueKey('homeTodayPeek'));
    expect(find.descendant(of: peek, matching: find.text('Pilav')), findsOneWidget, reason: 'tam menu (ucuncu yemek de) gorunur');
    expect(find.descendant(of: peek, matching: find.text('790 kcal')), findsOneWidget);
    expect(find.byKey(const ValueKey('homeTodayPeekOpen')), findsOneWidget);
    // Kart disina dokununca kapanir.
    await tester.tapAt(const Offset(5, 5));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('homeTodayPeek')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on izlemedeki Ac eylemi on izlemeyi kapatip ilgili sayfaya gider; normal tik on izleme acmaz', (tester) async {
    await _pump(tester);
    await tester.tap(find.textContaining('Mercimek').first);
    await settle(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('homeTodayPeek')), findsNothing, reason: 'tik on izleme acmaz');
    expect(find.byType(HomeTab), findsNothing, reason: 'tik menu sayfasina gider');
  });

  testWidgets('Ac dugmesi sayfaya gider', (tester) async {
    await _pump(tester);
    await tester.longPress(find.textContaining('Mercimek').first);
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('homeTodayPeekOpen')));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('homeTodayPeek')), findsNothing);
    expect(find.byType(HomeTab), findsNothing);
  });

  testWidgets('erisilebilirlik: satirda uzun basma eylemi var', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(tester);
    final n = tester.getSemantics(find.bySemanticsLabel(RegExp('^Öğle yemeği|^Lunch')).first);
    expect(n.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
    h.dispose();
  });
}
