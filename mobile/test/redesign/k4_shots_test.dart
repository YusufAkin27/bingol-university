@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// UI-K4 ekran goruntuleri: referans grup 17 (gonderi karti ve begeni), 6 ekran.
///
/// Varsayilan `flutter test` ile CALISMAZ. Uretim (C:\bu_mobile icinde):
///   STORE_SHOTS_OUT='C:/.../redesign/k4/uygulama' flutter test test/redesign/k4_shots_test.dart
/// Istege bagli: `K4_LANG=tr|en|ar`, `K4_ONLY=01,05`, `K4_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';

class _Shot {
  const _Shot(this.file, {this.mine = false, this.liked = false, this.count = 127, this.edited = false, this.act, this.failLike = false, this.skeleton = false, this.height = 844});
  final String file;
  final bool mine;
  final bool liked;
  final int count;
  final bool edited;
  final Future<void> Function(WidgetTester t)? act;
  final bool failLike;
  final bool skeleton;
  final double height;
}

Future<void> _tapHeart(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('like-heart')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 160));
}

Future<void> _doubleTapPhoto(WidgetTester t) async {
  final f = find.byKey(const ValueKey('post-photo-1000'));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 40));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _undoWithError(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('like-heart')));
  await t.pump(const Duration(milliseconds: 400)); // iyimser guncelleme + istek (hata) + geri alma
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

final _shots = <_Shot>[
  const _Shot('01_begenilmemis'),
  const _Shot('02_begeni_an', count: 127, act: _tapHeart),
  const _Shot('03_cift_dokunma', count: 127, act: _doubleTapPhoto),
  const _Shot('04_geri_al_hata', count: 127, failLike: true, act: _undoWithError),
  const _Shot('05_kendi_gonderim', mine: true, liked: true, count: 129, edited: true),
  const _Shot('06_baskasi_iskelet', liked: true, count: 128, skeleton: true, height: 1269),
  const _Shot('07_uzun_metin'),
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

Widget _page(_Shot shot, Session s) => Builder(builder: (context) {
      final json = samplePost(
        id: 1000,
        media: [samplePostMedia(id: 7)],
        text: shot.file == '07_uzun_metin' ? 'Bahar geldi kampüse hepimize merhaba' : 'Bahar geldi kampüse',
        liked: shot.liked,
        likeCount: shot.count,
        mine: shot.mine,
        authorId: shot.mine ? 1 : 12,
        authorName: shot.mine ? 'Elif Yıldız' : 'Mehmet Kaya',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
      );
      (json['author'] as Map)['department'] = shot.mine ? 'Bilgisayar Mühendisliği' : 'Makine Mühendisliği';
      if (shot.edited) json['editedAt'] = DateTime.now().toUtc().toIso8601String();
      final post = Post.fromJson(json);
      return Scaffold(
        backgroundColor: context.bu.bg,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
          child: Column(children: [
            PostCard(session: s, post: post, onChanged: (_) {}, onDeleted: (_) {}),
            if (shot.skeleton) ...[const SizedBox(height: 20), const PostCardSkeleton()],
          ]),
        ),
      );
    });

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
      testWidgets('k4 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, shot.height * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        if (!shot.failLike) fakePosts(b);
        if (shot.failLike) b.network('/posts/1000/like');
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(_page(shot, session), v.$2, key, v.$3));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        if (shot.act != null) await shot.act!(tester);
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
        await tester.pump(const Duration(seconds: 6));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
