import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_topup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

List<Map<String, dynamic>> _month() {
  final n = DateTime.now();
  return [
    for (var d = 1; d <= DateTime(n.year, n.month + 1, 0).day; d++)
      {
        'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        'items': ['Mercimek çorbası', 'Pilav', 'Ayran'],
      },
  ];
}

void main() {
  setUpAll(loadTestFonts);

  test('bakiye yükleme adresi https://yukle.al/', () {
    expect(menuTopUpUri.scheme, 'https');
    expect(menuTopUpUri.host, 'yukle.al');
  });

  for (final size in [const Size(320, 700), const Size(390, 844)]) {
    for (final dark in [false, true]) {
      final tag = '${size.width.toInt()}dp ${dark ? 'koyu' : 'acik'}';
      testWidgets('MenuPage: bakiye yükle kartı görünür, taşma yok ($tag)', (tester) async {
        useScreen(tester, size);
        final b = FakeBackend()..on('/menu', _month());
        await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b)),
            brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester);
        await tester.scrollUntilVisible(find.text('Bakiye yükle'), 200, scrollable: find.byType(Scrollable).last);
        expect(find.text('Yemek kartı bakiyesi'), findsOneWidget);
        expect(find.text('Bakiye yükle'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('MenuPage: menü listesi boşken de bakiye kartı görünür', (tester) async {
    useScreen(tester, const Size(320, 900));
    final b = FakeBackend()..on('/menu', <Map<String, dynamic>>[]);
    await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Bakiye yükle'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Bakiye yükle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
