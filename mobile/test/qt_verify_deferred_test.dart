import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/verify_email_sheet.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Günlük e-posta sınırı aşılınca kayıt doğrulaması ertelenir: kullanıcı sisteme alınır (oturum), hesap doğrulanmamış
/// kalır; Profil sekmesinde "E-postanızı doğrulayın" kartı ve kod girişi çıkar; kısıtlı işlemde 403
/// EMAIL_VERIFICATION_REQUIRED bildirimi doğrulamaya yönlendirir.
Widget _app(Widget home, {Locale locale = const Locale('tr'), Brightness br = Brightness.light, double scale = 1}) => MaterialApp(
      navigatorKey: rootNavigatorKey,
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

Map<String, dynamic> _profile({bool? verified, bool complete = true}) => {
      'id': 1,
      'email': 'ayse@bingol.edu.tr',
      'displayName': 'Ayşe Yılmaz',
      if (complete) ...{'faculty': 'Mühendislik Fakültesi', 'department': 'Bilgisayar Mühendisliği', 'grade': '3'},
      'role': 'USER',
      'postCount': 0,
      'reelCount': 0,
      if (verified != null) 'emailVerified': verified,
      if (verified == false) 'verificationDeferred': true,
    };

FakeBackend _profileBackend({bool? verified}) {
  final b = FakeBackend()
    ..on('/me/summary', {'communities': 0, 'events': 0, 'bookmarks': 0})
    ..on('/users/me', _profile(verified: verified))
    ..on('/users/1', {'id': 1, 'followerCount': 0, 'followingCount': 0, 'followedByMe': false});
  fakeCatalog(b);
  fakePosts(b, count: 0, empty: true);
  return b;
}

Future<Session> _openProfile(WidgetTester tester, FakeBackend b, {Size size = kPhoneMedium, Locale locale = const Locale('tr'), Brightness br = Brightness.light, double scale = 1}) async {
  useScreen(tester, size);
  final s = makeSession(b);
  await tester.pumpWidget(_app(ProfileTab(session: s, themeController: ThemeController()), locale: locale, br: br, scale: scale));
  await settle(tester, const Duration(milliseconds: 1200));
  return s;
}

Finder _card() => find.byKey(const ValueKey('verify-email-card'));

void main() {
  setUpAll(loadTestFonts);
  setUp(VerifyPrompt.resetForTest);

  group('kayıt: doğrulama ertelendi', () {
    testWidgets('201 + jetonlar + verificationDeferred: oturum açılır, kod ekranı AÇILMAZ, bölüm/sınıf adımı gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/auth/register', {
          'accessToken': 'a.b.c',
          'refreshToken': 'r1',
          'email': '226051015@bingol.edu.tr',
          'emailVerified': false,
          'verificationDeferred': true,
        }, status: 201)
        ..on('/users/me', _profile(verified: false, complete: false));
      fakeCatalog(b);
      final s = makeSession(b, signedIn: false);
      // Kök ekranı main.dart gibi oturum durumuna göre değişir: çıkışta kayıt düğmesi, girişte zorunlu profil kapısı.
      await tester.pumpWidget(_app(ListenableBuilder(
        listenable: s,
        builder: (context, _) => s.state == SessionState.signedIn
            ? ProfileCompletionGate(session: s, child: const Scaffold(body: Text('KABUK')))
            : Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage(session: s))),
                    child: const Text('AC'),
                  ),
                ),
              ),
      )));
      await tester.tap(find.text('AC'));
      await settle(tester, const Duration(milliseconds: 900));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodies['POST /auth/register'], containsPair('acceptTerms', true));
      expect(s.state, SessionState.signedIn);
      expect(s.emailUnverified.value, isTrue);
      expect(find.byType(VerifyCodePage), findsNothing);
      expect(find.byType(RegisterPage), findsNothing);
      // Bölüm + sınıf zorunlu adımı (profil kapısı) açık; kabuk henüz yok.
      expect(find.byKey(const ValueKey('profile-setup-gate')), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('normal kayıt (202): doğrulama kodu ekranı açılır, oturum açılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/auth/register', {'email': '226051015@bingol.edu.tr'}, status: 202);
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 900));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(s.state, isNot(SessionState.signedIn));
      expect(s.emailUnverified.value, isFalse);
      await unmount(tester);
    });

    testWidgets('verificationDeferred true ama jeton yok: ertelenmiş sayılmaz (kod ekranı)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/auth/register', {'email': '226051015@bingol.edu.tr', 'verificationDeferred': true}, status: 201);
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 900));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('profil doğrulama kartı', () {
    testWidgets('emailVerified:false: kart görünür; true ya da alan yok: HİÇ iz yok', (tester) async {
      await _openProfile(tester, _profileBackend(verified: false));
      expect(_card(), findsOneWidget);
      expect(find.text('E-postanızı doğrulayın'), findsOneWidget);
      expect(find.text('Doğrulanana kadar bazı işlemler (gönderi, mesaj, takip...) kapalıdır.'), findsOneWidget);
      expect(find.text('Kodu gir'), findsOneWidget);
      await unmount(tester);

      await _openProfile(tester, _profileBackend(verified: true));
      expect(_card(), findsNothing);
      expect(find.text('E-postanızı doğrulayın'), findsNothing);
      await unmount(tester);

      await _openProfile(tester, _profileBackend());
      expect(_card(), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('kod girişi başarılı: kart kaybolur, "E-postanız doğrulandı", doğru uç ve gövde', (tester) async {
      final b = _profileBackend(verified: false)..on('/auth/verification/verify', {'emailVerified': true});
      final s = await _openProfile(tester, b);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(VerifyEmailSheetBody), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await settle(tester, const Duration(seconds: 1));
      expect(b.bodies['POST /auth/verification/verify'], {'code': '123456'});
      expect(s.emailUnverified.value, isFalse);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(VerifyEmailSheetBody), findsNothing);
      expect(_card(), findsNothing);
      expect(find.text('E-postanız doğrulandı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('yanlış kod: hata gösterilir, sayfa ve kart kalır, doğrulanmış sayılmaz', (tester) async {
      final b = _profileBackend(verified: false)
        ..fail('/auth/verification/verify', status: 400, code: 'INVALID_CODE', message: 'Kod hatalı.');
      final s = await _openProfile(tester, b);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField), '000000');
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Kod hatalı.'), findsOneWidget);
      expect(find.byType(VerifyEmailSheetBody), findsOneWidget);
      expect(s.emailUnverified.value, isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('eksik kod ("Doğrula" 6 hane olmadan): uyarı, istek atılmaz', (tester) async {
      final b = _profileBackend(verified: false);
      await _openProfile(tester, b);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      await tester.tap(find.text('Doğrula').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('6 haneli kodu girin.'), findsOneWidget);
      expect(b.count('/auth/verification/verify'), 0);
      await unmount(tester);
    });

    testWidgets('yeniden gönder: başarıda bilgi + geri sayım; 429 MAIL_QUOTA_EXCEEDED: kota bilgisi, kod girişi açık', (tester) async {
      final b = _profileBackend(verified: false)..on('/auth/verification/resend', {'status': 'SENT'});
      await _openProfile(tester, b);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('POST /auth/verification/resend'), 1);
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
      expect(find.textContaining('Yeniden gönder ('), findsOneWidget);
      await unmount(tester);

      final q = _profileBackend(verified: false)..fail('/auth/verification/resend', status: 429, code: 'MAIL_QUOTA_EXCEEDED', message: 'Kota doldu.');
      await _openProfile(tester, q);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('verify-quota-info')), findsOneWidget);
      expect(find.textContaining('en kısa sürede göndereceğiz'), findsOneWidget);
      expect(find.text('Kota doldu.'), findsNothing); // hata değil bilgi
      expect(find.byType(TextField), findsOneWidget); // kod girişi açık
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('sözleşme ayrıntıları', () {
    testWidgets('emailVerified:false ama verificationDeferred:false: kart çıkmaz (yalnız ertelenmiş hesaplar)', (tester) async {
      final b = _profileBackend()..on('/users/me', {..._profile(), 'emailVerified': false, 'verificationDeferred': false});
      await _openProfile(tester, b);
      expect(_card(), findsNothing);
      await unmount(tester);
    });

    testWidgets('ertelenmiş hesap girişi (200 + jetonlar + emailVerified:false): oturum açılır, durum doğrulanmamış', (tester) async {
      final b = FakeBackend()
        ..on('/auth/login', {'accessToken': 'a.b.c', 'refreshToken': 'r1', 'emailVerified': false, 'verificationDeferred': true});
      final s = makeSession(b, signedIn: false);
      await tester.runAsync(() => s.login('226051015', 'Sifre1234'));
      expect(s.state, SessionState.signedIn);
      expect(s.emailUnverified.value, isTrue);
      expect(b.bodies['POST /auth/login'], containsPair('client', 'mobile'));
    });

    testWidgets('normal giriş (alan yok): doğrulanmamış işareti konmaz', (tester) async {
      final b = FakeBackend()..on('/auth/login', {'accessToken': 'a.b.c', 'refreshToken': 'r1'});
      final s = makeSession(b, signedIn: false);
      await tester.runAsync(() => s.login('226051015', 'Sifre1234'));
      expect(s.emailUnverified.value, isFalse);
    });

    testWidgets('yeniden gönder 409 EMAIL_ALREADY_VERIFIED: sayfa kapanır, kart kaybolur', (tester) async {
      final b = _profileBackend(verified: false)..fail('/auth/verification/resend', status: 409, code: 'EMAIL_ALREADY_VERIFIED');
      final s = await _openProfile(tester, b);
      await tester.tap(find.text('Kodu gir'));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(VerifyEmailSheetBody), findsNothing);
      expect(s.emailUnverified.value, isFalse);
      expect(_card(), findsNothing);
      await unmount(tester);
    });
  });

  group('403 EMAIL_VERIFICATION_REQUIRED', () {
    testWidgets('bildirim + "Doğrula" eylemi doğrulama sayfasını açar; durum doğrulanmamış olur; art arda tek bildirim', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..fail('/posts', status: 403, code: 'EMAIL_VERIFICATION_REQUIRED', message: 'E-posta doğrulanmadı.');
      final s = makeSession(b);
      await tester.pumpWidget(_app(const Scaffold(body: SizedBox.expand())));
      await settle(tester, const Duration(milliseconds: 300));
      expect(s.emailUnverified.value, isFalse);
      Object? err;
      for (var i = 0; i < 3; i++) {
        try {
          await s.api.post('/posts', {'text': 'x'});
        } catch (e) {
          err = e;
        }
      }
      expect(errorText(err!), 'Bu işlem için e-postanızı doğrulayın');
      await settle(tester, const Duration(milliseconds: 700));
      expect(s.emailUnverified.value, isTrue);
      expect(find.text('Bu işlem için e-postanızı doğrulayın'), findsOneWidget);
      await tester.tap(find.text('Doğrula'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VerifyEmailSheetBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('çağıran kendi hata bildirimini gösterse de eylemli bildirim üstte kalır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/follow', status: 403, code: 'EMAIL_VERIFICATION_REQUIRED');
      final s = makeSession(b);
      await tester.pumpWidget(_app(Builder(builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                try {
                  await s.api.post('/follow');
                } catch (e) {
                  if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
                }
              },
              child: const Text('TAKIP'),
            ),
          ))));
      await tester.tap(find.text('TAKIP'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Doğrula'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('görünüm matrisi', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final br in Brightness.values) {
        for (final size in const [Size(320, 640), Size(390, 844)]) {
          testWidgets('kart + kod sayfası | $lang ${br.name} ${size.width.toInt()} x1.3', (tester) async {
            LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
            addTearDown(() => LocaleController.current = null);
            await _openProfile(tester, _profileBackend(verified: false), size: size, locale: Locale(lang), br: br, scale: 1.3);
            expect(_card(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(find.descendant(of: _card(), matching: find.byType(BuButton)));
            await settle(tester, const Duration(milliseconds: 800));
            expect(find.byType(VerifyEmailSheetBody), findsOneWidget);
            expect(tester.takeException(), isNull);
            await unmount(tester);
          });
        }
      }
    }
  });
}
