import 'dart:typed_data';

import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_gallery_picker_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

class _FakeUploader extends PostMediaUploader {
  _FakeUploader(super.session);

  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

class _Comp implements VideoCompressor {
  @override
  Future<VideoInfo?> info(String path) async => VideoInfo(path: path, sizeBytes: 3 * 1024 * 1024, durationMs: 12000, width: 720, height: 1280);

  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async => null;

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => Uint8List.fromList(kFakePng);

  @override
  Future<void> cancel() async {}
}

/// Sayfayı bir düğmeyle açan ana sayfa; sonuç [result]'a yazılır.
Widget _host(Widget Function() page, List<Object?> result) => Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result.add(await Navigator.push<Object?>(c, MaterialPageRoute(builder: (_) => page()))),
            child: const Text('aç'),
          ),
        ),
      ),
    );

PostGalleryPickerPage _picker(
  dynamic session,
  MediaLibrary lib, {
  bool allow = true,
  MediaCameraLauncher? camera,
  SystemMediaPicker? system,
  List<(Uint8List?, String?)>? opened,
  bool realCompose = false,
  List<Object?>? calls,
}) =>
    PostGalleryPickerPage(
      session: session,
      library: lib,
      ensureAccess: (c, p, {rationale}) async => allow,
      openCamera: camera,
      systemPicker: system,
      composeBuilder: (photo, video) {
        opened?.add((photo, video));
        if (!realCompose) return Scaffold(body: Center(child: Text(photo != null ? 'FOTO' : 'VIDEO:$video', key: const ValueKey('composeStub'))));
        return ComposePostPage(
          session: session,
          initialPhoto: photo,
          initialVideoPath: video,
          uploader: _FakeUploader(session),
          cropPhoto: (c, b, spec) async => CropOutcome.cropped(b),
          videoService: VideoService(limitBytes: VideoService.postMaxBytes, compressor: _Comp()),
        );
      },
    );

Future<void> _open(WidgetTester tester, Widget Function() page, List<Object?> result,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, Widget Function(Widget)? wrap}) async {
  useScreen(tester, size);
  await tester.pumpWidget(wrap != null ? wrap(_host(page, result)) : buildApp(_host(page, result), brightness: b, size: size));
  await tester.tap(find.text('aç'));
  await settle(tester, const Duration(milliseconds: 500));
}

Finder _tile(String id) => find.byKey(ValueKey('postTile_$id'));

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

void main() {
  setUpAll(loadTestFonts);

  group('Galeri secici (Paylas +)', () {
    testWidgets('secenek sayfasi yok: ilk karo kamera, en yeni once, videoda sure rozeti, kapat + albume ad', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(5, videos: [FakeMediaLibrary.video('v1', ms: 15000)]);
      await _open(tester, () => _picker(makeSession(b), lib), []);
      expect(find.text('Fotoğraf paylaş'), findsNothing);
      expect(find.text('Video / Reels paylaş'), findsNothing);
      expect(find.byKey(const ValueKey('composeMenuPhoto')), findsNothing);
      expect(find.text('Son eklenenler'), findsOneWidget);
      expect(find.text('Yeni gönderi'), findsNothing); // başlık metni gizli (sayfa adı gizleme kuralı)
      expect(find.byKey(const ValueKey('postPickerClose')), findsOneWidget);
      final cam = tester.getRect(find.byKey(const ValueKey('postCameraTile')));
      final first = tester.getRect(_tile('v1'));
      final second = tester.getRect(_tile('p1'));
      expect(cam.left, lessThan(first.left)); // kamera ilk (sol üst)
      expect(cam.top, first.top);
      expect(cam.width, first.width);
      expect(first.left, lessThan(second.left));
      expect(first.left - cam.right, 2); // 2 dp aralık
      expect(find.descendant(of: _tile('v1'), matching: find.text('0:15')), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      _ok(tester);
    });

    testWidgets('dort sutun (390 dp) ve sayfalama: ilk sayfa 60, kaydirinca devami', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(150);
      await _open(tester, () => _picker(makeSession(b), lib), []);
      expect(lib.pagesRequested, [0]);
      final cam = tester.getRect(find.byKey(const ValueKey('postCameraTile')));
      final p1 = tester.getRect(_tile('p1'));
      final p3 = tester.getRect(_tile('p3'));
      final p4 = tester.getRect(_tile('p4'));
      expect(p1.top, cam.top);
      expect(p3.top, cam.top);
      expect(p4.top, greaterThan(cam.top)); // 4 sütun: kamera + 3 öğe ilk satır
      await tester.drag(find.byKey(const ValueKey('postGalleryGrid')), const Offset(0, -4000));
      await settle(tester, const Duration(milliseconds: 400));
      expect(lib.pagesRequested.contains(1), isTrue);
      _ok(tester);
    });

    testWidgets('dokun = ilerle: fotograf olusturucuya gecer (onay/onizleme yok); paylasilirsa Post doner', (tester) async {
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final lib = FakeMediaLibrary.photos(3);
      final opened = <(Uint8List?, String?)>[];
      final res = <Object?>[];
      await _open(tester, () => _picker(s, lib, opened: opened), res);
      await tester.tap(_tile('p2'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(opened, hasLength(1));
      expect(opened.single.$1, isNotNull);
      expect(opened.single.$2, isNull);
      expect(find.byKey(const ValueKey('composeStub')), findsOneWidget);
      // Olusturucudan Post ile donus: secici de kapanir ve Post'u iletir.
      Navigator.of(tester.element(find.byKey(const ValueKey('composeStub')))).pop(Post.fromJson({'id': 7, 'author': {'id': 1, 'displayName': 'Ayşe'}}));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsNothing);
      expect(res.single, isA<Post>());
      _ok(tester);
    });

    testWidgets('olusturucudan vazgecilirse izgara yerinde kalir', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(3);
      final res = <Object?>[];
      await _open(tester, () => _picker(makeSession(b), lib), res);
      await tester.tap(_tile('p1'));
      await settle(tester, const Duration(milliseconds: 500));
      Navigator.of(tester.element(find.byKey(const ValueKey('composeStub')))).pop();
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsOneWidget);
      expect(res, isEmpty);
      _ok(tester);
    });

    testWidgets('video karesine dokunmak video yoluyla olusturucuyu acar', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(2, videos: [FakeMediaLibrary.video('v1')]);
      final opened = <(Uint8List?, String?)>[];
      await _open(tester, () => _picker(makeSession(b), lib, opened: opened), []);
      await tester.tap(_tile('v1'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(opened.single.$1, isNull);
      expect(opened.single.$2, '/orig.mp4');
      expect(find.text('VIDEO:/orig.mp4'), findsOneWidget);
      _ok(tester);
    });

    testWidgets('kamera karosu: cekilen fotograf ayni akisa girer', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(2);
      final opened = <(Uint8List?, String?)>[];
      var cams = 0;
      await _open(tester, () => _picker(makeSession(b), lib, opened: opened, camera: (c) async {
            cams++;
            return fakePhotoPick('cam1');
          }), []);
      await tester.tap(find.byKey(const ValueKey('postCameraTile')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(cams, 1);
      expect(opened.single.$1, isNotNull);
      _ok(tester);
    });

    testWidgets('kamera karosu: cekilen video yolu olusturucuya gider; kameradan vazgecilirse bir sey olmaz', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(2);
      final opened = <(Uint8List?, String?)>[];
      var n = 0;
      await _open(tester, () => _picker(makeSession(b), lib, opened: opened, camera: (c) async => n++ == 0 ? null : fakeVideoPick('cv', ms: 9000)), []);
      await tester.tap(find.byKey(const ValueKey('postCameraTile')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened, isEmpty);
      await tester.tap(find.byKey(const ValueKey('postCameraTile')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(opened.single.$2, '/orig.mp4');
      _ok(tester);
    });

    testWidgets('bos galeri: kamera karosu kalir, bos durum metni gorunur', (tester) async {
      final b = FakeBackend();
      await _open(tester, () => _picker(makeSession(b), FakeMediaLibrary(const [])), []);
      expect(find.byKey(const ValueKey('postCameraTile')), findsOneWidget);
      expect(find.byKey(const ValueKey('postGalleryEmpty')), findsOneWidget);
      _ok(tester);
    });

    testWidgets('izin reddi: aciklama + Ayarlardan ac + sistem secicisi yedegi + kamera', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary.photos(2);
      final opened = <(Uint8List?, String?)>[];
      await _open(tester, () => _picker(makeSession(b), lib, allow: false, opened: opened, system: () async => fakePhotoPick('sys')), []);
      expect(find.byKey(const ValueKey('postGalleryDenied')), findsOneWidget);
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsNothing);
      expect(find.text('Galeriye erişim izni verilmedi.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('postGalleryOpenSettings')));
      await tester.pump();
      expect(lib.settingsOpened, 1);
      expect(find.byKey(const ValueKey('postPickerDeniedCamera')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('postPickerSystem')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(opened.single.$1, isNotNull); // sistem seçicisinden fotoğraf aynı akışa girdi
      _ok(tester);
    });

    testWidgets('sinirli erisim: bilgi seridi + Daha fazla sec', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary(
        [for (var i = 1; i <= 3; i++) GalleryItem(id: 'p$i', isVideo: false)],
        access: LibraryAccess.limited,
      );
      await _open(tester, () => _picker(makeSession(b), lib), []);
      expect(find.byKey(const ValueKey('postLimitedBanner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('postLimitedMore')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(lib.limitedOpened, 1);
      _ok(tester);
    });

    testWidgets('albumler: birden cok albumde baslik dokunulur, album listesi acilir', (tester) async {
      final b = FakeBackend();
      final lib = FakeMediaLibrary(
        [for (var i = 1; i <= 3; i++) GalleryItem(id: 'p$i', isVideo: false)],
        albumList: const [
          GalleryAlbum(id: 'all', name: 'Recent', count: 3, isAll: true),
          GalleryAlbum(id: 'cam', name: 'Camera', count: 2),
        ],
      );
      await _open(tester, () => _picker(makeSession(b), lib), []);
      await tester.tap(find.byKey(const ValueKey('postAlbumButton')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('albumList')), findsOneWidget);
      _ok(tester);
    });

    testWidgets('gercek olusturucu: secilen fotograf kirpma sonrasi onizlenir, Degistir galeriye doner', (tester) async {
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      await _open(tester, () => _picker(s, FakeMediaLibrary.photos(3), realCompose: true), []);
      await tester.tap(_tile('p1'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePicker')), findsNothing); // eski bos seçici ekranı yok
      await tester.tap(find.byKey(const ValueKey('composeChange')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('composePreview')), findsNothing);
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsOneWidget);
      _ok(tester);
    });

    testWidgets('gercek olusturucu: kirpmadan vazgecilirse galeriye donulur', (tester) async {
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      await _open(
          tester,
          () => PostGalleryPickerPage(
                session: s,
                library: FakeMediaLibrary.photos(2),
                ensureAccess: (c, p, {rationale}) async => true,
                composeBuilder: (photo, video) => ComposePostPage(session: s, initialPhoto: photo, cropPhoto: (c, b, spec) async => null),
              ),
          []);
      await tester.tap(_tile('p1'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsOneWidget);
      expect(find.byType(ComposePostPage), findsNothing);
      _ok(tester);
    });

    testWidgets('gercek olusturucu: galeriden video hazirlanir (kapak/paylas), Degistir galeriye doner', (tester) async {
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final lib = FakeMediaLibrary.photos(1, videos: [FakeMediaLibrary.video('v1')]);
      await _open(tester, () => _picker(s, lib, realCompose: true), []);
      await tester.tap(_tile('v1'));
      await settle(tester, const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePicker')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composeVideoChange')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('postGalleryGrid')), findsOneWidget);
      _ok(tester);
    });
  });

  group('Dil / olcek / tema', () {
    Widget app(Widget home, {Locale? locale, double scale = 1, Brightness b = Brightness.light, Size size = kPhoneMedium}) => MaterialApp(
          theme: BuTheme.light(),
          darkTheme: BuTheme.dark(),
          themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: home,
        );

    testWidgets('ar RTL: kamera karosu mantiksal basta (sag ust), Arapca metinler', (tester) async {
      final b = FakeBackend();
      final s = makeSession(b);
      final lib = FakeMediaLibrary.photos(5, videos: [FakeMediaLibrary.video('v1')]);
      await _open(tester, () => _picker(s, lib), [], wrap: (h) => app(h, locale: const Locale('ar')));
      final cam = tester.getRect(find.byKey(const ValueKey('postCameraTile')));
      final first = tester.getRect(_tile('v1'));
      expect(cam.right, greaterThan(first.right)); // RTL: ilk karo en sağda
      expect(cam.top, first.top);
      expect(find.text('الكاميرا'), findsOneWidget);
      _ok(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final dark in [false, true]) {
        testWidgets('${size.width.toInt()} dp, x1.3 yazi, ${dark ? 'koyu' : 'acik'}: tasma yok (izgara + reddedilmis + sinirli)', (tester) async {
          final b = FakeBackend();
          final s = makeSession(b);
          final br = dark ? Brightness.dark : Brightness.light;
          await _open(tester, () => _picker(s, FakeMediaLibrary.photos(8, videos: [FakeMediaLibrary.video('v1', ms: 3725000)])), [],
              size: size, wrap: (h) => app(h, scale: 1.3, b: br, size: size));
          expect(find.text('1:02:05'), findsOneWidget);
          _ok(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          final res = <Object?>[];
          await _open(tester, () => _picker(s, FakeMediaLibrary.photos(2), allow: false), res, size: size, wrap: (h) => app(h, scale: 1.3, b: br, size: size));
          expect(find.byKey(const ValueKey('postGalleryDenied')), findsOneWidget);
          _ok(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await _open(
              tester,
              () => _picker(s, FakeMediaLibrary([const GalleryItem(id: 'p1', isVideo: false)], access: LibraryAccess.limited)),
              [],
              size: size,
              wrap: (h) => app(h, scale: 1.3, b: br, size: size));
          expect(find.byKey(const ValueKey('postLimitedBanner')), findsOneWidget);
          _ok(tester);
        });
      }
    }
  });

  group('openComposePost', () {
    testWidgets('varsayilan: secenek sayfasi degil, galeri secici acilir; kind verilirse eski dogrudan yol', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Column(children: [
            TextButton(onPressed: () => openComposePost(c, s, library: FakeMediaLibrary.photos(2)), child: const Text('ac')),
            TextButton(onPressed: () => openComposePost(c, s, menu: false), child: const Text('bos')),
          ]),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostGalleryPickerPage), findsOneWidget);
      expect(find.text('Fotoğraf paylaş'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('postPickerClose')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostGalleryPickerPage), findsNothing);
      await tester.tap(find.text('bos'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostGalleryPickerPage), findsNothing);
      expect(find.byType(ComposePostPage), findsOneWidget);
      _ok(tester);
    });
  });
}
