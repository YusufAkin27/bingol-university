import 'package:flutter/material.dart';

import '../theme.dart';

/// Yükseklik/gölge sistemi. Premium White: gölge NEREDEYSE YOK (çok hafif, nötr); Premium Black: gölge yok
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
          BoxShadow(color: c.withValues(alpha: .04), blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: c.withValues(alpha: .03), blurRadius: 1, offset: const Offset(0, 1)),
        ],
      2 => [
          BoxShadow(color: c.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: c.withValues(alpha: .03), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      _ => [
          BoxShadow(color: c.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: c.withValues(alpha: .04), blurRadius: 3, offset: const Offset(0, 1)),
        ],
    };
  }
}
