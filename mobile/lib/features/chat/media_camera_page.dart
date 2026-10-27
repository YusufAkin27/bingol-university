import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/video_service.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media.dart';
import 'media_pick.dart';

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
        rationale: 'Fotoğraf ve video çekebilmeniz için kameraya erişmemiz gerekir.');
    if (!mounted) return;
    if (!cam) {
      setState(() => _denied = true);
      return;
    }
    // Mikrofon reddedilirse yalnız sessiz video çekilemez; fotoğraf yine çalışır.
    _audio = await ensurePermission(context, AppPermission.microphone,
        rationale: 'Video kaydederken sesi de alabilmemiz için mikrofona erişmemiz gerekir.');
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
    setState(() => _ready = true);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf çekilemedi.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video kaydedilemedi.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: _denied
                ? Center(
                    child: Text('Kamera kullanılamıyor.', style: BuType.body.copyWith(color: Colors.white70)),
                  )
                : (_ready && c != null)
                    ? Center(
                        child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c)),
                      )
                    : const Center(child: CircularProgressIndicator()),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: IconButton(
              tooltip: 'Kapat',
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_recording)
            PositionedDirectional(
              top: 18,
              start: 0,
              end: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                  child: Text(formatMediaDuration(_secs * 1000),
                      style: BuType.bodyStrong.copyWith(color: Colors.white)),
                ),
              ),
            ),
          PositionedDirectional(
            bottom: 24,
            start: 0,
            end: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Dokun: fotoğraf · Basılı tut: video',
                  style: BuType.caption.copyWith(color: Colors.white70)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 56),
                const SizedBox(width: 28),
                GestureDetector(
                  key: const ValueKey('shutter'),
                  onTap: _photo,
                  onLongPressStart: (_) => _startVideo(),
                  onLongPressEnd: (_) => _stopVideo(),
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                    child: Container(
                      decoration: BoxDecoration(
                          color: _recording ? Colors.red : Colors.white,
                          borderRadius: BorderRadius.circular(_recording ? 12 : 40)),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                SizedBox(
                  width: 56,
                  child: IconButton(
                    tooltip: 'Kamerayı çevir',
                    icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
                    onPressed: _flip,
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
