import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'chat_media_parts.dart';
import 'chatd_parts.dart';

/// Testlerde sahte platform ile birlikte ya da özel denetleyiciyle değiştirilebilir.
typedef VideoControllerFactory = VideoPlayerController Function(
    Uri uri, Map<String, String> headers);

VideoPlayerController _networkController(Uri uri, Map<String, String> headers) =>
    VideoPlayerController.networkUrl(uri, httpHeaders: headers);

/// Tam ekran siyah video oynatıcı: otomatik oynatır, dokununca oynat/duraklat, ilerleme çubuğu (tampon göstergeli).
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
    buHaptic(BuHaptic.selection);
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
    final l = context.l10n;
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(child: _stage()),
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdTopBar(
            child: Row(children: [
              ChatdRoundButton(
                  icon: LucideIcons.x,
                  tooltip: l.chatMiscClose,
                  onPressed: () => Navigator.pop(context)),
              const Spacer(),
              if (widget.onSave != null)
                ChatdRoundButton(
                    icon: LucideIcons.download,
                    tooltip: l.chatMiscDownload,
                    busy: _saving,
                    onPressed: _save),
            ]),
          ),
        ),
        if (!_loading && !_failed && _c != null)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ChatdBottomBar(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 28, 16, 8),
              child: _controls(_c!),
            ),
          ),
      ]),
    );
  }

  Widget _stage() {
    final l = context.l10n;
    if (_loading) {
      return Center(
        child: ChatdRing(icon: LucideIcons.play, semantics: l.chatMiscPlayVideo),
      );
    }
    final c = _c;
    if (_failed || c == null) {
      return ChatdMediaMessage(
        icon: LucideIcons.videoOff,
        title: l.chatMiscVideoPlayFailed,
        actionLabel: l.chatMiscRetry,
        onAction: _init,
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
          final showPlay = !v.isPlaying && !v.isBuffering;
          return Stack(alignment: Alignment.center, children: [
            Center(
                child: RepaintBoundary(
                    child: AspectRatio(
                        aspectRatio: ar, child: VideoPlayer(c)))),
            if (v.isBuffering)
              const ChatdRing(icon: LucideIcons.play),
            AnimatedSwitcher(
              duration: BuMotion.of(context, BuMotion.short),
              child: showPlay
                  ? Semantics(
                      key: const ValueKey('videoPlayIcon'),
                      label: l.chatMiscPlayVideo,
                      child: const ChatdPlay(size: 72),
                    )
                  : const SizedBox.shrink(key: ValueKey('videoNoIcon')),
            ),
          ]);
        },
      ),
    );
  }

  Widget _controls(VideoPlayerController c) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final timeStyle = tx.labelMedium!.copyWith(
        color: t.onMedia,
        fontFeatures: const [FontFeature.tabularFigures()]);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, v, _) {
        final total = v.duration.inMilliseconds > 0
            ? v.duration.inMilliseconds
            : (widget.durationMs ?? 0);
        final max = total > 0 ? total.toDouble() : 1.0;
        final pos = v.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
        final shown = _drag ?? pos.toDouble();
        final buffered = v.buffered.isEmpty
            ? 0.0
            : v.buffered.last.end.inMilliseconds.toDouble().clamp(0.0, max);
        // Seek çubuğu her dilde soldan sağa akar (zaman ekseni).
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            IconButton(
              key: const ValueKey('videoToggle'),
              tooltip: v.isPlaying ? l.p08Pause : l.chatMiscPlayVideo,
              onPressed: _toggle,
              icon: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 30),
              style: IconButton.styleFrom(
                foregroundColor: t.onMedia,
                minimumSize: const Size(48, 48),
                fixedSize: const Size(48, 48),
              ),
            ),
            ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(formatMediaDuration(shown.round()),
                    maxLines: 1, softWrap: false, style: timeStyle)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: t.onMedia,
                  inactiveTrackColor: t.onMedia.withValues(alpha: .24),
                  secondaryActiveTrackColor: t.onMedia.withValues(alpha: .42),
                  thumbColor: t.onMedia,
                  overlayColor: t.onMedia.withValues(alpha: .18),
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Semantics(
                  label: l.p08Seek,
                  child: Slider(
                    key: const ValueKey('videoSeek'),
                    min: 0,
                    max: max,
                    value: shown.clamp(0, max),
                    secondaryTrackValue: buffered,
                    semanticFormatterCallback: (x) =>
                        formatMediaDuration(x.round()),
                    onChanged:
                        total > 0 ? (x) => setState(() => _drag = x) : null,
                    onChangeEnd: (x) async {
                      setState(() => _drag = null);
                      await c.seekTo(Duration(milliseconds: x.round()));
                    },
                  ),
                ),
              ),
            ),
            ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(formatMediaDuration(total),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.end,
                    style: timeStyle)),
          ]),
        );
      },
    );
  }
}
