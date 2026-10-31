import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_settings_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_widgets.dart';
import 'package:bu_kampus/features/events/qr_painter.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Paket 16 (etkinlik organizator araclari + QR): 3 dil x acik/koyu x yazi 1.3 x 320/390 dp matrisi,
/// durum varyantlari, erisilebilirlik ve yeni etkilesimler.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({int? capacity = 14, int going = 9}) {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': 'Kampüs halı saha maçı ve yaz dönemi tanışma buluşması',
    'startsAt': _iso(s),
    'location': 'Kampüs halı sahası',
    'goingCount': going,
    'capacity': capacity,
    'canManage': true,
    'joinPolicy': 'APPROVAL',
    'createdBy': 2,
  };
}

Map<String, dynamic> _app(int id, String name, {String? dep, String? note}) =>
    {'id': id, 'userId': id, 'displayName': name, 'department': dep, 'note': note, 'answers': <String>[], 'status': 'PENDING'};

FakeBackend _be({Duration delay = Duration.zero, bool emptyReq = false, bool emptyAtt = false}) => FakeBackend(delay: delay)
  ..on('/events/5', _ev())
  ..on('/events/5/attendance', emptyAtt
      ? <Object>[]
      : [
          {'userId': 11, 'displayName': 'Ayşe Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'present': true, 'method': 'QR', 'markedAt': _iso(DateTime.now())},
          {'userId': 12, 'displayName': 'Can Demir', 'department': 'İşletme', 'present': false},
          {'userId': 2, 'displayName': 'Mehmet Kaya', 'present': true, 'method': 'MANUAL'},
        ])
  ..on('/events/5/checkin-code', {'code': '5.123.abcdef', 'qrPayload': 'bingol-checkin:5.123.abcdef', 'validForSeconds': 30})
  ..on('/events/5/admission', {'eventId': 5, 'mode': 'APPROVAL', 'questions': <String>[]})
  ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4})
  ..on('/events/5/requests?status=PENDING&size=50', {
    'items': emptyReq
        ? <Object>[]
        : [
            _app(21, 'Ayşe Yılmaz', dep: 'Bilgisayar Mühendisliği'),
            _app(22, 'Can Demir', dep: 'İşletme', note: 'Takıma katılmak isterim, kaleci olabilirim'),
          ],
    'nextCursor': null,
  })
  ..on('/events/5/requests?status=ACCEPTED&size=50', {'items': [_app(31, 'Mert Aksoy', dep: 'Makine Mühendisliği')], 'nextCursor': null})
  ..on('/events/5/requests?status=REJECTED&size=50', {'items': [_app(32, 'Selin Doğan', dep: 'Hukuk')], 'nextCursor': null});

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadIconFonts();
    mockSecureStorage();
  });

  final pages = <String, Widget Function(FakeBackend)>{
    'Istekler': (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev()),
    'Istekler dolu': (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(going: 14)),
    'Ayarlar': (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev()),
    'QR': (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev()),
    'Yoklama': (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev()),
  };

  for (final e in pages.entries) {
    testWidgets('${e.key}: 3 dil x tema x 1.3 x 320/390, tasma yok', (tester) async {
      await p00Matrix(tester, () => e.value(_be()), scaffold: false);
    });
  }

  group('durumlar', () {
    testWidgets('yukleniyor: iskelet (istekler/yoklama/QR)', (tester) async {
      for (final build in [
        (FakeBackend b) => Etkinlik2RequestsPage(key: UniqueKey(), session: makeSession(b), event: _ev()),
        (FakeBackend b) => Etkinlik2AttendancePage(key: UniqueKey(), session: makeSession(b), event: _ev()),
        (FakeBackend b) => Etkinlik2QrPage(key: UniqueKey(), session: makeSession(b), event: _ev()),
      ]) {
        await p00Matrix(tester, () => build(_be(delay: const Duration(milliseconds: 400))),
            scaffold: false, settleMs: 100, widths: const [320], check: (t, lang, dark, scale) async {
          expect(find.byType(BuSkeleton), findsWidgets, reason: '$lang dark=$dark x$scale');
        });
        await tester.pump(const Duration(seconds: 1));
      }
    });

    testWidgets('bos: bekleyen yok ve katilimci yok', (tester) async {
      await p00Matrix(tester, () => Etkinlik2RequestsPage(session: makeSession(_be(emptyReq: true)), event: _ev()),
          scaffold: false, widths: const [320], check: (t, lang, dark, scale) async {
        expect(find.byKey(const ValueKey('et2-req-back')), findsOneWidget);
      });
      await p00Matrix(tester, () => Etkinlik2AttendancePage(session: makeSession(_be(emptyAtt: true)), event: _ev()),
          scaffold: false, widths: const [320], check: (t, lang, dark, scale) async {
        expect(find.byKey(const ValueKey('et2-att-empty')), findsOneWidget);
      });
    });

    testWidgets('hata: yeniden dene gorunur', (tester) async {
      final be = _be()..network('/events/5/attendance');
      await p00Matrix(tester, () => Etkinlik2AttendancePage(session: makeSession(be), event: _ev()),
          scaffold: false, widths: const [320], check: (t, lang, dark, scale) async {
        expect(find.byKey(const ValueKey('et2-att-error')), findsOneWidget);
      });
      final be2 = _be()..network('/events/5/requests?status=PENDING&size=50');
      await p00Matrix(tester, () => Etkinlik2RequestsPage(session: makeSession(be2), event: _ev()),
          scaffold: false, widths: const [320], check: (t, lang, dark, scale) async {
        expect(find.byKey(const ValueKey('et2-req-error')), findsOneWidget);
      });
    });

    testWidgets('animasyonlar azaltilmis: istisna yok', (tester) async {
      await p00Matrix(tester, () => Etkinlik2AttendancePage(session: makeSession(_be()), event: _ev()),
          scaffold: false, widths: const [390], disableAnimations: true);
      await p00Matrix(tester, () => Etkinlik2QrPage(session: makeSession(_be()), event: _ev()),
          scaffold: false, widths: const [390], disableAnimations: true);
    });
  });

  group('erisilebilirlik', () {
    for (final dark in [false, true]) {
      for (final e in pages.entries) {
        testWidgets('${e.key} ${dark ? 'koyu' : 'acik'}: dokunma hedefi + etiket + kontrast', (tester) async {
          final h = tester.ensureSemantics();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(p00App(e.value(_be()), dark: dark, scaffold: false));
          await tester.pump(const Duration(milliseconds: 1200));
          await tester.pump(const Duration(milliseconds: 1200));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          h.dispose();
        });
      }
    }
  });

  group('etkilesimler', () {
    testWidgets('QR: kodu kopyala panoya yazar ve bildirir', (tester) async {
      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(Etkinlik2QrPage(session: makeSession(_be()), event: _ev()), scaffold: false));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('et2-manual-code')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clip, '5.123.abcdef');
      expect(find.text('Kod kopyalandı'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('QR: sure dolunca "yenileniyor" katmani cikar', (tester) async {
      var skew = Duration.zero;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final be = _be()..on('/events/5/checkin-code', {'code': 'X.1', 'qrPayload': 'bingol-checkin:X.1', 'validForSeconds': 10});
      await tester.pumpWidget(p00App(
          Etkinlik2QrPage(session: makeSession(be), event: _ev(), now: () => DateTime.now().add(skew)),
          scaffold: false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Kod '), findsWidgets);
      skew = const Duration(seconds: 11);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('Süresi doldu, yenileniyor…'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('yoklama: suzge bos sonucu gosterir', (tester) async {
      final be = _be();
      be.on('/events/5/attendance', [
        {'userId': 11, 'displayName': 'Ayşe Yılmaz', 'present': true, 'method': 'QR'},
      ]);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(Etkinlik2AttendancePage(session: makeSession(be), event: _ev()), scaffold: false));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('et2-filter-absent')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bu filtreye uygun katılımcı kaydı bulunamadı.'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('segment ve anahtar: kayarak degisir, devre disiyken dokunulmaz', (tester) async {
      var v = 'A';
      var on = false;
      await tester.pumpWidget(p00App(StatefulBuilder(builder: (c, set) {
        return Column(children: [
          Et2Segment<String>(value: v, options: const [('A', 'Bir'), ('B', 'Iki')], onChanged: (x) => set(() => v = x)),
          Et2Toggle(value: on, label: 'Ac', onChanged: (x) => set(() => on = x)),
          const Et2Toggle(value: false, label: 'Kapali', onChanged: null),
        ]);
      })));
      await tester.tap(find.text('Iki'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(v, 'B');
      await tester.tap(find.byType(Switch).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(on, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);
    });

    testWidgets('QrPainter: renkler belirtecten gelir, kodlanamayan veri yedek gosterir', (tester) async {
      await tester.pumpWidget(p00App(Column(children: [
        const QrView(data: 'bingol-checkin:5.123.abc', size: 120),
        QrView(data: 'a' * 300, size: 10, fallback: const Text('YEDEK')),
      ])));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('YEDEK'), findsOneWidget);
    });
  });
}
