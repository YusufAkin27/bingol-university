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

/// lg3 giris sayfasi (alt sayfa / sheet) ekran goruntuleri. Yalniz LG3_OUT tanimliysa calisir:
///   LG3_OUT='C:/bu_qa/shots/login/lg3' flutter test test/redesign/lg3_login_shots_test.dart
/// Istege bagli: `LG3_LANG=tr,ar`, `LG3_SCALE=1.3`, `LG3_W=390`, `LG3_H=844`, `LG3_ONLY=01,04`.
const _dpr = 2.0;

String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

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

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

Future<void> _type(WidgetTester t, int field, String text) async {
  await t.enterText(find.byType(TextFormField).at(field), text);
  await t.pump();
}

class _Shot {
  const _Shot(this.file, {this.setup, this.after, this.keyboard = false, this.back = false, this.delay});
  final String file;
  final void Function(FakeBackend b, Session s)? setup;
  final Future<void> Function(WidgetTester t, Session s)? after;
  final bool keyboard;
  final bool back;
  final Duration? delay;
}

Future<void> _fillAndSubmit(WidgetTester t, Session s) async {
  await _type(t, 0, '226051015');
  await _type(t, 1, 'Kampus2026!!');
  await t.tap(find.text(_l.loginSubmit).last);
  await t.pump(const Duration(milliseconds: 800));
  await t.pump(const Duration(milliseconds: 800));
}

final _shots = <_Shot>[
  const _Shot('01_bos'),
  const _Shot('02_geri_ok', back: true),
  _Shot('03_dolu', after: (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
  }),
  const _Shot('04_klavye', keyboard: true),
  _Shot('05_hata_alanlar', after: (t, s) async {
    await _type(t, 0, '226051015');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('06_istek_siniri',
      setup: (b, s) => b.on('/auth/login', {'code': 'TOO_MANY_REQUESTS', 'message': 'Çok fazla deneme. Lütfen biraz bekleyin.'},
          status: 429, headers: {'retry-after': '40'}),
      after: _fillAndSubmit),
  _Shot('07_yukleniyor', delay: const Duration(seconds: 30), after: (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('08_bantlar', setup: (b, s) {
    s.replacedNotice.value = true;
    s.pending.save('226051015@bingol.edu.tr');
  }),
  _Shot('09_oturum_hata', setup: (b, s) => b.network('/auth/login'), after: _fillAndSubmit),
  _Shot('10_klavye_hata', keyboard: true, setup: (b, s) => b.network('/auth/login'), after: _fillAndSubmit),
];

void main() {
  final out = Platform.environment['LG3_OUT'];
  final skip = out == null ? 'LG3_OUT tanimli degil' : null;
  final langs = (Platform.environment['LG3_LANG'] ?? 'tr').split(',');
  final scale = double.tryParse(Platform.environment['LG3_SCALE'] ?? '') ?? 1.0;
  final w = double.tryParse(Platform.environment['LG3_W'] ?? '') ?? 390.0;
  final h = double.tryParse(Platform.environment['LG3_H'] ?? '') ?? 844.0;
  final only = (Platform.environment['LG3_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final suffix = '${w.toInt()}x${h.toInt()}${scale != 1.0 ? '_x$scale' : ''}';

  for (final lang in langs) {
    setUpAll(() {
      _lang = lang;
      return _loadFonts(lang == 'ar');
    });
    for (final dark in [false, true]) {
      for (final shot in _shots) {
        if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
        final name = '${shot.file}${dark ? '_koyu' : ''}_${lang}_$suffix';
        testWidgets('lg3 $name', skip: skip != null, (tester) async {
          _lang = lang;
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(w * _dpr, h * _dpr);
          addTearDown(tester.view.reset);
          addTearDown(tester.view.resetViewInsets);

          final b = FakeBackend(delay: shot.delay ?? Duration.zero);
          final s = makeSession(b, signedIn: false);
          shot.setup?.call(b, s);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          final home = shot.back
              ? Builder(
                  builder: (c) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => LoginPage(session: s))),
                        child: const Text('go'),
                      ),
                    ),
                  ),
                )
              : LoginPage(session: s);
          await tester.pumpWidget(_app(home, lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1200));
          if (shot.back) {
            await tester.tap(find.text('go'));
            await settle(tester, const Duration(milliseconds: 1200));
          }
          if (shot.keyboard) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300 * _dpr);
            await tester.pump();
            await settle(tester, const Duration(milliseconds: 900));
          }
          if (shot.after != null) {
            await shot.after!(tester, s);
            await settle(tester, const Duration(milliseconds: 700));
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
            print('YAZILDI ${f.path} ${image.width}x${image.height}');
          });
          if (shot.delay != null) await tester.pump(shot.delay! + const Duration(seconds: 1));
          await unmount(tester);
        });
      }
    }
  }
}
