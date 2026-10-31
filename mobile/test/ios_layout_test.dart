import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// IOS2: iOS davranışı (Cupertino geçişi, çentik/Dynamic Island + home indicator güvenli alanı, sıçrayan kaydırma)
/// Windows'ta gerçek iPhone olmadan, platform geçersiz kılma + sahte görünüm dolgusuyla denetlenir. Gerçek cihaz
/// doğrulaması yerine GEÇMEZ (docs/DEVICE_TEST_PLAN.md 3b).
const _iphone15Pro = Size(393, 852);
const _iphoneSe = Size(375, 667);

void _insets(WidgetTester tester, {double top = 59, double bottom = 34}) {
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

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

/// iOS platformu yalnız test gövdesi boyunca açık kalır (flutter_test, değişkenin gövde sonunda sıfırlanmasını ister).
void iosTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  setUpAll(loadTestFonts);

  final screens = <String, Widget Function(FakeBackend b)>{
    'welcome': (b) => WelcomePage(onLogin: () {}, onRegister: () {}),
    'login': (b) => LoginPage(session: _s(b)),
    'register': (b) => RegisterPage(session: _s(b)),
  };

  group('iOS: çentik + home indicator ile taşma/istisna yok', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final size in const [_iphone15Pro, _iphoneSe]) {
        for (final scale in const [1.0, 1.3]) {
          screens.forEach((name, build) {
            iosTest('$name | $lang ${size.width.toInt()}x${size.height.toInt()} x$scale', (tester) async {
              useScreen(tester, size);
              _insets(tester, top: size == _iphoneSe ? 20 : 59, bottom: size == _iphoneSe ? 0 : 34);
              final b = FakeBackend();
              fakeCatalog(b);
              LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
              addTearDown(() => LocaleController.current = null);
              await tester.pumpWidget(_app(build(b), locale: Locale(lang), scale: scale));
              await settle(tester, const Duration(milliseconds: 1500));
              expect(tester.takeException(), isNull);
            });
          });
        }
      }
    }
  });

  iosTest('iOS: sayfa geçişi Cupertino (kenardan geri kaydırma) ve kaydırma fiziği sıçrayan', (tester) async {
    useScreen(tester, _iphone15Pro);
    _insets(tester);
    final b = FakeBackend();
    fakeCatalog(b);
    await tester.pumpWidget(_app(Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('ikinci')))),
            child: const Text('git'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('git'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // BuPageTransitionsBuilder(CupertinoPageTransitionsBuilder) iOS'ta CupertinoPageTransition üretir
    expect(find.byType(CupertinoPageTransition), findsWidgets);
    await tester.pumpAndSettle();
    // kenardan sürükleme geri götürür
    await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('ikinci'), findsNothing);
    expect(find.text('git'), findsOneWidget);
    // sıçrayan (bouncing) kaydırma fiziği (iOS'ta hem Material varsayılanı hem BuScrollBehavior bunu verir)
    final ctx = tester.element(find.byType(Scaffold));
    expect(ScrollConfiguration.of(ctx).getScrollPhysics(ctx), isA<BouncingScrollPhysics>());
  });

  iosTest('iOS: alt gezinme çubuğu home indicator (34 dp) üstünde kalır', (tester) async {
    useScreen(tester, _iphone15Pro);
    _insets(tester);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(buildApp(
      Scaffold(bottomNavigationBar: FloatingNav(index: 0, onChanged: (_) {}, chatBadge: badge)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final pill = tester.getRect(find.byKey(const ValueKey('nav-pill')));
    expect(pill.bottom, lessThanOrEqualTo(_iphone15Pro.height - 34 + 0.5),
        reason: 'nav hapı home indicator alanına taşmamalı');
  });
}
