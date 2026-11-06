@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_stream.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// KESFET2-MB: Stitch v3 kesfet2 referanslariyla YAN YANA goruntuler (sol referans, sag uygulama).
/// Uretim: STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/kesfet2' flutter test test/redesign/kesfet2_shots_test.dart
/// Istege bagli: `K2_LANG=tr|en|ar`, `K2_ONLY=01,08`, `K2_MODES=light,dark,x13`, `K2_REF=C:/bu_design/stitch/v3_kesfet2`.
/// Not: test render'inda fotograflar uretilmis soyut sahnelerdir (referanstaki gercek fotograflar degil); alt bar
/// (BukampusBottomNavigationBar) ayri bilesen oldugundan sag tarafta yoktur.
const _dpr = 2.0;
String _lang = 'tr';

class _Shot {
  const _Shot(this.file, this.ref, {this.state = 'full', this.after, this.detail = false});
  final String file;
  final String ref; // referans dosya adi on eki (NN_ad)
  final String state; // full | loading | empty | error | offline | band
  final Future<void> Function(WidgetTester t)? after;
  final bool detail;
}

/// (id, yazar, bolum, saat, begeni, begenilmis, genislik x yukseklik, metin, sahne)
const _rows = [
  (1, 'Emre Kaya', 'Makine Mühendisliği', 2, 284, true, (1080, 1440), 'Bahar geldi kampüse', 0),
  (2, 'Zeynep Arslan', 'Hemşirelik', 3, 142, false, (1080, 1080), 'Sessiz bir çalışma köşesi', 4),
  (3, 'Mert Demir', 'İşletme', 4, 198, true, (1080, 1620), 'Yeni kütüphane binası', 1),
  (4, 'Elif Yıldız', 'Hemşirelik', 5, 175, false, (1080, 1350), 'Sonbahar bisikleti', 2),
  (5, 'Can Aydın', 'İşletme', 26, 312, true, (1080, 1080), 'Ders çıkışı göl kenarında yürüyüş', 3),
  (6, 'Selin Öztürk', 'Mimarlık', 30, 96, false, (1080, 1620), 'Kampüsün tembel sakini', 5),
  (7, 'Burak Çelik', 'Bilgisayar Müh.', 31, 58, false, (1080, 1350), 'Satranç kulübü turnuvası', 6),
  (8, 'Ayşe Demir', 'İktisat', 33, 77, false, (1080, 1350), 'Akşam konseri', 7),
];

Map<String, dynamic> _post(int i) {
  final r = _rows[i % _rows.length];
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: r.$9, width: r.$7.$1, height: r.$7.$2)],
    text: r.$8,
    likeCount: r.$5,
    liked: r.$6,
    authorId: 20 + i,
    authorName: r.$2,
    createdAt: DateTime.now().subtract(Duration(hours: r.$4)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = r.$3;
  return p;
}

void _data(FakeBackend b, {bool suggestions = false, int count = 8}) {
  b.on('/feed*', {'items': [for (var i = 0; i < count; i++) _post(i)], 'nextCursor': null, 'hint': null});
  b.on('/posts/*', _post(0));
  b.on('/users/me/follow-suggestions*', {
    'items': suggestions
        ? [
            {'id': 31, 'displayName': 'Burak Çelik', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
            {'id': 32, 'displayName': 'Ayşe Demir', 'department': 'Hemşirelik', 'followedByMe': false},
            {'id': 33, 'displayName': 'Deniz Öztürk', 'department': 'İşletme', 'followedByMe': false},
          ]
        : <Object>[],
  });
}

Future<void> _scroll150(WidgetTester t) async {
  t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(150);
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _doubleTap(WidgetTester t) async {
  final at = t.getCenter(find.byKey(const ValueKey('post-photo-500')));
  await t.tapAt(at);
  await t.pump(const Duration(milliseconds: 50));
  await t.tapAt(at);
  await t.pump(const Duration(milliseconds: 120));
}

Future<void> _detailScrolled(WidgetTester t) async {
  final pos = t.state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('postStream')), matching: find.byType(Scrollable)).first).position;
  final target = find.byKey(const ValueKey('stream-post-496')); // 5. gonderi: "Can Aydin"
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 60));
    if (target.evaluate().isNotEmpty) {
      final dy = t.getTopLeft(target).dy - 138; // referans 09: yazar satiri ust kenari 138 dp
      if (dy.abs() < 1) break;
      pos.jumpTo(pos.pixels + dy);
    } else {
      pos.jumpTo(pos.pixels + 700);
    }
  }
  await t.pump(const Duration(milliseconds: 300));
}

final _shots = <_Shot>[
  const _Shot('01_masonry', '01_kesfet_masonry_A'),
  const _Shot('03_yukleniyor', '03_yukleniyor', state: 'loading'),
  const _Shot('04_bos', '04_bos', state: 'empty'),
  const _Shot('05_hata', '05_hata', state: 'error'),
  const _Shot('06_cevrimdisi', '06_cevrimdisi', state: 'offline'),
  const _Shot('07_tanir_misin', '07_tanir_misin_seridi', state: 'band', after: _scroll150),
  const _Shot('08_gonderi_sayfasi', '08_gonderi_sayfasi', detail: true),
  const _Shot('09_gonderi_kaydirilmis', '09_gonderi_kaydirilmis', detail: true, after: _detailScrolled, state: 'loadingmore'),
  const _Shot('10_cift_dokunus', '10_cift_dokunus_begeni', detail: true, after: _doubleTap),
];

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
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil' : null;
  final refDir = Platform.environment['K2_REF'] ?? 'C:/bu_design/stitch/v3_kesfet2';
  _lang = Platform.environment['K2_LANG'] ?? 'tr';
  final only = (Platform.environment['K2_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K2_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('light', false, 1.0),
    if (modes.contains('dark')) ('dark', true, 1.0),
    if (modes.contains('x13')) ('x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
      final name = '${shot.file}_${v.$1}_$_lang';
      testWidgets('kesfet2 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewPadding = FakeViewPadding.zero;
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        switch (shot.state) {
          case 'loading':
            _data(b);
            b.delay = const Duration(seconds: 4);
          case 'empty':
            b.on('/feed*', {'items': <Object>[], 'nextCursor': null, 'hint': null});
            b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
          case 'error':
            b.fail('/feed', status: 500, code: 'SERVER_ERROR', message: 'Sunucu hatası');
            b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
          case 'band':
            _data(b, suggestions: true);
          case 'loadingmore':
            _data(b, count: 8);
          default:
            _data(b);
        }
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        final Widget home;
        if (shot.detail) {
          final first = Post.fromJson(_post(0));
          home = PostDetailPage(
            session: session,
            postId: first.id,
            initial: first,
            stream: PostStreamSeed(items: [for (var i = 1; i < 8; i++) Post.fromJson(_post(i))], hasMore: shot.state == 'loadingmore'),
          );
        } else {
          home = DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null));
        }
        await tester.pumpWidget(_app(home, v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
        });
        if (shot.state == 'loading') {
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          await settle(tester, const Duration(milliseconds: 900));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (shot.state == 'offline') {
          // Ag yokken yenileme: warnSoft notu + eski gonderiler.
          b.offline = true;
          await tester.fling(find.byType(CustomScrollView).last, const Offset(0, 500), 2000);
          await settle(tester, const Duration(milliseconds: 1500));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (shot.state == 'loadingmore') b.delay = const Duration(seconds: 30);
        if (shot.after != null) await shot.after!(tester);
        if (shot.state == 'loadingmore') {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 500));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final mine = im.decodePng(data.buffer.asUint8List())!;
          final refFile = File('$refDir/${shot.ref}_${v.$2 ? 'dark' : 'light'}.png');
          if (v.$3 == 1.0 && _lang == 'tr' && refFile.existsSync()) {
            final ref = im.decodePng(refFile.readAsBytesSync())!;
            const gap = 24;
            final canvas = im.Image(width: ref.width + gap + mine.width, height: ref.height > mine.height ? ref.height : mine.height, numChannels: 3);
            im.fill(canvas, color: im.ColorRgb8(128, 128, 128));
            im.compositeImage(canvas, ref, dstX: 0, dstY: 0);
            im.compositeImage(canvas, mine, dstX: ref.width + gap, dstY: 0);
            File('${dir.path}/$name.png').writeAsBytesSync(im.encodePng(canvas, level: 1));
          } else {
            File('${dir.path}/$name.png').writeAsBytesSync(im.encodePng(mine, level: 1));
          }
          // ignore: avoid_print
          print('YAZILDI ${dir.path}/$name.png');
        });
        await unmount(tester);
        if (shot.state == 'loading' || shot.state == 'loadingmore') await tester.pump(const Duration(seconds: 90));
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
