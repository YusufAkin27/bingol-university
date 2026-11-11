import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_join_qr_page.dart';
import 'package:bu_kampus/features/profile/profile_qr_widgets.dart';
import 'package:bu_kampus/features/scan/scan_page.dart';
import 'package:bu_kampus/features/scan/scan_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _payload = 'bingol-clubjoin:7.30000000.AbC_-defGhIjKlMnOpQrSt';

Map<String, dynamic> _joinCode(String code, {int valid = 150}) => {
      'code': code,
      'expiresAt': '2026-11-11T12:00:00Z',
      'validForSeconds': valid,
    };

void main() {
  setUpAll(loadTestFonts);

  group('kulüp katılım yükü çözümleme', () {
    test('geçerli yük', () {
      final r = resolveScan(_payload);
      expect(r.kind, ScanKind.clubJoin);
      expect(r.clubId, 7);
      expect(r.code, _payload);
      expect(r.valid, isTrue);
    });

    test('bozuk / başka önek / sınır dışı: geçersiz', () {
      for (final v in [
        'bingol-clubjoin:abc.def',
        'bingol-clubjoin:7',
        'bingol-clubjoin:7.',
        'bingol-clubjoin:0.1.sig',
        'bingol-clubjoin:7.1.sig sig',
        'bingol-clubjoin:7.1.\nsig',
        'bingol-clubjoin:7.1.sig/../x',
        'bingol-clubjoin:${'9' * 19}.1.sig',
        'bingol-clubjoin:7.${'a' * 260}',
        'BINGOL-CLUBJOIN:7.1.sig',
        'xbingol-clubjoin:7.1.sig',
        'bingol-ticket:7.1.sig',
        'bingol-clubjoin: 7.1.sig',
      ]) {
        expect(resolveScan(v).kind, ScanKind.invalid, reason: v);
      }
    });

    test('yoklama yükü ve bağlantılar etkilenmez', () {
      expect(resolveScan('bingol-checkin:12.345.abc').kind, ScanKind.checkin);
      expect(resolveScan('https://bukampus.com.tr/s/c/5').kind, ScanKind.content);
    });
  });

  group('katılım QR sayfası', () {
    Future<FakeBackend> open(WidgetTester tester, {Size size = kPhoneMedium, double scale = 1, Brightness b = Brightness.light, FakeBackend? backend}) async {
      final be = backend ?? (FakeBackend()..on('/communities/7/join-code', _joinCode(_payload)));
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ClubJoinQrPage(session: makeSession(be), communityId: 7, clubName: 'Robotik Kulübü'),
        ),
        brightness: b,
        size: size,
      ));
      await settle(tester, const Duration(milliseconds: 500));
      return be;
    }

    testWidgets('kodu, kulüp adını ve açıklamayı gösterir; paylaş/kaydet yok', (tester) async {
      final be = await open(tester);
      expect(find.byType(ProfileQrPlate), findsOneWidget);
      expect(tester.widget<ProfileQrPlate>(find.byType(ProfileQrPlate)).data, _payload);
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      expect(find.byKey(const ValueKey('cjq-hint')), findsOneWidget);
      expect(find.byKey(const ValueKey('cjq-countdown')), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(be.count('GET /communities/7/join-code'), 1);
    });

    testWidgets('süre dolmadan kendiliğinden yeniler (150 sn geçerlilik -> 75 sn sonra)', (tester) async {
      final be = await open(tester);
      be.on('/communities/7/join-code', _joinCode('bingol-clubjoin:7.30000001.ZZZZZZZZZZZZZZZZZZZZZZ'));
      await tester.pump(const Duration(seconds: 74));
      expect(be.count('GET /communities/7/join-code'), 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(be.count('GET /communities/7/join-code'), 2);
      expect(tester.widget<ProfileQrPlate>(find.byType(ProfileQrPlate)).data, 'bingol-clubjoin:7.30000001.ZZZZZZZZZZZZZZZZZZZZZZ');
    });

    testWidgets('dispose sonrası zamanlayıcı da istek de yok', (tester) async {
      final be = await open(tester);
      await tester.pumpWidget(const SizedBox());
      final before = be.count('join-code');
      await tester.pump(const Duration(minutes: 10));
      expect(be.count('join-code'), before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hata: açıklayıcı metin + yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/communities/7/join-code', status: 500);
      await open(tester, backend: be);
      expect(find.byKey(const ValueKey('cjq-error')), findsOneWidget);
      expect(find.byType(ProfileQrPlate), findsNothing);
      be.on('/communities/7/join-code', _joinCode(_payload));
      await tester.tap(find.byKey(const ValueKey('cjq-retry')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(ProfileQrPlate), findsOneWidget);
    });

    testWidgets('yetkisiz (403): yetki mesajı, otomatik yeniden deneme yok', (tester) async {
      final be = FakeBackend()..fail('/communities/7/join-code', status: 403, code: 'FORBIDDEN');
      await open(tester, backend: be);
      expect(find.byKey(const ValueKey('cjq-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('cjq-retry')), findsNothing);
      await tester.pump(const Duration(seconds: 60));
      expect(be.count('join-code'), 1);
    });

    for (final c in [(kPhoneSmall, 1.0, Brightness.light), (kPhoneSmall, 1.6, Brightness.dark), (kPhoneMedium, 1.6, Brightness.light)]) {
      testWidgets('taşma yok: ${c.$1.width.toInt()} dp x${c.$2} ${c.$3.name}', (tester) async {
        await open(tester, size: c.$1, scale: c.$2, b: c.$3);
        expect(tester.takeException(), isNull);
        expect(find.byType(ProfileQrPlate), findsOneWidget);
      });
    }
  });

  group('tarayıcı: kulüp katılım akışı', () {
    late FakeBackend be;

    Future<void> open(WidgetTester tester) async {
      be = FakeBackend()
        ..on('/communities/7', {'id': 7, 'name': 'Robotik Kulübü', 'memberCount': 3, 'myStatus': 'ACTIVE', 'myRole': 'MEMBER'})
        ..on('/communities/7/posts*', {'items': [], 'nextCursor': null});
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
                    TextButton(key: const ValueKey('scan-join'), onPressed: () => onValue(_payload), child: const Text('a')),
                    TextButton(key: const ValueKey('scan-bad'), onPressed: () => onValue('bingol-clubjoin:zzz'), child: const Text('b')),
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

    testWidgets('başarı: POST + kulüp sayfası açılır, çift okuma tek istek', (tester) async {
      await open(tester);
      be.on('/communities/7/join-by-code', {'communityId': 7, 'status': 'ACTIVE'});
      await tester.tap(find.byKey(const ValueKey('scan-join')));
      await tester.tap(find.byKey(const ValueKey('scan-join')), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('POST /communities/7/join-by-code'), 1);
      expect(be.bodies['POST /communities/7/join-by-code'], {'code': _payload});
      expect(find.byType(ClubDetailPage), findsOneWidget);
      expect(find.byType(QrScanHubPage), findsNothing);
    });

    testWidgets('ALREADY: hata değil, kulüp sayfası açılır', (tester) async {
      await open(tester);
      be.on('/communities/7/join-by-code', {'communityId': 7, 'status': 'ALREADY'});
      await tester.tap(find.byKey(const ValueKey('scan-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ClubDetailPage), findsOneWidget);
      // ALREADY durumunda kulüp adı için ek istek atılmaz
      expect(be.count('GET /communities/7?'), 0);
    });

    testWidgets('hata kodu: sunucu mesajı gösterilir, tarayıcı açık kalır', (tester) async {
      await open(tester);
      be.fail('/communities/7/join-by-code', status: 422, code: 'CLUB_JOIN_CODE_INVALID', message: 'QR kodu geçersiz veya süresi dolmuş.');
      await tester.tap(find.byKey(const ValueKey('scan-join')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(QrScanHubPage), findsOneWidget);
      expect(find.byType(ClubDetailPage), findsNothing);
      expect(find.textContaining('QR kodu geçersiz'), findsOneWidget);
      await settle(tester, const Duration(seconds: 4)); // mesaj zamanlayıcısı bitsin
    });

    testWidgets('bozuk yük sunucuya gitmez', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('scan-bad')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('join-by-code'), 0);
      await settle(tester, const Duration(seconds: 4));
    });
  });
}
