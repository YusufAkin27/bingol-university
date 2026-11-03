import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Giris sayfasi: 320 dp genislik + 1.3x yazi + tr/ar + acik/koyu + klavye acikken tasma/istisna yok.
void main() {
  setUpAll(() => loadTestFonts());
  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final keyboard in [false, true]) {
        testWidgets('login tasma yok $lang dark=$dark klavye=$keyboard', (tester) async {
          tester.view.devicePixelRatio = 2;
          tester.view.physicalSize = const Size(320 * 2, 640 * 2);
          if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 260 * 2);
          addTearDown(tester.view.reset);
          addTearDown(tester.view.resetViewInsets);
          final b = FakeBackend();
          final s = makeSession(b, signedIn: false);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          await tester.pumpWidget(MaterialApp(
            theme: BuTheme.forLocale(Brightness.light, lang),
            darkTheme: BuTheme.forLocale(Brightness.dark, lang),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: LoginPage(session: s),
          ));
          await settle(tester, const Duration(milliseconds: 1200));
          await tester.enterText(find.byType(TextFormField).at(0), '226051015');
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }
}
