import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Widget _launcher(FakeBackend b) {
  b.on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]});
  final s = makeSession(b);
  return Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EventFormPage(session: s))),
          child: const Text('ac'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('I5-01: degisiklik yokken geri onaysiz; yazilinca onay sorar, vazgec formu korur', (tester) async {
    useScreen(tester, const Size(390, 1600));
    final b = FakeBackend();
    await tester.pumpWidget(buildApp(_launcher(b)));
    await tester.tap(find.text('ac'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Etkinliği oluştur'), findsOneWidget);

    // temiz form: geri doğrudan kapatır
    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('ac'), findsOneWidget);

    // yazılmış form: onay çıkar
    await tester.tap(find.text('ac'));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).first, 'Bahar Şenliği');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Değişiklikler atılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye devam'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Etkinliği oluştur'), findsOneWidget);
    expect(find.text('Bahar Şenliği'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('At'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('ac'), findsOneWidget);
    await unmount(tester);
  });
}
