// Sohbette sesli mesaj KAYDI (V1): kayıt servisi arayüzü, denetleyici, mikrofon düğmesi ve kayıt çubuğu.
//
// Akış: mikrofona basılı tut = kaydet, bırak = gönder, başlangıç tarafına kaydır = iptal. < 1 sn kayıtlar atılır,
// üst sınır 5 dk (sunucuda da denetlenir). Kayıt dosyası G10 kalıcı aktarım kuyruğuna girer (bkz. chat_transfer.dart).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart' show formatMediaDuration;

/// En kısa gönderilen kayıt (yanlışlıkla dokunma).
const kVoiceMinMs = 1000;

/// En uzun kayıt (sunucu 5 dk + 1,5 sn tolerans verir).
const kVoiceMaxMs = 5 * 60 * 1000;

/// Kayıt servisi arayüzü: testlerde sahtesi yazılır; üretimde [RecordVoiceRecorder].
abstract class VoiceRecorder {
  /// Mikrofon izni verilmiş mi (sistem istemi AÇMAZ; istem [ensurePermission] ile alınır).
  Future<bool> hasPermission();

  /// [path] dosyasına m4a/AAC kaydı başlatır; başlayamazsa false.
  Future<bool> start(String path);

  /// Kaydı bitirir; dosya yolunu döndürür (yoksa null).
  Future<String?> stop();

  /// Kaydı bırakır ve dosyayı siler.
  Future<void> cancel();

  /// 0..1 arası ses seviyesi (yaklaşık 10 Hz).
  Stream<double> get levels;

  /// Kayıt dışarıdan kesildi (arama, başka uygulama, ses oturumu kaybı).
  Stream<void> get interrupted;

  Future<void> dispose();
}

/// `record` paketiyle gerçek kayıt (AAC-LC, mono, 64 kb/sn: dakikada ~0,5 MB).
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder();

  // Tembel: sohbet her açılışında yerel kaydedici (mikrofon kaynağı) ayrılmasın; ilk kayıtta/izin sorgusunda kurulur.
  AudioRecorder? _recorder;
  AudioRecorder get _rec => _recorder ??= AudioRecorder();
  final _levels = StreamController<double>.broadcast();
  final _interrupted = StreamController<void>.broadcast();
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordState>? _stateSub;
  bool _active = false;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Stream<void> get interrupted => _interrupted.stream;

  @override
  Future<bool> hasPermission() => _rec.hasPermission(request: false);

  @override
  Future<bool> start(String path) async {
    try {
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
      _active = true;
      // dBFS (-60..0) -> 0..1
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) => _levels.add(((a.current + 60) / 60).clamp(0.0, 1.0)));
      _stateSub = _rec.onStateChanged().listen((s) {
        // Biz durdurmadan "durdu/duraklatıldı" = sistem kesintisi.
        if (_active && s != RecordState.record) _interrupted.add(null);
      });
      return true;
    } catch (_) {
      _active = false;
      return false;
    }
  }

  Future<void> _release() async {
    _active = false;
    await _ampSub?.cancel();
    await _stateSub?.cancel();
    _ampSub = null;
    _stateSub = null;
  }

  @override
  Future<String?> stop() async {
    await _release();
    try {
      return await _rec.stop();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    await _release();
    try {
      await _rec.cancel();
    } catch (_) {
      // Zaten durmuş olabilir.
    }
  }

  @override
  Future<void> dispose() async {
    await _release();
    await _levels.close();
    await _interrupted.close();
    try {
      await _recorder?.dispose();
    } catch (_) {}
  }
}

/// Biten kayıt.
class VoiceClip {
  const VoiceClip(this.path, this.durationMs);
  final String path;
  final int durationMs;
}

enum VoiceRecordPhase { idle, recording }

/// Kayıt durumunu tutar: süre, canlı seviye çubukları, iptal ipucu. Arayüz [ListenableBuilder] ile dinler.
class VoiceRecordController extends ChangeNotifier {
  VoiceRecordController({VoiceRecorder? recorder, Future<String> Function()? tempPath, DateTime Function()? now})
      : _recorder = recorder ?? RecordVoiceRecorder(),
        _tempPath = tempPath ?? _defaultTempPath,
        _now = now ?? DateTime.now;

  final VoiceRecorder _recorder;
  final Future<String> Function() _tempPath;
  final DateTime Function() _now;

  /// Süre sınırına ulaşınca otomatik bitirilen kayıt buraya verilir (gönderen sayfa dinler).
  void Function(VoiceClip clip)? onAutoFinished;

  /// Sistem kesintisinde (arama vb.) kayıt atılır; sayfa bildirim gösterir.
  VoidCallback? onInterrupted;

  VoiceRecordPhase _phase = VoiceRecordPhase.idle;
  DateTime? _startedAt;
  Timer? _tick;
  StreamSubscription<double>? _lvlSub;
  StreamSubscription<void>? _intSub;
  bool _cancelArmed = false;
  final List<double> _levels = [];

  VoiceRecordPhase get phase => _phase;
  bool get recording => _phase == VoiceRecordPhase.recording;
  bool get cancelArmed => _cancelArmed;
  List<double> get levels => List.unmodifiable(_levels);
  int get elapsedMs => _startedAt == null ? 0 : _now().difference(_startedAt!).inMilliseconds;

  static Future<String> _defaultTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Kaydı başlatır. İzin yoksa/başlamazsa false.
  Future<bool> start() async {
    if (recording) return false;
    final path = await _tempPath();
    final ok = await _recorder.start(path);
    if (!ok) return false;
    if (_disposed) {
      // Sayfa kayıt başlarken kapandı: kaydı bırak, dinleyici/zamanlayıcı kurma.
      unawaited(_recorder.cancel());
      return false;
    }
    _phase = VoiceRecordPhase.recording;
    _startedAt = _now();
    _cancelArmed = false;
    _levels.clear();
    _lvlSub = _recorder.levels.listen((v) {
      _levels.add(v);
      if (_levels.length > 48) _levels.removeAt(0);
    });
    _intSub = _recorder.interrupted.listen((_) => _onInterrupted());
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    notifyListeners();
    return true;
  }

  void _onTick() {
    if (!recording) return;
    if (elapsedMs >= kVoiceMaxMs) {
      unawaited(finish().then((c) {
        if (c != null) onAutoFinished?.call(c);
      }));
      return;
    }
    notifyListeners();
  }

  Future<void> _onInterrupted() async {
    if (!recording) return;
    await cancel();
    onInterrupted?.call();
  }

  void setCancelArmed(bool v) {
    if (_cancelArmed == v || !recording) return;
    _cancelArmed = v;
    notifyListeners();
  }

  Future<void> _stopTimers() async {
    _tick?.cancel();
    _tick = null;
    await _lvlSub?.cancel();
    await _intSub?.cancel();
    _lvlSub = null;
    _intSub = null;
  }

  /// Kaydı bitirir. 1 sn'den kısaysa ya da iptal işaretliyse dosya silinir ve null döner.
  Future<VoiceClip?> finish() async {
    if (!recording) return null;
    final ms = elapsedMs.clamp(0, kVoiceMaxMs);
    final armed = _cancelArmed;
    _phase = VoiceRecordPhase.idle;
    _startedAt = null;
    _cancelArmed = false;
    await _stopTimers();
    final path = await _recorder.stop();
    notifyListeners();
    if (path == null) return null;
    if (armed || ms < kVoiceMinMs) {
      await _delete(path);
      return null;
    }
    return VoiceClip(path, ms);
  }

  Future<void> cancel() async {
    if (!recording) return;
    _phase = VoiceRecordPhase.idle;
    _startedAt = null;
    _cancelArmed = false;
    await _stopTimers();
    await _recorder.cancel();
    notifyListeners();
  }

  static Future<void> _delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  bool _disposed = false;

  // Sayfa kapanırken bekleyen finish()/cancel()/start() sonradan notify ederse "dispose sonrası kullanım" olmasın.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _lvlSub?.cancel();
    _intSub?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

/// Mikrofon düğmesi (48 dp). Basılı tut = kaydet; bırak = gönder; başlangıç yönüne [cancelDistance] kaydır = iptal.
/// Ekran okuyucuda dokunma = kaydı başlat / ikinci dokunma = bitir ve gönder.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.controller,
    required this.onClip,
    required this.beforeStart,
    required this.onTooShort,
  });

  final VoiceRecordController controller;

  /// Biten kayıt (gönder).
  final void Function(VoiceClip clip) onClip;

  /// Kayıttan önce izin/engel denetimi; false = başlatma (izin penceresi o sırada açılmış olabilir).
  final Future<bool> Function() beforeStart;

  /// Tek dokunuş ya da < 1 sn: "Kaydetmek için basılı tutun".
  final VoidCallback onTooShort;

  static const cancelDistance = 72.0;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  bool _starting = false;
  bool _released = false;
  bool _a11yToggle = false;

  VoiceRecordController get _c => widget.controller;

  Future<void> _begin() async {
    if (_starting || _c.recording) return;
    _starting = true;
    _released = false;
    try {
      if (!await widget.beforeStart()) return;
      if (!mounted) return;
      final ok = await _c.start();
      if (!ok) return;
      buHaptic(BuHaptic.medium);
      if (_released || _a11yToggle) {
        // Parmak izin penceresi sırasında kalktıysa kayıt hiç başlamamış sayılır.
        if (_released && !_a11yToggle) await _end(send: true);
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _end({required bool send}) async {
    if (!_c.recording) return;
    if (!send) {
      await _c.cancel();
      return;
    }
    final clip = await _c.finish();
    if (clip != null) {
      widget.onClip(clip);
    } else if (!_c.cancelArmed) {
      widget.onTooShort();
    }
  }

  void _move(double dx) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toStart = rtl ? dx : -dx;
    _c.setCancelArmed(toStart >= VoiceMicButton.cancelDistance);
  }

  Future<void> _a11yTap() async {
    if (_c.recording) {
      _a11yToggle = false;
      await _end(send: true);
    } else {
      _a11yToggle = true;
      await _begin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final rec = _c.recording;
        return Semantics(
          button: true,
          label: rec ? l.chatVoiceStopSend : l.chatVoiceMic,
          onTap: _a11yTap,
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('voiceMicButton'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_a11yToggle) widget.onTooShort();
            },
            onLongPressStart: (_) => _begin(),
            onLongPressMoveUpdate: (d) => _move(d.offsetFromOrigin.dx),
            onLongPressEnd: (_) {
              _released = true;
              if (_c.recording && !_a11yToggle) _end(send: !_c.cancelArmed);
            },
            onLongPressCancel: () {
              _released = true;
              if (_c.recording && !_a11yToggle) _end(send: false);
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  width: rec ? 52 : 44,
                  height: rec ? 52 : 44,
                  decoration: BoxDecoration(
                    color: rec ? (_c.cancelArmed ? t.danger : t.pr) : t.sf2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(BuIcons.mic, size: 24, color: rec ? t.onPr : t.ink),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kayıt sırasında yazma alanının yerini alan çubuk: kırmızı nokta + süre + canlı seviye çubukları + iptal ipucu.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({super.key, required this.controller});

  final VoiceRecordController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final time = formatMediaDuration(controller.elapsedMs);
        final armed = controller.cancelArmed;
        return Semantics(
          liveRegion: true,
          label: l.chatVoiceRecording(time),
          child: Container(
            key: const ValueKey('voiceRecordingBar'),
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.sf,
              border: Border.all(color: armed ? t.danger : t.bd),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Icon(BuIcons.mic, size: 18, color: t.danger),
              const SizedBox(width: 8),
              Text(time, style: tx.bodyLarge!.copyWith(color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: VoiceLevelPainter(controller.levels, t.ink),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  armed ? l.chatVoiceCancel : l.chatVoiceSlideCancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.labelMedium!.copyWith(color: armed ? t.danger : t.mut),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Canlı seviye çubukları (son 48 örnek; yeni örnek sağda/sonda).
class VoiceLevelPainter extends CustomPainter {
  VoiceLevelPainter(this.levels, this.color);

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 3.0, gap = 3.0;
    final n = (size.width / (w + gap)).floor();
    if (n <= 0) return;
    final p = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    final shown = levels.length > n ? levels.sublist(levels.length - n) : levels;
    final mid = size.height / 2;
    for (var i = 0; i < n; i++) {
      final idx = i - (n - shown.length);
      final v = idx < 0 ? 0.0 : shown[idx];
      final h = (3 + v * (size.height - 3)).clamp(3.0, size.height);
      final x = i * (w + gap) + w / 2;
      p.color = color.withValues(alpha: idx < 0 ? .25 : .9);
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(VoiceLevelPainter old) => old.levels.length != levels.length || old.color != color ||
      (levels.isNotEmpty && old.levels.isNotEmpty && old.levels.last != levels.last);
}
