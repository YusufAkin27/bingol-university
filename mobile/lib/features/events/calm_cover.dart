import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';

/// Kapak fotoğrafı olmayan kulüp/etkinlik için sakin yer tutucu: düz nötr yüzey (`sf2`) + büyük silik simge
/// (gradyan/daire süsü yok). Üstüne yazı koyulmaz; yalnız kapak alanını doldurur. RTL'de simge aynalanır (mantıksal yön).
class CalmCover extends StatelessWidget {
  const CalmCover({super.key, required this.seed, required this.icon, this.iconAlignment = AlignmentDirectional.center});

  final int seed;
  final IconData icon;
  final AlignmentGeometry iconAlignment;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Tek nötr ton (kategori/kulüp başına farklı renk yok); [seed] yalnız eski çağrılar için.
    final tint = (bg: t.sf2, fg: t.ink);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint.bg),
          child: Stack(fit: StackFit.expand, children: [
            // Tek seferlik çok ince giriş: simge solarak ve %90 -> %100 ölçekle belirir (sürekli döngü yok; azaltılmışsa anında).
            Align(
              alignment: iconAlignment,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: BuMotion.of(context, BuMotion.long),
                curve: BuMotion.emphasizedDecelerate,
                child: Icon(icon, size: 44, color: tint.fg.withValues(alpha: .22)),
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .9 + .1 * v, child: child)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
