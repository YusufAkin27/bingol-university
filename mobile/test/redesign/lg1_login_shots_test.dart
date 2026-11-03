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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// lg1 giris sayfasi ekran goruntuleri (390x844, dpr 2). Uretim:
///   LG_OUT='C:/bu_qa/shots/login/lg1' flutter test test/redesign/lg1_login_shots_test.dart
/// Istege bagli: LG_LANG=tr,ar  LG_W=390  LG_H=844  LG_SCALE=1.0
const _dpr = 2.0;

class _Shot {
  const _Shot(this.name, this.after, {this.setup, this.keyboard = 0});
  final String name;
  final Future<void> Function(WidgetTester t, Session s) after;
  final void Function(FakeBackend b, Session s)? setup;
  final double keyboard;
}

String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

Future<void> _type(WidgetTester t, int field, String text) async {
  await t.enterText(find.byType(TextFormField).at(field), text);
  await t.pump();
}

Future<void> _noop(WidgetTester t, Session s) async {}

final _shots = <_Shot>[
  const _Shot('01_bos', _noop),
  _Shot('02_dolu_odakta', (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.byType(TextFormField).at(0));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('03_klavye_acik', (t, s) async {
    await _type(t, 0, '226051015');
    await t.tap(find.byType(TextFormField).at(1));
    await t.pump(const Duration(milliseconds: 300));
  }, keyboard: 336),
  _Shot('04_dogrulama_hatasi', (t, s) async {
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('05_istek_siniri', (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 600));
  }, setup: (b, s) => b.on('/auth/login', {'code': 'TOO_MANY_REQUESTS', 'message': 'Çok fazla deneme. Lütfen biraz bekleyin.'}, status: 429, headers: {'retry-after': '40'})),
  _Shot('06_bekleyen_ve_oturum', (t, s) async {
    await _type(t, 0, '226051015');
  }, setup: (b, s) {
    s.pending.save('226051015');
    s.replacedNotice.value = true;
  }),
  _Shot('07_sifre_gorunur_hata', (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'yanlis123');
    await t.tap(find.byTooltip(_l.authShowPassword));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 600));
  }, setup: (b, s) => b.fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'Okul numarası veya şifre hatalı.')),
];

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

void main() {
  final out = Platform.environment['LG_OUT'];
  final langs = (Platform.environment['LG_LANG'] ?? 'tr').split(',');
  final w = double.tryParse(Platform.environment['LG_W'] ?? '') ?? 390;
  final h = double.tryParse(Platform.environment['LG_H'] ?? '') ?? 844;
  final scale = double.tryParse(Platform.environment['LG_SCALE'] ?? '') ?? 1.0;

  setUpAll(() async {
    if (!langs.contains('ar')) {
      await loadTestFonts();
    } else {
      // Arapca glifler icin sistem Arial (yazi tipi yoksa kare cizilir).
      final f = FontLoader('Inter');
      for (final n in ['arial.ttf', 'arialbd.ttf']) {
        final file = File('C:/Windows/Fonts/$n');
        if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
      await f.load();
      await loadIconFonts();
    }
  });
  for (final lang in langs) {
    for (final dark in [false, true]) {
      for (final shot in _shots) {
        final name = '${shot.name}${dark ? '_koyu' : ''}_$lang${w != 390 ? '_w${w.toInt()}' : ''}${scale != 1.0 ? '_x$scale' : ''}';
        testWidgets('lg1 $name', skip: out == null, (tester) async {
          _lang = lang;
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(w * _dpr, h * _dpr);
          if (shot.keyboard > 0) tester.view.viewInsets = FakeViewPadding(bottom: shot.keyboard * _dpr);
          addTearDown(tester.view.reset);
          final b = FakeBackend();
          final s = makeSession(b, signedIn: false);
          shot.setup?.call(b, s);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(LoginPage(session: s), lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1200));
          await shot.after(tester, s);
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
}
