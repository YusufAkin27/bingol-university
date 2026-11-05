import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/features/chat/camera_quality.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'support/fake_app.dart';

CameraDescription _cam(String name, CameraLensDirection dir,
        {CameraLensType type = CameraLensType.unknown}) =>
    CameraDescription(name: name, lensDirection: dir, sensorOrientation: 90, lensType: type);

/// Platform kanalı kullanmayan sahte kamera: kurulum ayarlarını ve çağrıları kaydeder.
class _FakeCamera extends CameraPlatform with MockPlatformInterfaceMixin {
  _FakeCamera(this.cams, {this.preview = const Size(4000, 3000), this.maxZoom = 5});

  final List<CameraDescription> cams;
  final Size preview;
  final double maxZoom;

  final created = <(CameraDescription, MediaSettings)>[];
  final zooms = <double>[];
  final focusPoints = <Point<double>?>[];
  int pictures = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => cams;

  @override
  Future<int> createCameraWithSettings(CameraDescription d, MediaSettings s) async {
    created.add((d, s));
    return created.length;
  }

  @override
  Future<void> initializeCamera(int id, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(CameraInitializedEvent(
      id, preview.width, preview.height, ExposureMode.auto, true, FocusMode.auto, true));

  @override
  Stream<CameraErrorEvent> onCameraError(int id) => StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  Future<double> getMinZoomLevel(int id) async => 1;

  @override
  Future<double> getMaxZoomLevel(int id) async => maxZoom;

  @override
  Future<void> setZoomLevel(int id, double zoom) async => zooms.add(zoom);

  @override
  Future<void> setFlashMode(int id, FlashMode mode) async {}

  @override
  Future<void> setFocusMode(int id, FocusMode mode) async {}

  @override
  Future<void> setExposureMode(int id, ExposureMode mode) async {}

  @override
  Future<void> setFocusPoint(int id, Point<double>? p) async => focusPoints.add(p);

  @override
  Future<void> setExposurePoint(int id, Point<double>? p) async {}

  @override
  Future<XFile> takePicture(int id) async {
    pictures++;
    return XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'p.jpg');
  }

  @override
  Widget buildPreview(int id) => const ColoredBox(color: Color(0xFF123456));

  @override
  Future<void> dispose(int id) async {}
}

Future<_FakeCamera> _open(WidgetTester tester, _FakeCamera cam, List<Object?> result,
    {Size size = kPhoneMedium}) async {
  CameraPlatform.instance = cam;
  PermissionService.instance = FakePermissionService(
      initial: {AppPermission.camera: PermState.granted, AppPermission.microphone: PermState.granted});
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result.add(await openMediaCamera(c)),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
    size: size,
  ));
  await tester.tap(find.text('aç'));
  await settle(tester, const Duration(milliseconds: 800));
  return cam;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final prevPerm = PermissionService.instance;
  final prevCam = CameraPlatform.instance;

  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  tearDown(() {
    PermissionService.instance = prevPerm;
    CameraPlatform.instance = prevCam;
  });

  group('CameraQuality (saf mantik)', () {
    test('fotograf onayari en yuksek cozunurluk; video bit hizi sinirli', () {
      expect(CameraQuality.photoPreset, ResolutionPreset.max);
      final c = CameraQuality.controllerFor(_cam('0', CameraLensDirection.back), audio: true);
      expect(c.resolutionPreset, ResolutionPreset.max);
      expect(c.mediaSettings.enableAudio, isTrue);
      expect(c.mediaSettings.videoBitrate, CameraQuality.videoBitrate);
      expect(c.mediaSettings.fps, 30);
      expect(CameraQuality.controllerFor(_cam('0', CameraLensDirection.back), audio: false).enableAudio, isFalse);
    });

    test('ana arka kamera: lensType wide tercih edilir, ultraWide/telefoto elenir', () {
      final cams = [
        _cam('3', CameraLensDirection.back, type: CameraLensType.ultraWide),
        _cam('2', CameraLensDirection.back, type: CameraLensType.telephoto),
        _cam('1', CameraLensDirection.front, type: CameraLensType.wide),
        _cam('0', CameraLensDirection.back, type: CameraLensType.wide),
      ];
      expect(CameraQuality.mainBackIndex(cams), 3);
    });

    test('lensType bilinmiyorsa (Android) en kucuk kamera kimligi', () {
      final cams = [
        _cam('4', CameraLensDirection.back),
        _cam('1', CameraLensDirection.front),
        _cam('2', CameraLensDirection.back),
        _cam('0', CameraLensDirection.back),
      ];
      expect(CameraQuality.mainBackIndex(cams), 3);
    });

    test('yalniz ultraWide + front varsa ultraWide, arka yoksa 0', () {
      expect(
          CameraQuality.mainBackIndex([
            _cam('1', CameraLensDirection.front),
            _cam('0', CameraLensDirection.back, type: CameraLensType.ultraWide),
          ]),
          1);
      expect(CameraQuality.mainBackIndex([_cam('1', CameraLensDirection.front)]), 0);
      expect(CameraQuality.mainBackIndex(const []), 0);
    });

    test('cevirme: on <-> ana arka; telefoto/ultraWide dolasilmaz', () {
      final cams = [
        _cam('0', CameraLensDirection.back, type: CameraLensType.wide),
        _cam('1', CameraLensDirection.back, type: CameraLensType.ultraWide),
        _cam('2', CameraLensDirection.front),
      ];
      expect(CameraQuality.flipTarget(cams, 0), 2);
      expect(CameraQuality.flipTarget(cams, 2), 0);
      expect(CameraQuality.flipTarget(cams, 1), 2);
      expect(CameraQuality.flipTarget([cams.first], 0), 0);
    });

    test('onizleme kutusu: 4:3 ve 16:9 duzgun oranli, kirpma yok', () {
      const screen = Size(390, 844);
      final b43 = CameraQuality.previewBox(screen, 4 / 3);
      expect(b43.width, 390);
      expect(b43.height, closeTo(520, .01));
      expect(b43.width / b43.height, closeTo(3 / 4, 1e-6));
      final b169 = CameraQuality.previewBox(screen, 16 / 9);
      expect(b169.width / b169.height, closeTo(9 / 16, 1e-6));
      // Ekrandan buyuk olamaz.
      for (final b in [b43, b169]) {
        expect(b.width, lessThanOrEqualTo(screen.width + .001));
        expect(b.height, lessThanOrEqualTo(screen.height + .001));
      }
      // Cok uzun ekran degil, cok kisa ekran: yukseklik sinirlar.
      final wide = CameraQuality.previewBox(const Size(800, 400), 4 / 3);
      expect(wide.height, closeTo(400, .01));
      expect(wide.width, closeTo(300, .01));
    });

    test('yakinlastirma cihaz sinirlarina kirpilir', () {
      expect(CameraQuality.zoomFor(1, 10, 1, 5), 5);
      expect(CameraQuality.zoomFor(2, .1, 1, 5), 1);
      expect(CameraQuality.zoomFor(1, 2, 1, 5), 2);
      expect(CameraQuality.zoomFor(1, 3, 1, 1), 1); // yakinlastirma yok
    });
  });

  group('MediaCameraPage (sahte CameraPlatform)', () {
    final cams = [
      _cam('2', CameraLensDirection.back),
      _cam('1', CameraLensDirection.front),
      _cam('0', CameraLensDirection.back),
    ];

    testWidgets('ana arka kamera, max cozunurluk ve video ayarlariyla acilir; onizleme 4:3 kirpilmaz', (tester) async {
      final cam = await _open(tester, _FakeCamera(cams), []);
      expect(cam.created, hasLength(1));
      final (d, s) = cam.created.first;
      expect(d.name, '0');
      expect(d.lensDirection, CameraLensDirection.back);
      expect(s.resolutionPreset, ResolutionPreset.max);
      expect(s.videoBitrate, CameraQuality.videoBitrate);
      expect(s.enableAudio, isTrue);
      final box = tester.getSize(find.byKey(const ValueKey('cameraPreviewBox')));
      expect(box.width / box.height, closeTo(3 / 4, .005)); // 4000x3000 sensor, dikey
      expect(box.width, lessThanOrEqualTo(kPhoneMedium.width + .01));
    });

    testWidgets('16:9 onizleme de kirpilmadan, oranini koruyarak cizilir', (tester) async {
      await _open(tester, _FakeCamera(cams, preview: const Size(1920, 1080)), []);
      final box = tester.getSize(find.byKey(const ValueKey('cameraPreviewBox')));
      expect(box.width / box.height, closeTo(9 / 16, .005));
    });

    testWidgets('cevirme on kameraya gider, geri donunce yine ana arka kamera', (tester) async {
      final cam = await _open(tester, _FakeCamera(cams), []);
      await tester.tap(find.byKey(const ValueKey('cameraFlip')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(cam.created.last.$1.lensDirection, CameraLensDirection.front);
      await tester.tap(find.byKey(const ValueKey('cameraFlip')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(cam.created.last.$1.name, '0');
      expect(cam.created, hasLength(3));
    });

    testWidgets('iki parmak yakinlastirma cihaz maksimumunu asmaz', (tester) async {
      final cam = await _open(tester, _FakeCamera(cams, maxZoom: 3), []);
      final c = tester.getCenter(find.byKey(const ValueKey('cameraPreview')));
      final g1 = await tester.startGesture(c - const Offset(10, 0), pointer: 1);
      final g2 = await tester.startGesture(c + const Offset(10, 0), pointer: 2);
      for (var i = 0; i < 12; i++) {
        await g1.moveBy(const Offset(-15, 0));
        await g2.moveBy(const Offset(15, 0));
        await tester.pump();
      }
      await g1.up();
      await g2.up();
      await tester.pump();
      expect(cam.zooms, isNotEmpty);
      expect(cam.zooms.every((z) => z >= 1 && z <= 3), isTrue);
      expect(cam.zooms.last, 3);
    });

    testWidgets('dokunarak odak onizleme kutusunun icinde normalize edilir', (tester) async {
      final cam = await _open(tester, _FakeCamera(cams), []);
      final r = tester.getRect(find.byKey(const ValueKey('cameraPreviewBox')));
      await tester.tapAt(r.center);
      await tester.pump();
      expect(cam.focusPoints.last!.x, closeTo(.5, .01));
      expect(cam.focusPoints.last!.y, closeTo(.5, .01));
      final n = cam.focusPoints.length;
      // Kutunun disi (ust siyah serit): odak istenmez.
      await tester.tapAt(Offset(r.center.dx, r.top / 2));
      await tester.pump();
      expect(cam.focusPoints.length, n);
    });

    testWidgets('deklansor fotografi tam baytla dondurur', (tester) async {
      final res = <Object?>[];
      final cam = await _open(tester, _FakeCamera(cams), res);
      await tester.tap(find.byKey(const ValueKey('shutter')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(cam.pictures, 1);
      final pick = res.single as MediaPick;
      expect(pick.isVideo, isFalse);
      expect(await pick.imageBytes!(), Uint8List.fromList([1, 2, 3]));
    });
  });

  group('ImageService kalite', () {
    Uint8List jpeg(int w, int h, {int quality = 95, int orientation = 1}) {
      final im = img.Image(width: w, height: h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          im.setPixelRgb(x, y, (x * 7 + y * 3) & 255, (x * 3 + y * 11) & 255, (x ^ y) & 255);
        }
      }
      if (orientation != 1) im.exif.imageIfd.orientation = orientation;
      return Uint8List.fromList(img.encodeJpg(im, quality: quality));
    }

    test('sabitler: uzun kenar 2048, kalite 88', () {
      expect(ImageService.maxEdge, 2048);
      expect(ImageService.quality, 88);
      expect(ImageService.shrinkEdges.first, 2048);
      expect(ImageService.shrinkQualities.first, 88);
    });

    test('sinirin altindaki fotograf aynen korunur', () async {
      final b = jpeg(2400, 1800, quality: 60);
      final p = await ImageService().prepare(b, limit: b.length + 1);
      expect(identical(p.bytes, b) || p.bytes.length == b.length, isTrue);
    });

    test('shrink: sigarsa uzun kenar 2048 px ve yuksek kalitede kalir', () {
      final src = jpeg(3000, 2000, quality: 95);
      final out = ImageService.shrink(src, 6 * 1024 * 1024)!;
      final d = img.decodeJpg(out)!;
      expect(d.width, 2048);
      expect(d.height, closeTo(1365, 1));
    });

    test('shrink: kaynak 2048 den kucukse buyutmez', () {
      final out = ImageService.shrink(jpeg(1500, 1000), 6 * 1024 * 1024)!;
      final d = img.decodeJpg(out)!;
      expect(d.width, 1500);
      expect(d.height, 1000);
    });

    test('shrink: dikey fotografta UZUN kenar (yukseklik) sinirlanir', () {
      final out = ImageService.shrink(jpeg(2000, 3000), 6 * 1024 * 1024)!;
      final d = img.decodeJpg(out)!;
      expect(d.height, 2048);
      expect(d.width, closeTo(1365, 1));
    });

    test('shrink: sinir daralinca once kalite, sonra boyut dusurulur ama sinir tutulur', () {
      final src = jpeg(3000, 2000);
      final big = ImageService.shrink(src, 10 * 1024 * 1024)!;
      final limit = (big.length * .4).round();
      final out = ImageService.shrink(src, limit)!;
      expect(out.length, lessThanOrEqualTo(limit));
      expect(out.length, lessThan(big.length));
    });

    test('shrink: EXIF yonu piksellere islenir (yan cikmaz)', () {
      // 3000x2000 kayit, EXIF yonu 6 (90 derece): gorunen boyut 2000x3000 olmali.
      final src = jpeg(3000, 2000, orientation: 6);
      final out = ImageService.shrink(src, 6 * 1024 * 1024)!;
      final d = img.decodeJpg(out)!;
      expect(d.height, greaterThan(d.width));
      expect(d.height, 2048);
      expect(d.exif.imageIfd.hasOrientation, isFalse);
    });

    test('shrink: bozuk bayt null', () {
      expect(ImageService.shrink(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 0]), 1000), isNull);
    });

    test('sohbet siniri 4 MB (sunucu 5 MB), varsayilan 3 MB', () {
      expect(ImageService.chatLimit, 4 * 1024 * 1024);
      expect(ImageService.defaultLimit, 3 * 1024 * 1024);
      expect(ImageService.chatLimit, lessThan(5 * 1024 * 1024));
    });
  });
}
