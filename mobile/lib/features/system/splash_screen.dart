import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Açılış ekranı: tema zemini (açık beyaz / koyu #09090B), ortada tema duyarlı BÜ logosu ([BuLogo], 120 dp: yerel
/// açılış ekranındaki `splash_logo` / iOS `LaunchImage` ile aynı boyut ve konum, geçişte zıplamaz) ve altında ince
/// ilerleme halkası. Oturum durumu çözülürken gösterilir; ağ beklemez.
/// "Animasyonları azalt" açıkken halka sabit (dolu yay) durur.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = t.ink;
    return Scaffold(
      backgroundColor: t.bg,
      body: Semantics(
        label: 'BÜ Kampüs',
        excludeSemantics: true,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Logo tam ortada (yerel açılış ekranıyla aynı nokta); halka onun 28 dp altında.
              const BuLogo(width: 120, semanticLabel: null),
              Transform.translate(
                offset: const Offset(0, 60 + 28),
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                      backgroundColor: fg.withValues(alpha: .2),
                      value: BuMotion.reduced(context) ? .7 : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
