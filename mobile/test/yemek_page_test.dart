import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

List<Map<String, dynamic>> _month() {
  final n = DateTime.now();
  return [
    for (var d = 1; d <= DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day; d++)
      {
        'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        'items': ['Mercimek corbasi', 'Orman kebabi cok uzun bir yemek adi burada', 'Pilav', 'Sutlac'],
      },
  ];
}

void main() {
  testWidgets('Yemek kalori: satir kcal, eksikse en az N kcal, kalorisiz yemekte tire', (tester) async {
    useScreen(tester, const Size(390, 844));
    final n = DateTime.now();
    final b = FakeBackend()
      ..on('/menu', [
        {
          'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
          'items': ['KURU FASULYE', 'TURSU'],
          'dishes': [
            {'name': 'KURU FASULYE', 'kcal': 290},
            {'name': 'TURSU', 'kcal': null},
          ],
          'totalKcal': 290,
          'kcalComplete': false,
        },
      ]);
    await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await settle(tester);
    expect(find.text('Kuru Fasulye'), findsOneWidget);
    expect(find.text('290 kcal'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('En az 290 kcal'), findsOneWidget);
    expect(find.text('0 kcal'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Yemek kalori: tamamsa Toplam N kcal', (tester) async {
    useScreen(tester, const Size(390, 844));
    final n = DateTime.now();
    final b = FakeBackend()
      ..on('/menu', [
        {
          'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
          'items': ['Pilav'],
          'dishes': [
            {'name': 'Pilav', 'kcal': 280},
          ],
          'totalKcal': 280,
          'kcalComplete': true,
        },
      ]);
    await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await settle(tester);
    expect(find.text('Toplam'), findsOneWidget);
    expect(find.text('280 kcal'), findsNWidgets(2));
    await unmount(tester);
  });

  setUpAll(loadTestFonts);

  for (final dark in [false, true]) {
    for (final lang in ['tr', 'rtl']) {
      testWidgets('Yemek gun secici + ogle karti tasma yok (320 dp, ${dark ? 'koyu' : 'acik'}, $lang)', (tester) async {
        useScreen(tester, const Size(320, 700));
        final b = FakeBackend()..on('/menu', _month());
        await tester.pumpWidget(buildApp(Directionality(textDirection: lang == 'rtl' ? TextDirection.rtl : TextDirection.ltr, child: MenuPage(session: makeSession(b))),
            brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester);
        expect(find.text('Mercimek corbasi'), findsOneWidget);
        final n = DateTime.now();
        final next = DateTime(n.year, n.month, n.day + 1);
        final nextKey = ValueKey('yemek_day_${next.year}-${next.month}-${next.day}');
        expect(find.byKey(nextKey), findsOneWidget);
        await tester.tap(find.byKey(nextKey));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
