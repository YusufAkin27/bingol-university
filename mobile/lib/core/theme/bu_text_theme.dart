import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// Material 3 yazı ölçeği (Inter), mobil yoğunluğa ayarlı.
///
/// | Rol | Boyut / ağırlık | Kullanım |
/// |---|---|---|
/// | displayLarge/Medium/Small | 40 / 34 / 30, 800 | karşılama, büyük sayılar |
/// | headlineLarge/Medium/Small | 28 / 24 / 20, 800-700 | büyüyen sayfa başlığı (large app bar), bölüm başlığı |
/// | titleLarge/Medium/Small | 19 / 16 / 14, 700-600 | app bar başlığı, kart başlığı, satır başlığı |
/// | bodyLarge/Medium/Small | 15 / 14 / 12.5, 400 | gövde, açıklama |
/// | labelLarge/Medium/Small | 14 / 12.5 / 11.5, 600-500 | düğme, çip, rozet, zaman |
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
      displayLarge: _s(40, FontWeight.w800, 1.1, ls: -1, ar: ar),
      displayMedium: _s(34, FontWeight.w800, 1.12, ls: -.7, ar: ar),
      displaySmall: _s(30, FontWeight.w800, 1.15, ls: -.5, ar: ar),
      headlineLarge: _s(28, FontWeight.w800, 1.2, ls: -.4, ar: ar),
      headlineMedium: _s(24, FontWeight.w800, 1.22, ls: -.3, ar: ar),
      headlineSmall: _s(20, FontWeight.w700, 1.25, ls: -.2, ar: ar),
      titleLarge: _s(BuScale.title, FontWeight.w700, 1.3, ar: ar),
      titleMedium: _s(BuScale.heading, FontWeight.w700, 1.3, ar: ar),
      titleSmall: _s(BuScale.body, FontWeight.w600, 1.35, ar: ar),
      bodyLarge: _s(BuScale.bodyLarge, FontWeight.w400, 1.45, ar: ar),
      bodyMedium: _s(BuScale.body, FontWeight.w400, 1.45, ar: ar),
      bodySmall: _s(BuScale.label, FontWeight.w400, 1.4, ar: ar),
      labelLarge: _s(BuScale.body, FontWeight.w600, 1.3, ar: ar),
      labelMedium: _s(BuScale.label, FontWeight.w600, 1.3, ar: ar),
      labelSmall: _s(BuScale.caption, FontWeight.w500, 1.3, ar: ar),
    ).apply(bodyColor: t.ink, displayColor: t.ink);
  }
}
