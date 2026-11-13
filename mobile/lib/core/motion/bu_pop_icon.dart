import 'package:flutter/widgets.dart';

import '../theme/bu_motion.dart';

/// Durum değiştiren ikon (kalp, kaydet, zil, sessize al...): [icon] değişince tek ikon yaylanarak "pop" yapar
/// (ölçek 0.55 -> hafif aşım -> 1, opaklık 0.3 -> 1), [color] değişince renk yumuşakça geçer.
///
/// Tek bir `Icon` çizilir (eski ikon ağaçta kalmaz; `find.byIcon` testleri bozulmaz). İlk çizimde animasyon yoktur;
/// "animasyonları azalt" açıkken ikon ve renk anında değişir. Yalnız `transform`/`opacity` canlandırılır.
class BuPopIcon extends StatefulWidget {
  const BuPopIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// Pop süresi (BuMotion.medium ile uyumlu, yaylanma payı için biraz uzun).
  static const Duration duration = Duration(milliseconds: 320);

  @override
  State<BuPopIcon> createState() => _BuPopIconState();
}

class _BuPopIconState extends State<BuPopIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BuPopIcon.duration, value: 1);

  @override
  void didUpdateWidget(BuPopIcon old) {
    super.didUpdateWidget(old);
    if (old.icon != widget.icon && !BuMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BuMotion.reduced(context);
    final color = widget.color;
    Widget icon = Icon(widget.icon, size: widget.size, color: color, semanticLabel: widget.semanticLabel);
    if (color != null && !reduced) {
      icon = TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: BuMotion.short,
        builder: (_, c, __) => Icon(widget.icon, size: widget.size, color: c ?? color, semanticLabel: widget.semanticLabel),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _c.value;
        if (v >= 1) return child!;
        final s = .55 + .45 * Curves.easeOutBack.transform(v);
        return Opacity(opacity: (.3 + .7 * Curves.easeOut.transform(v)).clamp(0.0, 1.0), child: Transform.scale(scale: s, child: child));
      },
      child: icon,
    );
  }
}
