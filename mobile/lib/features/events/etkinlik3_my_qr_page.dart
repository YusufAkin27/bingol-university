import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader;
import 'etkinlik3_scan_page.dart';
import 'qr_painter.dart';

/// Katılımcının kişisel giriş QR'ı: sunucu imzalı, kısa ömürlü; süre dolmadan kendiliğinden yenilenir.
/// Organizatör/moderatör bu kodu okutarak yoklamayı alır. Yoklama açık değilse ya da katılım onaylı değilse
/// sunucunun açıklayıcı mesajı gösterilir (genel "sunucuya bağlanılamadı" değil).
class Etkinlik3MyQrPage extends StatefulWidget {
  const Etkinlik3MyQrPage({super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik3MyQrPage> createState() => _Etkinlik3MyQrPageState();
}

class _Etkinlik3MyQrPageState extends State<Etkinlik3MyQrPage> with WidgetsBindingObserver {
  String? _payload;
  String? _error;
  bool _busy = false;
  int _fails = 0;
  bool _ownerMode = false; // sahip/düzenleyen, katılımcı kaydı yok: bilet yerine yoklama araçları
  bool _joining = false;
  Timer? _refresh;

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plandan dönünce bileti hemen yenile (zamanlayıcı uykudayken bayatlamış olabilir).
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.session.api.get('/events/$_id/my-ticket');
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      setState(() {
        _payload = m['qrPayload'] as String?;
        _error = null;
      });
      // Bilet ~5 dk geçerli; 60 sn'de bir yenilenir (okutma sırasında bayat kod kalmasın).
      _fails = 0;
      _refresh?.cancel();
      _refresh = Timer(const Duration(seconds: 60), () {
        if (mounted) _load();
      });
    } catch (e) {
      if (e is ApiError && e.status == 403 && e.code == 'NOT_RSVPED' && widget.event['canManage'] == true && _payload == null) {
        if (mounted) setState(() => _ownerMode = true);
        return;
      }
      // Mevcut QR korunur (süresi dolana kadar çalışır); 4xx'te otomatik tekrar yok, ağ/5xx'te üstel geri çekilme.
      if (mounted) setState(() => _error = errorText(e));
      _refresh?.cancel();
      final retriable = e is! ApiError || e.isNetwork || e.status >= 500;
      if (retriable) {
        _fails++;
        final secs = (5 << (_fails > 4 ? 4 : _fails)).clamp(10, 60);
        _refresh = Timer(Duration(seconds: secs), () {
          if (mounted) _load();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinAsAttendee() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await widget.session.api.put('/events/$_id/rsvp', {'status': 'GOING'});
      if (!mounted) return;
      setState(() => _ownerMode = false);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget _ownerPanel(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(key: const ValueKey('et3-my-qr-owner'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.evtQrMyOwnerTitle, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
      const SizedBox(height: 6),
      Text(l.evtQrMyOwnerBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
      const SizedBox(height: 16),
      BuButton(
        label: l.evtQrMyOwnerScan,
        onPressed: () => Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik3_scan'), builder: (_) => Etkinlik3ScanPage(session: widget.session, event: widget.event))),
      ),
      const SizedBox(height: 4),
      TextButton(
        key: const ValueKey('et3-my-qr-join'),
        style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48)),
        onPressed: _joining ? null : _joinAsAttendee,
        child: Text(l.evtQrMyOwnerJoin, style: tx.bodyLarge!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.evtQrMyTitle),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 11, 20, 32), children: [
            Text('${widget.event['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.mut)),
            const SizedBox(height: 20),
            if (_ownerMode) _ownerPanel(context) else Center(
              child: Container(
                key: const ValueKey('et3-my-qr'),
                width: 240,
                height: 240,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.qrPaper, borderRadius: BorderRadius.circular(16)),
                child: _payload != null
                    ? QrView(data: _payload!, size: 216, radius: BuRadius.xs)
                    : (_busy ? const CircularProgressIndicator() : Icon(BuIcons.qrCode, size: 64, color: t.mut)),
              ),
            ),
            const SizedBox(height: 20),
            if (_ownerMode) const SizedBox.shrink() else if (_error != null) ...[
              Text(_error!, key: const ValueKey('et3-my-qr-error'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
              const SizedBox(height: 12),
              BuButton(label: l.commonRetry, busy: _busy, onPressed: _busy ? null : _load),
            ] else
              Text(l.evtQrMyHint, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}
