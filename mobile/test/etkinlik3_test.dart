import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_moderators_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_my_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_scan_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({bool manage = false, String? rsvp, bool meeting = false}) {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': 'Kampüs halı saha maçı',
    'description': 'Cuma akşamı maç.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Halı saha',
    'goingCount': 9,
    'interestedCount': 3,
    'myRsvp': rsvp,
    'canManage': manage,
    'joinPolicy': 'OPEN',
    'communityId': 10,
    'createdBy': 2,
    'organizer': {'id': 2, 'displayName': 'Mehmet Kaya', 'avatarUrl': null},
    'organizerName': 'Mehmet Kaya',
    if (meeting) ...{'meetingPoint': 'Mühendislik Fakültesi önü, ana giriş', 'meetingLat': 38.8847, 'meetingLng': 40.4986},
  };
}

/// Sunucu yoklama listesi: [st] 4 katılımcının durumu (PRESENT | ABSENT | NONE); sayaçlar satırlardan türer.
Map<String, dynamic> _roster({List<String> st = const ['PRESENT', 'ABSENT', 'NONE', 'NONE']}) {
  const people = [
    (11, 'Ayşe Yılmaz', 'Bilgisayar Mühendisliği'),
    (12, 'Can Demir', 'İşletme'),
    (13, 'Elif Kaya', 'Hukuk'),
    (14, 'Burak Çelik', null),
  ];
  final rows = <Map<String, dynamic>>[
    for (var i = 0; i < people.length; i++)
      {
        'userId': people[i].$1,
        'displayName': people[i].$2,
        if (people[i].$3 != null) 'department': people[i].$3,
        'rsvpStatus': 'GOING',
        'present': st[i] == 'PRESENT',
        'status': st[i],
        if (st[i] != 'NONE') ...{
          'method': st[i] == 'PRESENT' ? 'QR' : 'MANUAL',
          'markedByName': st[i] == 'PRESENT' ? 'Mehmet Kaya' : 'Zeynep Arslan',
          'markedAt': _iso(DateTime.now()),
        },
      },
  ];
  int n(String s) => st.where((e) => e == s).length;
  return {'rows': rows, 'present': n('PRESENT'), 'absent': n('ABSENT'), 'pending': n('NONE'), 'total': st.length};
}

FakeBackend _be({
  bool manage = false,
  String? rsvp,
  bool owner = false,
  bool open = false,
  List<String> perms = const [],
}) =>
    FakeBackend()
      ..on('/events/5', _ev(manage: manage, rsvp: rsvp))
      ..on('/events/5/attendees/preview', {'goingCount': 9, 'avatars': <Object>[]})
      ..on('/events/5/attendance/roster', _roster())
      ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': true})
      ..on('/events/5/my-permissions', {'owner': owner || manage, 'attendanceOpen': open, 'permissions': perms})
      ..on('/events/5/my-ticket', {'code': '5.1.1.abc', 'qrPayload': 'bingol-ticket:5.1.1.abc', 'validForSeconds': 180})
      ..on('/events/5/moderators', [
        {'userId': 21, 'displayName': 'Zeynep Arslan', 'permissions': ['TAKE_ATTENDANCE'], 'createdAt': _iso(DateTime.now())},
        {'userId': 22, 'displayName': 'Burak Çelik', 'permissions': <String>[], 'createdAt': _iso(DateTime.now())},
      ])
      ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4});

String? _shotsDir() => Platform.environment['EVT3_SHOTS'];

Future<void> _pump(WidgetTester tester, Widget w,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, double scale = 1.0, String lang = 'tr', GlobalKey? key}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: w,
    ),
  ));
  await settle(tester, const Duration(milliseconds: 600));
}

void _noErr(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail('$e');
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final dir = _shotsDir();
  if (dir == null) return;
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 1.0);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  final scenes = <String, (FakeBackend Function(), Widget Function(FakeBackend))>{
    'moderatorler': (() => _be(manage: true), (b) => Etkinlik3ModeratorsPage(session: makeSession(b), event: _ev(manage: true))),
    'okut': (() => _be(manage: true), (b) => Etkinlik3ScanPage(session: makeSession(b), event: _ev(manage: true), scannerBuilder: (c, f) => const SizedBox.expand())),
    'qrkodum': (() => _be(rsvp: 'GOING', open: true), (b) => Etkinlik3MyQrPage(session: makeSession(b), event: _ev(rsvp: 'GOING'))),
    'detay_sahip': (() => _be(manage: true, open: true), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'detay_moderator': (() => _be(open: true, perms: ['TAKE_ATTENDANCE', 'VIEW_ATTENDEES']), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'detay_katilimci_acik': (() => _be(rsvp: 'GOING', open: true), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'yoklama_araci': (() => _be(manage: true), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(manage: true))),
    'yoklama_goruntule': (() => _be(perms: ['VIEW_ATTENDEES']), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(), canTake: false)),
    'detay_bulusma': (() => _be()..on('/events/5', _ev(meeting: true)), (b) => EventDetailPage(session: makeSession(b), eventId: 5)),
    'form_duzenle': (() => _be(manage: true), (b) => EventFormPage(session: makeSession(b), event: _ev(manage: true, meeting: true))),
  };

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          scenes.forEach((name, sc) {
            final id = '$name ${dark ? 'koyu' : 'acik'} ${size.width.toInt()} x$scale $lang';
            testWidgets('etk3 $id', (tester) async {
              final key = GlobalKey();
              await _pump(tester, sc.$2(sc.$1()), b: dark ? Brightness.dark : Brightness.light, size: size, scale: scale, lang: lang, key: key);
              _noErr(tester);
              if (size == kPhoneMedium && scale == 1.0) await _shot(tester, key, 'etk3_${name}_${dark ? 'dark' : 'light'}_$lang');
              await unmount(tester);
            });
          });
        }
      }
    }
  }

  testWidgets('sahip: moderator satiri ve yoklama anahtari gorunur; moderatorde HIC gorunmez', (tester) async {
    await _pump(tester, EventDetailPage(session: makeSession(_be(manage: true)), eventId: 5));
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detail-open-moderators')), 300, scrollable: list);
    expect(find.byKey(const ValueKey('detail-open-moderators')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-att-open-switch')), findsOneWidget);
    await unmount(tester);

    await _pump(tester, EventDetailPage(session: makeSession(_be(open: true, perms: ['TAKE_ATTENDANCE'])), eventId: 5));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detail-mod-block')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('detail-mod-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-mod-requests')), findsNothing);
    expect(find.byKey(const ValueKey('detail-open-moderators')), findsNothing);
    expect(find.byKey(const ValueKey('detail-att-open-switch')), findsNothing);
    expect(find.byKey(const ValueKey('detail-open-qr')), findsNothing);
    await unmount(tester);
  });

  testWidgets('moderator: yoklama kapaliysa okutma yerine aciklama, yetkisiz uc yok', (tester) async {
    await _pump(tester, EventDetailPage(session: makeSession(_be(open: false, perms: ['TAKE_ATTENDANCE'])), eventId: 5));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detail-mod-block')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('detail-mod-closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-mod-scan')), findsNothing);
    await unmount(tester);
  });

  testWidgets('katilimci: yoklama aciksa QR kodum gorunur, kapaliysa gorunmez', (tester) async {
    await _pump(tester, EventDetailPage(session: makeSession(_be(rsvp: 'GOING', open: true)), eventId: 5));
    expect(find.byKey(const ValueKey('detail-my-qr')), findsOneWidget); // alt çubuk: tek eylem
    expect(find.byKey(const ValueKey('detail-enter-code')), findsNothing);
    expect(find.byKey(const ValueKey('detail-scan')), findsNothing);
    await unmount(tester);
    final closed = _be(rsvp: 'GOING', open: false)..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false});
    await _pump(tester, EventDetailPage(session: makeSession(closed), eventId: 5));
    expect(find.byKey(const ValueKey('detail-my-qr')), findsNothing);
    await unmount(tester);
  });

  testWidgets('okut: MARKED, ALREADY ve hata mesajlari', (tester) async {
    final be = _be(manage: true);
    void Function(String)? send;
    await _pump(
        tester,
        Etkinlik3ScanPage(
            session: makeSession(be),
            event: _ev(manage: true),
            scannerBuilder: (c, f) {
              send = f;
              return const SizedBox.expand();
            }));
    be.on('/events/5/scan', {'status': 'MARKED', 'userId': 11, 'displayName': 'Ayşe Yılmaz'});
    send!('bingol-ticket:a');
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Ayşe Yılmaz katıldı'), findsOneWidget);
    expect(be.bodies['POST /events/5/scan'], {'code': 'bingol-ticket:a'});
    await tester.pump(const Duration(seconds: 2));
    be.on('/events/5/scan', {'status': 'ALREADY', 'userId': 11, 'displayName': 'Ayşe Yılmaz'});
    send!('bingol-ticket:b');
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Ayşe Yılmaz zaten katıldı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    be.fail('/events/5/scan', status: 400, code: 'INVALID_CODE', message: 'Kod geçersiz veya süresi dolmuş.');
    send!('bingol-ticket:c');
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Kod geçersiz veya süresi dolmuş.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('qr kodum: kapaliysa sunucu mesaji (genel hata degil)', (tester) async {
    final be = _be(rsvp: 'GOING');
    be.fail('/events/5/my-ticket', status: 409, code: 'ATTENDANCE_NOT_OPEN', message: 'Etkinlik sahibi yoklamayı henüz açmadı.');
    await _pump(tester, Etkinlik3MyQrPage(session: makeSession(be), event: _ev(rsvp: 'GOING')));
    expect(find.text('Etkinlik sahibi yoklamayı henüz açmadı.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('qr kodum: 4xx sonrasi otomatik tekrar yok', (tester) async {
    final be = _be(rsvp: 'GOING');
    be.fail('/events/5/my-ticket', status: 409, code: 'ATTENDANCE_NOT_OPEN', message: 'Yoklama kapali.');
    await _pump(tester, Etkinlik3MyQrPage(session: makeSession(be), event: _ev(rsvp: 'GOING')));
    final n = be.requests.where((r) => r.contains('/events/5/my-ticket')).length;
    await tester.pump(const Duration(seconds: 90));
    expect(be.requests.where((r) => r.contains('/events/5/my-ticket')).length, n);
    await unmount(tester);
  });

  testWidgets('qr kodum: ag/5xx hatasinda mevcut QR kalir', (tester) async {
    final be = _be(rsvp: 'GOING', open: true);
    await _pump(tester, Etkinlik3MyQrPage(session: makeSession(be), event: _ev(rsvp: 'GOING')));
    expect(find.byKey(const ValueKey('et3-my-qr')), findsOneWidget);
    be.fail('/events/5/my-ticket', status: 500, message: 'Sunucu hatasi');
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('et3-my-qr-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('et3-my-qr')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('qr kodum: sahip/moderator icin 403 TICKET_NOT_FOR_STAFF: kisisel QR yok, aciklama gosterilir, yeniden deneme yok', (tester) async {
    final be = _be(manage: true, owner: true);
    be.fail('/events/5/my-ticket', status: 403, code: 'TICKET_NOT_FOR_STAFF', message: 'sunucu');
    await _pump(tester, Etkinlik3MyQrPage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.byKey(const ValueKey('et3-my-qr-error')), findsOneWidget);
    expect(find.textContaining('kişisel QR kodu yoktur'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
    final n = be.requests.where((r) => r.contains('/events/5/my-ticket')).length;
    await tester.pump(const Duration(seconds: 90));
    expect(be.requests.where((r) => r.contains('/events/5/my-ticket')).length, n);
    await unmount(tester);
  });

  testWidgets('yoklama kodu sayfasi: kapaliysa uyari + Yoklamayi ac PUT yapar', (tester) async {
    final be = _be(manage: true, owner: true, open: false);
    await _pump(tester, Etkinlik2QrPage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.byKey(const ValueKey('et2-att-closed')), findsOneWidget);
    await tester.tap(find.text('Yoklamayı aç'));
    await settle(tester, const Duration(milliseconds: 300));
    expect(be.requests.any((r) => r.contains('PUT') && r.contains('/events/5/attendance-open')), isTrue);
    expect(find.byKey(const ValueKey('et2-att-closed')), findsNothing);
    await unmount(tester);
  });

  testWidgets('yoklama kodu sayfasi: pencere disi 409 gercek mesaji gosterir (kok neden)', (tester) async {
    final be = _be(manage: true);
    be.fail('/events/5/checkin-code', status: 409, code: 'CHECKIN_CLOSED', message: 'Yoklama henüz açılmadı.');
    await _pump(tester, Etkinlik2QrPage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.text('Yoklama henüz açılmadı.'), findsOneWidget);
    expect(find.textContaining('bağlantı kurulamadı'), findsNothing);
    await unmount(tester);
  });

  testWidgets('moderatorler: yetki anahtari PUT yapar, kaldir DELETE yapar', (tester) async {
    final be = _be(manage: true);
    await _pump(tester, Etkinlik3ModeratorsPage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.text('Zeynep Arslan'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('et3-mod-remove-21')));
    await tester.tap(find.byKey(const ValueKey('et3-mod-remove-21')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(be.requests.any((r) => r.contains('DELETE') && r.contains('/events/5/moderators/21')), isTrue);
    expect(find.text('Zeynep Arslan'), findsNothing);
    final sw = find.byKey(const ValueKey('et3-perm-22-MANAGE_REQUESTS'));
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await settle(tester, const Duration(milliseconds: 300));
    expect(be.bodies['PUT /events/5/moderators/22'], {'permissions': ['MANAGE_REQUESTS']});
    await unmount(tester);
  });

  test('etkinlik olusturma yalniz kulup sahibine acik', () {
    expect(eventClubPublishMode({'myRole': 'OWNER', 'myStatus': 'ACTIVE'}), isTrue);
    expect(eventClubPublishMode({'myRole': 'ADMIN'}), isNull);
    expect(eventClubPublishMode({'myRole': 'MODERATOR'}), isNull);
    expect(eventClubPublishMode({'myRole': 'MEMBER', 'canManageEvents': true}), isNull);
  });

  // ---- Yoklama modeli v2: rol matrisi + yoklama araci ----

  testWidgets('rol matrisi: katilimci yalniz QR kodum; sahip ve moderator QR kodum gormez', (tester) async {
    // katilimci
    await _pump(tester, EventDetailPage(session: makeSession(_be(rsvp: 'GOING', open: true)), eventId: 5));
    expect(find.byKey(const ValueKey('detail-my-qr')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-open-attendance')), findsNothing);
    expect(find.byKey(const ValueKey('detail-mod-list')), findsNothing);
    await unmount(tester);
    // sahip (katilimci kaydi da olsa)
    await _pump(tester, EventDetailPage(session: makeSession(_be(manage: true, rsvp: 'GOING', open: true)), eventId: 5));
    expect(find.byKey(const ValueKey('detail-my-qr')), findsNothing);
    expect(find.byKey(const ValueKey('detail-checked-in')), findsNothing);
    await unmount(tester);
    // moderator (yetkili) katilimci kaydi olsa da
    await _pump(tester, EventDetailPage(session: makeSession(_be(rsvp: 'GOING', open: true, perms: ['TAKE_ATTENDANCE'])), eventId: 5));
    expect(find.byKey(const ValueKey('detail-my-qr')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detail-mod-block')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('detail-mod-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-mod-list')), findsOneWidget);
    await unmount(tester);
    // yetkisiz moderator: yalniz liste gorme (VIEW_ATTENDEES); okutma yok
    await _pump(tester, EventDetailPage(session: makeSession(_be(open: true, perms: ['VIEW_ATTENDEES'])), eventId: 5));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detail-mod-block')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('detail-mod-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-mod-scan')), findsNothing);
    await unmount(tester);
  });

  testWidgets('yoklama araci: sayac, arama ve suzge; satira dokununca Sifirla PUT {status: NONE}', (tester) async {
    final be = _be(manage: true);
    await _pump(tester, Etkinlik2AttendancePage(session: makeSession(be), event: _ev(manage: true)));
    expect(find.text('1 geldi · 1 gelmedi · 2 bekliyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('att-scan')), findsOneWidget);
    // arama
    await tester.enterText(find.byKey(const ValueKey('att-search')), 'elif');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Elif Kaya'), findsOneWidget);
    expect(find.text('Can Demir'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('att-search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('att-no-match')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('att-search')), '');
    await tester.pump(const Duration(milliseconds: 300));
    // gelmedi satirini sifirla
    await tester.tap(find.byKey(const ValueKey('att-row-12')));
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('att-opt-reset')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.bodies['PUT /events/5/attendance/12'], {'status': 'NONE'});
    expect(find.text('1 geldi · 0 gelmedi · 3 bekliyor'), findsOneWidget);
    // bekleyen -> gelmedi
    await tester.tap(find.byKey(const ValueKey('att-row-13')));
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('att-opt-absent')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.bodies['PUT /events/5/attendance/13'], {'status': 'ABSENT'});
    expect(find.text('1 geldi · 1 gelmedi · 2 bekliyor'), findsOneWidget);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('yoklama araci: Kalanlari gelmedi isaretle onayli toplu istek yapar', (tester) async {
    final be = _be(manage: true);
    await _pump(tester, Etkinlik2AttendancePage(session: makeSession(be), event: _ev(manage: true)));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('att-bulk')), 300, scrollable: find.byType(Scrollable).first);
    be.on('/events/5/attendance/bulk', {'updated': 2});
    be.on('/events/5/attendance/roster', _roster(st: ['PRESENT', 'ABSENT', 'ABSENT', 'ABSENT']));
    await tester.tap(find.byKey(const ValueKey('att-bulk')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.requests.where((r) => r.contains('/attendance/bulk')), isEmpty); // onay bekler
    await tester.tap(find.text('Kalanları gelmedi işaretle').last);
    await settle(tester, const Duration(milliseconds: 500));
    expect(be.bodies['POST /events/5/attendance/bulk'], {'status': 'ABSENT', 'rest': true});
    expect(find.text('1 geldi · 3 gelmedi · 0 bekliyor'), findsOneWidget);
    expect(find.byKey(const ValueKey('att-bulk')), findsNothing);
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('yoklama araci: yalniz goruntuleme (canTake=false): okut, toplu ve satir secimi yok', (tester) async {
    final be = _be();
    await _pump(tester, Etkinlik2AttendancePage(session: makeSession(be), event: _ev(), canTake: false));
    expect(find.byKey(const ValueKey('att-view-only')), findsOneWidget);
    expect(find.byKey(const ValueKey('att-scan')), findsNothing);
    expect(find.byKey(const ValueKey('att-bulk')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('att-row-13')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('att-opt-present')), findsNothing);
    expect(be.requests.where((r) => r.startsWith('PUT')), isEmpty);
    await unmount(tester);
  });

  testWidgets('yoklama araci: QR okutunca satir Geldi olur (liste donuste yenilenir)', (tester) async {
    final be = _be(manage: true);
    void Function(String)? send;
    await _pump(
        tester,
        Etkinlik2AttendancePage(
            session: makeSession(be),
            event: _ev(manage: true),
            scannerBuilder: (c, f) {
              send = f;
              return const SizedBox.expand();
            }));
    await tester.tap(find.byKey(const ValueKey('att-scan')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byType(Etkinlik3ScanPage), findsOneWidget);
    be.on('/events/5/scan', {'status': 'MARKED', 'userId': 13, 'displayName': 'Elif Kaya'});
    be.on('/events/5/attendance/roster', _roster(st: ['PRESENT', 'ABSENT', 'PRESENT', 'NONE']));
    send!('bingol-ticket:x');
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Elif Kaya katıldı'), findsOneWidget);
    await tester.tap(find.text('Yoklama listesi')); // listeye don
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byType(Etkinlik3ScanPage), findsNothing);
    expect(find.text('2 geldi · 1 gelmedi · 1 bekliyor'), findsOneWidget);
    expect(find.textContaining('Okutan: Mehmet Kaya'), findsWidgets); // Ayşe (önceki) + Elif (yeni)
    _noErr(tester);
    await unmount(tester);
  });

  testWidgets('yoklama araci: baska okutucunun isaretlemesi sessiz yenilemeyle (15 sn) gorunur', (tester) async {
    final be = _be(manage: true);
    await _pump(tester, Etkinlik2AttendancePage(session: makeSession(be), event: _ev(manage: true), refreshEvery: const Duration(seconds: 2)));
    expect(find.text('1 geldi · 1 gelmedi · 2 bekliyor'), findsOneWidget);
    final n = be.requests.where((r) => r.contains('/attendance/roster')).length;
    be.on('/events/5/attendance/roster', _roster(st: ['PRESENT', 'ABSENT', 'PRESENT', 'NONE']));
    await tester.pump(const Duration(seconds: 2));
    await settle(tester, const Duration(milliseconds: 300));
    expect(be.requests.where((r) => r.contains('/attendance/roster')).length, greaterThan(n));
    expect(find.text('2 geldi · 1 gelmedi · 1 bekliyor'), findsOneWidget);
    await unmount(tester); // zamanlayici iptal edilmeli
    _noErr(tester);
  });

  testWidgets('detay: bulusma noktasi bolumu (koordinat/harita baglantisi yok); yoksa bolum gizli', (tester) async {
    final be = _be()..on('/events/5', _ev(meeting: true));
    await _pump(tester, EventDetailPage(session: makeSession(be), eventId: 5));
    expect(find.byKey(const ValueKey('detail-meeting')), findsOneWidget);
    expect(find.text('Mühendislik Fakültesi önü, ana giriş'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-meeting-map')), findsNothing); // enlem/boylam kaldirildi
    await unmount(tester);
    await _pump(tester, EventDetailPage(session: makeSession(_be()), eventId: 5));
    expect(find.byKey(const ValueKey('detail-meeting')), findsNothing);
    await unmount(tester);
  });

  testWidgets('form: bulusma alani goruntusu (uzun ekran)', (tester) async {
    final key = GlobalKey();
    final be = _be(manage: true);
    await _pump(tester, EventFormPage(session: makeSession(be), event: _ev(manage: true, meeting: true)), size: const Size(390, 2000), key: key);
    await _shot(tester, key, 'etk3_form_bulusma_light_tr');
    await unmount(tester);
  });

  testWidgets('form: bulusma noktasi duzenlemede doldurulur; PATCH yalniz meetingPoint gonderir, koordinat alani/alanlari yok', (tester) async {
    final be = _be(manage: true);
    be.on('/events/5', _ev(manage: true, meeting: true));
    await _pump(tester, EventFormPage(session: makeSession(be), event: _ev(manage: true, meeting: true)));
    expect(find.byKey(const ValueKey('evc-meet')), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('evc-meet'))) as TextField).controller!.text, 'Mühendislik Fakültesi önü, ana giriş');
    expect(find.byKey(const ValueKey('evc-meet-lat')), findsNothing);
    expect(find.byKey(const ValueKey('evc-meet-lng')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('evc-submit')), 300, scrollable: find.byType(Scrollable).first);
    be.on('/events/5', _ev(manage: true, meeting: true));
    await tester.tap(find.byKey(const ValueKey('evc-submit')));
    await settle(tester, const Duration(milliseconds: 500));
    final body = be.bodies['PATCH /events/5'] as Map;
    expect(body['meetingPoint'], 'Mühendislik Fakültesi önü, ana giriş');
    expect(body.containsKey('meetingLat'), isFalse);
    expect(body.containsKey('meetingLng'), isFalse);
    expect(body['location'], 'Halı saha'); // yer ayri alan
    _noErr(tester);
  });
}
