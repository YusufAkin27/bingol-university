import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../core/session.dart';
import '../../core/typography.dart';
import '../chat/chat_media.dart' show formatMediaDuration;
import '../chat/chat_media_viewer.dart'
    show SaveImage, saveChatImageToGallery, saveChatVideoToGallery, chatVideoSaveErrorText;
import '../chat/chat_video_player.dart' show VideoControllerFactory;
import 'post_models.dart';
import 'video_autoplay.dart';

/// Tam ekran siyah galeriyi açar: yatay sayfalama, yakınlaştırma, video oynatıcı, aşağı sürükleyerek kapatma,
/// galeriye kaydetme (yalnız Android/iOS). Akıştaki otomatik oynatma galeri açıkken durur (rota görünmez olur).
Future<void> openPostMediaGallery(
  BuildContext context,
  Session session,
  List<PostMedia> media,
  int initialIndex, {
  SaveImage? saveImage,
  SaveImage? saveVideo,
  VideoControllerFactory? videoControllerFactory,
}) {
  if (media.isEmpty) return Future.value();
  // Akıştaki sessiz videoyu hemen durdur (rota geçişi bitmeden ses/CPU harcamasın).
  VideoAutoplayController.instance.suspend();
  return Navigator.of(context)
      .push<void>(PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, __, ___) => PostMediaGallery(
          session: session,
          media: media,
          initialIndex: initialIndex,
          saveImage: saveImage ?? saveChatImageToGallery,
          saveVideo: saveVideo ?? saveChatVideoToGallery,
          videoControllerFactory: videoControllerFactory,
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ))
      .whenComplete(VideoAutoplayController.instance.resume);
}

String _imageSaveError(Object e) {
  if (e is UnsupportedError) return 'Bu cihazda desteklenmiyor.';
  if (e is GalException) {
    return switch (e.type) {
      GalExceptionType.accessDenied => 'Galeri izni verilmedi.',
      GalExceptionType.notEnoughSpace => 'Cihazda yeterli alan yok.',
      _ => 'Görsel kaydedilemedi.',
    };
  }
  return 'Görsel kaydedilemedi.';
}

VideoPlayerController _networkController(Uri uri, Map<String, String> headers) =>
    VideoPlayerController.networkUrl(uri, httpHeaders: headers);

/// Galeri sayfası (testlerde doğrudan kurulabilir).
class PostMediaGallery extends StatefulWidget {
  const PostMediaGallery({
    super.key,
    required this.session,
    required this.media,
    this.initialIndex = 0,
    this.saveImage = saveChatImageToGallery,
    this.saveVideo = saveChatVideoToGallery,
    this.videoControllerFactory,
  });

  final Session session;
  final List<PostMedia> media;
  final int initialIndex;

  /// Testlerde platform kanalı yerine enjekte edilir.
  final SaveImage saveImage;
  final SaveImage saveVideo;
  final VideoControllerFactory? videoControllerFactory;

  @override
  State<PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<PostMediaGallery> {
  late final int _start = widget.initialIndex.clamp(0, widget.media.length - 1);
  late final PageController _pc = PageController(initialPage: _start);
  late int _index = _start;
  bool _bars = true;
  bool _zoomed = false;
  bool _saving = false;
  double _dy = 0;

  late final Map<String, String> _headers = postAuthHeaders(widget.session);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final item = widget.media[_index];
    setState(() => _saving = true);
    String msg;
    try {
      await (item.isVideo ? widget.saveVideo : widget.saveImage)(item.url, _headers);
      msg = 'Galeriye kaydedildi';
    } catch (e) {
      msg = item.isVideo ? chatVideoSaveErrorText(e) : _imageSaveError(e);
    }
    if (mounted) setState(() => _saving = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _dragEnd(DragEndDetails d) {
    if (_dy.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
      Navigator.maybePop(context);
    } else {
      setState(() => _dy = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final fade = (1 - (_dy.abs() / 400)).clamp(0.3, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _bars = !_bars),
            onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _dy += d.delta.dy),
            onVerticalDragEnd: _zoomed ? null : _dragEnd,
            onVerticalDragCancel: () => setState(() => _dy = 0),
            child: Transform.translate(
              offset: Offset(0, _dy),
              child: PageView.builder(
                key: const ValueKey('galleryPages'),
                controller: _pc,
                itemCount: widget.media.length,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (c, i) {
                  final m = widget.media[i];
                  return m.isVideo
                      ? _GalleryVideoPage(
                          key: ValueKey('galleryVideo${m.id}'),
                          media: m,
                          headers: _headers,
                          active: i == _index,
                          factory: widget.videoControllerFactory ?? _networkController,
                        )
                      : _ZoomPage(
                          key: ValueKey('galleryImage${m.id}'),
                          media: m,
                          headers: _headers,
                          onZoom: (z) {
                            if (z != _zoomed && i == _index) setState(() => _zoomed = z);
                          },
                        );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: !_bars,
            child: AnimatedOpacity(
              opacity: _bars ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: EdgeInsets.fromLTRB(4, top + 4, 4, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .7), Colors.black.withValues(alpha: 0)],
                  ),
                ),
                child: Row(children: [
                  IconButton(
                    key: const ValueKey('galleryClose'),
                    tooltip: 'Kapat',
                    color: Colors.white,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text('${_index + 1} / ${widget.media.length}',
                        key: const ValueKey('galleryCounter'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.label.copyWith(color: Colors.white)),
                  ),
                  IconButton(
                    key: const ValueKey('gallerySave'),
                    tooltip: 'İndir',
                    color: Colors.white,
                    icon: _saving
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.download),
                    onPressed: _saving ? null : _save,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  const _ZoomPage({super.key, required this.media, required this.headers, required this.onZoom});

  final PostMedia media;
  final Map<String, String> headers;
  final ValueChanged<bool> onZoom;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _tc = TransformationController();

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => widget.onZoom(_tc.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          m.url,
          headers: widget.headers,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (c, child, p) =>
              p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorBuilder: (c, e, s) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Görsel yüklenemedi.',
                key: const ValueKey('galleryImageError'), style: BuType.body.copyWith(color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}

/// Galeri video sayfası: sayfa görünür olunca yüklenir ve oynar; sayfa değişince durur.
class _GalleryVideoPage extends StatefulWidget {
  const _GalleryVideoPage({
    super.key,
    required this.media,
    required this.headers,
    required this.active,
    required this.factory,
  });

  final PostMedia media;
  final Map<String, String> headers;
  final bool active;
  final VideoControllerFactory factory;

  @override
  State<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends State<_GalleryVideoPage> {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _failed = false;
  double? _drag;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(covariant _GalleryVideoPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      final c = _c;
      if (c == null) {
        _init();
      } else if (c.value.isInitialized) {
        unawaited(c.play().catchError((_) {}));
      }
    } else if (!widget.active && old.active) {
      final c = _c;
      if (c != null && c.value.isInitialized) {
        unawaited(c.pause().catchError((_) {}));
      }
    }
  }

  Future<void> _init() async {
    final old = _c;
    _c = null;
    unawaited(old?.dispose());
    setState(() {
      _loading = true;
      _failed = false;
    });
    final c = widget.factory(Uri.parse(widget.media.url), widget.headers);
    _c = c;
    try {
      await c.initialize();
      if (!mounted || _c != c) return;
      await c.setLooping(false);
      if (widget.active) await c.play();
      if (mounted && _c == c) setState(() => _loading = false);
    } catch (_) {
      if (mounted && _c == c) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.dispose().catchError((_) {}));
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;
    if (v.isPlaying) {
      await c.pause();
    } else {
      if (v.duration > Duration.zero && v.position >= v.duration) await c.seekTo(Duration.zero);
      await c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final c = _c;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Video oynatılamadı', style: BuType.bodyStrong.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('galleryVideoRetry'),
            onPressed: _init,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(140, 44)),
            child: const Text('Yeniden dene'),
          ),
        ]),
      );
    }
    if (c == null || _loading || !c.value.isInitialized) {
      return Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
        if (m.thumbUrl != null)
          Image.network(m.thumbUrl!,
              headers: widget.headers, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink()),
        if (widget.active) const Center(child: CircularProgressIndicator(color: Colors.white)),
      ]);
    }
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('galleryVideoStage'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, v, _) {
              if (v.hasError && !_failed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _c == c && !_failed) setState(() => _failed = true);
                });
              }
              final ar = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
              return Stack(alignment: Alignment.center, children: [
                Center(child: AspectRatio(aspectRatio: ar, child: VideoPlayer(c))),
                if (v.isBuffering) const CircularProgressIndicator(color: Colors.white),
                if (!v.isPlaying && !v.isBuffering)
                  Container(
                    key: const ValueKey('galleryPlayIcon'),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.play, size: 29, color: Colors.white),
                  ),
              ]);
            },
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + bottom),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: .7), Colors.black.withValues(alpha: 0)],
            ),
          ),
          child: _controls(c),
        ),
      ),
    ]);
  }

  Widget _controls(VideoPlayerController c) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, v, _) {
        final total = v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds : (widget.media.durationMs ?? 0);
        final pos = v.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
        final shown = _drag ?? pos.toDouble();
        return Row(children: [
          Text(formatMediaDuration(shown.round()), style: BuType.caption.copyWith(color: Colors.white)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                key: const ValueKey('galleryVideoSeek'),
                min: 0,
                max: total > 0 ? total.toDouble() : 1,
                value: shown.clamp(0, total > 0 ? total.toDouble() : 1),
                onChanged: total > 0 ? (x) => setState(() => _drag = x) : null,
                onChangeEnd: (x) async {
                  setState(() => _drag = null);
                  await c.seekTo(Duration(milliseconds: x.round()));
                },
              ),
            ),
          ),
          Text(formatMediaDuration(total), style: BuType.caption.copyWith(color: Colors.white)),
        ]);
      },
    );
  }
}
