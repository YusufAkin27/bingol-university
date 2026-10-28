import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_settings_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

const _title = 'Kampüs halı saha maçı ve yaz dönemi tanışma buluşması';

Map<String, dynamic> _ev({
  String policy = 'OPEN',
  String? rsvp,
  bool manage = false,
  int? capacity,
  int going = 9,
  int pending = 0,
  bool closed = false,
}) {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': _title,
    'description': 'Cuma akşamı 7 kişilik takımlarla maç. Su getirin.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Kampüs halı sahası',
    'goingCount': going,
    'interestedCount': 3,
    'capacity': capacity,
    'myRsvp': rsvp,
    'canManage': manage,
    'joinPolicy': policy,
    'registrationClosed': closed,
    'createdBy': 2,
    'organizer': {'id': 2, 'displayName': 'Mehmet Kaya', 'avatarUrl': null},
    'organizerName': 'Mehmet Kaya',
    'pendingCount': manage ? pending : null,
  };
}

FakeBackend _be(Map<String, dynamic> ev) => FakeBackend()
  ..on('/events/5', ev)
  ..on('/events/5/attendees/preview', {
    'goingCount': 9,
    'avatars': [
      for (var i = 0; i < 5; i++) {'displayName': 'Kişi $i'},
    ],
  })
  ..on('/events/5/attendance', [
    {'userId': 11, 'displayName': 'Ayşe Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'present': true, 'method': 'QR', 'markedAt': _iso(DateTime.now())},
    {'userId': 12, 'displayName': 'Can Demir', 'department': 'İşletme', 'present': false},
    {'userId': 2, 'displayName': 'Mehmet Kaya', 'present': true, 'method': 'MANUAL'},
  ])
  ..on('/events/5/checkin-code', {
    'code': '5.123.abcdef',
    'qrPayload': 'bingol-checkin:5.123.abcdef',
    'validForSeconds': 30,
    'expiresAt': _iso(DateTime.now().add(const Duration(seconds: 30))),
  })
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false})
  ..on('/events/5/admission', {'eventId': 5, 'mode': 'APPROVAL', 'questions': <String>[]})
  ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4});

Map<String, dynamic> _applicant(int id, String name, {String? dep, String? note}) =>
    {'id': id, 'userId': id, 'displayName': name, 'department': dep, 'note': note, 'answers': <String>[], 'status': 'PENDING'};

void _noErr(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail('$e');
}

Future<void> _pump(WidgetTester tester, Widget w,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, bool rtl = false}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    rtl ? Directionality(textDirection: TextDirection.rtl, child: w) : w,
    brightness: b,
    size: size,
  ));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  FakeBackend requestsBe({bool full = false}) {
    final be = _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14, going: full ? 14 : 9, pending: 2));
    be.on('/events/5/requests?status=PENDING&size=50', {
      'items': [
        _applicant(21, 'Ayşe Yılmaz', dep: 'Bilgisayar Mühendisliği'),
        _applicant(22, 'Can Demir', dep: 'İşletme', note: 'Takıma katılmak isterim'),
      ],
      'nextCursor': null,
    });
    be.on('/events/5/requests?status=ACCEPTED&size=50', {
      'items': [_applicant(31, 'Mert Aksoy', dep: 'Makine Mühendisliği')],
      'nextCursor': null,
    });
    be.on('/events/5/requests?status=REJECTED&size=50', {
      'items': [_applicant(32, 'Selin Doğan', dep: 'Hukuk')],
      'nextCursor': null,
    });
    return be;
  }

  // ---- görünüm matrisi: açık/koyu x 3 boyut x LTR/RTL; taşma/istisna yok ----
  final scenes = <String, (FakeBackend Function(), Widget Function(FakeBackend))>{
    'Detay herkes katilir': (() => _be(_ev(capacity: 14)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Detay katildi': (() => _be(_ev(rsvp: 'GOING', capacity: 14)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Detay istek yok': (() => _be(_ev(policy: 'APPROVAL', capacity: 14)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Detay istek gonderildi': (() => _be(_ev(policy: 'APPROVAL', rsvp: 'PENDING', capacity: 14)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Detay reddedildi': (() => _be(_ev(policy: 'APPROVAL', rsvp: 'REJECTED')), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Detay yonetici istek ile': (() => _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14, pending: 3)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'Istekler': (() => requestsBe(), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14))),
    'Istekler dolu': (() => requestsBe(full: true), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14, going: 14))),
    'Ayarlar': (() => _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14)), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14))),
    'QR': (() => _be(_ev(manage: true)), (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(manage: true))),
    'Yoklama listesi': (() => _be(_ev(manage: true)), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(manage: true))),
    'Form yeni': (() => FakeBackend()..on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]}), (b) => EventFormPage(session: makeSession(b))),
    'Form duzenle': (() => FakeBackend(), (b) => EventFormPage(session: makeSession(b), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14))),
  };

  for (final e in scenes.entries) {
    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        for (final rtl in [false, true]) {
          if (rtl && size != kPhoneSmall && b == Brightness.dark) continue;
          testWidgets('${e.key} ${b.name} ${size.width.toInt()}${rtl ? ' rtl' : ''}: tasma yok', (tester) async {
            final be = e.value.$1();
            await _pump(tester, e.value.$2(be), b: b, size: size, rtl: rtl);
            _noErr(tester);
            await unmount(tester);
            _noErr(tester);
          });
        }
      }
    }
  }

  // ---- davranis ----
  testWidgets('istek ile: istek gonder -> PENDING kartina doner, geri cek DELETE yapar', (tester) async {
    final be = _be(_ev(policy: 'APPROVAL', capacity: 14));
    await _pump(tester, EventDetailPage(session: makeSession(be), eventId: 5), size: kPhoneMedium);
    expect(find.text('İstek ile katılım'), findsWidgets);
    expect(find.textContaining('Etkinlik sohbeti · Onaylanınca açılır'), findsOneWidget);
    expect(find.text('Katıl'), findsNothing); // alt çubuk yok
    be.on('/events/5', _ev(policy: 'APPROVAL', rsvp: 'PENDING', capacity: 14));
    be.on('/events/5/rsvp', {'myRsvp': 'PENDING', 'goingCount': 9, 'capacity': 14});
    await _reveal(tester, find.byKey(const ValueKey('et2-request-send')));
    await tester.tap(find.byKey(const ValueKey('et2-request-send')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.bodies['PUT /events/5/rsvp'], {'status': 'GOING'});
    expect(find.text('İstek gönderildi'), findsOneWidget);
    await _reveal(tester, find.byKey(const ValueKey('et2-withdraw')));
    await tester.tap(find.byKey(const ValueKey('et2-withdraw')));
    await settle(tester, const Duration(milliseconds: 300));
    be.on('/events/5', _ev(policy: 'APPROVAL', capacity: 14));
    await tester.tap(find.text('Geri çek').last);
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.requests, contains('DELETE /events/5/rsvp'));
    expect(find.byKey(const ValueKey('et2-request-send')), findsOneWidget);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('ANSWERS_REQUIRED: sorular sorulur, /applications ile gonderilir', (tester) async {
    final be = _be(_ev(policy: 'APPROVAL', capacity: 14));
    be.on('/events/5/admission', {'eventId': 5, 'mode': 'APPROVAL', 'questions': ['Neden katılmak istiyorsun?']});
    be.handlers.add((req, path) {
      if (req.method == 'PUT' && path == '/events/5/rsvp') {
        return const FakeResult.json({'code': 'ANSWERS_REQUIRED', 'message': 'Tüm sorulara yanıt vermelisiniz.'}, status: 400);
      }
      return null;
    });
    await _pump(tester, EventDetailPage(session: makeSession(be), eventId: 5), size: kPhoneMedium);
    await _reveal(tester, find.byKey(const ValueKey('et2-request-send')));
    await tester.tap(find.byKey(const ValueKey('et2-request-send')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Neden katılmak istiyorsun?'), findsOneWidget);
    // Boş cevapla gönderilmez.
    await tester.tap(find.text('Katılma isteği gönder').last);
    await tester.pump();
    expect(find.text('Tüm soruları yanıtlamalısın.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('et2-answer-0')), 'Spor yapmak');
    await tester.tap(find.text('Katılma isteği gönder').last);
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.bodies['POST /events/5/applications'], {'answers': ['Spor yapmak']});
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('yonetici: istek ile etkinlikte Katilim istekleri satiri + bekleyen rozeti', (tester) async {
    final be = _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14, pending: 3));
    await _pump(tester, EventDetailPage(session: makeSession(be), eventId: 5), size: kPhoneMedium);
    await _reveal(tester, find.text('Katılım istekleri'));
    expect(find.text('Katılım istekleri'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Yoklama kodu'), findsOneWidget);
    expect(find.text('Etkinlik ayarları'), findsOneWidget);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('yonetici: herkese acik etkinlikte istek satiri yok', (tester) async {
    final be = _be(_ev(manage: true, capacity: 14));
    await _pump(tester, EventDetailPage(session: makeSession(be), eventId: 5), size: kPhoneMedium);
    await _reveal(tester, find.text('Yoklama kodu'));
    expect(find.text('Katılım istekleri'), findsNothing);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('istekler: onayla/reddet uc noktalari, doluysa uyari bandi yalniz doluyken', (tester) async {
    final be = requestsBe();
    await _pump(tester, Etkinlik2RequestsPage(session: makeSession(be), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14)));
    expect(find.byKey(const ValueKey('et2-full-banner')), findsNothing);
    expect(find.text('Bekleyen · 2'), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('Reddedildi'), findsOneWidget);
    expect(find.text('5 yer kaldı'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('et2-approve-21')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.requests, contains('POST /events/5/requests/21/approve'));
    expect(find.text('Bekleyen · 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('et2-reject-22')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.requests, contains('POST /events/5/requests/22/reject'));
    expect(find.text('Bekleyen istek yok.'), findsOneWidget);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('istekler: kontenjan doluysa uyari bandi gorunur; EVENT_FULL istegi bekleyen birakir', (tester) async {
    final be = requestsBe(full: true);
    be.fail('/events/5/requests/21/approve', status: 409, code: 'EVENT_FULL', message: 'Kontenjan dolu.');
    await _pump(tester, Etkinlik2RequestsPage(session: makeSession(be), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14, going: 14)));
    expect(find.byKey(const ValueKey('et2-full-banner')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('et2-approve-21')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Bekleyen · 2'), findsOneWidget);
    expect(find.text('Kontenjan dolu.'), findsOneWidget);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('ayarlar: degisiklikler PUT admission / PATCH capacity / close / chat-room closed ile kaydedilir', (tester) async {
    final be = _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14));
    await _pump(tester, Etkinlik2SettingsPage(session: makeSession(be), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14)));
    await tester.tap(find.text('Herkes katılabilir'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('et2-settings-cap')), '20');
    await tester.tap(find.byKey(const ValueKey('et2-reg-switch')));
    await tester.tap(find.byKey(const ValueKey('et2-chat-switch')));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.bodies['PUT /events/5/admission'], {'mode': 'OPEN', 'questions': <String>[]});
    expect(be.bodies['PATCH /events/5'], {'capacity': 20});
    expect(be.requests, contains('POST /events/5/close'));
    expect(be.bodies['PUT /events/5/chat-room/closed'], {'closed': true});
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('ayarlar: kontenjan onayli sayidan dusuk olamaz', (tester) async {
    final be = _be(_ev(policy: 'APPROVAL', manage: true, capacity: 14));
    await _pump(tester, Etkinlik2SettingsPage(session: makeSession(be), event: _ev(policy: 'APPROVAL', manage: true, capacity: 14)));
    await tester.enterText(find.byKey(const ValueKey('et2-settings-cap')), '5');
    await tester.tap(find.text('Kaydet'));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('onaylı kişi sayısından (9) az olamaz'), findsOneWidget);
    expect(be.requests.where((r) => r.startsWith('PATCH')), isEmpty);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('QR: kod, geri sayim ve N / M sayaci; kapaninca zamanlayici kalmaz', (tester) async {
    final be = _be(_ev(manage: true));
    await _pump(tester, Etkinlik2QrPage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.text('5.123.abcdef'), findsOneWidget);
    expect(find.textContaining('Kod '), findsWidgets);
    expect(find.text('2 / 3 kişi geldi'), findsOneWidget);
    await unmount(tester); // bekleyen Timer'lar iptal edilmeli
    _noErr(tester);
  });

  testWidgets('yoklama listesi: filtre ve elle yoklama anahtari PUT yapar, hatada geri alinir', (tester) async {
    final be = _be(_ev(manage: true));
    await _pump(tester, Etkinlik2AttendancePage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.text('2 / 3 kişi geldi'), findsOneWidget);
    expect(find.text('Can Demir'), findsOneWidget);
    await tester.tap(find.text('Gelmedi'));
    await tester.pump();
    expect(find.text('Ayşe Yılmaz'), findsNothing);
    expect(find.text('Can Demir'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('et2-mark-12')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(be.bodies['PUT /events/5/attendance/12'], {'present': true});
    expect(find.text('3 / 3 kişi geldi'), findsOneWidget);
    be.fail('/events/5/attendance/11', status: 500);
    await tester.tap(find.text('Hepsi'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('et2-mark-11')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('3 / 3 kişi geldi'), findsOneWidget); // geri alındı: Ayşe hâlâ geldi
    _noErr(tester);
    await unmount(tester);
  });
}
