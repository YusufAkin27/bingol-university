import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme/bu_motion.dart';

/// Dokunma geri bildirimi türü.
enum BuHaptic { none, selection, light, medium }

/// Hafif dokunma titreşimi (tek yerden: testte ve titreşimsiz cihazda sessizce yutulur). [BuHaptics] sarmalayıcısına
/// yönlenir; eski çağıranlar için imza korunur.
void buHaptic([BuHaptic kind = BuHaptic.selection]) {
  switch (kind) {
    case BuHaptic.none:
      return;
    case BuHaptic.selection:
      BuHaptics.selection();
    case BuHaptic.light:
      BuHaptics.light();
    case BuHaptic.medium:
      BuHaptics.medium();
  }
}

/// Basılı tutunca hafifçe küçülen (0.97) ve hafifçe solan (opaklık ~0.92) dokunma sarmalayıcısı. İki kullanım:
///
/// * `onTap` verilirse dokunmayı kendisi yakalar (anlamsal düğme + titreşim).
/// * `onTap` null ise yalnız ölçek efekti verir; dokunmayı içerideki `InkWell` yakalar (kart/satır).
///
/// Ölçek `Transform` ile yapılır (yeniden düzen yok); parmak [kTouchSlop]'tan fazla kayarsa (kaydırma) geri döner.
/// "Animasyonları azalt" açıkken ölçek uygulanmaz.
class BuPressable extends StatefulWidget {
  const BuPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .97,
    this.pressedOpacity = .92,
    this.haptic = BuHaptic.none,
    this.enabled = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Basılıyken ölçek (0.9-1.0).
  final double scale;

  /// Basılıyken opaklık (1 = solma yok). Ölçekle birlikte 100 ms'de, "animasyonları azalt" açıkken hiç uygulanmaz.
  final double pressedOpacity;

  /// Dokunuşta titreşim ([onTap] ile birlikte).
  final BuHaptic haptic;
  final bool enabled;

  /// Yalnız [onTap] verildiğinde: ekran okuyucu etiketi (içerik metni yetmiyorsa).
  final String? semanticLabel;
  final HitTestBehavior behavior;

  @override
  State<BuPressable> createState() => _BuPressableState();
}

class _BuPressableState extends State<BuPressable> {
  bool _down = false;
  Offset? _origin;

  bool get _active => widget.enabled && !BuMotion.reduced(context);

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down && _active;
    Widget c = AnimatedScale(
      scale: pressed ? widget.scale : 1,
      duration: BuMotion.short,
      curve: BuMotion.standard,
      child: AnimatedOpacity(
        opacity: pressed ? widget.pressedOpacity : 1,
        duration: const Duration(milliseconds: 100),
        curve: BuMotion.standard,
        child: widget.child,
      ),
    );
    c = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _origin = e.position;
        if (widget.enabled) _set(true);
      },
      onPointerMove: (e) {
        final o = _origin;
        if (_down && o != null && (e.position - o).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: c,
    );
    if (widget.onTap == null && widget.onLongPress == null) return c;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                buHaptic(widget.haptic);
                widget.onTap!();
              }
            : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: c,
      ),
    );
  }
}
