import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/academic/academic_models.dart' show academicClock;
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/reminder_settings_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/events/checkin_input.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/etkinlik3_my_qr_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA-EV turu: elle yoklama kodu (kısa kod), QR tekrar gönderimi, onaylı etkinlikte yoklama, Katıldıklarım > Geçmiş
/// sayfalama, kulüp etkinlik yenileme, istek sayfası sayfalama.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({String? rsvp, String policy = 'OPEN', bool manage = false}) {
  final st = DateTime.now().subtract(const Duration(minutes: 10));
  return {
    'id': 5,
    'title': 'Bahar Şenliği',
    'startsAt': _iso(st),
    'endsAt': _iso(st.add(const Duration(hours: 3))),
    'location': 'Açık Hava Sahnesi',
    'communityId': 7,
    'communityName': 'Müzik Kulübü',
    'goingCount': 3,
    'capacity': 50,
    'myRsvp': rsvp,
    'status': 'ACTIVE',
    'joinPolicy': policy,
    'canManage': manage,
    'createdBy': 2,
  };
}

FakeBackend _detail(Map<String, dynamic> ev, {bool open = true}) => FakeBackend()
  ..on('/events/5', ev)
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': open})
  ..on('/events/5/check-in', {'present': true, 'checkInOpen': true});

Future<void> _gone(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadTestFonts);

  group('CheckinInput', () {
    test('kısa elle kod: boşluk/tire/küçük harf toleranslı, büyük harfe çevrilir', () {
      for (final raw in ['K7M4QX', 'k7m4qx', 'K7M 4QX', ' k7m-4qx ', 'bingol-checkin:K7M4QX']) {
        final i = CheckinInput.parse(raw)!;
        expect(i.isShort, isTrue, reason: raw);
        expect(i.code, 'K7M4QX', reason: raw);
        expect(i.eventId, isNull);
      }
    });

    test('uzun jeton: etkinlik kimliği koddan okunur, önek atılır, kod olduğu gibi gider', () {
      final i = CheckinInput.parse('bingol-checkin:5.123.abc_DEF-9')!;
      expect(i.isShort, isFalse);
      expect(i.eventId, 5);
      expect(i.code, '5.123.abc_DEF-9');
    });

    test('tanınmayan girdi null: boş, kısa, uzun, noktalı ama sayısız, Türkçe harf', () {
      for (final raw in ['', '   ', 'abc', 'K7M4QX9', 'x.1.2', 'ÇĞİÖŞÜ', 'K7M4Q!']) {
        expect(CheckinInput.parse(raw), isNull, reason: raw);
      }
    });

    test('spacedManualCode: 6 karakter 3+3, diğerleri aynen', () {
      expect(spacedManualCode('K7M4QX'), 'K7M 4QX');
      expect(spacedManualCode('5.123.abc'), '5.123.abc');
    });
  });

  group('ScanThrottle', () {
    test('ilk okuma kabul; reddedilen kod bekleme süresi dolmadan yeniden gönderilmez', () {
      final th = ScanThrottle();
      final t0 = DateTime(2026, 1, 1, 12);
      expect(th.accept('A', t0), isTrue);
      th.rejected('A', t0);
      // kamera ~250 ms'de bir aynı kareyi görür
      for (var ms = 250; ms < 4000; ms += 250) {
        expect(th.accept('A', t0.add(Duration(milliseconds: ms))), isFalse, reason: '$ms ms');
      }
      expect(th.accept('A', t0.add(const Duration(seconds: 4, milliseconds: 100))), isTrue);
    });

    test('aynı kod art arda reddedilince bekleme ikiye katlanır (en çok 32 sn)', () {
      final th = ScanThrottle();
      var now = DateTime(2026, 1, 1, 12);
      th.rejected('A', now);
      now = now.add(const Duration(seconds: 5));
      expect(th.accept('A', now), isTrue);
      th.rejected('A', now); // 2. ret: 8 sn
      expect(th.accept('A', now.add(const Duration(seconds: 7))), isFalse);
      expect(th.accept('A', now.add(const Duration(seconds: 8, milliseconds: 100))), isTrue);
      for (var i = 0; i < 10; i++) {
        th.rejected('A', now);
      }
      expect(th.accept('A', now.add(const Duration(seconds: 31))), isFalse);
      expect(th.accept('A', now.add(const Duration(seconds: 33))), isTrue);
    });

    test('başarıyla işlenen kod aynı karede tekrar gönderilmez (32 sn); farklı kod kabul edilir', () {
      final th = ScanThrottle();
      final t0 = DateTime(2026, 1, 1, 12);
      expect(th.accept('A', t0), isTrue);
      th.succeeded('A', t0);
      for (var ms = 250; ms < 30000; ms += 250) {
        expect(th.accept('A', t0.add(Duration(milliseconds: ms))), isFalse, reason: '$ms ms');
      }
      expect(th.accept('A', t0.add(const Duration(seconds: 33))), isTrue);
      expect(th.accept('B', t0.add(const Duration(milliseconds: 1300))), isTrue);
    });

    test('farklı kod en az 1,2 sn sonra kabul edilir; sayaç sıfırlanır', () {
      final th = ScanThrottle();
      final t0 = DateTime(2026, 1, 1, 12);
      th.rejected('A', t0);
      expect(th.accept('B', t0.add(const Duration(milliseconds: 500))), isFalse);
      expect(th.accept('B', t0.add(const Duration(milliseconds: 1300))), isTrue);
      th.rejected('B', t0.add(const Duration(seconds: 2)));
      // B ilk kez reddedildi: seri 1 -> 4 sn
      expect(th.accept('B', t0.add(const Duration(seconds: 5))), isFalse);
      expect(th.accept('B', t0.add(const Duration(seconds: 6, milliseconds: 100))), isTrue);
    });
  });

  group('QrScanPage', () {
    testWidgets('elle giriş reddedilince hata gösterilir, düzeltilince başarılı kapanır (tekrar gönderim yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      var calls = 0;
      await tester.pumpWidget(buildApp(
        QrScanPage(
          scannerBuilder: (_) => const SizedBox.shrink(),
          onSubmit: (code) async {
            calls++;
            return code == 'K7M4QX' ? null : 'Kod geçersiz';
          },
        ),
        size: kPhoneMedium,
      ));
      await settle(tester, const Duration(milliseconds: 600));
      // Kamera izni test ortamında istenir; elle giriş alanı her durumda ekrandadır.
      await tester.enterText(find.byType(TextField).last, 'XXXXXX');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kod geçersiz'), findsWidgets);
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 1, reason: 'hata sonrası kendiliğinden yeniden gönderilmez');
      await _gone(tester);
    });
  });

  group('Etkinlik2QrPage', () {
    FakeBackend be({String? manual}) => FakeBackend()
      ..on('/events/5/checkin-code', {
        'code': '5.123.abcdefghijklmnop',
        'qrPayload': 'bingol-checkin:5.123.abcdefghijklmnop',
        'validForSeconds': 30,
        if (manual != null) 'manualCode': manual,
      })
      ..on('/events/5/attendance/roster', <Object>[]);

    testWidgets('elle kod olarak sunucunun 6 karakterli manualCode değeri gösterilir ve kopyalanır', (tester) async {
      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Etkinlik2QrPage(session: makeSession(be(manual: 'K7M4QX')), event: const {'id': 5, 'title': 'Bahar Şenliği'}),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('K7M 4QX'), findsOneWidget);
      expect(find.textContaining('abcdefghijklmnop'), findsNothing, reason: 'uzun HMAC jetonu insana gösterilmez');
      await tester.tap(find.byKey(const ValueKey('et2-manual-code')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clip, 'K7M4QX');
      await _gone(tester);
    });

    testWidgets('eski sunucu (manualCode yok): uzun kod yedeği gösterilir, sayfa bozulmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Etkinlik2QrPage(session: makeSession(be()), event: const {'id': 5, 'title': 'Bahar Şenliği'}),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('et2-manual-code')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _gone(tester);
    });
  });

  group('EventDetailPage yoklama (katılımcı yalnız QR kodum)', () {
    FakeBackend det(Map<String, dynamic> ev, {bool open = true}) => _detail(ev, open: open)
      ..on('/events/5/my-ticket', {'code': '5.1.abc', 'qrPayload': 'bingol-ticket:5.1.1.abc', 'validForSeconds': 300});

    testWidgets('katılımcı: yalnız "QR kodum"; tarama, kod girişi ve elle kod yok', (tester) async {
      final b = det(_ev(rsvp: 'GOING'));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('detail-my-qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-scan')), findsNothing);
      expect(find.byKey(const ValueKey('detail-enter-code')), findsNothing);
      expect(find.byKey(const ValueKey('detail-code-field')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('detail-my-qr')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(Etkinlik3MyQrPage), findsOneWidget);
      expect(b.requests.where((r) => r.contains('check-in')), isEmpty);
      await _gone(tester);
    });

    testWidgets('onaylı (APPROVAL) etkinlikte katılımı onaylanan kişi de yalnız QR kodum görür', (tester) async {
      final b = det(_ev(rsvp: 'GOING', policy: 'APPROVAL'));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('detail-my-qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-enter-code')), findsNothing);
      // "Katılımdan ayrıl" yalnız gövdede (çubukta tekrarlanmaz)
      expect(find.byKey(const ValueKey('detail-leave')), findsNothing);
      expect(find.byKey(const ValueKey('detail-leave-approval')), findsOneWidget);
      await _gone(tester);
    });

    testWidgets('yoklama kapalı: QR kodum görünmez', (tester) async {
      final b = det(_ev(rsvp: 'GOING', policy: 'APPROVAL'), open: false);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('detail-my-qr')), findsNothing);
      expect(find.byKey(const ValueKey('detail-scan')), findsNothing);
      await _gone(tester);
    });

    testWidgets('sahip (katılımcı kaydı olsa da): QR kodum yok, yoklama aracı var', (tester) async {
      final b = det(_ev(rsvp: 'GOING', manage: true));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('detail-my-qr')), findsNothing);
      expect(find.byKey(const ValueKey('detail-checked-in')), findsNothing);
      expect(find.byKey(const ValueKey('detail-open-attendance')), findsOneWidget);
      await _gone(tester);
    });

    testWidgets('etkinlik sohbeti 404: "yakında" yerine sunucunun gerçek hatası gösterilir', (tester) async {
      final b = _detail(_ev(rsvp: 'GOING'))..fail('/events/5/chat', status: 404, code: 'EVENT_NOT_FOUND', message: 'Etkinlik bulunamadı');
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      final chat = find.byKey(const ValueKey('detail-chat'));
      await tester.ensureVisible(chat);
      await tester.pump();
      await tester.tap(chat);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('yakında'), findsNothing);
      await _gone(tester);
    });
  });

  group('EventsPage', () {
    testWidgets('üstte "Yoklama" (QR/kod girişi) düğmesi yok: katılımcı yoklamayı kendisi vermez', (tester) async {
      final b = FakeBackend()
        ..on('/events/calendar*', {'items': <Object>[], 'truncated': false})
        ..on('/me/events*', {'items': <Object>[], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('events-checkin')), findsNothing);
      expect(find.byKey(const ValueKey('events-create')), findsOneWidget);
      await _gone(tester);
    });
  });

  group('MyEventsPage > Geçmiş sayfalama', () {
    List<Map<String, dynamic>> items(int from, int n, {required bool past}) => [
          for (var i = from; i < from + n; i++)
            {
              'id': i,
              'title': '${past ? 'Geçmiş' : 'Yaklaşan'} etkinlik $i',
              'startsAt': past ? '2020-05-${10 + i % 10}T10:00:00' : '2098-05-${10 + i % 10}T10:00:00',
              'location': 'Salon',
              'myRsvp': 'GOING',
            },
        ];

    testWidgets('Geçmiş sekmesi açıkken kaydırınca GEÇMİŞ akışının sonraki sayfası yüklenir (Yaklaşan değil)', (tester) async {
      final b = FakeBackend()
        ..on('/me/events?mode=attending&size=20', {'items': items(1, 8, past: false), 'nextCursor': 9})
        ..on('/me/events?mode=attending&size=20&cursor=9', {'items': items(20, 2, past: false), 'nextCursor': null})
        ..on('/me/events?mode=past&size=20', {'items': items(100, 8, past: true), 'nextCursor': 7})
        ..on('/me/events?mode=past&size=20&cursor=7', {'items': items(200, 2, past: true), 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MyEventsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text('Geçmiş'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Geçmiş etkinlik 100'), findsOneWidget);
      final upBefore = b.count('mode=attending&size=20&cursor=9');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('mode=past&size=20&cursor=7'), 1, reason: 'görünen akış sayfalanır');
      expect(b.count('mode=attending&size=20&cursor=9'), upBefore, reason: 'görünmeyen Yaklaşan akışı büyütülmez');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Geçmiş etkinlik 201'), findsOneWidget);
      await _gone(tester);
    });

    testWidgets('sayfa getirme hatası toast ile gösterilir, yeniden deneme 5 sn aralıklıdır (toast yağmuru yok)', (tester) async {
      final b = FakeBackend()
        ..on('/me/events?mode=attending&size=20', {'items': items(1, 8, past: false), 'nextCursor': 9})
        ..fail('/me/events?mode=attending&size=20&cursor=9', status: 500)
        ..on('/me/events?mode=past&size=20', {'items': <Object>[], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MyEventsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('mode=attending&size=20&cursor=9'), 1);
      await tester.pump(const Duration(seconds: 6));
      await _gone(tester);
    });
  });

  group('ClubDetailPage', () {
    FakeBackend be() => FakeBackend()
      ..on('/communities/7', {
        'id': 7,
        'name': 'Robotik Kulübü',
        'description': 'Robot yarışmaları.',
        'category': 'Teknoloji',
        'memberCount': 42,
        'visibility': 'PUBLIC',
        'joinPolicy': 'OPEN',
        'myStatus': 'ACTIVE',
        'myRole': 'OWNER',
      })
      ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
      ..on('/communities/7/requests*', {'items': <Object>[], 'nextCursor': null})
      ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null})
      ..on('/events*', {'items': <Object>[], 'nextCursor': null});

    testWidgets('etkinlik oluşturma sayfasından dönünce Etkinlikler sekmesi yenilenir', (tester) async {
      final b = be();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 7), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text('Etkinlikler').first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('GET /events?communityId=7'), 1);
      await tester.ensureVisible(find.text('Etkinlik oluştur').first);
      await tester.tap(find.text('Etkinlik oluştur').first);
      await settle(tester, const Duration(milliseconds: 600));
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('GET /events?communityId=7'), 2, reason: 'dönüşte liste yeniden istenir');
      await _gone(tester);
    });

    testWidgets('yenileme hatası görünür (eski veri kalır ama sessiz geçilmez)', (tester) async {
      final b = be();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 7), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      b.fail('/communities/7', status: 500);
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Robotik Kulübü'), findsWidgets, reason: 'eski veri kalır');
      expect(find.textContaining('İşlem şu anda tamamlanamıyor'), findsWidgets, reason: 'hata kullanıcıya gösterilir');
      await tester.pump(const Duration(seconds: 6));
      await _gone(tester);
    });
  });

  group('Etkinlik2RequestsPage sayfalama', () {
    Map<String, dynamic> app(int id, String name) => {'id': id, 'userId': id, 'displayName': name, 'answers': <String>[], 'status': 'ACCEPTED'};

    testWidgets('Onaylanan sekmesi ilk 50\'yi aşınca "Daha fazla göster" ile sonraki sayfayı alır', (tester) async {
      final b = FakeBackend()
        ..on('/events/5', {'id': 5, 'title': 'X', 'goingCount': 60, 'capacity': 100})
        ..on('/events/5/requests?status=PENDING&size=50', {'items': <Object>[], 'nextCursor': null})
        ..on('/events/5/requests?status=ACCEPTED&size=50', {'items': [app(31, 'Mert Aksoy')], 'nextCursor': 77})
        ..on('/events/5/requests?status=ACCEPTED&size=50&cursor=77', {'items': [app(32, 'Selin Doğan')], 'nextCursor': null})
        ..on('/events/5/requests?status=REJECTED&size=50', {'items': <Object>[], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Etkinlik2RequestsPage(session: makeSession(b), event: const {'id': 5, 'title': 'X', 'goingCount': 60, 'capacity': 100}),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.textContaining('Onaylanan'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Mert Aksoy'), findsOneWidget);
      await tester.ensureVisible(find.text('Daha fazla göster'));
      await tester.tap(find.text('Daha fazla göster'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Selin Doğan'), findsOneWidget);
      expect(find.text('Daha fazla göster'), findsNothing);
      await _gone(tester);
    });
  });

  group('CourseFormPage hata yakalama', () {
    // Kayıt isteği ApiError DIŞINDA bir istisna fırlatırsa düğme meşgul kalmamalı (önceki sürümde takılırdı).
    testWidgets('beklenmeyen istisnada Kaydet yeniden etkinleşir', (tester) async {
      final b = FakeBackend()..on('/timetable/courses', {'id': 1, 'sessions': 'bozuk'}); // sessions List yerine String: ayrıştırma TypeError (ApiError değil)
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          CourseFormPage(session: makeSession(b), allCourses: const [], semesterId: 1, initialDay: 1),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      final name = find.byType(TextField).first;
      await tester.enterText(name, 'Matematik');
      await tester.pump();
      final save = find.widgetWithText(BuButton, 'Dersi ekle');
      await tester.scrollUntilVisible(save, 400, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(save);
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.requests, contains('POST /timetable/courses'));
      // sayfa hâlâ açık ve kaydet düğmesi yeniden dokunulabilir (busy bırakıldı)
      expect(find.byType(CourseFormPage), findsOneWidget);
      expect(tester.widget<BuButton>(save).onPressed, isNotNull);
      expect(tester.widget<BuButton>(save).busy, isFalse);
      await tester.pump(const Duration(seconds: 6));
      await _gone(tester);
    });
  });

  group('ReminderSettingsPage izin', () {
    tearDown(() => PermissionService.instance = SystemPermissionService());

    testWidgets('izin hiç sorulmadıysa "Ayarlardan aç" önce sistem istemini gösterir; verilince anahtarlar açılır', (tester) async {
      ReminderService.platform = _NoopReminders();
      ReminderService.store = MemoryReminderStore();
      addTearDown(() {
        ReminderService.platform = const ChannelReminderPlatform();
        ReminderService.store = const SecureReminderStore();
      });
      final fake = FakePermissionService(initial: {AppPermission.notifications: PermState.denied});
      PermissionService.instance = fake;
      final b = FakeBackend();
      fakeAcademic(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ReminderSettingsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text('Ayarlardan aç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(fake.settingsOpened, 0, reason: 'doğrudan Ayarlar yerine uygulama gerekçesi + sistem istemi');
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(fake.requested, [AppPermission.notifications]);
      expect(find.text('Ayarlardan aç'), findsNothing, reason: 'izin verildi, uyarı kalktı');
      await _gone(tester);
    });

    testWidgets('kalıcı reddedildiyse sistem istemi değil Ayarlar sayfası (sheet) sunulur', (tester) async {
      ReminderService.platform = _NoopReminders();
      ReminderService.store = MemoryReminderStore();
      addTearDown(() {
        ReminderService.platform = const ChannelReminderPlatform();
        ReminderService.store = const SecureReminderStore();
      });
      final fake = FakePermissionService(initial: {AppPermission.notifications: PermState.permanentlyDenied});
      PermissionService.instance = fake;
      final b = FakeBackend();
      fakeAcademic(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ReminderSettingsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text('Ayarlardan aç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(fake.requested, isEmpty);
      await tester.tap(find.text('Ayarlardan aç').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(fake.settingsOpened, 1);
      await _gone(tester);
    });
  });

  group('ClubsTab geri oku', () {
    testWidgets('başka sayfadan açılınca başlıkta geri oku vardır ve çalışır; kökte yoktur', (tester) async {
      final b = FakeBackend()
        ..on('/communities/categories', <Object>[])
        ..on('/communities*', {'items': <Object>[], 'nextCursor': null})
        ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      // kök: geri oku yok
      await tester.pumpWidget(buildApp(ClubsTab(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byTooltip('Geri'), findsNothing);
      // itilmiş: geri oku var
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: makeSession(b))))),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('AÇ'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byTooltip('Geri'), findsOneWidget);
      await tester.tap(find.byTooltip('Geri'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('AÇ'), findsOneWidget);
      await _gone(tester);
    });
  });
}

class _NoopReminders implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}
