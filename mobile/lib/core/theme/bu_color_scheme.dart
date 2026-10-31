import 'package:flutter/material.dart';

import '../theme.dart';

/// Marka belirteçlerinden Material 3 [ColorScheme] (tohum: marka kırmızısı; tüm roller açıkça verilir,
/// bu yüzden `fromSeed` hesabı yapılmaz ve tema kurulumu ucuzdur).
///
/// Eşleme: primary = `pr`; primaryContainer = `soft`; secondary = `ink`; **secondaryContainer = `soft`**
/// (NavigationBar göstergesi, FilledTonalButton, seçili çip/segment marka tonunda olur);
/// tertiary = `ok` (başarı); error = `danger`; surface = `sf` (kart); yüzey konteynerleri `sf`..`sf3`.
abstract final class BuColorScheme {
  static ColorScheme build(BuTokens t, Brightness b) {
    final dark = b == Brightness.dark;
    return ColorScheme(
      brightness: b,
      primary: t.pr,
      onPrimary: t.onPr,
      primaryContainer: t.soft,
      onPrimaryContainer: t.onSoft,
      primaryFixed: BuTokens.light.soft,
      primaryFixedDim: BuTokens.light.pr.withValues(alpha: .35),
      onPrimaryFixed: BuTokens.light.onSoft,
      onPrimaryFixedVariant: BuTokens.light.pr,
      secondary: t.ink,
      onSecondary: t.bg,
      secondaryContainer: t.soft,
      onSecondaryContainer: t.onSoft,
      tertiary: t.ok,
      onTertiary: t.onPr,
      tertiaryContainer: t.okSoft,
      onTertiaryContainer: t.onOkSoft,
      error: t.danger,
      onError: t.onPr,
      errorContainer: t.dangerSoft,
      onErrorContainer: t.danger,
      surface: t.sf,
      onSurface: t.ink,
      onSurfaceVariant: t.mut,
      surfaceDim: dark ? t.bg : t.sf2,
      surfaceBright: dark ? t.sf3 : t.sf,
      surfaceContainerLowest: dark ? t.bg : t.sf,
      surfaceContainerLow: t.sf,
      surfaceContainer: t.sf,
      surfaceContainerHigh: t.sf3,
      surfaceContainerHighest: t.sf2,
      outline: t.mut,
      outlineVariant: t.bd,
      shadow: t.shadow,
      scrim: t.scrim,
      surfaceTint: Colors.transparent,
      inverseSurface: t.ink,
      onInverseSurface: t.bg,
      inversePrimary: dark ? BuTokens.light.pr : BuTokens.dark.pr,
    );
  }
}
