import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Ekranda soldan sağa (Arapçada sağdan sola) yatay çekince [onBack] çağırır (geri dön).
/// Dikey kaydırmayı bozmaz: yalnız yatay sürükleme tanınır; kısa/dikey eğimli hareketler yok sayılır.
class BuSwipeBack extends StatelessWidget {
  const BuSwipeBack({super.key, required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  /// En az yatay mesafe (dp) ve hız (dp/sn); dikey sapma yataydan küçük olmalı.
  static const double minDistance = 80;
  static const double minVelocity = 220;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var dx = 0.0;
    var dy = 0.0;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (r) {
            r
              ..onStart = (_) {
                dx = 0;
                dy = 0;
              }
              ..onUpdate = (d) {
                dx += d.delta.dx;
                dy += d.delta.dy;
              }
              ..onEnd = (d) {
                final forward = rtl ? -dx : dx;
                final vx = rtl
                    ? -d.velocity.pixelsPerSecond.dx
                    : d.velocity.pixelsPerSecond.dx;
                if (forward >= minDistance &&
                    dy.abs() < forward * .6 &&
                    vx >= minVelocity) onBack();
              };
          },
        ),
      },
      child: child,
    );
  }
}
