import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Açılış ekranı (04/1): düz marka kırmızısı, ince beyaz dönen halkayla çevrili beyaz "BÜ" karosu ve uygulama adı.
/// Oturum durumu çözülürken gösterilir; ağ beklemez. "Animasyonları azalt" açıkken halka sabit durur.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = BuMotion.reduced(context);
    if (reduced) {
      _spin.stop();
    } else if (!_started) {
      _spin.repeat();
    }
    _started = true;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: t.h1,
      body: Center(
        child: Semantics(
          label: 'BÜ Kampüs',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 124,
                height: 124,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _spin,
                          builder: (_, __) => CustomPaint(painter: _RingPainter(_spin.value, t.onMedia)),
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.onMedia,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: t.scrim.withValues(alpha: .28), blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -8)],
                      ),
                      // Marka harfleri her dilde Latin kalır; yön ters çevrilmesin.
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text('BÜ', style: tx.displaySmall!.copyWith(color: t.h1, fontWeight: FontWeight.w800, letterSpacing: -.5, height: 1.1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('BÜ Kampüs',
                  style: tx.headlineMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w800, letterSpacing: rtl ? 0 : -.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soluk kılavuz halka + dönen kısa beyaz yay (r 57 / 124, çizgi 2.5; yay çevrenin 80/358'i).
class _RingPainter extends CustomPainter {
  const _RingPainter(this.turn, this.color);

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width * 57 / 124;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    const sweep = 2 * math.pi * 80 / (2 * math.pi * 57);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      turn * 2 * math.pi - math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: .95)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.turn != turn || old.color != color;
}
