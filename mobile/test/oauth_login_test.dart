import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/oauth/oauth_services.dart';
import 'package:bu_kampus/core/oauth_config.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/auth_landing_page.dart';
import 'package:bu_kampus/features/auth/data/onboarding_api.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/two_factor_code_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/onboarding/onboarding_flow.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Google / Apple ile giriş: karşılama ekranı (bayraklar, düğmeler, iptal, çift dokunma, hata dalları) ve oturum katmanı.
/// Gerçek Google/Apple girişi bu ortamda YAPILAMAZ (cihaz/kimlik yok): sağlayıcı SDK'ları sahte uygulamalarla değiştirilir.
class FakeGoogle implements GoogleSignInService {
  int calls = 0;
  GoogleCredential? result = const GoogleCredential(idToken: 'google-id-token', displayName: 'Ayşe Yılmaz');
  Object? error;
  Completer<void>? gate;

  @override
  Future<GoogleCredential?> signIn() async {
    calls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result;
  }
}

class FakeApple implements AppleSignInService {
  int calls = 0;
  AppleCredential? result =
      const AppleCredential(identityToken: 'apple-identity', nonce: 'raw-nonce', firstName: 'Zeynep', lastName: 'Kaya');
  Object? error;

  @override
  Future<AppleCredential?> signIn() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

const _googleKey = ValueKey('oauth-google');
const _appleKey = ValueKey('oauth-apple');
const _emailKey = ValueKey('landing-email');

const _allOn = OAuthConfig(
  googleFlag: true,
  googleServerClientId: 'web-client.apps.googleusercontent.com',
  appleFlag: true,
  appleSupportedPlatform: true,
);

Map<String, dynamic> _loginOk({bool completed = true, bool isNew = false}) =>
    {'accessToken': 'a', 'refreshToken': 'r', 'profileCompleted': completed, 'isNewUser': isNew};

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  late FakeGoogle google;
  late FakeApple apple;

  setUp(() async {
    google = FakeGoogle();
    apple = FakeApple();
    OAuthServices.current = OAuthServices(google: google, apple: apple);
    OAuthConfig.current = _allOn;
    await OnboardingDraftStore.clear();
  });

  tearDown(() {
    OAuthConfig.current = const OAuthConfig();
    OAuthServices.current = OAuthServices();
  });

  Future<(FakeBackend, Session)> open(WidgetTester tester,
      {Size size = kPhoneMedium, Brightness br = Brightness.light, FakeBackend? backend}) async {
    useScreen(tester, size);
    final b = backend ?? FakeBackend();
    final s = makeSession(b, signedIn: false);
    await tester.pumpWidget(buildApp(AuthLandingPage(session: s), brightness: br));
    await settle(tester, const Duration(milliseconds: 600));
    return (b, s);
  }

  group('yapılandırma ve görünürlük', () {
    test('OAuthConfig: bayrak + kimlik + platform kuralları', () {
      expect(const OAuthConfig().googleEnabled, isFalse);
      expect(const OAuthConfig().appleEnabled, isFalse);
      expect(const OAuthConfig(googleFlag: true).googleEnabled, isFalse, reason: 'web istemci kimliği yok');
      expect(const OAuthConfig(googleFlag: true, googleServerClientId: ' ').googleEnabled, isFalse);
      expect(const OAuthConfig(googleServerClientId: 'x').googleEnabled, isFalse, reason: 'bayrak kapalı');
      expect(_allOn.googleEnabled, isTrue);
      expect(const OAuthConfig(appleFlag: true).appleEnabled, isFalse, reason: 'Android/diğer: gizli');
      expect(const OAuthConfig(appleFlag: true, appleSupportedPlatform: true).appleEnabled, isTrue);
      expect(const OAuthConfig(appleSupportedPlatform: true).appleEnabled, isFalse, reason: 'bayrak kapalı');
    });

    test('Google: SDK derlemede, varsayılan kimlikler dolu ve Info.plist ile tutarlı, bayrak varsayılan AÇIK', () {
      expect(kGoogleSignInCompiled, isTrue);
      final env = OAuthConfig.fromEnvironment();
      expect(env.googleServerClientId, kDefaultGoogleServerClientId);
      expect(env.googleIosClientId, kDefaultGoogleIosClientId);
      expect(env.googleServerClientId, endsWith('.apps.googleusercontent.com'));
      expect(env.googleIosClientId, endsWith('.apps.googleusercontent.com'));
      expect(env.googleServerClientId, isNot(env.googleIosClientId), reason: 'web ve iOS istemcileri ayrı');
      expect(env.googleEnabled, isTrue, reason: 'GOOGLE_SIGNIN varsayılan açık (I2-01: Android AAB komutunda bayrak yok)');
      // iOS: Info.plist GIDClientID + ters kimlik URL şeması bu sabitle birebir aynı olmalı.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>GIDClientID</key>'));
      expect(plist, contains('<string>$kDefaultGoogleIosClientId</string>'));
      final reversed = 'com.googleusercontent.apps.${kDefaultGoogleIosClientId.replaceAll('.apps.googleusercontent.com', '')}';
      expect(plist, contains('<string>$reversed</string>'));
    });

    testWidgets('bayraklar kapalı: Google/Apple yok, "veya" yok, e-posta düğmesi ana düğme', (tester) async {
      OAuthConfig.current = const OAuthConfig();
      await open(tester);
      expect(find.byKey(_googleKey), findsNothing);
      expect(find.byKey(_appleKey), findsNothing);
      expect(find.text('veya'), findsNothing);
      expect(find.text('Google ile devam et'), findsNothing);
      expect(find.text('Apple ile devam et'), findsNothing);
      expect(find.text('Kampüsün burada.'), findsOneWidget);
      expect(find.text('Paylaş, keşfet ve topluluğuna katıl.'), findsOneWidget);
      expect(find.byKey(_emailKey), findsOneWidget);
      expect(find.text('E-posta ile devam et'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yalnız Google bayrağı açık: Google görünür, Apple görünmez', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web');
      await open(tester);
      expect(find.byKey(_googleKey), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.byKey(_appleKey), findsNothing);
      expect(find.text('veya'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Android: Apple bayrağı açık olsa da Apple düğmesi gizli', (tester) async {
      OAuthConfig.current = const OAuthConfig(appleFlag: true); // appleSupportedPlatform=false (Android)
      await open(tester);
      expect(find.byKey(_appleKey), findsNothing);
      expect(find.text('Apple ile devam et'), findsNothing);
      await unmount(tester);
    });

    testWidgets('üç yöntem: Google, Apple, ayırıcı ve E-posta; yasal bağlantılar ve kayıt geçişi', (tester) async {
      await open(tester);
      expect(find.byKey(_googleKey), findsOneWidget);
      expect(find.byKey(_appleKey), findsOneWidget);
      expect(find.text('Apple ile devam et'), findsOneWidget);
      expect(find.text('veya'), findsOneWidget);
      expect(find.text('E-posta ile devam et'), findsOneWidget);
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Kayıt ol'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('landing-terms')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(LegalDocPage), findsOneWidget);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        testWidgets('taşma yok: ${br.name} ${size.width.toInt()}x${size.height.toInt()}, 3 yöntem açık', (tester) async {
          await open(tester, size: size, br: br);
          expect(tester.takeException(), isNull);
          final box = tester.getSize(find.byKey(_googleKey));
          expect(box.height, greaterThanOrEqualTo(48), reason: 'dokunma hedefi >= 48 dp');
          expect(find.bySemanticsLabel('Google ile devam et'), findsWidgets);
          await unmount(tester);
        });
      }
    }

    testWidgets('e-posta ile devam et: e-posta/şifre girişi (LoginPage) açılır', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(_emailKey));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(LoginPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Google ile devam et', () {
    testWidgets('başarı (mevcut hesap, profil tamam): gövde sözleşmeye uygun, oturum açılır', (tester) async {
      final b = FakeBackend()..on('/auth/oauth/google', _loginOk());
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(google.calls, 1);
      expect(s.state, SessionState.signedIn);
      expect(s.profileCompletedHint, isTrue);
      final body = b.bodies['POST /auth/oauth/google'] as Map;
      expect(body['idToken'], 'google-id-token');
      expect(body['client'], 'mobile');
      expect(body.containsKey('nonce'), isFalse);
      // Profili tamam kullanıcıda onboarding taslağı yazılmaz.
      expect(await OnboardingDraftStore.load(), isNull);
      await unmount(tester);
    });

    testWidgets('yeni kullanıcı: profileCompleted=false ipucu + ad/soyad ön doldurma taslağı', (tester) async {
      final b = FakeBackend()..on('/auth/oauth/google', _loginOk(completed: false, isNew: true));
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(s.state, SessionState.signedIn);
      expect(s.profileCompletedHint, isFalse);
      final d = await OnboardingDraftStore.load();
      expect(d?.firstName, 'Ayşe');
      expect(d?.lastName, 'Yılmaz');
      await unmount(tester);
    });

    testWidgets('sunucu yanıtındaki firstName/lastName ön doldurmada displayName\'e tercih edilir', (tester) async {
      final b = FakeBackend()
        ..on('/auth/oauth/google', {..._loginOk(completed: false), 'user': {'firstName': 'Mehmet', 'lastName': 'Demir'}});
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(s.state, SessionState.signedIn);
      final d = await OnboardingDraftStore.load();
      expect((d?.firstName, d?.lastName), ('Mehmet', 'Demir'));
      await unmount(tester);
    });

    testWidgets('iptal: sessiz dönüş, hata yok, istek yok', (tester) async {
      google.result = null;
      final b = FakeBackend();
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(google.calls, 1);
      expect(b.count('/auth/oauth'), 0);
      expect(s.state, isNot(SessionState.signedIn));
      expect(find.byKey(const ValueKey('oauth-link-card')), findsNothing);
      expect(find.textContaining('tamamlanamadı'), findsNothing);
      // Düğme yeniden kullanılabilir.
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(google.calls, 2);
      await unmount(tester);
    });

    testWidgets('çift dokunma tek istek üretir; sürerken Apple/e-posta da pasif', (tester) async {
      google.gate = Completer<void>();
      final b = FakeBackend()..on('/auth/oauth/google', _loginOk());
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await tester.pump();
      await tester.tap(find.byKey(_googleKey), warnIfMissed: false);
      await tester.tap(find.byKey(_appleKey), warnIfMissed: false);
      await tester.tap(find.byKey(_emailKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(google.calls, 1);
      expect(apple.calls, 0);
      expect(find.byType(LoginPage), findsNothing);
      google.gate!.complete();
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.count('POST /auth/oauth/google'), 1);
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });

    testWidgets('SDK hatası: genel hata bandı, düğme geri açılır', (tester) async {
      google.error = const OAuthFailure('clientConfigurationError');
      final (_, s) = await open(tester);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Giriş tamamlanamadı. Lütfen tekrar dene.'), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      await unmount(tester);
    });

    testWidgets('internet yok: ağ hatası metni gösterilir', (tester) async {
      final b = FakeBackend()..offline = true;
      await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text(errorText(ApiError(0, 'NETWORK', ''))), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('409 OAUTH_LINK_REQUIRED: anlaşılır yönlendirme + e-posta ile giriş düğmesi, otomatik birleşme yok', (tester) async {
      final b = FakeBackend()
        ..on('/auth/oauth/google', {'code': 'OAUTH_LINK_REQUIRED', 'message': 'x', 'provider': 'google', 'emailMasked': 'a***@gmail.com'},
            status: 409);
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 500));
      expect(s.state, isNot(SessionState.signedIn));
      expect(find.text('Bu e-posta ile zaten bir hesabın var'), findsOneWidget);
      expect(find.textContaining('Hesap ve güvenlik bölümünden Google hesabını bağla'), findsOneWidget);
      expect(find.textContaining('a***@gmail.com'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('oauth-link-email')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(LoginPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('404 OAUTH_DISABLED: düğme bu oturum için gizlenir, kısa mesaj gösterilir', (tester) async {
      final b = FakeBackend()..fail('/auth/oauth/google', status: 404, code: 'OAUTH_DISABLED');
      await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(_googleKey), findsNothing);
      expect(find.byKey(_appleKey), findsOneWidget, reason: 'diğer sağlayıcı etkilenmez');
      expect(find.textContaining('Bu giriş yöntemi şu an kullanılamıyor'), findsOneWidget);
      await unmount(tester);
    });

    for (final c in const {
      'OAUTH_TOKEN_INVALID': 'Giriş doğrulanamadı. Lütfen tekrar dene.',
      'OAUTH_EMAIL_UNVERIFIED': 'Bu hesabın e-posta adresi sağlayıcıda doğrulanmamış. Önce adresi doğrula ya da e-posta ile devam et.',
      'OAUTH_EMAIL_MISSING': 'Hesabından e-posta adresi alınamadı. E-posta ile devam edebilirsin.',
    }.entries) {
      testWidgets('${c.key}: yerel metin', (tester) async {
        final b = FakeBackend()..fail('/auth/oauth/google', status: 400, code: c.key);
        await open(tester, backend: b);
        await tester.tap(find.byKey(_googleKey));
        await settle(tester, const Duration(milliseconds: 500));
        expect(find.text(c.value), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('2FA\'lı hesap: oturum açılmaz, mevcut kod ekranı açılır', (tester) async {
      final b = FakeBackend()
        ..on('/auth/oauth/google',
            {'twoFactorRequired': true, 'challengeToken': 'ct', 'emailHint': 'a***@bingol.edu.tr', 'expiresInSeconds': 600},
            status: 202);
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_googleKey));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(TwoFactorLoginPage), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      await unmount(tester);
    });
  });

  group('Apple ile devam et', () {
    testWidgets('başarı: HAM nonce + identityToken + ilk yetkilendirme adı gönderilir; ad güvenli depoya yazılır', (tester) async {
      final b = FakeBackend()..on('/auth/oauth/apple', _loginOk(completed: false, isNew: true));
      final (_, s) = await open(tester, backend: b);
      await tester.tap(find.byKey(_appleKey));
      await settle(tester, const Duration(milliseconds: 500));
      expect(apple.calls, 1);
      expect(s.state, SessionState.signedIn);
      final body = b.bodies['POST /auth/oauth/apple'] as Map;
      expect(body['identityToken'], 'apple-identity');
      expect(body['nonce'], 'raw-nonce');
      expect(body['firstName'], 'Zeynep');
      expect(body['lastName'], 'Kaya');
      expect(body['client'], 'mobile');
      final d = await OnboardingDraftStore.load();
      expect((d?.firstName, d?.lastName), ('Zeynep', 'Kaya'));
      await unmount(tester);
    });

    testWidgets('ad gelmediyse (sonraki girişler) gövdede firstName/lastName yok', (tester) async {
      apple.result = const AppleCredential(identityToken: 't', nonce: 'n');
      final b = FakeBackend()..on('/auth/oauth/apple', _loginOk());
      await open(tester, backend: b);
      await tester.tap(find.byKey(_appleKey));
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['POST /auth/oauth/apple'] as Map;
      expect(body.containsKey('firstName'), isFalse);
      expect(body.containsKey('lastName'), isFalse);
      await unmount(tester);
    });

    testWidgets('istek başarısız olsa da Apple\'ın bir kez verdiği ad kaybolmaz (yerel depo)', (tester) async {
      final b = FakeBackend()..offline = true;
      await open(tester, backend: b);
      await tester.tap(find.byKey(_appleKey));
      await settle(tester, const Duration(milliseconds: 600));
      // Hesap henüz bilinmiyor: ad geçici anahtarda bekler, hesap belli olunca o hesabın taslağına katılır.
      OnboardingDraftStore.activeUserId = 42;
      await OnboardingDraftStore.savePrefill();
      final d = await OnboardingDraftStore.load();
      expect((d?.firstName, d?.lastName), ('Zeynep', 'Kaya'));
      OnboardingDraftStore.activeUserId = null;
      await unmount(tester);
    });

    testWidgets('iptal: sessiz', (tester) async {
      apple.result = null;
      final b = FakeBackend();
      await open(tester, backend: b);
      await tester.tap(find.byKey(_appleKey));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.count('/auth/oauth'), 0);
      expect(find.textContaining('tamamlanamadı'), findsNothing);
      await unmount(tester);
    });
  });

  group('3 dil x 2 tema x dar ekran x büyük yazı: taşma/istisna yok (Arapça RTL dahil)', () {
    Widget app(Widget home, Locale loc, Brightness br) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.light(),
          darkTheme: BuTheme.dark(),
          themeMode: br == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          locale: loc,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
          home: home,
        );

    for (final lang in ['tr', 'en', 'ar']) {
      for (final br in Brightness.values) {
        for (final screen in ['landing', 'onboarding']) {
          testWidgets('$screen | $lang ${br.name} 320x640 x1.3', (tester) async {
            useScreen(tester, kPhoneSmall);
            LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
            addTearDown(() => LocaleController.current = null);
            final b = FakeBackend();
            fakeCatalog(b);
            final s = makeSession(b, signedIn: screen == 'onboarding');
            final Widget home = screen == 'landing' ? AuthLandingPage(session: s) : OnboardingFlow(session: s, onDone: () {});
            await tester.pumpWidget(app(home, Locale(lang), br));
            await settle(tester, const Duration(milliseconds: 1200));
            expect(tester.takeException(), isNull);
            await unmount(tester);
          });
        }
      }
    }
  });

  group('servis yardımcıları', () {
    test('sha256Hex bilinen test vektörü', () {
      expect(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });

    test('newOAuthNonce: 32 bayt, URL güvenli, her seferinde farklı', () {
      final a = newOAuthNonce(), b = newOAuthNonce();
      expect(a, isNot(b));
      expect(a.length, 43);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(a), isTrue);
    });

    test('OAuthProvider.tryParse', () {
      expect(OAuthProvider.tryParse('GOOGLE'), OAuthProvider.google);
      expect(OAuthProvider.tryParse('apple'), OAuthProvider.apple);
      expect(OAuthProvider.tryParse('github'), isNull);
      expect(OAuthProvider.tryParse(null), isNull);
    });

    test('kimlik nesneleri toString jeton sızdırmaz', () {
      expect(const GoogleCredential(idToken: 'secret').toString(), isNot(contains('secret')));
      expect(const AppleCredential(identityToken: 'secret', nonce: 'n').toString(), isNot(contains('secret')));
    });
  });
}
