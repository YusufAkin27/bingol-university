@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// UI-K4 gruplari 09 (kirpma), 10 (gonderi olustur/detay), 11 (menu/diyaloglar) ekran goruntuleri.
/// Uretim: STORE_SHOTS_OUT='C:/.../redesign/k4/yeni/uygulama' flutter test test/redesign/k4_yeni_shots_test.dart
/// Istege bagli: `K4_LANG=tr|en|ar`, `K4_ONLY=g10_01,g11`, `K4_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.act, this.height = 844});
  final String file;
  final Widget Function(FakeBackend b, Session s) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t, FakeBackend b)? act;
  final double height;
}

class _Up extends PostMediaUploader {
  _Up(super.session);

  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

Uint8List get _photo => storeImageBytes(0);

Widget _compose(Session s, {PostMediaUploader? up}) => ComposePostPage(
      session: s,
      uploader: up ?? _Up(s),
      pickPhoto: (_) async => _photo,
      cropPhoto: (c, b, spec) async => CropOutcome.cropped(b),
    );

Widget _opener(Future<void> Function(BuildContext c) go) => Builder(
      builder: (c) => Scaffold(
        backgroundColor: c.bu.bg,
        body: Center(child: ElevatedButton(key: const ValueKey('open'), onPressed: () => go(c), child: const Text('ac'))),
      ),
    );

Future<void> _openCrop(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('open')));
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _pickPhoto(WidgetTester t) async {
  // (gorsel cozumleme gercek zaman ister)
  await t.tap(find.byKey(const ValueKey('composeGallery')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump(const Duration(milliseconds: 200));
}

Post _post({bool mine = false, bool edited = false, int likes = 128, bool liked = false}) {
  final j = samplePost(
    id: 1000,
    media: [samplePostMedia(id: 7)],
    text: 'Bahar geldi kampüse',
    likeCount: likes,
    liked: liked,
    mine: mine,
    authorId: mine ? 1 : 12,
    authorName: mine ? 'Elif Yıldız' : 'Mehmet Kaya',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
  );
  (j['author'] as Map)['department'] = mine ? 'Bilgisayar Mühendisliği' : 'Makine Mühendisliği';
  if (edited) j['editedAt'] = DateTime.now().toUtc().toIso8601String();
  return Post.fromJson(j);
}

Widget _detail(FakeBackend b, Session s, Post p, {bool patch422 = false}) {
  final json = {
    ...samplePost(
        id: p.id,
        media: [samplePostMedia(id: 7)],
        text: p.text,
        likeCount: p.likeCount,
        liked: p.likedByMe,
        mine: p.mine,
        authorId: p.author.id,
        authorName: p.author.displayName),
    'author': {'id': p.author.id, 'displayName': p.author.displayName, 'avatarUrl': null, 'department': p.author.department},
    'createdAt': p.createdAt,
    'editedAt': p.editedAt,
  };
  // fakePosts'un kendi /posts/{id} isleyicisinden ONCE sorulur.
  b.handlers.insert(0, (req, path) {
    if (path != '/posts/${p.id}') return null;
    if (req.method == 'GET') return FakeResult.json(json);
    if (req.method == 'PATCH' && patch422) return const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': ''}, status: 422);
    return null;
  });
  return PostDetailPage(session: s, postId: p.id, initial: p);
}

Future<void> _menu(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('post-menu-button')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

final _shots = <_Shot>[
  // ---- 10 gonderi olustur / detay
  _Shot('g10_01_bos', (b, s) => _compose(s)),
  _Shot('g10_02_foto_secili', (b, s) => _compose(s), act: (t, b) async {
    await _pickPhoto(t);
    await t.enterText(find.byKey(const ValueKey('composeText')), 'Kütüphane önünde güzel bir gün');
    await t.pump();
  }),
  _Shot('g10_03_hata_kelime', (b, s) => _compose(s), act: (t, b) async {
    await t.enterText(find.byKey(const ValueKey('composeText')), 'Bugün kütüphanede yer kapmaca ve gereksiz laf kavgası');
    await t.pump();
  }),
  _Shot('g10_03b_hata_kufur', (b, s) => _compose(s), setup: (b) {
    b.handlers.insert(0, (req, path) => path == '/posts' && req.method == 'POST' ? const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': ''}, status: 422) : null);
  }, act: (t, b) async {
    await _pickPhoto(t);
    await t.enterText(find.byKey(const ValueKey('composeText')), 'Uygunsuz bir not');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('composeShare')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('g10_03c_hata_ag', (b, s) => _compose(s), act: (t, b) async {
    await _pickPhoto(t);
    b.offline = true;
    await t.tap(find.byKey(const ValueKey('composeShare')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
  }),
  _Shot('g10_04_vazgec', (b, s) => _compose(s), act: (t, b) async {
    await _pickPhoto(t);
    await t.tap(find.byKey(const ValueKey('composeClose')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('g10_05_detay_cift_dokunma', (b, s) => _detail(b, s, _post(liked: true, likes: 129)), act: (t, b) async {
    final f = find.byKey(const ValueKey('post-photo-1000'));
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
  }),
  _Shot('g10_06_detay_kendi', (b, s) => _detail(b, s, _post(mine: true, edited: true, liked: true, likes: 129))),
  _Shot('g10_07_detay_bulunamadi', (b, s) => PostDetailPage(session: s, postId: 99999)),
  // ---- 11 menuler ve diyaloglar
  _Shot('g11_01_menu_kendi', (b, s) => _detail(b, s, _post(mine: true)), act: (t, b) => _menu(t)),
  _Shot('g11_02_menu_baskasi', (b, s) => _detail(b, s, _post()), act: (t, b) => _menu(t)),
  _Shot('g11_03_duzenle', (b, s) => _detail(b, s, _post(mine: true), patch422: true), act: (t, b) async {
    await _menu(t);
    await t.tap(find.byKey(const ValueKey('post-act-edit')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const ValueKey('edit-post-text')), 'Uygunsuz not');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('edit-post-save')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('g11_03b_duzenle_bos', (b, s) => _detail(b, s, _post(mine: true)), act: (t, b) async {
    await _menu(t);
    await t.tap(find.byKey(const ValueKey('post-act-edit')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const ValueKey('edit-post-text')), '');
    await t.pump();
  }),
  _Shot('g11_04_sil', (b, s) => _detail(b, s, _post(mine: true)), act: (t, b) async {
    await _menu(t);
    await t.tap(find.byKey(const ValueKey('post-act-delete')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }),
  // ---- 09 kirpma
  _Shot('g09_01_profil', (b, s) => _opener((c) => cropImage(c, _photo, const CropSpec.profile())), act: (t, b) => _openCrop(t), height: 1000),
  _Shot('g09_02_gonderi', (b, s) => _opener((c) => cropImage(c, _photo, const CropSpec.post(previewName: 'Elif Yıldız', previewCaption: 'Kütüphane önünde güzel bir gün', allowChange: true))),
      act: (t, b) => _openCrop(t), height: 1500),
  _Shot('g09_03_logo', (b, s) => _opener((c) => cropImage(c, _photo, const CropSpec.logo(previewName: 'Robotik Kulübü'))), act: (t, b) => _openCrop(t), height: 1000),
  _Shot('g09_04_kapak', (b, s) => _opener((c) => cropImage(c, _photo, const CropSpec.cover(previewTitle: 'Bahar Şenliği', previewSubtitle: 'Müzik Kulübü', allowRemove: true))),
      act: (t, b) => _openCrop(t), height: 1000),
  _Shot('g09_05_sohbet', (b, s) => _opener((c) => cropImage(c, _photo, const CropSpec.chat())), act: (t, b) => _openCrop(t)),
  _Shot('g09_06_kaynak', (b, s) => _opener((c) => showPhotoSourceSheet(c, removable: true, error: 'Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin.')), act: (t, b) async {
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }),
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
  _lang = Platform.environment['K4_LANG'] ?? 'tr';
  final only = (Platform.environment['K4_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K4_MODES'] ?? 'light').split(',');
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
      testWidgets('k4 yeni $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        fakePosts(b);
        shot.setup?.call(b);
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(b, session), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
        });
        await settle(tester, const Duration(milliseconds: 700));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 150));
        if (shot.act != null) await shot.act!(tester, b);
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
        await tester.pump(const Duration(seconds: 8));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
