// ESKI (kullanimdan kalkti): sahibin "yoklama kodu" ekrani. Yeni modelde katilimci yalniz QR kodunu gosterir, yoklamayi sahip/moderator Etkinlik2AttendancePage araciyla alir; bu sayfa arayuzden acilmaz.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'etkinlik2_attendance_page.dart';
import '../clubs/clubs_widgets.dart' show ClubOutlineButton, ClubPageHeader;
import 'attendance_live.dart';
import 'checkin_input.dart';
import 'etkinlik2_widgets.dart';
import 'qr_painter.dart';

/// Organizatör yoklama kodu: QR + elle kod + yenilenme sayacı + "N / M kişi geldi".
/// Kod kısa ömürlüdür; süresi dolmadan kendiliğinden yenilenir (sayfa kapanınca zamanlayıcılar iptal).
class Etkinlik2QrPage extends StatefulWidget {
  const Etkinlik2QrPage({super.key, required this.session, required this.event, this.now});

  final Session session;
  final Map<String, dynamic> event;

  /// Yalnız test: saat kaynağı (süre dolumunu sahte saatle denemek için).
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<Etkinlik2QrPage> createState() => _Etkinlik2QrPageState();
}

class _Etkinlik2QrPageState extends State<Etkinlik2QrPage> {
  Map<String, dynamic>? _code;
  bool _busy = false;
  String? _failed;
  int _present = 0;
  int _total = 0;
  Timer? _refresh;
  Timer? _tick;
  DateTime? _expires;
  bool? _attOpen; // sahip yoklamayı açtı mı (my-permissions); null = bilinmiyor
  bool _attBusy = false;
  String? _lastName; // son okutan (gerçek zamanlı)
  AttendanceLiveBinding? _live;

  /// Kalan saniye: yalnız sayaç parçaları dinler (sayfanın tamamı her saniye yeniden kurulmaz).
  final _left = ValueNotifier<int>(0);

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _loadCode();
    _loadCounts();
    _loadOpen();
    _live = AttendanceLiveBinding(
      session: widget.session,
      eventId: _id,
      onEvent: (e) {
        if (!mounted || !e.isScan) return;
        setState(() {
          _present = e.present;
          if (e.total > 0) _total = e.total;
          if (e.displayName != null) _lastName = e.displayName;
        });
      },
      onPoll: _loadCounts,
    )..start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _expires != null) _left.value = _secsLeft;
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    _live?.dispose();
    _left.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final res = await widget.session.api.get('/events/$_id/attendance/roster');
      final r = res is Map ? res['rows'] : res;
      if (!mounted || r is! List) return;
      setState(() {
        _total = r.length;
        _present = r.whereType<Map>().where((e) => e['present'] == true).length;
      });
    } catch (_) {}
  }

  Future<void> _loadOpen() async {
    try {
      final r = await widget.session.api.get('/events/$_id/my-permissions');
      if (mounted && r is Map) setState(() => _attOpen = r['attendanceOpen'] == true);
    } catch (_) {}
  }

  Future<void> _openAttendance() async {
    if (_attBusy) return;
    setState(() => _attBusy = true);
    try {
      await widget.session.api.put('/events/$_id/attendance-open', {'open': true});
      if (mounted) setState(() => _attOpen = true);
      await _loadCode();
    } catch (e) {
      if (mounted) setState(() => _failed = errorText(e));
    } finally {
      if (mounted) setState(() => _attBusy = false);
    }
  }

  bool get _outsideWindow {
    final s = DateTime.tryParse('${widget.event['startsAt']}');
    final e = DateTime.tryParse('${widget.event['endsAt']}');
    if (s == null || e == null) return false;
    final n = _now();
    return n.isBefore(s.subtract(const Duration(minutes: 30))) || n.isAfter(e.add(const Duration(minutes: 30)));
  }

  /// Yoklama kapalıyken sahibe belirgin uyarı + tek dokunuşla açma.
  Widget _closedBanner(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(key: const ValueKey('et2-att-closed'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.evtQrOwnerClosed, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        if (_outsideWindow) ...[
          const SizedBox(height: 4),
          Text(l.evtQrOwnerOutside, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        ],
        const SizedBox(height: 8),
        BuButton(label: l.evtQrOwnerOpenAction, busy: _attBusy, onPressed: _attBusy ? null : _openAttendance),
      ]),
    );
  }

  Future<void> _loadCode() async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.session.api.get('/events/$_id/checkin-code');
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      final secs = ((m['validForSeconds'] as num?)?.toInt() ?? 30).clamp(10, 120);
      setState(() {
        _code = m;
        _failed = null;
        _expires = _now().add(Duration(seconds: secs));
      });
      _left.value = secs;
      _refresh?.cancel();
      _refresh = Timer(Duration(seconds: secs > 5 ? secs - 3 : secs), () {
        if (mounted) {
          _loadCode();
          _loadCounts();
        }
      });
    } catch (e) {
      // Sunucunun gerçek nedeni gösterilir (ör. "Yoklama henüz açılmadı"); eskiden her hata "Sunucu ile bağlantı
      // kurulamadı" yazıyordu. Ağ hatası ve 5xx dışındaki (4xx) cevaplar tekrar denenmez: durum kendiliğinden değişmez.
      if (mounted) setState(() => _failed = errorText(e));
      _refresh?.cancel();
      final retriable = e is! ApiError || e.isNetwork || e.status >= 500;
      if (retriable) {
        _refresh = Timer(const Duration(seconds: 5), () {
          if (mounted) _loadCode();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_attendance'), builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: widget.event)),
    );
    if (mounted) _loadCounts();
  }

  Future<void> _copy(String code) async {
    buHaptic(BuHaptic.light);
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) BuToast.show(context, context.l10n.p16QrCopied, kind: BuToastKind.success);
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  int get _secsLeft {
    final e = _expires;
    if (e == null) return 0;
    final s = e.difference(_now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final failed = _failed != null;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.p51EvQrTitle),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 11, 20, 32),
            children: [
              _strip(context),
              const SizedBox(height: 20),
              if (_attOpen == false) _closedBanner(context),
              Center(child: _qrCard(context)),
              if (failed) ...[
                const SizedBox(height: 16),
                _errorCard(context),
              ],
              const SizedBox(height: 24),
              _statusCard(context),
            ],
          ),
        ),
      ]),
    );
  }

  /// Etkinlik adı: ortalı, muted (kulüp adı varsa üstünde marka renginde küçük satır).
  Widget _strip(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final title = Text('${widget.event['title'] ?? ''}',
        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, color: t.mut));
    // Kapasite doluluğu: yalnız sınırlı kontenjanlı etkinlikte (capacity > 0) ve katılım sayısı biliniyorsa.
    final cap = (widget.event['capacity'] as num?)?.toInt() ?? 0;
    final going = (widget.event['goingCount'] as num?)?.toInt();
    if (cap <= 0 || going == null) return title;
    final pct = ((going / cap) * 100).round().clamp(0, 100);
    return Column(children: [
      title,
      const SizedBox(height: 6),
      Text(context.l10n.notifCapacityFull('$pct'),
          key: const ValueKey('et2-capacity'), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w400, color: t.prText)),
    ]);
  }

  /// "Kod 4 sn sonra yenilenir" gibi metinde [token] (sayı) vurgulanır.
  Widget _emph(String text, String token, TextStyle base, TextStyle emph) {
    final i = token.isEmpty ? -1 : text.indexOf(token);
    if (i < 0) return Text(text, textAlign: TextAlign.center, style: base);
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(text: token, style: emph),
        TextSpan(text: text.substring(i + token.length)),
      ]),
      textAlign: TextAlign.center,
    );
  }


  Widget _qrCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final long = _code?['code'] as String?;
    final qr = _code?['qrPayload'] as String?;
    if (long == null) return _noCode(context);
    // Elle giriş için sunucunun kısa kodu (6 karakter); eski sunucuda yalnız uzun jeton gelirse o gösterilir.
    final manual = (_code?['manualCode'] as String?)?.trim();
    final code = (manual != null && manual.isNotEmpty) ? manual : long;
    return Column(children: [
      ValueListenableBuilder<int>(
        valueListenable: _left,
        builder: (context, left, _) => _QrFrame(
          expired: left == 0,
          child: Semantics(
            label: l.eventFormCheckInCode,
            child: QrView(
              data: qr ?? long,
              size: 228,
              radius: BuRadius.xs,
              fallback: SelectableText(code,textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.prText)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      // El ile giriş kodu: büyük aralıklı rakamlar; dokununca panoya kopyalanır.
      Semantics(
        button: true,
        label: '${l.p16QrCopy}: $code',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _copy(code),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(spacedManualCode(code),
                key: const ValueKey('et2-manual-code'),
                maxLines: 1,
                style: tx.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w400, letterSpacing: 6, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ),
      ),
      const SizedBox(height: 6),
      ValueListenableBuilder<int>(
        valueListenable: _left,
        builder: (context, left, _) {
          final expired = left == 0;
          final base = tx.bodyMedium!.copyWith(color: t.mut);
          return expired
              ? Text(l.etkinlik2QrExpired, style: base)
              : _emph(l.etkinlik2QrRenewsIn('$left'), '$left', base, base.copyWith(fontWeight: FontWeight.w400, color: t.ink));
        },
      ),
    ]);
  }

  /// Kod henüz yok: yükleniyorsa QR iskeleti; hatadaysa bulanık yer tutucu + "Kod kısa süre geçerlidir".
  Widget _noCode(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (_busy) {
      return Semantics(
        label: l.eventFormCodePreparing,
        liveRegion: true,
        child: const BuSkeletonScope(
          child: Column(children: [
            BuSkeleton(width: 240, height: 240, radius: 16),
            SizedBox(height: 20),
            BuSkeleton(width: 180, height: 32, radius: 8),
            SizedBox(height: 10),
            BuSkeleton.line(width: 160),
          ]),
        ),
      );
    }
    return Column(children: [
      const _QrFrame(expired: true, child: SizedBox.shrink()),
      const SizedBox(height: 14),
      Text(l.eventFormCodeShortLived, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
    ]);
  }

  /// Hata: simgesiz, muted metin + marka renkli metin düğmeleri.
  Widget _errorCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(key: const ValueKey('et2-qr-error'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.eventFormCodeFailed, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        const SizedBox(height: 4),
        Text(_failed ?? l.p16QrErrBody, key: const ValueKey('et2-qr-error-body'), textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        const SizedBox(height: 8),
        BuButton(label: l.eventFormRefreshCode, busy: _busy, onPressed: _busy ? null : _loadCode),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48)),
          onPressed: _busy ? null : _loadCode,
          child: Text(l.commonRetry, style: tx.bodyLarge!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
        ),
      ]),
    );
  }

  /// "64 / 128 kişi geldi" (sayı vurgulu).
  Widget _presentText(BuildContext context, {TextStyle? style}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final base = style ?? tx.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink);
    final text = l.etkinlik2PresentOf('$_present', '$_total');
    return Directionality(
      textDirection: Directionality.of(context),
      child: Text(text, key: const ValueKey('et2-present-count'), style: base),
    );
  }

  /// Yoklama özeti: "64 / 128 kişi geldi" + sağda "%50", 4 dp marka dolgulu çubuk, çerçeveli "Yoklama listesi".
  Widget _statusCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final pct = _total == 0 ? 0 : ((_present / _total) * 100).round().clamp(0, 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _presentText(context)),
        Text('%$pct', style: tx.bodySmall!.copyWith(color: t.mut)),
      ]),
      const SizedBox(height: 8),
      Et2Progress(fraction: _total == 0 ? 0 : _present / _total, height: 4),
      if (_lastName != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(l.evtLiveLastScanned(_lastName!), key: const ValueKey('et2-live-last'), style: tx.bodyMedium!.copyWith(color: t.mut)),
        ),
      ],
      const SizedBox(height: 20),
      KeyedSubtree(
        key: const ValueKey('et2-open-list'),
        child: ClubOutlineButton(label: l.p51EvAttList, onPressed: _openList),
      ),
    ]);
  }
}

/// QR çerçevesi: yüksek kontrast kâğıt zemin (240 dp, 16 köşe, çerçevesiz); [expired] iken QR bulanıklaşır ve "Süresi doldu / Yenileniyor…" çıkar.
class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.expired, required this.child});

  final bool expired;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 240,
          height: 240,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.qrPaper, borderRadius: BorderRadius.circular(16)),
          child: expired
              ? ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Opacity(opacity: .55, child: child is SizedBox ? const _PlaceholderQr() : child),
                )
              : child,
        ),
        if (expired)
          Semantics(
            liveRegion: true,
            label: '${l.p16QrExpiredTitle}. ${l.p16QrRefreshing}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: t.pr)),
                const SizedBox(height: 6),
                Text(l.p16QrExpiredTitle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                Text(l.p16QrRefreshing, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Kod yokken QR'ı andıran süs deseni (gerçek veri içermez; bulanık çizilir).
class _PlaceholderQr extends StatelessWidget {
  const _PlaceholderQr();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(192, 192), painter: _PlaceholderPainter(context.bu.mut));
}

class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const f = 52.0;
    for (final o in [Offset.zero, Offset(size.width - f, 0), Offset(0, size.height - f)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, f, f), const Radius.circular(8)), p);
    }
    const cells = [(80, 8), (104, 8), (88, 32), (128, 40), (64, 72), (96, 80), (124, 96), (72, 112), (100, 124), (150, 128), (130, 150), (88, 160), (170, 90)];
    for (final c in cells) {
      canvas.drawRect(Rect.fromLTWH(c.$1.toDouble(), c.$2.toDouble(), 16, 16), p);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.color != color;
}
