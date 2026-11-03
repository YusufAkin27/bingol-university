@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Tek sayfa kayıt + zorunlu "bölümünü seç" ekran görüntüleri.
/// Üretim: REG_OUT='C:/bu_qa/shots/reg' flutter test test/redesign/reg_shots_test.dart
/// İsteğe bağlı: REG_LANG=tr,ar
void main() {
  final out = Platform.environment['REG_OUT'];
  final langs = (Platform.environment['REG_LANG'] ?? 'tr').split(',');
  const w = 390.0, h = 844.0, dpr = 2.0;
  setUpAll(loadTestFonts);

  final cases = <String, (Widget Function(FakeBackend b) page, Future<void> Function(WidgetTester t) act)>{
    'kayit_bos': ((b) => RegisterPage(session: makeSession(b, signedIn: false)), (t) async {}),
    'kayit_dolu': (
      (b) => RegisterPage(session: makeSession(b, signedIn: false)),
      (t) async {
        await fillRegister(t);
        await t.pump(const Duration(milliseconds: 300));
      }
    ),
    'kayit_hata': (
      (b) => RegisterPage(session: makeSession(b, signedIn: false)),
      (t) async {
        await fillRegister(t, name: '', password: '123');
        await t.tap(find.text('Kayıt ol').last);
        await t.pump(const Duration(milliseconds: 500));
      }
    ),
    'bolum_bos': ((b) => ProfileSetupPage(session: makeSession(b), onDone: () {}), (t) async {}),
    'bolum_hata': (
      (b) => ProfileSetupPage(session: makeSession(b), onDone: () {}),
      (t) async {
        await t.tap(find.byKey(const ValueKey('profile-setup-submit')));
        await t.pump(const Duration(milliseconds: 500));
      }
    ),
    'bolum_dolu': (
      (b) => ProfileSetupPage(session: makeSession(b), onDone: () {}),
      (t) async {
        await fillAcademic(t);
        await t.pump(const Duration(milliseconds: 300));
      }
    ),
  };

  for (final lang in langs) {
    for (final dark in [false, true]) {
      for (final e in cases.entries) {
        testWidgets('reg ${e.key} ${dark ? 'koyu' : 'acik'} $lang', skip: out == null, (tester) async {
          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize = const Size(w * dpr, h * dpr);
          addTearDown(tester.view.reset);
          final b = FakeBackend();
          fakeCatalog(b);
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
              home: e.value.$1(b),
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
            File('${dir.path}/${e.key}${dark ? '_koyu' : ''}_$lang.png').writeAsBytesSync(data.buffer.asUint8List());
          });
          await unmount(tester);
        });
      }
    }
  }
}
