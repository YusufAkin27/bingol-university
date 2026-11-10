// Sesli mesaj balonu (V1): oynat/duraklat, dalga + ilerleme, süre, 1x/1.5x/2x hız. Sıradakini otomatik çalmaz.
// Oynatma `video_player` ile (ses-yalnız MP4 de çalar); sunucu akışı Bearer'lı HTTP Range ile okunur.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart' show chatMediaUrl, formatMediaDuration;

/// Ek tür: sesli mesaj (`kind: "AUDIO"`).
bool isAudioAttachment(Map a) => '${a['kind'] ?? ''}'.toUpperCase() == 'AUDIO';

/// Oynatılacak kaynak: sunucu adresi (+ başlık) ya da yerel dosya (gönderimi süren kendi kaydım).
class VoiceSource {
  const VoiceSource.network(this.url, this.headers) : file = null;
  const VoiceSource.file(this.file)
      : url = null,
        headers = const {};
  final String? url;
  final Map<String, String> headers;
  final String? file;
}

/// Testlerde sahte denetleyici verilebilir.
typedef VoiceControllerFactory = VideoPlayerController Function(VoiceSource source);

VideoPlayerController defaultVoiceController(VoiceSource s) => s.file != null
    ? VideoPlayerController.file(File(s.file!))
    : VideoPlayerController.networkUrl(Uri.parse(chatMediaUrl(s.url!)), httpHeaders: s.headers);

/// Aynı anda tek sesli mesaj çalar: yenisi başlayınca öncekini duraklatır.
class VoicePlaybackCoordinator {
  VoicePlaybackCoordinator._();
  static final ValueNotifier<Object?> active = ValueNotifier<Object?>(null);
}

const kVoiceSpeeds = [1.0, 1.5, 2.0];

String voiceSpeedLabel(double s) => s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';

class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.source,
    required this.durationMs,
    required this.color,
    this.waveSeed = 0,
    this.uploading = false,
    this.trailing,
    this.controllerFactory = defaultVoiceController,
  });

  final VoiceSource source;

  /// Sunucudan/kayıttan bilinen süre (oynatıcı hazır olana dek gösterilir).
  final int durationMs;
  final Color color;

  /// Dalga şekli tohumu (ek kimliği): dalga süs amaçlıdır, gerçek genlik değildir.
  final int waveSeed;
  final bool uploading;

  /// Saat/tik satırı.
  final Widget? trailing;
  final VoiceControllerFactory controllerFactory;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _failed = false;
  int _speedIx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VoicePlaybackCoordinator.active.addListener(_onActive);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VoicePlaybackCoordinator.active.removeListener(_onActive);
    if (VoicePlaybackCoordinator.active.value == this) VoicePlaybackCoordinator.active.value = null;
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plana alınınca durdur.
    if (state != AppLifecycleState.resumed) _c?.pause();
  }

  void _onActive() {
    if (VoicePlaybackCoordinator.active.value != this) _c?.pause();
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError) {
      _failed = true;
    } else if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying) {
      // Bitti: başa sar, sıradakine GEÇME.
      c.seekTo(Duration.zero);
      c.pause();
    }
    setState(() {});
  }

  Future<void> _toggle() async {
    if (widget.uploading && widget.source.file == null) return;
    buHaptic(BuHaptic.selection);
    var c = _c;
    if (c == null || _failed) {
      c?.removeListener(_tick);
      await c?.dispose();
      c = widget.controllerFactory(widget.source);
      _c = c;
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        await c.initialize();
        await c.setLooping(false);
        await c.setPlaybackSpeed(kVoiceSpeeds[_speedIx]);
        c.addListener(_tick);
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      VoicePlaybackCoordinator.active.value = this;
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _cycleSpeed() async {
    buHaptic(BuHaptic.selection);
    _speedIx = (_speedIx + 1) % kVoiceSpeeds.length;
    await _c?.setPlaybackSpeed(kVoiceSpeeds[_speedIx]);
    if (mounted) setState(() {});
  }

  void _seek(double dx, double width) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var f = (dx / width).clamp(0.0, 1.0);
    if (rtl) f = 1 - f;
    c.seekTo(c.value.duration * f);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final c = _c;
    final playing = c?.value.isPlaying ?? false;
    final total = (c != null && c.value.isInitialized && c.value.duration > Duration.zero)
        ? c.value.duration.inMilliseconds
        : widget.durationMs;
    final pos = c != null && c.value.isInitialized ? c.value.position.inMilliseconds : 0;
    final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    final shownMs = playing || pos > 0 ? pos : total;
    final label = l.chatVoiceSemantics(formatMediaDuration(total), playing ? l.chatVoicePause : l.chatVoicePlay);
    final fg = widget.color;
    return Semantics(
      container: true,
      label: label,
      button: true,
      onTap: _toggle,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, minHeight: 48),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            key: const ValueKey('voicePlayButton'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: _loading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                    : Icon(_failed ? BuIcons.refreshCw : (playing ? BuIcons.pause : BuIcons.play), size: 26, color: fg),
              ),
            ),
          ),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _seek(d.localPosition.dx, box.maxWidth),
                  onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, box.maxWidth),
                  child: SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: VoiceWavePainter(seed: widget.waveSeed, progress: progress, color: fg, rtl: Directionality.of(context) == TextDirection.rtl),
                    ),
                  ),
                ),
              ),
              Row(children: [
                Text(
                  _failed ? l.chatVoiceFailed : formatMediaDuration(shownMs),
                  style: tx.labelMedium!.copyWith(color: fg, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const Spacer(),
                if (widget.trailing != null) widget.trailing!,
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: l.chatVoiceSpeed(voiceSpeedLabel(kVoiceSpeeds[_speedIx])),
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('voiceSpeedButton'),
              behavior: HitTestBehavior.opaque,
              onTap: _cycleSpeed,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(voiceSpeedLabel(kVoiceSpeeds[_speedIx]),
                      style: tx.labelMedium!.copyWith(color: fg)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Süs dalga + ilerleme dolgusu (RTL'de ters yönde ilerler). Şekil tohumdan üretilir (aynı mesaj hep aynı dalga).
class VoiceWavePainter extends CustomPainter {
  VoiceWavePainter({required this.seed, required this.progress, required this.color, required this.rtl});

  final int seed;
  final double progress;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 3.0, gap = 2.5;
    final n = (size.width / (w + gap)).floor();
    if (n <= 0) return;
    final rnd = math.Random(seed * 7919 + 17);
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    final mid = size.height / 2;
    for (var i = 0; i < n; i++) {
      final h = 4 + rnd.nextDouble() * (size.height - 6);
      final frac = (i + .5) / n;
      final played = rtl ? (1 - frac) <= progress : frac <= progress;
      p.color = color.withValues(alpha: played ? 1 : .35);
      final x = i * (w + gap) + w / 2;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(VoiceWavePainter o) => o.progress != progress || o.seed != seed || o.color != color || o.rtl != rtl;
}
