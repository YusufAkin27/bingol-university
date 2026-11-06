// QA-5: destek ekranlarının etkileşimleri: talep yanıtı, kapalı talep, öneri oyu (iyimser + geri alma), form doğrulamaları.
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

Map<String, dynamic> _ticket(String status) => {
      'ticket': {'id': 5, 'category': 'ACCOUNT', 'subject': 'Giriş sorunu', 'status': status, 'createdAt': '2026-11-01T10:00:00Z', 'updatedAt': '2026-11-02T10:00:00Z'},
      'messages': [
        {'id': 1, 'fromStaff': false, 'text': 'Giriş yapamıyorum', 'createdAt': '2026-11-01T10:00:00Z'},
        {'id': 2, 'fromStaff': true, 'text': 'Yardımcı olalım.', 'createdAt': '2026-11-02T10:00:00Z'},
      ],
    };

void main() {
  setUpAll(loadTestFonts);

  group('talep detayı', () {
    Future<FakeBackend> open(WidgetTester tester, {String status = 'OPEN'}) async {
      final b = FakeBackend();
      b.on('/support/tickets/5', _ticket(status));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SupportTicketPage(session: makeSession(b), ticketId: 5)));
      await settle(tester, const Duration(seconds: 1));
      return b;
    }

    testWidgets('mesajlar ve ekip yanıtı görünür; yanıt yazıp gönder POST /messages {text}', (tester) async {
      final b = await open(tester);
      expect(find.textContaining('Giriş yapamıyorum'), findsOneWidget);
      expect(find.textContaining('Yardımcı olalım.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '  Teşekkürler  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Gönder'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('POST /support/tickets/5/messages'), 1);
      expect((b.bodies['POST /support/tickets/5/messages'] as Map)['text'], 'Teşekkürler', reason: 'kırpılmış metin');
      await unmount(tester);
    });

    testWidgets('boş yanıt istek atmaz', (tester) async {
      final b = await open(tester);
      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.pump();
      await tester.tap(find.byTooltip('Gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('POST /support/tickets/5/messages'), 0);
      await unmount(tester);
    });

    testWidgets('yanıt 500 verirse metin korunur, hata iletisi çıkar, istisna yok', (tester) async {
      final b = await open(tester);
      b.fail('/support/tickets/5/messages', status: 500, code: 'SERVER_ERROR', message: 'Sunucu hatası');
      await tester.enterText(find.byType(TextField).last, 'Tekrar deneme');
      await tester.pump();
      await tester.tap(find.byTooltip('Gönder'));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Tekrar deneme');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('kapalı talepte yazma çubuğu yok', (tester) async {
      await open(tester, status: 'CLOSED');
      expect(find.byType(TextField), findsNothing);
      await unmount(tester);
    });

    testWidgets('2000 sınırı: 2001. karakter alana girmez', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).last, 'a' * 2100);
      expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text.length, 2000);
      await unmount(tester);
    });
  });

  group('öneri panosu oyu', () {
    Map<String, dynamic> board() => {
          'items': [
            {'id': 1, 'subject': 'Kütüphane saatleri', 'message': 'Uzatılsın', 'status': 'APPROVED', 'adminResponse': null, 'voteCount': 3, 'votedByMe': false, 'createdAt': '2026-11-01T10:00:00Z'},
          ],
          'page': 0,
          'totalPages': 1,
          'totalItems': 1,
        };

    Future<FakeBackend> open(WidgetTester tester) async {
      final b = FakeBackend();
      b.on('/suggestions*', board());
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SuggestionsPage(session: makeSession(b))));
      await settle(tester, const Duration(seconds: 1));
      return b;
    }

    testWidgets('oy iyimser artar, PUT gider; tekrar dokununca DELETE ile geri alınır', (tester) async {
      final b = await open(tester);
      expect(find.text('3'), findsWidgets);
      await tester.tap(find.byType(VotePill).first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('PUT /suggestions/1/vote'), 1);
      expect(find.text('4'), findsWidgets);
      await tester.tap(find.byType(VotePill).first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('DELETE /suggestions/1/vote'), 1);
      expect(find.text('3'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('oy hatası (429) iyimser artışı geri alır', (tester) async {
      final b = await open(tester);
      b.fail('/suggestions/1/vote', status: 429, code: 'RATE_LIMITED', message: 'Çok sık');
      await tester.tap(find.byType(VotePill).first);
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('form doğrulamaları', () {
    testWidgets('yeni talep: 3 karakterden kısa konu ve boş mesaj hata verir, istek atmaz', (tester) async {
      final b = FakeBackend();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewTicketPage(session: makeSession(b))));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.pump();
      final btn = find.widgetWithText(BuButton, 'Gönder');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Konu en az 3 karakter olmalı.'), findsOneWidget);
      expect(b.count('POST /support/tickets'), 0);
      await unmount(tester);
    });

    testWidgets('yeni talep başarı: gövde {category, subject, message} + sayfa kapanır', (tester) async {
      final b = FakeBackend();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<bool>(builder: (_) => NewTicketPage(session: makeSession(b)))),
          child: const Text('ac'),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).at(0), '  Giriş sorunu  ');
      await tester.enterText(find.byType(TextField).at(1), ' Mesajım ');
      await tester.pump();
      final btn = find.widgetWithText(BuButton, 'Gönder');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester, const Duration(seconds: 1));
      final sent = b.bodies['POST /support/tickets'] as Map;
      expect(sent['subject'], 'Giriş sorunu');
      expect(sent['message'], 'Mesajım');
      expect(sent['category'], isNotNull);
      expect(find.byType(NewTicketPage), findsNothing, reason: 'başarıda ekran kapanır');
      await unmount(tester);
    });

    testWidgets('geri bildirim: boş alanlarda uyarı, istek yok', (tester) async {
      final b = FakeBackend();
      b.on('/feedback/mine*', {'items': [], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(FeedbackPage(session: makeSession(b))));
      await settle(tester);
      final btn = find.widgetWithText(BuButton, 'Gönder');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Konu ve mesaj alanlarını doldurun.'), findsOneWidget);
      expect(b.count('POST /feedback'), 0);
      await unmount(tester);
    });

    testWidgets('geri bildirim başarı: gövde kategori/konu/mesaj/platform/appVersion taşır', (tester) async {
      final b = FakeBackend();
      b.on('/feedback/mine*', {'items': [], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(FeedbackPage(session: makeSession(b))));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Hata var');
      await tester.enterText(find.byType(TextField).at(1), 'Ayrıntı');
      await tester.pump();
      final btn = find.widgetWithText(BuButton, 'Gönder');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester, const Duration(seconds: 1));
      final sent = b.bodies['POST /feedback'] as Map;
      expect(sent['subject'], 'Hata var');
      expect(sent['message'], 'Ayrıntı');
      expect(sent['category'], 'BUG');
      expect(sent['appVersion'], isNotEmpty);
      await unmount(tester);
    });
  });
}
