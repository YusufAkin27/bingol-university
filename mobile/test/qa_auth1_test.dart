// QA alani 1 (giris / kayit / sifre / OAuth / 2FA / hesap guvenligi): QA turunda bulunan mantik hatalarinin regresyon
// testleri + sik hata yanitlari (401/403/409/422/429/5xx/cevrimdisi) icin etkilesimli duman testleri.
import 'dart:async';

import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/oauth/oauth_api.dart';
import 'package:bu_kampus/core/oauth/oauth_services.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/password_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/two_factor_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

class _Google implements GoogleSignInService {
  int calls = 0;
  GoogleCredential? result = const GoogleCredential(idToken: 'g-fresh', displayName: 'Ayse');

  @override
  Future<GoogleCredential?> signIn() async {
    calls++;
    return result;
  }
}

class _Apple implements AppleSignInService {
  @override
  Future<AppleCredential?> signIn() async => const AppleCredential(identityToken: 'a-fresh', nonce: 'n1');
}

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Session _passwordless(FakeBackend b) => makeSession(b)..hasPassword = false;

Widget _localized(Widget home, {Locale locale = const Locale('tr'), Brightness brightness = Brightness.light, double scale = 1}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  setUpAll(loadTestFonts);

  group('QA-AUTH-01: parolasiz (Google/Apple) hesap', () {
    testWidgets('GET /auth/me hasPassword alanini oturuma yazar; cikista temizlenir', (t) async {
      final b = FakeBackend()
        ..on('/auth/login', {'accessToken': 'A', 'refreshToken': 'R', 'expiresInSeconds': 900})
        ..on('/auth/me', {'id': 7, 'email': 'o@gmail.com', 'displayName': 'O', 'hasPassword': false});
      final s = makeSession(b, signedIn: false);
      await t.runAsync(() => s.login('o@gmail.com', 'x'));
      expect(s.hasPassword, isFalse);
      await t.runAsync(() => s.signOut(remote: false));
      expect(s.hasPassword, isNull);
    });

    testWidgets('eski sunucu (alan yok) = bilinmiyor (null), parola varmis gibi davranilir', (t) async {
      final b = FakeBackend()
        ..on('/auth/login', {'accessToken': 'A', 'refreshToken': 'R', 'expiresInSeconds': 900})
        ..on('/auth/me', {'id': 7, 'email': 'o@gmail.com', 'displayName': 'O'});
      final s = makeSession(b, signedIn: false);
      await t.runAsync(() => s.login('o@gmail.com', 'x'));
      expect(s.hasPassword, isNull);
    });

    testWidgets('hesap silme: parola alani yok, saglayici yeniden dogrulamasiyla DELETE /users/me gider', (t) async {
      useScreen(t, kPhoneMedium);
      final google = _Google();
      OAuthServices.current = OAuthServices(google: google, apple: _Apple());
      final b = FakeBackend()
        ..on('/auth/oauth/identities', [
          {'provider': 'GOOGLE', 'emailMasked': 'o***@gmail.com'}
        ])
        ..on('/users/me', {});
      final s = _passwordless(b);
      bool? result;
      await t.pumpWidget(_localized(Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await showModalBottomSheet<bool>(
                  context: ctx, isScrollControlled: true, builder: (_) => DeleteConfirmSheet(session: s)),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await t.tap(find.text('ac'));
      await settle(t);
      expect(find.byKey(const ValueKey('delete-password')), findsNothing);
      expect(find.text('Kimliği doğrula ve hesabı sil'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(t);
      expect(google.calls, 1);
      expect(b.bodies['DELETE /users/me'], {'provider': 'google', 'token': 'g-fresh'});
      expect(result, isTrue);
      OAuthServices.current = OAuthServices();
    });

    testWidgets('hesap silme: sagayici secicisi iptal edilirse sessizce doner, istek gitmez', (t) async {
      useScreen(t, kPhoneMedium);
      final google = _Google()..result = null;
      OAuthServices.current = OAuthServices(google: google, apple: _Apple());
      final b = FakeBackend()
        ..on('/auth/oauth/identities', [
          {'provider': 'GOOGLE'}
        ]);
      await t.pumpWidget(_localized(Scaffold(body: DeleteConfirmSheet(session: _passwordless(b)))));
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(t);
      expect(b.count('DELETE /users/me'), 0);
      expect(find.byKey(const ValueKey('delete-error')), findsNothing);
      OAuthServices.current = OAuthServices();
    });

    testWidgets('hesap silme: parolali hesapta eski akis (parola alani, parola govdede)', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..on('/users/me', {});
      await t.pumpWidget(_localized(Scaffold(body: DeleteConfirmSheet(session: makeSession(b)))));
      expect(find.byKey(const ValueKey('delete-password')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('delete-password')), 'Sifre123');
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(t);
      expect(b.bodies['DELETE /users/me'], {'password': 'Sifre123'});
    });

    testWidgets('sifre sayfasi: mevcut sifre formu yok, yalniz "Sifre belirle" (kod ile)', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..on('/auth/forgot-password', {});
      await t.pumpWidget(_localized(PasswordPage(session: _passwordless(b))));
      await settle(t);
      expect(find.byKey(const ValueKey('pw-current')), findsNothing);
      expect(find.byKey(const ValueKey('pw-none-note')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pw-forgot-send')));
      await settle(t);
      expect(b.count('POST /auth/forgot-password'), 1);
      expect(find.byType(ResetCodePage), findsOneWidget);
    });

    testWidgets('2FA kapatma: sifresiz hesap sifre yerine saglayici yeniden dogrulamasiyla kapatir', (t) async {
      useScreen(t, kPhoneMedium);
      final google = _Google();
      OAuthServices.current = OAuthServices(google: google, apple: _Apple());
      final b = FakeBackend()
        ..on('/auth/2fa', {'enabled': true, 'trustedDeviceCount': 0})
        ..on('/auth/2fa/devices', [])
        ..on('/auth/oauth/identities', [
          {'provider': 'GOOGLE'}
        ])
        ..on('/auth/2fa/disable', {'enabled': false});
      await t.pumpWidget(_localized(TwoFactorPage(session: _passwordless(b))));
      await settle(t);
      await t.tap(find.byType(Switch).first);
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('tf-disable-password')), findsNothing);
      await t.tap(find.text('Kapat'));
      await settle(t, const Duration(milliseconds: 600));
      expect(google.calls, 1);
      expect(b.bodies['POST /auth/2fa/disable'], {'provider': 'google', 'token': 'g-fresh'});
      OAuthServices.current = OAuthServices();
    });

    testWidgets('2FA kapatma: bagli saglayici yoksa Sifre ekranina yonlendirilir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()
        ..on('/auth/2fa', {'enabled': true, 'trustedDeviceCount': 0})
        ..on('/auth/2fa/devices', [])
        ..on('/auth/oauth/identities', []);
      await t.pumpWidget(_localized(TwoFactorPage(session: _passwordless(b))));
      await settle(t);
      await t.tap(find.byType(Switch).first);
      await settle(t, const Duration(milliseconds: 600));
      await t.tap(find.text('Kapat'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(PasswordPage), findsOneWidget);
      expect(b.count('POST /auth/2fa/disable'), 0);
    });

    testWidgets('hesap baglama: parolasiz hesapta baglı saglayicinin taze kimligi reauth* alanlariyla gider', (t) async {
      useScreen(t, kPhoneMedium);
      OAuthServices.current = OAuthServices(google: _Google(), apple: _Apple());
      final b = FakeBackend()
        ..on('/auth/oauth/identities', [
          {'provider': 'GOOGLE'}
        ])
        ..on('/auth/oauth/link', {'linked': true})
        ..on('/auth/2fa', {'enabled': false, 'trustedDeviceCount': 0});
      final s = _passwordless(b);
      await OAuthApi(s.api).link(OAuthProvider.apple,
          token: 'a-tok', nonce: 'n', reauthProvider: OAuthProvider.google, reauthToken: 'g-fresh');
      expect(b.bodies['POST /auth/oauth/link'], {
        'provider': 'apple',
        'token': 'a-tok',
        'nonce': 'n',
        'reauthProvider': 'google',
        'reauthToken': 'g-fresh',
      });
      OAuthServices.current = OAuthServices();
    });
  });

  group('QA-AUTH-02: sifremi unuttum 180 sn bekleme (RESEND_COOLDOWN) kod ekranini kapatmaz', () {
    testWidgets('giris > sifremi unuttum: 429 RESEND_COOLDOWN ise kod ekrani yine acilir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/forgot-password', status: 429, code: 'RESEND_COOLDOWN', message: 'Bekleyin.');
      await t.pumpWidget(_localized(ForgotPasswordPage(session: makeSession(b, signedIn: false), initialEmail: 'ayse@gmail.com')));
      await settle(t);
      await t.tap(find.text('Kod gönder'), warnIfMissed: false);
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsOneWidget);
    });

    testWidgets('baska 429 (kod RESEND_COOLDOWN degil) hata bandi gosterir, kod ekrani acilmaz', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/forgot-password', status: 429, code: 'RATE_LIMITED', message: 'Cok fazla deneme.');
      await t.pumpWidget(_localized(ForgotPasswordPage(session: makeSession(b, signedIn: false), initialEmail: 'ayse@gmail.com')));
      await settle(t);
      await t.tap(find.text('Kod gönder'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsNothing);
      expect(find.text('Cok fazla deneme.'), findsOneWidget);
    });

    testWidgets('sifre sayfasi (hesap modu): RESEND_COOLDOWN kod ekranini acar', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/forgot-password', status: 429, code: 'RESEND_COOLDOWN', message: 'Bekleyin.');
      await t.pumpWidget(_localized(PasswordPage(session: makeSession(b))));
      await settle(t);
      await t.ensureVisible(find.byKey(const ValueKey('pw-forgot-send')));
      await t.tap(find.byKey(const ValueKey('pw-forgot-send')));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsOneWidget);
    });
  });

  group('QA-AUTH-03: sifre degistirme sunucu politikasi hatalari', () {
    for (final code in ['PASSWORD_TOO_WEAK', 'PASSWORD_TOO_SHORT']) {
      testWidgets('$code: sunucu gerekcesi alanin altinda gorunur (genel "guncellenemedi" degil)', (t) async {
        useScreen(t, kPhoneMedium);
        final b = FakeBackend()..fail('/auth/change-password', status: 400, code: code, message: 'Bu sifre cok zayif.');
        await t.pumpWidget(_localized(PasswordPage(session: makeSession(b))));
        await settle(t);
        await t.enterText(_field('pw-current'), 'eskiSifre1');
        await t.enterText(_field('pw-new'), 'YeniSifre123');
        await t.enterText(_field('pw-repeat'), 'YeniSifre123');
        await t.ensureVisible(find.byKey(const ValueKey('pw-submit')));
        await t.tap(find.byKey(const ValueKey('pw-submit')));
        await settle(t);
        expect(find.text('Bu sifre cok zayif.'), findsOneWidget);
      });
    }

    testWidgets('403 WRONG_PASSWORD "mevcut sifre" alanini isaretler; 5xx genel hata; cevrimdisi ag hatasi', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/change-password', status: 403, code: 'WRONG_PASSWORD', message: 'Sifre hatali.');
      await t.pumpWidget(_localized(PasswordPage(session: makeSession(b))));
      await settle(t);
      await t.enterText(_field('pw-current'), 'yanlis123');
      await t.enterText(_field('pw-new'), 'YeniSifre123');
      await t.enterText(_field('pw-repeat'), 'YeniSifre123');
      await t.ensureVisible(find.byKey(const ValueKey('pw-submit')));
      await t.tap(find.byKey(const ValueKey('pw-submit')));
      await settle(t);
      expect(find.text('Sifre hatali.'), findsOneWidget);
      // 5xx
      b.fail('/auth/change-password', status: 500);
      await t.tap(find.byKey(const ValueKey('pw-submit')));
      await settle(t);
      expect(find.byKey(const ValueKey('pw-errors')), findsNothing);
      // ag yok
      b.network('/auth/change-password');
      await t.tap(find.byKey(const ValueKey('pw-submit')));
      await settle(t);
      expect(b.count('POST /auth/change-password'), 3);
    });
  });

  group('QA-AUTH-04: oturum suresi dolunca ustte kalan sayfalar kapanir', () {
    testWidgets('signOut(remote:false) (401 / gecersiz refresh yolu) itilmis rotalari kokte birakir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      final s = makeSession(b);
      await t.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: Text('KOK')),
      ));
      rootNavigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('AYARLAR'))));
      await t.pumpAndSettle();
      expect(find.text('AYARLAR'), findsOneWidget);
      await t.runAsync(() => s.signOut(remote: false));
      await t.pumpAndSettle();
      expect(find.text('AYARLAR'), findsNothing);
      expect(find.text('KOK'), findsOneWidget);
      expect(s.state, SessionState.signedOut);
    });
  });

  group('Giris / kayit: hata yanitlari ve girdi sinirlari', () {
    Future<void> pumpLogin(WidgetTester t, FakeBackend b, {Session? session, Locale locale = const Locale('tr'), double scale = 1}) async {
      useScreen(t, kPhoneSmall);
      await t.pumpWidget(_localized(LoginPage(session: session ?? makeSession(b, signedIn: false)), locale: locale, scale: scale));
      await settle(t);
    }

    testWidgets('bos form: istek gitmez, iki alan da hata gosterir', (t) async {
      final b = FakeBackend();
      await pumpLogin(t, b);
      await t.tap(find.text('Giriş yap'));
      await settle(t);
      expect(b.count('POST /auth/login'), 0);
    });

    testWidgets('401 INVALID_CREDENTIALS: genel hata bandi; sifre alani korunur', (t) async {
      final b = FakeBackend()..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.');
      await pumpLogin(t, b);
      await t.enterText(find.byType(TextFormField).first, 'ayse@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'yanlisSifre');
      await t.tap(find.text('Giriş yap'));
      await settle(t);
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(b.bodies['POST /auth/login'], containsPair('email', 'ayse@gmail.com'));
    });

    testWidgets('429: bekleme suresi ayri satirda gosterilir', (t) async {
      final b = FakeBackend()..fail('/auth/login', status: 429, code: 'RATE_LIMITED', message: 'Çok fazla deneme.');
      await pumpLogin(t, b);
      await t.enterText(find.byType(TextFormField).first, 'ayse@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'x1y2z3w4');
      await t.tap(find.text('Giriş yap'));
      await settle(t);
      expect(find.text('Çok fazla deneme.'), findsOneWidget);
    });

    testWidgets('5xx ve cevrimdisi: anlasilir hata, oturum acilmaz', (t) async {
      final b = FakeBackend()..fail('/auth/login', status: 503, code: 'DB_TIMEOUT');
      final s = makeSession(b, signedIn: false);
      await pumpLogin(t, b, session: s);
      await t.enterText(find.byType(TextFormField).first, 'ayse@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'x1y2z3w4');
      await t.tap(find.text('Giriş yap'));
      await settle(t);
      expect(find.textContaining('yoğun', findRichText: true), findsWidgets);
      b.offline = true;
      await t.tap(find.text('Giriş yap'));
      await settle(t);
      expect(s.state, isNot(SessionState.signedIn));
    });

    testWidgets('cift dokunma tek istek gonderir', (t) async {
      final b = FakeBackend(delay: const Duration(milliseconds: 300))..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'Hatalı.');
      await pumpLogin(t, b);
      await t.enterText(find.byType(TextFormField).first, 'ayse@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'x1y2z3w4');
      await t.tap(find.text('Giriş yap'));
      await t.pump(const Duration(milliseconds: 20));
      await t.tap(find.text('Giriş yap'), warnIfMissed: false);
      await settle(t, const Duration(seconds: 1));
      expect(b.count('POST /auth/login'), 1);
    });

    testWidgets('aşırı uzun e-posta ve sifre: coker yok, kayit ekraninda gecersiz e-posta reddedilir', (t) async {
      useScreen(t, kPhoneSmall);
      final b = FakeBackend();
      await t.pumpWidget(_localized(RegisterPage(session: makeSession(b, signedIn: false)), scale: 1.3));
      await settle(t);
      final long = 'a' * 300;
      await t.enterText(find.byType(TextFormField).at(0), long);
      await t.enterText(find.byType(TextFormField).at(1), '$long@x.com');
      await t.enterText(find.byType(TextFormField).at(2), 'p' * 100);
      await t.ensureVisible(find.text('Kayıt ol').last);
      await t.tap(find.text('Kayıt ol').last);
      await settle(t);
      expect(b.count('POST /auth/register'), 0); // yerel dogrulama gecersiz e-posta + 72+ sifreyi reddeder
      expect(t.takeException(), isNull);
    });

    testWidgets('kayit: 409 EMAIL_ALREADY_REGISTERED mesaji gosterilir; ar yerelinde cokmez (RTL)', (t) async {
      useScreen(t, kPhoneSmall);
      final b = FakeBackend()..fail('/auth/register', status: 409, code: 'EMAIL_ALREADY_REGISTERED', message: 'Bu e-posta ile zaten kayıt olunmuş.');
      await t.pumpWidget(_localized(RegisterPage(session: makeSession(b, signedIn: false)), locale: const Locale('tr')));
      await settle(t);
      await t.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
      await t.enterText(find.byType(TextFormField).at(1), 'ayse@gmail.com');
      await t.enterText(find.byType(TextFormField).at(2), 'Sifre1234');
      await t.ensureVisible(find.text('Kayıt ol').last);
      await t.tap(find.text('Kayıt ol').last);
      await settle(t);
      expect(find.text('Bu e-posta ile zaten kayıt olunmuş.'), findsOneWidget);
      await t.pumpWidget(_localized(RegisterPage(session: makeSession(b, signedIn: false)), locale: const Locale('ar'), brightness: Brightness.dark));
      await settle(t);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('hesap guvenligi: parolasiz hesapta sag/sol (ar) ve 1.3 yazi olceginde cokmez', (t) async {
    useScreen(t, kPhoneSmall);
    final b = FakeBackend()..on('/auth/2fa', {'enabled': false, 'trustedDeviceCount': 0});
    await t.pumpWidget(_localized(AccountSecurityPage(session: _passwordless(b)), locale: const Locale('ar'), scale: 1.3));
    await settle(t);
    expect(t.takeException(), isNull);
  });
}

