import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

/// Kimlik ekranlarındaki sonsuz (döngülü) hareketin tek anahtarı.
/// Testte ve "hareketi azalt" açıkken döngü çalışmaz (pumpAndSettle kilitlenmesin, pil/erişilebilirlik).
class AuthMotion {
  AuthMotion._();

  /// Testte döngüyü açmak için (ör. görsel inceleme); varsayılan: yalnız gerçek cihazda.
  @visibleForTesting
  static bool? forceLoop;

  static final bool _inTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static bool loopEnabled(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return forceLoop ?? !_inTest;
  }
}

/// Dokunsal geri bildirim (hata vermez; test/emülatörde sessizce atlanır).
enum AuthHaptic { tap, success, error }

void authHaptic(AuthHaptic kind) {
  try {
    final f = switch (kind) {
      AuthHaptic.tap => HapticFeedback.selectionClick(),
      AuthHaptic.success => HapticFeedback.lightImpact(),
      AuthHaptic.error => HapticFeedback.mediumImpact(),
    };
    f.catchError((Object _) {});
  } catch (_) {}
}

/// Ekran başına TEK döngülü ticker: arka plan, illüstrasyon süzülmesi ve parıltılar aynı saati okur.
/// Değer 0..1 (24 sn'de bir tur). Döngü kapalıysa sabit bir fazda durur.
class AuthClockHost extends StatefulWidget {
  const AuthClockHost({super.key, required this.child});

  final Widget child;

  @override
  State<AuthClockHost> createState() => _AuthClockHostState();
}

class _AuthClockHostState extends State<AuthClockHost> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24), value: .3);
  bool _looping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final want = AuthMotion.loopEnabled(context);
    if (want && !_looping) {
      _looping = true;
      _c.repeat();
    } else if (!want && _looping) {
      _looping = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthClock(clock: _c, child: widget.child);
}

class _AuthClock extends InheritedWidget {
  const _AuthClock({required this.clock, required super.child});

  final Animation<double> clock;

  @override
  bool updateShouldNotify(_AuthClock old) => old.clock != clock;
}

/// Üstte [AuthClockHost] yoksa sabit saat döner.
Animation<double> authClockOf(BuildContext context) {
  final w = context.getInheritedWidgetOfExactType<_AuthClock>();
  return w?.clock ?? const AlwaysStoppedAnimation<double>(.3);
}

/// Markaya özgü yumuşak arka plan: yavaş süzülen renk lekeleri + köşede eş merkezli halkalar.
/// Tek [CustomPainter], [RepaintBoundary] ile ayrı katmanda; dokunmaları ve erişilebilirliği etkilemez.
class AuthAmbient extends StatelessWidget {
  const AuthAmbient({super.key, this.height = 380});

  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _AmbientPainter(
                clock: authClockOf(context),
                a: t.pr,
                b: dark ? t.onSoft : t.h1,
                c: dark ? const Color(0xFF6C7BFF) : const Color(0xFFFFB199),
                dark: dark,
                rtl: rtl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.clock,
    required this.a,
    required this.b,
    required this.c,
    required this.dark,
    required this.rtl,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final Color a, b, c;
  final bool dark, rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final p = clock.value * math.pi * 2;
    final w = size.width;
    final sx = rtl ? -1.0 : 1.0;
    double x(double f) => rtl ? w - f : f;

    void blob(Offset o, double r, Color col, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [col.withValues(alpha: alpha), col.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: o, radius: r));
      canvas.drawCircle(o, r, paint);
    }

    // Üç yavaş leke (Lissajous yörüngeleri); koyu temada daha parlak, açıkta daha yumuşak.
    blob(Offset(x(w * .92 + math.sin(p) * 22 * sx), -20 + math.cos(p * 2) * 14), 300, a, dark ? .30 : .20);
    blob(Offset(x(w * .15 + math.cos(p) * 30 * sx), 120 + math.sin(p * 2) * 18), 220, c, dark ? .16 : .26);
    blob(Offset(x(w * .70 + math.sin(p * 2 + 1) * 26 * sx), 250 + math.cos(p) * 20), 170, b, dark ? .14 : .10);

    // Köşe halkaları: açılış ekranındaki halkaların yumuşak yankısı.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(x(w + 6), -6);
    const radii = [86.0, 144.0, 206.0, 272.0];
    for (var i = 0; i < radii.length; i++) {
      final breathe = math.sin(p + i * .9) * 3;
      ring.color = a.withValues(alpha: (dark ? .22 : .16) * (1 - i * .2));
      canvas.drawCircle(center, radii[i] + breathe, ring);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.a != a || old.b != b || old.c != c || old.dark != dark || old.rtl != rtl;
}

/// Aşamalı (staggered) giriş: [controller] 0..1; her çocuk kendi aralığında yukarı süzülerek belirir.
class AuthReveal extends StatelessWidget {
  const AuthReveal({super.key, required this.controller, required this.index, required this.child, this.dy = 18});

  final Animation<double> controller;
  final int index;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * .09).clamp(0.0, .6);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, math.min(1.0, start + .5), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, ch) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, (1 - curved.value) * dy), child: ch),
      ),
    );
  }
}

/// Hata sarsıntısı: [trigger] artınca 380 ms'lik sönümlü yatay titreşim oynar.
class AuthShake extends StatefulWidget {
  const AuthShake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<AuthShake> createState() => _AuthShakeState();
}

class _AuthShakeState extends State<AuthShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(AuthShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, ch) {
        final v = _c.value;
        final dx = math.sin(v * math.pi * 5) * 9 * (1 - v);
        return Transform.translate(offset: Offset(dx, 0), child: ch);
      },
    );
  }
}
