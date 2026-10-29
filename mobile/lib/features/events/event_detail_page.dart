import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_page.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'etkinlik2_apply_sheet.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_qr_page.dart';
import 'etkinlik2_requests_page.dart';
import 'etkinlik2_settings_page.dart';
import 'etkinlik2_widgets.dart';
import 'event_cover.dart';
import 'event_form_page.dart';
import 'event_parts.dart';
import 'events_page.dart';
import '../../core/typography.dart';

/// Dile göre intl biçimi; yerel ayar verisi yoksa varsayılana düşer.
String _fmtDate(BuildContext context, String pattern, DateTime d) {
  try {
    return DateFormat(pattern, Localizations.localeOf(context).toString()).format(d);
  } catch (_) {
    return DateFormat(pattern).format(d);
  }
}

/// Kısa ay adı, büyük harf (Türkçede noktalı İ korunur).
String _monthShortUpper(BuildContext context, DateTime d) {
  final s = _fmtDate(context, 'MMM', d).replaceAll('.', '');
  final isTr = Localizations.localeOf(context).languageCode == 'tr';
  return (isTr ? s.replaceAll('i', 'İ') : s).toUpperCase();
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

  Map<String, dynamic>? _preview; // herkese açık: sayılar + en çok 8 avatar
  Map<String, dynamic>? _myAtt;
  List<Map<String, dynamic>> _attendance = []; // yalnızca organizatör: özet sayısı için

  bool _rsvpBusy = false;
  bool _chatBusy = false;
  bool _checkBusy = false;
  bool _enterCode = false;
  final _codeCtl = TextEditingController();

  String get _path => '/events/${widget.eventId}';

  @override
  void initState() {
    super.initState();
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
    try {
      final r = await api.get('$_path/attendees/preview');
      if (mounted && r is Map) setState(() => _preview = Map<String, dynamic>.from(r));
    } catch (_) {}
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
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

  Future<void> _checkIn() async {
    await _submitCode(_codeCtl.text);
  }

  /// QR ile tara; kod başka bir etkinliğe aitse uyar.
  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrScanPage(title: context.l10n.eventFormScanTitle)),
    );
    if (raw != null && mounted) await _submitCode(raw);
  }

  /// Kod biçimi "bingol-checkin:{etkinlikId}.{pencere}.{imza}"; önek elle girişte olmayabilir.
  Future<void> _submitCode(String raw) async {
    var code = raw.trim();
    const prefix = 'bingol-checkin:';
    if (code.startsWith(prefix)) code = code.substring(prefix.length);
    if (code.isEmpty || _checkBusy) return;
    final id = int.tryParse(code.split('.').first);
    if (id != null && id != widget.eventId) {
      _toast(context.l10n.eventFormWrongEventCode);
      return;
    }
    setState(() => _checkBusy = true);
    try {
      final r = await widget.session.api.post('$_path/check-in', {'code': code});
      if (!mounted) return;
      setState(() {
        _myAtt = Map<String, dynamic>.from(r as Map);
        _enterCode = false;
        _codeCtl.clear();
      });
      _toast(context.l10n.eventFormCheckedIn);
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _checkBusy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_ev == null && _error is ApiError && (_error as ApiError).status == 404) {
      body = Column(children: [
        BuHeader(title: context.l10n.eventFormEventTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: EmptyView(icon: LucideIcons.calendarX, text: context.l10n.eventFormNotFound)),
      ]);
    } else if (_ev == null) {
      body = ErrorView(error: _error ?? 'hata', onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(padding: EdgeInsets.zero, children: _content(context)),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: body,
      bottomNavigationBar: (!_loading &&
              _ev != null &&
              !eventIsCancelled(_ev!) &&
              !eventIsPendingReview(_ev!) &&
              !eventIsRejected(_ev!))
          ? _actionBar()
          : null,
    );
  }

  /// Altta sabit eylem çubuğu (yalnız herkese açık katılımda): "Katıl" ya da "Etkinliklerimde" + "İlgileniyorum".
  /// İstek ile katılımda eylemler içerikteki kartta durur (bkz. [_requestCard]).
  Widget? _actionBar() {
    if (_approval) return null;
    final t = context.bu;
    final ev = _ev!;
    final closed = eventIsClosed(ev);
    final rsvp = _rsvp;
    Widget main;
    if (rsvp == 'GOING') {
      main = EventJoinedChip(large: true, onTap: _openMine);
    } else if (closed) {
      main = BuButton(label: context.l10n.eventFormRegsClosed, icon: LucideIcons.lock, kind: BuButtonKind.soft);
    } else {
      main = BuButton(
        label: context.l10n.eventFormJoin,
        icon: LucideIcons.check,
        busy: _rsvpBusy,
        onPressed: _rsvpBusy ? null : () => _join('GOING'),
      );
    }
    final showInterest = rsvp != 'GOING' && !closed;
    final narrow = MediaQuery.of(context).size.width < 360;
    return Et2BottomBar(
      child: Row(children: [
        Expanded(child: main),
        if (showInterest) ...[
          const SizedBox(width: 10),
          rsvp == 'INTERESTED'
              ? EventStatusTag(context.l10n.eventFormInterested, tone: EventTone.warn)
              : Semantics(
                  button: true,
                  label: context.l10n.eventFormInterested,
                  excludeSemantics: true,
                  onTap: _rsvpBusy ? null : () => _join('INTERESTED'),
                  child: Material(
                    color: t.sf,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.bd, width: 1.5)),
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onTap: _rsvpBusy ? null : () => _join('INTERESTED'),
                      child: Container(
                        height: 56,
                        constraints: const BoxConstraints(minWidth: 56),
                        padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 16),
                        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(LucideIcons.star, size: 20, color: t.pr),
                          if (!narrow) ...[
                            const SizedBox(width: 8),
                            Text(context.l10n.eventFormInterested,
                                style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
        ],
      ]),
    );
  }

  /// İstek ile katılım kartı: istek yok / gönderildi / reddedildi / kayıt kapalı.
  Widget _requestCard() {
    final t = context.bu;
    final l = context.l10n;
    final rsvp = _rsvp;
    if (rsvp == 'GOING') {
      return EventJoinedChip(large: true, onTap: _openMine);
    }
    if (rsvp == 'PENDING') {
      return BuCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12)),
              child: Icon(LucideIcons.clock, size: 20, color: t.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.etkinlik2RequestSent, style: BuType.bodyStrong.copyWith(color: t.ink)),
                Text(l.etkinlik2AwaitingReply, style: BuType.caption.copyWith(color: t.mut)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Et2GhostButton(
            key: const ValueKey('et2-withdraw'),
            label: l.etkinlik2Withdraw,
            busy: _rsvpBusy,
            onPressed: _rsvpBusy ? null : () => _leave(withdraw: true),
          ),
        ]),
      );
    }
    if (rsvp == 'REJECTED') {
      return Et2Banner(icon: LucideIcons.circleX, title: l.etkinlik2RejectedTitle, text: l.etkinlik2RejectedBody);
    }
    if (eventIsClosed(_ev!)) {
      return BuButton(label: l.eventFormRegsClosed, icon: LucideIcons.lock, kind: BuButtonKind.soft);
    }
    return BuCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(
          key: const ValueKey('et2-request-send'),
          label: l.etkinlik2SendRequest,
          busy: _rsvpBusy,
          onPressed: _rsvpBusy ? null : () => _join('GOING'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Text(l.etkinlik2RequestHint, style: BuType.caption.copyWith(height: 1.4, color: t.mut)),
        ),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, String label, VoidCallback? onTap) =>
      Et2CircleButton(icon: icon, label: label, onTap: onTap);

  List<Widget> _content(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
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
    final full = cap != null && going >= cap;
    final rsvp = _rsvp;
    final closed = eventIsClosed(ev);
    final cancelled = eventIsCancelled(ev);
    final pad = MediaQuery.of(context).padding;
    final policyTag = _approval ? l.etkinlik2PolicyApprovalTag : l.etkinlik2PolicyOpen;
    final capSub = _approval
        ? (closed ? l.eventFormRegsClosed : l.etkinlik2ApprovalByOrganizer)
        : (closed
            ? l.eventFormRegsClosed
            : (full ? null : l.etkinlik2RegOpenSlots('${cap == null ? 0 : cap - going}')));

    return [
      // Kapak / gradyan hero
      Container(
        height: 250,
        decoration: BoxDecoration(gradient: cover == null ? t.hero : null),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (cover != null) Positioned.fill(child: EventCoverImage(url: cover, cacheWidth: 1000)),
            // Geri/menü düğmeleri ve tarih kutusu her kapakta okunur: üstte ve altta koyu geçiş.
            if (cover != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF171E33).withValues(alpha: .45),
                        const Color(0xFF171E33).withValues(alpha: 0),
                        const Color(0xFF171E33).withValues(alpha: .65),
                      ],
                      stops: const [0, .38, 1],
                    ),
                  ),
                ),
              ),
            if (cover == null) ...[
              PositionedDirectional(end: -40, top: -50, child: _circle(200, .15)),
              PositionedDirectional(start: 30, bottom: -70, child: _circle(160, .10)),
            ],
            PositionedDirectional(
              start: 20,
              top: pad.top + 12,
              child: _circleBtn(buDirIcon(context, LucideIcons.arrowLeft), l.eventFormBack, () => Navigator.pop(context)),
            ),
            if (_manage && !cancelled)
              PositionedDirectional(
                end: 20,
                top: pad.top + 12,
                child: Theme(
                  data: Theme.of(context).copyWith(
                      popupMenuTheme: PopupMenuThemeData(color: t.sf, surfaceTintColor: Colors.transparent)),
                  child: PopupMenuButton<String>(
                    tooltip: l.eventFormManage,
                    onSelected: _manageAction,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l.eventFormEdit)),
                      PopupMenuItem(value: 'settings', child: Text(l.etkinlik2ManageSettings)),
                      PopupMenuItem(
                          value: closed ? 'reopen' : 'close',
                          child: Text(closed ? l.eventFormReopenRegs : l.eventFormCloseRegs)),
                      PopupMenuItem(
                          value: 'cancel', child: Text(l.eventFormCancelAction, style: TextStyle(color: t.danger))),
                    ],
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                      child: Icon(LucideIcons.ellipsis, size: 20, color: t.ink),
                    ),
                  ),
                ),
              )
            else if (!_manage)
              PositionedDirectional(
                end: 20,
                top: pad.top + 12,
                child: _circleBtn(
                  LucideIcons.flag,
                  l.eventFormReport,
                  () => ReportSheet.show(context, widget.session,
                      targetType: 'EVENT', targetId: widget.eventId, title: l.eventFormReportEvent),
                ),
              ),
            if (starts != null)
              PositionedDirectional(
                start: 20,
                bottom: 6,
                child: Et2DateChip(month: _monthShortUpper(context, starts), day: '${starts.day}'),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Organizatör satırı + katılım türü etiketi
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(children: [
              BuAvatar(name: orgName, url: fileUrl(org?['avatarUrl'] as String?), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (orgName.isNotEmpty)
                    Text(orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                  Text(l.etkinlik2Organizer,
                      style: BuType.caption.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                ]),
              ),
              const SizedBox(width: 8),
              Flexible(flex: 0, child: Et2Tag(policyTag)),
            ]),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (cancelled) _Pill(l.eventFormCancelledPill, warn: true),
            if (eventIsPendingReview(ev)) _Pill(l.evcStatusPending),
            if (eventIsRejected(ev)) _Pill(l.evcStatusRejected, warn: true),
            if (!cancelled && closed) _Pill(l.eventFormRegsClosed),
            if (rsvp == 'GOING')
              _Pill(l.eventFormInMine, ok: true)
            else if (rsvp == 'INTERESTED')
              _Pill(l.eventFormInterested),
          ]),
          if (eventIsPendingReview(ev) || eventIsRejected(ev)) ...[
            const SizedBox(height: 8),
            Text(
                eventIsPendingReview(ev)
                    ? l.evcInfoReview
                    : (eventRejectReason(ev) == null ? '' : l.evcRejectReason(eventRejectReason(ev)!)),
                style: BuType.caption.copyWith(color: t.mut)),
          ],
          if (rsvp == 'GOING' || rsvp == 'INTERESTED' || cancelled || closed) const SizedBox(height: 8),
          Text('${ev['title'] ?? ''}',
              // Detayda başlık kesilmez (sayfa kayar); tam metin her zaman okunur.
              style: BuType.title.copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, color: t.ink)),
          if (club != null && club.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: cid == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ClubDetailPage(session: widget.session, communityId: cid))),
                child: Text.rich(TextSpan(style: BuType.caption.copyWith(color: t.mut), children: [
                  TextSpan(text: '${l.eventFormOrganizedBy} '),
                  TextSpan(
                      text: club,
                      style: TextStyle(
                          fontWeight: cid == null ? FontWeight.w400 : FontWeight.w700,
                          color: cid == null ? t.mut : t.pr)),
                ])),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: BuCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(children: [
            if (starts != null)
              Et2InfoRow(
                icon: LucideIcons.calendarDays,
                title: _fmtDate(context, 'd MMMM y, EEEE', starts),
                sub: ends == null ? _hm(starts) : '${_hm(starts)} – ${_hm(ends)}',
              ),
            if (location != null && location.isNotEmpty)
              Et2InfoRow(icon: LucideIcons.mapPin, title: location, top: starts != null),
            if (cap != null)
              Et2InfoRow(
                icon: LucideIcons.users,
                title: full ? l.eventFormCapacityFull : l.eventFormCapacityCount(going.toString(), cap.toString()),
                sub: capSub,
                top: true,
              )
            else if (_approval)
              Et2InfoRow(
                icon: LucideIcons.users,
                title: l.etkinlik2PolicyApprovalTag,
                sub: closed ? l.eventFormRegsClosed : l.etkinlik2ApprovalByOrganizer,
                top: true,
              ),
          ]),
        ),
      ),
      if (desc != null && desc.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Text(desc, style: BuType.body.copyWith(fontSize: 14.5, height: 1.55, color: t.ink)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          if (_avatars.isNotEmpty) ...[
            _avatarStack(),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              interested != null
                  ? l.etkinlik2GoingInterested('$going', '$interested')
                  : l.etkinlik2GoingOnly('$going'),
              style: BuType.caption.copyWith(fontWeight: FontWeight.w600, color: t.mut),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (full && rsvp != 'GOING' && !_approval)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l.eventFormFullHint, style: BuType.caption.copyWith(color: t.danger)),
            ),
          if (_approval && !_manage && !cancelled) ...[
            _requestCard(),
            const SizedBox(height: 10),
          ],
          if (rsvp == 'GOING') ...[_attendanceBlock(), const SizedBox(height: 10)],
          if (!cancelled) _chatButton(),
          if (rsvp == 'GOING' || rsvp == 'INTERESTED') ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _rsvpBusy ? null : _leave,
                child: Text(l.eventFormManageJoin, style: BuType.label.copyWith(color: t.mut)),
              ),
            ),
          ],
          if (_manage) ...[
            const SizedBox(height: 18),
            _manageBlock(),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    ];
  }

  /// Etkinlik sohbeti: açık (herkese açıkta herkes; istek ile katılımda yalnız üye/organizatör) ya da kilitli.
  Widget _chatButton() {
    final l = context.l10n;
    final member = _rsvp == 'GOING' || _manage;
    if (_approval && !member) {
      return Et2GhostButton(
        key: const ValueKey('et2-chat-locked'),
        label: l.etkinlik2ChatLocked,
        icon: LucideIcons.lock,
        locked: true,
      );
    }
    return Et2GhostButton(
      label: l.eventFormChat,
      icon: LucideIcons.messageCircle,
      busy: _chatBusy,
      onPressed: _openChat,
    );
  }

  Widget _circle(double s, double a) => Container(
      width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));

  List<Map<String, dynamic>> get _avatars => _list(_preview?['avatars']);

  Widget _avatarStack() {
    final shown = _avatars.take(8).toList();
    final total = (_preview?['goingCount'] as num?)?.toInt() ?? (_ev?['goingCount'] as num? ?? 0).toInt();
    final more = total - shown.length;
    final t = context.bu;
    const size = 30.0;
    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * 20 + (more > 0 ? 34 : 0),
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          PositionedDirectional(
            start: i * 20.0,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
              child: BuAvatar(
                  name: shown[i]['displayName'] as String?,
                  url: fileUrl(shown[i]['avatarUrl'] as String?),
                  size: size - 4),
            ),
          ),
        if (more > 0)
          PositionedDirectional(
            start: shown.length * 20.0 + 6,
            child: Container(
              height: size,
              alignment: Alignment.center,
              child: Text('+$more', style: BuType.label.copyWith(color: t.mut)),
            ),
          ),
      ]),
    );
  }

  Widget _attendanceBlock() {
    final t = context.bu;
    final att = _myAtt;
    if (att == null) return const SizedBox.shrink();
    if (att['present'] == true) {
      return Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(23)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.circleCheck, size: 16, color: t.ok),
          const SizedBox(width: 8),
          Text(context.l10n.eventFormCheckedIn, style: BuType.bodyStrong.copyWith(color: t.ok)),
        ]),
      );
    }
    if (att['checkInOpen'] != true) {
      return Text(context.l10n.eventFormCheckInLater, style: BuType.caption.copyWith(color: t.mut));
    }
    if (!_enterCode) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(label: context.l10n.eventFormScanQr, icon: LucideIcons.scanLine, busy: _checkBusy, onPressed: _scan),
        const SizedBox(height: 8),
        BuButton(
            label: context.l10n.eventFormEnterCode,
            icon: LucideIcons.qrCode,
            kind: BuButtonKind.outline,
            onPressed: () => setState(() => _enterCode = true)),
      ]);
    }
    return BuCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.l10n.eventFormEnterOrganizerCode,
            style: BuType.label.copyWith(color: t.ink)),
        const SizedBox(height: 10),
        TextField(
          controller: _codeCtl,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkIn(),
          style: BuType.bodyStrong.copyWith(color: t.ink),
          decoration: InputDecoration(
            hintText: context.l10n.eventFormCheckInCode,
            hintStyle: TextStyle(color: t.mut),
            filled: true,
            fillColor: t.sf2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        BuButton(label: context.l10n.eventFormSendCheckIn, busy: _checkBusy, onPressed: _checkIn),
      ]),
    );
  }

  Widget _manageBlock() {
    final t = context.bu;
    final l = context.l10n;
    final present = _attendance.where((r) => r['present'] == true).length;
    final total = _attendance.length;
    final pending = (_ev?['pendingCount'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.etkinlik2ManageSection, style: BuType.heading.copyWith(color: t.ink)),
      const SizedBox(height: 10),
      BuCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Et2NavRow(
            icon: LucideIcons.qrCode,
            title: l.eventFormCheckInCode,
            sub: total == 0 ? l.eventFormNoAttendance : l.etkinlik2PresentOf('$present', '$total'),
            onTap: _openQr,
          ),
          Et2NavRow(
            top: true,
            icon: LucideIcons.clipboardCheck,
            title: l.etkinlik2ManageAttendance,
            onTap: _openAttendance,
          ),
          if (_approval)
            Et2NavRow(
              top: true,
              icon: LucideIcons.userCheck,
              title: l.etkinlik2ManageRequests,
              sub: pending == 0 ? l.etkinlik2ManageNoPending : l.etkinlik2ManagePending('$pending'),
              badge: pending > 0 ? '$pending' : null,
              onTap: _openRequests,
            ),
          Et2NavRow(
            top: true,
            icon: LucideIcons.settings,
            title: l.etkinlik2ManageSettings,
            onTap: _openSettings,
          ),
        ]),
      ),
    ]);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.ok = false, this.warn = false});

  final String text;
  final bool ok;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: ok ? t.okSoft : (warn ? t.danger.withValues(alpha: .14) : t.soft),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: BuType.micro.copyWith(color: ok ? t.ok : (warn ? t.danger : t.onSoft))),
      ),
    );
  }
}
