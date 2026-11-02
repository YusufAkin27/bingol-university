import 'package:flutter/widgets.dart';

import '../theme/bu_motion.dart';

/// İskelet -> içerik geçişi: yükleme bitince iskelet 0,7× sürede solarak gider, içerik solarak ve 8 dp yükselerek
/// gelir (yalnız `opacity` + `transform`; durum değişimi opaklıkla sınırlı kalmaz).
///
/// Kullanım: `BuSwapIn(loading: !loaded, skeleton: const BuListSkeleton(), child: liste)`.
/// Boyut değişimi animasyonlanmaz (düzen kayması yok); iki çocuk da üstten hizalı üst üste biner.
/// "Animasyonları azalt" açıksa yalnız 100 ms'lik solma (kayma yok). Katman [RepaintBoundary] ile ayrılır.
class BuSwapIn extends StatelessWidget {
  const BuSwapIn({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.duration = BuMotion.medium,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;
  final Duration duration;

  static const _skeletonKey = ValueKey<String>('bu-swap-skeleton');
  static const _contentKey = ValueKey<String>('bu-swap-content');

  @override
  Widget build(BuildContext context) {
    final reduced = BuMotion.reduced(context);
    final d = BuMotion.fadeOf(context, duration);
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: d,
        reverseDuration: reduced ? d : BuMotion.exit(d),
        switchInCurve: BuMotion.curves.emphasizedDecelerate,
        switchOutCurve: BuMotion.curves.accelerate,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (c, anim) {
          final fade = FadeTransition(opacity: anim, child: c);
          if (reduced || c.key != _contentKey) return fade;
          return AnimatedBuilder(
            animation: anim,
            child: fade,
            builder: (context, ch) => Transform.translate(offset: Offset(0, 8 * (1 - anim.value)), child: ch),
          );
        },
        child: loading
            ? KeyedSubtree(key: _skeletonKey, child: skeleton)
            : KeyedSubtree(key: _contentKey, child: child),
      ),
    );
  }
}
