import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// I5-01: destek talebi formu, yazılmış metin varken geri/kenar jestinde onay ister.
void main() {
  setUpAll(loadTestFonts);

  Future<void> open(WidgetTester tester) async {
    final s = makeSession(FakeBackend());
    await tester.pumpWidget(buildApp(Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => NewTicketPage(session: s))),
            child: const Text('ac'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
  }

  testWidgets('boş formda geri doğrudan kapanır', (tester) async {
    await open(tester);
    expect(find.byType(NewTicketPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NewTicketPage), findsNothing);
  });

  testWidgets('metin varken geri onay ister; "Düzenlemeye devam et" formu korur, "Sil ve çık" kapatır', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Konu basligi');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Yazdıkların silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(NewTicketPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil ve çık'));
    await tester.pumpAndSettle();
    expect(find.byType(NewTicketPage), findsNothing);
  });
}
