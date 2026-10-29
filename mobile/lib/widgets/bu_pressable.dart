import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/bu_motion.dart';

/// Dokunma geri bildirimi türü.
enum BuHaptic { none, selection, light, medium }

/// Hafif dokunma titreşimi (tek yerden: testte ve titreşimsiz cihazda sessizce yutulur).
void buHaptic([BuHaptic kind = BuHaptic.selection]) {
  try {
    switch (kind) {
      case BuHaptic.none:
        return;
      case BuHaptic.selection:
        HapticFeedback.selectionClick();
      case BuHaptic.light:
        HapticFeedback.lightImpact();
      case BuHaptic.medium:
        HapticFeedback.mediumImpact();
    }
  } catch (_) {}
}

/// Basılı tutunca hafifçe küçülen (0.97) dokunma sarmalayıcısı. İki kullanım:
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
    Widget c = AnimatedScale(
      scale: _down && _active ? widget.scale : 1,
      duration: BuMotion.short,
      curve: BuMotion.standard,
      child: widget.child,
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
