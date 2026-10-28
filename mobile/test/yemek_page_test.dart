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
        expect(find.byKey(const ValueKey('yemek_day_prev')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('yemek_day_next')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('yemek_day_prev')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
