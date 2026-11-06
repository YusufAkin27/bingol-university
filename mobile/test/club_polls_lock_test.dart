import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_club_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Kulüp anketleri: üye değilken sunucu 403 POLL_NOT_ELIGIBLE döner. Üye olmayana HİÇ istek atılmaz, kilit gösterilir.
Widget _section(FakeBackend b,
        {ClubPollAccess access = ClubPollAccess.member, bool canCreate = false, bool approval = false, VoidCallback? onJoin, bool hide = false}) =>
    SingleChildScrollView(
      child: PollClubSection(
        session: makeSession(b),
        communityId: 5,
        canCreate: canCreate,
        access: access,
        needsApproval: approval,
        onJoin: onJoin,
        hideWhenEmpty: hide,
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w, {Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(Scaffold(body: w), size: size));
  await settle(tester, const Duration(milliseconds: 800));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('uye degil: istek atilmaz, kilit + Katil dugmesi onJoin cagirir', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 3);
    var joined = 0;
    await _pump(tester, _section(b, access: ClubPollAccess.none, onJoin: () => joined++));
    expect(b.count('/polls'), 0, reason: 'uye olmayana anket istegi atilmaz');
    expect(find.byKey(const ValueKey('pollLocked')), findsOneWidget);
    expect(find.text('Anketleri görmek için kulübe katıl'), findsOneWidget);
    expect(find.text('Kulüp anketleri yalnızca üyelere açıktır.'), findsOneWidget);
    expect(find.text('Anket 1'), findsNothing);
    expect(find.text('Yüklenemedi, tekrar dene'), findsNothing);
    expect(find.text('Katıl'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('pollLockedJoin'))).height, greaterThanOrEqualTo(40));
    await tester.tap(find.byKey(const ValueKey('pollLockedJoin')));
    await tester.pump();
    expect(joined, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uye degil + katilim onayli kulup: "Katilma istegi gonder"', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 1);
    await _pump(tester, _section(b, access: ClubPollAccess.none, approval: true, onJoin: () {}));
    expect(find.text('İstek gönder'), findsOneWidget);
    expect(find.textContaining('onaylanınca burada görünür'), findsOneWidget);
    expect(b.count('/polls'), 0);
  });

  testWidgets('istek beklemede: kilit "onay bekliyor", dugme yok, istek yok', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 1);
    await _pump(tester, _section(b, access: ClubPollAccess.pending, onJoin: () {}));
    expect(find.text('Üyelik isteğin onay bekliyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollLockedJoin')), findsNothing);
    expect(b.count('/polls'), 0);
  });

  testWidgets('uye + anket var: liste, kilit yok', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 2);
    await _pump(tester, _section(b));
    expect(b.count('scope=community%3A5'), 1);
    expect(find.text('Anket 1'), findsOneWidget);
    expect(find.text('Anket 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollLocked')), findsNothing);
  });

  testWidgets('uye + anket yok: "Henuz anket yok"; yonetici degilse olusturma yok, yoneticide var', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 0);
    await _pump(tester, _section(b));
    expect(find.byKey(const ValueKey('pollEmpty')), findsOneWidget);
    expect(find.text('Henüz anket yok.'), findsOneWidget);
    expect(find.text('Anket oluştur'), findsNothing);
    await _pump(tester, _section(b, canCreate: true));
    expect(find.text('Henüz anket yok.'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollEmptyCreate')), findsOneWidget);
    expect(find.text('Anket oluştur'), findsOneWidget);
  });

  testWidgets('uye iken 403 POLL_NOT_ELIGIBLE: hata degil, kilit (katil dugmesi yok)', (tester) async {
    final b = FakeBackend()
      ..fail('/polls*', status: 403, code: 'POLL_NOT_ELIGIBLE', message: 'Bu ankete katılma hakkınız yok.');
    await _pump(tester, _section(b, onJoin: () {}));
    expect(find.byKey(const ValueKey('pollLocked')), findsOneWidget);
    expect(find.text('Yüklenemedi, tekrar dene'), findsNothing);
    expect(find.byKey(const ValueKey('pollLockedJoin')), findsNothing);
  });

  testWidgets('500: hata satiri + Yeniden dene, sonra basarili', (tester) async {
    final b = FakeBackend()..fail('/polls*', status: 500, code: 'SERVER_ERROR');
    await _pump(tester, _section(b));
    expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollLocked')), findsNothing);
    fakePolls(b, count: 1);
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.text('Anket 1'), findsOneWidget);
    expect(find.text('Yüklenemedi, tekrar dene'), findsNothing);
  });

  testWidgets('ag yok: kilit degil, hata + yeniden dene', (tester) async {
    final b = FakeBackend()..offline = true;
    await _pump(tester, _section(b));
    expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollLocked')), findsNothing);
  });

  testWidgets('uyelik degisince (didUpdateWidget) anketler o zaman istenir', (tester) async {
    final b = FakeBackend();
    fakePolls(b, count: 1);
    var access = ClubPollAccess.none;
    late StateSetter set;
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
      Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return _section(b, access: access, onJoin: () {});
        }),
      ),
      size: kPhoneMedium,
    ));
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.count('/polls'), 0);
    set(() => access = ClubPollAccess.member);
    await settle(tester, const Duration(milliseconds: 800));
    expect(b.count('/polls'), 1);
    expect(find.text('Anket 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollLocked')), findsNothing);
  });

  group('kulup detayinda (Hakkinda sekmesi)', () {
    FakeBackend be({String status = 'NONE', String? role, String policy = 'OPEN'}) {
      final b = FakeBackend()
        ..on('/communities/7', {
          'id': 7,
          'name': 'Fotoğraf Kulübü',
          'description': 'Kısa açıklama.',
          'category': 'Sanat',
          'memberCount': 128,
          'visibility': 'PUBLIC',
          'joinPolicy': policy,
          'myStatus': status,
          'myRole': role,
          'createdAt': '2019-03-12T09:00:00Z',
        })
        ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
        ..on('/communities/7/requests*', {'items': <Object>[], 'nextCursor': null})
        ..on('/communities/7/members*', {'items': <Object>[], 'nextCursor': null})
        ..on('/events*', {'items': <Object>[], 'nextCursor': null});
      if (status == 'ACTIVE') {
        fakePolls(b, count: 1).polls[0] = samplePoll(id: 1, title: 'Anket 1', communityId: 7);
      } else {
        // Sunucu davranisi: uye olmayana kulup anketleri 403.
        b.fail('/polls*', status: 403, code: 'POLL_NOT_ELIGIBLE', message: 'Bu ankete katılma hakkınız yok.');
      }
      return b;
    }

    Future<void> open(WidgetTester tester, FakeBackend b) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 7), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
    }

    testWidgets('uye degil: anket istegi YOK, "yuklenemedi" yok, kilit gorunur', (tester) async {
      final b = be();
      await open(tester, b);
      expect(b.count('/polls'), 0);
      expect(find.byKey(const ValueKey('pollLocked')), findsOneWidget);
      expect(find.text('Anketleri görmek için kulübe katıl'), findsOneWidget);
      expect(find.text('Yüklenemedi, tekrar dene'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('onayli kulup, istek bekliyor: "onay bekliyor" kilidi', (tester) async {
      final b = be(status: 'PENDING', policy: 'APPROVAL');
      await open(tester, b);
      expect(b.count('/polls'), 0);
      expect(find.text('Üyelik isteğin onay bekliyor'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('uye: anketler yuklenir', (tester) async {
      final b = be(status: 'ACTIVE', role: 'MEMBER');
      await open(tester, b);
      expect(b.count('/polls'), 1);
      expect(find.byKey(const ValueKey('pollLocked')), findsNothing);
      expect(find.text('Anket 1'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    for (final entry in <String, ClubPollAccess>{'uye degil': ClubPollAccess.none, 'bekliyor': ClubPollAccess.pending}.entries) {
      testWidgets('kilit ${entry.key}', (tester) async {
        final b = FakeBackend();
        await p00Matrix(tester, () => _section(b, access: entry.value, approval: true, onJoin: () {}), settleMs: 400);
      });
    }
    testWidgets('bos durum (yonetici)', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await p00Matrix(tester, () => _section(b, canCreate: true), settleMs: 600);
    });
  });
}
