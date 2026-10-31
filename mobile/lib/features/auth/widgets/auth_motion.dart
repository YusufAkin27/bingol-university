import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/bu.dart';

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

/// Adım göstergesi çubuğu (kayıt): her parça sırayla soldan (RTL'de sağdan) dolar; geri gidince boşalır.
/// Yalnız `transform` canlanır (düzen kayması yok); "animasyonları azalt" açıksa anında.
class AuthStepBar extends StatelessWidget {
  const AuthStepBar({super.key, required this.step, required this.steps});

  /// Geçerli adım (0 tabanlı); bu adıma kadar olan parçalar doludur.
  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = BuMotion.of(context, BuMotion.medium);
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          Expanded(
            child: RepaintBoundary(
              child: SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: ColoredBox(
                    color: t.sf2,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('auth-step-fill-$i'),
                      tween: Tween<double>(end: i <= step ? 1 : 0),
                      duration: d,
                      curve: BuMotion.emphasizedDecelerate,
                      builder: (context, v, _) => Transform(
                        alignment: AlignmentDirectional.centerStart,
                        transform: Matrix4.diagonal3Values(v, 1, 1),
                        child: ColoredBox(color: t.pr, child: const SizedBox.expand()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i < steps - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
