import 'package:flutter/widgets.dart';

import '../theme/bu_motion.dart';

/// İskelet -> içerik geçişi: yükleme bitince iskelet solarak gider, içerik solarak gelir (yalnız `opacity`).
///
/// Kullanım: `BuSwapIn(loading: !loaded, skeleton: const BuListSkeleton(), child: liste)`.
/// Boyut değişimi animasyonlanmaz (düzen kayması yok); iki çocuk da üstten hizalı üst üste biner.
/// "Animasyonları azalt" açıksa geçiş anlıktır. Katman [RepaintBoundary] ile ayrılır.
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
    final d = BuMotion.of(context, duration);
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: d,
        reverseDuration: d,
        switchInCurve: BuMotion.standard,
        switchOutCurve: BuMotion.standard,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),
        child: loading
            ? KeyedSubtree(key: _skeletonKey, child: skeleton)
            : KeyedSubtree(key: _contentKey, child: child),
      ),
    );
  }
}
