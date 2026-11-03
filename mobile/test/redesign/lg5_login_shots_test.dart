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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// lg5 giris sayfasi ekran goruntuleri (bos, dolu+hata, klavye acik). Ortam degiskeni yoksa ATLANIR:
///   LG5_OUT='C:/bu_qa/shots/login/lg5' flutter test test/redesign/lg5_login_shots_test.dart
/// Istege bagli: `LG5_LANG=tr,ar`, `LG5_SCALE=1.3`, `LG5_W=320`, `LG5_H=640`.
const _dpr = 2.0;

Widget _app(Widget home, String lang, bool dark, GlobalKey key, double scale) {
  return RepaintBoundary(
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
      home: home,
    ),
  );
}

void main() {
  final out = Platform.environment['LG5_OUT'];
  final skip = out == null ? 'LG5_OUT tanimli degil' : null;
  final langs = (Platform.environment['LG5_LANG'] ?? 'tr').split(',');
  final scale = double.tryParse(Platform.environment['LG5_SCALE'] ?? '') ?? 1.0;
  final w = double.tryParse(Platform.environment['LG5_W'] ?? '') ?? 390;
  final h = double.tryParse(Platform.environment['LG5_H'] ?? '') ?? 844;

  setUpAll(() async {
    if (!langs.contains('ar')) return loadTestFonts();
    final f = FontLoader('Inter');
    for (final n in ['arial.ttf', 'arialbd.ttf']) {
      final file = File('C:/Windows/Fonts/$n');
      if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await f.load();
    await loadIconFonts();
  });

  for (final lang in langs) {
    for (final dark in [false, true]) {
      for (final scene in ['bos', 'dolu_hata', 'klavye', 'klavye_odak_hata']) {
        final name = 'giris_${scene}_${dark ? 'koyu_' : ''}$lang${scale != 1.0 ? '_x$scale' : ''}${w != 390 ? '_${w.toInt()}' : ''}';
        testWidgets('lg5 $name', skip: skip != null, (tester) async {
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(w * _dpr, h * _dpr);
          addTearDown(tester.view.reset);
          addTearDown(tester.view.resetViewInsets);
          mockSecureStorage();
          final b = FakeBackend();
          if (scene == 'dolu_hata') b.fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'Okul numarası veya şifre hatalı.');
          final s = makeSession(b, signedIn: false);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(LoginPage(session: s), lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1200));
          if (scene == 'dolu_hata') {
            await tester.enterText(find.byType(TextFormField).at(0), '226051015');
            await tester.enterText(find.byType(TextFormField).at(1), 'YanlisSifre1');
            await tester.pump();
            await tester.tap(find.text(lookupAppLocalizations(Locale(lang)).loginSubmit).last);
            await settle(tester, const Duration(milliseconds: 900));
          } else if (scene.startsWith('klavye')) {
            await tester.tap(find.byType(TextFormField).at(0));
            await tester.enterText(find.byType(TextFormField).at(0), '2260510');
            tester.view.viewInsets = const FakeViewPadding(bottom: 300 * _dpr);
            await settle(tester, const Duration(milliseconds: 900));
            if (scene == 'klavye_odak_hata') {
              await tester.tap(find.byType(TextFormField).at(1));
              await tester.pump();
              await tester.tap(find.byType(TextFormField).at(0));
              await tester.pump();
              await tester.enterText(find.byType(TextFormField).at(0), '');
              await tester.tap(find.byType(TextFormField).at(1));
              await settle(tester, const Duration(milliseconds: 900));
            }
          }
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: _dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
            // ignore: avoid_print
            print('YAZILDI ${f.path}');
          });
          await unmount(tester);
        });
      }
    }
  }
}
