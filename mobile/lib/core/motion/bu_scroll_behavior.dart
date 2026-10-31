import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Genel kaydırma davranışı: platforma uygun fizik (Android: ClampingScrollPhysics + M3 ince "stretch" taşma
/// göstergesi; iOS/macOS: Bouncing), tüm işaretçi türleriyle sürükleme (emülatör/fare/tablet). Kaydırma çubuğu
/// mobilde görünmez (gürültü yok). `MaterialApp(scrollBehavior: const BuScrollBehavior())`.
class BuScrollBehavior extends MaterialScrollBehavior {
  const BuScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.normal);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
    }
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return child;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return super.buildScrollbar(context, child, details);
    }
  }
}
