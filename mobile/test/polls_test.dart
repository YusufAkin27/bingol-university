import 'package:bu_kampus/features/polls/poll_club_section.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_menu_card.dart';
import 'package:bu_kampus/features/polls/poll_models.dart';
import 'package:bu_kampus/features/polls/poll_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Future<void> show(WidgetTester tester, Widget w, {Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
  await tester.pumpWidget(buildApp(w, brightness: b, size: size));
  await tester.pumpAndSettle();
}

/// Kaydırarak görünür kıl, dokun, yerleş.
Future<void> tap(WidgetTester tester, Finder f, {bool settle = true}) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('oy mantigi', () {
    test('SINGLE: yeni secim eskisini degistirir', () {
      final s = PollSelection(PollType.single);
      expect(s.canSubmit, isFalse);
      s.toggle(1);
      s.toggle(2);
      expect(s.ids, [2]);
      expect(s.canSubmit, isTrue);
      expect(s.toBody(), {'optionIds': [2]});
    });

    test('MULTI: ac/kapat ve ust sinir', () {
      final s = PollSelection(PollType.multi, maxChoices: 2);
      expect(s.toggle(3), isTrue);
      expect(s.toggle(1), isTrue);
      expect(s.toggle(2), isFalse); // sinir dolu
      expect(s.toggle(3), isTrue); // kaldir
      expect(s.ids, [1]);
      expect(s.toBody(), {'optionIds': [1]});
    });

    test('RANKED: secim sirasi korunur, rank hesaplanir', () {
      final s = PollSelection(PollType.ranked, maxChoices: 3);
      s.toggle(30);
      s.toggle(10);
      s.toggle(20);
      expect(s.toggle(40), isFalse);
      expect(s.toBody(), {'optionIds': [30, 10, 20]});
      expect(s.rankOf(10), 2);
      s.toggle(30);
      expect(s.rankOf(10), 1);
      expect(s.rankOf(30), isNull);
    });

    test('RATING: 1-5 araliginda', () {
      final s = PollSelection(PollType.rating);
      expect(s.canSubmit, isFalse);
      s.setRating(9);
      expect(s.rating, 5);
      s.setRating(0);
      expect(s.rating, 1);
      expect(s.toBody(), {'rating': 1});
    });

    test('Poll.fromJson bos/null cokmez', () {
      final z = Poll.fromJson(null);
      expect(z.id, 0);
      expect(z.options, isEmpty);
      expect(z.voted, isFalse);
      expect(z.canVote, isTrue);
      expect(z.showResults(), isFalse);
      expect(Poll.fromJson({'status': 'CLOSED'}).isClosed(), isTrue);
      expect(Poll.fromJson({'status': 'CANCELLED'}).isClosed(), isTrue);
      expect(Poll.fromJson({'closesAt': '2000-01-01T00:00:00Z'}).isClosed(), isTrue);
    });

    test('Poll.fromJson sozlesme alanlari', () {
      final p = Poll.fromJson({
        'id': 5,
        'type': 'RANKED',
        'scope': 'COMMUNITY',
        'options': [
          {'id': 31, 'text': 'A', 'position': 1},
          {'id': 32, 'text': 'B', 'position': 2},
        ],
        'allowChangeVote': false,
        'state': 'SCHEDULED',
        'canVote': false,
        'voteBlockedReason': 'NOT_OPEN',
        'myVote': {'optionIds': [32, 31], 'rating': null},
        'resultsVisible': true,
        'results': [
          {'optionId': 31, 'count': 14, 'percent': 56.0, 'score': 30},
        ],
        'totalVotes': 25,
        'turnout': {'voted': 25, 'eligible': 140, 'percent': 17.9},
      });
      expect(p.type, PollType.ranked);
      expect(p.voted, isTrue);
      expect(p.myOptionIds, [32, 31]);
      expect(p.allowChangeVote, isFalse);
      expect(p.notOpenYet, isTrue);
      expect(p.countOf(p.options[0]), 14);
      expect(p.percentOf(p.options[0]), 56);
      expect(p.percentOf(p.options[1]), 0);
      expect(p.resultOf(p.options[0])!.score, 30);
      expect(p.turnoutEligible, 140);
      expect(p.participants, 25);
      expect(pollBlockedText('ALREADY_VOTED'), contains('değiştirilemez'));
    });

    test('pollIstanbulIso: +03:00 duvar saati', () {
      expect(pollIstanbulIso(DateTime.utc(2026, 11, 5, 15, 0)), '2026-11-05T18:00:00+03:00');
      expect(pollIstanbulIso(DateTime.utc(2026, 11, 5, 22, 30)), '2026-11-06T01:30:00+03:00');
    });

    test('pollRemaining', () {
      final now = DateTime.utc(2026, 10, 27, 12);
      expect(pollRemaining(null, now), isNull);
      expect(pollRemaining('2026-10-27T11:00:00Z', now), 'Sona erdi');
      expect(pollRemaining('2026-10-30T13:00:00Z', now), '3 gün kaldı');
      expect(pollRemaining('2026-10-27T17:00:00Z', now), '5 sa kaldı');
      expect(pollRemaining('2026-10-27T12:12:00Z', now), '12 dk kaldı');
    });

    test('validatePollDraft', () {
      final now = DateTime(2026, 10, 27);
      final ok = now.add(const Duration(days: 1));
      String? v(String t, List<String> o, DateTime? c, [PollType ty = PollType.single]) =>
          validatePollDraft(title: t, type: ty, options: o, closesAt: c, now: now);
      expect(v('', ['a', 'b'], ok), isNotNull);
      expect(v('T', ['a', ''], ok), contains('2 seçenek'));
      expect(v('T', ['a', 'A'], ok), contains('farklı'));
      expect(v('T', [for (var i = 0; i < 13; i++) 'x$i'], ok), contains('12'));
      expect(v('T', ['a', 'b'], null), isNotNull);
      expect(v('T', ['a', 'b'], now.subtract(const Duration(hours: 1))), contains('gelecekte'));
      expect(v('T', ['a', 'b'], ok), isNull);
      expect(v('T', const [], ok, PollType.rating), isNull);
    });
  });

  group('liste', () {
    testWidgets('acik anketler, sekme gecisi, bos durum', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 2);
      f.polls.add(samplePoll(id: 9, title: 'Eski anket', closed: true));
      await show(tester, PollListPage(session: makeSession(b)));
      expect(find.text('Anket 1'), findsOneWidget);
      expect(find.text('Anket 2'), findsOneWidget);
      expect(find.text('Eski anket'), findsNothing);
      await tap(tester, find.text('Kapanan'));
      expect(find.text('Eski anket'), findsOneWidget);
      await tap(tester, find.text('Katıldıklarım'));
      expect(find.text('Henüz bir ankete katılmadınız.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('imecli sayfalama', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 30)..pageSize = 10;
      await show(tester, PollListPage(session: makeSession(b)));
      expect(b.count('cursor='), 0);
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(b.count('cursor='), 1);
      expect(f.polls.length, 30);
      noErr(tester);
    });

    testWidgets('hata -> yeniden dene', (tester) async {
      final b = FakeBackend()..fail('/polls*', status: 500);
      await show(tester, PollListPage(session: makeSession(b)));
      expect(find.text('Yeniden dene'), findsOneWidget);
      b.reset('/polls*');
      fakePolls(b, count: 1);
      await tap(tester, find.text('Yeniden dene'));
      expect(find.text('Anket 1'), findsOneWidget);
    });

    for (final size in kPhoneSizes) {
      for (final br in Brightness.values) {
        testWidgets('tasma yok ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          final f = fakePolls(b, count: 1);
          f.polls[0] = samplePoll(
              id: 1,
              title: 'Cok uzun bir anket basligi ' * 4,
              anonymous: true,
              myOptionIds: [101],
              communityName: 'Cok uzun bir kulup adi ' * 3);
          await show(tester, PollListPage(session: makeSession(b)), size: size, b: br);
          expect(find.byType(PollCard), findsOneWidget);
          noErr(tester);
        });
      }
    }
  });

  group('detay', () {
    testWidgets('SINGLE: sec, oy ver, sonuclar gorunur, geri cek', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 1);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Oy ver'), findsOneWidget);
      // Secim yokken buton pasif.
      await tap(tester, find.text('Oy ver'), settle: false);
      expect(b.count('POST /polls/1/vote'), 0);
      await tap(tester, find.text('Seçenek 2'), settle: false);
      await tap(tester, find.text('Oy ver'));
      expect(b.bodies['POST /polls/1/vote'], {'optionIds': [102]});
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Oyu değiştir'), findsOneWidget);
      expect(find.text('Oyu geri çek'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6)); // bildirim şeridi düğmeyi örtmesin
      await tester.pumpAndSettle();
      await tap(tester, find.text('Oyu geri çek'));
      await tap(tester, find.text('Geri çek').last);
      expect(b.count('DELETE /polls/1/vote'), 1);
      expect(find.text('Oy ver'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('oyu degistir', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, myOptionIds: [101]);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Oy ver'), findsNothing);
      await tap(tester, find.text('Oyu değiştir'));
      await tap(tester, find.text('Seçenek 3'), settle: false);
      await tap(tester, find.text('Oyu güncelle'));
      expect(b.bodies['POST /polls/1/vote'], {'optionIds': [103]});
      noErr(tester);
    });

    testWidgets('MULTI ust sinir uyarisi', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, type: 'MULTI', maxChoices: 1);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      await tap(tester, find.text('Seçenek 1'), settle: false);
      await tap(tester, find.text('Seçenek 2'), settle: false);
      expect(find.text('En fazla 1 seçenek işaretleyebilirsiniz.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('RATING: yildiz ver', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, type: 'RATING');
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      await tap(tester, find.bySemanticsLabel('4 yıldız'), settle: false);
      await tap(tester, find.text('Oy ver'));
      expect(b.bodies['POST /polls/1/vote'], {'rating': 4});
      expect(find.text('Puanınız: 4'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('RANKED: tercih sirasi gonderilir', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, type: 'RANKED');
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      await tap(tester, find.text('Seçenek 3'), settle: false);
      await tap(tester, find.text('Seçenek 1'), settle: false);
      await tap(tester, find.text('Oy ver'));
      expect(b.bodies['POST /polls/1/vote'], {'optionIds': [103, 101]});
      noErr(tester);
    });

    testWidgets('AFTER_CLOSE: oydan sonra sonuc gizli, bilgi notu', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, showResults: 'AFTER_CLOSE', myOptionIds: [101]);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.byType(ResultBar), findsNothing);
      expect(find.text('Sonuçlar anket kapanınca görünecek.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('degisiklik kapali: oy degistir/geri cek yok', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(
          id: 1, allowChangeVote: false, canVote: false, voteBlockedReason: 'ALREADY_VOTED', myOptionIds: [101]);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Oyu değiştir'), findsNothing);
      expect(find.text('Oyu geri çek'), findsNothing);
      expect(find.textContaining('değiştirilemez'), findsOneWidget);
      expect(find.byType(ResultBar), findsNWidgets(3));
    });

    testWidgets('henuz acilmadi', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, state: 'SCHEDULED', canVote: false, voteBlockedReason: 'NOT_OPEN');
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Bu anket henüz açılmadı.'), findsOneWidget);
      expect(find.text('Oy ver'), findsNothing);
    });

    testWidgets('gizli oy etiketi', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, anonymous: true);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Oyunuz gizlidir'), findsOneWidget);
    });

    testWidgets('kapali: secim yok, sonuclar var', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, closed: true);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Bu anket kapandı. Oy verilemez.'), findsOneWidget);
      expect(find.text('Oy ver'), findsNothing);
      expect(find.byType(ResultBar), findsNWidgets(3));
    });

    testWidgets('yetkisiz', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1);
      f.polls[0] = samplePoll(id: 1, canVote: false, voteBlockedReason: 'NOT_ELIGIBLE');
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Bu ankete katılma yetkiniz yok.'), findsOneWidget);
      expect(find.text('Oy ver'), findsNothing);
    });

    testWidgets('POLL_CLOSED hatasi: bildirim + yeniden yukleme', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 1)..voteError = 'POLL_CLOSED';
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      await tap(tester, find.text('Seçenek 1'), settle: false);
      final before = b.count('GET /polls/1');
      await tap(tester, find.text('Oy ver'));
      expect(find.text('Bu anket kapandı.'), findsOneWidget); // yerel yedek metin
      expect(b.count('GET /polls/1'), before + 1);
      expect(f.voteError, 'POLL_CLOSED');
      noErr(tester);
    });

    testWidgets('POLL_ALREADY_VOTED ve NOT_ELIGIBLE metinleri', (tester) async {
      for (final code in ['POLL_ALREADY_VOTED', 'POLL_NOT_ELIGIBLE']) {
        final b = FakeBackend();
        fakePolls(b, count: 1).voteError = code;
        await show(tester, PollDetailPage(key: ValueKey(code), session: makeSession(b), pollId: 1));
        await tap(tester, find.text('Seçenek 1'), settle: false);
        await tap(tester, find.text('Oy ver'));
        expect(
            find.text(code == 'POLL_ALREADY_VOTED' ? 'Bu ankete zaten oy verdiniz.' : 'Bu ankete katılma yetkiniz yok.'),
            findsWidgets);
        noErr(tester);
      }
    });

    testWidgets('yuklenemedi -> yeniden dene', (tester) async {
      final b = FakeBackend()..fail('/polls/1', status: 500);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1));
      expect(find.text('Yeniden dene'), findsOneWidget);
    });

    for (final size in kPhoneSizes) {
      for (final br in Brightness.values) {
        testWidgets('tasma yok ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          final f = fakePolls(b, count: 1);
          f.polls[0] = samplePoll(id: 1, title: 'Uzun baslik ' * 10, type: 'MULTI', anonymous: true, optionCount: 8);
          await show(tester, PollDetailPage(session: makeSession(b), pollId: 1), size: size, b: br);
          expect(find.text('Oyunuz gizlidir'), findsOneWidget);
          noErr(tester);
        });
      }
    }
  });

  group('menu karti', () {
    testWidgets('204 -> gizli', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await show(tester, Scaffold(body: PollMenuCard(session: makeSession(b))));
      expect(find.text('Bugünün menüsünü puanla'), findsNothing);
      noErr(tester);
    });

    testWidgets('hata -> gizli', (tester) async {
      final b = FakeBackend()..fail('/polls/menu/today', status: 500);
      await show(tester, Scaffold(body: PollMenuCard(session: makeSession(b))));
      expect(find.text('Bugünün menüsünü puanla'), findsNothing);
    });

    testWidgets('puanla', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 0);
      f.menuPoll = samplePoll(id: 77, type: 'RATING', title: 'Menü', communityName: null, communityId: null);
      await show(tester, Scaffold(body: PollMenuCard(session: makeSession(b))));
      expect(find.text('Bugünün menüsünü puanla'), findsOneWidget);
      await tap(tester, find.bySemanticsLabel('5 yıldız'));
      expect(b.bodies['POST /polls/77/vote'], {'rating': 5});
      expect(find.textContaining('Puanınız: 5'), findsOneWidget);
      noErr(tester);
    });
  });

  group('kulup bolumu ve form', () {
    testWidgets('yonetici degil: olusturma gizli', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 1);
      await show(tester,
          Scaffold(body: SingleChildScrollView(child: PollClubSection(session: makeSession(b), communityId: 5, canCreate: false))));
      expect(find.text('Anket 1'), findsOneWidget);
      expect(find.text('Anket oluştur'), findsNothing);
    });

    testWidgets('yonetici: olusturma gorunur, bos durum', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await show(tester,
          Scaffold(body: SingleChildScrollView(child: PollClubSection(session: makeSession(b), communityId: 5, canCreate: true))));
      expect(find.text('Anket oluştur'), findsOneWidget);
      expect(find.text('Bu kulübün anketi yok.'), findsOneWidget);
    });

    testWidgets('form dogrulama ve gonderim', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, PollFormPage(session: makeSession(b), communityId: 5), size: const Size(390, 4000));
      await tap(tester, find.text('Yayınla'), settle: false);
      expect(find.text('Başlık gerekli.'), findsOneWidget);
      expect(b.count('POST /polls'), 0);
      await tester.enterText(find.byType(TextField).first, 'Başkan seçimi');
      await tester.enterText(find.byType(TextField).at(2), 'Ali');
      await tester.pump();
      await tap(tester, find.text('Yayınla'), settle: false);
      expect(find.textContaining('2 seçenek'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('form: secenek ekle/sil sinir 12', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, PollFormPage(session: makeSession(b), communityId: 5), size: const Size(320, 4000));
      for (var i = 0; i < 10; i++) {
        await tester.ensureVisible(find.text('Seçenek ekle'));
        await tap(tester, find.text('Seçenek ekle'), settle: false);
      }
      expect(find.text('Seçenek ekle'), findsNothing);
      expect(find.byTooltip('Seçeneği sil'), findsNWidgets(12));
      noErr(tester);
    });
  });
}
