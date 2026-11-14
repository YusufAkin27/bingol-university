import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/analytics.dart';
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../share/share_models.dart';
import '../platform/qr_scan_page.dart' show ScanThrottle;
import '../profile/profile_qr_style.dart' show QrCornerMarks;
import '../profile/user_profile_page.dart';
import '../share/share_open.dart';
import 'scan_resolver.dart';

/// Kamera önizlemesi yerine konan test parçası: okunan metni [onValue] ile iletir.
typedef ScanScannerBuilder = Widget Function(BuildContext context, void Function(String value) onValue);

/// Profil QR taraması: BÜ Kampüs profil kodu okunursa o profil açılır (kendi kodunda kendi profil). Başka değer,
/// yabancı alan adı ya da bozuk metin "Bu bir BÜ Kampüs profil kodu değil" der; okunan metin ASLA açılmaz/çalıştırılmaz.
/// Kamera izni yoksa açıklayıcı durum + ayarlara git; el feneri ve (destekleniyorsa) galeriden okuma vardır.
class QrScanHubPage extends StatefulWidget {
  const QrScanHubPage({super.key, required this.session, this.permissionService, this.scannerBuilder, this.openProfile});

  final Session session;

  @visibleForTesting
  final PermissionService? permissionService;

  @visibleForTesting
  final ScanScannerBuilder? scannerBuilder;

  /// Testlerde profil açma yerine konur; varsayılan: bu sayfanın yerine [UserProfilePage].
  @visibleForTesting
  final void Function(BuildContext context, int userId)? openProfile;

  @override
  State<QrScanHubPage> createState() => _QrScanHubPageState();
}

class _QrScanHubPageState extends State<QrScanHubPage> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _throttle = ScanThrottle();
  bool? _cam; // null = denetleniyor
  bool _done = false;
  bool _busy = false;
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
    _sweep.dispose();
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
    if (!mounted) return;
    setState(() => _cam = ok);
    // Tarama çizgisi sade ve sınırlı (6 gidiş-dönüş); "animasyonları azalt" açıkken durağan orta çizgi.
    if (ok && !MediaQuery.disableAnimationsOf(context)) {
      _sweep.repeat(reverse: true, count: 6);
    } else {
      _sweep.value = .5;
    }
  }

  /// Okunan değeri çözer ([resolveScan]): tanınırsa ilgili ekranı açar, değilse anlaşılır hata gösterir.
  /// Yoklama yükünde sunucu yetkiyi/hız sınırını denetler; sayfa açık kalır (görevli art arda okutabilir).
  Future<void> _onValue(String raw) async {
    if (_done || _busy) return;
    final now = DateTime.now();
    final v = raw.trim();
    if (!_throttle.accept(v, now)) return;
    final r = resolveScan(v, selfId: widget.session.userId);
    if (!r.valid) {
      _throttle.rejected(v, now);
      _flash(context.l10n.scanNotBu);
      return;
    }
    if (r.kind == ScanKind.checkin) {
      await _checkin(r, v);
      return;
    }
    if (r.kind == ScanKind.clubJoin) {
      await _joinClub(r, v);
      return;
    }
    if (r.kind == ScanKind.lesson) {
      await _lesson(v);
      return;
    }
    _done = true;
    buHaptic(BuHaptic.light);
    Analytics.instance.action('qr_scan', target: r.kind.name);
    if (r.kind == ScanKind.ownProfile) {
      BuToast.show(context, context.l10n.profileQrMyProfile, kind: BuToastKind.info);
    }
    final target = r.target!;
    final open = widget.openProfile;
    if (open != null && target.type == ShareType.user) {
      open(context, target.id);
      return;
    }
    final nav = Navigator.of(context);
    final ctx = context;
    if (target.type == ShareType.user) {
      nav.pushReplacement(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'user_profile'),
        builder: (_) => UserProfilePage(session: widget.session, userId: target.id),
      ));
      return;
    }
    // Kulüp/anket/etkinlik...: önce tarayıcı kapanır, sonra hedef ortak yoldan açılır (gizlilik hedef ekranda).
    final root = nav.context;
    nav.pop();
    await openShared(root.mounted ? root : ctx, widget.session, target);
  }

  Future<void> _checkin(ScanResult r, String v) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final res = await widget.session.api.post('/events/${r.eventId}/scan', {'code': r.code});
      if (!mounted) return;
      final name = res is Map ? '${res['displayName'] ?? ''}' : '';
      _throttle.succeeded(v, DateTime.now());
      buHaptic(BuHaptic.medium);
      _flash(res is Map && res['status'] == 'ALREADY' ? l.evtQrScanAlready(name) : l.scanCheckinDone(name));
    } catch (e) {
      _throttle.rejected(v, DateTime.now());
      if (!mounted) return;
      _flash(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kulüp katılım QR'ı: sunucu kodu doğrular ve kullanıcıyı doğrudan üye yapar (idempotent: zaten üyeyse ALREADY).
  /// Meşgul bayrağı + [ScanThrottle] çift okuma/çift istek olmasını önler; başarıda tarayıcı kapanır, kulüp sayfası açılır.
  Future<void> _joinClub(ScanResult r, String v) async {
    final l = context.l10n;
    final id = r.clubId!;
    setState(() => _busy = true);
    try {
      final res = await widget.session.api.post('/communities/$id/join-by-code', {'code': r.code});
      if (!mounted) return;
      final already = res is Map && res['status'] == 'ALREADY';
      _done = true;
      _throttle.succeeded(v, DateTime.now());
      buHaptic(BuHaptic.medium);
      Analytics.instance.action('qr_scan', target: 'club_join');
      var name = '';
      if (!already) {
        try {
          final c = await widget.session.api.get('/communities/$id');
          if (c is Map) name = '${c['name'] ?? ''}'.trim();
        } catch (_) {
          // Ad alınamazsa genel mesaj gösterilir; katılım zaten tamamdır.
        }
        if (!mounted) return;
      }
      final nav = Navigator.of(context);
      final root = nav.context;
      BuToast.show(
        context,
        already ? l.scanClubAlready : (name.isEmpty ? l.scanClubJoinedNoName : l.scanClubJoined(name)),
        kind: already ? BuToastKind.info : BuToastKind.success,
      );
      nav.pop();
      if (!root.mounted) return;
      await openShared(root, widget.session, ShareTarget(ShareType.club, id));
    } catch (e) {
      _throttle.rejected(v, DateTime.now());
      if (!mounted) return;
      _flash(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ders yoklama QR'ı: kod 5 sn'de bir değişir; ham metin sunucuya gider, içi uygulamada ayrıştırılmaz.
  /// Süresi dolmuş kod (422) aranan bir hata değildir: tarayıcı açık kalır, [ScanThrottle] işaretlenmez, öğrenci hemen yeniden okutur.
  Future<void> _lesson(String v) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final res = await widget.session.api.post('/attendance/scan', {'code': v});
      if (!mounted) return;
      final already = res is Map && res['status'] == 'ALREADY';
      final course = res is Map ? '${res['courseName'] ?? ''}'.trim() : '';
      _done = true;
      _throttle.succeeded(v, DateTime.now());
      buHaptic(BuHaptic.medium);
      Analytics.instance.action('qr_scan', target: 'lesson');
      BuToast.show(
        context,
        already ? l.scanLessonAlready(course) : l.scanLessonMarked(course),
        kind: already ? BuToastKind.info : BuToastKind.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.status == 422 && e.code == 'ATTENDANCE_CODE_INVALID') {
        _flash(l.scanLessonExpired);
      } else if (e is ApiError && e.status == 403 && e.code == 'ATTENDANCE_NOT_ENROLLED') {
        _throttle.rejected(v, DateTime.now());
        _flash(l.scanLessonNotEnrolled);
      } else {
        _throttle.rejected(v, DateTime.now());
        _flash(errorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        label: l.scanTitle,
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
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
            child: LayoutBuilder(builder: (ctx, c) {
              final side = math.min(264.0, math.min(c.maxWidth, c.maxHeight) - 96);
              final hole = Rect.fromCenter(center: Offset(c.maxWidth / 2, c.maxHeight * .42), width: side, height: side);
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _ScrimPainter(hole, t.scrim.withValues(alpha: .62)))),
                Positioned.fromRect(
                  rect: hole,
                  child: CustomPaint(painter: QrCornerMarks(color: t.onMedia, arm: 34, stroke: 4)),
                ),
                Positioned.fromRect(
                  rect: hole,
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (_, __) => Align(
                      alignment: Alignment(0, -.86 + 1.72 * _sweep.value),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 22),
                        height: 2,
                        decoration: BoxDecoration(color: t.onMedia.withValues(alpha: .85), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ]);
            }),
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
                      child: Text(_message ?? l.scanHint,
                          textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.onMedia, height: 1.35)),
                    ),
                  ]),
                ),
              ),
              if (ready) ...[
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  BuIconButton(
                    key: const ValueKey('pqr-torch'),
                    icon: _torch ? BuIcons.flashlightOff : BuIcons.flashlight,
                    tooltip: l.qrTorch,
                    filled: _torch,
                    size: 52,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: 20),
                  BuIconButton(
                    key: const ValueKey('pqr-gallery'),
                    icon: BuIcons.image,
                    tooltip: l.profileQrGallery,
                    size: 52,
                    onTap: _gallery,
                  ),
                ]),
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
                  child: Text(l.scanTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
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

/// Karartma: tüm ekran yarı saydam, tarama penceresi (yuvarlak köşeli) açık.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole, this.color);

  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(28)));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole || old.color != color;
}
