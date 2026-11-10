import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../platform/qr_scan_page.dart' show ScanThrottle;
import 'profile_qr_logic.dart';
import 'user_profile_page.dart';

/// Kamera önizlemesi yerine konan test parçası: okunan metni [onValue] ile iletir.
typedef ProfileQrScannerBuilder = Widget Function(BuildContext context, void Function(String value) onValue);

/// Profil QR taraması: BÜ Kampüs profil kodu okunursa o profil açılır (kendi kodunda kendi profil). Başka değer,
/// yabancı alan adı ya da bozuk metin "Bu bir BÜ Kampüs profil kodu değil" der; okunan metin ASLA açılmaz/çalıştırılmaz.
/// Kamera izni yoksa açıklayıcı durum + ayarlara git; el feneri ve (destekleniyorsa) galeriden okuma vardır.
class ProfileQrScanPage extends StatefulWidget {
  const ProfileQrScanPage({super.key, required this.session, this.permissionService, this.scannerBuilder, this.openProfile});

  final Session session;

  @visibleForTesting
  final PermissionService? permissionService;

  @visibleForTesting
  final ProfileQrScannerBuilder? scannerBuilder;

  /// Testlerde profil açma yerine konur; varsayılan: bu sayfanın yerine [UserProfilePage].
  @visibleForTesting
  final void Function(BuildContext context, int userId)? openProfile;

  @override
  State<ProfileQrScanPage> createState() => _ProfileQrScanPageState();
}

class _ProfileQrScanPageState extends State<ProfileQrScanPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _throttle = ScanThrottle();
  bool? _cam; // null = denetleniyor
  bool _done = false;
  bool _torch = false;
  String? _message;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCamera());
  }

  @override
  void dispose() {
    _clear?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCamera() async {
    if (!mounted) return;
    final ok = await ensurePermission(
      context,
      AppPermission.camera,
      rationale: context.l10n.qrCameraRationale,
      service: widget.permissionService,
    );
    if (mounted) setState(() => _cam = ok);
  }

  /// Okunan değeri çözer: geçerliyse profili açar, değilse anlaşılır hata gösterir.
  void _onValue(String raw) {
    if (_done) return;
    final now = DateTime.now();
    final v = raw.trim();
    if (!_throttle.accept(v, now)) return;
    final r = resolveProfileQr(v, selfId: widget.session.userId);
    if (!r.valid) {
      _throttle.rejected(v, now);
      _flash(context.l10n.profileQrInvalid);
      return;
    }
    _done = true;
    buHaptic(BuHaptic.light);
    Analytics.instance.action('profile_qr', target: r.kind == ProfileQrKind.own ? 'scan_own' : 'scan_profile');
    if (r.kind == ProfileQrKind.own) {
      BuToast.show(context, context.l10n.profileQrMyProfile, kind: BuToastKind.info);
    }
    final open = widget.openProfile;
    if (open != null) {
      open(context, r.userId!);
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'user_profile'),
      builder: (_) => UserProfilePage(session: widget.session, userId: r.userId!),
    ));
  }

  void _flash(String text) {
    _clear?.cancel();
    setState(() => _message = text);
    _clear = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      // El feneri yoksa/açılamazsa sessiz: tarama etkilenmez.
    }
  }

  Future<void> _gallery() async {
    final l = context.l10n;
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null || !mounted) return;
      final cap = await _controller.analyzeImage(f.path, formats: const [BarcodeFormat.qrCode]);
      if (!mounted) return;
      String? value;
      for (final b in cap?.barcodes ?? const <Barcode>[]) {
        final raw = b.rawValue;
        if (raw != null && raw.isNotEmpty) {
          value = raw;
          break;
        }
      }
      if (value == null) {
        _flash(l.profileQrGalleryNone);
        return;
      }
      _onValue(value);
    } catch (_) {
      if (mounted) _flash(l.profileQrGalleryNone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: _cam == false ? t.bg : t.scrim,
      body: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l.profileQrScanTitle,
        child: _cam == false ? _denied(context) : _scanner(context),
      ),
    );
  }

  Widget _scanner(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final ready = _cam == true;
    return Stack(fit: StackFit.expand, children: [
      if (ready)
        widget.scannerBuilder?.call(context, _onValue) ??
            MobileScanner(
              controller: _controller,
              onDetect: (cap) {
                for (final b in cap.barcodes) {
                  final v = b.rawValue;
                  if (v != null && v.isNotEmpty) {
                    _onValue(v);
                    return;
                  }
                }
              },
              errorBuilder: (ctx, e) => ColoredBox(
                color: t.scrim,
                child: _note(ctx, e.errorCode == MobileScannerErrorCode.permissionDenied ? l.qrDeniedSettings : l.qrCameraFailed),
              ),
            ),
      if (ready)
        Center(
          child: ExcludeSemantics(
            child: SizedBox(
              width: 250,
              height: 250,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.onMedia, width: 3),
                ),
              ),
            ),
          ),
        ),
      // Üst çubuk: geri, el feneri.
      PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _GlassButton(
                key: const ValueKey('pqr-back'),
                icon: buDirIcon(context, BuIcons.arrowLeft),
                label: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (ready)
                _GlassButton(
                  key: const ValueKey('pqr-torch'),
                  icon: _torch ? BuIcons.flashlightOff : BuIcons.flashlight,
                  label: l.qrTorch,
                  onTap: _toggleTorch,
                ),
            ]),
          ),
        ),
      ),
      // Alt: ipucu / hata + galeri.
      PositionedDirectional(
        start: 20,
        end: 20,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('pqr-hint'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: t.scrim.withValues(alpha: .7), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_message != null) ...[
                      ExcludeSemantics(child: Icon(BuIcons.circleAlert, size: 18, color: t.onMedia)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(_message ?? l.profileQrScanHint,
                          textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.onMedia, height: 1.35)),
                    ),
                  ]),
                ),
              ),
              if (ready) ...[
                const SizedBox(height: 12),
                BuButton(
                  key: const ValueKey('pqr-gallery'),
                  label: l.profileQrGallery,
                  icon: BuIcons.image,
                  kind: BuButtonKind.soft,
                  compact: true,
                  onPressed: _gallery,
                ),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _note(BuildContext context, String text) {
    final t = context.bu;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(BuIcons.cameraOff, size: 30, color: t.onMedia.withValues(alpha: .7))),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.onMedia, height: 1.4)),
        ]),
      ),
    );
  }

  /// Kamera izni yok: ne olduğunu anlat, izin ver / ayarlara git.
  Widget _denied(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final svc = widget.permissionService ?? PermissionService.instance;
    return SafeArea(
      child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            key: const ValueKey('pqr-back'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(buDirIcon(context, BuIcons.arrowLeft), color: t.ink),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(child: Icon(BuIcons.cameraOff, size: 44, color: t.mut)),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(l.profileQrScanTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
                ),
                const SizedBox(height: 8),
                Text(l.qrDeniedSettings, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
                const SizedBox(height: 20),
                BuButton(
                  key: const ValueKey('pqr-open-settings'),
                  label: l.profileQrOpenSettings,
                  icon: BuIcons.settings,
                  onPressed: () => svc.openSettings(),
                ),
                const SizedBox(height: 10),
                BuButton(
                  key: const ValueKey('pqr-retry'),
                  label: l.qrGrantCamera,
                  kind: BuButtonKind.soft,
                  onPressed: _ensureCamera,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
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
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.scrim.withValues(alpha: .45)),
                child: Icon(icon, size: 20, color: t.onMedia),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
