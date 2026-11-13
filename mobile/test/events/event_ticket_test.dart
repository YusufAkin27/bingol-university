import 'package:bu_kampus/features/events/event_ticket_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 10, 12);

  group('ticketAvailability', () {
    Map<String, dynamic> ev({String? rsvp = 'GOING', String status = 'ACTIVE', String end = '2026-11-10T18:00:00Z'}) => {'myRsvp': rsvp, 'status': status, 'endsAt': end};

    test('yalniz GOING bilet alir', () {
      expect(ticketAvailability(ev(), now: now), TicketAvailability.valid);
      for (final r in [null, 'INTERESTED', 'PENDING', 'REJECTED']) {
        expect(ticketAvailability(ev(rsvp: r), now: now), TicketAvailability.notGoing, reason: '$r');
      }
    });
    test('iptal ve gecmis devre disi', () {
      expect(ticketAvailability(ev(status: 'CANCELLED'), now: now), TicketAvailability.cancelled);
      expect(ticketAvailability(ev(end: '2026-11-10T11:00:00Z'), now: now), TicketAvailability.ended);
      expect(ticketAvailability(ev(), now: now, serverState: 'CANCELLED'), TicketAvailability.cancelled);
      expect(ticketAvailability(ev(), now: now, serverState: 'ENDED'), TicketAvailability.ended);
    });
  });

  group('EventTicketStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('hesap bazli: baska kullanici gormez, clear siler', () async {
      await EventTicketStore.save(7, 5, {'title': 'A'}, qr: 'bingol-ticket:x', qrExpiresAt: '2026-11-10T12:05:00Z');
      expect((await EventTicketStore.load(7, 5))!['qr'], 'bingol-ticket:x');
      expect(await EventTicketStore.load(8, 5), isNull);
      await EventTicketStore.save(7, 5, {'title': 'A2'}); // QR'siz kayit onceki QR'i korur
      expect((await EventTicketStore.load(7, 5))!['qr'], 'bingol-ticket:x');
      await EventTicketStore.clear();
      expect(await EventTicketStore.load(7, 5), isNull);
    });

    test('en cok 20 bilet tutulur', () async {
      for (var i = 0; i < 25; i++) {
        await EventTicketStore.save(7, i, {'title': '$i'});
      }
      var n = 0;
      for (var i = 0; i < 25; i++) {
        if (await EventTicketStore.load(7, i) != null) n++;
      }
      expect(n, EventTicketStore.maxTickets);
    });
  });
}
