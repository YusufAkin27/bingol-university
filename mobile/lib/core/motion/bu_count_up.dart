import 'package:flutter/widgets.dart';

import '../theme/bu_motion.dart';

/// Sayıyı eski değerinden yenisine sayarak gösterir (istatistik, sayaç). İlk görünümde 0'dan sayar
/// ([animateFirst] false ise doğrudan değeri gösterir). Ekran okuyucu yalnız son değeri okur.
/// "Animasyonları azalt" açıksa anında son değer.
class BuCountUp extends StatelessWidget {
  const BuCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = BuMotion.long,
    this.animateFirst = true,
    this.format,
    this.textAlign,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final bool animateFirst;
  final TextAlign? textAlign;

  /// Sayı biçimleyici (binlik ayracı vb.); verilmezse düz sayı.
  final String Function(int)? format;

  String _fmt(int v) => format?.call(v) ?? '$v';

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, duration);
    return Semantics(
      label: _fmt(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: animateFirst ? 0 : value.toDouble(), end: value.toDouble()),
        duration: d,
        curve: BuMotion.emphasizedDecelerate,
        builder: (context, v, _) => Text(
          _fmt(v.round()),
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// Küçük "pop": [trigger] değişince çocuk bir kez 1 -> [peak] -> 1 ölçeklenir (beğeni, rozet sayısı).
/// İlk kurulumda oynamaz. Yalnız `transform`; "animasyonları azalt" açıksa hiç oynamaz.
class BuPop extends StatefulWidget {
  const BuPop({super.key, required this.trigger, required this.child, this.peak = 1.18});

  /// Değiştiğinde (`!=`) animasyon oynar; ör. sayaç değeri ya da beğeni durumu.
  final Object? trigger;
  final Widget child;
  final double peak;

  @override
  State<BuPop> createState() => _BuPopState();
}

class _BuPopState extends State<BuPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BuMotion.medium);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.peak).chain(CurveTween(curve: BuMotion.emphasizedDecelerate)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: widget.peak, end: 1.0).chain(CurveTween(curve: BuMotion.standard)), weight: 60),
  ]).animate(_c);

  @override
  void didUpdateWidget(BuPop old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !BuMotion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}
