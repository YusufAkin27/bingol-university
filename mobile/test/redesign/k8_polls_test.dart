import 'package:bu_kampus/features/polls/anket_flat.dart';
import 'package:bu_kampus/features/polls/poll_club_section.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K8 (Anket liste/olusturma/detay, tasarim 31-32): tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390) ve davranis.

FakeBackend _closedBackend() {
  final b = FakeBackend();
  final f = fakePolls(b, count: 0);
  f.polls.add(samplePoll(id: 1, title: 'Kapanan oylama ' * 4, closed: true, optionCount: 4));
  f.polls.add(samplePoll(id: 2, title: 'Puanlama', type: 'RATING', closed: true, communityId: null, communityName: null)..['average'] = 2.4);
  f.polls.add(samplePoll(id: 3, title: 'Oy verilmis acik', myOptionIds: [301]));
  f.others[1] = {101: 14, 102: 9, 103: 4, 104: 1};
  f.others[2] = {201: 3, 202: 4, 203: 5, 204: 6, 205: 7};
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  group('K8 tasma matrisi', () {
    testWidgets('kapanan liste (sonuc ozeti)', (t) async {
      await p00Matrix(t, () => PollListPage(session: makeSession(_closedBackend())),
          scaffold: false,
          settleMs: 800,
          check: (t, l, d, s) async {
            await t.tap(find.descendant(of: find.byType(AnketTextTabs), matching: find.byType(GestureDetector)).last);
            await t.pump(const Duration(milliseconds: 600));
          });
    });

    testWidgets('form (hata kutusu ile)', (t) async {
      await p00Matrix(t, () {
        final b = FakeBackend();
        fakePolls(b, count: 0);
        return PollFormPage(session: makeSession(b), communityId: 5);
      }, scaffold: false, settleMs: 500);
    });

    testWidgets('kulup bolumu: bos ve dolu', (t) async {
      for (final empty in [true, false]) {
        await p00Matrix(t, () {
          final b = FakeBackend();
          final f = fakePolls(b, count: 0);
          if (!empty) f.polls.add(samplePoll(id: 1, title: 'Kulup anketi ' * 5, anonymous: true));
          return SingleChildScrollView(child: PollClubSection(session: makeSession(b), communityId: 5, canCreate: true));
        }, scaffold: true, settleMs: 700);
      }
    });

    testWidgets('oy degistirme modu', (t) async {
      await p00Matrix(t, () {
        final b = FakeBackend();
        fakePolls(b, count: 0).polls.add(samplePoll(id: 1, anonymous: true, myOptionIds: [101], title: 'Uzun baslik ' * 6));
        return PollDetailPage(session: makeSession(b), pollId: 1);
      }, scaffold: false, settleMs: 700);
    });
  });

  group('K8 davranis', () {
    testWidgets('liste: acik anketler kartsiz satir; "+ Yeni" yalniz kulup listesinde ve yetkiliyken', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 3);
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.byType(PollCard), findsNWidgets(3));
      expect(find.byTooltip('Anket oluştur'), findsNothing);
      await unmount(t);

      await t.pumpWidget(p00App(PollListPage(session: makeSession(b), communityId: 5, canCreate: true), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.bySemanticsLabel('Anket oluştur'), findsOneWidget);
      await unmount(t);

      await t.pumpWidget(p00App(PollListPage(session: makeSession(b), communityId: 5), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.bySemanticsLabel('Anket oluştur'), findsNothing);
      await unmount(t);
    });

    testWidgets('liste: hata seridi + yeniden dene', (t) async {
      final b = FakeBackend()..fail('/polls*');
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('satir: oy verilmis -> "Oy verdiniz" (yesil); kapali sekme -> "Sona erdi" meta, kartsiz', (t) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 0);
      f.polls
        ..add(samplePoll(id: 1, title: 'A'))
        ..add(samplePoll(id: 2, title: 'B', myOptionIds: [201]));
      await t.pumpWidget(p00App(PollListPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Oy ver'), findsNothing); // Stitch v3: satirda eylem dugmesi yok, satir dokunulur
      expect(find.text('Oy verdiniz'), findsOneWidget);
      await unmount(t);

      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollListPage(session: makeSession(_closedBackend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      await t.tap(find.text('Kapanan'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.byType(PollCard), findsNWidgets(2));
      expect(find.textContaining('Sona erdi'), findsNWidgets(2));
      expect(find.text('Katıldıklarım'), findsOneWidget); // yalniz sekme (alt blok kalkti)
      await unmount(t);
    });

    testWidgets('detay: oy degistir -> "Onceki seciminiz" rozeti, Oyu guncelle + Vazgec', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 0).polls.add(samplePoll(id: 1, anonymous: true, myOptionIds: [101]));
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.textContaining('Gizli oy'), findsOneWidget); // meta satiri
      await t.tap(find.text('Oyu değiştir'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Önceki seçiminiz'), findsOneWidget);
      expect(find.text('Oyu güncelle'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Oyu güncelle'), findsNothing);
      await unmount(t);
    });

    testWidgets('detay: coklu secim sayaci ve siralama rozetleri', (t) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 0);
      f.polls
        ..add(samplePoll(id: 1, type: 'MULTI', maxChoices: 2, optionCount: 3))
        ..add(samplePoll(id: 2, type: 'RANKED', optionCount: 3));
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('0 / 2 seçildi'), findsOneWidget);
      await t.tap(find.text('Seçenek 1'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('1 / 2 seçildi'), findsOneWidget);
      await unmount(t);

      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 2), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      await t.tap(find.text('Seçenek 3'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('1. Tercih'), findsOneWidget);
      expect(find.text('Seçmek için dokunun'), findsNWidgets(2));
      await unmount(t);
    });

    testWidgets('detay: coklu secimde gizlilik meta hapinda (kutu yok), sonuclar kapaninca notu', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 0).polls.add(samplePoll(id: 1, type: 'MULTI', maxChoices: 2, anonymous: true, showResults: 'AFTER_CLOSE'));
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.textContaining('Gizli oy'), findsOneWidget); // meta satirinda
      expect(find.textContaining('Kimliğiniz hiçbir yönetici'), findsNothing);
      expect(find.text('Sonuçlar anket kapanınca görünecek.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('detay: katilim oy sayisindan az uygun secmenle "343 / 40" yazmaz', (t) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 0);
      f.polls.add(samplePoll(id: 1, anonymous: true, myOptionIds: [101]));
      f.others[1] = {101: 30, 102: 20};
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollDetailPage(session: makeSession(b), pollId: 1), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.textContaining(' / 40 katılım'), findsNothing);
      await unmount(t);
    });

    testWidgets('form: gizli oy varsayilan ACIK, govdeye anonymous=true gider', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      t.view.physicalSize = const Size(390, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollFormPage(session: makeSession(b), communityId: 5), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField).first, 'Gun secimi');
      await t.enterText(find.byType(TextField).at(2), 'Pazartesi');
      await t.enterText(find.byType(TextField).at(3), 'Sali');
      await t.pump();
      await t.tap(find.text('Yayınla'));
      await settle(t, const Duration(milliseconds: 700));
      expect((b.bodies['POST /polls'] as Map)['anonymous'], true);
      await unmount(t);
    });

    testWidgets('form: tek form, 4 tur karti, sure dugmeleri, hata kutusu', (t) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      t.view.physicalSize = const Size(390, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(p00App(PollFormPage(session: makeSession(b), communityId: 5), scaffold: false));
      await settle(t, const Duration(milliseconds: 700));
      for (final s in ['Tek seçim', 'Çoklu', 'Puanlama', 'Sıralı', '1 gün', '3 gün', '7 gün', 'Her zaman', 'Oy verince', 'Anket kapanınca', 'Gizli oy', 'Bildirim gönder']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('2 / 12'), findsOneWidget);
      await t.tap(find.text('Yayınla'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Başlık gerekli.'), findsOneWidget);
      expect(b.count('POST /polls'), 0);
      await unmount(t);
    });
  });
}
