import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/scan/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _payload = 'bingol-lesson:42.368000000.AbC_-defGhIjKlMnOpQrSt';
const _fresh = 'bingol-lesson:42.368000001.ZyXwVuTsRqPoNmLkJiHg';
const _path = '/attendance/scan';

void main() {
  setUpAll(loadTestFonts);

  group('tarayıcı: ders yoklama akışı', () {
    late FakeBackend be;

    Future<void> open(WidgetTester tester) async {
      be = FakeBackend();
      final perms = FakePermissionService(initial: {AppPermission.camera: PermState.granted});
      useScreen(tester, kPhoneMedium);
      final session = makeSession(be);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              key: const ValueKey('go'),
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                builder: (_) => QrScanHubPage(
                  session: session,
                  permissionService: perms,
                  scannerBuilder: (c, onValue) => Column(children: [
                    TextButton(key: const ValueKey('scan-lesson'), onPressed: () => onValue(_payload), child: const Text('a')),
                    TextButton(key: const ValueKey('scan-fresh'), onPressed: () => onValue(_fresh), child: const Text('f')),
                    TextButton(key: const ValueKey('scan-bad'), onPressed: () => onValue('bingol-lesson:zzz'), child: const Text('b')),
                  ]),
                ),
              )),
              child: const Text('go'),
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await tester.tap(find.byKey(const ValueKey('go')));
      await settle(tester, const Duration(milliseconds: 500));
    }

    testWidgets('MARKED: ham kod gönderilir, ders adı gösterilir, tarayıcı kapanır, çift okuma tek istek', (tester) async {
      await open(tester);
      be.on(_path, {'status': 'MARKED', 'courseName': 'Matematik 101', 'lessonDate': '2026-11-14'});
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await tester.tap(find.byKey(const ValueKey('scan-lesson')), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('POST $_path'), 1);
      expect(be.bodies['POST $_path'], {'code': _payload});
      expect(find.byType(QrScanHubPage), findsNothing);
      expect(find.text('Yoklama alındı: Matematik 101'), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('ALREADY: hata değil, "zaten alınmış" mesajı ve ders adı, tarayıcı kapanır', (tester) async {
      await open(tester);
      be.on(_path, {'status': 'ALREADY', 'courseName': 'Fizik 102', 'lessonDate': '2026-11-14'});
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(QrScanHubPage), findsNothing);
      expect(find.textContaining('zaten alınmış'), findsOneWidget);
      expect(find.textContaining('Fizik 102'), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('PENDING: bilgi mesajı, tarayıcı kapanır', (tester) async {
      await open(tester);
      be.on(_path, {'status': 'PENDING', 'courseName': 'Fizik 102', 'lessonDate': '2026-11-14'});
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(QrScanHubPage), findsNothing);
      expect(find.textContaining('öğretim elemanına iletildi'), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('bilinmeyen durum: nötr "okutma alındı", çökmez', (tester) async {
      await open(tester);
      be.on(_path, {'status': 'SOMETHING_NEW', 'courseName': 'Fizik 102', 'lessonDate': '2026-11-14'});
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(QrScanHubPage), findsNothing);
      expect(find.text('Okutma alındı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('422: "süresi doldu" mesajı, tarayıcı açık kalır; aynı bayat kod tekrar gönderilmez, taze kod hemen gönderilir', (tester) async {
      await open(tester);
      be.fail(_path, status: 422, code: 'ATTENDANCE_CODE_INVALID', message: 'Kod geçersiz.');
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(QrScanHubPage), findsOneWidget);
      expect(find.textContaining('Ekrandaki kodu yeniden okut'), findsOneWidget);
      expect(be.count('POST $_path'), 1);
      // Kamera aynı bayat kodu art arda okur: sunucuya yeniden gitmez (10/dk sınırı tükenmesin).
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('scan-lesson')));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(be.count('POST $_path'), 1);
      // Farklı (taze) kod beklemeden gönderilir.
      be.on(_path, {'status': 'MARKED', 'courseName': 'Matematik 101', 'lessonDate': '2026-11-14'});
      await tester.tap(find.byKey(const ValueKey('scan-fresh')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('POST $_path'), 2);
      expect(be.bodies['POST $_path'], {'code': _fresh});
      expect(find.byType(QrScanHubPage), findsNothing);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('403: derste kayıtlı değil mesajı, tarayıcı açık kalır', (tester) async {
      await open(tester);
      be.fail(_path, status: 403, code: 'ATTENDANCE_NOT_ENROLLED', message: 'Sunucu metni.');
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(QrScanHubPage), findsOneWidget);
      expect(find.textContaining('yoklama listesinde görünmüyorsun'), findsOneWidget);
      await settle(tester, const Duration(seconds: 4));
    });

    testWidgets('403 ATTENDANCE_REVOKED: kaldırıldı mesajı, tarayıcı kapanır', (tester) async {
      await open(tester);
      be.fail(_path, status: 403, code: 'ATTENDANCE_REVOKED');
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(QrScanHubPage), findsNothing);
      expect(find.textContaining('öğretim elemanı tarafından kaldırıldı'), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('429: bekleme mesajı, tarayıcı açık kalır, süre dolana dek yeni kod bile gönderilmez', (tester) async {
      await open(tester);
      be.on(_path, {'code': 'RATE_LIMITED', 'message': ''}, status: 429, headers: {'retry-after': '30'});
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(QrScanHubPage), findsOneWidget);
      expect(find.textContaining('Çok fazla deneme'), findsOneWidget);
      expect(be.count('POST $_path'), 1);
      await tester.tap(find.byKey(const ValueKey('scan-fresh')));
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(be.count('POST $_path'), 1);
      await settle(tester, const Duration(seconds: 4));
    });

    testWidgets('ağ hatası: genel ağ mesajı, tarayıcı açık kalır', (tester) async {
      await open(tester);
      be.network(_path);
      await tester.tap(find.byKey(const ValueKey('scan-lesson')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(QrScanHubPage), findsOneWidget);
      expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
      await settle(tester, const Duration(seconds: 4));
    });

    testWidgets('bozuk yük sunucuya gitmez', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('scan-bad')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('attendance/scan'), 0);
      await settle(tester, const Duration(seconds: 4));
    });
  });
}
