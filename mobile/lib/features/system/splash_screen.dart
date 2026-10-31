import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Açılış ekranı (Stitch v3 "18"): tam ekran marka kırmızısı (koyu temada düz zemin), ortada "BÜ Kampüs" ve 24 dp altında
/// ince ilerleme halkası; monogram/karo/ikon yok. Oturum durumu çözülürken gösterilir; ağ beklemez.
/// "Animasyonları azalt" açıkken halka sabit (dolu yay) durur.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fg = dark ? t.ink : t.onMedia;
    return Scaffold(
      backgroundColor: dark ? t.bg : t.h1,
      body: Center(
        child: Semantics(
          label: 'BÜ Kampüs',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BÜ Kampüs', style: tx.headlineMedium!.copyWith(color: fg, fontWeight: FontWeight.w700, letterSpacing: rtl ? 0 : -.3)),
              const SizedBox(height: 24),
              RepaintBoundary(
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
            ],
          ),
        ),
      ),
    );
  }
}
