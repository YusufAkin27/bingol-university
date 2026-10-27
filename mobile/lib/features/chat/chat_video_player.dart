import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../core/typography.dart';
import 'chat_media.dart';
import 'message_bubble.dart' show chatMediaUrl;

/// Testlerde sahte platform ile birlikte ya da özel denetleyiciyle değiştirilebilir.
typedef VideoControllerFactory = VideoPlayerController Function(
    Uri uri, Map<String, String> headers);

VideoPlayerController _networkController(Uri uri, Map<String, String> headers) =>
    VideoPlayerController.networkUrl(uri, httpHeaders: headers);

/// Tam ekran siyah video oynatıcı: otomatik oynatır, dokununca oynat/duraklat, ilerleme çubuğu.
/// Akış, yetkili (Bearer) HTTP Range isteğiyle okunur; hata olursa "Video oynatılamadı" + yeniden dene.
class ChatVideoPlayerPage extends StatefulWidget {
  const ChatVideoPlayerPage({
    super.key,
    required this.url,
    required this.headers,
    this.durationMs,
    this.onSave,
    this.controllerFactory = _networkController,
  });

  /// Sunucu yolu (`/api/conversations/{cid}/media/{aid}`) ya da tam adres.
  final String url;
  final Map<String, String> headers;

  /// Bilinen süre (denetleyici hazır olana kadar etikette gösterilir).
  final int? durationMs;

  /// Verilirse "İndir" düğmesi görünür (galeriye kaydet).
  final Future<void> Function()? onSave;

  final VideoControllerFactory controllerFactory;

  @override
  State<ChatVideoPlayerPage> createState() => _ChatVideoPlayerPageState();
}

class _ChatVideoPlayerPageState extends State<ChatVideoPlayerPage> {
  VideoPlayerController? _c;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  double? _drag;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final old = _c;
    _c = null;
    old?.dispose();
    setState(() {
      _loading = true;
      _failed = false;
    });
    final c = widget.controllerFactory(
        Uri.parse(chatMediaUrl(widget.url)), widget.headers);
    _c = c;
    try {
      await c.initialize();
      if (!mounted || _c != c) return;
      await c.setLooping(false);
      await c.play();
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
    _c?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;
    if (v.isPlaying) {
      await c.pause();
    } else {
      if (v.duration > Duration.zero && v.position >= v.duration) {
        await c.seekTo(Duration.zero);
      }
      await c.play();
    }
  }

  Future<void> _save() async {
    final save = widget.onSave;
    if (save == null || _saving) return;
    setState(() => _saving = true);
    try {
      await save();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: _stage()),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(4, top + 4, 4, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .7),
                  Colors.black.withValues(alpha: 0)
                ],
              ),
            ),
            child: Row(children: [
              IconButton(
                tooltip: 'Kapat',
                color: Colors.white,
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              if (widget.onSave != null)
                IconButton(
                  tooltip: 'İndir',
                  color: Colors.white,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.download),
                  onPressed: _saving ? null : _save,
                ),
            ]),
          ),
        ),
        if (!_loading && !_failed && _c != null)
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
                  colors: [
                    Colors.black.withValues(alpha: .7),
                    Colors.black.withValues(alpha: 0)
                  ],
                ),
              ),
              child: _controls(_c!),
            ),
          ),
      ]),
    );
  }

  Widget _stage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final c = _c;
    if (_failed || c == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Video oynatılamadı',
                textAlign: TextAlign.center,
                style: BuType.bodyStrong.copyWith(color: Colors.white)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _init,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size(140, 44),
              ),
              child: const Text('Yeniden dene'),
            ),
          ]),
        ),
      );
    }
    return GestureDetector(
      key: const ValueKey('videoStage'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, v, _) {
          // Hata sonradan oluşursa (akış koptu) aynı hata ekranına düş.
          if (v.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _c == c && !_failed) setState(() => _failed = true);
            });
          }
          final ar = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
          return Stack(alignment: Alignment.center, children: [
            Center(child: AspectRatio(aspectRatio: ar, child: VideoPlayer(c))),
            if (v.isBuffering)
              const CircularProgressIndicator(color: Colors.white),
            if (!v.isPlaying && !v.isBuffering)
              Container(
                key: const ValueKey('videoPlayIcon'),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .5),
                    shape: BoxShape.circle),
                child: const Icon(LucideIcons.play,
                    size: 32, color: Colors.white),
              ),
          ]);
        },
      ),
    );
  }

  Widget _controls(VideoPlayerController c) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, v, _) {
        final total = v.duration.inMilliseconds > 0
            ? v.duration.inMilliseconds
            : (widget.durationMs ?? 0);
        final pos = v.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
        final shown = _drag ?? pos.toDouble();
        return Row(children: [
          Text(formatMediaDuration(shown.round()),
              style: BuType.caption.copyWith(color: Colors.white)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                key: const ValueKey('videoSeek'),
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
          Text(formatMediaDuration(total),
              style: BuType.caption.copyWith(color: Colors.white)),
        ]);
      },
    );
  }
}
