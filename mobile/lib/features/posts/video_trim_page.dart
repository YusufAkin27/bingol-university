import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/platform/video_frame.dart';
import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../chat/chat_media.dart' show formatMediaDuration;
import 'post_video.dart' show PostPlayBadge;
import 'post_video_limits.dart';

/// Kırpma ekranının sonucu: videodan alınacak aralık (ms).
class VideoTrimRange {
  const VideoTrimRange(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  /// Aralık tüm videoyu kapsıyor mu (kesmeye gerek yok).
  bool coversAll(int totalMs) => startMs <= 0 && endMs >= totalMs - 50;

  @override
  bool operator ==(Object other) => other is VideoTrimRange && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);
}

/// İki tutamaçlı aralığın saf mantığı (arayüzden bağımsız, test edilebilir): aralık hiçbir zaman [maxMs]'den uzun,
/// [minMs]'den kısa olmaz ve [0, totalMs] dışına çıkmaz. Tutamaç sınıra dayanınca durur (öbür ucu itmez).
class TrimWindow {
  TrimWindow({required this.totalMs, required this.maxMs, this.minMs = PostVideoLimits.minTrimMs})
      : start = 0,
        end = math.min(totalMs, maxMs);

  final int totalMs;
  final int maxMs;
  final int minMs;
  int start;
  int end;

  int get length => end - start;
  int get _min => math.min(minMs, totalMs);

  void moveStart(int ms) => start = ms.clamp(math.max(0, end - maxMs), end - _min).toInt();

  void moveEnd(int ms) => end = ms.clamp(start + _min, math.min(totalMs, start + maxMs)).toInt();

  /// Tüm aralığı [deltaMs] kaydırır (uzunluk korunur).
  void shift(int deltaMs) {
    final len = length;
    start = (start + deltaMs).clamp(0, totalMs - len).toInt();
    end = start + len;
  }

  VideoTrimRange get range => VideoTrimRange(start, end);
}

enum _Drag { none, start, end, move }

/// Video kırpma ekranı: zaman damgalı küçük resim şeridi üstünde iki tutamaç, aralık içinde döngülü canlı önizleme,
/// seçilen süre. [mandatory] iken (video sınırdan uzun) aralık en çok [maxDurationMs] seçilebilir ve vazgeçmek videoyu
/// paylaşılamaz bırakır. Sonuç [VideoTrimRange] (vazgeçilirse null). Üst çubukta başlık çizilmez, yalnız anlamsal etiket.
class VideoTrimPage extends StatefulWidget {
  const VideoTrimPage({
    super.key,
    required this.path,
    required this.durationMs,
    this.maxDurationMs = PostVideoLimits.maxDurationMs,
    this.mandatory = false,
    this.initial,
    this.frames,
  });

  final String path;
  final int durationMs;
  final int maxDurationMs;
  final bool mandatory;

  /// Önceki kırpma: ekran bu aralıkla açılır (yeniden düzenleme).
  final VideoTrimRange? initial;

  /// Testler için: küçük resim kaynağı (varsayılan `PlatformVideoFrames.instance`).
  final VideoFrameSource? frames;

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  static const _thumbCount = 8;
  static const _handleW = 18.0;
  static const _stripH = 60.0;
  static const _grab = 28.0; // tutamağa yakınlık (dokunma payı)

  late final TrimWindow _w = TrimWindow(totalMs: widget.durationMs, maxMs: widget.maxDurationMs);
  final _thumbs = List<Uint8List?>.filled(_thumbCount, null);
  VideoPlayerController? _c;
  bool _playing = true;
  _Drag _drag = _Drag.none;
  int _posMs = 0;

  VideoFrameSource get _frames => widget.frames ?? PlatformVideoFrames.instance;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _w.start = i.startMs.clamp(0, widget.durationMs).toInt();
      _w.end = i.endMs.clamp(_w.start + 1, widget.durationMs).toInt();
      if (_w.length > widget.maxDurationMs) _w.end = _w.start + widget.maxDurationMs;
    }
    _posMs = _w.start;
    unawaited(_initPlayer());
    unawaited(_loadThumbs());
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    c?.removeListener(_onTick);
    c?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      final c = VideoPlayerController.file(File(widget.path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _c = c;
      await c.initialize();
      if (!mounted) return;
      await c.setVolume(0);
      await c.setLooping(false);
      await c.seekTo(Duration(milliseconds: _w.start));
      c.addListener(_onTick);
      if (_playing) await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Oynatıcı kurulamadı (platform yok/bozuk dosya): önizleme küçük resimle sınırlı kalır, kırpma yine çalışır.
      final c = _c;
      _c = null;
      try {
        await c?.dispose();
      } catch (_) {}
    }
  }

  /// Aralık içinde döngü: bitişe varınca başa sar. Oynatma konumu şeritte çizgiyle gösterilir.
  void _onTick() {
    final c = _c;
    if (c == null || !mounted) return;
    final pos = c.value.position.inMilliseconds;
    if (_drag == _Drag.none && c.value.isPlaying && pos >= _w.end - 30) {
      unawaited(c.seekTo(Duration(milliseconds: _w.start)));
    }
    if ((pos - _posMs).abs() > 40) setState(() => _posMs = pos);
  }

  Future<void> _loadThumbs() async {
    for (var i = 0; i < _thumbCount; i++) {
      final at = (widget.durationMs * (i + .5) / _thumbCount).round();
      final f = await _frames.frame(path: widget.path, positionMs: at, maxEdge: 200);
      if (!mounted) return;
      if (f != null && f.isNotEmpty) setState(() => _thumbs[i] = f);
    }
  }

  Future<void> _seek(int ms) async {
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      setState(() => _posMs = ms);
      return;
    }
    await c.seekTo(Duration(milliseconds: ms));
  }

  Future<void> _setPlaying(bool play) async {
    setState(() => _playing = play);
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (play) {
      if (c.value.position.inMilliseconds < _w.start || c.value.position.inMilliseconds >= _w.end - 30) {
        await c.seekTo(Duration(milliseconds: _w.start));
      }
      await c.play();
    } else {
      await c.pause();
    }
  }

  // --- Sürükleme -------------------------------------------------------------------------------------------------------

  double _x(int ms, double width) => width <= 0 ? 0 : ms / widget.durationMs * width;

  void _dragStart(DragStartDetails d, double width) {
    final x = d.localPosition.dx;
    final xs = _x(_w.start, width), xe = _x(_w.end, width);
    final ds = (x - xs).abs(), de = (x - xe).abs();
    if (ds <= _grab && ds <= de) {
      _drag = _Drag.start;
    } else if (de <= _grab) {
      _drag = _Drag.end;
    } else if (x > xs && x < xe) {
      _drag = _Drag.move;
    } else {
      _drag = _Drag.none;
      return;
    }
    unawaited(_c?.pause());
  }

  void _dragUpdate(DragUpdateDetails d, double width) {
    if (_drag == _Drag.none || width <= 0) return;
    final dMs = (d.delta.dx / width * widget.durationMs).round();
    setState(() {
      switch (_drag) {
        case _Drag.start:
          _w.moveStart(_w.start + dMs);
          _posMs = _w.start;
        case _Drag.end:
          _w.moveEnd(_w.end + dMs);
          _posMs = math.max(_w.start, _w.end - 300);
        case _Drag.move:
          _w.shift(dMs);
          _posMs = _w.start;
        case _Drag.none:
          break;
      }
    });
    unawaited(_seek(_posMs));
  }

  void _dragEnd() {
    if (_drag == _Drag.none) return;
    _drag = _Drag.none;
    // Bırakınca seçilen aralığın başından yeniden oynat.
    unawaited(_seek(_w.start).then((_) {
      if (_playing) _c?.play();
    }));
  }

  void _nudge(_Drag which, int deltaMs) {
    setState(() {
      if (which == _Drag.start) {
        _w.moveStart(_w.start + deltaMs);
      } else {
        _w.moveEnd(_w.end + deltaMs);
      }
      _posMs = _w.start;
    });
    unawaited(_seek(_w.start));
  }

  // --- Arayüz ----------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final tooLong = PostVideoLimits.needsTrim(widget.durationMs) || widget.durationMs > widget.maxDurationMs;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Semantics(
          container: true,
          label: l.composeTrimTitle,
          child: Column(children: [
            SizedBox(
              height: 56,
              child: Row(children: [
                IconButton(
                  key: const ValueKey('trimClose'),
                  tooltip: l.postComposeClose,
                  icon: Icon(BuIcons.x, size: 24, color: t.ink),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Semantics(
                    button: true,
                    label: l.composeTrimDone,
                    child: Material(
                      key: const ValueKey('trimDone'),
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => Navigator.pop(context, _w.range),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: 64),
                          child: Center(
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(BuRadius.pill)),
                              child: SizedBox(
                                height: 36,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text(l.composeTrimDone,
                                        style: tt.labelLarge?.copyWith(color: t.onPr, fontSize: 14, fontWeight: FontWeight.w400)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: BuSpace.page), child: _preview(t))),
            const SizedBox(height: 12),
            _info(t, tt, l, tooLong),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
              child: _timeline(t, l),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _preview(BuTokens t) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final ar = ready && c.value.aspectRatio > 0 ? c.value.aspectRatio.clamp(.5, 1.91).toDouble() : 4 / 5;
    final poster = _thumbs.firstWhere((e) => e != null, orElse: () => null);
    return Center(
      child: AspectRatio(
        aspectRatio: ar,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GestureDetector(
            key: const ValueKey('trimPreview'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _setPlaying(!_playing),
            child: Semantics(
              button: true,
              label: _playing ? context.l10n.composeTrimPause : context.l10n.composeTrimPlay,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: t.sf2),
                if (poster != null) Image.memory(poster, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                if (ready)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
                  ),
                if (!_playing) const Center(child: PostPlayBadge(size: 56)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(BuTokens t, TextTheme tt, AppLocalizations l, bool tooLong) {
    final sel = formatMediaDuration(_w.length);
    final max = formatMediaDuration(widget.maxDurationMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
      child: Column(children: [
        Semantics(
          liveRegion: true,
          label: l.composeTrimSelected(sel),
          child: ExcludeSemantics(
            child: Text(sel,
                key: const ValueKey('trimSelected'),
                style: tt.headlineSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.mandatory && tooLong ? l.composeTrimTooLong(max) : l.composeTrimHint(max),
          key: const ValueKey('trimHint'),
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(color: widget.mandatory && tooLong ? t.ink : t.mut),
        ),
      ]),
    );
  }

  Widget _timeline(BuTokens t, AppLocalizations l) {
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final xs = _x(_w.start, width);
      final xe = _x(_w.end, width);
      final xp = _x(_posMs.clamp(_w.start, _w.end).toInt(), width);
      // Zaman ekseni her dilde soldan sağa (Arapçada da küçük resimler ve tutamaçlar aynı yönde).
      return Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
        key: const ValueKey('trimTimeline'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _dragStart(d, width),
        onHorizontalDragUpdate: (d) => _dragUpdate(d, width),
        onHorizontalDragEnd: (_) => _dragEnd(),
        onHorizontalDragCancel: _dragEnd,
        child: SizedBox(
          height: _stripH + 8,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              height: _stripH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BuRadius.sm),
                child: Row(children: [
                  for (var i = 0; i < _thumbCount; i++)
                    Expanded(
                      child: _thumbs[i] == null
                          ? ColoredBox(color: t.sf2)
                          : Image.memory(_thumbs[i]!, fit: BoxFit.cover, height: _stripH, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: t.sf2)),
                    ),
                ]),
              ),
            ),
            // Seçim dışı alan soluk.
            Positioned(left: 0, top: 4, width: xs, height: _stripH, child: ColoredBox(color: t.scrim.withValues(alpha: .6))),
            Positioned(left: xe, right: 0, top: 4, height: _stripH, child: ColoredBox(color: t.scrim.withValues(alpha: .6))),
            // Seçim çerçevesi.
            Positioned(
              left: xs,
              width: math.max(0, xe - xs),
              top: 4,
              height: _stripH,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: t.pr, width: 3))),
                ),
              ),
            ),
            // Oynatma konumu.
            Positioned(
              left: xp - 1,
              top: 0,
              width: 2,
              height: _stripH + 8,
              child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: t.onMedia, borderRadius: BorderRadius.circular(1)))),
            ),
            _handle(t, l, left: (xs - _handleW).clamp(-_handleW, width), which: _Drag.start),
            _handle(t, l, left: xe.clamp(0, width + _handleW), which: _Drag.end),
          ]),
        ),
      ));
    });
  }

  /// Tutamak: 18 dp görünür, anlamsal olarak kaydırıcı (artır/azalt 1 sn); asıl dokunma alanı şeritteki sürüklemedir.
  Widget _handle(BuTokens t, AppLocalizations l, {required double left, required _Drag which}) {
    final isStart = which == _Drag.start;
    final ms = isStart ? _w.start : _w.end;
    return Positioned(
      left: left,
      top: 4,
      width: _handleW,
      height: _stripH,
      child: Semantics(
        key: ValueKey(isStart ? 'trimHandleStart' : 'trimHandleEnd'),
        slider: true,
        label: isStart ? l.composeTrimStart : l.composeTrimEnd,
        value: formatMediaDuration(ms),
        increasedValue: formatMediaDuration(ms + 1000),
        decreasedValue: formatMediaDuration(math.max(0, ms - 1000)),
        onIncrease: () => _nudge(which, 1000),
        onDecrease: () => _nudge(which, -1000),
        child: Container(
          decoration: BoxDecoration(
            color: t.pr,
            borderRadius: BorderRadiusDirectional.horizontal(
              start: isStart ? const Radius.circular(BuRadius.sm) : Radius.zero,
              end: isStart ? Radius.zero : const Radius.circular(BuRadius.sm),
            ),
          ),
          alignment: Alignment.center,
          child: Container(width: 3, height: 22, decoration: BoxDecoration(color: t.onPr, borderRadius: BorderRadius.circular(2))),
        ),
      ),
    );
  }
}
