import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_my_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_scan_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Okutma gerçek zamanlı geri bildirimi: katılımcı QR ekranı "Okutuldu", görevli ekranı canlı sayaç + son okutan.
/// Kamera/QR okuma ve gerçek WebSocket GERÇEK CİHAZ testi ister; burada olaylar `debugEmitAttendance` ile taklit edilir.
Map<String, dynamic> _ev() {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': 'Kampüs halı saha maçı',
    'startsAt': s.toUtc().toIso8601String(),
    'endsAt': s.add(const Duration(hours: 2)).toUtc().toIso8601String(),
    'canManage': true,
    'goingCount': 9,
  };
}

FakeBackend _be() => FakeBackend()
  ..on('/events/5/attendance/roster', {'rows': <Object>[], 'present': 1, 'absent': 0, 'pending': 3, 'total': 4})
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': true})
  ..on('/events/5/my-permissions', {'owner': true, 'attendanceOpen': true, 'permissions': <String>[]})
  ..on('/events/5/my-ticket', {'code': '5.1.1.abc', 'qrPayload': 'bingol-ticket:5.1.1.abc', 'validForSeconds': 180});

Future<void> _pump(WidgetTester tester, Widget w, {String lang = 'tr', bool reduceMotion = false}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = kPhoneMedium;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.forLocale(Brightness.light, lang),
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
    home: w,
  ));
  await settle(tester, const Duration(milliseconds: 500));
}

Session _session(FakeBackend b) {
  final s = makeSession(b);
  s.realtime = ChatRealtime(s); // başlatılmaz: bağlantı yok, olaylar elle verilir
  return s;
}

Map<String, dynamic> _marked({String key = '5:1:1000', String? at}) =>
    {'type': 'MARKED', 'key': key, 'eventId': 5, 'userId': 1, 'at': at ?? DateTime.now().toUtc().toIso8601String()};

Map<String, dynamic> _scan({String key = '5:11:1000', String? name = 'Ayşe Yılmaz', int present = 2, int total = 9, int eventId = 5}) =>
    {'type': 'SCAN', 'key': key, 'eventId': eventId, 'userId': 11, 'displayName': name, 'at': DateTime.now().toUtc().toIso8601String(), 'present': present, 'total': total};

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  group('katilimci QR ekrani (okutulan taraf)', () {
    for (final lang in ['tr', 'en', 'ar']) {
      testWidgets('MARKED olayi: QR gider, Okutuldu + yoklama alindi gelir ($lang)', (tester) async {
        final s = _session(_be());
        await _pump(tester, Etkinlik3MyQrPage(session: s, event: _ev()), lang: lang);
        expect(find.byKey(const ValueKey('et3-my-qr')), findsOneWidget);
        expect(find.byKey(const ValueKey('et3-my-qr-done')), findsNothing);
        s.realtime!.debugEmitAttendance(_marked());
        await settle(tester, const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('et3-my-qr-done')), findsOneWidget);
        expect(find.byKey(const ValueKey('et3-my-qr')), findsNothing);
        final l = await AppLocalizations.delegate.load(Locale(lang));
        expect(find.text(l.evtLiveCheckedInTitle), findsOneWidget);
        expect(find.text(l.evtLiveCheckedInBody), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('baska etkinligin olayi etkilemez; cift olay tek kez isler; yeni bilet istenmez', (tester) async {
      final be = _be();
      final s = _session(be);
      await _pump(tester, Etkinlik3MyQrPage(session: s, event: _ev()));
      s.realtime!.debugEmitAttendance({..._marked(), 'eventId': 99, 'key': '99:1:1'});
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('et3-my-qr')), findsOneWidget);
      s.realtime!.debugEmitAttendance(_marked());
      s.realtime!.debugEmitAttendance(_marked()); // ayni key: elenir
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('et3-my-qr-done')), findsOneWidget);
      final n = be.count('/my-ticket');
      await tester.pump(const Duration(seconds: 90));
      expect(be.count('/my-ticket'), n, reason: 'okutulduktan sonra bilet yenilenmez');
      await unmount(tester);
    });

    testWidgets('olay kacarsa poll yedegi (my-attendance present=true) okutuldu durumuna gecirir', (tester) async {
      final be = _be();
      final s = _session(be);
      await _pump(tester, Etkinlik3MyQrPage(session: s, event: _ev()));
      expect(find.byKey(const ValueKey('et3-my-qr-done')), findsNothing);
      be.on('/events/5/my-attendance', {'present': true, 'method': 'QR', 'markedAt': DateTime.now().toUtc().toIso8601String(), 'checkInOpen': true});
      await tester.pump(const Duration(seconds: 9)); // baglanti yok: kisa aralikli yoklama
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('et3-my-qr-done')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('acilista zaten okutulmussa dogrudan Okutuldu', (tester) async {
      final be = _be()..on('/events/5/my-attendance', {'present': true, 'markedAt': DateTime.now().toUtc().toIso8601String(), 'checkInOpen': true});
      await _pump(tester, Etkinlik3MyQrPage(session: _session(be), event: _ev()));
      expect(find.byKey(const ValueKey('et3-my-qr-done')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hareket azaltma acikken de durum gorunur (animasyona bagli degil) + liveRegion', (tester) async {
      final s = _session(_be());
      await _pump(tester, Etkinlik3MyQrPage(session: s, event: _ev()), reduceMotion: true);
      s.realtime!.debugEmitAttendance(_marked());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('et3-my-qr-done')), findsOneWidget);
      final sem = tester.getSemantics(find.byKey(const ValueKey('et3-my-qr-done')).first);
      expect(sem.getSemanticsData().flagsCollection.isLiveRegion || sem.label.isNotEmpty, isTrue);
      await unmount(tester);
    });
  });

  group('gorevli tarayici ekrani (gosteren/okutan taraf)', () {
    Widget scan(Session s) => Etkinlik3ScanPage(session: s, event: _ev(), scannerBuilder: (c, f) => const SizedBox.expand());

    testWidgets('baska gorevlinin okutmasi: sayac + son okutan canli guncellenir', (tester) async {
      final s = _session(_be());
      await _pump(tester, scan(s));
      expect(find.text('1 / 4 kişi geldi'), findsOneWidget);
      s.realtime!.debugEmitAttendance(_scan());
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('2 / 9 kişi geldi'), findsOneWidget);
      expect(find.text('Son okutan: Ayşe Yılmaz'), findsOneWidget);
      s.realtime!.debugEmitAttendance(_scan(key: '5:12:2000', name: 'Can Demir', present: 3));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('3 / 9 kişi geldi'), findsOneWidget);
      expect(find.text('Son okutan: Can Demir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('engelli ciftte ad yok: sayac gider, onceki ad korunur; baska etkinlik ve cift olay yok sayilir', (tester) async {
      final s = _session(_be());
      await _pump(tester, scan(s));
      s.realtime!.debugEmitAttendance(_scan(key: 'a', name: null, present: 5));
      s.realtime!.debugEmitAttendance(_scan(key: 'a', name: 'Sizmamali', present: 6)); // ayni key: elenir
      s.realtime!.debugEmitAttendance(_scan(key: 'b', present: 7, eventId: 77)); // baska etkinlik
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('5 / 9 kişi geldi'), findsOneWidget);
      expect(find.textContaining('Son okutan'), findsNothing);
      await unmount(tester);
    });

    testWidgets('poll yedegi: ozet ucu sayaci ve son okutani esitler', (tester) async {
      final be = _be();
      final s = _session(be);
      await _pump(tester, scan(s));
      be.on('/events/5/attendance/summary', {'present': 4, 'total': 9, 'lastName': 'Elif Kaya', 'lastAt': DateTime.now().toUtc().toIso8601String()});
      await tester.pump(const Duration(seconds: 9));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('4 / 9 kişi geldi'), findsOneWidget);
      expect(find.text('Son okutan: Elif Kaya'), findsOneWidget);
      await unmount(tester);
    });

    for (final c in const [
      ('INVALID_CODE', 400, 'Yoklama kodu geçersiz veya süresi dolmuş.'),
      ('NOT_RSVPED_SCAN', 409, 'Bu kişi etkinliğe onaylı katılımcı değil.'),
      ('ATTENDANCE_NOT_OPEN', 409, 'Etkinlik sahibi yoklamayı henüz açmadı.'),
      ('EVENT_PERMISSION_DENIED', 403, 'Bu işlem için yetkiniz yok.'),
    ]) {
      testWidgets('okutan taraf hata: ${c.$1} sunucunun durust mesajini gosterir, sayac degismez', (tester) async {
        final be = _be()..fail('/events/5/scan', status: c.$2, code: c.$1, message: c.$3);
        final s = _session(be);
        late void Function(String) send;
        await _pump(tester, Etkinlik3ScanPage(session: s, event: _ev(), scannerBuilder: (ctx, f) {
          send = f;
          return const SizedBox.expand();
        }));
        send('bingol-ticket:x');
        await settle(tester, const Duration(milliseconds: 400));
        expect(find.text(c.$3), findsOneWidget);
        expect(find.text('1 / 4 kişi geldi'), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('sayfa kapaninca poll zamanlayicisi iptal (istek artmaz)', (tester) async {
      final be = _be();
      final s = _session(be);
      await _pump(tester, scan(s));
      await unmount(tester);
      final n = be.count('/attendance/summary');
      await tester.pump(const Duration(seconds: 120));
      expect(be.count('/attendance/summary'), n);
    });
  });

  testWidgets('organizator yoklama kodu ekrani (a yonu): SCAN olayi sayac + son okutan', (tester) async {
    final be = _be()..on('/events/5/checkin-code', {'code': '5.1.abc', 'qrPayload': 'bingol-checkin:5.1.abc', 'manualCode': 'K7M4QX', 'validForSeconds': 30});
    final s = _session(be);
    await _pump(tester, Etkinlik2QrPage(session: s, event: _ev()));
    s.realtime!.debugEmitAttendance(_scan(present: 3, total: 9));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('3 / 9 kişi geldi'), findsOneWidget);
    expect(find.byKey(const ValueKey('et2-live-last')), findsOneWidget);
    await unmount(tester);
  });
}
