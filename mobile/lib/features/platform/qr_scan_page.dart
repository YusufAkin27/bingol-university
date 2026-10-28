import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/sistem_widgets.dart';
import '../../core/typography.dart';

// Tasarımdaki sabit kamera çerçevesi tonları (Et3b): kamera alanı her iki temada koyudur.
const _camDark = Color(0xFF171E33);
const _camGlow = Color(0xFF2B3556);
const _scanLine = Color(0xFFE4725F);

/// QR tarar; ilk okunan değeri `Navigator.pop(context, code)` ile döndürür.
/// Kamera izni reddedilir/yoksa elle kod girişi sunulur (giriş alanı her zaman ekrandadır).
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, this.title});

  /// Verilmezse dile göre varsayılan başlık (QR kodu tara) kullanılır.
  final String? title;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _manual = TextEditingController();
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _done = false;
  bool _torch = false;

  /// Kamera izni: null = denetleniyor, true = tarayıcı açılır, false = elle girişe düşülür.
  bool? _cam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCamera());
  }

  /// Gerekçe + sistem istemi `ensurePermission` ile; tarayıcının kendi istemi çift çıkmaz (izin önceden alınır).
  Future<void> _ensureCamera() async {
    if (!mounted) return;
    final ok = await ensurePermission(
      context,
      AppPermission.camera,
      rationale: context.l10n.qrCameraRationale,
    );
    if (!mounted) return;
    setState(() => _cam = ok);
    if (ok && !MediaQuery.disableAnimationsOf(context)) {
      _sweep.repeat(reverse: true);
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _finish(String code) {
    final c = code.trim();
    if (_done || c.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(c);
  }

  void _onDetect(BarcodeCapture cap) {
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _finish(v);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {}
  }

  /// Kamera kullanılamazken çerçevede gösterilen açıklama (+ isteğe bağlı izin düğmesi).
  Widget _frameNote(BuildContext context, String note, {bool grant = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: Icon(LucideIcons.cameraOff, size: 30, color: Colors.white70)),
            const SizedBox(height: 10),
            Text(note, textAlign: TextAlign.center, style: BuType.body.copyWith(color: Colors.white, height: 1.4)),
            if (grant) ...[
              const SizedBox(height: 14),
              SistemButton(
                label: context.l10n.qrGrantCamera,
                kind: SistemButtonKind.outline,
                height: 44,
                radius: 14,
                onPressed: _ensureCamera,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _frame(BuildContext context, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _camDark.withValues(alpha: .5), blurRadius: 28, offset: const Offset(0, 14), spreadRadius: -16)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: _camDark,
                gradient: RadialGradient(center: Alignment(0, -.1), radius: .9, colors: [_camGlow, _camDark], stops: [0, .7]),
              ),
            ),
            if (_cam == null)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else if (_cam == false)
              _frameNote(context, context.l10n.qrCameraDenied, grant: true)
            else ...[
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (ctx, e) {
                  final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
                  return Container(
                    color: _camDark,
                    child: _frameNote(ctx, denied ? ctx.l10n.qrDeniedSettings : ctx.l10n.qrCameraFailed),
                  );
                },
              ),
              Center(
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: _CornerPainter())),
                        AnimatedBuilder(
                          animation: _sweep,
                          builder: (_, __) => Align(
                            alignment: Alignment(0, -.9 + 1.8 * _sweep.value),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              height: 3,
                              decoration: BoxDecoration(
                                color: _scanLine,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [BoxShadow(color: _scanLine.withValues(alpha: .9), blurRadius: 14)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 14,
                child: Text(context.l10n.sistemuiQrHint,
                    textAlign: TextAlign.center,
                    style: BuType.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              PositionedDirectional(
                top: 14,
                end: 14,
                child: Semantics(
                  button: true,
                  label: context.l10n.qrTorch,
                  excludeSemantics: true,
                  onTap: _toggleTorch,
                  child: InkResponse(
                    onTap: _toggleTorch,
                    radius: 26,
                    child: Tooltip(
                      message: context.l10n.qrTorch,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: _torch ? .32 : .16),
                          border: Border.all(color: Colors.white.withValues(alpha: .4)),
                        ),
                        child: Icon(_torch ? LucideIcons.zapOff : LucideIcons.zap, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final frameH = (MediaQuery.sizeOf(context).height * .42).clamp(230.0, 340.0);
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: widget.title ?? context.l10n.qrScanTitle, onBack: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _frame(context, frameH),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        ExcludeSemantics(child: Icon(LucideIcons.info, size: 17, color: t.onSoft)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(context.l10n.sistemuiQrNotice,
                              style: BuType.label.copyWith(color: t.onSoft, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 1, color: t.bd)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(context.l10n.sistemuiQrOr,
                              style: BuType.caption.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(child: Container(height: 1, color: t.bd)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
                    child: Text(context.l10n.qrManualLabel,
                        style: BuType.label.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                  ),
                  TextField(
                    controller: _manual,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: _finish,
                    style: BuType.title.copyWith(color: t.ink, fontWeight: FontWeight.w700, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: context.l10n.sistemuiQrManualHint,
                      hintStyle: BuType.title.copyWith(color: t.mut.withValues(alpha: .6), fontWeight: FontWeight.w500, letterSpacing: 2),
                      filled: true,
                      fillColor: t.sf,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.bd, width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.bd, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.pr, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.bg.withValues(alpha: 0), t.bg],
                stops: const [0, .28],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 20),
              child: SistemButton(label: context.l10n.sistemuiQrSubmit, onPressed: () => _finish(_manual.text)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dört köşe işareti (44 px kollar, 4 px beyaz çizgi, 18 px yuvarlak köşe).
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    const a = 44.0, r = 18.0, w = 2.0; // w: çizgi yarısı (kutu içinde kalsın)
    final x1 = s.width - w, y1 = s.height - w;
    Path corner(double cx, double cy, double dx, double dy) => Path()
      ..moveTo(cx, cy + dy * a)
      ..lineTo(cx, cy + dy * r)
      ..quadraticBezierTo(cx, cy, cx + dx * r, cy)
      ..lineTo(cx + dx * a, cy);
    canvas.drawPath(corner(w, w, 1, 1), p);
    canvas.drawPath(corner(x1, w, -1, 1), p);
    canvas.drawPath(corner(w, y1, 1, -1), p);
    canvas.drawPath(corner(x1, y1, -1, -1), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
