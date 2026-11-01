import 'dart:convert';

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/two_factor.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/two_factor_login_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/two_factor_pages.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_app.dart';

/// İki adımlı doğrulama (e-posta kodu): giriş 202 dalı, kod ekranı, ayarlar (açma/kapatma), güvenilen cihazlar.
/// Sözleşme: docs/TWO_FACTOR_API.md.
Widget _app(Widget home, {Locale locale = const Locale('tr'), Brightness br = Brightness.light, double scale = 1}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: br == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: home,
    );

/// Durumlu sahte 2FA sunucusu.
class _Tf {
  _Tf() {
    b.handlers.add(_handle);
  }

  final b = FakeBackend();

  /// Girişte tanınmayan cihaz (202) mi, güvenilir cihaz (200) mı?
  bool unknownDevice = true;
  String validCode = '123456';
  bool enabled = false;
  bool currentTrusted = true;
  String? loginError; // 2fa doğrulamada dönecek hata kodu
  String? resendError;
  String devicesReply = 'list';
  String validPassword = 'Sifre1234';
  final devices = <Map<String, Object?>>[
    {'id': 1, 'label': 'Android 14 · v2.0.5', 'createdAt': '2026-10-20T10:00:00', 'lastUsedAt': null, 'current': true},
    {'id': 2, 'label': 'iPhone 15 · v2.0.4', 'createdAt': '2026-10-01T10:00:00', 'lastUsedAt': '2026-10-28T09:00:00', 'current': false},
  ];

  Map<String, Object?> get _tokens => {'accessToken': 'a.b.c', 'refreshToken': 'r1'};

  Map<String, dynamic> _body(http.Request r) => r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;

  FakeResult _err(int status, String code, String msg) => FakeResult.json({'code': code, 'message': msg}, status: status);

  /// Bu yollar için işleyici susar (FakeBackend rotası, örn. Retry-After başlıklı 429, cevap verir).
  final skip = <String>{};

  FakeResult? _handle(http.Request req, String path) {
    final m = req.method;
    if (skip.contains(path)) return null;
    if (m == 'POST' && path == '/auth/login') {
      if (!unknownDevice) return FakeResult.json(_tokens);
      return const FakeResult.json({
        'twoFactorRequired': true,
        'challengeToken': 'ct-1',
        'emailHint': 'ay***@bingol.edu.tr',
        'expiresInSeconds': 600,
      }, status: 202);
    }
    if (m == 'POST' && path == '/auth/login/2fa') {
      if (loginError != null) return _err(400, loginError!, 'x');
      return _body(req)['code'] == validCode ? FakeResult.json(_tokens) : _err(400, 'TWO_FACTOR_CODE_INVALID', 'x');
    }
    if (m == 'POST' && path == '/auth/login/2fa/resend') {
      if (resendError != null) return _err(429, resendError!, 'Çok fazla deneme.');
      return const FakeResult.json({'expiresInSeconds': 600}, status: 202);
    }
    if (m == 'GET' && path == '/auth/2fa') {
      return FakeResult.json({'enabled': enabled, 'trustedDeviceCount': devices.length, 'currentDeviceTrusted': currentTrusted});
    }
    if (m == 'POST' && path == '/auth/2fa/enable/request') {
      return enabled ? _err(409, 'TWO_FACTOR_ALREADY_ENABLED', 'x') : const FakeResult.json(null, status: 202);
    }
    if (m == 'POST' && path == '/auth/2fa/enable/confirm') {
      if (_body(req)['code'] != validCode) return _err(400, 'INVALID_CODE', 'Kod hatalı.');
      enabled = true;
      return const FakeResult.json({'enabled': true});
    }
    if (m == 'POST' && path == '/auth/2fa/disable') {
      if (_body(req)['password'] != validPassword) return _err(400, 'INVALID_PASSWORD', 'x');
      enabled = false;
      devices.clear();
      return const FakeResult.json({'enabled': false});
    }
    if (m == 'GET' && path == '/auth/2fa/devices') {
      return FakeResult.json(devices);
    }
    if (m == 'DELETE' && path.startsWith('/auth/2fa/devices/')) {
      final id = int.parse(path.split('/').last);
      devices.removeWhere((d) => d['id'] == id);
      return const FakeResult.json(null, status: 204);
    }
    return null;
  }
}

Future<void> _fillAndLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'ayse@bingol.edu.tr');
  await tester.enterText(find.byType(TextFormField).at(1), 'Sifre1234');
  await tester.pump(const Duration(milliseconds: 700)); // giriş animasyonu bitmeden dokunma isabet etmez
  await tester.tap(find.text('Giriş yap'));
  await settle(tester, const Duration(milliseconds: 500));
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(EditableText).first, code);
  await settle(tester, const Duration(milliseconds: 1200));
}

void main() {
  setUpAll(loadTestFonts);

  group('giriş: 202 dalı', () {
    testWidgets('kod ekranı açılır, doğru kod oturumu açar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      expect(find.text('Giriş kodu'), findsOneWidget);
      expect(find.textContaining('ay***@bingol.edu.tr', findRichText: true), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      await _typeCode(tester, '123456');
      expect(f.b.bodies['POST /auth/login/2fa'], {'challengeToken': 'ct-1', 'code': '123456', 'trustDevice': true});
      expect(s.state, SessionState.signedIn);
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('yanlış kod: hata gösterilir, sayfa kalır, doğru kodla devam edilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      await _typeCode(tester, '000000');
      expect(find.text('Kod yanlış. Kontrol edip tekrar deneyin.'), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      await _typeCode(tester, '123456');
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });

    testWidgets('"Bu cihaza güven" varsayılan açık; kapatınca trustDevice false gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('tf-trust')));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await _typeCode(tester, '123456');
      expect((f.b.bodies['POST /auth/login/2fa'] as Map)['trustDevice'], false);
      await unmount(tester);
    });

    testWidgets('süre doldu: girişe dönülür ve bilgi bandı çıkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf()..loginError = 'TWO_FACTOR_CHALLENGE_EXPIRED';
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      await _typeCode(tester, '123456');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Kodun süresi doldu. Lütfen yeniden giriş yapın.'), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      await unmount(tester);
    });

    testWidgets('yeniden gönder: geri sayım biter, düğme açılır, istek gider, sayaç yeniden başlar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      await tester.pumpWidget(_app(LoginPage(session: makeSession(f.b, signedIn: false))));
      await _fillAndLogin(tester);
      expect(find.text('Yeniden gönder (60 sn)'), findsOneWidget);
      await settle(tester, const Duration(seconds: 30));
      expect(find.text('Yeniden gönder (30 sn)'), findsOneWidget);
      await settle(tester, const Duration(seconds: 31));
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.b.bodies['POST /auth/login/2fa/resend'], {'challengeToken': 'ct-1'});
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
      expect(find.textContaining('Yeniden gönder ('), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yeniden gönder 429: Retry-After süresi gösterilir ve o kadar beklenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      f.skip.add('/auth/login/2fa/resend');
      f.b.on('/auth/login/2fa/resend', {'code': 'RATE_LIMITED', 'message': 'Çok fazla deneme.'}, status: 429, headers: {'retry-after': '40'});
      await tester.pumpWidget(_app(LoginPage(session: makeSession(f.b, signedIn: false))));
      await _fillAndLogin(tester);
      await settle(tester, const Duration(seconds: 61));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('40 sn'), findsWidgets);
      expect(find.text('Yeniden gönder (40 sn)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('429 ile kod doğrulama: hata + bekleme süresi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf();
      f.skip.add('/auth/login/2fa');
      f.b.on('/auth/login/2fa', {'code': 'RATE_LIMITED', 'message': 'Çok fazla deneme.'}, status: 429, headers: {'retry-after': '30'});
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      await _typeCode(tester, '123456');
      expect(find.textContaining('30 sn'), findsOneWidget);
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('güvenilir cihaz: 200, kod ekranı açılmaz (mevcut davranış)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final f = _Tf()..unknownDevice = false;
      final s = makeSession(f.b, signedIn: false);
      await tester.pumpWidget(_app(LoginPage(session: s)));
      await _fillAndLogin(tester);
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });

    test('TwoFactorChallenge.tryParse: normal token yanıtı null, 202 yanıtı çözülür', () {
      expect(TwoFactorChallenge.tryParse({'accessToken': 'a', 'refreshToken': 'r'}), isNull);
      final c = TwoFactorChallenge.tryParse({'twoFactorRequired': true, 'challengeToken': 't', 'emailHint': 'a***@b', 'expiresInSeconds': 600});
      expect(c!.token, 't');
      expect(c.emailHint, 'a***@b');
      expect(c.expiresInSeconds, 600);
    });
  });

  group('ayarlar', () {
    Future<void> openSecurity(WidgetTester tester, _Tf f, {Size size = const Size(390, 1800)}) async {
      useScreen(tester, size);
      await tester.pumpWidget(_app(AccountSecurityPage(session: makeSession(f.b))));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('sunucuda uç yoksa (404) blok gösterilmez', (tester) async {
      final b = FakeBackend();
      useScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(_app(AccountSecurityPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('tf-toggle')), findsNothing);
      expect(find.byKey(const ValueKey('tf-retry')), findsNothing);
      await unmount(tester);
    });

    testWidgets('durum hatasında (5xx) yeniden dene satırı çıkar', (tester) async {
      final f = _Tf();
      f.skip.add('/auth/2fa');
      f.b.fail('/auth/2fa', status: 500);
      await openSecurity(tester, f);
      expect(find.byKey(const ValueKey('tf-retry')), findsOneWidget);
      f.b.reset('/auth/2fa');
      f.skip.clear();
      await tester.tap(find.byKey(const ValueKey('tf-retry')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('tf-toggle')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kapalıyken: açıklama görünür, cihazlar satırı yok', (tester) async {
      final f = _Tf();
      await openSecurity(tester, f);
      expect(find.text('İki adımlı doğrulama'), findsOneWidget);
      expect(find.textContaining('güvendiğiniz cihazda tekrar sorulmaz'), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('tf-toggle')), matching: find.byType(Switch))).value, isFalse);
      expect(find.byKey(const ValueKey('tf-devices')), findsNothing);
      await unmount(tester);
    });

    testWidgets('açma: request -> kod ekranı -> yanlış kod -> doğru kod -> açık + cihaz satırı', (tester) async {
      final f = _Tf();
      await openSecurity(tester, f);
      await tester.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(f.b.count('POST /auth/2fa/enable/request'), 1);
      expect(find.byType(TwoFactorEnablePage), findsOneWidget);
      expect(find.text('İki adımlı doğrulamayı aç'), findsOneWidget);
      await _typeCode(tester, '000000');
      expect(find.text('Kod hatalı.'), findsOneWidget);
      expect(f.enabled, isFalse);
      await _typeCode(tester, '123456');
      await settle(tester, const Duration(milliseconds: 700));
      expect(f.b.bodies['POST /auth/2fa/enable/confirm'], {'code': '123456'});
      expect(find.byType(TwoFactorEnablePage), findsNothing);
      expect(find.text('İki adımlı doğrulama açıldı.'), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('tf-toggle')), matching: find.byType(Switch))).value, isTrue);
      expect(find.byKey(const ValueKey('tf-devices')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('açma: zaten açık (409) uyarı verir ve durumu tazeler', (tester) async {
      final f = _Tf();
      await openSecurity(tester, f);
      f.enabled = true; // başka cihazda açıldı
      await tester.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(TwoFactorEnablePage), findsNothing);
      expect(find.text('İki adımlı doğrulama zaten açık.'), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('tf-toggle')), matching: find.byType(Switch))).value, isTrue);
      await unmount(tester);
    });

    testWidgets('açma ekranı: yeniden gönder enable/request çağırır', (tester) async {
      final f = _Tf();
      await openSecurity(tester, f);
      await tester.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(tester, const Duration(milliseconds: 700));
      await settle(tester, const Duration(seconds: 61));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.b.count('POST /auth/2fa/enable/request'), 2);
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kapatma: şifre diyaloğu, yanlış şifre satır içi hata, doğru şifre kapatır', (tester) async {
      final f = _Tf()..enabled = true;
      await openSecurity(tester, f);
      expect(find.byKey(const ValueKey('tf-devices')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('İki adımlı doğrulama kapatılsın mı?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('tf-disable-password')), 'yanlis');
      await tester.tap(find.text('Kapat'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Şifre hatalı.'), findsOneWidget);
      expect(find.text('İki adımlı doğrulama kapatılsın mı?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('tf-disable-password')), 'Sifre1234');
      await tester.tap(find.text('Kapat'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(f.b.bodies['POST /auth/2fa/disable'], {'password': 'Sifre1234'});
      expect(find.text('İki adımlı doğrulama kapatılsın mı?'), findsNothing);
      expect(find.text('İki adımlı doğrulama kapatıldı.'), findsOneWidget);
      expect(f.enabled, isFalse);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('tf-toggle')), matching: find.byType(Switch))).value, isFalse);
      expect(find.byKey(const ValueKey('tf-devices')), findsNothing);
      await unmount(tester);
    });

    testWidgets('kapatma: vazgeç hiçbir istek atmaz', (tester) async {
      final f = _Tf()..enabled = true;
      await openSecurity(tester, f);
      await tester.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.b.count('POST /auth/2fa/disable'), 0);
      expect(f.enabled, isTrue);
      await unmount(tester);
    });

    testWidgets('güvenilen cihazlar: liste, "Bu cihaz" rozeti, kaldırma', (tester) async {
      final f = _Tf()..enabled = true;
      await openSecurity(tester, f);
      expect(find.text('2'), findsOneWidget); // cihaz sayısı
      await tester.tap(find.byKey(const ValueKey('tf-devices')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(TrustedDevicesPage), findsOneWidget);
      expect(find.text('Android 14 · v2.0.5'), findsOneWidget);
      expect(find.text('iPhone 15 · v2.0.4'), findsOneWidget);
      expect(find.byKey(const ValueKey('tf-device-current')), findsOneWidget);
      expect(find.text('Bu cihaz'), findsOneWidget);
      // diğer cihaz kaldırılır
      await tester.tap(find.byKey(const ValueKey('tf-remove-2')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Cihaz kaldırılsın mı?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Kaldır')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(f.b.count('DELETE /auth/2fa/devices/2'), 1);
      expect(find.text('iPhone 15 · v2.0.4'), findsNothing);
      expect(find.text('Cihaz kaldırıldı.'), findsOneWidget);
      // geri dönünce sayı güncellenir
      await tester.tap(find.bySemanticsLabel('Geri').first);
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('tf-devices')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('mevcut cihazı kaldırma: uyarı metni gösterilir; vazgeçince silinmez', (tester) async {
      final f = _Tf()..enabled = true;
      await openSecurity(tester, f);
      await tester.tap(find.byKey(const ValueKey('tf-devices')));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('tf-remove-1')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.textContaining('Şu an kullandığınız cihazı kaldırıyorsunuz'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.b.count('DELETE'), 0);
      expect(find.text('Android 14 · v2.0.5'), findsOneWidget);
      // onaylanırsa silinir
      await tester.tap(find.byKey(const ValueKey('tf-remove-1')));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Kaldır')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(f.b.count('DELETE /auth/2fa/devices/1'), 1);
      expect(find.text('Android 14 · v2.0.5'), findsNothing);
      await unmount(tester);
    });

    testWidgets('güvenilen cihaz yoksa boş durum, hata varsa yeniden dene', (tester) async {
      final f = _Tf()..enabled = true;
      f.devices.clear();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_app(TrustedDevicesPage(session: makeSession(f.b))));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('tf-devices-empty')), findsOneWidget);
      expect(find.text('Güvenilen cihaz yok'), findsOneWidget);
      await unmount(tester);

      final g = _Tf();
      g.skip.add('/auth/2fa/devices');
      g.b.network('/auth/2fa/devices');
      await tester.pumpWidget(_app(TrustedDevicesPage(session: makeSession(g.b))));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Yeniden dene'), findsOneWidget);
      g.b.reset('/auth/2fa/devices');
      g.skip.clear();
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Android 14 · v2.0.5'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('taşma: 320 dp, açık/koyu, 3 dil, yazı ölçeği 1 ve 2', () {
    final screens = <String, Widget Function(_Tf f)>{
      'kod ekranı': (f) => TwoFactorLoginPage(
            session: makeSession(f.b, signedIn: false),
            challenge: const TwoFactorChallenge(token: 'ct-1', emailHint: 'ayse.cok.uzun.eposta***@ogr.bingol.edu.tr', expiresInSeconds: 600),
          ),
      'açma ekranı': (f) => TwoFactorEnablePage(session: makeSession(f.b)),
      'cihazlar': (f) {
        f.devices.add({'id': 3, 'label': 'Samsung Galaxy S24 Ultra çok uzun cihaz etiketi · v2.0.5', 'createdAt': '2026-09-01T10:00:00', 'lastUsedAt': '2026-10-31T10:00:00', 'current': false});
        return TrustedDevicesPage(session: makeSession(f.b));
      },
      'hesap ve güvenlik': (f) {
        f.enabled = true;
        return AccountSecurityPage(session: makeSession(f.b));
      },
    };

    for (final lang in ['tr', 'en', 'ar']) {
      for (final br in Brightness.values) {
        for (final scale in const [1.0, 2.0]) {
          screens.forEach((name, build) {
            testWidgets('$name | $lang ${br.name} x$scale', (tester) async {
              useScreen(tester, kPhoneSmall);
              LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
              addTearDown(() => LocaleController.current = null);
              final f = _Tf();
              await tester.pumpWidget(_app(build(f), locale: Locale(lang), br: br, scale: scale));
              await settle(tester, const Duration(milliseconds: 1500));
              expect(tester.takeException(), isNull);
              await unmount(tester);
            });
          });
        }
      }
    }

    for (final dark in [false, true]) {
      testWidgets('kapatma diyaloğu hata ile | ${dark ? 'koyu' : 'açık'} x2', (tester) async {
        useScreen(tester, kPhoneSmall);
        final f = _Tf()..enabled = true;
        await tester.pumpWidget(_app(AccountSecurityPage(session: makeSession(f.b)), br: dark ? Brightness.dark : Brightness.light, scale: 2));
        await settle(tester, const Duration(milliseconds: 600));
        await tester.scrollUntilVisible(find.byKey(const ValueKey('tf-toggle')), 200, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.byKey(const ValueKey('tf-toggle')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tf-toggle')));
        await settle(tester, const Duration(milliseconds: 700));
        await tester.enterText(find.byKey(const ValueKey('tf-disable-password')), 'yanlis');
        await tester.tap(find.text('Kapat'));
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.text('Şifre hatalı.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
