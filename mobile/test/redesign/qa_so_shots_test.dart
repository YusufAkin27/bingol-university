@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// QA-SO tasarim denetimi ekran goruntuleri: Ana Sayfa, Kesfet, Reels (surukleyici alt cubuk), Profil, kullanici profili.
///
/// Varsayilan `flutter test` ile CALISMAZ. Uretim:
///   STORE_SHOTS_OUT='C:/bu_qa/shots/social' flutter test test/redesign/qa_so_shots_test.dart
/// Istege bagli: `QA_SIZES=390x844,320x640`, `QA_ONLY=02,04`.
const _dpr = 2.5;

Map<String, dynamic> _post(int id, {bool video = false}) => {
      'id': id,
      'type': video ? 'VIDEO' : 'IMAGE',
      'author': {'id': 20 + id, 'displayName': ['Selin Kaya', 'Burak Çelik', 'Zeynep Demir', 'Mehmet Aksoy'][id % 4], 'department': 'Bilgisayar Mühendisliği'},
      'text': ['Kampüste bahar', 'Final haftası', 'Kütüphane köşesi', 'Akşam yürüyüşü'][id % 4],
      'media': video
          ? <Map<String, dynamic>>[]
          : [
              {'id': id, 'kind': 'IMAGE', 'url': '/api/posts/media/$id', 'thumbUrl': '/api/posts/media/$id?thumb=true', 'width': 600, 'height': id.isEven ? 750 : 450}
            ],
      if (video) 'video': {'url': '/api/posts/media/$id', 'posterUrl': '/api/posts/media/$id?thumb=true', 'durationMs': 23000, 'width': 720, 'height': 1280},
      'likeCount': 3 + id,
      'likedByMe': false,
      'mine': false,
      'canEdit': false,
      'canDelete': false,
      'createdAt': '2026-11-04T09:00:00Z',
      'popularityScore': 40 + id,
    };

void _base(FakeBackend b) {
  b
    ..on('/me/summary', {'unreadNotifications': 2, 'unreadMessages': 3, 'communities': 3, 'events': 2, 'bookmarks': 5})
    ..on('/auth/me', {'id': 1, 'displayName': 'Ayşe Kaya', 'email': 'seed.ayse@bingol.edu.tr', 'role': 'USER'})
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'email': 'seed.ayse@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım, satranç ve kampüs etkinlikleri.',
      'postCount': 12,
      'reelCount': 3,
      'popularityScore': 72,
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false})
    ..on('/posts/mine*', {'items': [for (var i = 1; i <= 9; i++) _post(i)], 'nextCursor': 'c', 'total': 12})
    ..on('/users/1/reels*', {'items': [for (var i = 31; i <= 33; i++) _post(i, video: true)], 'nextCursor': null})
    ..on('/feed/reels*', {'items': [videoPost(id: 41), videoPost(id: 42)], 'nextCursor': null})
    ..on('/feed*', {'items': [for (var i = 1; i <= 10; i++) _post(i, video: i % 5 == 0)], 'nextCursor': null})
    ..on('/users/me/follow-suggestions*', {
      'items': [
        for (final n in ['Emre Yılmaz', 'Selin Kaya', 'Can Öztürk', 'Elif Şahin'])
          {'id': 50 + n.length, 'displayName': n, 'department': 'İktisat', 'followState': 'NONE', 'isPrivate': false}
      ]
    })
    ..on('/users/12', {'id': 12, 'displayName': 'Ayşe Yılmaz', 'followState': 'NONE', 'isPrivate': false})
    ..on('/users/2', {
      'id': 2,
      'displayName': 'Mert Kaya',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Merhaba, ben Mert.',
      'followerCount': 126,
      'followingCount': 98,
      'followedByMe': false,
      'followsMe': true,
      'postCount': 9,
      'reelCount': 2,
    })
    ..on('/users/2/posts*', {'items': [for (var i = 1; i <= 9; i++) _post(i)], 'nextCursor': 'c', 'total': 9})
    ..on('/users/2/reels*', {'items': [for (var i = 31; i <= 32; i++) _post(i, video: true)], 'nextCursor': null});
}

class _Shot {
  const _Shot(this.file, this.build, {this.after});
  final String file;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? after;
}

Future<void> _tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t, const Duration(milliseconds: 900));
}

final _shots = <_Shot>[
  _Shot('01_ana_sayfa', (b) => AppShell(initialTab: AppTab.home, session: makeSession(b), themeController: ThemeController())),
  _Shot('02_kesfet', (b) => AppShell(initialTab: AppTab.home, session: makeSession(b), themeController: ThemeController()), after: (t) => _tapKey(t, 'nav-1')),
  _Shot('03_reels', (b) => AppShell(initialTab: AppTab.home, session: makeSession(b), themeController: ThemeController()), after: (t) async {
    await _tapKey(t, 'nav-1');
    await _tapKey(t, 'discoverFilter-reels');
  }),
  _Shot('04_profil_sekmesi', (b) => ProfileTab(session: makeSession(b), themeController: ThemeController())),
  _Shot('05_profil_reels_sekmesi', (b) => ProfileTab(session: makeSession(b), themeController: ThemeController()), after: (t) async {
    final f = find.text('Reels');
    await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(f);
  }),
  _Shot('06_kullanici_profili', (b) => UserProfilePage(session: makeSession(b), userId: 2)),
];

Widget _app(Widget home, bool dark, GlobalKey key, Size size) {
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, 'tr'),
      darkTheme: BuTheme.forLocale(Brightness.dark, 'tr'),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  final only = (Platform.environment['QA_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final sizes = (Platform.environment['QA_SIZES'] ?? '390x844')
      .split(',')
      .map((s) => s.split('x'))
      .map((p) => Size(double.parse(p[0]), double.parse(p[1])))
      .toList();
  final tag = Platform.environment['QA_TAG'] ?? 'sonra';

  setUpAll(loadTestFonts);

  for (final size in sizes) {
    for (final dark in [false, true]) {
      for (final shot in _shots) {
        if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
        final name = '${shot.file}_${size.width.toInt()}${dark ? '_koyu' : ''}_$tag';
        testWidgets('qa_so $name', skip: skip != null, (tester) async {
          debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
          final plat = FakeVideoPlatformKs();
          final prev = VideoPlayerPlatform.instance;
          VideoPlayerPlatform.instance = plat;
          addTearDown(() => VideoPlayerPlatform.instance = prev);
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(size.width * _dpr, size.height * _dpr);
          tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          addTearDown(tester.view.reset);

          final b = FakeBackend();
          _base(b);
          LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
          addTearDown(() => LocaleController.current = null);

          final key = GlobalKey();
          await tester.pumpWidget(_app(shot.build(b), dark, key, size));
          await tester.runAsync(() async {
          });
          await settle(tester, const Duration(milliseconds: 900));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 150));
          if (shot.after != null) {
            await shot.after!(tester);
            await settle(tester, const Duration(milliseconds: 700));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
            await tester.pump(const Duration(milliseconds: 300));
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
          await unmount(tester);
          debugNetworkImageHttpClientProvider = null;
        });
      }
    }
  }
}
