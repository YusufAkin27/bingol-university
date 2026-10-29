import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/otp_code_boxes.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/auth/widgets/auth_controls.dart';
import 'package:bu_kampus/features/auth/widgets/auth_motion.dart';
import 'package:bu_kampus/features/legal/legal_reaccept.dart';
import 'package:bu_kampus/features/legal/legal_reaccept_page.dart';
import 'package:bu_kampus/features/system/splash_screen.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Kimlik akışı yeniden tasarımı (AUTH1): her ekran 3 dil x 2 tema x 2 boyut x 2 yazı ölçeğinde taşmadan çizilir;
/// yeni bileşenlerin davranışları (satır içi doğrulama, yapıştırma, deneme sınırı, dil sayfası, başarı ekranı).
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

Session _s(FakeBackend b) => makeSession(b, signedIn: false);

final _screens = <String, Widget Function(FakeBackend b)>{
  'splash': (b) => const SplashScreen(),
  'welcome': (b) => WelcomePage(onLogin: () {}, onRegister: () {}),
  'login': (b) => LoginPage(session: _s(b)),
  'register': (b) => RegisterPage(session: _s(b)),
  'verify': (b) => VerifyCodePage(session: _s(b), email: 'ayse.cok.uzun.eposta.adresi@ogr.bingol.edu.tr', unverified: true),
  'forgot': (b) => ForgotPasswordPage(session: _s(b)),
  'resetCode': (b) => ResetCodePage(session: _s(b), email: 'ayse@bingol.edu.tr'),
  'newPassword': (b) => NewPasswordPage(session: _s(b), email: 'ayse@bingol.edu.tr', resetToken: 't'),
  'success': (b) => const ResetSuccessPage(),
  'legal': (b) => LegalReacceptPage(
        session: _s(b),
        state: const LegalReaccept([LegalItem('TERMS', 3), LegalItem('PRIVACY', 3), LegalItem('KVKK', 2)], enforced: false),
      ),
};

void main() {
  setUpAll(loadTestFonts);

  group('ekran matrisi: taşma/istisna yok', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final br in Brightness.values) {
        for (final size in const [Size(320, 640), Size(390, 844)]) {
          for (final scale in const [1.0, 1.3]) {
            _screens.forEach((name, build) {
              testWidgets('$name | $lang ${br.name} ${size.width.toInt()}x${size.height.toInt()} x$scale', (tester) async {
                useScreen(tester, size);
                final b = FakeBackend();
                fakeCatalog(b);
                LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
                addTearDown(() => LocaleController.current = null);
                await tester.pumpWidget(_app(build(b), locale: Locale(lang), br: br, scale: scale));
                await settle(tester, const Duration(milliseconds: 1600));
                expect(tester.takeException(), isNull);
                await unmount(tester);
              });
            });
          }
        }
      }
    }
  });

  group('karşılama', () {
    testWidgets('düğmeler geri çağırır; dil düğmesi dil sayfasını açar ve dili değiştirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      var login = 0, register = 0;
      final lc = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      LocaleController.current = lc;
      addTearDown(() => LocaleController.current = null);
      mockSecureStorage();
      await tester.pumpWidget(_app(WelcomePage(onLogin: () => login++, onRegister: () => register++)));
      await settle(tester, const Duration(milliseconds: 1800));
      await tester.tap(find.text('Giriş yap'));
      await tester.tap(find.text('Hesap oluştur'));
      expect((login, register), (1, 1));
      await tester.tap(find.text('TR'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Dil seçin'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('English'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(lc.pref, 'en');
      await unmount(tester);
    });
  });

  group('satır içi doğrulama', () {
    testWidgets('e-posta alanı: yazarken hata yok, alandan çıkınca hata, düzeltince anında kalkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(_app(ForgotPasswordPage(session: _s(b))));
      await settle(tester, const Duration(milliseconds: 1200));
      const err = 'Okul numaranızı veya e-posta adresinizi girin.';
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'ayse@gmail.com');
      await tester.pump();
      expect(find.textContaining('bingol.edu.tr uzantılı', findRichText: true), findsNothing);
      // Alandan çık: odak başka yere.
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.textContaining('bingol.edu.tr'), findsWidgets);
      expect(find.text(err), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'ayse@bingol.edu.tr');
      await tester.pump();
      expect(find.textContaining('uzantılı'), findsNothing);
      await unmount(tester);
    });

    testWidgets('kayıt: parola kuralları yazdıkça tik alır', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(_app(RegisterPage(session: _s(b))));
      await settle(tester, const Duration(milliseconds: 600));
      await fillRegister(tester, password: 'abc');
      List<bool> rules() => tester.widgetList<AuthRule>(find.byType(AuthRule)).map((w) => w.ok).toList();
      expect(rules(), [false, false]);
      await tester.enterText(find.byType(TextFormField).first, 'abcdefgh');
      await tester.pump();
      expect(rules(), [true, false]);
      await tester.enterText(find.byType(TextFormField).first, 'abcdefg1');
      await tester.pump();
      expect(rules(), [true, true]);
      await unmount(tester);
    });
  });

  group('kod girişi', () {
    testWidgets('Yapıştır panodaki 6 haneyi yazar ve tamamlanınca onCompleted çağırır', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      var done = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': 'Kodunuz: 482 913'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_app(Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: OtpCodeBoxes(controller: c, onCompleted: () => done++)))));
      await tester.pump();
      await tester.tap(find.text('Yapıştır'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(c.text, '482913');
      expect(done, 1);
      // Dolu alanda yapıştır kısayolu gizlenir.
      expect(find.text('Yapıştır'), findsNothing);
      await unmount(tester);
    });

    testWidgets('verify: TOO_MANY_ATTEMPTS mesajı gösterir, kodu temizler ve beklemeden yeniden gönderi açar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..fail('/auth/verify-email', status: 429, code: 'TOO_MANY_ATTEMPTS', message: 'Çok fazla hatalı deneme. Yeni kod isteyin.');
      final s = _s(b)..rememberCredentials('a@bingol.edu.tr', 'Sifre1234');
      await tester.pumpWidget(_app(VerifyCodePage(session: s, email: 'a@bingol.edu.tr')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('Kodu yeniden gönder'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Çok fazla hatalı deneme. Yeni kod isteyin.'), findsOneWidget);
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, '');
      await unmount(tester);
    });
  });

  group('başarı ekranı', () {
    testWidgets('geri tuşu da girişe (kök ekrana) döner', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ResetSuccessPage())),
            child: const Text('git'),
          ),
        ),
      )));
      await tester.tap(find.text('git'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Şifreniz güncellendi'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('git'), findsOneWidget);
      expect(find.byType(ResetSuccessPage), findsNothing);
    });
  });

  group('hareket anahtarı', () {
    testWidgets('testte döngü kapalı: pumpAndSettle kilitlenmez', (tester) async {
      await tester.pumpWidget(_app(WelcomePage(onLogin: () {}, onRegister: () {})));
      await tester.pumpAndSettle();
      expect(AuthMotion.forceLoop, isNull);
    });
  });
}
