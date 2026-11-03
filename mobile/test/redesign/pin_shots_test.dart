@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// 6 haneli PIN alanı ekran görüntüleri (giriş, kayıt 3. adım, yeni şifre).
/// Üretim: PIN_OUT='C:/bu_qa/shots/pin' flutter test test/redesign/pin_shots_test.dart
/// İsteğe bağlı: PIN_LANG=tr,ar  PIN_SCALE=1.3  PIN_W=320
void main() {
  final out = Platform.environment['PIN_OUT'];
  final lang = Platform.environment['PIN_LANG'] ?? 'tr';
  final scale = double.tryParse(Platform.environment['PIN_SCALE'] ?? '') ?? 1.0;
  final w = double.tryParse(Platform.environment['PIN_W'] ?? '') ?? 390.0;
  const h = 844.0;
  const dpr = 2.0;
  setUpAll(loadTestFonts);

  final cases = <String, (Widget Function(FakeBackend b) page, Future<void> Function(WidgetTester t) act)>{
    'giris_bos': (
      (b) => LoginPage(session: makeSession(b, signedIn: false)),
      (t) async {},
    ),
    'giris_3_hane_odakta': (
      (b) => LoginPage(session: makeSession(b, signedIn: false)),
      (t) async {
        await t.enterText(find.byType(TextFormField).at(0), '226051015');
        await t.tap(find.byType(TextFormField).at(1));
        await t.enterText(find.byType(TextFormField).at(1), '481');
        await t.pump(const Duration(milliseconds: 400));
      },
    ),
    'giris_dolu_acik_rakamlar': (
      (b) => LoginPage(session: makeSession(b, signedIn: false)),
      (t) async {
        await t.enterText(find.byType(TextFormField).at(0), '226051015');
        await t.enterText(find.byType(TextFormField).at(1), '481952');
        await t.tap(find.byType(IconButton).first);
        await t.pump(const Duration(milliseconds: 400));
      },
    ),
    'giris_sunucu_hatasi_ipucu': (
      (b) {
        b.fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.');
        return LoginPage(session: makeSession(b, signedIn: false));
      },
      (t) async {
        await t.enterText(find.byType(TextFormField).at(0), '226051015');
        await t.enterText(find.byType(TextFormField).at(1), '481952');
        await t.pump(const Duration(milliseconds: 700));
        await t.tap(find.text(lookupAppLocalizations(Locale(lang)).loginSubmit).last);
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
      },
    ),
    'giris_hesap_kilidi': (
      (b) {
        b.on('/auth/login', {'code': 'ACCOUNT_TEMP_LOCKED', 'message': ''}, status: 429, headers: {'retry-after': '900'});
        return LoginPage(session: makeSession(b, signedIn: false));
      },
      (t) async {
        await t.enterText(find.byType(TextFormField).at(0), '226051015');
        await t.enterText(find.byType(TextFormField).at(1), '481952');
        await t.pump(const Duration(milliseconds: 700));
        await t.tap(find.text(lookupAppLocalizations(Locale(lang)).loginSubmit).last);
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
      },
    ),
    'kayit_3_adim_bos': (
      (b) {
        fakeCatalog(b);
        return RegisterPage(session: makeSession(b, signedIn: false));
      },
      (t) async {
        await fillRegister(t, password: '');
        await t.pump(const Duration(milliseconds: 400));
      },
    ),
    'kayit_3_adim_zayif': (
      (b) {
        fakeCatalog(b);
        return RegisterPage(session: makeSession(b, signedIn: false));
      },
      (t) async {
        await fillRegister(t, password: '123456');
        await t.tap(find.text(lookupAppLocalizations(Locale(lang)).loginRegister).last);
        await t.pump(const Duration(milliseconds: 600));
      },
    ),
    'kayit_3_adim_gecerli': (
      (b) {
        fakeCatalog(b);
        return RegisterPage(session: makeSession(b, signedIn: false));
      },
      (t) async {
        await fillRegister(t, password: '481952');
        await t.pump(const Duration(milliseconds: 500));
      },
    ),
    'yeni_sifre': (
      (b) => NewPasswordPage(session: makeSession(b, signedIn: false), email: 'ayse@bingol.edu.tr', resetToken: 't'),
      (t) async {
        await t.enterText(find.byType(TextFormField).at(0), '739204');
        await t.enterText(find.byType(TextFormField).at(1), '7392');
        await t.pump(const Duration(milliseconds: 500));
      },
    ),
  };

  for (final dark in [false, true]) {
    for (final e in cases.entries) {
      testWidgets('pin ${e.key} ${dark ? 'koyu' : 'acik'}', skip: out == null, (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(w * dpr, (e.key.startsWith('kayit') ? 1500 : h) * dpr);
        addTearDown(tester.view.reset);
        final b = FakeBackend();
        final page = e.value.$1(b);
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: page,
          ),
        ));
        await settle(tester, const Duration(milliseconds: 1200));
        await e.value.$2(tester);
        await settle(tester, const Duration(milliseconds: 700));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final tag = '${lang}_${w.toInt()}${scale != 1.0 ? '_x$scale' : ''}';
          File('${dir.path}/${e.key}${dark ? '_koyu' : ''}_$tag.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}
