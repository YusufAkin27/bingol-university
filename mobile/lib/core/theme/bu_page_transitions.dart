import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform geçişini sarar ve "animasyonları azalt" açıksa geçişi anlık yapar.
///
/// Android: tahmini geri (predictive back) + M3 "fade forwards" yedeği; iOS: yerel Cupertino kaydırma
/// (kenardan geri jesti korunur). Sayfa içi paylaşılan eksen için `BuPageRoute` / `BuSharedAxis` (lib/widgets/bu_transitions.dart).
class BuPageTransitionsBuilder extends PageTransitionsBuilder {
  const BuPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return inner.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
  }
}

/// [ThemeData.pageTransitionsTheme] değeri.
abstract final class BuPageTransitions {
  static const theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: BuPageTransitionsBuilder(PredictiveBackPageTransitionsBuilder()),
      TargetPlatform.iOS: BuPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      TargetPlatform.macOS: BuPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      TargetPlatform.windows: BuPageTransitionsBuilder(ZoomPageTransitionsBuilder()),
      TargetPlatform.linux: BuPageTransitionsBuilder(ZoomPageTransitionsBuilder()),
    },
  );
}
