import 'package:flutter/material.dart';

import '../theme/bu_motion.dart';

/// Uygulama genelindeki TEK sayfa geçiş dili: ince yatay kayma + solma (paylaşılan eksen X).
/// Gelen sayfa kısa mesafeden kayarak solar; giderken ters yönde, daha az mesafeyle geri çekilir.
/// Kapanışta (pop) aynı hareket tersine çalışır. RTL'de yön aynalanır; "animasyonları azalt" açıksa anlıktır.
/// Yalnız `transform` + `opacity` (gölge/blur yok). iOS'ta yerel Cupertino kaydırma korunur
/// (kenardan geri jesti); diğer platformlar [BuAxisPageTransitionsBuilder] kullanır.
abstract final class BuPageTransition {
  /// Gelen sayfanın başlangıç kayma mesafesi (dp).
  static const double distance = 28;

  /// Giden (arkada kalan) sayfanın geri çekilme mesafesi (dp).
  static const double exitDistance = 14;

  static const Duration forward = BuMotion.medium;
  static const Duration reverse = BuMotion.short;

  /// [animation]: rotanın giriş animasyonu, [secondary]: üstüne yeni rota bindiğinde ilerler.
  static Widget axisX(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (BuMotion.reduced(context)) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dir = rtl ? -1.0 : 1.0;
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: BuMotion.emphasizedDecelerate,
      reverseCurve: BuMotion.emphasizedAccelerate,
    );
    final outCurve = CurvedAnimation(parent: secondary, curve: BuMotion.standard);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([inCurve, outCurve]),
        child: child,
        builder: (context, c) {
          final enter = inCurve.value;
          final exit = outCurve.value;
          final dx = dir * (distance * (1 - enter) - exitDistance * exit);
          final opacity = (enter * (1 - exit * .15)).clamp(0.0, 1.0);
          return Opacity(opacity: opacity, child: Transform.translate(offset: Offset(dx, 0), child: c));
        },
      ),
    );
  }
}

/// iOS dışı platformlarda [BuPageTransition.axisX] uygular; Android'de sistem geri jesti sürerken
/// (tahmini geri) yerel [PredictiveBackPageTransitionsBuilder]'a devreder.
class BuAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const BuAxisPageTransitionsBuilder({this.predictiveBack = false});

  final bool predictiveBack;

  static const _predictive = PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => BuPageTransition.forward;

  @override
  Duration get reverseTransitionDuration => BuPageTransition.reverse;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (predictiveBack && route.popGestureInProgress) {
      return _predictive.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
    }
    return BuPageTransition.axisX(context, animation, secondaryAnimation, child);
  }
}
