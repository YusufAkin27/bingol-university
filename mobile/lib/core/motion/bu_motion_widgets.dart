import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'bu_motion.dart';

/// Giriş: solma + kısa yükselme (varsayılan 12 dp), bir kez oynar. [index] ile liste kademesi
/// ([BuMotion.stagger]: 60 ms × en çok 6); [animate] false ise doğrudan gösterir (uzun listede görünür
/// olmayan öğeler için). "Animasyonları azalt" açıksa kayma yok, yalnız 100 ms solma.
///
/// Yalnız `opacity` + `transform` canlandırılır; çocuk yeniden düzenlenmez.
class BuFadeSlideIn extends StatefulWidget {
  const BuFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.duration,
    this.animate = true,
    this.axis = Axis.vertical,
  });

  final Widget child;

  /// Liste sırası (kademe gecikmesi için); tek öğede 0.
  final int index;

  /// Başlangıç kayması (dp); dikeyde aşağıdan, yatayda yazı yönünün sonundan gelir.
  final double offset;

  /// Verilmezse [BuDurations.standard].
  final Duration? duration;
  final bool animate;
  final Axis axis;

  @override
  State<BuFadeSlideIn> createState() => _BuFadeSlideInState();
}

class _BuFadeSlideInState extends State<BuFadeSlideIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _t;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || !widget.animate) return;
    _reduced = BuMotion.reduced(context);
    final dur = widget.duration ?? BuMotion.durations.standard;
    final delay = _reduced ? Duration.zero : BuMotion.stagger(widget.index);
    final fade = _reduced ? BuMotion.durations.reducedFade : dur;
    final total = delay + fade;
    final c = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: c,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: BuMotion.curves.emphasizedDecelerate),
    );
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) {
        final v = t.value;
        if (v >= 1) return child!;
        final d = _reduced ? 0.0 : widget.offset * (1 - v);
        final off = widget.axis == Axis.vertical ? Offset(0, d) : Offset(rtl ? -d : d, 0);
        return Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: off, child: child));
      },
    );
  }
}

/// Yükleniyor -> içerik -> hata gibi durum değişimi geçişi. [state] değişince eski çocuk 0.7× sürede solar,
/// yenisi solarak + 8 dp yükselerek gelir (yalnız opaklık değil). İki çocuk üst üste biner, boyut animasyonu yok.
/// "Animasyonları azalt" açıksa yalnız 100 ms solma.
///
/// ```dart
/// BuStateSwitcher(state: loading ? 'load' : error != null ? 'err' : 'ok', child: ...)
/// ```
class BuStateSwitcher extends StatelessWidget {
  const BuStateSwitcher({super.key, required this.state, required this.child, this.duration, this.alignment = Alignment.topCenter});

  /// Durum anahtarı; `==` ile karşılaştırılır (String, enum, int).
  final Object state;
  final Widget child;
  final Duration? duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reduced = BuMotion.reduced(context);
    final dur = reduced ? BuMotion.durations.reducedFade : (duration ?? BuMotion.durations.standard);
    return AnimatedSwitcher(
      duration: dur,
      reverseDuration: BuMotion.exit(dur),
      switchInCurve: BuMotion.curves.emphasizedDecelerate,
      switchOutCurve: BuMotion.curves.accelerate,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (c, anim) {
        final fade = FadeTransition(opacity: anim, child: c);
        if (reduced) return fade;
        return AnimatedBuilder(
          animation: anim,
          child: fade,
          builder: (context, ch) => Transform.translate(offset: Offset(0, 8 * (1 - anim.value)), child: ch),
        );
      },
      child: KeyedSubtree(key: ValueKey<Object>(state), child: child),
    );
  }
}

/// Hata sarsıntısı: [trigger] değişince çocuk yatayda 2,5 salınımla (sönümlü, ±[amplitude] dp) sallanır;
/// 320 ms, taşma/ölçek yok. İlk kurulumda oynamaz. "Animasyonları azalt" açıksa oynamaz (hata metin/renkle
/// zaten belirtilir).
class BuShake extends StatefulWidget {
  const BuShake({super.key, required this.trigger, required this.child, this.amplitude = 6});

  final Object? trigger;
  final Widget child;
  final double amplitude;

  /// Sönümlü sinüs: `sin(2π · 2,5 · t) · (1 − t)`; t = 0..1.
  static double offsetAt(double t, double amplitude) => math.sin(2 * math.pi * 2.5 * t) * (1 - t) * amplitude;

  @override
  State<BuShake> createState() => _BuShakeState();
}

class _BuShakeState extends State<BuShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BuMotion.durations.shake);

  @override
  void didUpdateWidget(BuShake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !BuMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          if (!_c.isAnimating) return child!;
          return Transform.translate(offset: Offset(BuShake.offsetAt(_c.value, widget.amplitude), 0), child: child);
        },
      );
}
