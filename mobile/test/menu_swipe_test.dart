import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Yemek listesi: gövdede sağa/sola kaydırmak komşu güne geçirir (LTR: sola = sonraki gün).

Future<void> _pump(WidgetTester tester, {TextDirection? dir}) async {
  useScreen(tester, kPhoneMedium);
  final n = menuToday();
  final last = DateTime(n.year, n.month + 1, 0).day;
  final month = [
    for (var d = 1; d <= last; d++)
      {'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}', 'items': ['Yemek$d']},
  ];
  final be = FakeBackend()..on('/menu', month);
  await tester.pumpWidget(buildApp(
      dir == null ? MenuPage(session: makeSession(be)) : Directionality(textDirection: dir, child: MenuPage(session: makeSession(be))),
      size: kPhoneMedium));
  await settle(tester);
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('sola kaydırınca sonraki gün, sağa kaydırınca önceki gün menüsü gelir', (tester) async {
    final n = menuToday();
    final last = DateTime(n.year, n.month + 1, 0).day;
    // Ay sınırını aşmayacak yön (ay yüklemesi bu testin konusu değil).
    final goNext = n.day < last;
    await _pump(tester);
    expect(find.textContaining('Yemek${n.day}'), findsWidgets);
    final swipe = find.byKey(const ValueKey('menu-swipe'));
    await tester.fling(swipe, Offset(goNext ? -300 : 300, 0), 1500);
    await settle(tester);
    final d1 = goNext ? n.day + 1 : n.day - 1;
    expect(find.textContaining('Yemek$d1'), findsWidgets, reason: 'komşu gün menüsü');
    expect(find.textContaining('Yemek${n.day}'), findsNothing);
    // Geri kaydır: bugüne dön.
    await tester.fling(swipe, Offset(goNext ? 300 : -300, 0), 1500);
    await settle(tester);
    expect(find.textContaining('Yemek${n.day}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kısa/yavaş yatay hareket günü değiştirmez', (tester) async {
    final n = menuToday();
    await _pump(tester);
    await tester.drag(find.byKey(const ValueKey('menu-swipe')), const Offset(-40, 0));
    await settle(tester);
    expect(find.textContaining('Yemek${n.day}'), findsWidgets);
  });

  testWidgets('sağdan sola düzende (Arapça) yön tersine döner', (tester) async {
    final n = menuToday();
    final last = DateTime(n.year, n.month + 1, 0).day;
    final goNext = n.day < last;
    await _pump(tester, dir: TextDirection.rtl);
    // RTL: sonraki gün = SAĞA kaydırma.
    await tester.fling(find.byKey(const ValueKey('menu-swipe')), Offset(goNext ? 300 : -300, 0), 1500);
    await settle(tester);
    final d1 = goNext ? n.day + 1 : n.day - 1;
    expect(find.textContaining('Yemek$d1'), findsWidgets);
  });
}
