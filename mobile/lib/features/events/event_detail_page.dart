import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_page.dart';
import '../../widgets/report_sheet.dart';
import '../clubs/club_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'qr_painter.dart';
import '../../core/typography.dart';

const _monthsShort = ['OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'];

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
  List<Map<String, dynamic>> _attendees = []; // yalnızca organizatör, sayfalı
  int? _attNext;
  bool _attBusy = false;
  Map<String, dynamic>? _myAtt;
  Map<String, dynamic>? _code;
  List<Map<String, dynamic>> _attendance = [];
  Timer? _codeTimer;

  bool _rsvpBusy = false;
  bool _codeBusy = false;
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
    _codeTimer?.cancel();
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
      setState(() {
        if (_ev == null || !refresh) _error = e;
        _loading = false;
      });
      if (refresh && _ev != null) _toast(errorText(e));
    }
  }

  bool get _manage => _ev?['canManage'] == true;
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
        final r = await api.get('$_path/attendees?size=20');
        if (mounted) {
          setState(() {
            _attendees = _list(r is Map ? r['items'] : null);
            _attNext = r is Map ? (r['nextCursor'] as num?)?.toInt() : null;
          });
        }
      } catch (_) {}
      try {
        final r = await api.get('$_path/attendance');
        if (mounted) setState(() => _attendance = _list(r));
      } catch (_) {}
      await _loadCode();
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

  Future<void> _moreAttendees() async {
    if (_attBusy || _attNext == null) return;
    setState(() => _attBusy = true);
    try {
      final r = await widget.session.api.get('$_path/attendees?size=20&cursor=$_attNext');
      if (!mounted) return;
      setState(() {
        _attendees = [..._attendees, ..._list(r is Map ? r['items'] : null)];
        _attNext = r is Map ? (r['nextCursor'] as num?)?.toInt() : null;
      });
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _attBusy = false);
    }
  }

  Future<void> _loadCode() async {
    if (!mounted) return; // _loadExtras'ın await'lerinden sonra sayfa kapanmış olabilir
    setState(() => _codeBusy = true);
    try {
      final r = await widget.session.api.get('$_path/checkin-code');
      if (!mounted) return;
      setState(() {
        _code = Map<String, dynamic>.from(r as Map);
      });
      _codeTimer?.cancel();
      // Kod kısa ömürlü: süresi dolmadan kendiliğinden yenilenir.
      final secs = ((_code?['validForSeconds'] as num?)?.toInt() ?? 30).clamp(10, 120);
      _codeTimer = Timer(Duration(seconds: secs > 5 ? secs - 3 : secs), () {
        if (mounted) _loadCode();
      });
    } catch (e) {
      if (mounted) _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _codeBusy = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _setRsvp(String status) async {
    if (_rsvpBusy) return;
    final ev = _ev!;
    final cap = (ev['capacity'] as num?)?.toInt();
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    if (status == 'GOING' && _rsvp != 'GOING' && cap != null && going >= cap) {
      _toast('Kontenjan doldu. "İlgileniyorum" ile takipte kalabilirsin.');
      return;
    }
    // İyimser güncelleme: sayaç ve durum hemen değişir, hata olursa geri alınır.
    final old = Map<String, dynamic>.from(ev);
    final next = _rsvp == status ? null : status;
    var g = going;
    if (_rsvp == 'GOING') g--;
    if (next == 'GOING') g++;
    var i = (ev['interestedCount'] as num?)?.toInt();
    if (i != null) {
      if (_rsvp == 'INTERESTED') i--;
      if (next == 'INTERESTED') i++;
    }
    setState(() {
      _rsvpBusy = true;
      _ev = {...ev, 'myRsvp': next, 'goingCount': g < 0 ? 0 : g, if (i != null) 'interestedCount': i < 0 ? 0 : i};
    });
    try {
      if (next == null) {
        await widget.session.api.delete('$_path/rsvp');
      } else {
        await widget.session.api.put('$_path/rsvp', {'status': status});
      }
      if (mounted) setState(() => _rsvpBusy = false);
      await _load(refresh: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ev = old;
          _rsvpBusy = false;
        });
      }
      _toast(errorText(e));
    }
  }

  Future<void> _checkIn() async {
    await _submitCode(_codeCtl.text);
  }

  /// QR ile tara; kod başka bir etkinliğe aitse uyar.
  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage(title: 'Yoklama QR kodunu tara')),
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
      _toast('Bu kod başka bir etkinliğe ait.');
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
      _toast('Yoklaman alındı');
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
      if (e.status == 404 || e.status == 405) {
        _toast('Etkinlik sohbeti yakında');
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
        BuHeader(title: 'Etkinlik', onBack: () => Navigator.pop(context)),
        const Expanded(child: EmptyView(icon: LucideIcons.calendarX, text: 'Etkinlik bulunamadı')),
      ]);
    } else if (_ev == null) {
      body = ErrorView(error: _error ?? 'hata', onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(padding: EdgeInsets.zero, children: _content(context)),
      );
    }
    return Scaffold(backgroundColor: t.bg, body: body);
  }

  List<Widget> _content(BuildContext context) {
    final t = context.bu;
    final ev = _ev!;
    final starts = DateTime.tryParse('${ev['startsAt']}')?.toLocal();
    final ends = DateTime.tryParse('${ev['endsAt']}')?.toLocal();
    final cover = fileUrl(ev['coverUrl'] as String?);
    final club = ev['communityName'] as String?;
    final organizer = (club != null && club.isNotEmpty) ? club : ev['organizerName'] as String?;
    final cid = (ev['communityId'] as num?)?.toInt();
    final location = ev['location'] as String?;
    final desc = ev['description'] as String?;
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    final interested = (ev['interestedCount'] as num?)?.toInt();
    final cap = (ev['capacity'] as num?)?.toInt();
    final full = cap != null && going >= cap;
    final rsvp = _rsvp;
    final pad = MediaQuery.of(context).padding;

    return [
      // Kapak / gradyan hero
      Container(
        height: 210 + pad.top * .3,
        decoration: BoxDecoration(
          gradient: cover == null ? t.hero : null,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          image: cover == null ? null : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            if (cover == null) ...[
              Positioned(
                  right: -40, top: -50, child: _circle(200, .15)),
              Positioned(left: 30, bottom: -70, child: _circle(160, .10)),
            ],
            Positioned(
              left: 20,
              top: pad.top + 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.arrowLeft, size: 22, color: Colors.white),
                ),
              ),
            ),
            if (!_manage)
              Positioned(
                right: 20,
                top: pad.top + 12,
                child: Semantics(
                  button: true,
                  label: 'Şikâyet et',
                  child: GestureDetector(
                    onTap: () => ReportSheet.show(context, widget.session,
                        targetType: 'EVENT', targetId: widget.eventId, title: 'Etkinliği şikâyet et'),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.flag, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (starts != null)
              Positioned(
                left: 20,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_monthsShort[starts.month - 1],
                        style: BuType.micro.copyWith(color: const Color(0xFF8E1B13))),
                    Text('${starts.day}',
                        style: BuType.display.copyWith(height: 1.1, color: const Color(0xFF8E1B13))),
                  ]),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (rsvp == 'GOING')
            const _Pill('Katılıyorsun', ok: true)
          else if (rsvp == 'INTERESTED')
            const _Pill('İlgileniyorsun'),
          if (rsvp != null) const SizedBox(height: 8),
          Text('${ev['title'] ?? ''}',
              style: BuType.display.copyWith(letterSpacing: -.4, height: 1.2, color: t.ink)),
          if (organizer != null && organizer.isNotEmpty)
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
                  const TextSpan(text: 'Düzenleyen: '),
                  TextSpan(
                      text: organizer,
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
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            if (starts != null)
              _InfoRow(
                icon: LucideIcons.calendarDays,
                title: '${starts.day} ${_monthName(starts.month)} ${starts.year}, ${_weekday(starts.weekday)}',
                sub: ends == null ? _hm(starts) : '${_hm(starts)} – ${_hm(ends)}',
              ),
            if (location != null && location.isNotEmpty)
              _InfoRow(icon: LucideIcons.mapPin, title: location, sub: null, top: starts != null),
            if (cap != null)
              _InfoRow(
                icon: LucideIcons.users,
                title: full ? 'Kontenjan doldu' : 'Kontenjan: $going / $cap',
                sub: null,
                top: true,
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          if (_avatars.isNotEmpty) ...[
            _avatarStack(),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text.rich(TextSpan(style: BuType.caption.copyWith(color: t.mut), children: [
              TextSpan(text: '$going', style: TextStyle(fontWeight: FontWeight.w800, color: t.ink)),
              const TextSpan(text: ' katılıyor'),
              if (interested != null) ...[
                const TextSpan(text: ' · '),
                TextSpan(text: '$interested', style: TextStyle(fontWeight: FontWeight.w800, color: t.ink)),
                const TextSpan(text: ' ilgileniyor'),
              ],
            ])),
          ),
        ]),
      ),
      if (desc != null && desc.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Text(desc, style: BuType.body.copyWith(height: 1.55, color: t.ink)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Dar ekranda (320 dp) iki ikonlu düğme yan yana sığmaz: alt alta dizilir.
          LayoutBuilder(builder: (context, box) {
            final going = BuButton(
              label: rsvp == 'GOING' ? 'Katılıyorsun' : 'Katılıyorum',
              icon: LucideIcons.check,
              kind: rsvp == 'GOING' ? BuButtonKind.primary : BuButtonKind.soft,
              busy: _rsvpBusy,
              onPressed: () => _setRsvp('GOING'),
            );
            final interested = BuButton(
              label: rsvp == 'INTERESTED' ? 'İlgileniyorsun' : 'İlgileniyorum',
              icon: LucideIcons.star,
              kind: rsvp == 'INTERESTED' ? BuButtonKind.primary : BuButtonKind.outline,
              onPressed: _rsvpBusy ? null : () => _setRsvp('INTERESTED'),
            );
            if (box.maxWidth < 380) {
              return Column(children: [going, const SizedBox(height: 10), interested]);
            }
            return Row(children: [
              Expanded(child: going),
              const SizedBox(width: 10),
              Expanded(child: interested),
            ]);
          }),
          if (full && rsvp != 'GOING')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Kontenjan doldu; yine de ilgilendiğini belirtebilirsin.',
                  style: BuType.caption.copyWith(color: t.danger)),
            ),
          if (rsvp == 'GOING') ...[const SizedBox(height: 10), _attendanceBlock()],
          if (rsvp != null) ...[
            const SizedBox(height: 10),
            BuButton(
              label: 'Etkinlik sohbeti',
              icon: LucideIcons.messageCircle,
              kind: BuButtonKind.outline,
              busy: _chatBusy,
              onPressed: _openChat,
            ),
          ],
          if (_manage) ...[const SizedBox(height: 18), _manageBlock()],
          const SizedBox(height: 32),
        ]),
      ),
    ];
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
          Positioned(
            left: i * 20.0,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
              child: BuAvatar(
                  name: shown[i]['displayName'] as String?,
                  url: fileUrl(shown[i]['avatarUrl'] as String?),
                  size: size - 4),
            ),
          ),
        if (more > 0)
          Positioned(
            left: shown.length * 20.0 + 6,
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
          Icon(LucideIcons.circleCheck, size: 18, color: t.ok),
          const SizedBox(width: 8),
          Text('Yoklaman alındı', style: BuType.bodyStrong.copyWith(color: t.ok)),
        ]),
      );
    }
    if (att['checkInOpen'] != true) {
      return Text('Yoklama etkinlik saatinde açılır.', style: BuType.caption.copyWith(color: t.mut));
    }
    if (!_enterCode) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(label: 'QR kodu tara', icon: LucideIcons.scanLine, busy: _checkBusy, onPressed: _scan),
        const SizedBox(height: 8),
        BuButton(
            label: 'Kodu elle gir',
            icon: LucideIcons.qrCode,
            kind: BuButtonKind.outline,
            onPressed: () => setState(() => _enterCode = true)),
      ]);
    }
    return BuCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Organizatörün gösterdiği kodu gir',
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
            hintText: 'Yoklama kodu',
            hintStyle: TextStyle(color: t.mut),
            filled: true,
            fillColor: t.sf2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        BuButton(label: 'Yoklamayı gönder', busy: _checkBusy, onPressed: _checkIn),
      ]),
    );
  }

  Widget _manageBlock() {
    final t = context.bu;
    final code = _code?['code'] as String?;
    final qr = _code?['qrPayload'] as String?;
    final exp = DateTime.tryParse('${_code?['expiresAt']}')?.toLocal();
    final present = _attendance.where((r) => r['present'] == true).length;
    final total = _attendance.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Yoklama kodu', style: BuType.heading.copyWith(color: t.ink)),
      const SizedBox(height: 10),
      BuCard(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          if (code == null)
            Text(_codeBusy ? 'Kod hazırlanıyor…' : 'Kod alınamadı.', style: TextStyle(color: t.mut))
          else ...[
            QrView(
              data: qr ?? code,
              size: 220,
              fallback: SelectableText(code,
                  textAlign: TextAlign.center,
                  style: BuType.bodyStrong.copyWith(color: t.pr)),
            ),
            const SizedBox(height: 8),
            Text('Katılımcılar bu QR kodunu uygulamadan taratır.',
                textAlign: TextAlign.center, style: BuType.caption.copyWith(color: t.mut)),
            const SizedBox(height: 6),
            Text(
              exp == null
                  ? 'Kod kısa süre geçerlidir.'
                  : 'Son kullanma: ${_hms(exp)} · kod otomatik yenilenir',
              style: BuType.caption.copyWith(color: t.mut),
            ),
          ],
          const SizedBox(height: 12),
          BuButton(
            label: 'Kodu yenile',
            icon: LucideIcons.refreshCw,
            kind: BuButtonKind.soft,
            compact: true,
            busy: _codeBusy,
            onPressed: _loadCode,
          ),
        ]),
      ),
      const SizedBox(height: 10),
      BuCard(
        child: Row(children: [
          Icon(LucideIcons.clipboardCheck, size: 20, color: t.onSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              total == 0 ? 'Henüz yoklama kaydı yok' : 'Yoklama: $present / $total kişi geldi',
              style: BuType.bodyStrong.copyWith(color: t.ink),
            ),
          ),
        ]),
      ),
      if (_attendees.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Katılımcılar', style: BuType.heading.copyWith(color: t.ink)),
        const SizedBox(height: 10),
        for (final a in _attendees)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              BuAvatar(name: a['displayName'] as String?, url: fileUrl(a['avatarUrl'] as String?), size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${a['displayName'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(color: t.ink)),
              ),
              if (a['status'] == 'INTERESTED') Text('İlgileniyor', style: BuType.caption.copyWith(color: t.mut)),
            ]),
          ),
        if (_attNext != null)
          BuButton(
              label: 'Daha fazla göster',
              kind: BuButtonKind.soft,
              compact: true,
              busy: _attBusy,
              onPressed: _moreAttendees),
      ],
    ]);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  static String _hms(DateTime d) => '${_hm(d)}:${_two(d.second)}';
  static String _monthName(int m) => longDate(DateTime(2000, m, 1)).split(',').first.split(' ').last;
  static String _weekday(int w) => longDate(DateTime(2024, 1, w)).split(', ').last;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.ok = false});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: ok ? t.okSoft : t.soft, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: BuType.micro.copyWith(color: ok ? t.ok : t.onSoft)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.sub, this.top = false});

  final IconData icon;
  final String title;
  final String? sub;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, size: 20, color: t.onSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BuType.bodyStrong.copyWith(color: t.ink)),
            if (sub != null) Text(sub!, style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
      ]),
    );
  }
}
