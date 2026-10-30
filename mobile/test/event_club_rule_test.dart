import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Etkinlik kuralı: yalnız bir kulüp adına oluşturulur (kulüpsüz yok).
/// Yönetici -> hemen yayın, izinli üye -> onaya, diğerleri -> seçenek yok.

Map<String, dynamic> _club(int id, String name, String role, {String status = 'ACTIVE', Map<String, dynamic>? extra}) =>
    {'id': id, 'name': name, 'myRole': role, 'myStatus': status, ...?extra};

FakeBackend _be(List<Map<String, dynamic>> clubs, {Object? created}) => FakeBackend()
  ..on('/me/communities*', {'items': clubs})
  ..on('/events', created ?? {'id': 77});

Widget _launcher(FakeBackend b, {int? communityId, DateTime Function()? now}) {
  final s = makeSession(b);
  return Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => EventFormPage(session: s, communityId: communityId, now: now)),
          ),
          child: const Text('ac'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, FakeBackend b, {int? communityId, DateTime Function()? now}) async {
  useScreen(tester, const Size(390, 1600));
  await tester.pumpWidget(buildApp(_launcher(b, communityId: communityId, now: now)));
  await tester.tap(find.text('ac'));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _submit(WidgetTester tester, {String title = 'Boğaz yürüyüşü'}) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.ensureVisible(find.text('Etkinliği oluştur'));
  await tester.pump();
  await tester.tap(find.text('Etkinliği oluştur'));
  await settle(tester, const Duration(milliseconds: 800));
}

/// Zamana bagli varsayilanlar icin sabit "simdi" (gercek saatten bagimsiz, gece yarisi tasmasi dahil).
DateTime Function() _at(int h, int m) => () => DateTime(2026, 10, 28, h, m);
final _fixedNow = _at(10, 20);

void main() {
  setUpAll(loadTestFonts);

  testWidgets('kulubu olmayan kullanici: form yerine bos durum + Kuluplere goz at', (tester) async {
    final b = _be([]);
    await _open(tester, b);
    expect(find.text('Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın'), findsOneWidget);
    expect(find.text('Kulüplere göz at'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Etkinliği oluştur'), findsNothing);
    expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);
    await unmount(tester);
  });

  testWidgets('yalniz izinsiz uye / bekleyen uye: secenek yok, bos durum', (tester) async {
    final b = _be([
      _club(8, 'Sadece Üye Kulüp', 'MEMBER'),
      _club(9, 'Bekleyen Kulüp', 'ADMIN', status: 'PENDING'),
    ]);
    await _open(tester, b);
    expect(find.text('Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın'), findsOneWidget);
    expect(find.text('Sadece Üye Kulüp'), findsNothing);
    await unmount(tester);
  });

  testWidgets('tek kulup otomatik secili, yonetici: Hemen yayinlanir, communityId gider', (tester) async {
    final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
    await _open(tester, b);
    expect(find.text('Robotik Topluluğu'), findsOneWidget);
    expect(find.text('Hemen yayınlanır.'), findsOneWidget);
    expect(find.text('Admin onayından sonra yayınlanır.'), findsNothing);
    await _submit(tester);
    final body = b.bodies['POST /events'] as Map;
    expect(body['communityId'], 7);
    expect(body['joinPolicy'], 'OPEN');
    expect(find.text('ac'), findsOneWidget); // durum yok -> form kapandı
    await unmount(tester);
  });

  testWidgets('communityId verilen kulup (kulup detayindan) onceden secilir', (tester) async {
    final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER'), _club(3, 'Müzik Kulübü', 'ADMIN')]);
    await _open(tester, b, communityId: 3);
    expect(find.text('Müzik Kulübü'), findsOneWidget);
    await _submit(tester);
    expect((b.bodies['POST /events'] as Map)['communityId'], 3);
    await unmount(tester);
  });

  testWidgets('cok kulup: secim zorunlu; izinli uye onay metniyle listelenir', (tester) async {
    final b = _be([
      _club(7, 'Robotik Topluluğu', 'OWNER'),
      _club(8, 'İzinli Üye Kulübü', 'MEMBER', extra: {'myPermissions': ['MANAGE_EVENTS']}),
      _club(9, 'İzinsiz Üye Kulübü', 'MEMBER'),
    ]);
    await _open(tester, b);
    expect(find.text('Kulüp seç'), findsOneWidget); // seçilmedi
    expect(find.text('Hemen yayınlanır.'), findsNothing);
    await _submit(tester);
    expect(find.text('Önce bir kulüp seç.'), findsOneWidget);
    expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);

    await tester.ensureVisible(find.byKey(const ValueKey('et2-club-field')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('et2-club-field')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('İzinsiz Üye Kulübü'), findsNothing);
    await tester.tap(find.text('İzinli Üye Kulübü'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Admin onayından sonra yayınlanır.'), findsOneWidget);
    expect(find.text('Hemen yayınlanır.'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('et2-club-field')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('et2-club-field')));
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Robotik Topluluğu'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Hemen yayınlanır.'), findsOneWidget);
    await _submit(tester);
    expect((b.bodies['POST /events'] as Map)['communityId'], 7);
    await unmount(tester);
  });

  testWidgets('PENDING_REVIEW: Onaya gonderildi bilgisi, sonra form kapanir', (tester) async {
    final b = _be([_club(8, 'İzinli Üye Kulübü', 'MEMBER', extra: {'canManageEvents': true})],
        created: {'id': 77, 'status': 'PENDING_REVIEW'});
    await _open(tester, b);
    await _submit(tester);
    expect(find.text('Onaya gönderildi'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('ac'), findsOneWidget);
    expect(b.requests.where((r) => r.startsWith('GET /events/77')), isEmpty); // detaya gitmedi
    await unmount(tester);
  });

  testWidgets('ACTIVE: olusturunca etkinlik detayina gider', (tester) async {
    final s = DateTime.now().add(const Duration(days: 2));
    final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')], created: {'id': 77, 'status': 'ACTIVE'})
      ..on('/events/77', {
        'id': 77,
        'title': 'Boğaz yürüyüşü',
        'status': 'ACTIVE',
        'startsAt': s.toUtc().toIso8601String(),
        'endsAt': s.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'canManage': true,
        'communityId': 7,
        'communityName': 'Robotik Topluluğu',
      });
    await _open(tester, b);
    await _submit(tester);
    expect(b.requests, contains('GET /events/77'));
    expect(find.byType(EventDetailPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('400 EVENT_CLUB_REQUIRED ve 403 anlasilir mesaj gosterir', (tester) async {
    final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')])
      ..fail('/events', status: 400, code: 'EVENT_CLUB_REQUIRED');
    await _open(tester, b);
    await _submit(tester);
    expect(find.text('Etkinlik bir kulüp adına oluşturulmalı. Bir kulüp seç.'), findsOneWidget);
    b.fail('/events', status: 403, code: 'FORBIDDEN', message: 'Forbidden');
    await tester.ensureVisible(find.text('Etkinliği oluştur'));
    await tester.pump();
    await tester.tap(find.text('Etkinliği oluştur'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.text('Bu kulüp adına etkinlik oluşturma yetkin yok.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('detay: admin gizledi (404) -> Etkinlik bulunamadi', (tester) async {
    final b = FakeBackend()..fail('/events/5', status: 404, code: 'EVENT_NOT_FOUND');
    useScreen(tester, const Size(390, 900));
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5)));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Etkinlik bulunamadı'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('detay: PENDING_REVIEW rozeti + REJECTED nedeni', (tester) async {
    final s = DateTime.now().add(const Duration(days: 2));
    Map<String, dynamic> ev(String st, {String? reason}) => {
          'id': 5,
          'title': 'Bahar Şenliği',
          'status': st,
          'startsAt': s.toUtc().toIso8601String(),
          'endsAt': s.add(const Duration(hours: 2)).toUtc().toIso8601String(),
          'canManage': true,
          'rejectReason': reason,
        };
    final b = FakeBackend()..on('/events/5', ev('PENDING_REVIEW'));
    useScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5)));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Onay bekliyor'), findsOneWidget);
    await unmount(tester);

    final b2 = FakeBackend()..on('/events/5', ev('REJECTED', reason: 'Tarih uygun değil'));
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b2), eventId: 5)));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Reddedildi'), findsOneWidget);
    expect(find.text('Neden: Tarih uygun değil'), findsOneWidget);
    await unmount(tester);
  });

  group('tarih/saat ve aciklama kurallari', () {
    String summaryText(WidgetTester t) => t.widget<Semantics>(find.byKey(const ValueKey('evd-summary'))).properties.label ?? '';

    testWidgets('varsayilan: siradaki yuvarlak saat, bitis +2 saat (10:20 -> 11:00-13:00)', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _fixedNow);
      expect(summaryText(tester), contains('11:00 – 13:00'));
      expect(find.byKey(const ValueKey('evd-error')), findsNothing);
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Gelecek hafta'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget); // özel saat çipi seçili saati gösterir
      await unmount(tester);
    });

    testWidgets('gece yarisi: 21:40 -> 22:00 baslar, bitis ertesi gun 00:00 (cok gunlu ozet, gecerli)', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _at(21, 40));
      final txt = summaryText(tester);
      expect(txt, isNot(contains('·'))); // tek gunluk bicim degil
      expect(txt, contains('22:00 –'));
      expect(txt, endsWith('00:00'));
      expect(txt, contains('28'));
      expect(txt, contains('29'));
      expect(find.byKey(const ValueKey('evd-error')), findsNothing); // bitis baslangictan sonra: hata yok
      await unmount(tester);
    });

    testWidgets('gece yarisi: 23:30 -> baslangic ertesi gun 00:00, bitis 02:00 (gecerli)', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _at(23, 30));
      expect(summaryText(tester), contains('29'));
      expect(summaryText(tester), contains('00:00 – 02:00'));
      expect(find.byKey(const ValueKey('evd-error')), findsNothing);
      await unmount(tester);
    });

    testWidgets('hizli tarih + saat + sure cipleri istek govdesine yansir', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _fixedNow);
      await tester.ensureVisible(find.text('Yarın'));
      await tester.pump();
      await tester.tap(find.text('Yarın'));
      await tester.pump();
      await tester.tap(find.text('14:00'));
      await tester.pump();
      await tester.tap(find.text('Yarım gün'));
      await tester.pump();
      expect(summaryText(tester), contains('14:00 – 18:00'));
      await tester.tap(find.text('1 saat'));
      await tester.pump();
      expect(summaryText(tester), contains('14:00 – 15:00'));
      await _submit(tester);
      final body = b.bodies['POST /events'] as Map;
      final st = DateTime.parse(body['startsAt'] as String).toLocal();
      final en = DateTime.parse(body['endsAt'] as String).toLocal();
      final tmr = _fixedNow().add(const Duration(days: 1));
      expect([st.year, st.month, st.day, st.hour], [tmr.year, tmr.month, tmr.day, 14]);
      expect(en.difference(st), const Duration(hours: 1));
      await unmount(tester);
    });

    testWidgets('bugun icin gecmis saat cipi kapali, baslangic gecmise dusmez', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _fixedNow);
      await tester.ensureVisible(find.text('Bugün'));
      await tester.pump();
      await tester.tap(find.text('Bugün'));
      await tester.pump();
      final before = summaryText(tester);
      await tester.tap(find.text('09:00')); // 10:20'de gecmis saat
      await tester.pump();
      expect(summaryText(tester), before); // kapalı çip: değişmez
      expect(find.byKey(const ValueKey('evd-error')), findsNothing);
      await unmount(tester);
    });

    testWidgets('aciklama sayaci + sinir asiminda gonderme kapali', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b);
      expect(find.text('0/1000'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'a' * 124);
      await tester.pump();
      expect(find.text('124/1000'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'a' * 1005);
      await tester.pump();
      expect(find.text('1005/1000'), findsOneWidget);
      expect(find.text('Açıklama en fazla 1000 karakter olabilir.'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Boğaz yürüyüşü');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.pump();
      await tester.tap(find.text('Etkinliği oluştur'), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);
      await unmount(tester);
    });

    testWidgets('bitis tarihi ayri secilebilir (cok gunlu)', (tester) async {
      final b = _be([_club(7, 'Robotik Topluluğu', 'OWNER')]);
      await _open(tester, b, now: _fixedNow);
      await tester.ensureVisible(find.text('Bitiş tarihi seç'));
      await tester.pump();
      await tester.tap(find.text('Bitiş tarihi seç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextButton)).last);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextButton)).last);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('evd-summary')), findsOneWidget);
      await unmount(tester);
    });
  });
}
