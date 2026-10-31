import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P51 Etkinlikler Stitch v3 birebir: metin sekmeleri, duz satir, kartsiz takvim, detay/form/QR/istekler/yoklama,
/// 3 dil x acik/koyu x 1.0/1.3 x 320/390 tasma matrisi.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev(int id, String title, {String? rsvp, int going = 12, int? cap, String policy = 'OPEN'}) {
  final n = DateTime.now();
  final s = DateTime(n.year, n.month, n.day, 23, 30);
  return {
    'id': id,
    'source': 'USER',
    'title': title,
    'description': 'Açıklama metni.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(minutes: 20))),
    'location': 'Konferans Salonu',
    'communityId': 7,
    'communityName': 'Müzik Kulübü',
    'goingCount': going,
    if (cap != null) 'capacity': cap,
    'myRsvp': rsvp,
    'status': 'ACTIVE',
    'joinPolicy': policy,
    'canManage': false,
    'createdBy': 2,
  };
}

FakeBackend _listBe() => FakeBackend()
  ..on('/events/calendar*', [_ev(1, 'Akustik Dinleti'), _ev(2, 'Kariyer Günleri', rsvp: 'GOING')], headers: {'x-truncated': 'false'})
  ..on('/me/events*', {'items': [_ev(2, 'Kariyer Günleri', rsvp: 'GOING')], 'nextCursor': null})
  ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null});

FakeBackend _detailBe({String? rsvp, bool open = false, String policy = 'OPEN'}) => FakeBackend()
  ..on('/events/5', _ev(5, 'Kariyer Günleri', rsvp: rsvp, cap: 50, policy: policy))
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': open})
  ..on('/events/5/admission', {'eventId': 5, 'mode': policy, 'questions': <Object>[]});

FakeBackend _manageBe() => FakeBackend()
  ..on('/events/5/checkin-code', {'code': '482913', 'qrPayload': 'bingol-checkin:5.1.abc', 'validForSeconds': 30})
  ..on('/events/5/attendance', [
    {'userId': 1, 'displayName': 'Zeynep Kaya', 'present': true, 'method': 'QR'},
    {'userId': 3, 'displayName': 'Elif Demir', 'present': false},
  ])
  ..on('/events/5', {'id': 5, 'goingCount': 31, 'capacity': 40})
  ..on('/events/5/requests*', {
    'items': [
      {'userId': 11, 'displayName': 'Zeynep Kaya', 'department': 'Bilgisayar Mühendisliği', 'classYear': 2}
    ],
    'nextCursor': null,
  });

Map<String, dynamic> get _evMap => {'id': 5, 'title': 'Kariyer Günleri', 'communityName': 'Bilgisayar Topluluğu', 'goingCount': 31, 'capacity': 40, 'createdBy': 2};

FakeBackend _formBe({bool noClub = false}) => FakeBackend()
  ..on('/me/communities*', {
    'items': noClub
        ? <Object>[]
        : [
            {'id': 7, 'name': 'Müzik Kulübü', 'myStatus': 'ACTIVE', 'myRole': 'OWNER', 'status': 'ACTIVE', 'joinPolicy': 'OPEN', 'visibility': 'PUBLIC', 'category': 'Müzik'}
          ],
    'nextCursor': null,
  });

void main() {
  setUpAll(loadTestFonts);

  testWidgets('liste: metin sekmeleri, kartsiz takvim, duz satir + Katil/Katiliyorsun', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(EventsPage(session: makeSession(_listBe())), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.byType(ClubTextTabs), findsOneWidget);
    expect(find.byKey(const ValueKey('events-calendar')), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('Katılıyorsun'), findsOneWidget);
    expect(find.byType(ClubJoinButton), findsOneWidget);
    // Yoklama metin dugmesi + "+" duz ikon.
    expect(find.byKey(const ValueKey('events-checkin')), findsOneWidget);
    expect(find.byKey(const ValueKey('events-create')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('takvim: gun secimi satir listesini suzer, ay okuyla degisir', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(EventsPage(session: makeSession(_listBe())), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('events-calendar')), matching: find.text('${DateTime.now().day}')).first);
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('2 Etkinlik'), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki ay'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('detay: duz kapak + etiket-deger satirlari + alt cubuk (Ilgileniyorum + Katil); katildiysa yoklama notu', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(_detailBe()), eventId: 5), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    for (final s in ['Tarih', 'Saat', 'Yer', 'Katılımcı']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text('İlgileniyorum'), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('MK'), findsOneWidget); // filigran
    await unmount(tester);
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(_detailBe(rsvp: 'GOING', open: true)), eventId: 5), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.text('Yoklama açık'), findsOneWidget);
    expect(find.text('QR ile yoklama ver'), findsOneWidget);
    expect(find.text('Kodu elle gir'), findsOneWidget);
    expect(find.text('Katılımdan ayrıl'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('istekler: sekmeler (sayili), onayla/reddet metin dugmeleri, kontenjan satiri', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Etkinlik2RequestsPage(session: makeSession(_manageBe()), event: _evMap), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.text('Kontenjan 40 · 31 onaylı'), findsOneWidget);
    expect(find.text('Bekleyen 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('et2-approve-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('et2-reject-11')), findsOneWidget);
    expect(find.text('Kontenjan dolduğunda yeni istek onaylanamaz.'), findsOneWidget);
    await tester.tap(find.textContaining('Onaylanan'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('et2-approve-11')), findsNothing);
    await unmount(tester);
  });

  testWidgets('QR: kod 3-3 bosluklu, % ilerleme, Yoklama listesi dugmesi', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Etkinlik2QrPage(session: makeSession(_manageBe()), event: _evMap), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Yoklama listesi'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);
    await unmount(tester);
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('etkinlik listesi', (tester) async {
      await p00Matrix(tester, () => EventsPage(session: makeSession(_listBe())), scaffold: false, settleMs: 700);
    });
    testWidgets('etkinlik detayi', (tester) async {
      await p00Matrix(tester, () => EventDetailPage(session: makeSession(_detailBe(rsvp: 'GOING', open: true)), eventId: 5), scaffold: false, settleMs: 700);
    });
    testWidgets('etkinlik formu', (tester) async {
      await p00Matrix(tester, () => EventFormPage(session: makeSession(_formBe())), scaffold: false, settleMs: 500);
    });
    testWidgets('kulup gerekli', (tester) async {
      await p00Matrix(tester, () => EventFormPage(session: makeSession(_formBe(noClub: true))), scaffold: false, settleMs: 500);
    });
    testWidgets('yoklama QR', (tester) async {
      await p00Matrix(tester, () => Etkinlik2QrPage(session: makeSession(_manageBe()), event: _evMap), scaffold: false, settleMs: 500);
    });
    testWidgets('basvurular', (tester) async {
      await p00Matrix(tester, () => Etkinlik2RequestsPage(session: makeSession(_manageBe()), event: _evMap), scaffold: false, settleMs: 500);
    });
    testWidgets('yoklama listesi', (tester) async {
      await p00Matrix(tester, () => Etkinlik2AttendancePage(session: makeSession(_manageBe()), event: _evMap), scaffold: false, settleMs: 500);
    });
  });
}
