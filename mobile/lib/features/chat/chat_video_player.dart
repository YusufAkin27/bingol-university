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
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
            child: Row(children: [
              ChatdRoundButton(icon: LucideIcons.x, tooltip: l.chatMiscClose, onPressed: () => Navigator.pop(context)),
              const Spacer(),
              if (widget.onSave != null) ChatdRoundButton(icon: LucideIcons.download, tooltip: l.chatMiscDownload, busy: _saving, onPressed: _save),
            ]),
          ),
        ),
        if (!_loading && !_failed && _c != null)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ChatdBottomBar(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 28, 16, 12),
              child: _controls(_c!),
            ),
          ),
      ]),
    );
  }

  Widget _stage() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    if (_loading) {
      return Center(
        child: ChatdRing(icon: LucideIcons.play, semantics: l.chatMiscPlayVideo),
      );
    }
    final c = _c;
    if (_failed || c == null) {
      // Referans 26: koyu lacivert yuvarlak kart, halkalı kırmızı simge, başlık ve kırmızı "Yeniden dene".
      return Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 4 + 48 + 12, 16, MediaQuery.paddingOf(context).bottom + 16),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color.lerp(t.scrim, kChatdNavy, .35), borderRadius: BorderRadius.circular(20)),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: t.pr.withValues(alpha: .18), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                    child: Icon(LucideIcons.videoOff, size: 26, color: t.onPr),
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  liveRegion: true,
                  child: Text(l.chatMiscVideoPlayFailed, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: BuButton(label: l.chatMiscRetry, icon: LucideIcons.refreshCw, onPressed: _init),
                ),
              ]),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      key: const ValueKey('videoStage'),
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
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
          final playing = v.isPlaying;
          return Stack(alignment: Alignment.center, children: [
            // Dikey videolar ekranı doldurur ve üst çubuğun arkasına uzanır (referans 26); yatay videolar sığdırılır.
            Positioned.fill(
              child: RepaintBoundary(
                child: ar < 1
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(width: v.size.width > 0 ? v.size.width : 720, height: v.size.height > 0 ? v.size.height : 1280, child: VideoPlayer(c)),
                      )
                    : Center(child: AspectRatio(aspectRatio: ar, child: VideoPlayer(c))),
              ),
            ),
            if (v.isBuffering) const ChatdRing(icon: LucideIcons.play),
            // Orta düğme her zaman görünür: oynarken "duraklat", duraklayınca "oynat" (referans 26).
            Semantics(
              key: ValueKey(playing ? 'videoPauseIcon' : 'videoPlayIcon'),
              label: playing ? l.p08Pause : l.chatMiscPlayVideo,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Color.alphaBlend(t.onMedia.withValues(alpha: .18), t.scrim).withValues(alpha: .82)),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44, color: t.onMedia),
              ),
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
    final timeStyle = tx.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, v, _) {
        final total = v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds : (widget.durationMs ?? 0);
        final max = total > 0 ? total.toDouble() : 1.0;
        final pos = v.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
        final shown = _drag ?? pos.toDouble();
        final buffered = v.buffered.isEmpty ? 0.0 : v.buffered.last.end.inMilliseconds.toDouble().clamp(0.0, max);
        // Seek çubuğu her dilde soldan sağa akar (zaman ekseni).
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: t.pr,
                inactiveTrackColor: t.onMedia.withValues(alpha: .24),
                secondaryActiveTrackColor: t.onMedia.withValues(alpha: .42),
                thumbColor: t.onMedia,
                overlayColor: t.pr.withValues(alpha: .18),
                trackShape: const RoundedRectSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Semantics(
                label: l.p08Seek,
                child: Slider(
                  key: const ValueKey('videoSeek'),
                  min: 0,
                  max: max,
                  value: shown.clamp(0, max),
                  secondaryTrackValue: buffered,
                  semanticFormatterCallback: (x) => formatMediaDuration(x.round()),
                  onChanged: total > 0 ? (x) => setState(() => _drag = x) : null,
                  onChangeEnd: (x) async {
                    setState(() => _drag = null);
                    await c.seekTo(Duration(milliseconds: x.round()));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Text(formatMediaDuration(shown.round()), maxLines: 1, softWrap: false, style: timeStyle),
                const Spacer(),
                Text(formatMediaDuration(total), maxLines: 1, softWrap: false, style: timeStyle.copyWith(color: t.onMedia.withValues(alpha: .6))),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
