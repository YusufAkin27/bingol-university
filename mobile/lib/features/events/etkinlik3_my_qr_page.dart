import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader;
import 'qr_painter.dart';

/// Katılımcının kişisel giriş QR'ı: sunucu imzalı, kısa ömürlü; süre dolmadan kendiliğinden yenilenir.
/// Organizatör/moderatör bu kodu okutarak yoklamayı alır; katılımcı BAŞKA HİÇBİR ŞEY yapmaz (okutmaz, kod girmez).
/// Sahip/moderatörün kişisel QR'ı yoktur (sunucu 403 `TICKET_NOT_FOR_STAFF`); yoklama açık değilse ya da katılım onaylı
/// değilse sunucunun açıklayıcı mesajı gösterilir (genel "sunucuya bağlanılamadı" değil).
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
  bool _staff = false; // sahip/moderatör: kişisel QR yok
  int _fails = 0;
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
      if (e is ApiError && e.status == 403 && e.code == 'TICKET_NOT_FOR_STAFF') {
        // Görevlinin QR'ı olmaz: yeniden denemek anlamsız, sunucu mesajı gösterilir.
        if (mounted) {
          setState(() {
            _staff = true;
            _error = context.l10n.evtAtt2StaffNoQr;
          });
        }
        _refresh?.cancel();
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
            Center(
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
            if (_error != null) ...[
              Text(_error!, key: const ValueKey('et3-my-qr-error'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
              if (!_staff) ...[
                const SizedBox(height: 12),
                BuButton(label: l.commonRetry, busy: _busy, onPressed: _busy ? null : _load),
              ],
            ] else
              Text(l.evtAtt2ParticipantHint, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}
