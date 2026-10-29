import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/widgets/auth_art.dart';
import '../auth/widgets/auth_motion.dart';

/// Açılış ekranı: marka kırmızısı sahne (yavaş dalgalar + nefes alan halkalar), ölçeklenerek gelen logo karosu
/// ve parıltı, altta üç noktalı yükleme göstergesi. Oturum durumu çözülürken gösterilir; ağ beklemez.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = CurvedAnimation(parent: _intro, curve: const Interval(0, .55, curve: Curves.easeOutBack));
    final sheen = CurvedAnimation(parent: _intro, curve: const Interval(.45, .95, curve: Curves.easeInOut));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(.35, .85, curve: Curves.easeOut));
    return AuthClockHost(
      child: Builder(
        builder: (context) {
          final clock = authClockOf(context);
          return Scaffold(
            backgroundColor: kBrandRed,
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF4A3D), Color(0xFFD92E22)]),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(child: CustomPaint(painter: AuthHeroPainter(clock, ringY: .45))),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: Tween(begin: .55, end: 1.0).animate(card),
                          child: FadeTransition(
                            opacity: card.drive(Tween(begin: 0.0, end: 1.0)),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 48, offset: const Offset(0, 24), spreadRadius: -20)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(34),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/branding/mark_white.svg',
                                      width: 76,
                                      height: 76,
                                      colorFilter: const ColorFilter.mode(kBrandRed, BlendMode.srcIn),
                                      semanticsLabel: 'BÜ Kampüs',
                                    ),
                                    Positioned.fill(child: CustomPaint(painter: AuthSheenPainter(sheen))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: text,
                          child: Column(
                            children: [
                              Text('BÜ Kampüs',
                                  style: BuType.display.copyWith(color: Colors.white, fontSize: 32, letterSpacing: -.6, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text('Bingöl Üniversitesi',
                                  style: BuType.body.copyWith(color: Colors.white.withValues(alpha: .88), fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 64,
                    child: ExcludeSemantics(child: _Dots(clock: clock)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Üç noktalı yükleme: tek saatten beslenir (ek ticker yok); hareket kapalıyken sabit.
class _Dots extends StatelessWidget {
  const _Dots({required this.clock});

  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final p = clock.value * math.pi * 24; // 1 sn'lik döngü
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .45 + .55 * ((math.sin(p - i * 1.1) + 1) / 2)),
                ),
              ),
          ],
        );
      },
    );
  }
}
