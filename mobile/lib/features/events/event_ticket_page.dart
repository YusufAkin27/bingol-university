import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader;
import 'attendance_live.dart';
import 'event_ticket_store.dart';
import 'qr_painter.dart';

/// "Biletim" (T1): onaylı katılımcının etkinlik bileti. Etkinlik bilgisi `GET /events/{id}/ticket`, kişisel kısa ömürlü
/// QR `GET /events/{id}/my-ticket` (mevcut yoklama sözleşmesi aynen; yalnız yoklama açıkken). Çevrimdışıyken son
/// görülen bilet (hesap bazlı) gösterilir, QR'ın süresi dolmuş olabileceği belirtilir. Paylaşma YOKTUR: bilet kişiye özeldir.
class EventTicketPage extends StatefulWidget {
  const EventTicketPage({super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage> with WidgetsBindingObserver {
  Map<String, dynamic>? _info;
  String? _qr;
  DateTime? _qrExp;
  bool _offline = false;
  bool _loading = true;
  String? _error;
  Timer? _refresh;
  bool _staff = false; // sahip/moderatör: kişisel QR yok (sunucu 403 TICKET_NOT_FOR_STAFF)
  String? _qrError; // my-ticket 4xx: sunucunun açıklayıcı mesajı (yoklama açık değil / katılım onaylı değil ...)

  /// Görevli QR'ı okuttu: yoklama alındı (gerçek zamanlı olay ya da poll yedeği). Null = henüz okutulmadı.
  DateTime? _checkedAt;
  AttendanceLiveBinding? _live;

  int get _id => (widget.event['id'] as num).toInt();
  int? get _uid => widget.session.userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _live = AttendanceLiveBinding(
      session: widget.session,
      eventId: _id,
      onEvent: (e) {
        if (e.isMarked) _markDone(e.at);
      },
      onPoll: _pollMine,
    )..start();
    _pollMine();
  }

  /// Yedek eşitleme: olay kaçsa da `my-attendance` doğruyu söyler (idempotent).
  Future<void> _pollMine() async {
    if (_checkedAt != null) return;
    try {
      final r = await widget.session.api.get('/events/$_id/my-attendance', force: true);
      if (r is Map && r['present'] == true) _markDone(DateTime.tryParse('${r['markedAt'] ?? ''}'));
    } catch (_) {
      // En iyi çaba: sonraki turda yeniden denenir.
    }
  }

  void _markDone(DateTime? at) {
    if (!mounted || _checkedAt != null) return; // çift olay: yalnız ilk
    _refresh?.cancel();
    buHaptic(BuHaptic.medium);
    setState(() {
      _checkedAt = (at ?? DateTime.now()).toLocal();
      _qr = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plandan dönünce bileti hemen yenile (zamanlayıcı uykudayken bayatlamış olabilir).
    if (state == AppLifecycleState.resumed && _checkedAt == null) {
      _load();
      _pollMine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _live?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.session.api.get('/events/$_id/ticket', force: true);
      final info = Map<String, dynamic>.from(r as Map);
      if (!mounted) return;
      setState(() {
        _info = info;
        _offline = false;
      });
      await _loadQr(info);
      final uid = _uid;
      if (uid != null) {
        await EventTicketStore.save(uid, _id, info, qr: _qr, qrExpiresAt: _qrExp?.toUtc().toIso8601String());
      }
    } catch (e) {
      if (e is ApiError && e.status == 403 && e.code == 'TICKET_NOT_FOR_STAFF') {
        if (mounted) setState(() => _staff = true);
        _refresh?.cancel();
        return;
      }
      await _fallback(e);
      if (_offline) _scheduleRetry(); // ağ kesintisinde de biletin canlı hali kendiliğinden gelsin
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Hata sonrası yeniden deneme (dispose'da iptal edilir).
  void _scheduleRetry() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(seconds: 15), () {
      if (mounted) _load();
    });
  }

  Future<void> _loadQr(Map<String, dynamic> info) async {
    if (_checkedAt != null) return;
    final state = ticketAvailability(widget.event, serverState: info['state'] as String?);
    if (state != TicketAvailability.valid || info['attendanceOpen'] != true) {
      if (mounted) setState(() => _qr = null);
      _refresh?.cancel();
      // Bilet geçerli ama yoklama henüz kapalı: sayfa açıkken görevli yoklamayı açınca QR kendiliğinden gelsin.
      if (state == TicketAvailability.valid) {
        _refresh = Timer(const Duration(seconds: 30), () {
          if (mounted) _load();
        });
      }
      return;
    }
    try {
      final r = await widget.session.api.get('/events/$_id/my-ticket', force: true);
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      setState(() {
        _qr = m['qrPayload'] as String?;
        _qrExp = DateTime.tryParse('${m['expiresAt'] ?? ''}');
        _qrError = null;
      });
      _refresh?.cancel();
      _refresh = Timer(const Duration(seconds: 60), () {
        if (mounted) _load();
      });
    } catch (e) {
      if (e is ApiError && e.status == 403 && e.code == 'TICKET_NOT_FOR_STAFF') {
        // Görevlinin QR'ı olmaz: yeniden denemek anlamsız, sunucu mesajı gösterilir.
        if (mounted) setState(() => _staff = true);
        _refresh?.cancel();
        return;
      }
      if (e is ApiError && !e.isNetwork && e.status < 500) {
        // 4xx: sunucunun açıklayıcı mesajı gösterilir (genel "bağlanılamadı" değil); otomatik tekrar yok.
        if (mounted) setState(() { _qr = null; _qrError = errorText(e); });
        _refresh?.cancel();
        return;
      }
      // QR alınamadı (ağ/5xx): mevcut QR korunur (süresi dolana kadar çalışır), hata altında gösterilir; kısa aralıkla yeniden dene.
      if (mounted) setState(() => _qrError = errorText(e));
      _scheduleRetry();
    }
  }

  /// Ağ yoksa son görülen bilet; başka hata (403/404) sunucu mesajıyla gösterilir.
  Future<void> _fallback(Object e) async {
    final offline = e is! ApiError || e.isNetwork || e.status >= 500;
    final uid = _uid;
    if (offline && uid != null) {
      final c = await EventTicketStore.load(uid, _id);
      if (c != null && mounted) {
        setState(() {
          _info = Map<String, dynamic>.from(c['info'] as Map);
          _qr = c['qr'] as String?;
          _qrExp = DateTime.tryParse('${c['qrExp'] ?? ''}');
          _offline = true;
        });
        return;
      }
    }
    if (mounted) setState(() => _error = errorText(e));
  }

  String _fmt(DateTime d, String p) {
    try {
      return DateFormat(p, Localizations.localeOf(context).toString()).format(d);
    } catch (_) {
      return DateFormat(p).format(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final info = _info;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ClubPageHeader(title: l.evtTicketTitle),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 11, 20, 32), children: [
            if (info == null && _loading) const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: BuSpinner(size: 28))),
            if (info == null && _staff)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(l.evtAtt2StaffNoQr, key: const ValueKey('ticket-staff-note'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
              ),
            if (info == null && !_loading && !_staff)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  Text(_error ?? l.evtTicketLoadFailed, key: const ValueKey('ticket-error'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
                  const SizedBox(height: 12),
                  BuButton(label: l.commonRetry, onPressed: _load),
                ]),
              ),
            if (info != null) ..._ticket(context, info),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _ticket(BuildContext context, Map<String, dynamic> info) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final av = ticketAvailability(widget.event, serverState: info['state'] as String?);
    final off = av != TicketAvailability.valid;
    final starts = DateTime.tryParse('${info['startsAt'] ?? ''}')?.toLocal();
    final ends = DateTime.tryParse('${info['endsAt'] ?? ''}')?.toLocal();
    final place = '${info['location'] ?? ''}'.trim();
    final org = '${info['organizerName'] ?? ''}'.trim();
    final holder = '${info['holderName'] ?? ''}'.trim();
    final expired = _qrExp != null && !_qrExp!.isAfter(DateTime.now());

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 88, child: Text(k, style: tx.bodySmall!.copyWith(color: t.mut))),
            Expanded(child: Text(v, style: tx.bodyMedium!.copyWith(color: t.ink))),
          ]),
        );
    Widget notch(bool start) => Container(
          width: 10,
          height: 20,
          decoration: BoxDecoration(
            color: t.bg,
            border: Border.all(color: t.bd),
            borderRadius: BorderRadiusDirectional.horizontal(start: start ? Radius.zero : const Radius.circular(10), end: start ? const Radius.circular(10) : Radius.zero)
                .resolve(Directionality.of(context)),
          ),
        );

    return [
      if (_offline)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(l.evtTicketOffline, key: const ValueKey('ticket-offline'), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
        ),
      Container(
        key: const ValueKey('ticket-card'),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${info['title'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tx.titleLarge!.copyWith(
                      fontWeight: FontWeight.w400, color: off ? t.mut : t.ink, decoration: av == TicketAvailability.cancelled ? TextDecoration.lineThrough : null)),
              if (starts != null) kv(l.p51EvLblDate, _fmt(starts, 'd MMMM EEEE')),
              if (starts != null) kv(l.p51EvLblTime, ends == null ? _fmt(starts, 'HH:mm') : '${_fmt(starts, 'HH:mm')} – ${_fmt(ends, 'HH:mm')}'),
              if (place.isNotEmpty) kv(l.p51EvLblPlace, place),
              if (org.isNotEmpty) kv(l.evtTicketOrganizer, org),
              if (holder.isNotEmpty) kv(l.evtTicketHolder, holder),
            ]),
          ),
          // Kesik kenar: yalnız sade çizgiler (iki yan çentik + kesik çizgi), gölge/degrade yok.
          Row(children: [
            notch(true),
            Expanded(child: LayoutBuilder(builder: (_, c) {
              final n = (c.maxWidth / 10).floor();
              return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (var i = 0; i < n; i++) Container(width: 5, height: 1, color: t.bd)]);
            })),
            notch(false),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _checkedAt != null ? _done(context) : (off ? _disabled(context, av) : _qrBlock(context, info, expired)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(l.evtTicketPrivacyNote, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(height: 1.45, color: t.mut)),
    ];
  }

  /// Okutuldu durumu: QR yerine belirgin onay (Semantics liveRegion ile ekran okuyucuya duyurulur).
  Widget _done(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final at = _checkedAt!;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${l.evtLiveCheckedInTitle}. ${l.evtLiveCheckedInBody}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          key: const ValueKey('ticket-done'),
          duration: liveMotion(context),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
              child: Icon(BuIcons.check, size: 40, color: t.bg),
            ),
            const SizedBox(height: 16),
            Text(l.evtLiveCheckedInTitle, textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
            const SizedBox(height: 6),
            Text(l.evtLiveCheckedInBody, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
            const SizedBox(height: 4),
            Text(l.evtLiveCheckedInAt(time), textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
          ]),
        ),
      ),
    );
  }

  Widget _disabled(BuildContext context, TicketAvailability av) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(children: [
      Icon(BuIcons.qrCode, size: 48, color: t.mut),
      const SizedBox(height: 10),
      Text(av == TicketAvailability.cancelled ? l.evtTicketCancelled : l.evtTicketEnded,
          key: const ValueKey('ticket-disabled'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink)),
    ]);
  }

  Widget _qrBlock(BuildContext context, Map<String, dynamic> info, bool expired) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (_staff) {
      return Text(l.evtAtt2StaffNoQr, key: const ValueKey('ticket-staff-note'), textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink));
    }
    if (_qr == null && _qrError != null) {
      return Text(_qrError!, key: const ValueKey('ticket-qr-error'), textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.ink));
    }
    if (_qr == null) {
      return Text(info['attendanceOpen'] == true ? l.evtTicketQrUnavailable : l.evtTicketQrNotOpen,
          key: const ValueKey('ticket-qr-note'), textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut));
    }
    return Column(children: [
      Container(
        key: const ValueKey('ticket-qr'),
        width: 232,
        height: 232,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.qrPaper, borderRadius: BorderRadius.circular(16)),
        child: QrView(data: _qr!, size: 208, radius: BuRadius.xs),
      ),
      const SizedBox(height: 12),
      Text(expired || _offline ? l.evtTicketQrMaybeExpired : l.evtAtt2ParticipantHint,
          key: const ValueKey('ticket-qr-hint'), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(height: 1.45, color: t.mut)),
      if (_qrError != null) ...[
        const SizedBox(height: 8),
        Text(_qrError!, key: const ValueKey('ticket-qr-error'), textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.ink)),
      ],
    ]);
  }
}
