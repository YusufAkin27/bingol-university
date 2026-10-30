import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Yerelleştirme temsilcileriyle sarılmış uygulama (fake_app.buildApp temsilcisizdir).
Widget _app(Widget home, Locale locale) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  group('resolveAppLocale', () {
    test('kullanıcı seçimi cihaz dilini ezer', () {
      expect(resolveAppLocale('ar', const [Locale('tr')]), const Locale('ar'));
      expect(resolveAppLocale('en', const [Locale('tr')]), const Locale('en'));
    });
    test('sistem: cihaz dili destekleniyorsa o', () {
      expect(resolveAppLocale('system', const [Locale('tr', 'TR')]), const Locale('tr'));
      expect(resolveAppLocale('system', const [Locale('ar', 'SA')]), const Locale('ar'));
    });
    test('sistem: ilk desteklenen cihaz dili seçilir', () {
      expect(resolveAppLocale('system', const [Locale('de'), Locale('tr')]), const Locale('tr'));
    });
    test('desteklenmeyen cihaz dili ya da boş liste: İngilizce', () {
      expect(resolveAppLocale('system', const [Locale('fr'), Locale('de')]), const Locale('en'));
      expect(resolveAppLocale('system', const []), const Locale('en'));
      expect(resolveAppLocale('bozuk', const [Locale('ja')]), const Locale('en'));
    });
    test('LocaleController: çözülen kod ApiClient dil callback ına gider', () async {
      mockSecureStorage();
      final seen = <String>[];
      final c = LocaleController(onResolved: seen.add, deviceLocales: () => const [Locale('fr')]);
      expect(c.locale, const Locale('en'));
      await c.set('ar');
      expect(c.locale, const Locale('ar'));
      expect(seen.last, 'ar');
      await c.set('system');
      expect(seen.last, 'en');
    });
  });

  const expected = {
    'tr': ['Ana Sayfa', 'Hoş geldiniz', 'Giriş yap'],
    'en': ['Home', 'Welcome', 'Log in'],
    'ar': ['الرئيسية', 'مرحبًا بك', 'تسجيل الدخول'],
  };

  for (final code in ['tr', 'en', 'ar']) {
    testWidgets('giriş sayfası $code: metinler, yön, 320 dp taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      await tester.pumpWidget(_app(LoginPage(session: makeSession(b, signedIn: false)), Locale(code)));
      await tester.pump();
      expect(find.text(expected[code]![1]), findsWidgets);
      expect(find.text(expected[code]![2]), findsWidgets);
      final dir = Directionality.of(tester.element(find.byType(LoginPage)));
      expect(dir, code == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });

    testWidgets('alt gezinme $code: erişilebilirlik etiketleri', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneSmall);
      final badge = ValueNotifier<int>(0);
      addTearDown(badge.dispose);
      await tester.pumpWidget(_app(
        Scaffold(bottomNavigationBar: FloatingNav(index: 0, onChanged: (_) {}, chatBadge: badge)),
        Locale(code),
      ));
      // M3 NavigationBar etikete konum metni ekler ("Ana Sayfa Tab 1 of 5"): etiketle başlayan düğüm aranır.
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(expected[code]![0])}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      h.dispose();
    });

    testWidgets('ayarlar $code: başlık ve dil seçimi, 320 dp taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      mockSecureStorage();
      final b = FakeBackend();
      final lc = LocaleController(deviceLocales: () => [Locale(code)]);
      await tester.pumpWidget(_app(
        SettingsPage(session: makeSession(b), themeController: ThemeController(), localeController: lc),
        Locale(code),
      ));
      await settle(tester);
      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.settingsTitle), findsOneWidget);
      expect(find.text(l.settingsLanguage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Arapça: ayarlar satırı sağdan sola yerleşir', (tester) async {
    useScreen(tester, kPhoneMedium);
    mockSecureStorage();
    final lc = LocaleController(deviceLocales: () => const [Locale('ar')]);
    await tester.pumpWidget(_app(
      SettingsPage(session: makeSession(FakeBackend()), themeController: ThemeController(), localeController: lc),
      const Locale('ar'),
    ));
    await settle(tester);
    final title = tester.getTopRight(find.text('الإعدادات'));
    // Başlık RTL'de sağ yarıda başlar (geri düğmesi sağda).
    expect(title.dx, greaterThan(kPhoneMedium.width / 2));
  });
}
