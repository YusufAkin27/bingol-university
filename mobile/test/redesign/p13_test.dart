import 'package:bu_kampus/features/polls/anket_art.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_menu_card.dart';
import 'package:bu_kampus/features/polls/poll_models.dart';
import 'package:bu_kampus/features/polls/poll_parts.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Paket 13 (Anketler ve Destek): 3 dil x acik/koyu x yazi 1.0/1.3 x 320/390 dp'de tasma, durumlar, etkilesim, erisilebilirlik.

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

FakeBackend _pollBackend({int extra = 0}) {
  final b = FakeBackend();
  final f = fakePolls(b, count: 0);
  f.polls
    ..add(samplePoll(id: 1, title: 'Yeni dönem kulüp başkanı kim olsun? ' * 3, anonymous: true, communityName: 'Çok uzun adlı bir robotik ve yapay zekâ kulübü'))
    ..add(samplePoll(id: 2, title: 'Kampüste hangi etkinlik?', communityId: null, communityName: null, myOptionIds: [201]))
    ..add(samplePoll(id: 3, title: 'Yemek', type: 'RATING', communityId: null, communityName: null))
    ..add(samplePoll(id: 9, title: 'Eski anket', closed: true));
  for (var i = 0; i < extra; i++) {
    f.polls.add(samplePoll(id: 20 + i));
  }
  return b;
}

FakeBackend _supportBackend() => FakeBackend()
  ..on('/faq', [
    {
      'category': 'Hesap',
      'items': [
        {'question': 'Şifremi nasıl değiştiririm? ' * 2, 'answer': 'Ayarlar sayfasından. ' * 6},
        {'question': 'Hesabımı nasıl silerim?', 'answer': 'Ayarlar > Gizlilik.'},
      ],
    },
    {
      'category': 'Yemek',
      'items': [
        {'question': 'Menü ne zaman güncellenir?', 'answer': 'Ayda bir.'},
      ],
    },
  ])
  ..on('/support/tickets', _page([
    {'id': 5, 'subject': 'Bildirim gelmiyor ' * 4, 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-01T10:00:00'},
    {'id': 6, 'subject': 'Giriş', 'status': 'OPEN', 'category': 'ACCOUNT', 'createdAt': '2026-10-02T10:00:00'},
    {'id': 7, 'subject': 'Eksik liste', 'status': 'CLOSED', 'category': 'CONTENT', 'createdAt': '2026-10-03T10:00:00'},
  ]))
  ..on('/support/tickets/5', {
    'ticket': {'id': 5, 'subject': 'Bildirim gelmiyor ' * 4, 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-01T10:00:00'},
    'messages': [
      {'id': 1, 'text': 'Merhaba ' * 25, 'fromStaff': false, 'createdAt': '2026-10-01T10:00:00'},
      {'id': 2, 'text': 'Yardımcı olalım. ' * 8, 'fromStaff': true, 'createdAt': '2026-10-01T11:00:00'},
    ],
  })
  ..on('/feedback/mine', _page([
    {'id': 1, 'subject': 'Hata ' * 8, 'message': 'Uygulama çöküyor. ' * 10, 'category': 'BUG', 'status': 'IN_REVIEW', 'createdAt': '2026-10-01T10:00:00', 'adminResponse': 'Teşekkürler, inceleniyor. ' * 3},
  ]))
  ..on('/suggestions', {
    'totalPages': 1,
    'items': [
      {'id': 1, 'subject': 'Alerjen bilgisi gösterilsin ' * 3, 'message': 'Etiket ' * 30, 'status': 'PLANNED', 'voteCount': 1280, 'votedByMe': true, 'adminResponse': 'Planlandı.'},
      {'id': 2, 'subject': 'Kütüphane', 'message': 'x', 'status': 'REJECTED', 'voteCount': 94, 'votedByMe': false},
    ],
  });

void main() {
  setUpAll(loadTestFonts);

  group('P13 anketler: 3 dil x tema x olcek x genislik', () {
    testWidgets('liste', (t) async {
      await p00Matrix(t, () => PollListPage(session: makeSession(_pollBackend())),
          scaffold: false, settleMs: 700, check: (t, lang, dark, scale) async => expect(find.byType(PollCard), findsWidgets));
    });

    testWidgets('detay: tek secim, secilmis', (t) async {
      await p00Matrix(t, () {
        final b = _pollBackend();
        return PollDetailPage(session: makeSession(b), pollId: 1);
      }, scaffold: false, settleMs: 900);
    });

    testWidgets('detay: sonuclar (gizli oy notu, katilim cubugu)', (t) async {
      await p00Matrix(t, () {
        final b = FakeBackend();
        final f = fakePolls(b, count: 0);
        f.polls.add(samplePoll(id: 1, title: 'Uzun baslik ' * 8, anonymous: true, optionCount: 6, myOptionIds: [101]));
        f.others[1] = {101: 14, 102: 9, 103: 4};
        return PollDetailPage(session: makeSession(b), pollId: 1);
      }, scaffold: false, settleMs: 900, check: (t, l, d, s) async {
        // Yuzde zaten sag ustte; alt satir yalniz oy sayisi (yuzde tekrar edilmez).
        final loc = lookupAppLocalizations(Locale(l));
        final votes = RegExp('^${RegExp.escape(loc.pollVotes('0')).replaceFirst('0', r'\d+')}\$');
        expect(find.byWidgetPredicate((w) => w is Text && w.data != null && votes.hasMatch(w.data!)), findsNWidgets(6), reason: l);
        expect(find.descendant(of: find.byType(ResultBar), matching: find.textContaining(' · ')), findsNothing);
      });
    });

    testWidgets('detay: puanlama oylama ve sonuc', (t) async {
      for (final voted in [false, true]) {
        await p00Matrix(t, () {
          final b = FakeBackend();
          final f = fakePolls(b, count: 0);
          f.polls.add(samplePoll(id: 1, type: 'RATING', myRating: voted ? 4 : null, menuItems: ['Mercimek çorbası', 'Tavuk sote']));
          f.others[1] = {101: 1, 102: 2, 103: 5, 104: 12, 105: 7};
          return PollDetailPage(session: makeSession(b), pollId: 1);
        }, scaffold: false, settleMs: 900);
      }
    });

    testWidgets('detay: sirali + coklu secim', (t) async {
      for (final type in ['RANKED', 'MULTI']) {
        await p00Matrix(t, () {
          final b = FakeBackend();
          fakePolls(b, count: 0).polls.add(samplePoll(id: 1, type: type, optionCount: 8, maxChoices: 3, anonymous: true, title: 'Soru ' * 12));
          return PollDetailPage(session: makeSession(b), pollId: 1);
        }, scaffold: false, settleMs: 900);
      }
    });

    testWidgets('yemek puan karti', (t) async {
      await p00Matrix(t, () {
        final b = FakeBackend();
        fakePolls(b, count: 0).menuPoll = samplePoll(id: 77, type: 'RATING', menuItems: ['Mercimek çorbası', 'Tavuk sote', 'Pilav', 'Ayran, salata ve tatlı seçenekleri'], myRating: 3);
        return SingleChildScrollView(padding: const EdgeInsets.all(20), child: PollMenuCard(session: makeSession(b)));
      }, settleMs: 700);
    });

    testWidgets('bos durum illustrasyonlari tum turlerde ve dillerde sigar', (t) async {
      await p00Matrix(
        t,
        () => SingleChildScrollView(
          child: Column(children: [
            for (final a in AnketArt.values) AnketEmptyState(compact: true, art: a, title: 'Baslik ' * 4, message: 'Aciklama ' * 12, actionLabel: 'Eylem', onAction: () {}),
          ]),
        ),
      );
    });
  });

  group('P13 anket durumlari', () {
    testWidgets('liste: ilk yuklemede iskelet (cember yok), sonra kartlar', (t) async {
      final b = _pollBackend()..delay = const Duration(milliseconds: 400);
      t.view.physicalSize = const Size(390, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(BuSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PollCard), findsNothing);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.byType(PollCard), findsWidgets);
      expect(find.byType(BuSkeleton), findsNothing);
      await unmount(t);
    });

    testWidgets('liste: bos durum her sekmede kendi metni + aciklamasi', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Şu an açık anket yok.'), findsOneWidget); // Stitch v3: tek soluk satir (aciklama yok)
      await t.tap(find.text('Kapanan'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Kapanan anket yok.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('liste: hata -> yeniden dene -> kartlar', (t) async {
      final b = FakeBackend()..fail('/polls*');
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Yeniden dene'), findsOneWidget);
      b.reset('/polls*');
      fakePolls(b, count: 2);
      await t.tap(find.text('Yeniden dene'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(PollCard), findsNWidgets(2));
      await unmount(t);
    });

    testWidgets('detay: iskelet -> icerik; hata -> yeniden dene', (t) async {
      final b = _pollBackend()..delay = const Duration(milliseconds: 400);
      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(BuSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pump(const Duration(milliseconds: 900));
      expect(find.text('Oy ver'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('sonuc cubugu hedef yuzdeye dolar; hareket azaltilinca aninda', (t) async {
      double fillOf() => t.widget<FractionallySizedBox>(find.descendant(of: find.byType(ResultBar), matching: find.byType(FractionallySizedBox))).widthFactor!;
      await t.pumpWidget(p00App(const ResultBar(text: 'A', percent: 60, votes: 6)));
      await t.pump();
      expect(fillOf(), lessThan(.1));
      await t.pump(const Duration(milliseconds: 600));
      expect(fillOf(), closeTo(.6, .001));
      await t.pumpWidget(p00App(const ResultBar(text: 'A', percent: 60, votes: 6), disableAnimations: true));
      await t.pump();
      expect(fillOf(), closeTo(.6, .001));
    });

    test('PollCard.elapsedFraction: acilistan bitise gecen oran', () {
      final p = Poll.fromJson({'opensAt': '2026-10-01T00:00:00Z', 'closesAt': '2026-10-11T00:00:00Z'});
      expect(PollCard.elapsedFraction(p, DateTime.utc(2026, 10, 6)), closeTo(.5, .001));
      expect(PollCard.elapsedFraction(p, DateTime.utc(2026, 9, 1)), 0);
      expect(PollCard.elapsedFraction(p, DateTime.utc(2027, 1, 1)), 1);
      expect(PollCard.elapsedFraction(Poll.fromJson({'closesAt': '2026-10-11T00:00:00Z'})), isNull);
    });
  });

  group('P13 anket erisilebilirlik', () {
    for (final dark in [false, true]) {
      testWidgets('oylama ekrani: dokunma hedefi, etiket, kontrast (${dark ? 'koyu' : 'acik'})', (t) async {
        final h = t.ensureSemantics();
        final b = FakeBackend();
        fakePolls(b, count: 0).polls.add(samplePoll(id: 1, type: 'MULTI', anonymous: true, optionCount: 4, maxChoices: 2));
        await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false, dark: dark));
        await settle(t, const Duration(seconds: 2));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        await unmount(t);
        h.dispose();
      });
    }

    testWidgets('puan yildizlari: 5 etiketli, 48 dp dokunma alani', (t) async {
      final h = t.ensureSemantics();
      var v = 0;
      await t.pumpWidget(p00App(Center(child: StarRating(value: null, onChanged: (x) => v = x))));
      for (var i = 1; i <= 5; i++) {
        expect(find.bySemanticsLabel('$i yıldız'), findsOneWidget);
      }
      await t.tap(find.bySemanticsLabel('3 yıldız'));
      expect(v, 3);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    });
  });

  group('P13 destek: 3 dil x tema x olcek x genislik', () {
    testWidgets('destek ana sayfa', (t) async {
      await p00Matrix(t, () => SupportPage(session: makeSession(_supportBackend())), scaffold: false, settleMs: 700);
    });
    testWidgets('yeni talep (hata kutusu ile)', (t) async {
      await p00Matrix(t, () => NewTicketPage(session: makeSession(_supportBackend())), scaffold: false);
    });
    testWidgets('talep detayi', (t) async {
      await p00Matrix(t, () => SupportTicketPage(session: makeSession(_supportBackend()), ticketId: 5), scaffold: false, settleMs: 700);
    });
    testWidgets('geri bildirim', (t) async {
      await p00Matrix(t, () => FeedbackPage(session: makeSession(_supportBackend())), scaffold: false, settleMs: 700);
    });
    testWidgets('oneri panosu', (t) async {
      await p00Matrix(t, () => SuggestionsPage(session: makeSession(_supportBackend())), scaffold: false, settleMs: 700);
    });
  });

  group('P13 destek: etkilesim ve durumlar', () {
    testWidgets('SSS: soruya dokununca cevap acilir, tekrar dokununca kapanir', (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SupportPage(session: makeSession(_supportBackend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Ayarlar > Gizlilik.'), findsNothing);
      await t.tap(find.text('Hesabımı nasıl silerim?'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Ayarlar > Gizlilik.'), findsOneWidget);
      await t.tap(find.text('Hesabımı nasıl silerim?'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Ayarlar > Gizlilik.'), findsNothing);
      await unmount(t);
    });

    testWidgets('destek bos: SSS ve talep bos durumu, hata ikisinde de -> tam ekran hata', (t) async {
      final b = FakeBackend()
        ..on('/faq', <Object>[])
        ..on('/support/tickets', _page([]));
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SupportPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Henüz sık sorulan soru yok.'), findsOneWidget);
      expect(find.text('Henüz talebin yok.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Yeni talep'), findsOneWidget); // bos durumda tek "Yeni talep" metin dugmesi
      await unmount(t);
      final f = FakeBackend()
        ..fail('/faq')
        ..fail('/support/tickets');
      await t.pumpWidget(p00App(SupportPage(session: makeSession(f)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yeni talep: bos alanlarda hata kutusu, doluyken gonderim govdesi', (t) async {
      final b = _supportBackend();
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(NewTicketPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 500));
      await t.tap(find.text('Gönder'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Konu ve mesaj alanlarını doldurun.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);
      await t.tap(find.text('İçerik'));
      await t.enterText(find.byType(TextField).first, 'Konu');
      await t.enterText(find.byType(TextField).last, 'Mesaj metni');
      await t.pump();
      await t.tap(find.text('Gönder'));
      await settle(t, const Duration(milliseconds: 500));
      expect(b.bodies['POST /support/tickets'], {'category': 'CONTENT', 'subject': 'Konu', 'message': 'Mesaj metni'});
      await unmount(t);
    });

    testWidgets('talep: kapatma onayi (iptal edilirse istek yok, onaylanirsa kapanir)', (t) async {
      final b = _supportBackend();
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SupportTicketPage(session: makeSession(b), ticketId: 5), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      await t.tap(find.text('Talebi kapat')); // durum satirindaki soluk metin baglantisi
      await settle(t, const Duration(milliseconds: 700));
      expect(find.byType(Dialog), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await settle(t, const Duration(milliseconds: 500));
      expect(b.requests.where((r) => r.contains('/close')), isEmpty);
      await t.tap(find.text('Talebi kapat').first);
      await settle(t, const Duration(milliseconds: 700));
      await t.tap(find.text('Kapat').last);
      await settle(t, const Duration(milliseconds: 500));
      expect(b.requests.where((r) => r.contains('POST /support/tickets/5/close')), hasLength(1));
      await unmount(t);
    });

    testWidgets('talep: yanit gonderilir ve alan temizlenir', (t) async {
      final b = _supportBackend();
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SupportTicketPage(session: makeSession(b), ticketId: 5), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField), 'Teşekkürler');
      await t.tap(find.byTooltip('Gönder'));
      await settle(t, const Duration(milliseconds: 700));
      expect(b.bodies['POST /support/tickets/5/messages'], {'text': 'Teşekkürler'});
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      await unmount(t);
    });

    testWidgets('geri bildirim: sayac, dogrulama hatasi, tur secimi govdeye yansir', (t) async {
      final b = _supportBackend();
      t.view.physicalSize = const Size(390, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(FeedbackPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      await t.tap(find.text('Gönder').last);
      await settle(t, const Duration(milliseconds: 400));
      expect(find.text('Konu ve mesaj alanlarını doldurun.'), findsOneWidget);
      await t.tap(find.text('Öneri'));
      await t.enterText(find.byType(TextField).first, 'Başlık');
      await t.enterText(find.byType(TextField).last, 'Merhaba');
      await t.pump();
      expect(find.text('7 / 1000'), findsOneWidget);
      await t.tap(find.text('Gönder').last);
      await settle(t, const Duration(milliseconds: 700));
      expect((b.bodies['POST /feedback'] as Map)['category'], 'SUGGESTION');
      await unmount(t);
    });

    testWidgets('oneriler: oy ver / geri al iyimser sayar, bos durum metni', (t) async {
      final b = _supportBackend();
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(SuggestionsPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('94'), findsOneWidget);
      await t.tap(find.bySemanticsLabel(RegExp('94 oy')));
      await settle(t, const Duration(milliseconds: 500));
      // ignore: avoid_print
      print('REQ ${b.requests} TEXTS ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
      expect(find.text('95'), findsOneWidget);
      expect(b.requests, contains('PUT /suggestions/2/vote'));
      await unmount(t);

      final e = FakeBackend()..on('/suggestions', {'totalPages': 0, 'items': <Object>[]});
      await t.pumpWidget(p00App(SuggestionsPage(session: makeSession(e)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Henüz öneri yok.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('destek sayfalari ilk yuklemede iskelet gosterir (cember yok)', (t) async {
      for (final build in <Widget Function(FakeBackend)>[
        (b) => SupportPage(session: makeSession(b)),
        (b) => SupportTicketPage(session: makeSession(b), ticketId: 5),
        (b) => SuggestionsPage(session: makeSession(b)),
      ]) {
        final b = _supportBackend()..delay = const Duration(milliseconds: 300);
        await t.pumpWidget(p00App(build(b), scaffold: false));
        await t.pump(const Duration(milliseconds: 80));
        expect(find.byType(BuSkeleton), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await settle(t, const Duration(seconds: 2));
        await unmount(t);
      }
    });

    testWidgets('429 hatasi: sunucu mesaji yoksa bekleme uyarisi (BuToast)', (t) async {
      final b = _supportBackend()..fail('/support/tickets', status: 429, code: 'RATE_LIMITED');
      b.on('/support/tickets', {'code': 'RATE_LIMITED', 'message': ''}, status: 429);
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
      expect(find.textContaining('Çok fazla istek'), findsOneWidget);
      await unmount(t);
    });
  });
}
