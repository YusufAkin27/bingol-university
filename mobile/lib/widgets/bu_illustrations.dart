import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Boş/hata durumları için kodla çizilmiş küçük illüstrasyonlar (görsel dosyası yok).
/// PREMIUM MONOCHROME: nötr çizgi + yüzey tonları (gradyan, gölge, süs noktası yok); yalnız [BuIllustration.check]
/// anlamsal başarı rengini (`ok`) taşır.
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
  // Nötr yuvarlak zemin (sf2 + ince kenarlık), üstünde ink çizgili nesne. Nesne dolgusu `sf3`, ana çizgi `ink` (2.2),
  // ikincil çizgi `mut`, tek dolu vurgu `pr` (koyuda beyaz, açıkta siyah).
  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill;
  Paint _line(Color c, [double w = 2.2]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _blob(Canvas c) {
    c.drawCircle(const Offset(60, 60), 50, _fill(t.sf2));
    c.drawCircle(const Offset(60, 60), 50, _line(t.bdSubtle, 1));
  }

  void _card(Canvas c, RRect r, {Color? fill}) {
    c.drawRRect(r, _fill(fill ?? t.sf3));
    c.drawRRect(r, _line(t.ink));
  }

  void _shape(Canvas c, Path p, {Color? fill}) {
    c.drawPath(p, _fill(fill ?? t.sf3));
    c.drawPath(p, _line(t.ink));
  }

  // --- kutu ---
  void _box(Canvas c) {
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(32, 54, 56, 38), const Radius.circular(6));
    _card(c, body);
    final l = Path()
      ..moveTo(32, 54)
      ..lineTo(22, 42)
      ..lineTo(48, 42)
      ..lineTo(60, 54)
      ..close();
    final r = Path()
      ..moveTo(88, 54)
      ..lineTo(98, 42)
      ..lineTo(72, 42)
      ..lineTo(60, 54)
      ..close();
    _shape(c, l, fill: t.sf2);
    _shape(c, r, fill: t.sf2);
    c.drawLine(const Offset(51, 66), const Offset(69, 66), _line(t.mut, 2.4));
  }

  // --- mesaj ---
  void _message(Canvas c) {
    final a = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 32, 58, 36), const Radius.circular(12));
    _card(c, a);
    final tail = Path()
      ..moveTo(34, 68)
      ..lineTo(32, 80)
      ..lineTo(46, 68);
    c.drawPath(tail, _fill(t.sf3));
    c.drawPath(tail, _line(t.ink));
    c.drawLine(const Offset(34, 68), const Offset(45, 68), _line(t.sf3, 3.4));
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(39.0 + i * 12, 50), 2.6, _fill(t.mut));
    }
    final b = RRect.fromRectAndRadius(const Rect.fromLTWH(52, 62, 46, 30), const Radius.circular(10));
    c.drawRRect(b, _fill(t.pr));
    c.drawLine(const Offset(62, 73), const Offset(88, 73), _line(t.onPr, 2.4));
    c.drawLine(const Offset(62, 81), const Offset(78, 81), _line(t.onPr.withValues(alpha: .6), 2.4));
  }

  // --- arama ---
  void _search(Canvas c) {
    c.drawCircle(const Offset(54, 54), 24, _fill(t.sf3));
    c.drawCircle(const Offset(54, 54), 24, _line(t.ink, 2.8));
    c.drawLine(const Offset(72, 72), const Offset(92, 92), _line(t.ink, 5));
    // üzgün ağız
    c.drawArc(const Rect.fromLTWH(45, 58, 18, 12), math.pi * 1.15, math.pi * .7, false, _line(t.mut, 2.2));
    c.drawCircle(const Offset(48, 48), 2, _fill(t.mut));
    c.drawCircle(const Offset(60, 48), 2, _fill(t.mut));
  }

  // --- takvim ---
  void _calendar(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 32, 68, 62), const Radius.circular(10));
    _card(c, r);
    c.drawLine(const Offset(26, 50), const Offset(94, 50), _line(t.ink));
    c.drawLine(const Offset(42, 26), const Offset(42, 38), _line(t.ink, 3));
    c.drawLine(const Offset(78, 26), const Offset(78, 38), _line(t.ink, 3));
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final hi = row == 1 && col == 2;
        c.drawCircle(Offset(38.0 + col * 15, 62.0 + row * 11), hi ? 4.4 : 2.2, _fill(hi ? t.pr : t.mut.withValues(alpha: .6)));
      }
    }
  }

  // --- kulüp ---
  void _club(Canvas c) {
    void person(Offset o, double s, Color body) {
      c.drawCircle(o + Offset(0, -14 * s), 9 * s, _fill(t.sf3));
      c.drawCircle(o + Offset(0, -14 * s), 9 * s, _line(t.ink));
      final sh = Path()
        ..moveTo(o.dx - 17 * s, o.dy + 22 * s)
        ..quadraticBezierTo(o.dx - 17 * s, o.dy - 2 * s, o.dx, o.dy - 2 * s)
        ..quadraticBezierTo(o.dx + 17 * s, o.dy - 2 * s, o.dx + 17 * s, o.dy + 22 * s)
        ..close();
      c.drawPath(sh, _fill(body));
      c.drawPath(sh, _line(t.ink));
    }

    person(const Offset(36, 62), .8, t.sf2);
    person(const Offset(84, 62), .8, t.sf2);
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
    _shape(c, p);
    c.drawLine(const Offset(60, 28), const Offset(60, 34), _line(t.ink, 2.8));
    c.drawArc(const Rect.fromLTWH(52, 78, 16, 12), 0, math.pi, false, _line(t.ink, 2.6));
  }

  // --- bağlantı yok ---
  void _wifiOff(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final r = 16.0 + i * 13;
      c.drawArc(Rect.fromCircle(center: const Offset(60, 76), radius: r), math.pi * 1.2, math.pi * .6, false,
          _line(i == 0 ? t.ink : t.ink.withValues(alpha: .6), 3.2));
    }
    c.drawCircle(const Offset(60, 76), 4, _fill(t.ink));
    c.drawLine(const Offset(34, 36), const Offset(88, 90), _line(t.sf2, 7));
    c.drawLine(const Offset(34, 36), const Offset(88, 90), _line(t.ink, 2.8));
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
    _shape(c, p);
    c.drawLine(const Offset(60, 50), const Offset(60, 69), _line(t.ink, 3.4));
    c.drawCircle(const Offset(60, 79), 2.6, _fill(t.ink));
  }

  // --- kalp (anlamsal kırmızı değil: boş durum çizimi nötr çizgidir) ---
  void _heart(Canvas c) {
    final p = Path()
      ..moveTo(60, 90)
      ..cubicTo(26, 66, 28, 36, 46, 34)
      ..cubicTo(54, 33, 58, 38, 60, 42)
      ..cubicTo(62, 38, 66, 33, 74, 34)
      ..cubicTo(92, 36, 94, 66, 60, 90)
      ..close();
    _shape(c, p);
  }

  // --- görsel ---
  void _image(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 34, 72, 56), const Radius.circular(10));
    _card(c, r);
    c.drawCircle(const Offset(44, 52), 5.5, _fill(t.mut));
    final m = Path()
      ..moveTo(24, 84)
      ..lineTo(50, 62)
      ..lineTo(66, 76)
      ..lineTo(78, 66)
      ..lineTo(96, 82)
      ..lineTo(96, 90)
      ..lineTo(24, 90)
      ..close();
    c.save();
    c.clipRRect(r);
    c.drawPath(m, _fill(t.sf2));
    c.restore();
    c.drawPath(
        Path()
          ..moveTo(24, 84)
          ..lineTo(50, 62)
          ..lineTo(66, 76)
          ..lineTo(78, 66)
          ..lineTo(96, 82),
        _line(t.ink));
    c.drawRRect(r, _line(t.ink));
  }

  // --- kilit ---
  void _lock(Canvas c) {
    c.drawArc(const Rect.fromLTWH(42, 28, 36, 40), math.pi, math.pi, false, _line(t.ink, 3.6));
    c.drawLine(const Offset(42, 48), const Offset(42, 58), _line(t.ink, 3.6));
    c.drawLine(const Offset(78, 48), const Offset(78, 58), _line(t.ink, 3.6));
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(32, 56, 56, 38), const Radius.circular(10));
    c.drawRRect(r, _fill(t.pr));
    c.drawCircle(const Offset(60, 72), 5, _fill(t.onPr));
    c.drawLine(const Offset(60, 74), const Offset(60, 84), _line(t.onPr, 3.2));
  }

  // --- onay (anlamsal başarı rengi) ---
  void _check(Canvas c) {
    c.drawCircle(const Offset(60, 60), 30, _fill(t.sf3));
    c.drawCircle(const Offset(60, 60), 30, _line(t.ok, 2.6));
    c.drawPath(
        Path()
          ..moveTo(47, 61)
          ..lineTo(56, 70)
          ..lineTo(74, 50),
        _line(t.ok, 4));
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
    _shape(c, p);
    c.drawPath(
        Path()
          ..moveTo(70, 28)
          ..lineTo(70, 46)
          ..lineTo(88, 46),
        _line(t.ink));
    c.drawLine(const Offset(46, 60), const Offset(78, 60), _line(t.mut, 2.4));
    c.drawLine(const Offset(46, 70), const Offset(78, 70), _line(t.mut, 2.4));
    c.drawLine(const Offset(46, 80), const Offset(64, 80), _line(t.mut, 2.4));
  }

  @override
  bool shouldRepaint(_IllPainter old) => old.kind != kind || old.t != t;
}
