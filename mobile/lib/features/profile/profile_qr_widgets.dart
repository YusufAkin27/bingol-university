import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../events/qr_painter.dart' show QrCode;
import 'profile_qr_style.dart';

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
          painter: qr == null ? null : ProfileQrStylePainter(qr, ink: kQrInk, paper: kQrPaper),
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
  ProfileQrStylePainter(qr, ink: kQrInk, paper: kQrPaper).paint(Canvas(rec), Size.square(px.toDouble()));
  final img = await rec.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// QR plakası: beyaz zemin, yuvarlak köşe, dört köşe işareti ve içeride sessiz bölgeli QR. Her iki temada aynı
/// (koyu temada da beyaz plaka). Açılışta sade belirme (opaklık + %4 ölçek); "animasyonları azalt" açıkken anında.
class ProfileQrPlate extends StatefulWidget {
  const ProfileQrPlate({super.key, required this.data, required this.size, this.semanticLabel});

  final String data;

  /// Plakanın dış kenarı.
  final double size;
  final String? semanticLabel;

  @override
  State<ProfileQrPlate> createState() => _ProfileQrPlateState();
}

class _ProfileQrPlateState extends State<ProfileQrPlate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1;
    } else if (!_c.isCompleted && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = (widget.size * .07).clamp(14.0, 24.0);
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1).animate(curve),
        child: DecoratedBox(
          decoration: BoxDecoration(color: kQrPaper, borderRadius: BorderRadius.circular(28)),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(painter: QrCornerMarks(color: kQrInk, arm: widget.size * .09, stroke: 3.5, inset: 6)),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
                child: ProfileQrView(data: widget.data, size: widget.size - 2 * pad, semanticLabel: widget.semanticLabel),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
