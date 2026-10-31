import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

FakeBackend _backend() => FakeBackend()
  ..on('/faq', [
    {
      'category': 'Hesap',
      'items': [
        {'question': 'Sifremi nasil degistiririm?', 'answer': 'Ayarlar sayfasindan.'}
      ],
    },
    {
      'category': 'Yemek',
      'items': [
        {'question': 'Menu nerede?', 'answer': 'Yemek sekmesinde.'}
      ],
    },
  ])
  ..on('/support/tickets', {
    'items': [
      {'id': 5, 'subject': 'Bildirim gelmiyor', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-01T10:00:00'}
    ],
    'nextCursor': null,
  })
  ..on('/support/tickets/5', {
    'ticket': {'id': 5, 'subject': 'Bildirim gelmiyor', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-01T10:00:00'},
    'messages': [
      {'id': 1, 'text': 'Merhaba ' * 20, 'fromStaff': false, 'createdAt': '2026-10-01T10:00:00'},
      {'id': 2, 'text': 'Yardimci olalim.', 'fromStaff': true, 'createdAt': '2026-10-01T11:00:00'},
    ],
  })
  ..on('/suggestions', {
    'totalPages': 1,
    'items': [
      {'id': 1, 'subject': 'Alerjen bilgisi', 'message': 'Etiket gosterilsin ' * 5, 'status': 'PLANNED', 'voteCount': 128, 'votedByMe': true},
      {'id': 2, 'subject': 'Kutuphane doluluk', 'message': 'x', 'status': 'IN_REVIEW', 'voteCount': 94, 'votedByMe': false},
    ],
  })
  ..on('/legal', [
    {'type': 'TERMS', 'title': 'Kullanim Kosullari', 'version': 2, 'publishedAt': '2026-09-01T00:00:00'},
    {'type': 'PRIVACY', 'title': 'Gizlilik', 'version': 1, 'publishedAt': '2026-09-01T00:00:00'},
    {'type': 'KVKK', 'title': 'KVKK', 'version': 1, 'publishedAt': '2026-09-01T00:00:00'},
  ])
  ..on('/legal/TERMS', {'type': 'TERMS', 'title': 'Kullanim Kosullari', 'version': 2, 'publishedAt': '2026-09-01T00:00:00', 'content': '## 1. Kapsam\n\nMetin.'})
  ..on('/legal/PRIVACY', {'type': 'PRIVACY', 'title': 'Gizlilik', 'version': 1, 'publishedAt': '2026-09-01T00:00:00', 'content': '## Veri\n\nGizlilik metni.'});

void main() {
  final pages = <String, Widget Function(FakeBackend)>{
    'support': (b) => SupportPage(session: makeSession(b)),
    'ticket': (b) => SupportTicketPage(session: makeSession(b), ticketId: 5),
    'suggestions': (b) => SuggestionsPage(session: makeSession(b)),
    'legal': (b) => LegalDocPage(session: makeSession(b), type: 'TERMS'),
  };
  for (final e in pages.entries) {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        testWidgets('${e.key} dark=$dark rtl=$rtl 320dp tasma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          final w = e.value(_backend());
          await tester.pumpWidget(buildApp(
              Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: w),
              brightness: dark ? Brightness.dark : Brightness.light));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('SSS arama (7+ soruda gorunur) listeyi suzer; az soruda arama alani yok', (tester) async {
    useScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(buildApp(SupportPage(session: makeSession(_backend())), size: const Size(390, 1200)));
    await tester.pumpAndSettle();
    expect(find.text('Sifremi nasil degistiririm?'), findsOneWidget);
    expect(find.text('Menu nerede?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // Stitch v3: uc soruluk listede arama/suzgec yok
    await tester.pumpWidget(const SizedBox.shrink());

    final many = _backend()
      ..on('/faq', [
        {
          'category': 'Hesap',
          'items': [for (var i = 0; i < 5; i++) {'question': 'Soru hesap $i', 'answer': 'Cevap.'}, {'question': 'Sifremi nasil degistiririm?', 'answer': 'Ayarlar sayfasindan.'}],
        },
        {
          'category': 'Yemek',
          'items': [for (var i = 0; i < 2; i++) {'question': 'Soru yemek $i', 'answer': 'Cevap.'}, {'question': 'Menu nerede?', 'answer': 'Yemek sekmesinde.'}],
        },
      ]);
    useScreen(tester, const Size(390, 1600));
    await tester.pumpWidget(buildApp(SupportPage(session: makeSession(many)), size: const Size(390, 1600)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'menu');
    await tester.pump();
    expect(find.text('Sifremi nasil degistiririm?'), findsNothing);
    expect(find.text('Menu nerede?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Yemek'));
    await tester.pumpAndSettle();
    expect(find.text('Menu nerede?'), findsOneWidget);
    expect(find.text('Soru hesap 0'), findsNothing);
  });

  // Yeni tasarimda belge sayfasinda sekme seridi yok: belge secimi liste sayfasindan yapilir.
  testWidgets('Sozlesme listesinden secilen belge acilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(LegalListPage(session: makeSession(_backend()))));
    await tester.pumpAndSettle();
    expect(find.text('Kullanim Kosullari'), findsOneWidget);
    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();
    expect(find.text('Gizlilik metni.'), findsOneWidget);
    expect(find.text('Metin.'), findsNothing);
  });
}
