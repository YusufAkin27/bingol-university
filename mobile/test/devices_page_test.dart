import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/device_identity.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/user_sessions.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/devices_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuErrorState;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_app.dart';

const _wait = Duration(milliseconds: 1500);

String _ago(int minutes) => DateTime.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

/// `GET/DELETE /auth/sessions` durumlu sahte uygulaması.
class FakeSessions {
  FakeSessions(this.b) {
    b.handlers.add(handle);
  }

  final FakeBackend b;
  final List<Map<String, dynamic>> items = [];

  /// Silme isteği bu kodla düşer (örn. 404 SESSION_NOT_FOUND); null = 204.
  int? deleteStatus;
  bool listFails = false;

  Map<String, dynamic> add(String id, String name,
      {String platform = 'ANDROID', String version = '2.2.0', String ip = '203.0.*.*', bool current = false, int minutes = 5, String client = 'mobile'}) {
    final m = {
      'id': id,
      'client': client,
      'platform': platform,
      'deviceName': name,
      'appVersion': version,
      'ipMasked': ip,
      'createdAt': _ago(60 * 24),
      'lastUsedAt': _ago(minutes),
      'current': current,
    };
    items.add(m);
    return m;
  }

  FakeResult? handle(http.Request req, String path) {
    if (path == '/auth/sessions' && req.method == 'GET') {
      if (listFails) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
      return FakeResult.json(List<Map<String, dynamic>>.from(items));
    }
    if (path.startsWith('/auth/sessions/') && req.method == 'DELETE') {
      if (deleteStatus != null) {
        return FakeResult.json({'code': 'SESSION_NOT_FOUND', 'message': 'Oturum bulunamadı veya zaten kapatılmış.'}, status: deleteStatus!);
      }
      final id = path.substring('/auth/sessions/'.length);
      items.removeWhere((e) => e['id'] == id);
      return const FakeResult.json(null, status: 204);
    }
    return null;
  }
}

Session _signedIn(FakeBackend b) {
  final s = makeSession(b);
  s.api.tokens = Tokens('acc', 'ref');
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  group('Cihazlarım sayfası', () {
    Future<(FakeBackend, FakeSessions, Session)> open(WidgetTester t,
        {void Function(FakeSessions f)? seed, Size size = kPhoneMedium, Duration delay = Duration.zero}) async {
      useScreen(t, size);
      final b = FakeBackend(delay: delay);
      final f = FakeSessions(b);
      seed?.call(f);
      final s = _signedIn(b);
      await t.pumpWidget(buildApp(DevicesPage(session: s), size: size));
      await settle(t, _wait);
      return (b, f, s);
    }

    void twoDevices(FakeSessions f) {
      f.add('cur0000000000000000000000000001', 'Pixel 8', current: true, minutes: 0);
      f.add('oth0000000000000000000000000002', 'iPhone 15', platform: 'IOS', version: '2.1.9', ip: '10.1.*.*', minutes: 90);
    }

    testWidgets('liste: cihaz adı, "Bu cihaz", son kullanım, platform · sürüm · maskeli IP, çıkış düğmeleri', (t) async {
      final (b, _, _) = await open(t, seed: twoDevices);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('Bu cihaz'), findsOneWidget);
      expect(find.text('iPhone 15'), findsOneWidget);
      expect(find.textContaining('Son kullanım:'), findsOneWidget);
      expect(find.text('Android · v2.2.0 · 203.0.*.*'), findsOneWidget);
      expect(find.text('iOS · v2.1.9 · 10.1.*.*'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsNWidgets(2));
      expect(find.text('Tüm cihazlardan çıkış yap'), findsOneWidget);
      expect(b.count('GET /auth/sessions'), 1);
      await unmount(t);
    });

    testWidgets('başka cihazdan çıkış: onay penceresi -> DELETE -> satır kalkar + bildirim; diğerleri etkilenmez', (t) async {
      final (b, f, _) = await open(t, seed: twoDevices);
      await t.tap(find.byKey(const ValueKey('dev-signout-oth0000000000000000000000000002')));
      await settle(t, _wait);
      expect(find.text('Bu cihazdan çıkış yapılsın mı?'), findsOneWidget);
      expect(find.textContaining('iPhone 15 cihazındaki oturum kapatılacak'), findsOneWidget);
      await t.tap(find.text('Çıkış yap').last);
      await settle(t, _wait);
      expect(b.count('DELETE /auth/sessions/oth0000000000000000000000000002'), 1);
      expect(find.text('iPhone 15'), findsNothing);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('iPhone 15 cihazından çıkış yapıldı.'), findsOneWidget);
      expect(f.items.length, 1);
      expect(b.count('POST /auth/logout'), 0);
      await unmount(t);
    });

    testWidgets('onay verilmezse istek atılmaz', (t) async {
      final (b, _, _) = await open(t, seed: twoDevices);
      await t.tap(find.byKey(const ValueKey('dev-signout-oth0000000000000000000000000002')));
      await settle(t, _wait);
      await t.tap(find.text('Vazgeç'));
      await settle(t, _wait);
      expect(b.count('DELETE /auth/sessions'), 0);
      expect(find.text('iPhone 15'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('oturum zaten kapanmış (404): bilgi + liste tazelenir', (t) async {
      final (b, f, _) = await open(t, seed: twoDevices);
      f.deleteStatus = 404;
      f.items.removeWhere((e) => e['id'] == 'oth0000000000000000000000000002'); // başka yerden kapanmış
      await t.tap(find.byKey(const ValueKey('dev-signout-oth0000000000000000000000000002')));
      await settle(t, _wait);
      await t.tap(find.text('Çıkış yap').last);
      await settle(t, _wait);
      expect(find.text('Bu oturum zaten kapatılmış.'), findsOneWidget);
      expect(find.text('iPhone 15'), findsNothing);
      expect(b.count('GET /auth/sessions'), 2);
      await unmount(t);
    });

    testWidgets('bu cihazdan çıkış normal çıkıştır: POST /auth/logout, oturum kapanır; DELETE /auth/sessions atılmaz', (t) async {
      final (b, _, s) = await open(t, seed: twoDevices);
      await t.tap(find.byKey(const ValueKey('dev-signout-cur0000000000000000000000000001')));
      await settle(t, _wait);
      expect(find.textContaining('Bu cihazdaki oturumun kapatılacak'), findsOneWidget);
      await t.tap(find.text('Çıkış yap').last);
      await settle(t, _wait);
      expect(b.count('POST /auth/logout'), 1);
      expect(b.count('DELETE /auth/sessions'), 0);
      expect(s.state, SessionState.signedOut);
      await unmount(t);
    });

    testWidgets('tüm cihazlardan çık: onay -> POST /auth/logout-all -> yerel çıkış', (t) async {
      final (b, _, s) = await open(t, seed: twoDevices);
      await t.tap(find.byKey(const ValueKey('dev-logout-all')));
      await settle(t, _wait);
      expect(find.text('Tüm cihazlardan çıkış'), findsOneWidget);
      await t.tap(find.text('Çıkış yap').last);
      await settle(t, _wait);
      expect(b.count('POST /auth/logout-all'), 1);
      expect(s.state, SessionState.signedOut);
      await unmount(t);
    });

    testWidgets('tüm cihazlardan çık vazgeçilirse istek atılmaz', (t) async {
      final (b, _, _) = await open(t, seed: twoDevices);
      await t.tap(find.byKey(const ValueKey('dev-logout-all')));
      await settle(t, _wait);
      await t.tap(find.text('Vazgeç'));
      await settle(t, _wait);
      expect(b.count('POST /auth/logout-all'), 0);
      await unmount(t);
    });

    testWidgets('yükleniyor iskeleti, ardından liste', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 300));
      final f = FakeSessions(b);
      twoDevices(f);
      await t.pumpWidget(buildApp(DevicesPage(session: _signedIn(b)), size: kPhoneMedium));
      await t.pump();
      expect(find.byKey(const ValueKey('dev-loading')), findsOneWidget);
      await settle(t, _wait);
      expect(find.byKey(const ValueKey('dev-loading')), findsNothing);
      expect(find.text('Pixel 8'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('boş liste: boş durum metni; "Tüm cihazlardan çık" yine de görünür', (t) async {
      await open(t);
      expect(find.byKey(const ValueKey('dev-empty')), findsOneWidget);
      expect(find.text('Listelenecek açık oturum yok.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dev-logout-all')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('hata: yeniden dene ile liste gelir', (t) async {
      final (b, f, _) = await open(t, seed: (f) {
        twoDevices(f);
        f.listFails = true;
      });
      expect(find.text('Pixel 8'), findsNothing);
      expect(find.byType(BuErrorState), findsOneWidget);
      f.listFails = false;
      await t.tap(find.text('Yeniden dene'));
      await settle(t, _wait);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(b.count('GET /auth/sessions'), 2);
      await unmount(t);
    });

    testWidgets('çevrimdışı: bağlantı yok durumu + yeniden dene', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..offline = true;
      FakeSessions(b);
      await t.pumpWidget(buildApp(DevicesPage(session: _signedIn(b)), size: kPhoneMedium));
      await settle(t, const Duration(seconds: 4));
      expect(find.byType(BuErrorState), findsOneWidget);
      expect(find.text('Pixel 8'), findsNothing);
      await unmount(t);
    });

    testWidgets('adsız oturum platformdan adlandırılır; web oturumu dizüstü simgesi alır', (t) async {
      await open(t, seed: (f) {
        f.add('a0000000000000000000000000000001', '', platform: 'ANDROID', current: true, minutes: 0);
        f.add('w0000000000000000000000000000002', '', platform: 'WEB', client: 'web', version: '', ip: '');
        f.add('u0000000000000000000000000000003', '', platform: '', version: '', ip: '');
      });
      expect(find.text('Android cihaz'), findsOneWidget);
      expect(find.text('Web tarayıcı'), findsOneWidget);
      expect(find.text('Bilinmeyen cihaz'), findsOneWidget);
      await unmount(t);
    });

    for (final dark in [false, true]) {
      testWidgets('320x640 ${dark ? 'koyu' : 'açık'}: taşma yok', (t) async {
        useScreen(t, kPhoneSmall);
        final b = FakeBackend();
        final f = FakeSessions(b);
        f.add('lng0000000000000000000000000009', 'Çok uzun bir cihaz adı örneği: Samsung Galaxy S24 Ultra 512 GB', current: true, minutes: 0);
        twoDevices(f);
        await t.pumpWidget(buildApp(DevicesPage(session: _signedIn(b)), size: kPhoneSmall, brightness: dark ? Brightness.dark : Brightness.light));
        await settle(t, _wait);
        expect(t.takeException(), isNull);
        await unmount(t);
      });
    }

    testWidgets('ar RTL: taşma yok, Arapça metinler', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      twoDevices(FakeSessions(b));
      await t.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DevicesPage(session: _signedIn(b)),
      ));
      await settle(t, _wait);
      expect(find.text('هذا الجهاز'), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });

  group('Hesap ve güvenlik girişi', () {
    testWidgets('"Tüm cihazlardan çık" satırı kalktı; Cihazlarım satırı sayfayı açar', (t) async {
      useScreen(t, const Size(390, 1400));
      final b = FakeBackend();
      FakeSessions(b).add('cur0000000000000000000000000001', 'Pixel 8', current: true, minutes: 0);
      await t.pumpWidget(buildApp(AccountSecurityPage(session: _signedIn(b)), size: const Size(390, 1400)));
      await settle(t, _wait);
      expect(find.byKey(const ValueKey('sec-logout-all')), findsNothing);
      expect(find.text('Tüm cihazlardan çıkış yap'), findsNothing);
      expect(find.byKey(const ValueKey('sec-devices')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('sec-devices')));
      await t.tap(find.byKey(const ValueKey('sec-devices')));
      await settle(t, _wait);
      expect(find.byType(DevicesPage), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget);
      await unmount(t);
    });
  });

  group('API modeli', () {
    test('UserSessionInfo.tryParse: geçerli satır, eksik kimlik null, bozuk alanlar boş', () {
      final ok = UserSessionInfo.tryParse({
        'id': 'abc',
        'client': 'mobile',
        'platform': 'android',
        'deviceName': ' Pixel 8 ',
        'appVersion': '2.2.0',
        'ipMasked': '203.0.*.*',
        'createdAt': '2026-11-06T10:00:00Z',
        'lastUsedAt': 'bozuk',
        'current': true,
      })!;
      expect(ok.id, 'abc');
      expect(ok.platform, 'ANDROID');
      expect(ok.deviceName, 'Pixel 8');
      expect(ok.createdAt, isNotNull);
      expect(ok.lastUsedAt, isNull);
      expect(ok.current, isTrue);
      expect(ok.isWeb, isFalse);
      expect(UserSessionInfo.tryParse({'id': ''}), isNull);
      expect(UserSessionInfo.tryParse({'deviceName': 'x'}), isNull);
      expect(UserSessionInfo.tryParse('x'), isNull);
      expect(UserSessionInfo.tryParse({'id': 'w', 'client': 'web'})!.isWeb, isTrue);
    });

    test('UserSessionsApi: liste ve silme yolları', () async {
      final b = FakeBackend();
      final f = FakeSessions(b)..add('aa', 'Pixel 8', current: true);
      final api = UserSessionsApi(_signedIn(b).api);
      final list = await api.list();
      expect(list.single.id, 'aa');
      await api.revoke('aa');
      expect(b.requests, contains('DELETE /auth/sessions/aa'));
      expect(f.items, isEmpty);
    });

    test('liste gövdesi dizi değilse BAD_RESPONSE', () async {
      final b = FakeBackend()..on('/auth/sessions', {'items': []});
      await expectLater(UserSessionsApi(_signedIn(b).api).list(), throwsA(isA<ApiError>()));
    });
  });

  group('cihaz adı başlığı ve push yönlendirmesi', () {
    test('DeviceIdentity.deviceNameFor: Android sürümü, iOS sürümü, bilinmeyen', () {
      expect(DeviceIdentity.deviceNameFor(TargetPlatform.android, 'Linux 6.1.99-android14-11-g123 #1 SMP PREEMPT'), 'Android 14');
      expect(DeviceIdentity.deviceNameFor(TargetPlatform.android, 'Linux 4.9'), 'Android');
      expect(DeviceIdentity.deviceNameFor(TargetPlatform.iOS, 'Version 17.5.1 (Build 21F90)'), 'iPhone (iOS 17.5)');
      expect(DeviceIdentity.deviceNameFor(TargetPlatform.iOS, ''), 'iPhone');
      expect(DeviceIdentity.deviceNameFor(TargetPlatform.windows, ''), 'Mobil');
    });

    test('her istekte X-Device-Name gider (ASCII)', () {
      DeviceIdentity.debugNameOverride = 'Android 14';
      addTearDown(() => DeviceIdentity.debugNameOverride = null);
      expect(DeviceIdentity.instance.httpHeaders['X-Device-Name'], 'Android 14');
      expect(DeviceIdentity.deviceName.codeUnits.every((c) => c < 128), isTrue);
    });

    test('yeni cihaz bildirimi (SECURITY + devices / securityKind NEW_DEVICE) Cihazlarım\'ı açar', () {
      const devices = PushTarget(PushDest.devices);
      expect(resolvePushTarget({'target': 'SECURITY', 'value': 'devices', 'securityKind': 'NEW_DEVICE'}), devices);
      expect(resolvePushTarget({'targetType': 'SECURITY', 'targetId': 'devices', 'type': 'SYSTEM'}), devices);
      expect(resolvePushTarget({'targetType': 'SECURITY', 'securityKind': 'NEW_DEVICE'}), devices);
      expect(resolvePushTarget({'targetType': 'DEVICES'}), devices);
      // Diğer güvenlik bildirimleri eskisi gibi Hesap güvenliği'ne gider
      expect(resolvePushTarget({'targetType': 'ACCOUNT_SECURITY'}), const PushTarget(PushDest.accountSecurity));
      expect(resolvePushTarget({'target': 'SECURITY', 'securityKind': 'TWOFA_ENABLED'}), const PushTarget(PushDest.accountSecurity));
    });
  });
}

