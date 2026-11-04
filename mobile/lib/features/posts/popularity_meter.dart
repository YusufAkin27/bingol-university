import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Popülerlik puanı göstergesi (0..100): "Popülerlik" etiketi + ince çubuk + sayı. Puanı SUNUCU hesaplar (log-ölçekli
/// beğeni, yazar takipçisi, beğeni hızı, izlenme, taze bonus, şikâyet cezası); burada yalnız gerçek sayı çizilir,
/// uydurma rozet/ödül yoktur. [onMedia] true: koyu (video/foto) zemin üstünde açık renkler.
class PopularityMeter extends StatelessWidget {
  const PopularityMeter({super.key, required this.score, this.onMedia = false, this.width = 96});

  final int score;
  final bool onMedia;

  /// Çubuğun uzunluğu (dp).
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final s = score.clamp(0, 100);
    final ink = onMedia ? t.onMedia : t.ink;
    final soft = onMedia ? t.onMedia.withValues(alpha: .75) : t.mut;
    final track = onMedia ? t.onMedia.withValues(alpha: .28) : t.sf2;
    final fill = onMedia ? t.onMedia : t.pr;
    return Semantics(
      container: true,
      label: context.l10n.kesPopularityOf('$s'),
      excludeSemantics: true,
      child: Row(key: const ValueKey('popularityMeter'), mainAxisSize: MainAxisSize.min, children: [
        Text(context.l10n.kesPopularity, style: tt.labelMedium?.copyWith(color: soft, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        SizedBox(
          width: width,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: track)),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: s / 100,
                  child: ColoredBox(key: const ValueKey('popularityFill'), color: fill),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('$s',
            key: const ValueKey('popularityValue'),
            style: tt.labelMedium?.copyWith(
                color: ink, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
