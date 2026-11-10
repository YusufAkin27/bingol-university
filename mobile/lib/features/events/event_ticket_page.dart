import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/wallet_config.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader;
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

class _EventTicketPageState extends State<EventTicketPage> {
  Map<String, dynamic>? _info;
  String? _qr;
  DateTime? _qrExp;
  bool _offline = false;
  bool _loading = true;
  String? _error;
  Timer? _refresh;

  int get _id => (widget.event['id'] as num).toInt();
  int? get _uid => widget.session.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refresh?.cancel();
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
      await _fallback(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQr(Map<String, dynamic> info) async {
    final state = ticketAvailability(widget.event, serverState: info['state'] as String?);
    if (state != TicketAvailability.valid || info['attendanceOpen'] != true) {
      if (mounted) setState(() => _qr = null);
      return;
    }
    try {
      final r = await widget.session.api.get('/events/$_id/my-ticket', force: true);
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r as Map);
      setState(() {
        _qr = m['qrPayload'] as String?;
        _qrExp = DateTime.tryParse('${m['expiresAt'] ?? ''}');
      });
      _refresh?.cancel();
      _refresh = Timer(const Duration(seconds: 60), () {
        if (mounted) _load();
      });
    } catch (_) {
      // QR alınamadı (yoklama kapandı/ağ): bilet bilgisi yine görünür.
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
            if (info == null && _loading) const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator())),
            if (info == null && !_loading)
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
    final wallet = info['wallet'] is Map ? info['wallet'] as Map : const {};
    final showWallet = kWalletEnabled && !off && (wallet['apple'] == true || wallet['google'] == true);

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
            child: off ? _disabled(context, av) : _qrBlock(context, info, expired),
          ),
        ]),
      ),
      if (showWallet) ...[
        const SizedBox(height: 16),
        BuButton(
            key: const ValueKey('ticket-wallet'),
            label: l.evtTicketAddWallet,
            kind: BuButtonKind.outline,
            icon: BuIcons.qrCode,
            onPressed: () => BuToast.show(context, l.evtTicketWalletSoon)),
      ],
      const SizedBox(height: 16),
      Text(l.evtTicketPrivacyNote, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(height: 1.45, color: t.mut)),
    ];
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
    ]);
  }
}
