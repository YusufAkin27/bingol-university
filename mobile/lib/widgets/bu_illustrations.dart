import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Boş/hata durumları için kodla çizilmiş küçük illüstrasyonlar (görsel dosyası yok, tema renkleriyle uyumlu).
enum BuIllustration { box, message, search, calendar, club, bell, wifiOff, alert, heart, image, lock, check, document }

/// 120x120 tuvalde çizilen illüstrasyon; [size] verilen kenara ölçeklenir. Dekoratiftir (anlam dışı, `ExcludeSemantics`).
class BuIllustrationView extends StatelessWidget {
  const BuIllustrationView(this.kind, {super.key, this.size = 120});

  final BuIllustration kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: _IllPainter(kind, t)),
      ),
    );
  }
}

class _IllPainter extends CustomPainter {
  _IllPainter(this.kind, this.t);

  final BuIllustration kind;
  final BuTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120);
    _blob(canvas);
    switch (kind) {
      case BuIllustration.box:
        _box(canvas);
      case BuIllustration.message:
        _message(canvas);
      case BuIllustration.search:
        _search(canvas);
      case BuIllustration.calendar:
        _calendar(canvas);
      case BuIllustration.club:
        _club(canvas);
      case BuIllustration.bell:
        _bell(canvas);
      case BuIllustration.wifiOff:
        _wifiOff(canvas);
      case BuIllustration.alert:
        _alert(canvas);
      case BuIllustration.heart:
        _heart(canvas);
      case BuIllustration.image:
        _image(canvas);
      case BuIllustration.lock:
        _lock(canvas);
      case BuIllustration.check:
        _check(canvas);
      case BuIllustration.document:
        _document(canvas);
    }
    canvas.restore();
  }

  // --- yardımcılar ---
  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _line(Color c, [double w = 2.6]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  BuTint get _a => t.tint(1);
  BuTint get _b => t.tint(3);

  void _blob(Canvas c) {
    c.drawCircle(const Offset(60, 62), 50, _fill(t.soft));
    c.drawCircle(const Offset(60, 62), 36, _fill(t.soft.withValues(alpha: .55)));
    // küçük süs noktaları
    c.drawCircle(const Offset(14, 30), 3.4, _fill(_a.fg.withValues(alpha: .55)));
    c.drawCircle(const Offset(104, 24), 2.6, _fill(t.pr.withValues(alpha: .6)));
    c.drawCircle(const Offset(110, 92), 3, _fill(_b.fg.withValues(alpha: .5)));
    _sparkle(c, const Offset(20, 90), 5, t.pr.withValues(alpha: .7));
  }

  void _sparkle(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(p, _fill(color));
  }

  void _card(Canvas c, RRect r, {Color? fill}) {
    c.drawRRect(r.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawRRect(r, _fill(fill ?? t.sf));
    c.drawRRect(r, _line(t.ink, 2.4));
  }

  // --- kutu ---
  void _box(Canvas c) {
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(30, 54, 60, 40), const Radius.circular(6));
    _card(c, body);
    // kapak kanatları
    final l = Path()
      ..moveTo(30, 54)
      ..lineTo(18, 40)
      ..lineTo(48, 40)
      ..lineTo(60, 54)
      ..close();
    final r = Path()
      ..moveTo(90, 54)
      ..lineTo(102, 40)
      ..lineTo(72, 40)
      ..lineTo(60, 54)
      ..close();
    c.drawPath(l, _fill(t.sf2));
    c.drawPath(l, _line(t.ink, 2.4));
    c.drawPath(r, _fill(t.sf2));
    c.drawPath(r, _line(t.ink, 2.4));
    c.drawLine(const Offset(50, 66), const Offset(70, 66), _line(t.pr, 3));
    c.drawLine(const Offset(60, 24), const Offset(60, 32), _line(t.pr, 2.6));
    c.drawLine(const Offset(44, 28), const Offset(48, 34), _line(t.pr, 2.6));
    c.drawLine(const Offset(76, 28), const Offset(72, 34), _line(t.pr, 2.6));
  }

  // --- mesaj ---
  void _message(Canvas c) {
    final a = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 30, 58, 38), const Radius.circular(14));
    _card(c, a);
    final tail = Path()
      ..moveTo(34, 68)
      ..lineTo(32, 80)
      ..lineTo(46, 68);
    c.drawPath(tail, _fill(t.sf));
    c.drawPath(tail, _line(t.ink, 2.4));
    c.drawLine(const Offset(34, 68), const Offset(46, 68), _line(t.sf, 3.4));
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(39.0 + i * 12, 49), 3, _fill(t.mut));
    }
    final b = RRect.fromRectAndRadius(const Rect.fromLTWH(52, 62, 46, 30), const Radius.circular(12));
    c.drawRRect(b.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawRRect(b, _fill(t.pr));
    c.drawLine(const Offset(62, 73), const Offset(88, 73), _line(t.onPr, 2.6));
    c.drawLine(const Offset(62, 81), const Offset(78, 81), _line(t.onPr.withValues(alpha: .75), 2.6));
  }

  // --- arama ---
  void _search(Canvas c) {
    c.drawCircle(const Offset(54, 54), 24, _fill(t.sf));
    c.drawCircle(const Offset(54, 54), 24, _line(t.ink, 3));
    c.drawLine(const Offset(72, 72), const Offset(92, 92), _line(t.ink, 6));
    c.drawLine(const Offset(72, 72), const Offset(92, 92), _line(t.pr, 3));
    c.drawArc(Rect.fromCircle(center: const Offset(54, 54), radius: 15), math.pi * 1.1, math.pi * .45, false, _line(t.soft, 3));
    // üzgün ağız
    c.drawArc(const Rect.fromLTWH(45, 56, 18, 12), math.pi * 1.15, math.pi * .7, false, _line(t.mut, 2.4));
    c.drawCircle(const Offset(48, 48), 2, _fill(t.mut));
    c.drawCircle(const Offset(60, 48), 2, _fill(t.mut));
  }

  // --- takvim ---
  void _calendar(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 32, 68, 62), const Radius.circular(12));
    _card(c, r);
    final head = RRect.fromRectAndCorners(const Rect.fromLTWH(26, 32, 68, 18),
        topLeft: const Radius.circular(12), topRight: const Radius.circular(12));
    c.drawRRect(head, _fill(t.pr));
    c.drawRRect(r, _line(t.ink, 2.4));
    c.drawLine(const Offset(42, 26), const Offset(42, 38), _line(t.ink, 3.4));
    c.drawLine(const Offset(78, 26), const Offset(78, 38), _line(t.ink, 3.4));
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final hi = row == 1 && col == 2;
        c.drawCircle(Offset(38.0 + col * 15, 62.0 + row * 12), hi ? 4.6 : 2.4, _fill(hi ? t.pr : t.mut.withValues(alpha: .6)));
      }
    }
  }

  // --- kulüp ---
  void _club(Canvas c) {
    void person(Offset o, double s, Color body, {bool front = true}) {
      c.drawCircle(o + Offset(0, -14 * s), 9 * s, _fill(t.sf));
      c.drawCircle(o + Offset(0, -14 * s), 9 * s, _line(t.ink, 2.4));
      final sh = Path()
        ..moveTo(o.dx - 17 * s, o.dy + 22 * s)
        ..quadraticBezierTo(o.dx - 17 * s, o.dy - 2 * s, o.dx, o.dy - 2 * s)
        ..quadraticBezierTo(o.dx + 17 * s, o.dy - 2 * s, o.dx + 17 * s, o.dy + 22 * s)
        ..close();
      c.drawPath(sh, _fill(body));
      c.drawPath(sh, _line(t.ink, 2.4));
    }

    person(const Offset(36, 60), .8, _a.bg);
    person(const Offset(84, 60), .8, _b.bg);
    person(const Offset(60, 66), 1.05, t.pr);
  }

  // --- zil ---
  void _bell(Canvas c) {
    final p = Path()
      ..moveTo(36, 78)
      ..quadraticBezierTo(44, 70, 44, 52)
      ..quadraticBezierTo(44, 34, 60, 34)
      ..quadraticBezierTo(76, 34, 76, 52)
      ..quadraticBezierTo(76, 70, 84, 78)
      ..close();
    c.drawPath(p.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawPath(p, _fill(t.sf));
    c.drawPath(p, _line(t.ink, 2.4));
    c.drawLine(const Offset(60, 28), const Offset(60, 34), _line(t.ink, 3));
    c.drawArc(const Rect.fromLTWH(52, 78, 16, 12), 0, math.pi, false, _line(t.pr, 3.2));
    c.drawCircle(const Offset(60, 84), 4, _fill(t.pr));
    c.drawArc(const Rect.fromLTWH(30, 44, 10, 20), math.pi * .6, math.pi * .8, false, _line(t.pr.withValues(alpha: .7), 2.4));
    c.drawArc(const Rect.fromLTWH(80, 44, 10, 20), math.pi * 1.6, math.pi * .8, false, _line(t.pr.withValues(alpha: .7), 2.4));
  }

  // --- bağlantı yok ---
  void _wifiOff(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final r = 16.0 + i * 13;
      c.drawArc(Rect.fromCircle(center: const Offset(60, 76), radius: r), math.pi * 1.2, math.pi * .6, false,
          _line(i == 0 ? t.ink : t.ink.withValues(alpha: .75), 3.6));
    }
    c.drawCircle(const Offset(60, 76), 4.4, _fill(t.ink));
    c.drawLine(const Offset(34, 36), const Offset(88, 90), _line(t.sf, 8));
    c.drawLine(const Offset(34, 36), const Offset(88, 90), _line(t.pr, 4));
  }

  // --- uyarı ---
  void _alert(Canvas c) {
    final p = Path()
      ..moveTo(60, 28)
      ..quadraticBezierTo(64, 28, 66, 32)
      ..lineTo(96, 84)
      ..quadraticBezierTo(98, 90, 92, 90)
      ..lineTo(28, 90)
      ..quadraticBezierTo(22, 90, 24, 84)
      ..lineTo(54, 32)
      ..quadraticBezierTo(56, 28, 60, 28)
      ..close();
    c.drawPath(p.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawPath(p, _fill(t.sf));
    c.drawPath(p, _line(t.ink, 2.4));
    c.drawLine(const Offset(60, 50), const Offset(60, 70), _line(t.pr, 4.2));
    c.drawCircle(const Offset(60, 79), 2.8, _fill(t.pr));
  }

  // --- kalp ---
  void _heart(Canvas c) {
    final p = Path()
      ..moveTo(60, 90)
      ..cubicTo(26, 66, 28, 36, 46, 34)
      ..cubicTo(54, 33, 58, 38, 60, 42)
      ..cubicTo(62, 38, 66, 33, 74, 34)
      ..cubicTo(92, 36, 94, 66, 60, 90)
      ..close();
    c.drawPath(p.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawPath(p, _fill(t.sf));
    c.drawPath(p, _line(t.ink, 2.4));
    c.drawPath(
        Path()
          ..moveTo(44, 46)
          ..quadraticBezierTo(40, 52, 44, 60),
        _line(t.pr, 3));
    _sparkle(c, const Offset(92, 40), 6, t.pr);
  }

  // --- görsel ---
  void _image(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 34, 72, 56), const Radius.circular(10));
    _card(c, r);
    c.drawCircle(const Offset(44, 52), 6, _fill(t.pr));
    final m = Path()
      ..moveTo(24, 84)
      ..lineTo(50, 62)
      ..lineTo(66, 76)
      ..lineTo(78, 66)
      ..lineTo(96, 84)
      ..lineTo(96, 80)
      ..lineTo(96, 90)
      ..lineTo(24, 90)
      ..close();
    c.save();
    c.clipRRect(r);
    c.drawPath(m, _fill(_a.bg));
    c.restore();
    c.drawRRect(r, _line(t.ink, 2.4));
  }

  // --- kilit ---
  void _lock(Canvas c) {
    c.drawArc(const Rect.fromLTWH(42, 28, 36, 40), math.pi, math.pi, false, _line(t.ink, 4.4));
    c.drawLine(const Offset(42, 48), const Offset(42, 58), _line(t.ink, 4.4));
    c.drawLine(const Offset(78, 48), const Offset(78, 58), _line(t.ink, 4.4));
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(32, 56, 56, 38), const Radius.circular(10));
    _card(c, r, fill: t.pr);
    c.drawCircle(const Offset(60, 72), 5, _fill(t.onPr));
    c.drawLine(const Offset(60, 74), const Offset(60, 84), _line(t.onPr, 3.6));
  }

  // --- onay ---
  void _check(Canvas c) {
    c.drawCircle(const Offset(60, 62), 30, _fill(t.okSoft));
    c.drawCircle(const Offset(60, 62), 30, _line(t.ok, 3));
    c.drawPath(
        Path()
          ..moveTo(46, 62)
          ..lineTo(56, 72)
          ..lineTo(76, 50),
        _line(t.ok, 5));
  }

  // --- belge ---
  void _document(Canvas c) {
    final p = Path()
      ..moveTo(36, 28)
      ..lineTo(70, 28)
      ..lineTo(88, 46)
      ..lineTo(88, 92)
      ..lineTo(36, 92)
      ..close();
    c.drawPath(p.shift(const Offset(0, 3)), _fill(t.shadow.withValues(alpha: .10)));
    c.drawPath(p, _fill(t.sf));
    c.drawPath(p, _line(t.ink, 2.4));
    c.drawPath(
        Path()
          ..moveTo(70, 28)
          ..lineTo(70, 46)
          ..lineTo(88, 46),
        _line(t.ink, 2.4));
    c.drawLine(const Offset(46, 60), const Offset(78, 60), _line(t.mut, 2.6));
    c.drawLine(const Offset(46, 70), const Offset(78, 70), _line(t.mut, 2.6));
    c.drawLine(const Offset(46, 80), const Offset(64, 80), _line(t.pr, 2.8));
  }

  @override
  bool shouldRepaint(_IllPainter old) => old.kind != kind || old.t != t;
}
