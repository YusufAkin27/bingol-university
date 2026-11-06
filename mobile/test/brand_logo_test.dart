import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/auth/help/about_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/system/splash_screen.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Marka logosu (dark_logo / light_logo): tema duyarlı [BuLogo]; koyu temada beyaz glif (logo_dark.png),
/// açık temada siyah glif (logo_light.png). Marka ekranlarında (açılış, karşılama, giriş, hakkında) kullanılır.
Widget _app(Widget home, Brightness br, String lang) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(br, lang),
      themeMode: br == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Ağaçtaki marka logosu görsellerinin varlık adları.
List<String> _logoAssets(WidgetTester t) => [
      for (final w in t.widgetList<Image>(find.byType(Image)))
        if (w.image is AssetImage && (w.image as AssetImage).assetName.contains('branding/logo_')) (w.image as AssetImage).assetName,
    ];

void main() {
  setUpAll(loadTestFonts);

  test('assetFor: koyu -> logo_dark (beyaz glif), açık -> logo_light (siyah glif)', () {
    expect(BuLogo.assetFor(Brightness.dark), 'assets/branding/logo_dark.png');
    expect(BuLogo.assetFor(Brightness.light), 'assets/branding/logo_light.png');
  });

  test('iki logo varlığı pakette ve çözülebilir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final a in [BuLogo.darkAsset, BuLogo.lightAsset]) {
      final data = await rootBundle.load(a);
      expect(data.lengthInBytes, greaterThan(1000), reason: a);
    }
  });

  group('BuLogo doğru varyantı seçer (320/390 dp, tr/en/ar)', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final w in [320.0, 390.0]) {
        for (final br in Brightness.values) {
          testWidgets('$lang ${w.toInt()} ${br.name}', (tester) async {
            tester.view.devicePixelRatio = 2;
            tester.view.physicalSize = Size(w * 2, 640 * 2);
            addTearDown(tester.view.reset);
            await tester.pumpWidget(_app(const Scaffold(body: Center(child: BuLogo(width: 120))), br, lang));
            await tester.pump();
            expect(_logoAssets(tester), [br == Brightness.dark ? BuLogo.darkAsset : BuLogo.lightAsset]);
            expect(tester.takeException(), isNull);
            final size = tester.getSize(find.byType(Image));
            expect(size.width, 120);
            expect(size.height, greaterThan(0));
          });
        }
      }
    }
  });

  group('marka ekranları logoyu temaya göre gösterir', () {
    final screens = <String, Widget Function()>{
      'splash': () => const SplashScreen(),
      'welcome': () => WelcomePage(onLogin: () {}, onRegister: () {}),
      'login': () => LoginPage(session: makeSession(FakeBackend(), signedIn: false)),
      'about': () => AboutPage(session: makeSession(FakeBackend(), signedIn: false)),
    };
    for (final lang in ['tr', 'ar']) {
      for (final br in Brightness.values) {
        for (final w in [320.0, 390.0]) {
          screens.forEach((name, build) {
            testWidgets('$name $lang ${br.name} ${w.toInt()}', (tester) async {
              tester.view.devicePixelRatio = 2;
              tester.view.physicalSize = Size(w * 2, 844 * 2);
              addTearDown(tester.view.reset);
              LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
              addTearDown(() => LocaleController.current = null);
              await tester.pumpWidget(_app(build(), br, lang));
              await settle(tester, const Duration(milliseconds: 1200));
              final want = br == Brightness.dark ? BuLogo.darkAsset : BuLogo.lightAsset;
              expect(_logoAssets(tester), isNotEmpty, reason: name);
              expect(_logoAssets(tester).toSet(), {want}, reason: '$name yanlış logo varyantı');
              expect(tester.takeException(), isNull);
              await unmount(tester);
            });
          });
        }
      }
    }
  });
}
