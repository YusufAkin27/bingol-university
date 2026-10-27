import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/permissions/ensure_permission.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../core/typography.dart';

/// QR tarar; ilk okunan değeri `Navigator.pop(context, code)` ile döndürür.
/// Kamera izni reddedilir/yoksa elle kod girişi sunulur.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, this.title = 'QR kodu tara'});

  final String title;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _manual = TextEditingController();
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
      rationale: 'QR kodu okutabilmek için kameraya erişmemiz gerekir.',
    );
    if (mounted) setState(() => _cam = ok);
  }

  @override
  void dispose() {
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

  Widget _manualEntry(BuildContext context, {String? note}) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null) ...[
            Text(note, style: BuType.body.copyWith(color: t.mut)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _manual,
            textInputAction: TextInputAction.done,
            onSubmitted: _finish,
            decoration: const InputDecoration(labelText: 'Kodu elle gir'),
          ),
          const SizedBox(height: 12),
          BuButton(label: 'Onayla', onPressed: () => _finish(_manual.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: widget.title, onBack: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cam == null)
                      Container(color: t.sf2, alignment: Alignment.center, child: const CircularProgressIndicator())
                    else if (_cam == false)
                      Container(
                        color: t.sf2,
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _manualEntry(context,
                                  note: 'Kamera izni verilmedi. Kodu elle girebilir ya da izin verip taramayı '
                                      'yeniden deneyebilirsiniz.'),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: BuButton(
                                    label: 'Kamera izni ver', kind: BuButtonKind.outline, onPressed: _ensureCamera),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (ctx, e) {
                        final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
                        return Container(
                          color: t.sf2,
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            child: _manualEntry(
                              ctx,
                              note: denied
                                  ? 'Kamera izni verilmedi. Ayarlar > BÜ Kampüs bölümünden izin verebilir '
                                      'ya da kodu elle girebilirsiniz.'
                                  : 'Kamera açılamadı. Kodu elle girebilirsiniz.',
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: BuIconButton(
                        icon: _torch ? LucideIcons.zapOff : LucideIcons.zap,
                        tooltip: 'El feneri',
                        onTap: () async {
                          try {
                            await _controller.toggleTorch();
                            if (mounted) setState(() => _torch = !_torch);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ExpansionTile(
                title: const Text('Kodu elle gir'),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [_manualEntry(context)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
