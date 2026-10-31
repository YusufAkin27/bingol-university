import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../widgets/bu.dart';
import '../system/gate_views.dart' show GateArrowButton;

/// Okunan/girilen kodu doğrulayan isteğe bağlı kanca: hata metni dönerse sayfada gösterilir ve sayfa açık kalır;
/// null dönerse "Yoklaman alındı" kısa gösterilip sayfa kodla kapanır.
typedef QrCodeValidator = Future<String?> Function(String code);

/// QR tarar; ilk okunan değeri `Navigator.pop(context, code)` ile döndürür.
/// Kamera izni reddedilir/yoksa elle kod girişi sunulur (giriş alanı her zaman ekrandadır).
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, this.title, this.onSubmit, this.permissionService, this.scannerBuilder});

  /// Verilmezse dile göre varsayılan başlık (QR kodu tara) kullanılır.
  final String? title;

  /// Verilirse kod sayfa kapanmadan önce doğrulanır (06/6): hata sayfada kalır, başarı kısa gösterilir.
  final QrCodeValidator? onSubmit;

  /// Testlerde izin servisi (yoksa [PermissionService.instance]).
  @visibleForTesting
  final PermissionService? permissionService;

  /// Testlerde kamera önizlemesi yerine konacak parça (platform kanalı gerekmez).
  @visibleForTesting
  final WidgetBuilder? scannerBuilder;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _manual = TextEditingController();
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _done = false;
  bool _busy = false;
  bool _torch = false;
  bool _success = false;
  String? _error;

  /// Kamera izni: null = denetleniyor, true = tarayıcı açılır, false = elle girişe düşülür.
  bool? _cam;

  @override
  void initState() {
    super.initState();
    _manual.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCamera());
  }

  /// Gerekçe + sistem istemi `ensurePermission` ile; tarayıcının kendi istemi çift çıkmaz (izin önceden alınır).
  Future<void> _ensureCamera() async {
    if (!mounted) return;
    final ok = await ensurePermission(
      context,
      AppPermission.camera,
      rationale: context.l10n.qrCameraRationale,
      service: widget.permissionService,
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

  Future<void> _finish(String code) async {
    final c = code.trim();
    if (_done || _busy || c.isEmpty) return;
    final check = widget.onSubmit;
    if (check == null) {
      _done = true;
      Navigator.of(context).pop(c);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final generic = context.l10n.coreErrGeneric;
    String? err;
    try {
      err = await check(c);
    } catch (_) {
      err = generic;
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    setState(() {
      _busy = false;
      _success = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || _done) return;
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final title = widget.title ?? context.l10n.qrScanTitle;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: _cam == false ? _deniedLayout(context) : _scanLayout(context, title),
      ),
    );
  }

  // ---- Kamera açık (06/4) -------------------------------------------------------------------------------------

  Widget _scanLayout(BuildContext context, String title) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final camH = (c.maxHeight * .52).clamp(240.0, 460.0);
        return Stack(
          children: [
            PositionedDirectional(top: 0, start: 0, end: 0, height: camH, child: _camera(context)),
            // Üst çubuk: geri, başlık, el feneri.
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _RoundGlassButton(
                        icon: buDirIcon(context, LucideIcons.arrowLeft),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tx.titleMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                      ),
                      if (_cam == true)
                        _TorchPill(label: l.qrTorch, on: _torch, onTap: _toggleTorch)
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            // Alt panel: kamera alanının 24 dp üstüne biner.
            Positioned.fill(
              top: camH - 24,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                // Panel kalan yüksekliği doldurur: uzun ekranlarda altta zemin renginde boşluk kalmaz.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (c.maxHeight - (camH - 24)).clamp(0.0, double.infinity)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(color: t.sf, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                    child: SafeArea(top: false, child: _panelBody(context, camera: true)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _camera(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return ColoredBox(
      color: t.scrim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_cam == true) ...[
            widget.scannerBuilder?.call(context) ??
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (ctx, e) {
                    final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
                    return ColoredBox(
                      color: t.scrim,
                      child: _frameNote(ctx, denied ? ctx.l10n.qrDeniedSettings : ctx.l10n.qrCameraFailed),
                    );
                  },
                ),
            // Üst çubuğun her görüntüde okunması için hafif karartma.
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.scrim.withValues(alpha: .5), t.scrim.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 254,
                  height: 254,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _CornerPainter(t.onMedia))),
                      AnimatedBuilder(
                        animation: _sweep,
                        builder: (_, __) => Align(
                          alignment: Alignment(0, -.88 + 1.76 * _sweep.value),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            height: 2,
                            decoration: BoxDecoration(
                              color: t.h1,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [BoxShadow(color: t.h1.withValues(alpha: .9), blurRadius: 12)],
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
              bottom: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), borderRadius: BuRadius.bPill),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.h1, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(l.sistemuiQrHint,
                            textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tarayıcı kendi hatasını (izin/kamera açılamadı) çerçevede açıklar.
  Widget _frameNote(BuildContext context, String note) {
    final t = context.bu;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(LucideIcons.cameraOff, size: 30, color: t.onMedia.withValues(alpha: .7))),
            const SizedBox(height: 10),
            Text(note, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.onMedia, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // ---- Kamera izni yok (06/5) ---------------------------------------------------------------------------------

  Widget _deniedLayout(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final cameraTitle = permissionInfo(AppPermission.camera, context).title;
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                icon: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: t.ink),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Center(
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bXl),
                        child: Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
                          child: Icon(LucideIcons.cameraOff, size: 34, color: t.pr),
                        ),
                      ),
                      PositionedDirectional(
                        top: -2,
                        end: -4,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(l.p01PermDeniedTitle(cameraTitle),
                  textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(l.qrCameraDenied, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
            ),
            const SizedBox(height: 16),
            BuButton(label: l.qrGrantCamera, icon: LucideIcons.video, onPressed: _ensureCamera),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bPill))),
            ),
            const SizedBox(height: 16),
            ..._feedback(context),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
              child: _panelBody(context, camera: false),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ortak: elle giriş paneli -------------------------------------------------------------------------------

  /// Hata/başarı geri bildirimi (06/6): kırmızı bant ve "Yoklaman alındı" kartı.
  List<Widget> _feedback(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return [
      if (_error != null) ...[
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16), boxShadow: BuElevation.of(context, 1)),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.error, size: 22, color: t.onSoft)),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: tx.bodyMedium!.copyWith(color: t.onSoft, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_success) ...[
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf3, borderRadius: BorderRadius.circular(16), boxShadow: BuElevation.of(context, 2)),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.check_circle, size: 24, color: t.ok)),
                const SizedBox(width: 10),
                Expanded(child: Text(context.l10n.p01QrAttended, style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _panelBody(BuildContext context, {required bool camera}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final tint = t.tint(1);
    final err = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (camera) ...[
          ..._feedback(context),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(LucideIcons.calendarClock, size: 18, color: tint.fg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l.sistemuiQrNotice, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: t.bd)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l.sistemuiQrOr, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Container(height: 1, color: t.bd)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
          child: Text(l.qrManualLabel, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        ),
        TextField(
          controller: _manual,
          enabled: !_busy && !_success,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: _finish,
          style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: l.sistemuiQrManualHint,
            hintStyle: tx.titleMedium!.copyWith(color: t.mut.withValues(alpha: .7), fontWeight: FontWeight.w500, letterSpacing: .5),
            filled: true,
            fillColor: err != null ? t.soft : t.sf2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: camera ? null : Icon(LucideIcons.keyboard, size: 20, color: t.mut),
            border: const OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide.none),
            enabledBorder: const OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide.none),
            disabledBorder: const OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: t.pr, width: 2)),
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: 8),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(LucideIcons.circleX, size: 14, color: t.danger)),
                const SizedBox(width: 6),
                Expanded(child: Text(err, style: tx.labelMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (camera)
          GateArrowButton(label: l.sistemuiQrSubmit, busy: _busy, onPressed: _success ? null : () => _finish(_manual.text))
        else
          BuButton(label: l.qrConfirm, busy: _busy, onPressed: _success ? null : () => _finish(_manual.text)),
      ],
    );
  }
}

/// Yarı saydam yuvarlak düğme (kamera üstünde).
class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.scrim.withValues(alpha: .35)),
                child: Icon(icon, size: 20, color: t.onMedia),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El feneri hapı ("El feneri"): açıkken biraz daha dolu.
class _TorchPill extends StatelessWidget {
  const _TorchPill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: t.scrim.withValues(alpha: on ? .6 : .35), borderRadius: BuRadius.bPill),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? LucideIcons.flashlightOff : LucideIcons.flashlight, size: 16, color: t.onMedia),
                  const SizedBox(width: 6),
                  Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dört köşe işareti (32 px kollar, 4 px çizgi, 16 px yuvarlak köşe).
class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    const a = 34.0, r = 16.0, w = 2.0; // w: çizgi yarısı (kutu içinde kalsın)
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
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
