import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// D2 Kesfet yeniden tasarim ekran goruntuleri (onceki/sonra).
/// Uretim: D2_OUT='C:/bu_qa/shots/tasarim/kesfet/sonra' D2_W=390 flutter test test/redesign/d2_kesfet_shots_test.dart
/// Istege bagli: `D2_LANG=tr|en|ar`, `D2_ONLY=01,03`, `D2_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';
final double _w = double.tryParse(Platform.environment['D2_W'] ?? '') ?? 390;

class _Shot {
  const _Shot(this.file, {this.height = 844, this.state = 'full', this.after});
  final String file;
  final double height;
  final String state; // full | loading | empty | error
  final Future<void> Function(WidgetTester t)? after;
}

const _authors = [
  ('Emre Kaya', 'Çim Alan', 2),
  ('Zeynep Arslan', 'Kütüphane', 4),
  ('Kaan Çelik', 'Kafeterya', 6),
  ('Kampüs Spor', 'Spor Salonu', 8),
];

Map<String, dynamic> _post(int i) {
  final a = _authors[i % _authors.length];
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: 40 + i, width: 1200, height: 900)],
    text: const [
      'Güneşli ve huzurlu bir sonbahar günü',
      'Kütüphane merdivenlerinde nöbet tutan sevimli dostumuz',
      'Vize haftasında sıcak bir kahve molası',
      'Sabah antrenmanları tüm hızıyla devam ediyor',
    ][i % 4],
    likeCount: const [284, 512, 189, 340][i % 4],
    authorId: 20 + i,
    authorName: a.$1,
    createdAt: DateTime.now().subtract(Duration(hours: a.$3)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = a.$2;
  return p;
}

void _data(FakeBackend b) {
  b.on('/feed*', {'items': [for (var i = 0; i < 4; i++) _post(i)], 'nextCursor': null, 'hint': null});
  b.on('/users/me/follow-suggestions*', {
    'items': [
      {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
      {'id': 32, 'displayName': 'Ece Yılmaz', 'department': 'İktisat', 'followedByMe': false},
      {'id': 33, 'displayName': 'Selin Öztürk', 'department': 'Mimarlık', 'followedByMe': false},
    ],
  });
}

final _shots = <_Shot>[
  const _Shot('01_dolu'),
  const _Shot('02_dolu_uzun', height: 1700),
  const _Shot('03_yukleniyor', state: 'loading'),
  const _Shot('04_bos', state: 'empty'),
  const _Shot('05_hata', state: 'error'),
  const _Shot('05b_hata_ag', state: 'offline'),
  const _Shot('06_populer_cipi', after: _popular),
  const _Shot('07_oneriler', after: _suggestions),
];

Future<void> _suggestions(WidgetTester t) async {
  await t.drag(find.byType(CustomScrollView).last, const Offset(0, -700));
  await t.pump();
  await t.drag(find.byType(CustomScrollView).last, const Offset(0, -700));
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _popular(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('discoverChipPopular')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
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

void main() {
  final out = Platform.environment['D2_OUT'];
  final skip = out == null ? 'D2_OUT tanimli degil' : null;
  _lang = Platform.environment['D2_LANG'] ?? 'tr';
  final only = (Platform.environment['D2_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['D2_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
      final name = '${shot.file}${v.$1}_$_lang';
      testWidgets('d2 kesfet $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        switch (shot.state) {
          case 'loading':
            _data(b);
            b.delay = const Duration(seconds: 4);
          case 'empty':
            b.on('/feed*', {'items': <Object>[], 'nextCursor': null, 'hint': null});
            b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
          case 'offline':
            b.network('/feed');
            b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
          case 'error':
            b.fail('/feed', status: 500, code: 'SERVER_ERROR', message: 'Sunucu hatası');
            b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
          default:
            _data(b);
        }
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null)), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
        });
        if (shot.state != 'loading') {
          await settle(tester, const Duration(milliseconds: 900));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 150));
        } else {
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (shot.after != null) await shot.after!(tester);
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
        if (shot.state == 'loading') await tester.pump(const Duration(seconds: 90));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }

  // Ana Sayfa Hizli Erisim (Anketler karosu): D2_ONLY=home ile uretilir.
  if (only.contains('home')) {
    for (final v in variants) {
      final name = 'ana_sayfa_hizli_erisim${v.$1}_$_lang';
      testWidgets('d2 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, 960 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final b = FakeBackend()..on('/menu/today', {'date': '2026-01-01', 'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav']});
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(Scaffold(body: HomeTab(session: session, onOpenTab: (i, {newsType}) {})), v.$2, key, v.$3));
        await settle(tester, const Duration(milliseconds: 900));
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
