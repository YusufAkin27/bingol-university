import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubOutlineButton, ClubPageHeader;
import '../platform/qr_scan_page.dart' show ScanThrottle;
import '../../core/realtime/chat_realtime.dart' show AttendanceLiveEvent;
import 'attendance_live.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_widgets.dart';

/// Etkinlik düzenleyeni: katılımcıların kişisel QR'larını art arda okutur (sayfa kapanmaz).
/// Her okuma `POST /events/{id}/scan` ile doğrulanır; sonuç "X katıldı" / "X zaten katıldı" / hata olarak gösterilir.
class Etkinlik3ScanPage extends StatefulWidget {
  const Etkinlik3ScanPage({super.key, required this.session, required this.event, this.fromList = false, this.scannerBuilder, this.permissionService});

  final Session session;
  final Map<String, dynamic> event;

  /// Yoklama aracından açıldıysa "Listeyi aç" düğmesi geri döner (aynı listeye ikinci sayfa yığılmaz).
  final bool fromList;

  /// Yalnız test: kamera yerine konacak parça; verilen `onCode` okunan değeri iletir.
  @visibleForTesting
  final Widget Function(BuildContext context, void Function(String code) onCode)? scannerBuilder;

  @visibleForTesting
  final PermissionService? permissionService;

  @override
  State<Etkinlik3ScanPage> createState() => _Etkinlik3ScanPageState();
}

class _Etkinlik3ScanPageState extends State<Etkinlik3ScanPage> {
  final _throttle = ScanThrottle(anyCooldown: const Duration(milliseconds: 900), sameCooldown: const Duration(seconds: 3));
  MobileScannerController? _controller;
  bool? _cam;
  bool _busy = false;
  String? _message;
  bool _isError = false;
  int _present = 0;
  int _total = 0;
  String? _lastName; // son okutan katılımcı (bu cihaz ya da başka görevli)
  AttendanceLiveBinding? _live;

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    if (widget.scannerBuilder == null) _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    _loadCounts();
    _live = AttendanceLiveBinding(session: widget.session, eventId: _id, onEvent: _onLive, onPoll: _pollSummary)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCamera());
  }

  @override
  void dispose() {
    _live?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureCamera() async {
    if (!mounted) return;
    if (widget.scannerBuilder != null) {
      setState(() => _cam = true);
      return;
    }
    final ok = await ensurePermission(context, AppPermission.camera, rationale: context.l10n.qrCameraRationale, service: widget.permissionService);
    if (mounted) setState(() => _cam = ok);
  }

  Future<void> _loadCounts() async {
    try {
      final r = await widget.session.api.get('/events/$_id/attendance/roster');
      if (!mounted || r is! Map) return;
      final p = (r['present'] as num?)?.toInt() ?? 0;
      final a = (r['absent'] as num?)?.toInt() ?? 0;
      final n = (r['pending'] as num?)?.toInt() ?? 0;
      setState(() {
        _total = p + a + n;
        _present = p;
      });
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Gerçek zamanlı: başka görevlinin (ya da bu cihazın) okutması; sunucu sayacı esastır (idempotent).
  void _onLive(AttendanceLiveEvent e) {
    if (!mounted || !e.isScan) return;
    setState(() {
      _present = e.present;
      if (e.total > 0) _total = e.total;
      if (e.displayName != null) _lastName = e.displayName;
    });
  }

  /// Yedek yoklama (olay kaçarsa): hafif özet ucu.
  Future<void> _pollSummary() async {
    final r = await widget.session.api.get('/events/$_id/attendance/summary', force: true);
    if (!mounted || r is! Map || r['present'] == null) return;
    setState(() {
      _present = (r['present'] as num).toInt();
      final t = (r['total'] as num?)?.toInt() ?? 0;
      if (t > 0) _total = t;
      final n = r['lastName'];
      if (n is String && n.isNotEmpty) _lastName = n;
    });
  }

  Future<void> _onCode(String code) async {
    final c = code.trim();
    if (c.isEmpty || _busy) return;
    final now = DateTime.now();
    if (!_throttle.accept(c, now)) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final r = await widget.session.api.post('/events/$_id/scan', {'code': c});
      if (!mounted) return;
      final m = r is Map ? r : const {};
      final name = '${m['displayName'] ?? ''}';
      final already = m['status'] == 'ALREADY';
      _throttle.succeeded(c, DateTime.now());
      buHaptic(already ? BuHaptic.light : BuHaptic.medium);
      setState(() {
        _isError = false;
        _message = already ? l.evtQrScanAlready(name) : l.evtQrScanMarked(name);
        if (!already) _present = _total == 0 ? _present + 1 : (_present + 1).clamp(0, _total);
        if (name.isNotEmpty) _lastName = name;
      });
      // Kaydı geçici sayacı sunucuyla eşitle (yürüyen girişler de sayılsın).
      _loadCounts();
    } catch (e) {
      _throttle.rejected(c, DateTime.now());
      if (!mounted) return;
      buHaptic(BuHaptic.light);
      setState(() {
        _isError = true;
        _message = errorText(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openList() async {
    if (widget.fromList) {
      Navigator.pop(context);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_attendance'), builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: widget.event)),
    );
    if (mounted) _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final pct = _total == 0 ? 0.0 : (_present / _total).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.evtQrScanTitle),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Text('${widget.event['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(color: t.scrim, child: _camera(context)),
              ),
            ),
            const SizedBox(height: 8),
            Text(l.evtQrScanHint, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _message == null
                  ? const SizedBox(key: ValueKey('et3-none'), height: 0)
                  : Container(
                      key: ValueKey('et3-msg-$_message'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isError ? t.danger.withValues(alpha: .1) : t.sf2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Icon(_isError ? BuIcons.circleAlert : BuIcons.check, size: 20, color: _isError ? t.danger : t.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_message!, style: tx.bodyLarge!.copyWith(color: _isError ? t.danger : t.ink)),
                          ),
                        ),
                      ]),
                    ),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(l.etkinlik2PresentOf('$_present', '$_total'), key: const ValueKey('et3-present-count'), style: tx.bodyMedium!.copyWith(color: t.ink)),
            ),
            if (_lastName != null) ...[
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(l.evtLiveLastScanned(_lastName!), key: const ValueKey('et3-live-last'), style: tx.bodyMedium!.copyWith(color: t.mut)),
              ),
            ],
            const SizedBox(height: 8),
            Et2Progress(fraction: pct, height: 4),
            const SizedBox(height: 20),
            ClubOutlineButton(label: l.p51EvAttList, onPressed: _openList),
          ]),
        ),
      ]),
    );
  }

  Widget _camera(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    if (_cam == null) return const Center(child: CircularProgressIndicator());
    if (_cam == false) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(l.qrDeniedSettings, textAlign: TextAlign.center, style: TextStyle(color: t.onMedia))));
    }
    final custom = widget.scannerBuilder;
    if (custom != null) return custom(context, _onCode);
    return MobileScanner(
      controller: _controller,
      onDetect: (cap) {
        for (final b in cap.barcodes) {
          final v = b.rawValue;
          if (v != null && v.isNotEmpty) {
            _onCode(v);
            break;
          }
        }
      },
      errorBuilder: (ctx, e) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(ctx.l10n.qrCameraFailed, textAlign: TextAlign.center, style: TextStyle(color: t.onMedia)))),
    );
  }
}
