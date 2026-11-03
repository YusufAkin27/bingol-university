import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/theme.dart';
import 'avatar_editor_model.dart';

/// Zemin renkleri: yalnız tema belirteçlerinden (ham renk yok). [AvatarBg.blur] için null.
Color? avatarBgColor(AvatarBg bg) => switch (bg) {
      AvatarBg.blur => null,
      AvatarBg.white => BuTokens.dark.onMedia,
      AvatarBg.black => BuTokens.dark.scrim,
      AvatarBg.brand => BuTokens.light.prPressed,
      AvatarBg.navy => BuTokens.dark.infoSoft,
      AvatarBg.sand => BuTokens.light.warnSoft,
    };

/// Düzenleme sonucunu [frame] karesine çizer. Hem canlı tuval hem nihai çıktı AYNI işlevi kullanır (gördüğün = kaydedilen).
///
/// - [image]: çözülmüş görsel; [geometry] mantıksal görsel boyutuna ([AvatarGeometry.imageWidth]) göre oranlanır
///   (önizleme küçültülmüş görsel olabilir).
/// - [viewport]: görselin çizim kırpması. Null: yalnız [frame] (çıktı). Verilirse görsel çerçevenin dışında da
///   (karartılacak şekilde) görünür; zemin ve vinyet yine yalnız çerçeve içindedir.
void paintAvatarComposition(
  Canvas canvas,
  Rect frame, {
  required ui.Image image,
  required AvatarEditState state,
  required AvatarGeometry geometry,
  Rect? viewport,
}) {
  final k = frame.width / AvatarGeometry.frame;
  final angle = geometry.angle(state);
  final ratio = image.width / geometry.imageWidth; // gerçek piksel / mantıksal piksel
  final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final matrix = avatarColorMatrix(state.filter, state.adjust);
  final identity = isIdentityMatrix(matrix);

  void drawImage(double scaleLogical, Offset center, {Paint? paint}) {
    final p = paint ?? Paint();
    p.filterQuality = FilterQuality.high;
    if (!identity) p.colorFilter = ColorFilter.matrix(matrix);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    if (state.flip) canvas.scale(-1, 1);
    final w = image.width * scaleLogical / ratio, h = image.height * scaleLogical / ratio;
    canvas.drawImageRect(image, src, Rect.fromCenter(center: Offset.zero, width: w, height: h), p);
    canvas.restore();
  }

  canvas.save();
  canvas.clipRect(viewport ?? frame);

  // 1) Zemin (yalnız çerçeve içinde).
  canvas.save();
  canvas.clipRect(frame);
  final bgColor = avatarBgColor(state.bg);
  if (bgColor != null) {
    canvas.drawRect(frame, Paint()..color = bgColor);
  } else {
    // Bulanık: aynı görsel çerçeveyi kaplayacak kadar büyütülüp bulanıklaştırılır (kenar sızıntısı için %30 pay).
    final sigma = frame.width * .045;
    canvas.saveLayer(frame.inflate(frame.width * .2), Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp));
    drawImage(geometry.fillScale(angle) * k * 1.3, frame.center);
    canvas.restore();
    // Hafif karartma: ön plandaki görsel zeminden ayrışır.
    canvas.drawRect(frame, Paint()..color = BuTokens.dark.scrim.withValues(alpha: .12));
  }
  canvas.restore();

  // 2) Görsel.
  final c = frame.center + state.offset * k;
  drawImage(geometry.scale(state) * k, c);

  // 3) Vinyet (yalnız çerçeve içinde, görselin üstünde).
  final v = state.adjust.vignette;
  if (v > 0) {
    canvas.save();
    canvas.clipRect(frame);
    final shader = ui.Gradient.radial(
      frame.center,
      frame.width * .75,
      [BuTokens.dark.scrim.withValues(alpha: 0), BuTokens.dark.scrim.withValues(alpha: 0), BuTokens.dark.scrim.withValues(alpha: .8 * v)],
      const [0, .45, 1],
    );
    canvas.drawRect(frame, Paint()..shader = shader);
    canvas.restore();
  }
  canvas.restore();
}

/// Nihai çıktı: [size] x [size] kare, JPEG (EXIF/meta yok). Sunucu yükleme hattı bunu olduğu gibi (<= 2 MB) alır.
/// Çizim ana isolate'ta (GPU), JPEG kodlama ayrı isolate'ta yapılır. Hata durumunda null.
Future<Uint8List?> renderAvatarJpeg({
  required ui.Image image,
  required AvatarEditState state,
  required AvatarGeometry geometry,
  int size = 1024,
  int quality = 90,
}) async {
  ui.Image? out;
  try {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final frame = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    paintAvatarComposition(canvas, frame, image: image, state: state, geometry: geometry);
    final pic = rec.endRecording();
    out = await pic.toImage(size, size);
    pic.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final args = (raw: raw, size: size, quality: quality);
    return await Isolate.run(() => _encodeJpeg(args));
  } catch (_) {
    return null;
  } finally {
    out?.dispose();
  }
}

Uint8List _encodeJpeg(({Uint8List raw, int size, int quality}) a) {
  final im = img.Image.fromBytes(
      width: a.size, height: a.size, bytes: a.raw.buffer, bytesOffset: a.raw.offsetInBytes, numChannels: 4, order: img.ChannelOrder.rgba);
  return Uint8List.fromList(img.encodeJpg(im, quality: a.quality));
}

/// Karartma + daire maske + ince beyaz halka + (isteğe bağlı) kılavuzlar.
class AvatarMaskPainter extends CustomPainter {
  const AvatarMaskPainter({required this.frame, required this.guides, required this.fineGrid, required this.scrimColor, required this.lineColor});

  final Rect frame;

  /// Sürüklerken: üçte bir ızgarası + merkez artısı.
  final bool guides;

  /// Açı kaydırıcısı sürülürken: sık ızgara (düzeltme çizgileri).
  final bool fineGrid;
  final Color scrimColor, lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Path()..addOval(frame);
    final all = Path()..addRect(Offset.zero & size);
    canvas.drawPath(Path.combine(PathOperation.difference, all, circle), Paint()..color = scrimColor);
    if (guides || fineGrid) {
      canvas.save();
      canvas.clipPath(circle);
      final p = Paint()
        ..color = lineColor.withValues(alpha: fineGrid ? .35 : .45)
        ..strokeWidth = 1;
      final n = fineGrid ? 8 : 3;
      for (var i = 1; i < n; i++) {
        final t = i / n;
        canvas.drawLine(Offset(frame.left + frame.width * t, frame.top), Offset(frame.left + frame.width * t, frame.bottom), p);
        canvas.drawLine(Offset(frame.left, frame.top + frame.height * t), Offset(frame.right, frame.top + frame.height * t), p);
      }
      if (guides && !fineGrid) {
        // Merkez artısı: yüz/orta nokta.
        final cp = Paint()
          ..color = lineColor.withValues(alpha: .8)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final c = frame.center;
        final r = math.min(frame.width, frame.height) * .035;
        canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), cp);
        canvas.drawLine(c.translate(0, -r), c.translate(0, r), cp);
      }
      canvas.restore();
    }
    canvas.drawOval(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = lineColor.withValues(alpha: .92),
    );
  }

  @override
  bool shouldRepaint(AvatarMaskPainter o) =>
      o.frame != frame || o.guides != guides || o.fineGrid != fineGrid || o.scrimColor != scrimColor || o.lineColor != lineColor;
}

/// Tuvalin canlı önizlemesi.
class AvatarCanvasPainter extends CustomPainter {
  const AvatarCanvasPainter({required this.image, required this.state, required this.geometry, required this.frame});

  final ui.Image image;
  final AvatarEditState state;
  final AvatarGeometry geometry;
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    paintAvatarComposition(canvas, frame, image: image, state: state, geometry: geometry, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(AvatarCanvasPainter o) => o.image != image || o.state != state || o.frame != frame || o.geometry != geometry;
}
