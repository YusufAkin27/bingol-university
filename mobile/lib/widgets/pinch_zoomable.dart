import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../core/theme.dart';
import 'bu_pressable.dart';

/// Gönderi görseli/videosu için "iki parmakla aç" yakınlaştırması (Instagram benzeri).
///
/// Davranış:
/// - Yalnız **iki parmak** tetikler. Tek parmak hiçbir şeyi çalmaz: liste/carousel kaydırması, dokunma ve çift
///   dokunuş (beğeni) aynen çalışır. Jest, kendi [ScaleGestureRecognizer]'sız küçük bir tanıyıcıyla kurulur ve
///   gesture arena'da **ikinci parmak inince** kazanır; böylece tek parmaklı yatay/dikey sürükleme tanıyıcıları
///   (liste, `PageView`) o dokunuş için reddedilir = kaydırma geçici kilitlenir.
/// - Görsel, kök [Overlay]'e (alt çubuk dahil her şeyin üstüne) yükselir; arka plan hafif kararır (en çok 0.6).
///   Ölçek 1x-4x; iki parmağı kaydırmak (pan) yakınlaştırılmış görselde gezdirir.
/// - Parmaklar kalkınca (biri kalksa bile) görsel ~250 ms yaylanarak eski yerine döner; "animasyonları azalt"
///   açıksa anında. Yakınlaştırma kalıcı değildir (kalıcı yakınlaştırma yalnız tam ekran görüntüleyicidedir).
/// - Eşik geçişinde (ilk ~%10) hafif titreşim.
///
/// Yakınlaştırılan kopya iki yoldan gelir:
/// - [overlayBuilder] verilirse (fotoğraf) o kopya kurulur: yüklü görsel önbellekten, gerekirse yüksek çözünürlüklü
///   katmanla. Ek ağ isteği yoktur.
/// - Verilmezse (video) çocuğun o anki karesi `RepaintBoundary.toImage` ile alınır (oynatıcı ikinci kez kurulmaz).
///
/// Ekran okuyucu için çocuğun anlamsal etiketi korunur; bu sarmalayıcı anlamsal düğüm eklemez, yalnız jesttir.
class PinchZoomable extends StatefulWidget {
  const PinchZoomable({super.key, required this.child, this.overlayBuilder, this.enabled = true, this.maxScale = 4});

  final Widget child;

  /// Yakınlaştırılan kopyanın kurucusu (kutu boyutu = çocuğun boyutu, sıkı kısıtla verilir).
  final WidgetBuilder? overlayBuilder;
  final bool enabled;
  final double maxScale;

  /// Yaylanarak geri dönüşün yaklaşık süresi (testler için).
  static const Duration settle = Duration(milliseconds: 300);

  @override
  State<PinchZoomable> createState() => _PinchZoomableState();
}

class _PinchZoomableState extends State<PinchZoomable> with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  final _repaint = ValueNotifier<int>(0);
  late final AnimationController _back = AnimationController(vsync: this);

  OverlayEntry? _entry;
  Rect _rect = Rect.zero;
  Offset _f0 = Offset.zero;
  Offset _focal = Offset.zero;
  double _scale = 1;
  bool _buzzed = false;
  bool _releasing = false;
  ui.Image? _snap;
  int _session = 0;

  @override
  void dispose() {
    _session++;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _snap?.dispose();
    _snap = null;
    _back.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _start(Offset focal) {
    if (!widget.enabled || !mounted) return;
    _dropEntry();
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _session++;
    final mine = _session;
    _rect = box.localToGlobal(Offset.zero) & box.size;
    _f0 = focal;
    _focal = focal;
    _scale = 1;
    _buzzed = false;
    _releasing = false;
    final scrim = context.bu.scrim;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(builder: (ctx) => _layer(ctx, scrim));
    overlay.insert(_entry!);
    if (widget.overlayBuilder == null) _capture(mine);
  }

  /// Çocuğun o anki karesi (video): tek seferlik anlık görüntü; hazır olunca kopyada görünür.
  Future<void> _capture(int mine) async {
    try {
      final b = _boundaryKey.currentContext?.findRenderObject();
      if (b is! RenderRepaintBoundary) return;
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final img = await b.toImage(pixelRatio: math.min(dpr * 1.5, 4));
      if (!mounted || mine != _session) {
        img.dispose();
        return;
      }
      _snap?.dispose();
      _snap = img;
      _repaint.value++;
    } catch (_) {
      // Kare alınamazsa kopya boş kalır; jest yine zararsız biter.
    }
  }

  void _update(double raw, Offset focal) {
    if (_entry == null || _releasing) return;
    _scale = raw.clamp(1.0, widget.maxScale);
    _focal = focal;
    if (!_buzzed && _scale > 1.1) {
      _buzzed = true;
      buHaptic(BuHaptic.light);
    }
    _repaint.value++;
  }

  void _end() {
    if (_entry == null || _releasing) return;
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (calm || _scale <= 1.001 && _focal == _f0) {
      _dropEntry();
      return;
    }
    _releasing = true;
    final mine = _session;
    // Kritik sönümlü yay: taşma yok, ~250 ms de oturur.
    final spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 900, ratio: 1);
    _back.value = 0;
    _back.animateWith(SpringSimulation(spring, 0, 1, 0, tolerance: const Tolerance(distance: 0.01, velocity: 0.2))).whenComplete(() {
      if (mounted && mine == _session) _dropEntry();
    });
  }

  void _dropEntry() {
    if (_back.isAnimating) _back.stop();
    _releasing = false;
    final e = _entry;
    _entry = null;
    if (e != null) {
      e.remove();
      e.dispose();
    }
    _snap?.dispose();
    _snap = null;
    _scale = 1;
  }

  Widget _layer(BuildContext ctx, Color scrim) {
    return AnimatedBuilder(
      animation: Listenable.merge([_repaint, _back]),
      builder: (ctx, _) {
        final k = _releasing ? (1 - _back.value).clamp(0.0, 1.0) : 1.0;
        final s = 1 + (_scale - 1) * k;
        final tx = (_focal.dx - _rect.left + _scale * (_rect.left - _f0.dx)) * k;
        final ty = (_focal.dy - _rect.top + _scale * (_rect.top - _f0.dy)) * k;
        final dim = 0.6 * ((s - 1) / 0.6).clamp(0.0, 1.0);
        final Widget content;
        final builder = widget.overlayBuilder;
        if (builder != null) {
          content = builder(ctx);
        } else if (_snap != null) {
          content = RawImage(image: _snap, fit: BoxFit.fill);
        } else {
          content = const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: scrim.withValues(alpha: dim))),
            Positioned.fromRect(
              rect: _rect,
              child: Transform(
                transform: Matrix4.identity()
                  ..setTranslationRaw(tx, ty, 0)
                  ..scaleByDouble(s, s, 1, 1),
                child: ExcludeSemantics(child: RepaintBoundary(child: content)),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _TwoFingerRecognizer: GestureRecognizerFactoryWithHandlers<_TwoFingerRecognizer>(
          () => _TwoFingerRecognizer(debugOwner: this),
          (r) => r
            ..onStart = _start
            ..onUpdate = _update
            ..onEnd = _end,
        ),
      },
      child: RepaintBoundary(key: _boundaryKey, child: widget.child),
    );
  }
}

/// Yalnız iki parmak inince kazanan tanıyıcı. Tek parmakta arena'ya girer ama hiçbir şey talep etmez; parmak
/// kalkınca kendini reddeder (böylece dokunma/çift dokunuş tanıyıcıları normal kazanır).
class _TwoFingerRecognizer extends OneSequenceGestureRecognizer {
  _TwoFingerRecognizer({super.debugOwner});

  void Function(Offset focal)? onStart;
  void Function(double scale, Offset focal)? onUpdate;
  VoidCallback? onEnd;

  final _pos = <int, Offset>{};
  final _lost = <int>{};
  List<int> _ids = const [];
  double _span0 = 1;
  bool _active = false;

  Offset get _focal => (_pos[_ids[0]]! + _pos[_ids[1]]!) / 2;
  double get _span => (_pos[_ids[0]]! - _pos[_ids[1]]!).distance;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pos[event.pointer] = event.position;
    if (!_active && _pos.length >= 2) {
      _begin();
    } else if (_active) {
      resolvePointer(event.pointer, GestureDisposition.accepted); // 3. parmak da bu jestin
    }
  }

  void _begin() {
    _ids = _pos.keys.take(2).toList();
    _span0 = math.max(_span, 40);
    _active = true;
    for (final p in _pos.keys.toList()) {
      if (!_lost.contains(p)) resolvePointer(p, GestureDisposition.accepted);
    }
    onStart?.call(_focal);
  }

  @override
  void handleEvent(PointerEvent event) {
    final id = event.pointer;
    if (event is PointerMoveEvent) {
      _pos[id] = event.position;
      if (_active && _ids.contains(id) && _ids.every(_pos.containsKey)) {
        onUpdate?.call(_span / _span0, _focal);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final wasActive = _active && _ids.contains(id);
      _pos.remove(id);
      if (wasActive) {
        _active = false;
        onEnd?.call();
      } else if (!_active && !_lost.contains(id)) {
        // Tek parmak serbest bırakıldı: sweep'te "ilk üye kazanır" kuralıyla dokunmayı çalmayalım.
        resolvePointer(id, GestureDisposition.rejected);
      }
      _lost.remove(id);
      stopTrackingPointer(id);
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _lost.add(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pos.clear();
    _lost.clear();
    if (_active) {
      _active = false;
      onEnd?.call();
    }
  }

  @override
  String get debugDescription => 'pinchZoom';
}
