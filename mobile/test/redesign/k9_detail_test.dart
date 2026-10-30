import 'package:bu_kampus/features/events/etkinlik_parts.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K9 (etkinlik detayi, 38/39/41-01): durum matrisi (3 dil x tema x 1.3 x 320/390), alt cubuk dugmeleri,
/// katilma istegi sayfasi, yoklama (elle kod hatasi/basari), organizator bolumu.
Map<String, dynamic> _ev({
  String? rsvp,
  int going = 34,
  int? cap = 50,
  bool closed = false,
  String status = 'ACTIVE',
  String policy = 'OPEN',
  bool manage = false,
  int? pending,
}) {
  final st = DateTime.now().add(const Duration(days: 10));
  return {
    'id': 5,
    'title': 'Bahar Şenliği',
    'description': 'Açık hava sahnesinde akustik dinletiler.',
    'startsAt': st.toUtc().toIso8601String(),
    'endsAt': st.add(const Duration(hours: 3)).toUtc().toIso8601String(),
    'location': 'Açık Hava Sahnesi',
    'communityId': 7,
    'communityName': 'Müzik Kulübü',
    'goingCount': going,
    'interestedCount': 12,
    if (cap != null) 'capacity': cap,
    'myRsvp': rsvp,
    'status': status,
    'registrationClosed': closed,
    'joinPolicy': policy,
    'canManage': manage,
    if (pending != null) 'pendingCount': pending,
    'createdBy': 2,
  };
}

FakeBackend _be(Map<String, dynamic> ev, {bool open = false, bool present = false}) => FakeBackend()
  ..on('/events/5', ev)
  ..on('/events/5/my-attendance', {'present': present, 'checkInOpen': open})
  ..on('/events/5/admission', {'eventId': 5, 'mode': ev['joinPolicy'], 'questions': ['Neden katılmak istiyorsun?']})
  ..on('/events/5/attendance', [
    for (var i = 0; i < 4; i++) {'userId': 100 + i, 'displayName': 'K $i', 'present': i < 1},
  ]);

Widget _page(FakeBackend b) => EventDetailPage(session: makeSession(b), eventId: 5);

Future<void> _show(WidgetTester tester, FakeBackend b, {double h = 2000}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, h);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(p00App(_page(b), scaffold: false));
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadIconFonts();
    mockSecureStorage();
  });

  final states = <String, FakeBackend Function()>{
    'acik': () => _be(_ev()),
    'katiliyor': () => _be(_ev(rsvp: 'GOING')),
    'ilgileniyor': () => _be(_ev(rsvp: 'INTERESTED')),
    'dolu': () => _be(_ev(going: 50)),
    'kapali': () => _be(_ev(closed: true)),
    'iptal': () => _be(_ev(status: 'CANCELLED')),
    'istek_bekliyor': () => _be(_ev(policy: 'APPROVAL', rsvp: 'PENDING')),
    'istek_reddedildi': () => _be(_ev(policy: 'APPROVAL', rsvp: 'REJECTED')),
    'onaylandi_yoklama_acik': () => _be(_ev(policy: 'APPROVAL', rsvp: 'GOING'), open: true),
    'yoklama_alindi': () => _be(_ev(rsvp: 'GOING'), open: true, present: true),
    'organizator': () => _be(_ev(policy: 'APPROVAL', manage: true, pending: 3)),
  };
  for (final e in states.entries) {
    testWidgets('detay ${e.key}: 3 dil x tema x 1.3 x 320/390, tasma yok', (tester) async {
      await p00Matrix(tester, () => _page(e.value()), scaffold: false, widths: const [320, 390]);
    });
  }

  group('alt cubuk', () {
    testWidgets('kayit acik: Ilgileniyorum + Katil aktif; Katil PUT GOING', (tester) async {
      final b = _be(_ev());
      b.on('/events/5/rsvp', {'myRsvp': 'GOING', 'goingCount': 35, 'capacity': 50});
      await _show(tester, b);
      expect(tester.widget<EtkinlikActionButton>(find.byKey(const ValueKey('detail-join'))).onTap, isNotNull);
      expect(tester.widget<EtkinlikActionButton>(find.byKey(const ValueKey('detail-interested'))).onTap, isNotNull);
      await tester.tap(find.byKey(const ValueKey('detail-join')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(b.bodies['PUT /events/5/rsvp'], {'status': 'GOING'});
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('kontenjan dolu: yalniz Ilgileniyorum aktif, Katil pasif', (tester) async {
      await _show(tester, _be(_ev(going: 50)));
      expect(tester.widget<EtkinlikActionButton>(find.byKey(const ValueKey('detail-join'))).onTap, isNull);
      expect(tester.widget<EtkinlikActionButton>(find.byKey(const ValueKey('detail-interested'))).onTap, isNotNull);
      expect(find.text('Kontenjan doldu; yine de ilgilendiğini belirtebilirsin.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ilgileniyor: secili dugmeye dokununca ilgi geri alinir (DELETE rsvp), onaysiz', (tester) async {
      final b = _be(_ev(rsvp: 'INTERESTED'));
      await _show(tester, b);
      await tester.tap(find.byKey(const ValueKey('detail-interested')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(b.requests, contains('DELETE /events/5/rsvp'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('iptal edildi: alt cubuk yok, bildirim var, sohbet satiri yok', (tester) async {
      await _show(tester, _be(_ev(status: 'CANCELLED')));
      expect(find.byKey(const ValueKey('detail-join')), findsNothing);
      expect(find.byKey(const ValueKey('detail-cancelled')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-chat')), findsNothing);
      expect(find.text('Bu etkinlik iptal edildi.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('yoklama', () {
    testWidgets('saatten once: kilitli metin; QR/kod yok', (tester) async {
      await _show(tester, _be(_ev(rsvp: 'GOING')));
      expect(find.text('Yoklama etkinlik saatinde açılır.'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-scan')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('acik: elle kod: baska etkinlik hatasi alanin altinda; dogru kod basari karti', (tester) async {
      final b = _be(_ev(rsvp: 'GOING'), open: true);
      b.on('/events/5/check-in', {'present': true, 'checkInOpen': true});
      await _show(tester, b);
      expect(find.byKey(const ValueKey('detail-scan')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-enter-code')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byKey(const ValueKey('detail-code-field')), '9.123.abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bu kod başka bir etkinliğe ait.'), findsOneWidget);
      expect(b.requests.where((r) => r.contains('check-in')), isEmpty);
      await tester.enterText(find.byKey(const ValueKey('detail-code-field')), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bu bir yoklama kodu değil.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('detail-code-field')), '5.123.abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
      expect(b.bodies['POST /events/5/check-in'], {'code': '5.123.abc'});
      expect(find.byKey(const ValueKey('detail-checked-in')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('istek ile katilim', () {
    testWidgets('sorular varsa sayfa acilir; bos gonderim hata satiri; Vazgec kapatir', (tester) async {
      final b = _be(_ev(policy: 'APPROVAL', cap: 45, going: 12));
      b.handlers.add((req, path) {
        if (req.method == 'PUT' && path == '/events/5/rsvp') {
          return const FakeResult.json({'code': 'ANSWERS_REQUIRED', 'message': 'x'}, status: 400);
        }
        return null;
      });
      await _show(tester, b, h: 900);
      await tester.ensureVisible(find.byKey(const ValueKey('et2-request-send')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('et2-request-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Neden katılmak istiyorsun?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('et2-apply-send')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('et2-apply-error')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('et2-apply-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('et2-apply-error')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('reddedildi: Etkinlikleri kesfet dugmesi; sohbet kilitli', (tester) async {
      await _show(tester, _be(_ev(policy: 'APPROVAL', rsvp: 'REJECTED')));
      expect(find.text('İsteğin reddedildi'), findsOneWidget);
      expect(find.byKey(const ValueKey('et2-browse')), findsOneWidget);
      expect(find.byKey(const ValueKey('et2-chat-locked')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
