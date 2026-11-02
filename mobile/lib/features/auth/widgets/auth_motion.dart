
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

/// Hata sarsıntısı: [trigger] artınca hafif (±6 dp, 2,5 salınım, 320 ms) sönümlü yatay titreşim; taşma/ölçek yok.
/// Ortak [BuShake]'e yönlenir; "animasyonları azalt" açıksa oynamaz.
class AuthShake extends StatelessWidget {
  const AuthShake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) => BuShake(trigger: trigger, child: child);
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
