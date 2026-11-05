import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/two_factor.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/two_factor_code_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/two_factor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_two_factor.dart';

const _longWait = Duration(milliseconds: 1500);

Widget _ar(Widget page, Size size, {bool dark = false}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar'),
      home: page,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: child)),
        ),
      ),
    );

Future<void> _submitLogin(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).at(0), '210001001');
  await t.enterText(find.byType(TextFormField).at(1), 'Sifre1234');
  await t.pump();
  await t.tap(find.text('Giriş yap').last);
  await settle(t, _longWait);
}

void main() {
  setUpAll(loadTestFonts);

  group('Session: giriş + ikinci adım', () {
    test('2FA yoksa login oturumu açar ve null döner', () async {
      final b = FakeBackend();
      FakeTwoFactor(b);
      final s = makeSession(b, signedIn: false);
      final ch = await s.login('210001001', 'Sifre1234');
      expect(ch, isNull);
      expect(s.state, SessionState.signedIn);
      expect(s.api.tokens, isNotNull);
    });

    test('202 + twoFactorRequired: challenge döner, oturum AÇILMAZ', () async {
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      final ch = await s.login('210001001', 'Sifre1234');
      expect(ch, isNotNull);
      expect(ch!.token, 'challenge-abc');
      expect(ch.emailHint, 'ay***@bingol.edu.tr');
      expect(ch.expiresInSeconds, 600);
      expect(s.state, isNot(SessionState.signedIn));
      expect(s.api.tokens, isNull);
      // Belirteç yanlışlıkla günlüğe düşmesin.
      expect('$ch', isNot(contains('challenge-abc')));
    });

    test('doğru kod: oturum açılır, trustDevice varsayılan false AÇIKÇA gönderilir', () async {
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      final ch = (await s.login('210001001', 'Sifre1234'))!;
      await s.loginTwoFactor(ch, ' 123456 ');
      expect(s.state, SessionState.signedIn);
      expect(b.bodies['POST /auth/login/2fa'], {'challengeToken': 'challenge-abc', 'code': '123456', 'trustDevice': false});
    });

    test('trustDevice true gönderilir; yanlış kod ApiError ve oturum açılmaz', () async {
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      final ch = (await s.login('210001001', 'Sifre1234'))!;
      await expectLater(
          s.loginTwoFactor(ch, '000000'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'TWO_FACTOR_CODE_INVALID')));
      expect(s.state, isNot(SessionState.signedIn));
      await s.loginTwoFactor(ch, '123456', trustDevice: true);
      expect((b.bodies['POST /auth/login/2fa'] as Map)['trustDevice'], true);
      expect(s.state, SessionState.signedIn);
    });

    test('resend: expiresInSeconds döner', () async {
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      final ch = (await s.login('210001001', 'Sifre1234'))!;
      expect(await s.resendTwoFactor(ch), 600);
      expect(b.bodies['POST /auth/login/2fa/resend'], {'challengeToken': 'challenge-abc'});
    });

    test('TwoFactorChallenge.tryParse: eksik/yanlış gövde null', () {
      expect(TwoFactorChallenge.tryParse({'accessToken': 'a'}), isNull);
      expect(TwoFactorChallenge.tryParse({'twoFactorRequired': true}), isNull);
      expect(TwoFactorChallenge.tryParse({'twoFactorRequired': true, 'challengeToken': ''}), isNull);
      expect(TwoFactorChallenge.tryParse(null), isNull);
    });
  });

  group('giriş ekranı: 2FA ikinci adımı', () {
    testWidgets('2FA gerekli: kod ekranı açılır, doğru kodla oturum açılır (güven varsayılan KAPALI)', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      expect(find.textContaining('ay***@bingol.edu.tr', findRichText: true), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      // Anahtar kapalı başlar.
      expect(t.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('tf-trust')), matching: find.byType(Switch))).value, isFalse);

      await t.enterText(find.byType(TextField), '123456');
      await settle(t, _longWait);
      expect(s.state, SessionState.signedIn);
      expect(b.bodies['POST /auth/login/2fa'], {'challengeToken': 'challenge-abc', 'code': '123456', 'trustDevice': false});
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      await unmount(t);
    });

    testWidgets('"Bu cihaza güven" açılırsa trustDevice true gider', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      await t.tap(find.byKey(const ValueKey('tf-trust')));
      await t.pump();
      await t.enterText(find.byType(TextField), '123456');
      await settle(t, _longWait);
      expect((b.bodies['POST /auth/login/2fa'] as Map)['trustDevice'], true);
      expect(s.state, SessionState.signedIn);
      await unmount(t);
    });

    testWidgets('yanlış kod: çevrilmiş hata, kutular temizlenir, ekran açık kalır', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      await t.enterText(find.byType(TextField), '000000');
      await settle(t, _longWait);
      expect(find.text('Doğrulama kodu geçersiz veya süresi dolmuş.'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      // Düzeltilmiş kodla devam edilir.
      await t.enterText(find.byType(TextField), '123456');
      await settle(t, _longWait);
      expect(s.state, SessionState.signedIn);
      await unmount(t);
    });

    testWidgets('çok yanlış deneme: challenge ölür, "Girişe dön" ile giriş ekranına dönülür', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, requireOnLogin: true);
      f.wrongBudget = 2;
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      for (var i = 0; i < 2; i++) {
        await t.enterText(find.byType(TextField), '00000$i');
        await settle(t, _longWait);
      }
      // Challenge öldü: sunucu doğru kodu da reddeder; istemci kod girişini kapatır.
      await t.enterText(find.byType(TextField), '123456');
      await settle(t, _longWait);
      expect(find.text('Doğrulama oturumunun süresi doldu. Lütfen tekrar giriş yapın.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tf-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('tf-verify')), findsNothing);
      expect(s.state, isNot(SessionState.signedIn));
      await t.ensureVisible(find.byKey(const ValueKey('tf-back')));
      await t.tap(find.byKey(const ValueKey('tf-back')));
      await settle(t, _longWait);
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yeniden gönder: önce bekleme, süre dolunca düğme, yeni kod bilgisi', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, requireOnLogin: true);
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      expect(find.textContaining('Yeniden gönder ('), findsOneWidget);
      expect(find.text('Kodu yeniden gönder'), findsNothing);
      await settle(t, const Duration(seconds: 61));
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
      await t.ensureVisible(find.text('Kodu yeniden gönder'));
      await t.tap(find.text('Kodu yeniden gönder'));
      await settle(t, _longWait);
      expect(f.resends, 1);
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
      // Sayaç yeniden başladı.
      expect(find.textContaining('Yeniden gönder ('), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yeni cihaz kilidi (429 TWO_FACTOR_LOCKED): kod ekranı açılmaz, mesaj girişte görünür', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, requireOnLogin: true);
      f.locked = true;
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      expect(find.textContaining('24 saat kilitlendi'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('2FA yoksa normal giriş: kod ekranı hiç açılmaz', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      FakeTwoFactor(b);
      final s = makeSession(b, signedIn: false);
      await t.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(t, _longWait);
      await _submitLogin(t);
      expect(find.byType(TwoFactorLoginPage), findsNothing);
      expect(s.state, SessionState.signedIn);
      await unmount(t);
    });

    for (final dark in [false, true]) {
      testWidgets('kod ekranı 320 x2 ${dark ? 'koyu' : 'açık'} taşma yok', (t) async {
        useScreen(t, kPhoneSmall);
        t.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final s = makeSession(FakeBackend(), signedIn: false);
        await t.pumpWidget(buildApp(
            TwoFactorLoginPage(session: s, challenge: TwoFactorChallenge(token: 'x', emailHint: 'ay***@bingol.edu.tr')),
            brightness: dark ? Brightness.dark : Brightness.light,
            size: kPhoneSmall));
        await settle(t, _longWait);
        expect(t.takeException(), isNull);
        await unmount(t);
      });
    }

    testWidgets('kod ekranı ar RTL taşma yok', (t) async {
      useScreen(t, kPhoneSmall);
      final s = makeSession(FakeBackend(), signedIn: false);
      await t.pumpWidget(_ar(TwoFactorLoginPage(session: s, challenge: TwoFactorChallenge(token: 'x', emailHint: 'ay***@bingol.edu.tr')), kPhoneSmall));
      await settle(t, _longWait);
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });

  group('ayar sayfası', () {
    Future<(FakeBackend, FakeTwoFactor, Session)> open(WidgetTester t,
        {bool enabled = false, Size size = kPhoneMedium, void Function(FakeTwoFactor f)? seed}) async {
      useScreen(t, size);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, enabled: enabled);
      seed?.call(f);
      final s = makeSession(b);
      await t.pumpWidget(buildApp(TwoFactorPage(session: s), size: size));
      await settle(t, _longWait);
      return (b, f, s);
    }

    testWidgets('kapalı durum: anahtar kapalı, cihaz bölümü yok', (t) async {
      await open(t);
      expect(find.byKey(const ValueKey('tf-toggle')), findsOneWidget);
      expect(find.textContaining('Kapalı. Tanımadığın bir cihazdan'), findsOneWidget);
      expect(find.byKey(const ValueKey('tf-devices-empty')), findsNothing);
      expect(find.byKey(const ValueKey('tf-device-11')), findsNothing);
      await unmount(t);
    });

    testWidgets('yükleniyor iskeleti ve hata + yeniden dene', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 300));
      final f = FakeTwoFactor(b)..statusFails = true;
      await t.pumpWidget(buildApp(TwoFactorPage(session: makeSession(b)), size: kPhoneMedium));
      await t.pump();
      expect(find.byKey(const ValueKey('tf-loading')), findsOneWidget);
      await settle(t, const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('tf-toggle')), findsNothing);
      expect(find.text('Yeniden dene'), findsWidgets);
      f.statusFails = false;
      await t.tap(find.text('Yeniden dene').first);
      await settle(t, const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('tf-toggle')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('açma: istek -> kod -> onay -> açık + cihaz listesi', (t) async {
      final (b, f, _) = await open(t);
      await t.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(t, _longWait);
      expect(f.enableRequests, 1);
      expect(find.byType(TwoFactorEnablePage), findsOneWidget);
      expect(find.textContaining('ayse@bingol.edu.tr', findRichText: true), findsOneWidget);
      // Güven anahtarı yalnız girişte vardır.
      expect(find.byType(Switch), findsNothing);
      await t.enterText(find.byType(TextField), '123456');
      await settle(t, _longWait);
      expect(b.bodies['POST /auth/2fa/enable/confirm'], {'code': '123456'});
      expect(f.enabled, isTrue);
      expect(find.byType(TwoFactorEnablePage), findsNothing);
      expect(find.text('İki faktörlü doğrulama açıldı.'), findsOneWidget);
      expect(find.textContaining('Açık. Tanımadığın bir cihazdan'), findsOneWidget);
      expect(find.text('android 2.0.6'), findsOneWidget);
      expect(find.textContaining('Bu cihaz ·'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('açma: yanlış kod hatası gösterilir, sayfa açık kalır', (t) async {
      final (_, f, _) = await open(t);
      await t.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(t, _longWait);
      await t.enterText(find.byType(TextField), '999999');
      await settle(t, _longWait);
      expect(find.text('Doğrulama kodu geçersiz veya süresi dolmuş.'), findsOneWidget);
      expect(find.byType(TwoFactorEnablePage), findsOneWidget);
      expect(f.enabled, isFalse);
      await unmount(t);
    });

    testWidgets('açma: 409 zaten açık -> hata + durum tazelenir', (t) async {
      final (_, f, _) = await open(t);
      f.enabled = true; // başka cihazdan açıldı
      await t.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(t, _longWait);
      expect(find.byType(TwoFactorEnablePage), findsNothing);
      expect(find.text('İki faktörlü doğrulama zaten açık.'), findsOneWidget);
      expect(find.textContaining('Açık. Tanımadığın bir cihazdan'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('kapatma: yanlış şifre satır içi hata; doğru şifreyle kapanır, cihazlar silinir', (t) async {
      final (b, f, _) = await open(t, enabled: true, seed: (f) => f.addDevice('android 2.0.6', current: true));
      expect(find.text('android 2.0.6'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(t, _longWait);
      expect(find.text('İki faktörlü doğrulama kapatılsın mı?'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('tf-disable-password')), 'yanlis');
      await t.tap(find.byKey(const ValueKey('tf-disable-confirm')));
      await settle(t, _longWait);
      expect(find.text('Şifre hatalı.'), findsOneWidget);
      expect(f.enabled, isTrue);
      await t.enterText(find.byKey(const ValueKey('tf-disable-password')), 'Sifre1234');
      await t.tap(find.byKey(const ValueKey('tf-disable-confirm')));
      await settle(t, _longWait);
      expect(b.bodies['POST /auth/2fa/disable'], {'password': 'Sifre1234'});
      expect(f.enabled, isFalse);
      expect(find.text('İki faktörlü doğrulama kapatıldı.'), findsOneWidget);
      expect(find.textContaining('Kapalı. Tanımadığın bir cihazdan'), findsOneWidget);
      expect(find.text('android 2.0.6'), findsNothing);
      await unmount(t);
    });

    testWidgets('kapatma: boş şifre sunucuya gitmez', (t) async {
      final (b, _, _) = await open(t, enabled: true);
      await t.tap(find.byKey(const ValueKey('tf-toggle')));
      await settle(t, _longWait);
      await t.tap(find.byKey(const ValueKey('tf-disable-confirm')));
      await settle(t, _longWait);
      expect(find.text('Şifrenizi girin.'), findsOneWidget);
      expect(b.count('POST /auth/2fa/disable'), 0);
      await unmount(t);
    });

    testWidgets('güvenilen cihazlar: liste, tek tek kaldırma, boş durum', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, enabled: true);
      final cur = f.addDevice('android 2.0.6', current: true);
      final other = f.addDevice('ios 2.0.5');
      await t.pumpWidget(buildApp(TwoFactorPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t, _longWait);
      expect(find.byKey(ValueKey('tf-device-${cur['id']}')), findsOneWidget);
      expect(find.text('ios 2.0.5'), findsOneWidget);
      await t.tap(find.byKey(ValueKey('tf-device-remove-${other['id']}')));
      await settle(t, _longWait);
      expect(find.text('Cihaz kaldırılsın mı?'), findsOneWidget);
      await t.tap(find.text('Kaldır'));
      await settle(t, _longWait);
      expect(b.count('DELETE /auth/2fa/devices/${other['id']}'), 1);
      expect(find.text('ios 2.0.5'), findsNothing);
      expect(find.text('Cihaz kaldırıldı.'), findsOneWidget);
      // Son cihazı da kaldır: boş durum.
      await t.tap(find.byKey(ValueKey('tf-device-remove-${cur['id']}')));
      await settle(t, _longWait);
      await t.tap(find.text('Kaldır'));
      await settle(t, _longWait);
      expect(find.byKey(const ValueKey('tf-devices-empty')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('cihaz kaldırma vazgeçilirse istek atılmaz', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, enabled: true);
      final d = f.addDevice('ios 2.0.5');
      await t.pumpWidget(buildApp(TwoFactorPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t, _longWait);
      await t.tap(find.byKey(ValueKey('tf-device-remove-${d['id']}')));
      await settle(t, _longWait);
      await t.tap(find.text('Vazgeç'));
      await settle(t, _longWait);
      expect(b.count('DELETE /auth/2fa/devices'), 0);
      expect(find.text('ios 2.0.5'), findsOneWidget);
      await unmount(t);
    });

    for (final dark in [false, true]) {
      testWidgets('320 x2 ${dark ? 'koyu' : 'açık'} taşma yok (cihazlı)', (t) async {
        useScreen(t, kPhoneSmall);
        t.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final b = FakeBackend();
        final f = FakeTwoFactor(b, enabled: true);
        f.addDevice('android 2.0.6 uzun cihaz etiketi örneği', current: true);
        await t.pumpWidget(buildApp(TwoFactorPage(session: makeSession(b)),
            brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall));
        await settle(t, _longWait);
        expect(t.takeException(), isNull);
        await unmount(t);
      });
    }

    testWidgets('ar RTL taşma yok', (t) async {
      useScreen(t, kPhoneSmall);
      final b = FakeBackend();
      final f = FakeTwoFactor(b, enabled: true);
      f.addDevice('android 2.0.6', current: true);
      await t.pumpWidget(_ar(TwoFactorPage(session: makeSession(b)), kPhoneSmall));
      await settle(t, _longWait);
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });

  group('Hesap ve güvenlik: giriş noktası', () {
    testWidgets('satır durumu gösterir ve ayar sayfasını açar', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      FakeTwoFactor(b, enabled: true);
      await t.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t, _longWait);
      final row = find.byKey(const ValueKey('sec-2fa'));
      await t.ensureVisible(row);
      expect(find.descendant(of: row, matching: find.text('İki faktörlü doğrulama')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Açık')), findsOneWidget);
      await t.tap(row);
      await settle(t, _longWait);
      expect(find.byType(TwoFactorPage), findsOneWidget);
      await unmount(t);
    });

    testWidgets('durum alınamazsa satır yine görünür (değersiz), sayfa bozulmaz', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final f = FakeTwoFactor(b);
      f.statusFails = true;
      await t.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t, _longWait);
      final row = find.byKey(const ValueKey('sec-2fa'));
      await t.ensureVisible(row);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Açık')), findsNothing);
      expect(find.descendant(of: row, matching: find.text('Kapalı')), findsNothing);
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });
}
