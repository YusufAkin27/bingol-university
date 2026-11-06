@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/help/about_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/system/splash_screen.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Marka logosu ekran goruntuleri (acilis / karsilama / giris / hakkinda, acik + koyu).
/// Uretim: BRAND_OUT='C:/bu_qa/shots/brand' flutter test test/redesign/brand_logo_shots_test.dart  (BRAND_LANG=tr|ar, BRAND_W=390)
void main() {
  final out = Platform.environment['BRAND_OUT'];
  final lang = Platform.environment['BRAND_LANG'] ?? 'tr';
  final w = double.tryParse(Platform.environment['BRAND_W'] ?? '') ?? 390.0;
  const h = 844.0;
  const dpr = 2.0;
  setUpAll(loadTestFonts);

  final screens = <String, Widget Function()>{
    'splash': () => const SplashScreen(),
    'welcome': () => WelcomePage(onLogin: () {}, onRegister: () {}),
    'login': () => LoginPage(session: makeSession(FakeBackend(), signedIn: false)),
    'about': () => AboutPage(session: makeSession(FakeBackend(), signedIn: false)),
  };

  for (final dark in [false, true]) {
    screens.forEach((name, build) {
      testWidgets('marka $name ${dark ? 'koyu' : 'acik'}', skip: out == null, (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(w * dpr, h * dpr);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
            home: build(),
          ),
        ));
        await settle(tester, const Duration(milliseconds: 1200));
        // Gorsel cozumu gercek asenkron is: logo PNG'sini bekle.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/${name}_${dark ? 'koyu' : 'acik'}_${lang}_${w.toInt()}.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    });
  }
}
