import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_page.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'calm_cover.dart';
import 'etkinlik2_apply_sheet.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_qr_page.dart';
import 'etkinlik2_requests_page.dart';
import 'etkinlik2_settings_page.dart';
import 'etkinlik2_widgets.dart';
import 'etkinlik_parts.dart';
import 'event_cover.dart';
import 'event_form_page.dart';
import 'event_parts.dart';
import 'events_page.dart';

/// Dile göre intl biçimi; yerel ayar verisi yoksa varsayılana düşer.
String _fmtDate(BuildContext context, String pattern, DateTime d) {
  try {
    return DateFormat(pattern, Localizations.localeOf(context).toString()).format(d);
  } catch (_) {
    return DateFormat(pattern).format(d);
  }
}

/// Etkinlik detayı: bilgi, RSVP, yoklama, organizatör araçları ve etkinlik sohbeti.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.session, required this.eventId});

  final Session session;
  final int eventId;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? _ev;
  Object? _error;
  bool _loading = true;

  Map<String, dynamic>? _myAtt;
  List<Map<String, dynamic>> _attendance = []; // yalnızca organizatör: özet sayısı için

  bool _rsvpBusy = false;
  bool _chatBusy = false;
  bool _checkBusy = false;
  bool _enterCode = false;
  String? _codeError;
  final _codeCtl = TextEditingController();

  String get _path => '/events/${widget.eventId}';

  @override
  void initState() {
    super.initState();
    _codeCtl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load({bool refresh = false}) async {
    if (!refresh) setState(() => _loading = true);
    try {
      final r = await widget.session.api.get(_path);
      if (!mounted) return;
      setState(() {
        _ev = Map<String, dynamic>.from(r as Map);
        _error = null;
        _loading = false;
      });
      _loadExtras();
    } catch (e) {
      if (!mounted) return;
      // Admin gizlediyse (404) etkinlik herkes için yok: "Etkinlik bulunamadı" ekranına düşer.
      final gone = eventIsNotFound(e);
      setState(() {
        if (gone) _ev = null;
        if (_ev == null || !refresh || gone) _error = e;
        _loading = false;
      });
      if (refresh && _ev != null && !gone) _toast(errorText(e));
    }
  }

  bool get _manage => _ev?['canManage'] == true;

  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(session: widget.session, event: _ev)),
    );
    if (ok == true && mounted) _load(refresh: true);
  }
  String? get _rsvp => _ev?['myRsvp'] as String?;

  /// İkincil veriler: hata verirse sayfa bozulmaz.
  Future<void> _loadExtras() async {
    final api = widget.session.api;
    if (_manage) {
      try {
        final r = await api.get('$_path/attendance');
        if (mounted) setState(() => _attendance = _list(r));
      } catch (_) {}
    }
    if (_rsvp == 'GOING') {
      try {
        final r = await api.get('$_path/my-attendance');
        if (mounted) setState(() => _myAtt = Map<String, dynamic>.from(r as Map));
      } catch (_) {}
    } else if (mounted) {
      setState(() => _myAtt = null);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    BuToast.show(context, m);
  }

  bool get _approval => _ev?['joinPolicy'] == 'APPROVAL';

  /// Katıl / İlgileniyorum: yalnızca ekler. Geri alma "Katılımı yönet" bağlantısından, onayla yapılır.
  /// İstek ile etkinlikte `GOING` katılma isteği açar (yanıt `PENDING`).
  Future<void> _join(String status) async {
    if (_rsvpBusy) return;
    final ev = _ev!;
    final cap = (ev['capacity'] as num?)?.toInt();
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    if (status == 'GOING' && !_approval && _rsvp != 'GOING' && cap != null && going >= cap) {
      _toast(context.l10n.eventFormJoinFull);
      return;
    }
    setState(() => _rsvpBusy = true);
    try {
      final r = await widget.session.api.put('$_path/rsvp', {'status': status});
      if (!mounted) return;
      setState(() => _rsvpBusy = false);
      if (r is Map && r['myRsvp'] == 'PENDING') {
        _toast(context.l10n.etkinlik2RequestSentToast);
      } else {
        showJoinedToast(context, _openMine);
      }
      await _load(refresh: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _rsvpBusy = false;
          if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED') _ev = {...ev, 'registrationClosed': true};
        });
      }
      if (e is ApiError && e.code == 'ANSWERS_REQUIRED') {
        await _applyWithAnswers();
        return;
      }
      if (e is ApiError && (e.code == 'EVENT_FULL' || e.code == 'APPLICATION_REJECTED')) {
        if (mounted) await _load(refresh: true);
      }
      _toast(eventErrorText(e));
    }
  }

  /// Organizatör soru tanımladıysa: sorular alınır, cevaplarla `POST /applications` yapılır.
  Future<void> _applyWithAnswers() async {
    final api = widget.session.api;
    var questions = <String>[];
    try {
      final r = await api.get('$_path/admission');
      if (r is Map) questions = (r['questions'] as List? ?? const []).map((e) => '$e').toList();
    } catch (e) {
      _toast(errorText(e));
      return;
    }
    if (!mounted) return;
    final res = await showEtkinlik2ApplySheet(context, questions);
    if (res == null || !mounted) return;
    setState(() => _rsvpBusy = true);
    try {
      await api.post('$_path/applications', {
        if (res.note != null) 'note': res.note,
        'answers': res.answers,
      });
      if (!mounted) return;
      setState(() => _rsvpBusy = false);
      _toast(context.l10n.etkinlik2RequestSentToast);
      await _load(refresh: true);
    } catch (e) {
      if (mounted) setState(() => _rsvpBusy = false);
      _toast(eventErrorText(e));
    }
  }

  void _openMine() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventsPage(session: widget.session, initialTab: 1)),
    );
  }

  /// İkincil "Katılımı yönet": onay diyaloğundan sonra RSVP silinir.
  /// Bekleyen istek için "Geri çek" aynı ucu kullanır.
  Future<void> _leave({bool withdraw = false}) async {
    if (_rsvpBusy) return;
    final l = context.l10n;
    final ok = await confirmEventDialog(
      context,
      title: withdraw ? l.etkinlik2WithdrawTitle : l.eventFormLeaveTitle,
      message: withdraw ? l.etkinlik2WithdrawMessage : l.eventFormLeaveMessage,
      confirmLabel: withdraw ? l.etkinlik2Withdraw : l.eventFormLeaveConfirm,
      danger: true,
      icon: withdraw ? LucideIcons.undo2 : LucideIcons.calendarX,
    );
    if (!ok || !mounted) return;
    setState(() => _rsvpBusy = true);
    try {
      await widget.session.api.delete('$_path/rsvp');
      if (mounted) setState(() => _rsvpBusy = false);
      if (withdraw) _toast(l.etkinlik2WithdrawnToast);
      await _load(refresh: true);
    } catch (e) {
      if (mounted) setState(() => _rsvpBusy = false);
      _toast(eventErrorText(e));
    }
  }

  /// Yönetici menüsü: düzenle / ayarlar / kayıtları kapat-aç / iptal et.
  Future<void> _manageAction(String action) async {
    final api = widget.session.api;
    try {
      switch (action) {
        case 'edit':
          await _edit();
          return;
        case 'settings':
          await _openSettings();
          return;
        case 'close':
          await api.post('$_path/close', {});
          if (!mounted) return;
          _toast(context.l10n.eventFormRegsClosedToast);
        case 'reopen':
          await api.post('$_path/reopen', {});
          if (!mounted) return;
          _toast(context.l10n.eventFormRegsReopenedToast);
        case 'cancel':
          final ok = await confirmEventDialog(
            context,
            title: context.l10n.eventFormCancelTitle,
            message: context.l10n.eventFormCancelMessage,
            confirmLabel: context.l10n.eventFormCancelAction,
            danger: true,
            centered: true,
          );
          if (!ok || !mounted) return;
          await api.delete(_path);
          if (!mounted) return;
          _toast(context.l10n.eventFormCancelledToast);
      }
      if (mounted) await _load(refresh: true);
    } catch (e) {
      if (eventIsNotFound(e)) {
        if (mounted) await _load(refresh: true); // gizlenmiş: "Etkinlik bulunamadı" ekranı
      } else {
        if (!mounted) return;
        _toast(eventSaveErrorText(context, e));
      }
    }
  }

  Future<void> _openSettings() async {
    final r = await Navigator.push<Etkinlik2SettingsResult>(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2SettingsPage(session: widget.session, event: _ev!)),
    );
    if (r != null && mounted) _load(refresh: true);
  }

  Future<void> _openRequests() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2RequestsPage(session: widget.session, event: _ev!)),
    );
    if (mounted) _load(refresh: true);
  }

  Future<void> _openQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2QrPage(session: widget.session, event: _ev!)),
    );
    if (mounted) _loadExtras();
  }

  Future<void> _openAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: _ev!)),
    );
    if (mounted) _loadExtras();
  }

  /// QR tarayıcı sayfasındaki doğrulama kancası: hata metni dönerse sayfada kalır, null = yoklama alındı.
  Future<String?> _verifyScanned(String raw) async {
    final l = context.l10n;
    var code = raw.trim();
    const prefix = 'bingol-checkin:';
    if (code.startsWith(prefix)) code = code.substring(prefix.length);
    if (code.isEmpty) return l.eventListNotCode;
    final id = int.tryParse(code.split('.').first);
    if (id == null) return l.eventListNotCode;
    if (id != widget.eventId) return l.eventFormWrongEventCode;
    try {
      final r = await widget.session.api.post('$_path/check-in', {'code': code});
      if (mounted) setState(() => _myAtt = Map<String, dynamic>.from(r as Map));
      return null;
    } catch (e) {
      return errorText(e);
    }
  }

  /// QR ile tara (doğrulama tarayıcı sayfasında yapılır).
  Future<void> _scan() async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrScanPage(title: context.l10n.eventFormScanTitle, onSubmit: _verifyScanned)),
    );
  }

  /// Elle girilen kod: hata alanın altında kırmızı gösterilir.
  Future<void> _checkIn() async {
    if (_checkBusy) return;
    final raw = _codeCtl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _checkBusy = true;
      _codeError = null;
    });
    final err = await _verifyScanned(raw);
    if (!mounted) return;
    setState(() {
      _checkBusy = false;
      _codeError = err;
      if (err == null) {
        _enterCode = false;
        _codeCtl.clear();
      }
    });
  }

  Future<void> _openChat() async {
    if (_chatBusy) return;
    setState(() => _chatBusy = true);
    try {
      final r = await widget.session.api.get('/events/${widget.eventId}/chat');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(session: widget.session, conversation: Map<String, dynamic>.from(r as Map)),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 404 || e.status == 405) {
        _toast(context.l10n.eventFormChatSoon);
      } else {
        _toast(errorText(e));
      }
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  void _report() => ReportSheet.show(context, widget.session,
      targetType: 'EVENT', targetId: widget.eventId, title: context.l10n.eventFormReportEvent);

  // ---- görünüm ----

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    Widget body;
    if (_loading) {
      body = _DetailSkeleton(title: l.eventFormEventTitle);
    } else if (_ev == null && _error is ApiError && (_error as ApiError).status == 404) {
      body = Column(children: [
        BuHeader(title: l.eventFormEventTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: EmptyView(icon: LucideIcons.calendarX, text: l.eventFormNotFound)),
      ]);
    } else if (_ev == null) {
      body = ErrorView(error: _error ?? 'hata', onRetry: _load);
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              backgroundColor: t.bg,
              scrolledUnderElevation: 0,
              title: Text(l.eventFormEventTitle),
              actions: [_menu(), const SizedBox(width: 4)],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(context)),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: body,
      bottomNavigationBar: _barOrNull(),
    );
  }

  /// Sağ üst "⋯": organizatörde yönetim menüsü, diğerlerinde "Etkinliği şikâyet et".
  Widget _menu() {
    final t = context.bu;
    final l = context.l10n;
    final ev = _ev;
    if (ev == null) return const SizedBox.shrink();
    final closed = eventIsClosed(ev);
    if (_manage && !eventIsCancelled(ev)) {
      return PopupMenuButton<String>(
        tooltip: l.eventFormManage,
        icon: Icon(LucideIcons.ellipsis, color: t.ink),
        onSelected: _manageAction,
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(LucideIcons.pencil, size: 18, color: t.ink), const SizedBox(width: 12), Text(l.eventFormEdit)])),
          PopupMenuItem(
              value: 'settings',
              child: Row(children: [Icon(LucideIcons.settings, size: 18, color: t.ink), const SizedBox(width: 12), Text(l.etkinlik2ManageSettings)])),
          PopupMenuItem(
              value: closed ? 'reopen' : 'close',
              child: Row(children: [
                Icon(closed ? LucideIcons.lockOpen : LucideIcons.lock, size: 18, color: t.ink),
                const SizedBox(width: 12),
                Text(closed ? l.eventFormReopenRegs : l.eventFormCloseRegs),
              ])),
          const PopupMenuDivider(),
          PopupMenuItem(
              value: 'cancel',
              child: Row(children: [
                Icon(LucideIcons.trash2, size: 18, color: t.danger),
                const SizedBox(width: 12),
                Text(l.eventFormCancelAction, style: TextStyle(color: t.danger, fontWeight: FontWeight.w700)),
              ])),
        ],
      );
    }
    if (_manage) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: l.eventFormReport,
      icon: Icon(LucideIcons.ellipsis, color: t.ink),
      onSelected: (_) => _report(),
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'report',
            child: Row(children: [Icon(LucideIcons.flag, size: 18, color: t.danger), const SizedBox(width: 12), Text(l.eventFormReportEvent)])),
      ],
    );
  }

  /// Eylem çubuğu; durum (katıldı / ilgileniyor / hiçbiri) değişince solarak yer değiştirir.
  Widget? _barOrNull() {
    if (_loading || _ev == null || eventIsCancelled(_ev!) || eventIsPendingReview(_ev!) || eventIsRejected(_ev!)) return null;
    final bar = _actionBar();
    if (bar == null) return null;
    return BuFadeThrough(
      duration: BuMotion.short,
      child: KeyedSubtree(key: ValueKey<String>('bar-${_rsvp ?? '-'}-$_approval'), child: bar),
    );
  }

  /// Altta sabit eylem çubuğu (yalnız herkese açık katılımda).
  /// Katıldıysa "Katılımdan ayrıl"; değilse "İlgileniyorum" + "Katıl". Kapalı/dolu durumda ilgili düğme pasiftir.
  Widget? _actionBar() {
    if (_approval) {
      // İstek reddedildiyse sayfa altında tam genişlik koyu "Etkinlikleri keşfet" düğmesi.
      if (_rsvp == 'REJECTED' && !_manage) {
        return Et2BottomBar(
          child: EtkinlikInkButton(
            key: const ValueKey('et2-browse'),
            label: context.l10n.eventListDiscover,
            icon: LucideIcons.compass,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventsPage(session: widget.session))),
          ),
        );
      }
      return null;
    }
    final l = context.l10n;
    final ev = _ev!;
    final closed = eventIsClosed(ev);
    final cap = (ev['capacity'] as num?)?.toInt();
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    final rsvp = _rsvp;
    final full = cap != null && going >= cap && rsvp != 'GOING';
    if (rsvp == 'GOING') {
      final t = context.bu;
      return Et2BottomBar(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EtkinlikActionButton(
            key: const ValueKey('detail-leave'),
            label: l.eventFormLeaveTitle,
            icon: LucideIcons.calendarX,
            iconColor: t.danger,
            big: true,
            grey: true,
            onTap: _rsvpBusy ? null : _leave,
          ),
          const SizedBox(height: 8),
          Text(l.p15LeaveHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
        ]),
      );
    }
    final interested = rsvp == 'INTERESTED';
    return Et2BottomBar(
      child: Row(children: [
        Expanded(
          flex: 5,
          child: EtkinlikActionButton(
            key: const ValueKey('detail-interested'),
            label: l.eventFormInterested,
            icon: interested ? Icons.star_rounded : LucideIcons.star, // seçiliyken dolu yıldız
            big: true,
            selected: interested,
            // Kayıtlar kapalıyken önceden ilgilenen kullanıcı ilgisini geri alabilir.
            onTap: _rsvpBusy ? null : (interested ? _unInterested : (closed ? null : () => _join('INTERESTED'))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: EtkinlikActionButton(
            key: const ValueKey('detail-join'),
            label: l.eventFormJoin,
            icon: (closed || full) ? LucideIcons.lock : LucideIcons.circleCheck,
            primary: true,
            big: true,
            busy: _rsvpBusy && !interested,
            onTap: (_rsvpBusy || closed || full) ? null : () => _join('GOING'),
          ),
        ),
      ]),
    );
  }

  /// "İlgileniyorum" seçiliyken tekrar dokunmak ilgiyi geri alır (onaysız; DELETE rsvp).
  Future<void> _unInterested() async {
    if (_rsvpBusy) return;
    setState(() => _rsvpBusy = true);
    try {
      await widget.session.api.delete('$_path/rsvp');
      if (mounted) setState(() => _rsvpBusy = false);
      await _load(refresh: true);
    } catch (e) {
      if (mounted) setState(() => _rsvpBusy = false);
      _toast(eventErrorText(e));
    }
  }

  /// İstek ile katılım kartı: istek yok / gönderildi / reddedildi / kayıt kapalı.
  Widget _requestCard() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final rsvp = _rsvp;
    if (rsvp == 'GOING') return const SizedBox.shrink();
    if (rsvp == 'PENDING') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.warn.withValues(alpha: .18), shape: BoxShape.circle),
                child: Icon(LucideIcons.hourglass, size: 22, color: t.onWarnSoft),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.etkinlik2RequestSent, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onWarnSoft)),
                Text(l.etkinlik2AwaitingReply, style: tx.bodyMedium!.copyWith(color: t.onWarnSoft.withValues(alpha: .85))),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Et2GreyButton(
            key: const ValueKey('et2-withdraw'),
            label: l.etkinlik2Withdraw,
            onPressed: _rsvpBusy ? null : () => _leave(withdraw: true),
          ),
        ]),
      );
    }
    if (rsvp == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
                child: Icon(LucideIcons.x, size: 22, color: t.onPr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.etkinlik2RejectedTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
                const SizedBox(height: 2),
                Text(l.etkinlik2RejectedBody, style: tx.bodyMedium!.copyWith(height: 1.4, color: t.danger)),
              ]),
            ),
          ]),
        ]),
      );
    }
    if (eventIsClosed(_ev!)) return const SizedBox.shrink();
    return BuCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(
          key: const ValueKey('et2-request-send'),
          label: l.etkinlik2SendRequest,
          busy: _rsvpBusy,
          onPressed: _rsvpBusy ? null : () => _join('GOING'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Text(l.etkinlik2RequestHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
        ),
      ]),
    );
  }

  Widget _iconRow(IconData icon, String title, {String? sub, Widget? trailing, bool strike = false, Widget? subWidget}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(children: [
      ExcludeSemantics(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: t.pr),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              style: tx.titleSmall!.copyWith(
                  fontWeight: FontWeight.w700, color: strike ? t.mut : t.ink, decoration: strike ? TextDecoration.lineThrough : null)),
          if (subWidget != null) subWidget else if (sub != null) Text(sub, style: tx.bodySmall!.copyWith(color: t.mut)),
        ]),
      ),
      if (trailing != null) trailing,
    ]);
  }

  List<Widget> _content(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final ev = _ev!;
    final starts = DateTime.tryParse('${ev['startsAt']}')?.toLocal();
    final ends = DateTime.tryParse('${ev['endsAt']}')?.toLocal();
    final cover = fileUrl(ev['coverUrl'] as String?);
    final club = ev['communityName'] as String?;
    final org = ev['organizer'] is Map ? Map<String, dynamic>.from(ev['organizer'] as Map) : null;
    final orgName = '${org?['displayName'] ?? ev['organizerName'] ?? ''}'.trim();
    final cid = (ev['communityId'] as num?)?.toInt();
    final location = ev['location'] as String?;
    final desc = ev['description'] as String?;
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    final interested = (ev['interestedCount'] as num?)?.toInt();
    final cap = (ev['capacity'] as num?)?.toInt();
    final rsvp = _rsvp;
    final full = cap != null && going >= cap && rsvp != 'GOING';
    final closed = eventIsClosed(ev);
    final cancelled = eventIsCancelled(ev);
    final pendingReview = eventIsPendingReview(ev);
    final rejected = eventIsRejected(ev);
    final member = rsvp == 'GOING' || _manage;

    // Durum hapları
    final pills = <Widget>[
      if (cancelled) EventStatusTag(l.eventFormCancelledPill, tone: EventTone.danger, icon: LucideIcons.circleX),
      if (pendingReview) EventStatusTag(l.evcStatusPending, tone: EventTone.warn, icon: LucideIcons.hourglass),
      if (rejected) EventStatusTag(l.evcStatusRejected, tone: EventTone.danger, icon: LucideIcons.circleAlert),
      if (!cancelled && _approval) EventStatusTag(l.etkinlik2PolicyApprovalTag, tone: EventTone.brand),
      if (!cancelled && rsvp == 'GOING') ...[
        EventStatusTag(_approval ? l.etkinlik2ApprovedTag : l.eventFormInMine, tone: EventTone.ok, icon: LucideIcons.circleCheck),
        EventStatusTag(l.eventFormGoingLabel, tone: EventTone.neutral, icon: LucideIcons.checkCheck),
      ],
      if (!cancelled && rsvp == 'INTERESTED') EventStatusTag(l.p15StatusInterested, tone: EventTone.neutral, icon: LucideIcons.circleCheck),
      if (!cancelled && closed) EventStatusTag(l.eventFormRegsClosed, tone: EventTone.neutral, icon: LucideIcons.lock),
      if (!cancelled && !closed && !full && !_approval && rsvp == null && cap != null)
        EventStatusTag(l.etkinlik2RegOpenSlots('${cap - going}'), tone: EventTone.brand, icon: LucideIcons.zap),
    ];

    final Widget cover0 = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          if (cover != null) EventCoverImage(url: cover, cacheWidth: 1000) else CalmCover(seed: (ev['communityId'] as num?)?.toInt() ?? (ev['id'] as num?)?.toInt() ?? 0, icon: LucideIcons.calendarDays),
          if (cancelled) Positioned.fill(child: ColoredBox(color: t.scrim.withValues(alpha: .4))),
          if (!cancelled && closed)
            PositionedDirectional(
              start: 12,
              top: 12,
              child: _OverlayChip(label: l.eventFormRegsClosed, icon: LucideIcons.lock),
            )
          else if (!cancelled && full)
            PositionedDirectional(
              start: 12,
              top: 12,
              child: _OverlayChip(label: l.eventFormCapacityFull, icon: LucideIcons.ban, danger: true),
            ),
        ]),
      ),
    );

    final Widget info = BuCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (pills.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Wrap(spacing: 8, runSpacing: 6, children: pills)),
        Text('${ev['title'] ?? ''}',
            style: tx.headlineSmall!.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: cancelled ? t.mut : t.ink,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            )),
        if ((club != null && club.isNotEmpty) || orgName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Semantics(
            button: cid != null,
            child: BuPressable(
              onTap: cid == null
                  ? null
                  : () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ClubDetailPage(session: widget.session, communityId: cid))),
              enabled: cid != null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
                    child: Icon(LucideIcons.users, size: 16, color: t.bg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: tx.bodyMedium!.copyWith(color: t.mut), children: [
                        TextSpan(text: (club != null && club.isNotEmpty) ? '${l.eventFormOrganizedBy} ' : '${l.etkinlik2Organizer}: '),
                        TextSpan(
                            text: (club != null && club.isNotEmpty) ? club : orgName,
                            style: TextStyle(fontWeight: FontWeight.w700, color: cid == null ? t.ink : t.pr)),
                      ]),
                    ),
                  ),
                  if (cid != null) Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (starts != null)
          _iconRow(
            LucideIcons.calendarDays,
            '${_fmtDate(context, 'd MMMM y', starts)} · ${ends == null ? _hm(starts) : '${_hm(starts)} - ${_hm(ends)}'}',
            sub: _fmtDate(context, 'EEEE', starts),
            strike: cancelled,
            subWidget: cancelled
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.calendarX, size: 13, color: t.danger),
                    const SizedBox(width: 4),
                    Text(l.p15WontHappen, style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
                  ])
                : null,
          ),
        if (location != null && location.isNotEmpty) ...[
          if (starts != null) const SizedBox(height: 10),
          _iconRow(LucideIcons.mapPin, location),
        ],
        if (!cancelled) ...[
          const SizedBox(height: 14),
          _capacityBlock(going: going, interested: interested, cap: cap, full: full, closed: closed),
        ],
      ]),
    );

    final Widget chat = _chatRow(member: member);

    final rejectedRequest = _approval && !_manage && !cancelled && rsvp == 'REJECTED';
    return [
      cover0,
      if (rejectedRequest) ...[const SizedBox(height: 12), _requestCard()],
      const SizedBox(height: 12),
      info,
      if (cancelled) ...[
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('detail-cancelled'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
                child: Icon(LucideIcons.info, size: 20, color: t.onPr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.p15CancelledNotice, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.danger)),
                const SizedBox(height: 2),
                Text(l.p15CancelledBody, style: tx.bodyMedium!.copyWith(color: t.danger.withValues(alpha: .85))),
              ]),
            ),
          ]),
        ),
      ],
      if (eventIsPendingReview(ev) || rejected) ...[
        const SizedBox(height: 12),
        Text(
            eventIsPendingReview(ev)
                ? l.evcInfoReview
                : (eventRejectReason(ev) == null ? '' : l.evcRejectReason(eventRejectReason(ev)!)),
            style: tx.bodySmall!.copyWith(color: t.mut)),
      ],
      if (_manage && !cancelled) ...[
        const SizedBox(height: 12),
        _manageBlock(),
      ],
      if (_approval && !_manage && !cancelled && !pendingReview && !rejected && rsvp != 'GOING' && rsvp != 'REJECTED') ...[
        const SizedBox(height: 12),
        _requestCard(),
      ],
      if (rsvp == 'GOING' && !cancelled) ...[
        const SizedBox(height: 12),
        // Yoklama durumu değişince (yoklama aç/kapalı -> geldi) blok solarak yer değiştirir.
        BuFadeThrough(duration: BuMotion.short, child: _attendanceBlock()),
      ],
      if (!cancelled) ...[
        const SizedBox(height: 12),
        chat,
      ],
      if (desc != null && desc.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        BuCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.p15AboutTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
            const SizedBox(height: 8),
            Text(desc, style: tx.bodyMedium!.copyWith(height: 1.55, color: t.mut)),
          ]),
        ),
      ],
      if (_approval && rsvp == 'GOING' && !cancelled) ...[
        const SizedBox(height: 12),
        Et2GreyButton(key: const ValueKey('detail-leave-approval'), label: l.eventFormLeaveTitle, icon: LucideIcons.calendarX, onPressed: _rsvpBusy ? null : _leave),
      ],
    ];
  }

  /// Kontenjan bloğu: "Kontenjan: 34 / 50" + doluluk + çubuk; sayaç satırı; doluysa uyarı.
  Widget _capacityBlock({required int going, required int? interested, required int? cap, required bool full, required bool closed}) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final pct = cap == null || cap == 0 ? 0 : ((going / cap) * 100).round().clamp(0, 100);
    final counts = interested != null ? l.etkinlik2GoingInterested('$going', '$interested') : l.etkinlik2GoingOnly('$going');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (cap != null) ...[
          Row(children: [
            ExcludeSemantics(child: Icon(LucideIcons.users, size: 18, color: t.pr)),
            const SizedBox(width: 8),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(l.eventFormCapacityCount('$going', '$cap'),
                    style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              ),
            ),
            if (full)
              EventStatusTag(l.eventFormCapacityFull, tone: EventTone.danger)
            else
              Text(l.p15PercentFull('$pct'), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
          ]),
          const SizedBox(height: 10),
          Et2Progress(fraction: cap == 0 ? 1 : going / cap, height: 8),
          const SizedBox(height: 10),
        ],
        Row(children: [
          ExcludeSemantics(child: Icon(LucideIcons.users, size: 15, color: t.mut)),
          const SizedBox(width: 8),
          Expanded(child: Text(counts, style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
        ]),
        if (full && !_approval)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.info, size: 16, color: t.mut),
                const SizedBox(width: 8),
                Expanded(child: Text(l.eventFormFullHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut))),
              ]),
            ),
          ),
        if (_approval && !closed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(LucideIcons.userCheck, size: 15, color: t.mut),
              const SizedBox(width: 8),
              Expanded(child: Text(l.etkinlik2ApprovalByOrganizer, style: tx.bodySmall!.copyWith(color: t.mut))),
            ]),
          ),
      ]),
    );
  }

  /// Etkinlik sohbeti: açık (herkese açıkta herkes; istek ile katılımda yalnız üye/organizatör) ya da kilitli.
  Widget _chatRow({required bool member}) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    // Katılmamış kullanıcıya: istek ile katılımda ya da kayıtlar kapalıyken sohbet kilitli (sunucu da RSVP'siz 403 verir).
    final locked = !member && (_approval || eventIsClosed(_ev!));
    return BuCard(
      key: ValueKey(locked ? 'et2-chat-locked' : 'detail-chat'),
      radius: 20,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
      onTap: locked || _chatBusy ? null : _openChat,
      child: Row(children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: locked ? t.sf2 : t.soft, borderRadius: BorderRadius.circular(14)),
            child: Icon(locked ? LucideIcons.lock : LucideIcons.messagesSquare, size: 22, color: locked ? t.mut : t.pr),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.eventFormChat, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: locked ? t.mut : t.ink)),
            Text(locked ? l.p15ChatLockedSub : l.p15ChatSub, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        if (locked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: t.mut.withValues(alpha: .12), borderRadius: BorderRadius.circular(BuRadius.pill)),
            child: Text(l.p15LockedBadge, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
          )
        else
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
            child: _chatBusy
                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.ink),
          ),
      ]),
    );
  }

  Widget _attendanceBlock() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final att = _myAtt;
    if (att == null) return const SizedBox.shrink();
    if (att['present'] == true) {
      return Container(
        key: const ValueKey('detail-checked-in'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          // Başarı onayı: yeşil daire 0.5 -> 1 ölçekle yaylanarak belirir, onay işareti ardından solar (tek seferlik).
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: BuMotion.of(context, BuMotion.long),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: .5 + .5 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle),
              child: Icon(LucideIcons.check, size: 24, color: t.onPr),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.eventFormCheckedIn, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ok)),
              Text(l.p15CheckedInBody, style: tx.bodyMedium!.copyWith(color: t.ok)),
            ]),
          ),
        ]),
      );
    }
    final open = att['checkInOpen'] == true;
    return BuCard(
      key: const ValueKey('detail-attendance'),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (open)
            Container(width: 10, height: 10, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle))
          else
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                child: Icon(LucideIcons.clock, size: 20, color: t.ink),
              ),
            ),
          SizedBox(width: open ? 10 : 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.etkinlik2AttendanceLabel, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              if (!open) Text(l.eventFormCheckInLater, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
        ]),
        if (open) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.info, size: 16, color: t.pr),
              const SizedBox(width: 8),
              Expanded(child: Text(l.p15AttOpenHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut))),
            ]),
          ),
          const SizedBox(height: 12),
          BuButton(key: const ValueKey('detail-scan'), label: l.eventFormScanQr, icon: LucideIcons.scanLine, onPressed: _scan),
          const SizedBox(height: 8),
          Et2GreyButton(
            key: const ValueKey('detail-enter-code'),
            label: l.eventFormEnterCode,
            icon: LucideIcons.keyboard,
            onPressed: () => setState(() => _enterCode = !_enterCode),
          ),
          if (_enterCode) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text(l.eventFormCheckInCode, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
              Text(l.p15CodeChars('${_codeCtl.text.length}'), style: tx.labelSmall!.copyWith(color: t.mut)),
            ]),
            Text(l.eventFormEnterOrganizerCode, style: tx.bodySmall!.copyWith(color: t.mut)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('detail-code-field'),
              controller: _codeCtl,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_codeError != null) setState(() => _codeError = null);
              },
              onSubmitted: (_) => _checkIn(),
              textAlign: TextAlign.center,
              style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2, color: t.ink),
              decoration: InputDecoration(
                hintText: 'K7M4QX',
                hintStyle: tx.titleMedium!.copyWith(color: t.mut.withValues(alpha: .6), letterSpacing: 2),
                filled: true,
                fillColor: t.sf2,
                suffixIcon: _codeCtl.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('detail-code-clear'),
                        tooltip: l.p15ClearField,
                        icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                        onPressed: () {
                          _codeCtl.clear();
                          if (_codeError != null) setState(() => _codeError = null);
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            if (_codeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(LucideIcons.circleAlert, size: 16, color: t.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_codeError!, key: const ValueKey('detail-code-error'), style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            const SizedBox(height: 10),
            EtkinlikInkButton(label: l.eventFormSendCheckIn, icon: LucideIcons.userCheck, onTap: _checkBusy ? () {} : _checkIn),
          ],
        ],
      ]),
    );
  }

  Widget _manageBlock() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final present = _attendance.where((r) => r['present'] == true).length;
    final total = _attendance.length;
    final pending = (_ev?['pendingCount'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BuCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Et2IconBox(LucideIcons.userCheck, size: 40, tint: t.tint(1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.p16QrStatusTitle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                Text(total == 0 ? l.eventFormNoAttendance : l.eventFormAttendanceCount('$present', '$total'),
                    key: const ValueKey('detail-att-summary'), style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Et2Progress(fraction: total == 0 ? 0 : present / total, height: 8),
          const SizedBox(height: 12),
          EtkinlikActionButton(
            key: const ValueKey('detail-open-qr'),
            label: l.eventFormCheckInCode,
            icon: LucideIcons.qrCode,
            onTap: _openQr,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      BuCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l.etkinlik2ManageSection, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ),
          ),
          if (_approval)
            Et2NavRow(
              icon: LucideIcons.userCheck,
              title: l.etkinlik2ManageRequests,
              sub: pending == 0 ? l.etkinlik2ManageNoPending : l.etkinlik2ManagePending('$pending'),
              badge: pending > 0 ? l.etkinlik2ManagePending('$pending') : null,
              onTap: _openRequests,
            ),
          Et2NavRow(
            top: _approval,
            icon: LucideIcons.clipboardCheck,
            title: l.etkinlik2ManageAttendance,
            sub: total == 0 ? l.eventFormNoAttendance : l.eventFormAttendanceCount('$present', '$total'),
            onTap: _openAttendance,
          ),
          Et2NavRow(
            top: true,
            icon: LucideIcons.settings,
            title: l.etkinlik2ManageSettings,
            sub: l.p15SettingsSub,
            onTap: _openSettings,
          ),
        ]),
      ),
    ]);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}

/// Kapak üstü yarı saydam hap ("Kayıtlar kapalı" / "Kontenjan doldu").
class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label, required this.icon, this.danger = false});

  final String label;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = danger ? t.danger : BuTokens.light.sf.withValues(alpha: .95);
    final fg = danger ? t.onPr : BuTokens.light.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// Yükleniyor iskeleti: başlıklı çubuk + kapak + bilgi kartı.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(children: [
      BuHeader(title: title, onBack: () => Navigator.pop(context)),
      Expanded(
        child: BuSkeletonScope(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const AspectRatio(aspectRatio: 16 / 9, child: BuSkeleton(radius: 20)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton(width: 120, height: 20, radius: 10),
                  SizedBox(height: 12),
                  BuSkeleton.line(height: 24),
                  SizedBox(height: 12),
                  BuSkeleton(height: 48, radius: 14),
                  SizedBox(height: 14),
                  BuSkeleton.line(width: 200, height: 16),
                  SizedBox(height: 10),
                  BuSkeleton.line(width: 160, height: 16),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
