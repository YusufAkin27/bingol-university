import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/video_service.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'media_pick.dart';
import 'sohbety_widgets.dart';

/// Kamerayı açıp bir öğe (fotoğraf ya da video) döndüren işlev; testlerde sahtesi verilir.
typedef MediaCameraLauncher = Future<MediaPick?> Function(BuildContext context);

Future<MediaPick?> openMediaCamera(BuildContext context) => Navigator.push<MediaPick>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const MediaCameraPage()),
    );

/// Uygulama içi sade kamera: dokununca fotoğraf, basılı tutunca video (en çok 60 sn, yalnız süre sayacı).
/// Kullanıcı kararı 2026-10-30: odak çerçevesi/ipucu/galeri küçük resmi yok; dokunarak odak ve iki parmakla
/// yakınlaştırma sessiz çalışır (ekranda gösterge çizilmez).
class MediaCameraPage extends StatefulWidget {
  const MediaCameraPage({super.key});

  @override
  State<MediaCameraPage> createState() => _MediaCameraPageState();
}

class _MediaCameraPageState extends State<MediaCameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cams = const [];
  CameraController? _ctl;
  int _cam = 0;
  bool _audio = true;
  bool _ready = false;
  bool _denied = false;
  bool _recording = false;
  bool _busy = false;
  SohbetyFlashMode _flash = SohbetyFlashMode.off;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1, _zoomBase = 1;
  int _secs = 0;
  Timer? _tick;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _ctl?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final cam = await ensurePermission(context, AppPermission.camera,
        rationale: context.l10n.chatMiscCameraRationale);
    if (!mounted) return;
    if (!cam) {
      setState(() => _denied = true);
      return;
    }
    // Mikrofon reddedilirse yalnız sessiz video çekilemez; fotoğraf yine çalışır.
    _audio = await ensurePermission(context, AppPermission.microphone,
        rationale: context.l10n.chatMiscMicRationale);
    if (!mounted) return;
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) throw StateError('no camera');
      _cam = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_cam < 0) _cam = 0;
      await _start();
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  Future<void> _start() async {
    final old = _ctl;
    final c = CameraController(_cams[_cam], ResolutionPreset.high, enableAudio: _audio);
    _ctl = c;
    setState(() => _ready = false);
    await old?.dispose();
    await c.initialize();
    if (!mounted) return;
    try {
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = await c.getMaxZoomLevel();
    } catch (_) {
      _minZoom = _maxZoom = 1;
    }
    _zoom = _minZoom;
    await _applyFlash(c);
    if (!mounted) return;
    setState(() => _ready = true);
  }

  /// Ön kamerada flaş donanımı yoktur: düğme gizlenir.
  bool get _hasFlash => _cams.isNotEmpty && _cams[_cam].lensDirection != CameraLensDirection.front;

  Future<void> _applyFlash(CameraController c, {bool video = false}) async {
    if (!_hasFlash) return;
    final mode = switch (_flash) {
      SohbetyFlashMode.off => FlashMode.off,
      // Videoda çekim flaşı olmaz: yalnız "açık" fener olarak yanar.
      SohbetyFlashMode.auto => video ? FlashMode.off : FlashMode.auto,
      SohbetyFlashMode.on => video ? FlashMode.torch : FlashMode.always,
    };
    try {
      await c.setFlashMode(mode);
    } catch (_) {}
  }

  /// Flaş: kapalı -> otomatik -> açık -> kapalı (tek dokunuş).
  Future<void> _toggleFlash() async {
    final c = _ctl;
    if (c == null || !_ready || _recording) return;
    setState(() => _flash = SohbetyFlashMode.values[(_flash.index + 1) % SohbetyFlashMode.values.length]);
    await _applyFlash(c);
  }

  /// Dokunarak odak: sessiz, yalnız sistem odağı (ekrana işaret çizilmez).
  Future<void> _focusAt(TapUpDetails d, Size size) async {
    final c = _ctl;
    if (c == null || !_ready || size.isEmpty) return;
    final p = Offset((d.localPosition.dx / size.width).clamp(0.0, 1.0), (d.localPosition.dy / size.height).clamp(0.0, 1.0));
    try {
      await c.setFocusPoint(p);
      await c.setExposurePoint(p);
    } catch (_) {}
  }

  void _zoomUpdate(ScaleUpdateDetails d) {
    final c = _ctl;
    if (c == null || !_ready || d.pointerCount < 2 || _maxZoom <= _minZoom) return;
    final z = (_zoomBase * d.scale).clamp(_minZoom, _maxZoom);
    if ((z - _zoom).abs() < .02) return;
    _zoom = z;
    c.setZoomLevel(z).catchError((_) {});
  }

  Future<void> _flip() async {
    if (_cams.length < 2 || _recording || _busy) return;
    _cam = (_cam + 1) % _cams.length;
    try {
      await _start();
    } catch (_) {}
  }

  Future<void> _photo() async {
    final c = _ctl;
    if (c == null || !_ready || _busy || _recording) return;
    _busy = true;
    try {
      final f = await c.takePicture();
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      Navigator.pop(
        context,
        MediaPick(
          key: 'cam_photo_${DateTime.now().microsecondsSinceEpoch}_${_n++}',
          isVideo: false,
          thumb: (_) async => bytes,
          imageBytes: () async => bytes,
        ),
      );
    } catch (_) {
      _busy = false;
      if (mounted) BuToast.show(context, context.l10n.chatMiscPhotoFailed, kind: BuToastKind.error);
    }
  }

  Future<void> _startVideo() async {
    final c = _ctl;
    if (c == null || !_ready || _busy || _recording) return;
    try {
      await _applyFlash(c, video: true);
      await c.startVideoRecording();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _secs = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs++);
      if (_secs >= VideoService.maxDurationMs ~/ 1000) _stopVideo();
    });
  }

  Future<void> _stopVideo() async {
    final c = _ctl;
    if (c == null || !_recording || _busy) return;
    _busy = true;
    _tick?.cancel();
    final secs = _secs;
    try {
      final f = await c.stopVideoRecording();
      _applyFlash(c);
      if (!mounted) return;
      final path = f.path;
      Uint8List? poster;
      Future<Uint8List?> loadPoster(int _) async =>
          poster ??= await PlatformVideoCompressor().poster(path);
      Navigator.pop(
        context,
        MediaPick(
          key: 'cam_video_${DateTime.now().microsecondsSinceEpoch}_${_n++}',
          isVideo: true,
          durationMs: secs * 1000,
          thumb: loadPoster,
          videoPath: () async => path,
        ),
      );
    } catch (_) {
      _busy = false;
      if (mounted) {
        setState(() => _recording = false);
        BuToast.show(context, context.l10n.chatMiscVideoSaveFailed, kind: BuToastKind.error);
      }
    }
  }

  /// Görüntüyü ekranı dolduracak biçimde (kırparak) çizer: tasarımda tam ekran vizör.
  Widget _cover(BuildContext context, CameraController c) {
    final size = MediaQuery.sizeOf(context);
    final pa = 1 / c.value.aspectRatio;
    final sa = size.width / size.height;
    final scale = pa > sa ? pa / sa : sa / pa;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: AspectRatio(aspectRatio: pa, child: CameraPreview(c))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: _denied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const BuIllustrationView(BuIllustration.lock, size: 112),
                      BuGap.h16,
                      Text(l.chatMiscCameraUnavailable,
                          textAlign: TextAlign.center,
                          style: tx.bodyLarge!.copyWith(color: t.onMedia.withValues(alpha: .85))),
                      BuGap.h24,
                      BuButton(
                          label: l.chatMiscClose,
                          kind: BuButtonKind.soft,
                          compact: true,
                          onPressed: () => Navigator.pop(context)),
                    ]),
                  ),
                )
              : (_ready && c != null)
                  ? LayoutBuilder(
                      builder: (_, box) => GestureDetector(
                        key: const ValueKey('cameraPreview'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _focusAt(d, box.biggest),
                        onScaleStart: (_) => _zoomBase = _zoom,
                        onScaleUpdate: _zoomUpdate,
                        child: _cover(context, c),
                      ),
                    )
                  : Center(
                      child: ExcludeSemantics(
                        child: Icon(LucideIcons.camera, size: 44, color: t.onMedia.withValues(alpha: .35)),
                      ),
                    ),
        ),
        if (!_denied)
          Positioned.fill(
            child: SohbetyCameraChrome(
              recording: _recording,
              timer: formatMediaDuration(_secs * 1000),
              progress: _secs * 1000 / VideoService.maxDurationMs,
              flash: _flash,
              showFlash: _hasFlash,
              canFlip: _cams.length > 1,
              onClose: () => Navigator.pop(context),
              onFlash: _toggleFlash,
              onFlip: _flip,
              onPhoto: _photo,
              onVideoStart: _startVideo,
              onVideoEnd: _stopVideo,
              closeLabel: l.chatMiscClose,
              flashLabel: l.sohbetyFlash,
              flipLabel: l.chatMiscFlipCamera,
              shutterLabel: _recording ? l.sohbetyStopRec : l.sohbetyTakePhoto,
            ),
          ),
      ]),
    );
  }
}
