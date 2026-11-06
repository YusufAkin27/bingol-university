@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Giris sayfasi (lg4) ekran goruntuleri. Uretim: LG_OUT='C:/bu_qa/shots/login/lg4' flutter test test/redesign/login_lg4_shots_test.dart
/// Istege bagli: LG_LANG=tr,ar  LG_SCALE=1.3  LG_W=320
void main() {
  final out = Platform.environment['LG_OUT'];
  final lang = Platform.environment['LG_LANG'] ?? 'tr';
  final scale = double.tryParse(Platform.environment['LG_SCALE'] ?? '') ?? 1.0;
  final w = double.tryParse(Platform.environment['LG_W'] ?? '') ?? 390.0;
  const h = 844.0;
  const dpr = 2.0;
  setUpAll(loadTestFonts);

  final cases = <String, Future<void> Function(WidgetTester t, FakeBackend b)>{
    '1_bos': (t, b) async {},
    '2_dolu_odakta': (t, b) async {
      await t.enterText(find.byType(TextFormField).at(0), 'ali@gmail.com');
      await t.pump();
      await t.tap(find.byType(TextFormField).at(1));
      await t.pump();
      await t.enterText(find.byType(TextFormField).at(1), 'Kampus2026!!');
      await t.pump(const Duration(milliseconds: 300));
    },
    '3_klavye': (t, b) async {
      t.view.viewInsets = const FakeViewPadding(bottom: 320 * dpr);
      await t.tap(find.byType(TextFormField).at(0));
      await t.enterText(find.byType(TextFormField).at(0), 'ali@gmail.com');
      await t.pump(const Duration(milliseconds: 500));
    },
    '4_dogrulama_hatasi': (t, b) async {
      await t.enterText(find.byType(TextFormField).at(0), '12345');
      await t.pump();
      await t.tap(find.text(lookupAppLocalizations(Locale(lang)).loginSubmit).last);
      await t.pump(const Duration(milliseconds: 500));
    },
    '5_sunucu_hatasi': (t, b) async {
      await t.enterText(find.byType(TextFormField).at(0), 'ali@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'Kampus2026!!');
      await t.pump();
      await t.tap(find.text(lookupAppLocalizations(Locale(lang)).loginSubmit).last);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
    },
  };

  for (final dark in [false, true]) {
    for (final e in cases.entries) {
      testWidgets('lg4 ${e.key} ${dark ? 'koyu' : 'acik'}', skip: out == null, (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(w * dpr, h * dpr);
        addTearDown(tester.view.reset);
        final b = FakeBackend();
        if (e.key == '5_sunucu_hatasi') {
          b.fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.');
        }
        final s = makeSession(b, signedIn: false);
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
            home: LoginPage(session: s),
          ),
        ));
        await settle(tester, const Duration(milliseconds: 1200));
        await e.value(tester, b);
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
