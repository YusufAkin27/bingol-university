import 'package:flutter/material.dart';

import '../theme.dart';

/// Yükseklik/gölge sistemi. Açık temada iki yumuşak, lacivert tonlu gölge; koyu temada gölge yok
/// (yüzey tonu ile ayrışır: `sf` < `sf2` < `sf3`). Kaydırılan listelerde gölgeli kartı az kullanın.
abstract final class BuElevation {
  /// 0: düz, 1: kart (hafif), 2: yüzen (menü/yüzen çubuk), 3: üst katman (diyalog/alt sayfa).
  static List<BoxShadow> of(BuildContext context, int level) {
    if (level <= 0) return const [];
    final t = context.bu;
    if (Theme.of(context).brightness == Brightness.dark) return const [];
    final c = t.shadow;
    return switch (level) {
      1 => [
          BoxShadow(color: c.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: c.withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      2 => [
          BoxShadow(color: c.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: c.withValues(alpha: .05), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      _ => [
          BoxShadow(color: c.withValues(alpha: .16), blurRadius: 40, offset: const Offset(0, 16)),
          BoxShadow(color: c.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
    };
  }
}
