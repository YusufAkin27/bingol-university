import 'dart:ui' show Size;
import 'package:bu_kampus/features/events/event_ticket_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Biletim: QR alınamayınca (ağ hatası) bayat QR kalmasın; sayfa kendiliğinden yeniden dener, dispose'da zamanlayıcı kalmaz.
void main() {
  setUpAll(loadTestFonts);

  testWidgets('QR ag hatasinda yeniden denenir', (t) async {
    useScreen(t, const Size(390, 844));
    final be = FakeBackend()
      ..on('/events/5/ticket', {'state': 'ACTIVE', 'attendanceOpen': true, 'title': 'Maç'})
      ..network('/events/5/my-ticket');
    final ev = {
      'id': 5,
      'title': 'Maç',
      'myRsvp': 'GOING',
      'status': 'ACTIVE',
      'endsAt': DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String(),
    };
    await t.pumpWidget(buildApp(EventTicketPage(session: makeSession(be), event: ev)));
    await settle(t, const Duration(milliseconds: 500));
    int qrCalls() => be.requests.where((r) => r.contains('/events/5/my-ticket')).length;
    final first = qrCalls();
    expect(first, greaterThan(0));
    await t.pump(const Duration(seconds: 16));
    await settle(t, const Duration(milliseconds: 300));
    expect(qrCalls(), greaterThan(first), reason: '15 sn sonra yeniden denenmeli');
    await unmount(t);
    final after = qrCalls();
    await t.pump(const Duration(seconds: 40));
    expect(qrCalls(), after, reason: 'dispose sonrası istek yok');
  });
}
