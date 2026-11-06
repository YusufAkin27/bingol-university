import '../../core/analytics.dart';
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
import '../clubs/club_ref_widgets.dart' show clubFill;
import '../clubs/clubs_widgets.dart' show ClubJoinButton, ClubOutlineButton, clubsInitials;
import '../platform/qr_scan_page.dart';
import 'checkin_input.dart';
import 'etkinlik2_apply_sheet.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_qr_page.dart';
import 'etkinlik3_moderators_page.dart';
import 'etkinlik3_my_qr_page.dart';
import 'etkinlik3_scan_page.dart';
import 'etkinlik2_requests_page.dart';
import 'etkinlik2_settings_page.dart';
import 'etkinlik2_widgets.dart';
import 'etkinlik_parts.dart';
import 'event_cover.dart';
import 'event_form_page.dart';
import 'event_parts.dart';
import 'events_page.dart';
import '../share/share_button.dart' show ShareIconButton, shareContentForEvent;
import '../share/share_sheet.dart' show showShareSheet;

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
  const EventDetailPage({super.key, required this.session, required this.eventId, this.autoScan = false});

  final Session session;
  final int eventId;

  /// Bildirim "QR ile Giriş" düğmesi: yoklama açıksa ve katılımcıysa QR tarayıcı kendiliğinden açılır.
  final bool autoScan;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? _ev;
  Object? _error;
  bool _loading = true;

  Map<String, dynamic>? _myAtt;
  List<Map<String, dynamic>> _attendance = []; // yalnızca organizatör: özet sayısı için

  bool _attOpen = false; // sahip yoklamayı açtı mı (my-permissions)
  bool _attOpenBusy = false;
  List<String> _perms = const []; // moderatörün bu etkinlikteki yetkileri (sahipte boş)
  bool _rsvpBusy = false;
  bool _chatBusy = false;
  bool _checkBusy = false;
  bool _enterCode = false;
  bool _autoScanned = false;
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
      MaterialPageRoute(settings: const RouteSettings(name: 'event_form'), builder: (_) => EventFormPage(session: widget.session, event: _ev)),
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
    try {
      final r = await api.get('$_path/my-permissions');
      if (mounted && r is Map) {
        setState(() {
          _attOpen = r['attendanceOpen'] == true;
          _perms = r['owner'] == true ? const [] : [for (final p in (r['permissions'] as List? ?? const [])) '$p'];
        });
      }
    } catch (_) {}
    if (_rsvp == 'GOING') {
      try {
        final r = await api.get('$_path/my-attendance');
        if (mounted) setState(() => _myAtt = Map<String, dynamic>.from(r as Map));
        final att = _myAtt;
        if (mounted && widget.autoScan && !_autoScanned && att != null && att['checkInOpen'] == true && att['present'] != true) {
          _autoScanned = true;
          unawaited(_scan());
        }
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
      Analytics.instance.action('rsvp', target: status.toLowerCase());
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
      Analytics.instance.action('rsvp', target: 'apply');
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
      MaterialPageRoute(settings: const RouteSettings(name: 'events'), builder: (_) => EventsPage(session: widget.session, initialTab: 1)),
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
      icon: withdraw ? BuIcons.undo2 : BuIcons.calendarX,
    );
    if (!ok || !mounted) return;
    setState(() => _rsvpBusy = true);
    try {
      await widget.session.api.delete('$_path/rsvp');
      Analytics.instance.action('rsvp', target: 'cancel');
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
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_settings'), builder: (_) => Etkinlik2SettingsPage(session: widget.session, event: _ev!)),
    );
    if (r != null && mounted) _load(refresh: true);
  }

  Future<void> _openRequests() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_requests'), builder: (_) => Etkinlik2RequestsPage(session: widget.session, event: _ev!)),
    );
    if (mounted) _load(refresh: true);
  }

  Future<void> _openQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_qr'), builder: (_) => Etkinlik2QrPage(session: widget.session, event: _ev!)),
    );
    if (mounted) _loadExtras();
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik3_scan'), builder: (_) => Etkinlik3ScanPage(session: widget.session, event: _ev!)),
    );
    if (mounted) _loadExtras();
  }

  bool get _isMod => !_manage && _perms.isNotEmpty;

  Future<void> _openModerators() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik3_moderators'), builder: (_) => Etkinlik3ModeratorsPage(session: widget.session, event: _ev!)),
    );
  }

  /// Moderatör: yalnız kendisine verilen yetkilerin eylemleri görünür; sahip-özel eylemler (kapatma, iptal,
  /// yoklamayı açıp kapatma, moderatör yönetimi) hiç çizilmez.
  Widget _moderatorBlock() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final rows = <Widget>[];
    void add(Widget w) => rows.add(w);
    final pending = (_ev?['pendingCount'] as num?)?.toInt() ?? 0;
    if (_perms.contains('TAKE_ATTENDANCE')) {
      add(_attOpen
          ? Et2NavRow(key: const ValueKey('detail-mod-scan'), icon: BuIcons.qrCode, title: l.evtQrScanTitle, sub: l.evtPermTakeAttendanceSub, top: rows.isNotEmpty, onTap: _openScanner)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.evtAttClosedNote, key: const ValueKey('detail-mod-closed'), style: tx.bodyMedium!.copyWith(color: t.mut)),
            ));
    }
    if (_perms.contains('VIEW_ATTENDEES') || _perms.contains('TAKE_ATTENDANCE')) {
      add(Et2NavRow(key: const ValueKey('detail-mod-list'), icon: BuIcons.clipboardCheck, title: l.etkinlik2ManageAttendance, sub: l.evtPermViewAttendeesSub, top: rows.isNotEmpty, onTap: _openAttendance));
    }
    if (_perms.contains('MANAGE_REQUESTS') && _approval) {
      add(Et2NavRow(
          key: const ValueKey('detail-mod-requests'),
          icon: BuIcons.userCheck,
          title: l.etkinlik2ManageRequests,
          sub: pending == 0 ? l.etkinlik2ManageNoPending : l.etkinlik2ManagePending('$pending'),
          top: rows.isNotEmpty,
          onTap: _openRequests));
    }
    return BuCard(
      key: const ValueKey('detail-mod-block'),
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(l.evtModManageTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        ),
        if (rows.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.evtModManageNone, style: tx.bodyMedium!.copyWith(color: t.mut))) else ...rows,
      ]),
    );
  }

  Future<void> _openMyQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik3_my_qr'), builder: (_) => Etkinlik3MyQrPage(session: widget.session, event: _ev!)),
    );
  }

  /// Yoklamayı aç/kapat (yalnız sahip). Açıkken katılımcılar kişisel QR'ını gösterir, sahip/moderatör okutur.
  Future<void> _toggleAttendanceOpen(bool open) async {
    if (_attOpenBusy) return;
    setState(() {
      _attOpenBusy = true;
      _attOpen = open;
    });
    try {
      await widget.session.api.put('$_path/attendance-open', {'open': open});
    } catch (e) {
      if (mounted) setState(() => _attOpen = !open);
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _attOpenBusy = false);
    }
  }

  Future<void> _openAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'etkinlik2_attendance'), builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: _ev!)),
    );
    if (mounted) _loadExtras();
  }

  /// QR tarayıcı sayfasındaki doğrulama kancası: hata metni dönerse sayfada kalır, null = yoklama alındı.
  Future<String?> _verifyScanned(String raw) async {
    final l = context.l10n;
    final input = CheckinInput.parse(raw);
    if (input == null) return l.eventListNotCode;
    // Uzun jeton etkinlik kimliğini taşır (başka etkinliğin QR'ı istemcide elenir); kısa elle kod bu sayfanın etkinliğine yazılır.
    if (!input.isShort && input.eventId != widget.eventId) return l.eventFormWrongEventCode;
    final code = input.code;
    try {
      final r = await widget.session.api.post('$_path/check-in', {'code': code});
      Analytics.instance.action('checkin', target: 'qr');
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
      MaterialPageRoute(settings: const RouteSettings(name: 'qr_scan'), builder: (_) => QrScanPage(title: context.l10n.eventFormScanTitle, onSubmit: _verifyScanned)),
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
        MaterialPageRoute(settings: const RouteSettings(name: 'chat_detail'), 
          builder: (_) => ChatDetailPage(session: widget.session, conversation: Map<String, dynamic>.from(r as Map)),
        ),
      );
    } catch (e) {
      // Sohbet ucu vardır: 404/403 gerçek durumu (etkinlik gizli, katılım şartı vb.) sunucu mesajıyla söyler; "yakında" yedeği yoktur.
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
        Expanded(child: EmptyView(icon: BuIcons.calendarX, text: l.eventFormNotFound)),
      ]);
    } else if (_ev == null) {
      body = ErrorView(error: _error ?? 'hata', onRetry: _load);
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: Analytics.pullRefresh(() => _load(refresh: true)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              backgroundColor: t.bg,
              scrolledUnderElevation: 0,
              title: Semantics(header: true, label: l.eventFormEventTitle, child: const SizedBox.shrink()),
              actions: [_shareAction(), _menu(), const SizedBox(width: 4)],
            ),
            SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(context)),
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

  /// Sağ üst Paylaş: yalnız yayında (iptal/inceleme/ret dışı) etkinliklerde; kişiye mesajla, bağlantı, diğer uygulamalar.
  Widget _shareAction() {
    final ev = _ev;
    if (ev == null || eventIsCancelled(ev) || eventIsPendingReview(ev) || eventIsRejected(ev)) return const SizedBox.shrink();
    return ShareIconButton(
      key: const ValueKey('event-share'),
      onTap: () => showShareSheet(context, widget.session, shareContentForEvent({...ev, 'id': widget.eventId})),
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
        icon: Icon(BuIcons.ellipsisVertical, color: t.ink),
        onSelected: _manageAction,
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(BuIcons.pencil, size: 18, color: t.ink), const SizedBox(width: 12), Text(l.eventFormEdit)])),
          PopupMenuItem(
              value: 'settings',
              child: Row(children: [Icon(BuIcons.settings, size: 18, color: t.ink), const SizedBox(width: 12), Text(l.etkinlik2ManageSettings)])),
          PopupMenuItem(
              value: closed ? 'reopen' : 'close',
              child: Row(children: [
                Icon(closed ? BuIcons.lockOpen : BuIcons.lock, size: 18, color: t.ink),
                const SizedBox(width: 12),
                Text(closed ? l.eventFormReopenRegs : l.eventFormCloseRegs),
              ])),
          const PopupMenuDivider(),
          PopupMenuItem(
              value: 'cancel',
              child: Row(children: [
                Icon(BuIcons.trash2, size: 18, color: t.danger),
                const SizedBox(width: 12),
                Text(l.eventFormCancelAction, style: TextStyle(color: t.danger, fontWeight: FontWeight.w400)),
              ])),
        ],
      );
    }
    if (_manage) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: l.eventFormReport,
      icon: Icon(BuIcons.ellipsisVertical, color: t.ink),
      onSelected: (_) => _report(),
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'report',
            child: Row(children: [Icon(BuIcons.flag, size: 18, color: t.danger), const SizedBox(width: 12), Text(l.eventFormReportEvent)])),
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

  /// Yoklama açıkken "QR ile yoklama ver" + muted "Kodu elle gir" (katılan herkes için; açık ve onaylı etkinlik).
  Widget _checkInButtons() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BuButton(key: const ValueKey('detail-scan'), label: l.p51EvScanQr, onPressed: _scan),
      Center(
        child: TextButton(
          key: const ValueKey('detail-enter-code'),
          style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48)),
          onPressed: () => setState(() => _enterCode = !_enterCode),
          child: Text(l.eventFormEnterCode, style: tx.bodyLarge!.copyWith(color: t.mut)),
        ),
      ),
    ]);
  }

  /// Altta sabit eylem çubuğu (Stitch v3).
  /// Katılmadıysa: çerçeveli "İlgileniyorum" + marka dolgulu "Katıl". Katıldıysa: yoklama açıkken marka dolgulu
  /// "QR ile yoklama ver" + muted "Kodu elle gir"; en altta "Katılıyorsun" + küçük çerçeveli "Katılımdan ayrıl".
  Widget? _actionBar() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    if (_approval) {
      // İstek reddedildiyse sayfa altında tam genişlik "Etkinlikleri keşfet" düğmesi.
      if (_rsvp == 'REJECTED' && !_manage) {
        return Et2BottomBar(
          child: BuButton(
            key: const ValueKey('et2-browse'),
            label: l.eventListDiscover,
            onPressed: () => Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'events'), builder: (_) => EventsPage(session: widget.session))),
          ),
        );
      }
      // Katılımı onaylanan kişi de yoklama verebilmeli: yoklama açıkken yalnız QR + elle kod düğmeleri
      // ("Katılımdan ayrıl" sayfa gövdesinde zaten var, çubukta tekrarlanmaz).
      final att = _myAtt;
      final canCheck = _rsvp == 'GOING' && att != null && att['checkInOpen'] == true && att['present'] != true;
      if (!canCheck) return null;
      return Et2BottomBar(child: _checkInButtons());
    }
    final ev = _ev!;
    final closed = eventIsClosed(ev);
    final cap = (ev['capacity'] as num?)?.toInt();
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    final rsvp = _rsvp;
    final full = cap != null && going >= cap && rsvp != 'GOING';
    if (rsvp == 'GOING') {
      final att = _myAtt;
      final canCheck = att != null && att['checkInOpen'] == true && att['present'] != true;
      return Et2BottomBar(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (canCheck) _checkInButtons(),
          Row(children: [
            Expanded(
              child: Row(children: [
                Flexible(child: Text(l.p51EvGoingYou, style: tx.bodyMedium!.copyWith(color: t.mut))),
                const SizedBox(width: 4),
                ExcludeSemantics(child: Icon(BuIcons.check, size: 16, color: t.ink)),
              ]),
            ),
            const SizedBox(width: 12),
            ClubJoinButton(key: const ValueKey('detail-leave'), label: l.eventFormLeaveTitle, busy: _rsvpBusy, onPressed: _rsvpBusy ? null : _leave),
          ]),
        ]),
      );
    }
    final interested = rsvp == 'INTERESTED';
    return Et2BottomBar(
      child: Row(children: [
        Expanded(
          flex: 4,
          child: KeyedSubtree(
            key: const ValueKey('detail-interested'),
            child: ClubOutlineButton(
              label: l.eventFormInterested,
              // Kayıtlar kapalıyken önceden ilgilenen kullanıcı ilgisini geri alabilir.
              onPressed: _rsvpBusy ? null : (interested ? _unInterested : (closed ? null : () => _join('INTERESTED'))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 7,
          child: BuButton(
            key: const ValueKey('detail-join'),
            label: l.eventFormJoin,
            busy: _rsvpBusy && !interested,
            onPressed: (_rsvpBusy || closed || full) ? null : () => _join('GOING'),
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
      Analytics.instance.action('rsvp', target: 'cancel');
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
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.mut.withValues(alpha: .18), shape: BoxShape.circle),
                child: Icon(BuIcons.hourglass, size: 22, color: t.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.etkinlik2RequestSent, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                Text(l.etkinlik2AwaitingReply, style: tx.bodyMedium!.copyWith(color: t.ink.withValues(alpha: .85))),
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
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
                child: Icon(BuIcons.x, size: 22, color: t.onPr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.etkinlik2RejectedTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.danger)),
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
      radius: 16,
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

  Widget _pad(Widget w, {double top = 0}) => Padding(padding: EdgeInsetsDirectional.fromSTEB(20, top, 20, 0), child: w);

  /// Etiket-değer satırı (ikonsuz): etiket muted solda, değer ink/600 sağda; altında ince ayraç.
  Widget _kv(String label, String value, {bool strike = false, Key? key}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tx.bodyLarge!.copyWith(color: t.mut)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              style: tx.bodyLarge!.copyWith(color: strike ? t.mut : t.ink, fontWeight: FontWeight.w400, decoration: strike ? TextDecoration.lineThrough : null)),
        ),
      ]),
    );
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
    final cap = (ev['capacity'] as num?)?.toInt();
    final rsvp = _rsvp;
    final full = cap != null && going >= cap && rsvp != 'GOING';
    final closed = eventIsClosed(ev);
    final cancelled = eventIsCancelled(ev);
    final pendingReview = eventIsPendingReview(ev);
    final rejected = eventIsRejected(ev);
    final member = rsvp == 'GOING' || _manage;
    final who = (club != null && club.isNotEmpty) ? club : orgName;

    // Kapak (Stitch v3): tam genişlik 180 dp düz zemin + silik büyük baş harf filigranı; fotoğraf varsa onu gösterir.
    final Widget cover0 = SizedBox(
      width: double.infinity,
      height: 180,
      child: Stack(fit: StackFit.expand, children: [
        if (cover != null)
          EventCoverImage(url: cover, cacheWidth: 1000)
        else ...[
          ColoredBox(color: t.sf2),
          Align(
            alignment: const Alignment(0, -.05),
            child: ExcludeSemantics(
              child: Text(clubsInitials(who.isEmpty ? '${ev['title'] ?? ''}' : who),
                  maxLines: 1,
                  style: TextStyle(fontFamily: BuType.family, fontSize: 88, fontWeight: FontWeight.w400, height: 1, color: t.ink.withValues(alpha: .08))),
            ),
          ),
        ],
        if (cancelled) Positioned.fill(child: ColoredBox(color: t.scrim.withValues(alpha: .4))),
        if (!cancelled && closed)
          PositionedDirectional(start: 12, top: 12, child: _OverlayChip(label: l.eventFormRegsClosed, icon: BuIcons.lock))
        else if (!cancelled && full)
          PositionedDirectional(start: 12, top: 12, child: _OverlayChip(label: l.eventFormCapacityFull, icon: BuIcons.ban, danger: true)),
      ]),
    );

    final rejectedRequest = _approval && !_manage && !cancelled && rsvp == 'REJECTED';
    final peopleText = cap != null ? l.p51EvPeople('$going / $cap') : l.p51EvPeople('$going');
    return [
      cover0,
      // Yoklama durumu (Stitch v3 04): kapağın hemen altında yeşil not; durum değişince solarak yer değiştirir.
      if (rsvp == 'GOING' && !cancelled) _pad(BuFadeThrough(duration: BuMotion.short, child: _attendanceBlock()), top: 16),
      _pad(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (who.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: cid != null,
                child: BuPressable(
                  onTap: cid == null
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'club_detail'), builder: (_) => ClubDetailPage(session: widget.session, communityId: cid))),
                  enabled: cid != null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: Text(
                          (club != null && club.isNotEmpty) ? club : '${l.etkinlik2Organizer}: $orgName',
                          style: tx.bodyMedium!.copyWith(color: cid == null ? t.mut : t.prText, fontWeight: BuType.emphasisWeight)),
                    ),
                  ),
                ),
              ),
            ),
          Text('${ev['title'] ?? ''}',
              style: BuType.display.copyWith(
                fontSize: 28,
                height: 1.25,
                color: cancelled ? t.mut : t.ink,
                decoration: cancelled ? TextDecoration.lineThrough : null,
              )),
          const SizedBox(height: 16),
          Container(height: 1, color: t.bd),
        ]),
        top: 20,
      ),
      if (rejectedRequest) _pad(_requestCard(), top: 12),
      _pad(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          if (starts != null) _kv(l.p51EvLblDate, _fmtDate(context, 'd MMMM EEEE', starts), strike: cancelled),
          if (starts != null) _kv(l.p51EvLblTime, ends == null ? _hm(starts) : '${_hm(starts)} – ${_hm(ends)}', strike: cancelled),
          if (location != null && location.isNotEmpty) _kv(l.p51EvLblPlace, location),
          if (!cancelled) _kv(l.p51EvLblAttendees, peopleText, key: const ValueKey('detail-attendees')),
          if (!cancelled && _approval) _kv(l.clubMgmtJoinLabel, l.etkinlik2PolicyApprovalTag),
          if (full && !_approval && !cancelled) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.eventFormFullHint, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut))),
        ]),
      ),
      if (cancelled)
        _pad(
          Container(
            key: const ValueKey('detail-cancelled'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.p15CancelledNotice, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.danger)),
              const SizedBox(height: 2),
              Text(l.p15CancelledBody, style: tx.bodyMedium!.copyWith(color: t.danger.withValues(alpha: .9))),
            ]),
          ),
          top: 12,
        ),
      if (pendingReview || rejected)
        _pad(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: pendingReview ? t.sf2 : t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pendingReview ? l.evcStatusPending : l.evcStatusRejected,
                  style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: pendingReview ? t.ink : t.danger)),
              if (pendingReview || eventRejectReason(ev) != null) ...[
                const SizedBox(height: 2),
                Text(pendingReview ? l.evcInfoReview : l.evcRejectReason(eventRejectReason(ev)!),
                    style: tx.bodySmall!.copyWith(height: 1.4, color: pendingReview ? t.ink : t.danger)),
              ],
            ]),
          ),
          top: 12,
        ),
      if (_manage && !cancelled) _pad(_manageBlock(), top: 12),
      if (_isMod && !cancelled) _pad(_moderatorBlock(), top: 12),
      if (_approval && !_manage && !cancelled && !pendingReview && !rejected && rsvp != 'GOING' && rsvp != 'REJECTED') _pad(_requestCard(), top: 12),
      if (!cancelled) _pad(_chatRow(member: member), top: 4),
      if (desc != null && desc.trim().isNotEmpty) _pad(Text(desc, style: tx.titleMedium!.copyWith(height: 1.6, color: t.ink, fontWeight: FontWeight.w400)), top: 24),
      if (_approval && rsvp == 'GOING' && !cancelled)
        _pad(Et2GreyButton(key: const ValueKey('detail-leave-approval'), label: l.eventFormLeaveTitle, icon: BuIcons.calendarX, onPressed: _rsvpBusy ? null : _leave), top: 16),
      const SizedBox(height: 24),
    ];
  }

  /// Etkinlik sohbeti: ikonsuz satır ("Etkinlik sohbeti  >"); kilitliyse muted + "Kilitli".
  Widget _chatRow({required bool member}) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    // Katılmamış kullanıcıya: istek ile katılımda ya da kayıtlar kapalıyken sohbet kilitli (sunucu da RSVP'siz 403 verir).
    final locked = !member && (_approval || eventIsClosed(_ev!));
    return Semantics(
      button: !locked,
      label: l.eventFormChat,
      excludeSemantics: true,
      onTap: locked || _chatBusy ? null : _openChat,
      child: Material(
        key: ValueKey(locked ? 'et2-chat-locked' : 'detail-chat'),
        color: t.bg,
        child: InkWell(
          onTap: locked || _chatBusy ? null : _openChat,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
            child: Row(children: [
              Expanded(child: Text(l.eventFormChat, style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, color: locked ? t.mut : t.ink))),
              if (locked)
                Text(l.p15LockedBadge, style: tx.bodySmall!.copyWith(color: t.mut))
              else if (_chatBusy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
            ]),
          ),
        ),
      ),
    );
  }

  /// Yoklama durumu (Stitch v3): açıkken yeşil "Yoklama açık" notu, alınınca yeşil onay notu; kod alanı "Kodu elle gir" ile açılır.
  Widget _attendanceBlock() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final att = _myAtt;
    if (att == null) return const SizedBox.shrink();
    Widget note(String text, {Key? key}) => Container(
          key: key,
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
          child: Text(text, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
        );
    if (att['present'] == true) {
      // Başarı onayı: not 0.9 -> 1 ölçekle yaylanarak belirir (tek seferlik).
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: BuMotion.of(context, BuMotion.long),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: .9 + .1 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
        child: note(l.eventFormCheckedIn, key: const ValueKey('detail-checked-in')),
      );
    }
    final open = att['checkInOpen'] == true;
    return Column(key: const ValueKey('detail-attendance'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (open) note(l.p51EvAttOpen) else Text(l.eventFormCheckInLater, style: tx.bodyMedium!.copyWith(color: t.mut)),
      if (_attOpen) ...[
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('detail-att-open-note'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
          child: Text(l.evtAttOpenYou, style: tx.bodyMedium!.copyWith(color: t.ink)),
        ),
        const SizedBox(height: 8),
        ClubOutlineButton(key: const ValueKey('detail-my-qr'), label: l.evtQrMyTitle, onPressed: _openMyQr),
      ],
      if (open && _enterCode) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(l.eventFormCheckInCode, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink))),
          Text(l.p15CodeChars('${_codeCtl.text.length}'), style: tx.labelSmall!.copyWith(color: t.mut)),
        ]),
        Text(l.eventFormEnterOrganizerCode, style: tx.bodySmall!.copyWith(color: t.mut)),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('detail-code-field'),
          controller: _codeCtl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_codeError != null) setState(() => _codeError = null);
          },
          onSubmitted: (_) => _checkIn(),
          textAlign: TextAlign.center,
          style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, letterSpacing: 2, color: t.ink),
          decoration: clubFill(context,
              hint: l.sistemuiQrManualHint,
              hasError: _codeError != null,
              suffixIcon: _codeCtl.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('detail-code-clear'),
                      tooltip: l.p15ClearField,
                      icon: Icon(BuIcons.x, size: 18, color: t.mut),
                      onPressed: () {
                        _codeCtl.clear();
                        if (_codeError != null) setState(() => _codeError = null);
                      },
                    )),
        ),
        if (_codeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(_codeError!, key: const ValueKey('detail-code-error'), style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: BuType.emphasisWeight)),
            ),
          ),
        const SizedBox(height: 12),
        BuButton(label: l.eventFormSendCheckIn, busy: _checkBusy, onPressed: _checkBusy ? null : _checkIn),
      ],
    ]);
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
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Et2IconBox(BuIcons.userCheck, size: 40, tint: t.tint(1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.p16QrStatusTitle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                Text(total == 0 ? l.eventFormNoAttendance : l.eventFormAttendanceCount('$present', '$total'),
                    key: const ValueKey('detail-att-summary'), style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Et2Progress(fraction: total == 0 ? 0 : present / total, height: 8),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('detail-att-open-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.evtAttOpenTitle, style: tx.bodyLarge!.copyWith(color: t.ink)),
            subtitle: Text(l.evtAttOpenSub, style: tx.bodySmall!.copyWith(color: t.mut)),
            value: _attOpen,
            onChanged: _attOpenBusy ? null : _toggleAttendanceOpen,
          ),
          const SizedBox(height: 8),
          EtkinlikActionButton(
            key: const ValueKey('detail-scan-qr'),
            label: l.evtQrScanTitle,
            icon: BuIcons.qrCode,
            onTap: _openScanner,
          ),
          const SizedBox(height: 8),
          EtkinlikActionButton(
            key: const ValueKey('detail-open-qr'),
            label: l.eventFormCheckInCode,
            icon: BuIcons.qrCode,
            onTap: _openQr,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      BuCard(
        radius: 16,
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l.etkinlik2ManageSection, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
            ),
          ),
          if (_approval)
            Et2NavRow(
              icon: BuIcons.userCheck,
              title: l.etkinlik2ManageRequests,
              sub: pending == 0 ? l.etkinlik2ManageNoPending : l.etkinlik2ManagePending('$pending'),
              badge: pending > 0 ? l.etkinlik2ManagePending('$pending') : null,
              onTap: _openRequests,
            ),
          Et2NavRow(
            top: _approval,
            icon: BuIcons.clipboardCheck,
            title: l.etkinlik2ManageAttendance,
            sub: total == 0 ? l.eventFormNoAttendance : l.eventFormAttendanceCount('$present', '$total'),
            onTap: _openAttendance,
          ),
          if ((_ev?['communityId'] as num?) != null)
            Et2NavRow(
              key: const ValueKey('detail-open-moderators'),
              top: true,
              icon: BuIcons.users,
              title: l.evtModTitle,
              sub: l.evtModSub,
              onTap: _openModerators,
            ),
          Et2NavRow(
            top: true,
            icon: BuIcons.settings,
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
    final bg = danger ? t.danger : t.sf.withValues(alpha: .95);
    final fg = danger ? t.onPr : t.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w400, color: fg)),
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
              const AspectRatio(aspectRatio: 16 / 9, child: BuSkeleton(radius: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
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
