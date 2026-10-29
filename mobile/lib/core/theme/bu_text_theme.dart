import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// Material 3 yazı ölçeği (Inter), mobil yoğunluğa ayarlı.
///
/// | Rol | Boyut / ağırlık | Kullanım |
/// |---|---|---|
/// | displayLarge/Medium/Small | 40 / 34 / 30, 800 | karşılama, büyük sayılar |
/// | headlineLarge/Medium/Small | 28 / 24 / 20, 800-700 | büyüyen sayfa başlığı (large app bar), bölüm başlığı |
/// | titleLarge/Medium/Small | 18 / 15.3 / 13.5, 700-600 | app bar başlığı, kart başlığı, satır başlığı |
/// | bodyLarge/Medium/Small | 15 / 13.5 / 12, 400 | gövde, açıklama |
/// | labelLarge/Medium/Small | 13.5 / 12 / 11, 600-500 | düğme, çip, rozet, zaman |
///
/// Arapçada harf aralığı sıfırdır (bitişik harfler bozulmasın) ve satır yüksekliği ~%12 artar.
/// `BuType` (eski ölçek) KİLİTLİ ve kullanılabilir kalır; yeni kodda `Theme.of(context).textTheme` tercih edilir.
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
      titleLarge: _s(18, FontWeight.w700, 1.3, ar: ar),
      titleMedium: _s(15.3, FontWeight.w700, 1.3, ar: ar),
      titleSmall: _s(13.5, FontWeight.w600, 1.35, ar: ar),
      bodyLarge: _s(15, FontWeight.w400, 1.45, ar: ar),
      bodyMedium: _s(13.5, FontWeight.w400, 1.45, ar: ar),
      bodySmall: _s(12, FontWeight.w400, 1.4, ar: ar),
      labelLarge: _s(13.5, FontWeight.w600, 1.3, ar: ar),
      labelMedium: _s(12, FontWeight.w600, 1.3, ar: ar),
      labelSmall: _s(11, FontWeight.w500, 1.3, ar: ar),
    ).apply(bodyColor: t.ink, displayColor: t.ink);
  }
}
