import 'package:flutter/painting.dart';

/// Sayılar için tabular (eşit genişlikli) rakam: sayaç, saat, tarih, kalori, rozet. Rakamlar değişirken
/// metin genişliği oynamaz (BuCountUp, geri sayım, saat satırları). `typography.dart`'a dokunmadan eklenir:
///
/// ```dart
/// Text('12:45', style: BuType.title.tabular)
/// Text('$kcal kcal', style: BuNumberStyle.of(tx.titleMedium!))
/// ```
extension BuNumberStyleX on TextStyle {
  /// Aynı stil + `FontFeature.tabularFigures()` (varsa mevcut özellikler korunur).
  TextStyle get tabular => BuNumberStyle.of(this);
}

abstract final class BuNumberStyle {
  static const FontFeature _tab = FontFeature.tabularFigures();

  static TextStyle of(TextStyle base) {
    final f = base.fontFeatures ?? const <FontFeature>[];
    if (f.any((x) => x.feature == 'tnum')) return base;
    return base.copyWith(fontFeatures: [...f, _tab]);
  }
}
