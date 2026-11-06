@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profile_menu_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Profilim uc cizgi menusu, sayisiz sekmeler, Gizlilik e-posta anahtari ekran goruntuleri. Varsayilan `flutter test` ile atlanir.
/// Uretim: STORE_SHOTS_OUT='C:/bu_qa/shots/profile_menu' flutter test test/redesign/profile_menu_shots_test.dart
const _dpr = 2.5;

enum _Screen { profile, menu, privacy }

class _Shot {
  const _Shot(this.file, this.screen, {this.width = 390, this.dark = false, this.lang = 'tr', this.scale = 1.0, this.requests = 0});
  final String file;
  final _Screen screen;
  final double width;
  final bool dark;
  final String lang;
  final double scale;
  final int requests;
}

const _shots = <_Shot>[
  _Shot('01_profilim', _Screen.profile),
  _Shot('02_profilim_koyu', _Screen.profile, dark: true),
  _Shot('03_profilim_320_x13', _Screen.profile, width: 320, scale: 1.3),
  _Shot('04_profilim_arapca_rtl', _Screen.profile, lang: 'ar'),
  _Shot('05_menu', _Screen.menu),
  _Shot('06_menu_istekli', _Screen.menu, requests: 3),
  _Shot('07_menu_koyu', _Screen.menu, dark: true),
  _Shot('08_menu_320_x13', _Screen.menu, width: 320, scale: 1.3),
  _Shot('09_menu_arapca_rtl', _Screen.menu, lang: 'ar'),
  _Shot('10_menu_ingilizce', _Screen.menu, lang: 'en'),
  _Shot('11_gizlilik_eposta', _Screen.privacy),
  _Shot('12_gizlilik_koyu', _Screen.privacy, dark: true),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil' : null;

  setUpAll(() async {
    await loadTestFonts();
  });

  for (final shot in _shots) {
    testWidgets('profile_menu ${shot.file}', skip: skip != null, (tester) async {
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
          'bio': 'Yazılım, satranç ve kampüs etkinlikleri.',
          'showEmail': true,
          'postCount': 2,
          'reelCount': 1,
        })
        ..on('/users/me/follow-requests/count', {'count': shot.requests})
        ..on('/users/me/privacy', {
          'avatar': 'EVERYONE',
          'bio': 'SHARED_CONTEXT',
          'department': 'EVERYONE',
          'faculty': 'ONLY_ME',
          'classYear': 'SHARED_CONTEXT',
          'avatarHiddenByModeration': false,
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
          home: switch (shot.screen) {
            _Screen.profile => ProfileTab(session: session, themeController: ThemeController()),
            _Screen.menu => ProfileMenuPage(session: session, themeController: ThemeController()),
            _Screen.privacy => PrivacyDataPage(session: session),
          },
        ),
      ));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
      });
      await settle(tester, const Duration(milliseconds: 900));
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
