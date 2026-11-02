import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_sizes.dart';

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

/// Görünür kutu küçükken (çip 34, düğme 34 dp, 44 dp'lik çip) dokunma alanını en az [BuSize.touch] (48 dp) yapar; görünür
/// kutuyu ortalar, çevresindeki boşluk da basılabilir (dıştaki `BuPressable`/`GestureDetector`/`InkWell` bu kutunun
/// tamamını yakalar: bu sarmalayıcıyı onların İÇİNE koyun). Görünür boyut AYNI kalır; yalnız yerleşim kutusu büyür.
///
/// [axis] verilirse yalnız o eksende büyür: geniş çiplerde (`Axis.vertical`) genişlik hiç değişmez.
///
/// ```dart
/// BuPressable(onTap: f, child: BuTouchTarget(axis: Axis.vertical, child: chip))
/// ```
class BuTouchTarget extends StatelessWidget {
  const BuTouchTarget({super.key, required this.child, this.minSize = BuSize.touch, this.axis});

  final Widget child;
  final double minSize;

  /// null: iki eksen; [Axis.vertical]: yalnız yükseklik; [Axis.horizontal]: yalnız genişlik.
  final Axis? axis;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: axis == Axis.horizontal ? 0 : minSize,
          minWidth: axis == Axis.vertical ? 0 : minSize,
        ),
        // heightFactor: 1 -> sınırlı yükseklikli üst kutuda (Row/SizedBox) bile gereğinden fazla uzamaz.
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      );
}

/// Basılı tutunca hafifçe küçülen (0.97, 120 ms) ve hafifçe solan (opaklık ~0.92) dokunma sarmalayıcısı; bırakınca
/// 300 ms'de yerleşir (BuMotion.curves.settle). İki kullanım:
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

  /// Basılıyken opaklık (1 = solma yok). Ölçekle birlikte 120 ms'de, "animasyonları azalt" açıkken hiç uygulanmaz.
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
    // Basma <150 ms (micro 120), bırakınca 200-300 ms'de hafif taşmayla (~%3) yerleşir.
    const d = BuMotion.durations;
    Widget c = AnimatedScale(
      scale: pressed ? widget.scale : 1,
      duration: pressed ? d.micro : d.standard,
      curve: pressed ? BuMotion.curves.standard : BuMotion.curves.settle,
      child: AnimatedOpacity(
        opacity: pressed ? widget.pressedOpacity : 1,
        duration: d.micro,
        curve: BuMotion.curves.standard,
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
