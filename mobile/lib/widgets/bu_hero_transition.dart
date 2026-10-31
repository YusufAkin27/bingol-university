import 'package:flutter/material.dart';

import '../core/theme/bu_motion.dart';

/// Liste -> detay görsel geçişi için `Hero` sarmalayıcısı: uçuş sırasında köşe yarıçapı kaynak ve hedef arasında
/// yumuşakça geçer (kart 16 dp -> tam ekran kapak 0 dp). "Animasyonları azalt" açıkken rota süresi zaten sıfırdır.
///
/// ```dart
/// // Liste kartı:
/// BuHero(tag: BuHero.tagOf('news', id), radius: 16, child: BuImage(...))
/// // Detay kapağı (aynı etiket):
/// BuHero(tag: BuHero.tagOf('news', id), radius: 0, child: BuImage(...))
/// ```
///
/// Kurallar: etiket sayfada **benzersiz** olmalı (yineleyen etiket framework hatası verir; liste öğesine kimlik
/// ekleyin). Çocuk boyutu sınırlardan türesin (sabit boyut yerine kapsayıcıyı doldurun). Uçuş yalnız `transform`/
/// kırpma yarıçapı değiştirir; görseli yeniden yüklemez.
class BuHero extends StatelessWidget {
  const BuHero({
    super.key,
    required this.tag,
    required this.child,
    this.radius = 0,
    this.transitionOnUserGestures = false,
  });

  /// Benzersiz etiket üretici: `BuHero.tagOf('news', 12)` -> `bu-hero-news-12`.
  static String tagOf(String kind, Object id) => 'bu-hero-$kind-$id';

  final Object tag;
  final Widget child;

  /// Bu uçtaki köşe yarıçapı (dp). Kaynak ve hedef farklıysa uçuşta ikisi arasında geçilir.
  final double radius;

  /// iOS kenar kaydırma geri jestinde de uçuş (varsayılan kapalı: Android tahmini geri ile çakışmasın).
  final bool transitionOnUserGestures;

  @override
  Widget build(BuildContext context) {
    final inner = radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child) : child;
    return Hero(
      tag: tag,
      transitionOnUserGestures: transitionOnUserGestures,
      flightShuttleBuilder: _shuttle,
      child: inner,
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = fromHeroContext.findAncestorWidgetOfExactType<BuHero>();
    final to = toHeroContext.findAncestorWidgetOfExactType<BuHero>();
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;
    // Gidişte hedefin, dönüşte kaynağın (şu an ekrandaki) görünümü uçar.
    final shown = direction == HeroFlightDirection.push ? (to?.child ?? toHero.child) : (from?.child ?? fromHero.child);
    final r0 = from?.radius ?? 0;
    final r1 = to?.radius ?? 0;
    if (r0 == r1) return r0 > 0 ? ClipRRect(borderRadius: BorderRadius.circular(r0), child: shown) : shown;
    final push = direction == HeroFlightDirection.push;
    return AnimatedBuilder(
      animation: animation,
      child: shown,
      builder: (context, c) {
        // Rota animasyonu itişte 0->1, dönüşte 1->0 gider; ilerleme her iki yönde kaynak -> hedef olsun.
        final p = BuMotion.emphasized.transform((push ? animation.value : 1 - animation.value).clamp(0.0, 1.0));
        final r = r0 + (r1 - r0) * p;
        return ClipRRect(borderRadius: BorderRadius.circular(r < 0 ? 0 : r), child: c);
      },
    );
  }
}
