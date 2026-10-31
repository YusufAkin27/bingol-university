import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:bu_kampus/features/events/etkinlik_parts.dart';
import 'package:bu_kampus/features/events/event_parts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

const _longTitle = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';

Map<String, dynamic> _ev(int id,
    {String? title,
    String? rsvp,
    bool manage = false,
    bool closed = false,
    String status = 'ACTIVE',
    int days = 2,
    String? cover,
    int going = 4}) {
  final s = DateTime.now().add(Duration(days: days));
  return {
    'id': id,
    'source': 'USER',
    'title': title ?? 'Etkinlik $id',
    'description': 'Açıklama',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Konferans Salonu',
    'communityName': 'Robotik Topluluğu',
    'goingCount': going,
    'myRsvp': rsvp,
    'canManage': manage,
    'registrationClosed': closed,
    'status': status,
    'coverUrl': cover,
  };
}

List<Map<String, dynamic>> _calendar() {
  final now = DateTime.now();
  final s = DateTime(now.year, now.month, now.day, 23, 30);
  return [
    {..._ev(5, title: _longTitle), 'startsAt': _iso(s), 'endsAt': _iso(s.add(const Duration(minutes: 20)))},
    {
      'id': 9,
      'source': 'OFFICIAL',
      'title': 'Resmi duyuru etkinliği',
      'date':
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    },
  ];
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items, [int? next]) => {'items': items, 'nextCursor': next};

FakeBackend _backend({bool closed = false}) => FakeBackend()
  ..on('/events/calendar*', _calendar(), headers: {'x-truncated': 'false'})
  ..on('/me/events?mode=attending&size=20', _page([_ev(5, title: 'Katıldığım etkinlik', rsvp: 'GOING')]))
  ..on('/me/events?mode=past&size=20', _page([_ev(3, title: 'Bitmiş etkinlik', rsvp: 'GOING', days: -3)]))
  ..on('/me/events?mode=organizing&size=20', _page([_ev(8, title: 'Benim etkinliğim', manage: true, closed: closed)]));

Future<void> _open(WidgetTester tester, FakeBackend b,
    {Size size = kPhoneMedium, Brightness br = Brightness.light, int tab = 0}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b), initialTab: tab), brightness: br, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _tapText(WidgetTester tester, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester, const Duration(milliseconds: 400));
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Seçenekler').first);
  await settle(tester, const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadTestFonts);

  group('Etkinlikler sayfasi', () {
    testWidgets('3 esit segment ve sabit (pinned) cubuk', (tester) async {
      await _open(tester, _backend());
      expect(find.text('Keşfet'), findsOneWidget);
      expect(find.text('Etkinliklerim'), findsOneWidget);
      expect(find.text('Oluşturduklarım'), findsOneWidget);
      expect(find.byTooltip('Etkinlik oluştur'), findsOneWidget);
      expect(find.byType(ClubTextTabs), findsOneWidget); // metin sekmeleri (Stitch v3)
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('resmi etkinlik ayri sade satir, Katil dugmesi yok', (tester) async {
      await _open(tester, _backend());
      expect(find.text('Resmi duyuru etkinliği'), findsOneWidget);
      expect(find.text('Katıl'), findsOneWidget); // yalnizca kullanici etkinligi
      await unmount(tester);
    });

    testWidgets('Katil: PUT, durum cipi "Etkinliklerimde", geri alma YOK', (tester) async {
      final b = _backend();
      await _open(tester, b);
      expect(find.text('Katılıyorum'), findsNothing);
      await _tapText(tester, 'Katıl');
      expect(b.requests, contains('PUT /events/5/rsvp'));
      expect((b.bodies['PUT /events/5/rsvp'] as Map)['status'], 'GOING');
      expect(find.text('Katılıyorsun'), findsOneWidget); // satir ici durum metni (tiklanmaz, geri almaz)
      expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
      // Etkinliklerim sekmesini ac.
      await _tapText(tester, 'Etkinliklerim');
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse);
      expect(find.text('Geçmiş'), findsOneWidget); // alt cipler
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('snackbar kisayolu Etkinliklerim sekmesini acar', (tester) async {
      final b = _backend();
      await _open(tester, b);
      await _tapText(tester, 'Katıl');
      await tester.tap(find.text('Etkinliklerim').last); // SnackBarAction
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kayitlar kapali: 409 mesaji gosterilir, kart "Kayitlar kapali" olur', (tester) async {
      final b = _backend()..fail('/events/5/rsvp', status: 409, code: 'EVENT_REGISTRATION_CLOSED', message: 'Bu etkinliğin kayıtları kapalı.');
      await _open(tester, b);
      await _tapText(tester, 'Katıl');
      expect(find.text('Bu etkinliğin kayıtları kapalı.'), findsOneWidget);
      expect(find.text('Katılıyorsun'), findsNothing);
      expect(find.text('Kayıt kapalı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Etkinliklerim: Katilimdan ayril yalnizca menu + onayla DELETE', (tester) async {
      final b = _backend();
      await _open(tester, b, tab: 1);
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      expect(find.text('Katıl'), findsNothing);
      await _menu(tester);
      await tester.tap(find.text('Katılımdan ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse); // onay bekliyor
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse);
      await _menu(tester);
      await tester.tap(find.text('Katılımdan ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /events/5/rsvp'));
      expect(find.text('Katıldığım etkinlik'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Gecmis alt cipi bitmis etkinlikleri getirir', (tester) async {
      final b = _backend();
      await _open(tester, b, tab: 1);
      await _tapText(tester, 'Geçmiş');
      expect(b.requests, contains('GET /me/events?mode=past&size=20'));
      expect(find.text('Bitmiş etkinlik'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Olusturduklarim: durum etiketi ve close/reopen/cancel istekleri', (tester) async {
      final b = _backend();
      await _open(tester, b);
      await _tapText(tester, 'Oluşturduklarım');
      expect(find.text('Benim etkinliğim'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);

      await _menu(tester);
      await tester.tap(find.text('Kayıtları kapat'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('POST /events/8/close'));

      // Sunucu artik kapali donuyor.
      b.on('/me/events?mode=organizing&size=20', _page([_ev(8, title: 'Benim etkinliğim', manage: true, closed: true)]));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Kayıt kapalı'), findsOneWidget);
      await _menu(tester);
      await tester.tap(find.text('Kayıtları yeniden aç'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('POST /events/8/reopen'));

      await _menu(tester);
      await tester.tap(find.text('İptal et'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Bu etkinlik tüm katılımcılar için iptal edilecek.'), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse);
      await tester.tap(find.text('İptal et').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /events/8'));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Olusturduklarim bos: olustur dugmesi', (tester) async {
      final b = FakeBackend()
        ..on('/events/calendar*', <Object>[])
        ..on('/me/communities*', {'items': [{'id': 7, 'name': 'K', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]})
        ..on('/me/events*', _page([]));
      await _open(tester, b, tab: 2);
      expect(find.text('Henüz bir etkinlik oluşturmadın.'), findsOneWidget);
      expect(find.text('Etkinlik oluştur'), findsWidgets); // başlık düğmesi + boş durum düğmesi
      await unmount(tester);
    });

    testWidgets('Olusturduklarim bos + kulup yok: "kulubun yoneticisi olmalisin" karti', (tester) async {
      final b = FakeBackend()
        ..on('/events/calendar*', <Object>[])
        ..on('/me/communities*', {'items': <Object>[]})
        ..on('/me/events*', _page([]));
      await _open(tester, b, tab: 2);
      expect(find.text('Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın'), findsOneWidget);
      expect(find.text('Kulüplere göz at'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sonsuz kaydirma: imlec ile ikinci sayfa yuklenir', (tester) async {
      final first = [for (var i = 1; i <= 6; i++) _ev(100 + i, title: 'Birinci sayfa $i', rsvp: 'GOING')];
      final b = FakeBackend()
        ..on('/events/calendar*', <Object>[])
        ..on('/me/events?mode=attending&size=20', _page(first, 99))
        ..on('/me/events?mode=attending&size=20&cursor=99', _page([_ev(200, title: 'Ikinci sayfa', rsvp: 'GOING')]));
      await _open(tester, b, tab: 1);
      for (var i = 0; i < 12 && !b.requests.contains('GET /me/events?mode=attending&size=20&cursor=99'); i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await settle(tester, const Duration(milliseconds: 300));
      }
      expect(b.requests, contains('GET /me/events?mode=attending&size=20&cursor=99'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Ikinci sayfa'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata -> Yeniden dene; yukleniyor iskeleti', (tester) async {
      final b = _backend()..delay = const Duration(milliseconds: 300);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b), initialTab: 1), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Katıldığım etkinlik'), findsNothing);
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Katıldığım etkinlik'), findsOneWidget);
      b.fail('/me/events?mode=organizing&size=20');
      b.delay = Duration.zero;
      await _tapText(tester, 'Oluşturduklarım');
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('etkinlik detayi', () {
    FakeBackend backend({String? rsvp, bool manage = false, bool closed = false}) => FakeBackend()
      ..on('/events/5', _ev(5, title: 'Detay etkinliği', rsvp: rsvp, manage: manage, closed: closed))
      ..on('/events/5/attendees/preview', {'goingCount': 4, 'avatars': <Object>[]})
      ..on('/events/5/attendees*', _page([]))
      ..on('/events/5/attendance', <Object>[])
      ..on('/events/5/checkin-code', {'code': '5.1.a', 'qrPayload': 'bingol-checkin:5.1.a', 'validForSeconds': 30})
      ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false});

    Future<void> openDetail(WidgetTester tester, FakeBackend b, {Size size = kPhoneMedium}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: size));
      await settle(tester, const Duration(milliseconds: 800));
    }

    testWidgets('Katil -> PUT, "Katiliyorum/Katiliyorsun" yazmaz', (tester) async {
      final b = backend();
      await openDetail(tester, b);
      expect(find.text('Katıl'), findsOneWidget);
      expect(find.text('Katılıyorum'), findsNothing);
      await tester.tap(find.text('Katıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('PUT /events/5/rsvp'));
      await unmount(tester);
    });

    testWidgets('katilmis: "Etkinliklerimde" cipi geri almaz; Katilimi yonet onayla DELETE', (tester) async {
      final b = backend(rsvp: 'GOING');
      await openDetail(tester, b);
      expect(find.text('Katılıyorsun'), findsOneWidget); // alt çubukta durum metni
      // Ayrılmak alttaki sabit "Katılımdan ayrıl" düğmesiyle, onayla yapılır.
      await tester.tap(find.byKey(const ValueKey('detail-leave')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse); // onay bekler
      await tester.tap(find.text('Ayrıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /events/5/rsvp'));
      await unmount(tester);
    });

    testWidgets('kapali etkinlik: Katil yerine "Kayitlar kapali"; 409 mesaji', (tester) async {
      final b = backend(closed: true);
      await openDetail(tester, b);
      expect(find.text('Kayıtlar kapalı'), findsWidgets);
      // Kayıtlar kapalıyken iki düğme de pasif (tek "Kayıtlar kapandı" düğmesi yok).
      expect(tester.widget<BuButton>(find.byKey(const ValueKey('detail-join'))).onPressed, isNull);
      expect(tester.widget<ClubOutlineButton>(find.descendant(of: find.byKey(const ValueKey('detail-interested')), matching: find.byType(ClubOutlineButton))).onPressed, isNull);
      final b2 = backend()
        ..fail('/events/5/rsvp', status: 409, code: 'EVENT_REGISTRATION_CLOSED', message: 'Bu etkinliğin kayıtları kapalı.');
      await unmount(tester);
      await openDetail(tester, b2);
      await tester.tap(find.text('Katıl'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Bu etkinliğin kayıtları kapalı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yonetici Yonet menusu: kapat ve iptal', (tester) async {
      final b = backend(manage: true);
      await openDetail(tester, b);
      await tester.tap(find.byTooltip('Yönet'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Kayıtları kapat'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('POST /events/5/close'));
      await tester.tap(find.byTooltip('Yönet'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('İptal et'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('İptal et').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /events/5'));
      await unmount(tester);
    });
  });

  group('ana sayfa karti', () {
    // Stitch v3: ana sayfa satiri yalniz bilgi + detaya gider; katilma/geri alma etkinlik detayinda (ana sayfada RSVP yok).
    testWidgets('satir: Katil dugmesi yok, RSVP/DELETE istegi atilmaz', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()..on('/events/featured', {..._ev(5), 'capacity': 50});
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Katıl'), findsNothing);
      expect(find.text('Etkinliklerimde'), findsNothing);
      expect(b.requests.any((r) => r.startsWith('PUT') || r.startsWith('DELETE')), isFalse);
      await unmount(tester);
    });
  });

  group('tema x ekran: tasma yok', () {
    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        for (final tab in [0, 1, 2]) {
          testWidgets('sekme $tab ${br.name} ${size.width.toInt()}', (tester) async {
            final b = _backend();
            b.on('/me/events?mode=organizing&size=20', _page([
              _ev(8, title: _longTitle, manage: true, closed: true, cover: '/files/e.jpg'),
              _ev(9, title: 'İptal', manage: true, status: 'CANCELLED'),
            ]));
            await _open(tester, b, size: size, br: br, tab: tab);
            expect(tester.takeException(), isNull);
            for (var i = 0; i < 3; i++) {
              await tester.drag(find.byType(CustomScrollView), const Offset(0, -300), warnIfMissed: false);
              await settle(tester, const Duration(milliseconds: 200));
              expect(tester.takeException(), isNull);
            }
            await unmount(tester);
          });
        }
      }
    }
  });
}
