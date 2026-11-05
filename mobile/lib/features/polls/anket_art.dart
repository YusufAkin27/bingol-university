import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Anket ve destek ekranlarının boş durum illüstrasyonları (kodla çizilir, tema renkli, dosya yok).
/// Monochrome: 120x120 tuval, yalnız `ink` çizgi + nötr yüzey tonları (renkli vurgu, gölge ve süs noktası yok).
enum AnketArt { ballot, chart, idea, ticket, help }

/// Dekoratif (anlam dışı); [size] kenara ölçeklenir.
class AnketArtView extends StatelessWidget {
  const AnketArtView(this.kind, {super.key, this.size = 120});

  final AnketArt kind;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: _ArtPainter(kind, context.bu))),
      );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind, this.t);

  final AnketArt kind;
  final BuTokens t;

  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill;
  Paint _line(Color c, [double w = 2.4]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120);
    // zemin: nötr daire
    canvas.drawCircle(const Offset(60, 62), 50, _fill(t.sf2));
    canvas.drawCircle(const Offset(60, 62), 36, _fill(t.sf3.withValues(alpha: .6)));
    switch (kind) {
      case AnketArt.ballot:
        _ballot(canvas);
      case AnketArt.chart:
        _chart(canvas);
      case AnketArt.idea:
        _idea(canvas);
      case AnketArt.ticket:
        _ticket(canvas);
      case AnketArt.help:
        _help(canvas);
    }
    canvas.restore();
  }

  void _card(Canvas c, RRect r, {Color? fill}) {
    c.drawRRect(r, _fill(fill ?? t.sf));
    c.drawRRect(r, _line(t.ink));
  }

  // Oy pusulası: üç satır, ilki işaretli.
  void _ballot(Canvas c) {
    c.save();
    c.translate(60, 62);
    c.rotate(-.06);
    c.translate(-60, -62);
    _card(c, RRect.fromRectAndRadius(const Rect.fromLTWH(30, 22, 60, 76), const Radius.circular(10)));
    c.drawLine(const Offset(40, 34), const Offset(64, 34), _line(t.ink, 2.8));
    for (var i = 0; i < 3; i++) {
      final y = 52.0 + i * 16;
      final on = i == 0;
      c.drawCircle(Offset(42, y), 5.2, _fill(on ? t.ink : t.sf));
      c.drawCircle(Offset(42, y), 5.2, _line(t.ink, 2));
      if (on) {
        final p = Path()
          ..moveTo(39.4, y + .2)
          ..lineTo(41.4, y + 2.3)
          ..lineTo(45, y - 1.8);
        c.drawPath(p, _line(t.onPr, 1.9));
      }
      c.drawLine(Offset(54, y), Offset(on ? 80 : (i == 1 ? 74 : 68), y), _line(on ? t.ink : t.bdStrong, 3));
    }
    c.restore();
    // kalem
    final pen = Path()
      ..moveTo(84, 70)
      ..lineTo(102, 52)
      ..lineTo(108, 58)
      ..lineTo(90, 76)
      ..close();
    c.drawPath(pen, _fill(t.sf3));
    c.drawPath(pen, _line(t.ink, 2.2));
    final tip = Path()
      ..moveTo(84, 70)
      ..lineTo(82, 80)
      ..lineTo(90, 76)
      ..close();
    c.drawPath(tip, _fill(t.ink));
  }

  // Sütun grafik: en uzun sütun `ink`, diğerleri nötr gri.
  void _chart(Canvas c) {
    _card(c, RRect.fromRectAndRadius(const Rect.fromLTWH(24, 26, 72, 66), const Radius.circular(10)));
    final bars = [
      (36.0, 26.0, t.bdStrong),
      (52.0, 46.0, t.ink),
      (68.0, 34.0, t.bdStrong),
      (84.0, 18.0, t.bdStrong),
    ];
    for (final b in bars) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(b.$1 - 5, 82 - b.$2, 10, b.$2), const Radius.circular(3));
      c.drawRRect(r, _fill(b.$3));
    }
    c.drawLine(const Offset(30, 83), const Offset(90, 83), _line(t.ink, 2));
    c.drawLine(const Offset(34, 36), const Offset(52, 36), _line(t.bdStrong, 3));
  }

  // Ampul: öneri/fikir.
  void _idea(Canvas c) {
    c.drawCircle(const Offset(60, 52), 24, _fill(t.sf3));
    c.drawCircle(const Offset(60, 52), 24, _line(t.ink));
    final base = RRect.fromRectAndRadius(const Rect.fromLTWH(50, 74, 20, 14), const Radius.circular(4));
    _card(c, base, fill: t.sf2);
    c.drawLine(const Offset(53, 80), const Offset(67, 80), _line(t.ink, 2));
    c.drawLine(const Offset(55, 95), const Offset(65, 95), _line(t.ink, 2.4));
    final fil = Path()
      ..moveTo(53, 58)
      ..lineTo(57, 48)
      ..lineTo(63, 56)
      ..lineTo(67, 46);
    c.drawPath(fil, _line(t.ink, 2.6));
    const o = Offset(60, 52);
    for (final deg in [-160.0, -125.0, -90.0, -55.0, -20.0]) {
      final a = deg * math.pi / 180;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawLine(o + d * 31, o + d * 38, _line(t.ink, 2.6));
    }
  }

  // Bilet: destek talebi.
  void _ticket(Canvas c) {
    final body = Path()
      ..moveTo(26, 38)
      ..lineTo(94, 38)
      ..arcToPoint(const Offset(94, 56), radius: const Radius.circular(9), clockwise: false)
      ..lineTo(94, 84)
      ..lineTo(26, 84)
      ..lineTo(26, 56)
      ..arcToPoint(const Offset(26, 38), radius: const Radius.circular(9), clockwise: false)
      ..close();
    c.drawPath(body, _fill(t.sf));
    c.drawPath(body, _line(t.ink));
    final dash = _line(t.bdStrong, 2);
    for (var y = 42.0; y < 82; y += 8) {
      c.drawLine(Offset(78, y), Offset(78, y + 4), dash);
    }
    c.drawLine(const Offset(36, 52), const Offset(66, 52), _line(t.ink, 2.8));
    c.drawLine(const Offset(36, 64), const Offset(60, 64), _line(t.bdStrong, 3));
    c.drawLine(const Offset(36, 74), const Offset(52, 74), _line(t.bdStrong, 3));
    c.drawCircle(const Offset(86, 61), 5, _fill(t.ink));
  }

  // Konuşma balonu + soru işareti: yardım.
  void _help(Canvas c) {
    final bubble = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 26, 68, 50), const Radius.circular(16));
    final tail = Path()
      ..moveTo(44, 74)
      ..lineTo(40, 92)
      ..lineTo(60, 76)
      ..close();
    c.drawPath(tail, _fill(t.sf));
    c.drawRRect(bubble, _fill(t.sf));
    c.drawRRect(bubble, _line(t.ink));
    c.drawPath(tail, _line(t.ink));
    final q = Path()
      ..moveTo(52, 46)
      ..arcToPoint(const Offset(68, 46), radius: const Radius.circular(8), clockwise: true)
      ..cubicTo(68, 52, 60, 52, 60, 58);
    c.drawPath(q, _line(t.ink, 3));
    c.drawCircle(const Offset(60, 66), 2.2, _fill(t.ink));
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.kind != kind || old.t != t;
}

/// Boş durum: illüstrasyon + başlık + açıklama (+ eylem). `BuEmptyState`'in anket/destek illüstrasyonlu eşi; ekranı
/// ortalar, sığmazsa kaydırır, belirirken bir kez yumuşakça yükselir (hareket azaltılmışsa anında).
class AnketEmptyState extends StatelessWidget {
  const AnketEmptyState({
    super.key,
    required this.art,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final AnketArt art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Liste içi küçük görünüm (kart içinde).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final col = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnketArtView(art, size: compact ? 92 : 128),
          SizedBox(height: compact ? 8 : 16),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? 12 : 20),
            SizedBox(width: 220, child: BuButton(label: actionLabel!, onPressed: onAction)),
          ],
        ],
      ),
    );
    final padded = Padding(padding: EdgeInsets.all(compact ? 16 : 24), child: col);
    final animated = _Rise(child: padded);
    if (compact) return Center(child: animated);
    return LayoutBuilder(
      builder: (context, c) => c.hasBoundedHeight
          ? SingleChildScrollView(
              child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: Center(child: animated)),
            )
          : Center(child: animated),
    );
  }
}

/// Belirirken bir kez yükselme (14 dp) + solma; hareket azaltılmışsa anında.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (BuMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: BuMotion.long,
      curve: BuMotion.emphasizedDecelerate,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
      child: child,
    );
  }
}
