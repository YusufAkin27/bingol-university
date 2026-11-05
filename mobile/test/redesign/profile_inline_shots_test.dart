@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Profilim satir ici duzenleme ekran goruntuleri. Varsayilan `flutter test` ile atlanir.
/// Uretim: STORE_SHOTS_OUT='C:/bu_qa/shots/profile_inline' flutter test test/redesign/profile_inline_shots_test.dart
const _dpr = 2.5;

class _Shot {
  const _Shot(this.file, {this.width = 390, this.dark = false, this.lang = 'tr', this.bio = 'Yazılım, satranç ve kampüs etkinlikleri.', this.after, this.scale = 1.0});
  final String file;
  final double width;
  final bool dark;
  final String lang;
  final String bio;
  final double scale;
  final Future<void> Function(WidgetTester t)? after;
}

Future<void> _tapKey(WidgetTester t, String k) async {
  await t.tap(find.byKey(ValueKey(k)));
  await t.pump(const Duration(milliseconds: 600));
}

final _shots = <_Shot>[
  const _Shot('01_profilim'),
  _Shot('02_ad_duzenleme', after: (t) async {
    await _tapKey(t, 'inline-name');
    await t.enterText(find.byKey(const ValueKey('inline-name-field')), 'Ayşe Kaya Yılmaz');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('03_ad_hata', after: (t) async {
    await _tapKey(t, 'inline-name');
    await t.enterText(find.byKey(const ValueKey('inline-name-field')), 'A');
    await _tapKey(t, 'inline-save');
  }),
  _Shot('04_bio_duzenleme', after: (t) async {
    await _tapKey(t, 'inline-bio');
    await t.enterText(find.byKey(const ValueKey('inline-bio-field')), 'Yazılım, satranç ve kampüs etkinlikleri. Hafta sonları robotik kulübünde atölye düzenliyorum.');
    await t.pump(const Duration(milliseconds: 300));
  }),
  const _Shot('05_bio_bos', bio: ''),
  const _Shot('06_320dp', width: 320),
  const _Shot('07_320dp_x13', width: 320, scale: 1.3),
  _Shot('08_koyu', dark: true, after: (t) async {
    await _tapKey(t, 'inline-bio');
    await t.pump(const Duration(milliseconds: 300));
  }),
  const _Shot('09_koyu_normal', dark: true),
  const _Shot('10_arapca_rtl', lang: 'ar'),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil' : null;

  setUpAll(() async {
    await loadTestFonts();
  });

  for (final shot in _shots) {
    testWidgets('profile_inline ${shot.file}', skip: skip != null, (tester) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = Size(shot.width * _dpr, 900 * _dpr);
      tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
      addTearDown(tester.view.reset);
      final b = FakeBackend()
        ..on('/me/summary', {'communities': 3, 'events': 4, 'bookmarks': 12})
        ..on('/users/me', {
          'id': 1,
          'displayName': 'Ayşe Kaya',
          'email': 'ayse@bingol.edu.tr',
          'faculty': 'Mühendislik Fakültesi',
          'department': 'Bilgisayar Mühendisliği',
          'grade': '3',
          'bio': shot.bio,
          'showEmail': false,
        })
        ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false});
      fakeCatalog(b);
      fakePosts(b, count: 4);
      final Session session = makeSession(b)..api.lang = shot.lang;
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(shot.lang)])..pref = shot.lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.forLocale(Brightness.light, shot.lang),
          darkTheme: BuTheme.forLocale(Brightness.dark, shot.lang),
          themeMode: shot.dark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(shot.lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(shot.scale)),
            child: child!,
          ),
          home: ProfileTab(session: session, themeController: ThemeController()),
        ),
      ));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
      });
      await settle(tester, const Duration(milliseconds: 900));
      if (shot.after != null) {
        await shot.after!(tester);
        await settle(tester, const Duration(milliseconds: 500));
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: _dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory(out!)..createSync(recursive: true);
        File('${dir.path}/${shot.file}.png').writeAsBytesSync(data.buffer.asUint8List());
      });
      await unmount(tester);
    });
  }
}
