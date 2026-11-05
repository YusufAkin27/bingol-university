import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// Material 3 yazı ölçeği (Inter), mobil yoğunluğa ayarlı.
///
/// | Rol | Boyut / ağırlık | Kullanım |
/// |---|---|---|
/// | displayLarge/Medium/Small | 32 / 30 / 28 (hero) | karşılama, büyük sayılar |
/// | headlineLarge/Medium/Small | 26 / 22 / 20 | sayfa başlığı, içerik başlığı |
/// | titleLarge/Medium/Small | 18 / 16 / 14 | app bar başlığı, kart başlığı, satır başlığı |
/// | bodyLarge/Medium/Small | 15 / 14 / 12.5 | gövde, açıklama |
/// | labelLarge/Medium/Small | 14 / 12.5 / 11.5 | düğme, çip, rozet, zaman |
///
/// Boyutlar `BuScale`'den gelir (tek ölçek, en küçük 11.5 sp); `BuType` aynı ölçeği kullanır.
/// Arapçada harf aralığı sıfırdır (bitişik harfler bozulmasın) ve satır yüksekliği ~%12 artar.
abstract final class BuTextTheme {
  static TextStyle _s(double size, FontWeight w, double h, {double ls = 0, required bool ar}) => TextStyle(
        fontFamily: BuType.family,
        fontSize: size,
        fontWeight: w,
        height: ar ? h * 1.12 : h,
        letterSpacing: ar ? 0 : ls,
      );

  static TextTheme build(BuTokens t, {bool arabic = false}) {
    final ar = arabic;
    return TextTheme(
      displayLarge: _s(32, BuType.emphasisWeight, 1.15, ls: -.6, ar: ar),
      displayMedium: _s(30, BuType.emphasisWeight, 1.16, ls: -.5, ar: ar),
      displaySmall: _s(BuScale.hero, BuType.emphasisWeight, 1.18, ls: -.4, ar: ar),
      headlineLarge: _s(26, BuType.emphasisWeight, 1.2, ls: -.3, ar: ar),
      headlineMedium: _s(BuScale.display, BuType.emphasisWeight, 1.22, ls: -.2, ar: ar),
      headlineSmall: _s(20, BuType.emphasisWeight, 1.25, ls: -.1, ar: ar),
      titleLarge: _s(BuScale.title, BuType.emphasisWeight, 1.3, ar: ar),
      titleMedium: _s(BuScale.heading, BuType.emphasisWeight, 1.3, ar: ar),
      titleSmall: _s(BuScale.body, BuType.emphasisWeight, 1.35, ar: ar),
      bodyLarge: _s(BuScale.bodyLarge, BuType.emphasisWeight, 1.45, ar: ar),
      bodyMedium: _s(BuScale.body, BuType.emphasisWeight, 1.45, ar: ar),
      bodySmall: _s(BuScale.label, BuType.emphasisWeight, 1.4, ar: ar),
      labelLarge: _s(BuScale.body, BuType.emphasisWeight, 1.3, ar: ar),
      labelMedium: _s(BuScale.label, BuType.emphasisWeight, 1.3, ar: ar),
      labelSmall: _s(BuScale.caption, BuType.emphasisWeight, 1.3, ar: ar),
    ).apply(bodyColor: t.ink, displayColor: t.ink);
  }
}
