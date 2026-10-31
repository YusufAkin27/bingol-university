import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Kapak fotoğrafı olmayan kulüp/etkinlik için sakin yer tutucu: düz kırmızı vitrin yerine paletin yumuşak
/// kategori tonlarından biri ([seed] ile kararlı seçilir; yeni renk yok), çok hafif iki daire ve büyük silik simge.
/// Üstüne yazı koyulmaz; yalnız kapak alanını doldurur. RTL'de simge ve daireler aynalanır (mantıksal yön).
class CalmCover extends StatelessWidget {
  const CalmCover({super.key, required this.seed, required this.icon, this.iconAlignment = AlignmentDirectional.center});

  final int seed;
  final IconData icon;
  final AlignmentGeometry iconAlignment;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tint = t.tint(seed);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tint.bg, Color.lerp(tint.bg, tint.fg, .14)!],
            ),
          ),
          child: Stack(fit: StackFit.expand, children: [
            PositionedDirectional(
              end: -36,
              top: -48,
              child: _Disc(size: 170, color: tint.fg.withValues(alpha: .07)),
            ),
            PositionedDirectional(
              start: -28,
              bottom: -52,
              child: _Disc(size: 130, color: tint.fg.withValues(alpha: .05)),
            ),
            Align(alignment: iconAlignment, child: Icon(icon, size: 44, color: tint.fg.withValues(alpha: .28))),
          ]),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
