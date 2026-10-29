import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'auth_motion.dart';

/// Kod ile çizilmiş küçük marka illüstrasyonları (dış görsel yok; her biri tek CustomPainter).
enum AuthArtKind { envelope, key, lock, cap, user, shield }

class AuthArt extends StatelessWidget {
  const AuthArt(this.kind, {super.key, this.size = 112});

  final AuthArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ArtPainter(
              kind: kind,
              clock: authClockOf(context),
              pr: t.pr,
              soft: t.soft,
              sf: t.sf,
              ink: t.ink,
              mut: t.mut,
              ok: t.ok,
              onPr: t.onPr,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({
    required this.kind,
    required this.clock,
    required this.pr,
    required this.soft,
    required this.sf,
    required this.ink,
    required this.mut,
    required this.ok,
    required this.onPr,
    required this.dark,
  }) : super(repaint: clock);

  final AuthArtKind kind;
  final Animation<double> clock;
  final Color pr, soft, sf, ink, mut, ok, onPr;
  final bool dark;

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s);
    // 24 sn'lik saatin 6 katı: 4 sn'de bir nefes alan süzülme (döngü kapanışı kesintisiz).
    final ph = clock.value * math.pi * 12;
    final fy = math.sin(ph) * 2.6;

    // Zemin: yumuşak daire + iki ince halka.
    canvas.drawCircle(const Offset(60, 60), 54, _fill(soft));
    canvas.drawCircle(const Offset(60, 60), 54, _stroke(pr.withValues(alpha: .22), 1.2));
    canvas.drawCircle(const Offset(60, 60), 44, _stroke(pr.withValues(alpha: .10), 1));

    // Süzülen minik noktalar.
    canvas.drawCircle(Offset(18, 36 + math.sin(ph + 1) * 3), 3.2, _fill(pr.withValues(alpha: .55)));
    canvas.drawCircle(Offset(104, 78 + math.sin(ph + 2.4) * 3), 2.4, _fill(pr.withValues(alpha: .40)));
    canvas.drawCircle(Offset(96, 22 + math.sin(ph + 4) * 2.5), 2, _fill(ink.withValues(alpha: .22)));

    canvas.save();
    canvas.translate(0, fy);
    switch (kind) {
      case AuthArtKind.envelope:
        _envelope(canvas);
      case AuthArtKind.key:
        _shield(canvas);
        _key(canvas);
      case AuthArtKind.lock:
        _shield(canvas);
        _lock(canvas);
      case AuthArtKind.cap:
        _cap(canvas);
      case AuthArtKind.user:
        _user(canvas);
      case AuthArtKind.shield:
        _shield(canvas);
        _tick(canvas);
    }
    canvas.restore();
    canvas.restore();
  }

  void _envelope(Canvas canvas) {
    // Mektup (zarfın içinden çıkan kart).
    canvas.save();
    canvas.translate(60, 50);
    canvas.rotate(-.09);
    final card = RRect.fromLTRBR(-23, -24, 23, 18, const Radius.circular(7));
    canvas.drawRRect(card, _fill(sf));
    canvas.drawRRect(card, _stroke(pr.withValues(alpha: .35), 1.4));
    canvas.drawRRect(RRect.fromLTRBR(-14, -14, 8, -9, const Radius.circular(2.5)), _fill(pr.withValues(alpha: .85)));
    canvas.drawRRect(RRect.fromLTRBR(-14, -4, 14, -1, const Radius.circular(1.5)), _fill(mut.withValues(alpha: .35)));
    canvas.drawRRect(RRect.fromLTRBR(-14, 3, 6, 6, const Radius.circular(1.5)), _fill(mut.withValues(alpha: .35)));
    canvas.restore();

    // Zarf gövdesi + kapak çizgileri.
    final body = RRect.fromLTRBR(23, 56, 97, 96, const Radius.circular(10));
    canvas.drawRRect(body, _fill(pr));
    canvas.drawPath(
      Path()
        ..moveTo(26, 59)
        ..lineTo(60, 80)
        ..lineTo(94, 59),
      _stroke(onPr.withValues(alpha: .92), 2.6),
    );
    canvas.drawLine(const Offset(27, 92), const Offset(52, 74), _stroke(onPr.withValues(alpha: .30), 1.6));
    canvas.drawLine(const Offset(93, 92), const Offset(68, 74), _stroke(onPr.withValues(alpha: .30), 1.6));

    // Rozet: onay.
    canvas.drawCircle(const Offset(96, 44), 12.5, _fill(sf));
    canvas.drawCircle(const Offset(96, 44), 10, _fill(ok));
    canvas.drawPath(
      Path()
        ..moveTo(91.5, 44.2)
        ..lineTo(95, 47.6)
        ..lineTo(101, 41),
      _stroke(Colors.white, 2.2),
    );
  }

  Path _shieldPath() => Path()
    ..moveTo(60, 17)
    ..lineTo(95, 29)
    ..lineTo(95, 58)
    ..cubicTo(95, 80, 79, 94, 60, 103)
    ..cubicTo(41, 94, 25, 80, 25, 58)
    ..lineTo(25, 29)
    ..close();

  void _shield(Canvas canvas) {
    final p = _shieldPath();
    canvas.drawShadow(p, ink.withValues(alpha: dark ? .5 : .22), 6, false);
    canvas.drawPath(p, _fill(sf));
    canvas.drawPath(p, _stroke(pr, 3));
    // İç ince çizgi: kalkana derinlik.
    canvas.save();
    canvas.translate(60, 60);
    canvas.scale(.82);
    canvas.translate(-60, -60);
    canvas.drawPath(p, _stroke(pr.withValues(alpha: .18), 1.4));
    canvas.restore();
  }

  void _key(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 52), 10.5, _stroke(pr, 5));
    canvas.drawLine(const Offset(58, 60), const Offset(80, 82), _stroke(pr, 5));
    canvas.drawLine(const Offset(72, 74), const Offset(77, 69), _stroke(pr, 4.2));
    canvas.drawLine(const Offset(78, 80), const Offset(83, 75), _stroke(pr, 4.2));
    canvas.drawCircle(const Offset(47.5, 49.5), 2.4, _fill(pr.withValues(alpha: .28)));
  }

  void _lock(Canvas canvas) {
    canvas.drawArc(const Rect.fromLTWH(49, 41, 22, 26), math.pi, math.pi, false, _stroke(pr, 5));
    canvas.drawLine(const Offset(51.5, 54), const Offset(51.5, 60), _stroke(pr, 5));
    canvas.drawLine(const Offset(68.5, 54), const Offset(68.5, 60), _stroke(pr, 5));
    final b = RRect.fromLTRBR(44, 58, 76, 82, const Radius.circular(7));
    canvas.drawRRect(b, _fill(pr));
    canvas.drawCircle(const Offset(60, 67.5), 3.2, _fill(onPr));
    canvas.drawLine(const Offset(60, 68), const Offset(60, 74), _stroke(onPr, 2.8));
  }

  void _tick(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(46, 60)
        ..lineTo(57, 71)
        ..lineTo(76, 48),
      _stroke(pr, 6),
    );
  }

  void _cap(Canvas canvas) {
    // Gövde (arka), kep (ön), püskül.
    final base = Path()
      ..moveTo(40, 60)
      ..lineTo(40, 76)
      ..cubicTo(40, 84, 80, 84, 80, 76)
      ..lineTo(80, 60)
      ..close();
    canvas.drawPath(base, _fill(pr.withValues(alpha: .72)));
    final top = Path()
      ..moveTo(60, 30)
      ..lineTo(100, 48)
      ..lineTo(60, 66)
      ..lineTo(20, 48)
      ..close();
    canvas.drawShadow(top, ink.withValues(alpha: .25), 3, false);
    canvas.drawPath(top, _fill(pr));
    canvas.drawPath(top, _stroke(onPr.withValues(alpha: .22), 1.2));
    canvas.drawLine(const Offset(60, 48), const Offset(94, 52), _stroke(onPr.withValues(alpha: .55), 1.6));
    canvas.drawLine(const Offset(94, 52), const Offset(94, 72), _stroke(const Color(0xFFFFB020), 3));
    canvas.drawCircle(const Offset(94, 75), 4, _fill(const Color(0xFFFFB020)));
    canvas.drawCircle(const Offset(60, 48), 3.4, _fill(onPr));
  }

  void _user(Canvas canvas) {
    // Kimlik kartı gibi: yuvarlak kart + baş + omuz.
    final card = RRect.fromLTRBR(26, 30, 94, 92, const Radius.circular(14));
    canvas.drawShadow(Path()..addRRect(card), ink.withValues(alpha: .22), 5, false);
    canvas.drawRRect(card, _fill(sf));
    canvas.drawRRect(card, _stroke(pr.withValues(alpha: .35), 1.6));
    canvas.drawCircle(const Offset(60, 54), 11, _fill(pr));
    final sh = Path()
      ..moveTo(40, 86)
      ..cubicTo(40, 68, 80, 68, 80, 86)
      ..close();
    canvas.drawPath(sh, _fill(pr));
    canvas.drawRRect(RRect.fromLTRBR(36, 37, 56, 41, const Radius.circular(2)), _fill(mut.withValues(alpha: .3)));
    canvas.drawCircle(const Offset(91, 33), 10.5, _fill(sf));
    canvas.drawCircle(const Offset(91, 33), 8.4, _fill(ok));
    canvas.drawPath(
      Path()
        ..moveTo(87.4, 33.2)
        ..lineTo(90.2, 35.9)
        ..lineTo(95, 30.4),
      _stroke(Colors.white, 2),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.kind != kind || old.pr != pr || old.soft != soft || old.sf != sf || old.dark != dark;
}

/// Başarı: yeşil daire büyür, tik çizilir, konfeti saçılır (tek denetleyici, ~1.6 sn, sonra durur).
class AuthSuccessBadge extends StatefulWidget {
  const AuthSuccessBadge({super.key, this.size = 148});

  final double size;

  @override
  State<AuthSuccessBadge> createState() => _AuthSuccessBadgeState();
}

class _AuthSuccessBadgeState extends State<AuthSuccessBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
      authHaptic(AuthHaptic.success);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: CustomPaint(
            painter: _SuccessPainter(_c, ok: t.ok, soft: t.okSoft, pr: t.pr, ink: t.ink),
          ),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.c, {required this.ok, required this.soft, required this.pr, required this.ink})
      : super(repaint: c) {
    final r = math.Random(11);
    for (var i = 0; i < 26; i++) {
      _parts.add(_Part(
        angle: (i / 26) * math.pi * 2 + r.nextDouble() * .5,
        speed: 90 + r.nextDouble() * 80,
        spin: (r.nextDouble() - .5) * 14,
        size: 4 + r.nextDouble() * 4,
        rect: i.isEven,
        color: [pr, ok, const Color(0xFFFFB020), const Color(0xFF4C8DFF), const Color(0xFFFF7AA8)][i % 5],
      ));
    }
  }

  final Animation<double> c;
  final Color ok, soft, pr, ink;
  final List<_Part> _parts = [];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final v = c.value;
    final base = size.width / 1.5 / 2; // yarıçap tabanı
    // Daire: 0 - .35 arası büyür (taşmalı yay).
    final grow = Curves.easeOutBack.transform((v / .35).clamp(0.0, 1.0));
    final r = base * .62 * grow;
    // Dışa yayılan halka.
    final ringT = ((v - .1) / .6).clamp(0.0, 1.0);
    if (ringT > 0 && ringT < 1) {
      canvas.drawCircle(
        center,
        r + base * .5 * ringT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ok.withValues(alpha: .35 * (1 - ringT)),
      );
    }
    canvas.drawCircle(center, r * 1.22, Paint()..color = soft);
    canvas.drawCircle(center, r, Paint()..color = ok);

    // Tik: .3 - .65 arası çizilir.
    final tv = Curves.easeOutCubic.transform(((v - .3) / .35).clamp(0.0, 1.0));
    if (tv > 0) {
      final s = r / 40;
      final path = Path()
        ..moveTo(center.dx - 17 * s, center.dy + 1 * s)
        ..lineTo(center.dx - 5 * s, center.dy + 13 * s)
        ..lineTo(center.dx + 19 * s, center.dy - 13 * s);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * tv),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }

    // Konfeti: .35'ten sonra; yerçekimi + sönme.
    final cv = ((v - .35) / .65).clamp(0.0, 1.0);
    if (cv > 0 && cv < 1) {
      final fade = (1 - math.pow(cv, 2.2)).toDouble();
      for (final p in _parts) {
        final d = p.speed * Curves.easeOutQuad.transform(cv) * (base / 110);
        final dx = math.cos(p.angle) * d;
        final dy = math.sin(p.angle) * d + 80 * cv * cv * (base / 110);
        canvas.save();
        canvas.translate(center.dx + dx, center.dy + dy);
        canvas.rotate(p.spin * cv);
        final paint = Paint()..color = p.color.withValues(alpha: fade);
        if (p.rect) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * .8),
                  const Radius.circular(1.5)),
              paint);
        } else {
          canvas.drawCircle(Offset.zero, p.size * .5, paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) => old.ok != ok || old.pr != pr;
}

class _Part {
  _Part({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.rect,
    required this.color,
  });

  final double angle, speed, spin, size;
  final bool rect;
  final Color color;
}

/// Hero için küçük marka işareti parıltısı: kare üzerinde bir kez geçen çapraz ışık bandı.
class AuthSheenPainter extends CustomPainter {
  AuthSheenPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final v = progress.value;
    if (v <= 0 || v >= 1) return;
    final x = ui.lerpDouble(-size.width * .6, size.width * 1.6, v)!;
    canvas.save();
    canvas.translate(x, 0);
    final rect = Rect.fromLTWH(0, 0, size.width * .35, size.height);
    final skew = Path()
      ..moveTo(rect.left + 18, 0)
      ..lineTo(rect.right + 18, 0)
      ..lineTo(rect.right - 18, size.height)
      ..lineTo(rect.left - 18, size.height)
      ..close();
    canvas.drawPath(
      skew,
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: .55),
          Colors.white.withValues(alpha: 0),
        ]).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AuthSheenPainter old) => false;
}

/// Kırmızı sahne: nefes alan halkalar, yumuşak ışık lekeleri ve alttan yükselen üç yavaş dalga.
class AuthHeroPainter extends CustomPainter {
  AuthHeroPainter(this.clock, {this.ringY = .40}) : super(repaint: clock);

  final Animation<double> clock;
  final double ringY;

  @override
  void paint(Canvas canvas, Size size) {
    final p = clock.value * math.pi * 2;
    final w = size.width, h = size.height;

    void glow(Offset c, double r, Color col, double a) {
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    glow(Offset(w * .12 + math.sin(p) * 24, h * .18 + math.cos(p * 2) * 12), 190, Colors.white, .16);
    glow(Offset(w * .92 + math.cos(p) * 20, h * .62 + math.sin(p * 2) * 16), 220, const Color(0xFF5A0F0A), .32);

    final center = Offset(w / 2, h * ringY);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const radii = [82.0, 124.0, 172.0, 224.0, 282.0];
    for (var i = 0; i < radii.length; i++) {
      ring.color = Colors.white.withValues(alpha: .20 - i * .033);
      canvas.drawCircle(center, radii[i] + math.sin(p * 2 + i) * 3.5, ring);
    }

    for (var k = 0; k < 3; k++) {
      final base = h - 70 + k * 12;
      final amp = 9.0 + k * 3;
      final wl = w * (1.1 - k * .18);
      final phase = p * (k + 1) + k * 1.7;
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w + 8; x += 8) {
        path.lineTo(x, base + math.sin(x / wl * math.pi * 2 + phase) * amp);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .06 + k * .035));
    }
  }

  @override
  bool shouldRepaint(AuthHeroPainter old) => false;
}
