import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../events/qr_painter.dart' show QrCode;
import 'profile_qr_widgets.dart' show kQrInk, kQrPaper;

/// Profil QR'Ã„Â±nÃ„Â±n gÃƒÂ¶rsel stili (yoklama QR'Ã„Â± `events/qr_painter.dart` AYNEN kalÃ„Â±r; bu yalnÃ„Â±z profil iÃƒÂ§indir).
///
/// Tarama gÃƒÂ¼venliÃ„Å¸i ÃƒÂ¶nceliklidir: modÃƒÂ¼ller yalnÃ„Â±z hafif yuvarlatÃ„Â±lÃ„Â±r (kÃƒÂ¶Ã…Å¸e yarÃ„Â±ÃƒÂ§apÃ„Â± 0,28 hÃƒÂ¼cre; komÃ…Å¸u modÃƒÂ¼ller yine
/// hÃƒÂ¼cre sÃ„Â±nÃ„Â±rÃ„Â±nda buluÃ…Å¸ur), ÃƒÂ¼ÃƒÂ§ bulucu "gÃƒÂ¶z" yapÃ„Â±sÃ„Â± (7x7 halka + 3x3 ÃƒÂ§ekirdek) korunur, koyu modÃƒÂ¼l / aÃƒÂ§Ã„Â±k zemin
/// kontrastÃ„Â± sabittir, sessiz bÃƒÂ¶lge 4 modÃƒÂ¼ldÃƒÂ¼r. Ortaya logo KONMAZ (hata dÃƒÂ¼zeltme dÃƒÂ¼zeyi M).
class ProfileQrStylePainter extends CustomPainter {
  ProfileQrStylePainter(this.qr, {Color? ink, Color? paper, this.quiet = 4})
      : ink = ink ?? kQrInk,
        paper = paper ?? kQrPaper;

  final QrCode qr;
  final Color ink;
  final Color paper;

  /// Sessiz bÃƒÂ¶lge (modÃƒÂ¼l). Standart en az 4.
  final int quiet;

  /// Veri modÃƒÂ¼lÃƒÂ¼ kÃƒÂ¶Ã…Å¸e yuvarlaklÃ„Â±Ã„Å¸Ã„Â± (hÃƒÂ¼cre oranÃ„Â±). 0,3'ÃƒÂ¼ aÃ…Å¸maz: bunun ÃƒÂ¼stÃƒÂ¼ bazÃ„Â± tarayÃ„Â±cÃ„Â±larda doÃ„Å¸ruluÃ„Å¸u dÃƒÂ¼Ã…Å¸ÃƒÂ¼rÃƒÂ¼r.
  /// Göz (bulucu) köşe yuvarlaklıkları: OpenCV ile 6 farklı kimlik uzunluğunda doğrulanan en yuvarlak değerler;
  /// daha fazlası (1,0+) bazı kimliklerde çözümü bozdu.
  static const double eyeOuter = .5, eyeMid = .2, eyeCore = .4;
  static const double moduleRadius = 0.28;

  static bool _inFinder(int x, int y, int n) =>
      (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7);

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.size;
    final cells = n + quiet * 2;
    final cell = size.shortestSide / cells;
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final off = quiet * cell;
    final p = Paint()
      ..color = ink
      ..isAntiAlias = true;

    final data = Path();
    final r = Radius.circular(cell * moduleRadius);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (_inFinder(x, y, n) || !qr.isDark(x, y)) continue;
        data.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(off + x * cell, off + y * cell, cell, cell), r));
      }
    }
    canvas.drawPath(data, p);

    for (final o in [(0, 0), (n - 7, 0), (0, n - 7)]) {
      final left = off + o.$1 * cell, top = off + o.$2 * cell;
      final eye = Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, 7 * cell, 7 * cell), Radius.circular(cell * eyeOuter)))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(left + cell, top + cell, 5 * cell, 5 * cell), Radius.circular(cell * eyeMid)))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 2 * cell, top + 2 * cell, 3 * cell, 3 * cell), Radius.circular(cell * eyeCore)));
      canvas.drawPath(eye, p);
    }
  }

  @override
  bool shouldRepaint(ProfileQrStylePainter old) =>
      old.qr != qr || old.ink != ink || old.paper != paper || old.quiet != quiet;
}

/// KÃƒÂ¶Ã…Å¸e iÃ…Å¸aretleri (L biÃƒÂ§imli dÃƒÂ¶rt ayraÃƒÂ§): ÃƒÂ§erÃƒÂ§evenin kÃƒÂ¶Ã…Å¸elerine ÃƒÂ§izilir, QR'a ve sessiz bÃƒÂ¶lgeye girmez.
class QrCornerMarks extends CustomPainter {
  QrCornerMarks({required this.color, this.arm = 22, this.stroke = 3.5, this.inset = 0});

  final Color color;
  final double arm;
  final double stroke;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final l = inset + stroke / 2, t = inset + stroke / 2, r = size.width - l, b = size.height - t;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawPath(
          Path()
            ..moveTo(x + dx * arm, y)
            ..lineTo(x, y)
            ..lineTo(x, y + dy * arm),
          p);
    }

    corner(l, t, 1, 1);
    corner(r, t, -1, 1);
    corner(l, b, 1, -1);
    corner(r, b, -1, -1);
  }

  @override
  bool shouldRepaint(QrCornerMarks old) => old.color != color || old.arm != arm || old.stroke != stroke || old.inset != inset;
}

/// PaylaÃ…Å¸Ã„Â±m kartÃ„Â± (PNG) metinleri: ÃƒÂ§aÃ„Å¸Ã„Â±ran yerelleÃ…Å¸tirir.
class ProfileCardTexts {
  const ProfileCardTexts({
    required this.brand,
    required this.name,
    required this.findMe,
    required this.link,
    this.username,
    this.rtl = false,
  });

  final String brand;
  final String name;
  final String? username;
  final String findMe;
  final String link;
  final bool rtl;
}

/// 4:5 (1080x1350) siyah-beyaz paylaÃ…Å¸Ã„Â±m kartÃ„Â±: marka satÃ„Â±rÃ„Â±, ad, @kullanÃ„Â±cÃ„Â± adÃ„Â±, ÃƒÂ§erÃƒÂ§eveli bÃƒÂ¼yÃƒÂ¼k QR, "Beni BÃƒÅ“ KampÃƒÂ¼s'te
/// bul" ve baÃ„Å¸lantÃ„Â± alt yazÃ„Â±sÃ„Â±. Her zaman aÃƒÂ§Ã„Â±k zemin / koyu modÃƒÂ¼l (sosyal ortamda ve yazÃ„Â±cÃ„Â±da aynÃ„Â± okunur).
/// Avatar bilinÃƒÂ§li YOK: gÃƒÂ¶rsel yÃƒÂ¼klemesi aÃ„Å¸a baÃ„Å¸lÃ„Â±dÃ„Â±r, kart ÃƒÂ§evrimdÃ„Â±Ã…Å¸Ã„Â± da ÃƒÂ¼retilebilmeli.
Future<Uint8List?> renderProfileCardPng(String data, ProfileCardTexts t, {int width = 1080}) async {
  final qr = QrCode.tryEncode(data);
  if (qr == null) return null;
  final w = width.toDouble(), h = w * 5 / 4;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = kQrPaper);
  final dir = t.rtl ? TextDirection.rtl : TextDirection.ltr;

  double text(String s, double y, double size, Color color, {double letter = 0, int maxLines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, letterSpacing: letter, height: 1.15)),
      textDirection: dir,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      ellipsis: 'Ã¢â‚¬Â¦',
    )..layout(maxWidth: w - 160);
    tp.paint(c, Offset((w - tp.width) / 2, y));
    return tp.height;
  }

  final mut = kQrInk.withValues(alpha: .6);
  var y = 96.0;
  y += text(t.brand.toUpperCase(), y, 34, kQrInk, letter: t.rtl ? 0 : 6) + 44;
  y += text(t.name, y, 76, kQrInk, maxLines: 2) + 12;
  if (t.username != null) y += text(t.username!, y, 42, mut) + 12;
  y += 40;

  // QR plakasÃ„Â±: 4 kÃƒÂ¶Ã…Å¸e iÃ…Å¸areti + sessiz bÃƒÂ¶lgeli QR.
  final plate = w - 2 * 150;
  final left = (w - plate) / 2;
  c.save();
  c.translate(left, y);
  QrCornerMarks(color: kQrInk, arm: 64, stroke: 10).paint(c, Size(plate, plate));
  const pad = 44.0;
  c.translate(pad, pad);
  ProfileQrStylePainter(qr, quiet: 4).paint(c, Size.square(plate - 2 * pad));
  c.restore();
  y += plate + 56;

  y += text(t.findMe, y, 50, kQrInk) + 14;
  text(t.link.replaceFirst(RegExp(r'^https?://'), ''), y, 34, mut);

  final img = await rec.endRecording().toImage(width, h.round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// YalnÃ„Â±z test/doÃ„Å¸rulama: QR'Ã„Â±n tek baÃ…Å¸Ã„Â±na, yÃƒÂ¼ksek ÃƒÂ§ÃƒÂ¶zÃƒÂ¼nÃƒÂ¼rlÃƒÂ¼klÃƒÂ¼ PNG'si (stil painter'Ã„Â±).
Future<Uint8List?> renderStyledQrPng(String data, {int px = 800, Color? ink, Color? paper}) async {
  final qr = QrCode.tryEncode(data);
  if (qr == null) return null;
  final rec = ui.PictureRecorder();
  ProfileQrStylePainter(qr, ink: ink, paper: paper).paint(Canvas(rec), Size.square(px.toDouble()));
  final img = await rec.endRecording().toImage(px, math.max(px, 1));
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
