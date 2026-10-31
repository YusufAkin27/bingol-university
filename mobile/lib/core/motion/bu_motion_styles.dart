import 'package:flutter/widgets.dart';

import '../theme/bu_motion.dart';

/// Alt sayfa / diyalog / bildirim açılış-kapanış animasyon stilleri (framework varsayılanları yerine BuMotion).
/// Açılış yavaşlayan (emphasized decelerate), kapanış hızlanan (accelerate) eğri; "animasyonları azalt" açıksa süre 0.
abstract final class BuMotionStyles {
  /// `showModalBottomSheet(sheetAnimationStyle: ...)`.
  static AnimationStyle sheet(BuildContext context) => AnimationStyle(
        duration: BuMotion.of(context, BuMotion.medium),
        reverseDuration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.emphasizedDecelerate,
        reverseCurve: BuMotion.emphasizedAccelerate,
      );

  /// `showDialog(animationStyle: ...)`.
  static AnimationStyle dialog(BuildContext context) => AnimationStyle(
        duration: BuMotion.of(context, BuMotion.medium),
        reverseDuration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.emphasizedDecelerate,
        reverseCurve: BuMotion.emphasizedAccelerate,
      );

  /// `showSnackBar(snackBarAnimationStyle: ...)` (yalnız süre kullanılır).
  static AnimationStyle toast(BuildContext context) => AnimationStyle(
        duration: BuMotion.of(context, BuMotion.medium),
        reverseDuration: BuMotion.of(context, BuMotion.short),
      );
}
