import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'etkinlik2_attendance_page.dart';
import 'etkinlik2_widgets.dart';
import 'qr_painter.dart';

/// Organizatör yoklama kodu: QR + elle kod + yenilenme sayacı + "N / M kişi geldi".
/// Kod kısa ömürlüdür; süresi dolmadan kendiliğinden yenilenir (sayfa kapanınca zamanlayıcılar iptal).
class Etkinlik2QrPage extends StatefulWidget {
  const Etkinlik2QrPage({super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

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
  int _validFor = 30;

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _loadCode();
    _loadCounts();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _expires != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final r = await widget.session.api.get('/events/$_id/attendance');
      if (!mounted || r is! List) return;
      setState(() {
        _total = r.length;
        _present = r.whereType<Map>().where((e) => e['present'] == true).length;
      });
    } catch (_) {}
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
        _validFor = secs;
        _expires = DateTime.now().add(Duration(seconds: secs));
      });
      _refresh?.cancel();
      _refresh = Timer(Duration(seconds: secs > 5 ? secs - 3 : secs), () {
        if (mounted) {
          _loadCode();
          _loadCounts();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _failed = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Etkinlik2AttendancePage(session: widget.session, event: widget.event, fromQr: true)),
    );
    if (mounted) _loadCounts();
  }

  int get _secsLeft {
    final e = _expires;
    if (e == null) return 0;
    final s = e.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final code = _code?['code'] as String?;
    final qr = _code?['qrPayload'] as String?;
    final starts = DateTime.tryParse('${widget.event['startsAt']}')?.toLocal();
    final loc = widget.event['location'] as String?;
    final sub = [
      if (starts != null) '${starts.day}.${starts.month.toString().padLeft(2, '0')} · ${_hm(starts)}',
      if (loc != null && loc.isNotEmpty) loc,
    ].join(' · ');
    final left = _secsLeft;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.eventFormCheckInCode, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 16), children: [
            Text('${widget.event['title'] ?? ''}', style: BuType.bodyStrong.copyWith(color: t.ink)),
            if (sub.isNotEmpty) Text(sub, style: BuType.caption.copyWith(color: t.mut)),
            const SizedBox(height: 16),
            BuCard(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(children: [
                if (code == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(_busy ? l.eventFormCodePreparing : (_failed ?? l.eventFormCodeFailed),
                        textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.bd),
                    ),
                    child: Semantics(
                      label: l.eventFormCheckInCode,
                      child: QrView(
                        data: qr ?? code,
                        size: 200,
                        fallback: SelectableText(code,
                            textAlign: TextAlign.center, style: BuType.bodyStrong.copyWith(color: t.pr)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.etkinlik2QrManualCaption,
                      textAlign: TextAlign.center,
                      style: BuType.caption.copyWith(fontWeight: FontWeight.w700, color: t.mut, letterSpacing: .6)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      code,
                      style: BuType.display.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: t.ink,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.clock, size: 16, color: t.onSoft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(l.etkinlik2QrRenewsIn('$left'),
                            style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Et2Progress(fraction: _validFor == 0 ? 0 : left / _validFor, height: 6),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text('${l.eventFormQrHelp} ${l.eventFormCodeShortLived}',
                  textAlign: TextAlign.center, style: BuType.caption.copyWith(height: 1.45, color: t.mut)),
            ),
          ]),
        ),
        Et2BottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.etkinlik2AttendanceLabel, style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              Flexible(
                child: Text(l.etkinlik2PresentOf('$_present', '$_total'),
                    key: const ValueKey('et2-present-count'),
                    style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: BuButton(
                  label: l.eventFormRefreshCode,
                  icon: LucideIcons.refreshCw,
                  busy: _busy,
                  onPressed: _busy ? null : _loadCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BuButton(label: l.eventFormAttendees, kind: BuButtonKind.outline, onPressed: _openList),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
