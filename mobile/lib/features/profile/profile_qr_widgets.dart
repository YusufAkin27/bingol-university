import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../events/qr_painter.dart' show QrCode, QrPainter;

/// QR zemini/mürekkebi her iki temada da AYNIDIR (belirteç `qrPaper` beyaz, `qrInk` siyah; her iki BuTokens ayarında
/// sabit): koyu temada da beyaz zemin kutusunda okunur. Mevcut saf Dart üretici + çizici (yoklama QR'ı) yeniden
/// kullanılır; bağımsız çözücü testi `test/qr_painter_test.dart`.
Color get kQrPaper => BuTokens.light.qrPaper;
Color get kQrInk => BuTokens.light.qrInk;

/// [data] (profil bağlantısı) için QR; sığmazsa/bozulursa null.
QrCode? buildProfileQr(String data) {
  try {
    return QrCode.tryEncode(data);
  } catch (_) {
    return null;
  }
}

/// Sessiz bölgeli (4 modül) beyaz zeminli QR kutusu; her temada aynı görünür.
class ProfileQrView extends StatelessWidget {
  const ProfileQrView({super.key, required this.data, this.size = 240, this.semanticLabel});

  final String data;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final qr = buildProfileQr(data);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: qr == null ? null : QrPainter(qr, ink: kQrInk, paper: kQrPaper),
        ),
      ),
    );
  }
}

/// Paylaşım için PNG (yalnız kod; ad/avatar yok): [px] kenar uzunluğu, sessiz bölge dahil.
Future<Uint8List?> renderQrPng(String data, {int px = 1024}) async {
  final qr = buildProfileQr(data);
  if (qr == null) return null;
  final rec = ui.PictureRecorder();
  QrPainter(qr, ink: kQrInk, paper: kQrPaper).paint(Canvas(rec), Size.square(px.toDouble()));
  final img = await rec.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
