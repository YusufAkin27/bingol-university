@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/features/chat/media_preview_page.dart';
import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p10_images.dart';

/// N2 (Paket 10) ekran goruntuleri: Stitch 25 (medya secici, izin durumlari, album, onizleme, kamera, video hazirlama).
/// Varsayilan `flutter test`te ATLANIR. Uretim (C:\bu_mobile icinde):
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/n2/uygulama' flutter test test/redesign/p10_shots_test.dart
/// Istege bagli: P10_LANG=tr|en|ar, P10_MODES=light,dark,x13, P10_ONLY=01,03
const _dpr = 2.5;
String _lang = 'tr';

/// Ekran goruntusu galerisi: 0 = durum; her oge farkli gradyan kare; 3., 6., 11. oge video.
class _ShotLibrary implements MediaLibrary {
  _ShotLibrary({this.access = LibraryAccess.full});
  final LibraryAccess access;

  static const _video = {3: 23000, 6: 45000, 11: 12000};

  @override
  Future<LibraryAccess> requestAccess() async => access;

  @override
  Future<List<GalleryAlbum>> albums() async => const [
        GalleryAlbum(id: 'all', name: 'Recent', count: 1428, isAll: true),
        GalleryAlbum(id: 'cam', name: 'Camera', count: 312),
        GalleryAlbum(id: 'shot', name: 'Screenshots', count: 84),
        GalleryAlbum(id: 'dl', name: 'Download', count: 56),
      ];

  @override
  Future<List<GalleryItem>> items(String? albumId, {required int page, required int size}) async {
    if (page > 0) return const [];
    final base = switch (albumId) { 'cam' => 20, 'shot' => 40, 'dl' => 60, _ => 0 };
    return [
      for (var i = 1; i <= 17; i++)
        GalleryItem(id: 'p${base + i}', isVideo: _video.containsKey(i), durationMs: _video[i] ?? 0),
    ];
  }

  int _n(GalleryItem g) => int.parse(g.id.substring(1));

  @override
  Future<Uint8List?> thumb(GalleryItem item, int size) async => p10Photo(_n(item));

  @override
  Future<Uint8List?> imageBytes(GalleryItem item) async => p10Photo(_n(item), w: 480, h: 600);

  @override
  Future<String?> videoPath(GalleryItem item) async => '/x.mp4';

  @override
  Future<void> manageLimited() async {}

  @override
  Future<void> openSettings() async {}
}

MediaPick _pick(int i, {bool video = false}) => MediaPick(
      key: 'p$i',
      isVideo: video,
      durationMs: video ? 18000 : 0,
      thumb: (s) async => p10Photo(i),
      imageBytes: video ? null : () async => p10Photo(i, w: 480, h: 600),
      videoPath: video ? () async => '/x.mp4' : null,
    );

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

class _Board {
  const _Board(this.file, this.build, {this.after});
  final String file;
  final Widget Function() build;
  final Future<void> Function(WidgetTester t)? after;
}

/// Gorsel cozumleme gercek zaman ister: kisa gercek bekleme + kare.
Future<void> _settleImg(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await settle(t, const Duration(milliseconds: 300));
  }
}

Future<void> _tapKey(WidgetTester t, String k) async {
  await t.tap(find.byKey(ValueKey(k)));
  await t.pump();
}

Widget _picker([LibraryAccess access = LibraryAccess.full]) => MediaPickerPage(
      library: _ShotLibrary(access: access),
      ensureAccess: (c, p, {rationale}) async => access != LibraryAccess.denied,
      openCamera: (c) async => null,
    );

Future<void> _select(WidgetTester t, List<int> ids) async {
  for (final i in ids) {
    await _tapKey(t, 'galleryTile_p$i');
  }
}

Widget _cameraChrome(BuildContext c, bool rec, {SohbetyFlashMode flash = SohbetyFlashMode.off}) => Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Image.memory(p10Photo(2, w: 360, h: 640), fit: BoxFit.cover)),
        Positioned.fill(
          child: SohbetyCameraChrome(
            recording: rec,
            timer: '0:12',
            progress: .2,
            flash: flash,
            onClose: () {},
            onFlash: () {},
            onFlip: () {},
            onPhoto: () {},
            onVideoStart: () {},
            onVideoEnd: () {},
            closeLabel: c.l10n.chatMiscClose,
            flashLabel: c.l10n.sohbetyFlash,
            flipLabel: c.l10n.chatMiscFlipCamera,
            shutterLabel: rec ? c.l10n.sohbetyStopRec : c.l10n.sohbetyTakePhoto,
          ),
        ),
      ]),
    );

/// Video hazirlama penceresi + alttaki bildirim kartlari (Stitch 25-6).
Widget _videoBoard() => Builder(builder: (c) {
      final l = c.l10n;
      final t = c.bu;
      return Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          Expanded(
            child: Container(
              color: t.nav,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SohbetyVideoPrepareCard(
                title: l.chatDetailVideoPreparing('45'),
                subtitle: l.p10VideoPrepareSub,
                cancelLabel: l.chatDetailCancel,
                progress: .45,
                onCancel: () {},
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SohbetyNoticeCard(message: l.chatDetailVideoTooLong, kind: SohbetyNoticeKind.warning, onClose: () {}),
                const SizedBox(height: 8),
                SohbetyNoticeCard(message: l.chatDetailVideoTooLarge, kind: SohbetyNoticeKind.error, onClose: () {}),
                const SizedBox(height: 8),
                SohbetyNoticeCard(message: l.chatDetailVideosSplit, kind: SohbetyNoticeKind.info, onClose: () {}),
              ]),
            ),
          ),
        ]),
      );
    });

final _boards = <_Board>[
  _Board('01_galeri_secici', _picker, after: (t) => _select(t, [1, 2, 3])),
  _Board('01b_galeri_bos_secim', _picker),
  _Board('02_galeri_sinirli', () => _picker(LibraryAccess.limited)),
  _Board('02b_galeri_izin_yok', () => _picker(LibraryAccess.denied)),
  _Board('03_album', _picker, after: (t) async {
    await _tapKey(t, 'albumButton');
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Board('04_onizleme', () => MediaPreviewPage(picks: [for (var i = 1; i <= 3; i++) _pick(i)]), after: (t) async {
    await _tapKey(t, 'onceButton_0');
  }),
  _Board('04b_onizleme_video', () => MediaPreviewPage(picks: [_pick(2), _pick(3, video: true), _pick(5)]), after: (t) async {
    await _tapKey(t, 'previewThumb_1');
  }),
  _Board('05_kamera', () => Builder(builder: (c) => _cameraChrome(c, false))),
  _Board('05b_kamera_kayit', () => Builder(builder: (c) => _cameraChrome(c, true))),
  _Board('05c_kamera_flas_otomatik', () => Builder(builder: (c) => _cameraChrome(c, false, flash: SohbetyFlashMode.auto))),
  _Board('05d_kamera_flas_acik', () => Builder(builder: (c) => _cameraChrome(c, false, flash: SohbetyFlashMode.on))),
  _Board('05e_kamera_izin_yok', () => const MediaCameraPage()),
  _Board('06_video_hazirlama', _videoBoard),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['P10_LANG'] ?? 'tr';
  final only = (Platform.environment['P10_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P10_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() async {
    await _loadFonts(_lang == 'ar');
    // 05e: gercek kamera sayfasi; izinler verili, kamera yok -> "kullanilamiyor" karti.
    PermissionService.instance = FakePermissionService(
        initial: {AppPermission.camera: PermState.granted, AppPermission.microphone: PermState.granted});
  });

  for (final v in variants) {
    for (final b in _boards) {
      if (only.isNotEmpty && !only.any((o) => b.file.startsWith(o))) continue;
      final name = '${b.file}${v.$1}_$_lang';
      testWidgets('p10 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.pumpWidget(_app(b.build(), v.$2, key, v.$3));
        await _settleImg(tester);
        if (b.after != null) {
          await b.after!(tester);
          await _settleImg(tester);
        }
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
