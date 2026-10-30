import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K8 Destek (tasarim 34-35): davranis ve tasma matrisi.

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

FakeBackend _backend() => FakeBackend()
  ..on('/faq', [
    {
      'category': 'Hesap',
      'items': [
        {'question': 'Sifremi unuttum', 'answer': 'Sifirlama baglantisi.'},
      ],
    },
    {
      'category': 'Teknik',
      'items': [
        {'question': 'Uygulama acilmiyor', 'answer': 'Guncelleyin.'},
      ],
    },
  ])
  ..on('/support/tickets', _page([
    {'id': 5, 'subject': 'Giris hatasi', 'status': 'OPEN', 'category': 'ACCOUNT', 'createdAt': '2026-05-14T10:45:00'},
    {'id': 6, 'subject': 'Kapali talep', 'status': 'CLOSED', 'category': 'TECHNICAL', 'createdAt': '2026-04-28T10:45:00'},
  ]))
  ..on('/feedback/mine', _page([
    {'id': 1, 'subject': 'Hata ' * 6, 'message': 'x', 'category': 'BUG', 'status': 'PLANNED', 'createdAt': '2026-10-20T10:00:00'},
    {'id': 2, 'subject': 'Tesekkur', 'message': 'x', 'category': 'PRAISE', 'status': 'DONE', 'createdAt': '2026-10-10T10:00:00'},
  ]))
  ..on('/suggestions', {
    'totalPages': 1,
    'items': [
      {'id': 1, 'subject': 'Priz eklensin ' * 4, 'message': 'Mesaj ' * 20, 'status': 'PLANNED', 'voteCount': 128, 'votedByMe': true, 'createdAt': '2026-10-27T10:00:00'},
      {'id': 2, 'subject': 'Turnike', 'message': 'kod', 'status': 'IN_REVIEW', 'voteCount': 94, 'votedByMe': false, 'createdAt': '2026-10-26T10:00:00'},
    ],
  });

void main() {
  setUpAll(loadTestFonts);

  group('K8 destek: tasma matrisi', () {
    testWidgets('destek ana sayfa', (t) async {
      await p00Matrix(t, () => SupportPage(session: makeSession(_backend())), scaffold: false, settleMs: 700);
    });
    testWidgets('geri bildirim + oneri panosu', (t) async {
      await p00Matrix(t, () => FeedbackPage(session: makeSession(_backend())), scaffold: false, settleMs: 700);
      await p00Matrix(t, () => SuggestionsPage(session: makeSession(_backend())), scaffold: false, settleMs: 700);
    });
  });

  group('K8 destek: davranis', () {
    testWidgets('SSS kategori cipi suzer', (t) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SupportPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Sifremi unuttum'), findsOneWidget);
      expect(find.text('Uygulama acilmiyor'), findsOneWidget);
      await t.tap(find.text('Teknik'));
      await settle(t, const Duration(milliseconds: 400));
      expect(find.text('Sifremi unuttum'), findsNothing);
      expect(find.text('Uygulama acilmiyor'), findsOneWidget);
      expect(find.text('Sürüm 2.0.2'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yeni talep: varsayilan kategori Hesap (ACCOUNT)', (t) async {
      final b = _backend();
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(NewTicketPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 500));
      await t.enterText(find.byType(TextField).first, 'Konu');
      await t.enterText(find.byType(TextField).last, 'Mesaj');
      await t.pump();
      await t.tap(find.text('Gönder'));
      await settle(t, const Duration(milliseconds: 500));
      expect((b.bodies['POST /support/tickets'] as Map)['category'], 'ACCOUNT');
      await unmount(t);
    });

    testWidgets('geri bildirim: 4 tur, varsayilan Hata; gonderilenlerde durum hapi', (t) async {
      final b = _backend();
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(FeedbackPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      for (final s in ['Hata', 'Öneri', 'Şikâyet', 'Teşekkür']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Planlandı'), findsOneWidget);
      expect(find.text('Tamamlandı'), findsOneWidget);
      await t.tap(find.text('Şikâyet').first);
      await t.enterText(find.byType(TextField).first, 'B');
      await t.enterText(find.byType(TextField).at(1), 'M');
      await t.pump();
      await t.tap(find.text('Gönder'));
      await settle(t, const Duration(milliseconds: 600));
      expect((b.bodies['POST /feedback'] as Map)['category'], 'COMPLAINT');
      await unmount(t);
    });

    testWidgets('oneri panosu: siralama, ayrinti sayfasinda oy, onay notu', (t) async {
      final b = _backend();
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SuggestionsPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('En çok oy'), findsOneWidget);
      expect(find.text('Öneri ekle'), findsOneWidget);
      expect(find.text('Öneriler yönetici onayından sonra yayımlanır.'), findsOneWidget);
      await t.tap(find.text('En yeni'));
      await settle(t, const Duration(milliseconds: 500));
      expect(b.requests.any((r) => r.contains('sort=new')), isTrue);
      await t.tap(find.text('Turnike'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Oy vermek için dokun'), findsOneWidget);
      await t.tap(find.text('Oy vermek için dokun'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Oyunu kaydettin'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(b.requests, contains('PUT /suggestions/2/vote'));
      await unmount(t);
    });
  });
}
