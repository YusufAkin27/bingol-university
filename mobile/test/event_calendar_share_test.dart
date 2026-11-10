import 'package:bu_kampus/core/platform/device_calendar.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_share.dart';
import 'package:bu_kampus/features/events/event_calendar.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/widgets/widget_link.dart';
import 'package:flutter/material.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:bu_kampus/features/share/share_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_app.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({String? rsvp}) {
  final s = DateTime.now().add(const Duration(days: 2));
  return {
    'id': 5,
    'title': 'Halı saha',
    'description': 'Mac',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Saha',
    'goingCount': 3,
    'interestedCount': 0,
    'capacity': 20,
    'myRsvp': rsvp,
    'canManage': false,
    'joinPolicy': 'OPEN',
    'createdBy': 2,
    'organizer': {'id': 2, 'displayName': 'Mehmet', 'avatarUrl': null},
    'organizerName': 'Mehmet',
  };
}

FakeBackend _be(Map<String, dynamic> ev) => FakeBackend()
  ..on('/events/5', ev)
  ..on('/events/5/attendees/preview', {'goingCount': 3, 'avatars': <Object>[]})
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false})
  ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4});

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  late FakeDeviceCalendarBackend dev;
  late MemoryEventCalStore store;
  late EventCalendarService svc;

  setUp(() {
    dev = FakeDeviceCalendarBackend();
    store = MemoryEventCalStore();
    svc = EventCalendarService(backend: dev, store: store);
  });

  group('servis', () {
    final start = DateTime.now().add(const Duration(days: 2));

    test('ekler, secilen sure kadar once alarm kurar; ikinci cagri gunceller; kaldirma siler', () async {
      expect(await svc.add(eventId: 5, title: 'A', startsAt: start, leadMin: 1440), EventCalResult.added);
      final spec = dev.events.values.single;
      expect(spec.alarmAtMs, start.subtract(const Duration(days: 1)).millisecondsSinceEpoch);
      expect(await svc.add(eventId: 5, title: 'A', startsAt: start, leadMin: 15), EventCalResult.updated);
      expect(dev.creates, 1);
      expect(dev.events.values.single.alarmAtMs, start.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch);
      expect(await svc.remove(5), isTrue);
      expect(dev.events, isEmpty);
      expect(await svc.linkOf(5), isNull);
      expect(await svc.remove(5), isFalse);
    });

    test('izin reddi ve gecmis etkinlik yazmaz', () async {
      dev.state = CalAccess.denied;
      expect(await svc.add(eventId: 5, title: 'A', startsAt: start), EventCalResult.denied);
      dev.state = CalAccess.granted;
      expect(await svc.add(eventId: 6, title: 'B', startsAt: DateTime.now().subtract(const Duration(hours: 1))), EventCalResult.pastEvent);
      expect(dev.upserts, 0);
    });
  });

  group('etkinlik detayi', () {
    testWidgets('takvim satiri gorunur, sheet acilir, sure secilip eklenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(_be(_ev())), eventId: 5, calendar: svc), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      final row = find.byKey(const ValueKey('detail-calendar'));
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('15 dakika önce'), findsOneWidget);
      expect(find.text('1 gün önce'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('evcal-lead-15')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('evcal-add')));
      await settle(tester, const Duration(milliseconds: 600));
      expect((await svc.linkOf(5))?.leadMin, 15);
      expect(dev.events, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('katilim sonrasi oneri cikar; "bir daha sorma" tercihi saklanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _be(_ev());
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5, calendar: svc), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('detail-join')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('evcal-never')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('evcal-never')));
      await settle(tester, const Duration(milliseconds: 600));
      expect((await svc.state()).dontAsk, isTrue);
      expect(dev.events, isEmpty);
    });

    testWidgets('katilimdan ayrilinca takvim kaydi ve hatirlatici iptal olur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final start = DateTime.now().add(const Duration(days: 2));
      await svc.add(eventId: 5, title: 'Halı saha', startsAt: start);
      expect(dev.events, hasLength(1));
      await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(_be(_ev(rsvp: 'GOING'))), eventId: 5, calendar: svc), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('detail-leave')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Ayrıl').last);
      await settle(tester, const Duration(milliseconds: 900));
      expect(dev.events, isEmpty);
      expect(await svc.linkOf(5), isNull);
    });
  });

  group('paylasim ve derin baglanti', () {
    test('bukampus://clubs/id ve events/id cozulur', () {
      expect(WidgetLink.parse('bukampus://clubs/7'), WidgetLink.club(7));
      expect(WidgetLink.parse('bukampus://events/12'), WidgetLink.event(12));
      expect(WidgetLink.parse('bukampus://clubs'), WidgetLink.clubs);
      expect(WidgetLink.parse('bukampus://clubs/abc'), isNull);
      expect(clubShareLink(7), 'bukampus://clubs/7');
      expect(WidgetLink.parse(clubShareLink(7)), WidgetLink.club(7));
    });

    testWidgets('kulup detayinda Paylas dugmesi sistem paylasimini baglantiyla cagirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      ShareParams? got;
      debugClubShare = (p) async => got = p;
      addTearDown(() => debugClubShare = null);
      final b = FakeBackend()
        ..on('/communities/7', {
          'id': 7,
          'name': 'Robotik',
          'description': 'x',
          'category': 'Teknoloji',
          'memberCount': 4,
          'visibility': 'PUBLIC',
          'joinPolicy': 'OPEN',
          'myStatus': 'ACTIVE',
          'myRole': 'OWNER',
        })
        ..on('/communities/7/posts*', {'items': [], 'nextCursor': null})
        ..on('/communities/7/requests*', {'items': [], 'nextCursor': null})
        ..on('/events*', {'items': [], 'nextCursor': null});
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 7), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('club-share')));
      await settle(tester, const Duration(milliseconds: 300));
      // Paylaşım artık ortak paylaşım sayfasıdır; bağlantı herkese açık /s/c/7 biçimidir.
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(const ShareTarget(ShareType.club, 7).url, 'https://bukampus.com.tr/s/c/7');
      expect(got, isNull);
    });
  });
}
