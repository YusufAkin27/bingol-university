@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/home/home_suggestions.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// SG-MB ekran goruntuleri: Ana Sayfa "Onerilen kisiler" seridi, "Tumunu gor" sayfasi, profilde artik yok.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (PowerShell):
///   $env:SG_SHOTS_OUT='C:/bu_qa/shots/suggest'; flutter test test/redesign/sg_shots_test.dart
/// Istege bagli: `SG_LANG=tr|ar`, `SG_MODES=light,dark,x13`, `SG_ONLY=01,03`.
const _dpr = 2.0;
String _lang = 'tr';

const _names = ['Mehmet Demir', 'Zeynep Kaya', 'Burak Şahin', 'Ayşe Nur Çelik', 'Emre Yılmaz', 'Elif Arslan', 'Can Öztürk'];
const _depts = [
  'Bilgisayar Mühendisliği',
  'Moleküler Biyoloji ve Genetik',
  'İktisadi ve İdari Bilimler',
  'İlahiyat Fakültesi',
  'Diş Hekimliği Fakültesi',
];

List<Map<String, dynamic>> _people(int n, {bool reasons = true}) => [
      for (var i = 0; i < n; i++)
        {
          'id': 200 + i,
          'displayName': _names[i % _names.length],
          'department': _depts[i % _depts.length],
          'classYear': 1 + i % 4,
          'followState': i == 2 ? 'FOLLOWING' : 'NONE',
          if (reasons && i % 2 == 0) 'reason': _lang == 'ar' ? 'نفس القسم، 14 مشتركًا' : 'Aynı bölümden 14 ortak',
        },
    ];

void _sugg(FakeBackend b, {int n = 10}) => b.on('/users/me/follow-suggestions*', {'items': _people(n)});

void _homeData(FakeBackend b) {
  _sugg(b);
  b
    ..on('/menu/today', {
      'date': '2026-11-05',
      'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav'],
      'dishes': [
        {'name': 'Mercimek çorbası', 'kcal': 160},
        {'name': 'Orman kebabı', 'kcal': 380},
        {'name': 'Pilav', 'kcal': 210},
      ],
      'totalKcal': 750,
      'kcalComplete': true,
    })
    ..on('/news?type=HABER&page=0&size=5', {
      'items': [
        {'id': 1, 'title': 'Bahar dönemi kayıt tarihleri açıklandı', 'type': 'HABER', 'publishedDate': '2026-11-01'},
        {'id': 3, 'title': 'Kampüste yeni kütüphane saatleri', 'type': 'HABER', 'publishedDate': '2026-11-02'},
      ]
    })
    ..on('/news?type=DUYURU&page=0&size=3', {
      'items': [
        {'id': 2, 'title': 'Sınav takvimi açıklandı', 'type': 'DUYURU', 'publishedDate': '2026-11-02'},
      ]
    });
}

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.height = 844, this.width = 390});
  final String file;
  final Widget Function(FakeBackend b, Session s) build;
  final void Function(FakeBackend b)? setup;
  final double height;
  final double width;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

final _shots = <_Shot>[
  _Shot('01_ana_sayfa', (b, s) => Scaffold(body: HomeTab(session: s, onOpenTab: (i, {newsType}) {})), setup: _homeData, height: 2100),
  _Shot('02_serit_320', (b, s) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: HomeSuggestions(session: s)))),
      setup: _sugg, width: 320, height: 420),
  _Shot('03_serit_yukleniyor', (b, s) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: HomeSuggestions(session: s)))),
      setup: (b) {
        _sugg(b);
        b.delay = const Duration(seconds: 3);
      },
      height: 360),
  _Shot('04_tumunu_gor', (b, s) => FollowSuggestionsPage(session: s), setup: (b) => _sugg(b, n: 7)),
  _Shot('05_tumunu_gor_320', (b, s) => FollowSuggestionsPage(session: s), setup: (b) => _sugg(b, n: 7), width: 320, height: 640),
  _Shot('06_tumunu_gor_bos', (b, s) => FollowSuggestionsPage(session: s), setup: (b) => b.on('/users/me/follow-suggestions*', {'items': <Object>[]})),
  _Shot('07_tumunu_gor_hata', (b, s) => FollowSuggestionsPage(session: s),
      setup: (b) => b.fail('/users/me/follow-suggestions*', status: 500, code: 'SERVER_ERROR', message: 'Sunucuyla iletişim kurulurken bir aksama yaşandı.')),
  _Shot('08_profil_oneri_yok', (b, s) => Scaffold(body: ProfileTab(session: s, themeController: ThemeController())), setup: (b) {
    b
      ..on('/me/summary', {'unreadNotifications': 2, 'unreadMessages': 3, 'communities': 8, 'events': 19, 'bookmarks': 12})
      ..on('/users/me', {'id': 1, 'displayName': 'Defne Kaya', 'email': 'defne.kaya@bingol.edu.tr', 'department': 'Bilgisayar Mühendisliği', 'grade': '3', 'bio': ''})
      ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false});
  }, height: 1100),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, _lang),
        darkTheme: BuTheme.forLocale(Brightness.dark, _lang),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(_lang),
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
  final out = Platform.environment['SG_SHOTS_OUT'];
  final skip = out == null ? 'SG_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['SG_LANG'] ?? 'tr';
  final only = (Platform.environment['SG_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['SG_MODES'] ?? 'light').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(loadTestFonts);

  for (final v in variants) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
      final name = '${shot.file}${v.suffix}_$_lang';
      testWidgets('sg $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(shot.width * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        shot.setup?.call(b);
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(b, session), v.dark, key, v.scale));
        await settle(tester, const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 150));
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
        await tester.pump(const Duration(seconds: 40));
        await unmount(tester);
      });
    }
  }
}
