@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// lg2 giris sayfasi ekran goruntuleri (390x844). LG_OUT tanimli degilse atlanir.
/// Uretim: LG_OUT='C:/bu_qa/shots/login/lg2' flutter test test/redesign/lg2_login_shots_test.dart
const _w = 390.0;
const _h = 844.0;
const _dpr = 2.0;

Widget _app(Widget home, String lang, bool dark, GlobalKey key, double scale) => RepaintBoundary(
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

Future<void> _type(WidgetTester t, int field, String text) async {
  await t.enterText(find.byType(TextFormField).at(field), text);
  await t.pump();
}

void main() {
  final out = Platform.environment['LG_OUT'];
  final skip = out == null ? 'LG_OUT tanimli degil' : null;

  setUpAll(() => loadTestFonts());

  final cases = <String, Future<void> Function(WidgetTester, Session, FakeBackend)?>{
    'bos': null,
    'dolu': (t, s, b) async {
      await _type(t, 0, '226051015');
      await _type(t, 1, 'Kampus2026!!');
    },
    'odak': (t, s, b) async {
      await t.tap(find.byType(TextFormField).at(0));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byType(TextFormField).at(0), '226051015');
      await t.pump(const Duration(milliseconds: 300));
    },
    'alan_hata': (t, s, b) async {
      await _type(t, 0, '1234');
      await t.tap(find.text(lookupAppLocalizations(const Locale('tr')).loginSubmit).last);
      await t.pump(const Duration(milliseconds: 500));
    },
    'hata_bandi': (t, s, b) async {
      await _type(t, 0, '226051015');
      await _type(t, 1, 'Kampus2026!!');
      await t.tap(find.text(lookupAppLocalizations(const Locale('tr')).loginSubmit).last);
      await t.pump(const Duration(milliseconds: 800));
      await t.pump(const Duration(milliseconds: 800));
    },
    'klavye': (t, s, b) async {
      t.view.viewInsets = const FakeViewPadding(bottom: 336 * _dpr);
      await t.tap(find.byType(TextFormField).at(0));
      await t.pump(const Duration(milliseconds: 500));
      await t.enterText(find.byType(TextFormField).at(0), '226051015');
      await t.pump(const Duration(milliseconds: 500));
    },
  };

  for (final dark in [false, true]) {
    for (final e in cases.entries) {
      if (dark && !['bos', 'dolu', 'klavye', 'hata_bandi'].contains(e.key)) continue;
      final name = '${e.key}${dark ? '_koyu' : ''}_tr';
      testWidgets('lg2 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(_w * _dpr, _h * _dpr);
        addTearDown(tester.view.reset);
        addTearDown(tester.view.resetViewInsets);
        final b = FakeBackend();
        if (e.key == 'hata_bandi') b.network('/auth/login');
        final s = makeSession(b, signedIn: false);
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(LoginPage(session: s), 'tr', dark, key, 1.0));
        await settle(tester, const Duration(milliseconds: 1200));
        await e.value?.call(tester, s, b);
        await settle(tester, const Duration(milliseconds: 700));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}
