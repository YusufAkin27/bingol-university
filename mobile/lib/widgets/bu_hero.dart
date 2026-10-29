import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_shape.dart';

/// Süs deseni türü.
enum BuHeroPattern {
  /// Büyük yarı saydam daireler (varsayılan).
  orbs,

  /// İç içe halkalar.
  rings,

  /// Yumuşak dalga şeritleri.
  waves,

  /// Desen yok, yalnız gradyan.
  none,
}

/// Vitrin yüzeyleri için sınırlı gradyan kart: marka kırmızısı gradyan + `CustomPainter` deseni.
/// Kullanım yeri YALNIZ vitrin: Ana Sayfa öne çıkan kart, etkinlik/kulüp kapağı, karşılama, profil başlığı.
/// Liste öğesi, form ve ayar ekranlarında kullanılmaz. İçerideki yazı/ikon `onMedia` (beyaz) renginde başlar.
/// Desen `RepaintBoundary` içinde bir kez boyanır; RTL'de aynalanır.
class BuGradientHero extends StatelessWidget {
  const BuGradientHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = BuRadius.xl,
    this.pattern = BuHeroPattern.orbs,
    this.minHeight,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BuHeroPattern pattern;
  final double? minHeight;

  /// Verilirse kart dokunulabilir (dalga efekti + düğme anlamı).
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final br = BorderRadius.circular(radius);
    Widget body = Stack(
      children: [
        if (pattern != BuHeroPattern.none)
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(painter: _HeroPainter(pattern, t.onMedia, rtl)),
              ),
            ),
          ),
        Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: t.onMedia),
            child: IconTheme.merge(data: IconThemeData(color: t.onMedia), child: child),
          ),
        ),
      ],
    );
    if (minHeight != null) body = ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight!), child: body);
    final deco = DecoratedBox(
      decoration: BoxDecoration(gradient: t.hero, borderRadius: br),
      child: onTap == null
          ? body
          : Material(
              type: MaterialType.transparency,
              child: InkWell(borderRadius: br, onTap: onTap, child: body),
            ),
    );
    final clipped = ClipRRect(borderRadius: br, child: deco);
    return semanticLabel == null && onTap == null
        ? clipped
        : Semantics(button: onTap != null, label: semanticLabel, container: true, child: clipped);
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.pattern, this.color, this.rtl);

  final BuHeroPattern pattern;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width, h = size.height;
    Paint fill(double a) => Paint()..color = color.withValues(alpha: a);
    Paint line(double a, double sw) => Paint()
      ..color = color.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    switch (pattern) {
      case BuHeroPattern.orbs:
        canvas.drawCircle(Offset(w + 10, -h * .15), math.min(w, h) * .62, fill(.13));
        canvas.drawCircle(Offset(w * .72, h + 20), math.min(w, h) * .46, fill(.09));
        canvas.drawCircle(Offset(w * .08, h * .1), math.min(w, h) * .12, fill(.06));
      case BuHeroPattern.rings:
        final c = Offset(w * .92, h * .18);
        for (var i = 1; i <= 4; i++) {
          canvas.drawCircle(c, 34.0 * i, line(.16 - i * .025, 1.6));
        }
        canvas.drawCircle(Offset(w * .1, h * 1.05), 60, fill(.08));
      case BuHeroPattern.waves:
        for (var i = 0; i < 3; i++) {
          final y = h * (.55 + i * .16);
          final p = Path()..moveTo(0, y);
          p.cubicTo(w * .25, y - 22, w * .5, y + 22, w * .75, y - 8);
          p.quadraticBezierTo(w * .9, y - 20, w, y - 6);
          p.lineTo(w, h);
          p.lineTo(0, h);
          p.close();
          canvas.drawPath(p, fill(.07 + i * .02));
        }
        canvas.drawCircle(Offset(w * .88, h * .2), 26, fill(.12));
      case BuHeroPattern.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.pattern != pattern || old.color != color || old.rtl != rtl;
}

/// Adım göstergesi: çubuk dizisi (tamamlanan/geçerli adımlar marka renginde, dolum animasyonlu) + isteğe bağlı etiketler.
/// Ekran okuyucu "Adım 2 / 3" okur. [current] sıfır tabanlıdır (0 = ilk adım).
class BuProgressSteps extends StatelessWidget {
  const BuProgressSteps({super.key, required this.count, required this.current, this.labels, this.height = 6})
      : assert(count > 0);

  final int count;
  final int current;

  /// Çubukların altında yazılan adım adları (uzunluk [count]).
  final List<String>? labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cur = current.clamp(0, count - 1);
    return Semantics(
      label: context.l10n.p00StepOf('${cur + 1}', '$count'),
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _Segment(done: i <= cur, height: height, active: i == cur),
                  ),
                ],
              ],
            ),
            if (labels != null && labels!.length == count) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        labels![i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: tx.labelSmall!.copyWith(
                          color: i <= cur ? t.ink : t.mut,
                          fontWeight: i == cur ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.done, required this.height, required this.active});

  final bool done;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: done ? 1 : 0),
      duration: BuMotion.of(context, BuMotion.medium),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: t.sf2)),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: v,
                  child: ColoredBox(color: active ? t.pr : t.pr.withValues(alpha: .6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
