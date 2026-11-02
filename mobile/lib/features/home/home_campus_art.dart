import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Dekoratif kampüs çizimi; gerçek bir bina fotoğrafı veya kurum logosu değildir.
class HomeCampusArt extends StatelessWidget {
  const HomeCampusArt({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: RepaintBoundary(
    child: CustomPaint(painter: _CampusPainter(context.bu.pr)),
  ));
}

class _CampusPainter extends CustomPainter {
  const _CampusPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 88);
    final line = Paint()..color = color.withValues(alpha: .32)..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: .07);
    final hills = Path()..moveTo(0, 86)..quadraticBezierTo(45, 53, 90, 70)..quadraticBezierTo(140, 48, 180, 81)..lineTo(180, 88)..lineTo(0, 88)..close();
    canvas.drawPath(hills, fill);
    canvas.drawPath(hills, line);
    final building = Path()..moveTo(38, 70)..lineTo(38, 40)..lineTo(104, 28)..lineTo(104, 70)..moveTo(121, 70)..lineTo(121, 34)..lineTo(160, 43)..lineTo(160, 73);
    canvas.drawPath(building, line);
    canvas.drawRect(const Rect.fromLTWH(104, 11, 17, 60), fill);
    canvas.drawRect(const Rect.fromLTWH(104, 11, 17, 60), line);
    canvas.drawPath(Path()..moveTo(100, 11)..lineTo(112.5, 2)..lineTo(125, 11)..close(), line);
    canvas.drawCircle(const Offset(112.5, 23), 4, line);
    canvas.drawLine(const Offset(112.5, 20), const Offset(112.5, 23), line);
    canvas.drawLine(const Offset(112.5, 23), const Offset(115, 25), line);
    for (final x in [44.0, 56.0, 68.0, 80.0, 92.0, 129.0, 141.0, 153.0]) {
      for (final y in [45.0, 57.0]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 5, 7), const Radius.circular(1)), line);
      }
    }
    for (final x in [26.0, 170.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 61), width: 7, height: 22), fill);
      canvas.drawLine(Offset(x, 57), Offset(x, 76), line);
    }
    canvas.drawPath(Path()..moveTo(13, 24)..quadraticBezierTo(13, 17, 22, 20)..quadraticBezierTo(27, 8, 35, 20)..quadraticBezierTo(45, 18, 45, 24)..close(), line);
    canvas.restore();
  }
  @override
  bool shouldRepaint(_CampusPainter oldDelegate) => oldDelegate.color != color;
}
