import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/nav.dart' show rootNavigatorKey;

/// Ekranda soldan sağa (Arapçada sağdan sola) yatay çekince [onBack] çağırır (geri dön).
/// Dikey kaydırmayı bozmaz: yalnız yatay sürükleme tanınır; kısa/dikey eğimli hareketler yok sayılır.
/// [edgeIgnore] > 0: kenardan (iOS yerel geri jesti) başlayan çekmeler yok sayılır, çifte geri olmasın.
class BuSwipeBack extends StatelessWidget {
  const BuSwipeBack({super.key, required this.onBack, required this.child, this.edgeIgnore = 0});

  final VoidCallback onBack;
  final Widget child;
  final double edgeIgnore;

  /// En az yatay mesafe (dp) ve hız (dp/sn); dikey sapma yataydan küçük olmalı.
  static const double minDistance = 80;
  static const double minVelocity = 220;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = MediaQuery.sizeOf(context).width;
    var dx = 0.0;
    var dy = 0.0;
    var fromEdge = false;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (r) {
            r
              ..onStart = (d) {
                dx = 0;
                dy = 0;
                final x = d.globalPosition.dx;
                fromEdge = edgeIgnore > 0 && (rtl ? x >= width - edgeIgnore : x <= edgeIgnore);
              }
              ..onUpdate = (d) {
                dx += d.delta.dx;
                dy += d.delta.dy;
              }
              ..onEnd = (d) {
                if (fromEdge) return;
                final forward = rtl ? -dx : dx;
                final vx = rtl ? -d.velocity.pixelsPerSecond.dx : d.velocity.pixelsPerSecond.dx;
                if (forward >= minDistance && dy.abs() < forward * .6 && vx >= minVelocity) onBack();
              };
          },
        ),
      },
      child: child,
    );
  }
}

/// iOS'ta uygulamanın her yerinde: ekranı soldan sağa çekince bir önceki sayfaya dön (ana sayfa/kök hariç: geri
/// dönülecek sayfa yoksa hiçbir şey olmaz). Kenardan başlayan çekme iOS yerel geri jestine bırakılır. Sayfanın
/// kendi `PopScope` mantığı (onay, `_back`) `maybePop` ile aynen çalışır. Android'de sistem geri jesti vardır: değişmez.
class BuGlobalSwipeBack extends StatelessWidget {
  const BuGlobalSwipeBack({super.key, required this.child});

  final Widget child;

  static bool get enabled => defaultTargetPlatform == TargetPlatform.iOS;

  static void _back() {
    final nav = rootNavigatorKey.currentState;
    if (nav != null && nav.canPop()) nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return BuSwipeBack(onBack: _back, edgeIgnore: 24, child: child);
  }
}
