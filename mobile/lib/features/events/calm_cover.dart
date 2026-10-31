import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';

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
    // Tek sakin ton: yumuşak marka zemini + nötr daireler (kategori/kulüp başına farklı renk yok); [seed] yalnız eski çağrılar için.
    final tint = (bg: t.soft, fg: t.onSoft);
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
            // Tek seferlik çok ince giriş: simge solarak ve %90 -> %100 ölçekle belirir (sürekli döngü yok; azaltılmışsa anında).
            Align(
              alignment: iconAlignment,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: BuMotion.of(context, BuMotion.long),
                curve: BuMotion.emphasizedDecelerate,
                child: Icon(icon, size: 44, color: tint.fg.withValues(alpha: .28)),
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .9 + .1 * v, child: child)),
              ),
            ),
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
