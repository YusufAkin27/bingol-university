import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/l10n/app_localizations_tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// W1-J / A9-01 ve A9-03: kritik kullanıcı metinleri.
void main() {
  setUpAll(loadTestFonts);

  test('A9-01: "tüm cihazlardan çıkış" metni hesabın kapatılacağını söylemez', () {
    final tr = AppLocalizationsTr().settingsLogoutAllBody;
    expect(tr, 'Tüm cihazlardaki oturumlarınız kapatılacak ve yeniden giriş yapmanız gerekecek.');
    expect(tr.toLowerCase(), isNot(contains('hesabınız')));
  });

  testWidgets('A9-03: karşılama ekranı (Stitch v3 01: marka etiketi yok; iki satırlı başlık) ve yanlış "BU Kampüs" yazımı asla', (tester) async {
    useScreen(tester, const Size(390, 1000));
    final lc = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    LocaleController.current = lc;
    addTearDown(() => LocaleController.current = null);
    mockSecureStorage();
    await tester.pumpWidget(buildApp(WelcomePage(onLogin: () {}, onRegister: () {})));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text(AppLocalizationsTr().welcomeHeadline), findsOneWidget);
    expect(find.text('BU Kampüs'), findsNothing);
    expect(find.text('BU KAMPÜS'), findsNothing);
  });

  testWidgets('A9-03: ana sayfa üst çubuğu: yazı marka adı "BÜ Kampüs" + "Merhaba, Ad" (logo karosu yok), yanlış yazımlar asla', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(const Scaffold(
      body: HomeBrandHeader(actions: [SizedBox()], hello: 'Merhaba, Ayşe', greeting: 'İyi günler'),
    )));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('Merhaba, Ayşe'), findsOneWidget);
    expect(find.text('BÜ Kampüs'), findsOneWidget); // yalnız yazı (wordmark)
    expect(find.text('BU KAMPÜS'), findsNothing);
    expect(find.text('BU Kampüs'), findsNothing);
  });
}
