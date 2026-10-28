import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/video_service.dart';
import '../../core/typography.dart';
import 'chat_media.dart';
import 'media_pick.dart';
import 'sohbety_widgets.dart';

/// Kamerayı açıp bir öğe (fotoğraf ya da video) döndüren işlev; testlerde sahtesi verilir.
typedef MediaCameraLauncher = Future<MediaPick?> Function(BuildContext context);

Future<MediaPick?> openMediaCamera(BuildContext context) => Navigator.push<MediaPick>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const MediaCameraPage()),
    );

/// Uygulama içi kamera: dokununca fotoğraf, basılı tutunca video (en çok 60 sn, sayaçlı).
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
  bool _flash = false;
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
    if (_flash) {
      try {
        await c.setFlashMode(FlashMode.torch);
      } catch (_) {}
    }
    setState(() => _ready = true);
  }

  /// Flaş: kapalı <-> sürekli (fener; fotoğrafta da videoda da yanar).
  Future<void> _toggleFlash() async {
    final c = _ctl;
    if (c == null || !_ready) return;
    final next = !_flash;
    try {
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flash = next);
    } catch (_) {}
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.chatMiscPhotoFailed)));
    }
  }

  Future<void> _startVideo() async {
    final c = _ctl;
    if (c == null || !_ready || _busy || _recording) return;
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.chatMiscVideoSaveFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1220),
      body: Stack(children: [
        // Önizleme gelene kadar tasarımdaki koyu radyal zemin.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.16),
                radius: .85,
                colors: [Color(0xFF2A3250), Color(0xFF0E1220)],
                stops: [0, .7],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: _denied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(l.chatMiscCameraUnavailable,
                        textAlign: TextAlign.center,
                        style: BuType.body.copyWith(color: Colors.white70)),
                  ),
                )
              : (_ready && c != null)
                  ? Center(
                      child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c)),
                    )
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        Positioned.fill(
          child: SohbetyCameraChrome(
            recording: _recording,
            timer: formatMediaDuration(_secs * 1000),
            flashOn: _flash,
            onClose: () => Navigator.pop(context),
            onFlash: _toggleFlash,
            // Galeri: kamerayı kapatıp seçiciye (galeriye) döner.
            onGallery: () => Navigator.pop(context),
            onFlip: _flip,
            onPhoto: _photo,
            onVideoStart: _startVideo,
            onVideoEnd: _stopVideo,
            closeLabel: l.chatMiscClose,
            flashLabel: l.sohbetyFlash,
            galleryLabel: l.chatMiscGallery,
            flipLabel: l.chatMiscFlipCamera,
            shutterLabel: _recording ? l.sohbetyStopRec : l.sohbetyTakePhoto,
            hint: l.chatMiscCameraHint,
          ),
        ),
      ]),
    );
  }
}
