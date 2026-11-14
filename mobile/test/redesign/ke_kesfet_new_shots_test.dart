@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../kesfet_ks_test.dart' show FakeVideoPlatformKs;
import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// KE-MB: yeni Keşfet (filtre yok, karma ızgara, boş/kırmızı kalp, dikey akış) ekran görüntüleri.
/// Üretim: STORE_SHOTS_OUT='C:/bu_qa/shots/kesfet_new' flutter test test/redesign/ke_kesfet_new_shots_test.dart
/// İsteğe bağlı: `KE_MODES=light,dark,x13`.
const _dpr = 2.0;

const _rows = [
  (284, true, (1080, 1440), 'Bahar geldi kampüse', 'Emre Kaya', 'Makine Mühendisliği', false),
  (142, false, (1080, 1080), 'Sessiz bir çalışma köşesi', 'Zeynep Arslan', 'Hemşirelik', true),
  (198, true, (1080, 1620), 'Yeni kütüphane binası', 'Mert Demir', 'İşletme', false),
  (175, false, (1080, 1350), 'Sonbahar bisikleti', 'Elif Yıldız', 'Hemşirelik', false),
  (312, true, (1080, 1080), 'Göl kenarında yürüyüş', 'Can Aydın', 'İşletme', true),
  (96, false, (1080, 1620), 'Kampüsün tembel sakini', 'Selin Öztürk', 'Mimarlık', false),
  (58, false, (1080, 1350), 'Satranç kulübü turnuvası', 'Burak Çelik', 'Bilgisayar Müh.', false),
  (77, false, (1080, 1350), 'Akşam konseri', 'Ayşe Demir', 'İktisat', true),
];

Map<String, dynamic> _post(int i) {
  final r = _rows[i % _rows.length];
  final id = 500 - i;
  final isVideo = r.$7;
  final p = samplePost(
    id: id,
    media: isVideo ? [] : [samplePostMedia(id: i + 1, width: r.$3.$1, height: r.$3.$2)],
    text: r.$4,
    likeCount: r.$1,
    liked: r.$2,
    authorId: 20 + i,
    authorName: r.$5,
    createdAt: DateTime.now().subtract(Duration(hours: i + 2)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = r.$6;
  if (isVideo) {
    p['type'] = 'VIDEO';
    p['video'] = {
      'url': '/api/posts/media/${i + 1}',
      'posterUrl': '/api/posts/media/${i + 1}?thumb=true',
      'durationMs': 23000,
      'width': 720,
      'height': 1280,
    };
  }
  return p;
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

class _Shot {
  const _Shot(this.file, {this.open, this.scrollUp = false, this.size = const Size(390, 844)});
  final String file;
  final int? open; // aç: kutu id
  final bool scrollUp;
  final Size size;
}

final _shots = <_Shot>[
  const _Shot('01_izgara'),
  const _Shot('02_izgara_320', size: Size(320, 640)),
  const _Shot('03_dikey_akis_foto', open: 498),
  const _Shot('04_dikey_akis_ustte_onceki', open: 498, scrollUp: true),
  const _Shot('05_dikey_akis_video', open: 499),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil' : null;
  final modes = (Platform.environment['KE_MODES'] ?? 'light,dark').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('light', false, 1.0),
    if (modes.contains('dark')) ('dark', true, 1.0),
    if (modes.contains('x13')) ('x1.3', false, 1.3),
  ];

  setUpAll(loadTestFonts);

  for (final v in variants) {
    for (final shot in _shots) {
      final name = '${shot.file}_${v.$1}';
      testWidgets('kesfet yeni $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        final prevPlat = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = FakeVideoPlatformKs();
        addTearDown(() => VideoPlayerPlatform.instance = prevPlat);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(shot.size.width * _dpr, shot.size.height * _dpr);
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewPadding = FakeViewPadding.zero;
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        final items = [for (var i = 0; i < 8; i++) _post(i)];
        b.on('/feed*', {'items': items, 'nextCursor': null});
        for (final p in items) {
          b.on('/posts/${p['id']}', p);
        }
        b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
        final session = makeSession(b)..api.lang = 'tr';
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null)), v.$2, key, v.$3));
        await tester.runAsync(() async {
        });
        await settle(tester, const Duration(milliseconds: 900));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        if (shot.open != null) {
          await tester.tapAt(tester.getCenter(find.byKey(ValueKey('discover-post-${shot.open}'))));
          await settle(tester, const Duration(milliseconds: 900));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 500));
          if (shot.scrollUp) {
            await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, 420));
            await settle(tester, const Duration(milliseconds: 500));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final mine = im.decodePng(data.buffer.asUint8List())!;
          File('${dir.path}/$name.png').writeAsBytesSync(im.encodePng(mine, level: 1));
          // ignore: avoid_print
          print('YAZILDI ${dir.path}/$name.png');
        });
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
