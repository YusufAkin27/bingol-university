import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

/// Açılış ekranı: marka kırmızısı zemin, soluk eş merkezli halkalar, beyaz logo karosu ve ad.
/// Oturum durumu çözülürken gösterilir.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandRed,
      body: Stack(
        children: [
          Positioned.fill(child: ExcludeSemantics(child: CustomPaint(painter: _RingsPainter()))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 48, offset: const Offset(0, 24), spreadRadius: -20)],
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/branding/mark_white.svg',
                    width: 76,
                    height: 76,
                    colorFilter: const ColorFilter.mode(kBrandRed, BlendMode.srcIn),
                    semanticsLabel: 'BÜ Kampüs',
                  ),
                ),
                const SizedBox(height: 22),
                Text('BÜ Kampüs',
                    style: BuType.display.copyWith(color: Colors.white, fontSize: 32, letterSpacing: -0.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Bingöl Üniversitesi',
                    style: BuType.body.copyWith(color: Colors.white.withValues(alpha: 0.88), fontSize: 15)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: i == 0 ? 1 : 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.09);
    final c = Offset(size.width / 2, size.height * 0.45);
    for (final r in [120.0, 200.0, 290.0, 390.0]) {
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
