import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'etkinlik2_qr_page.dart';
import 'etkinlik2_widgets.dart';

enum _Filter { all, present, absent }

/// Katılımcılar ve yoklama (organizatör): özet, Hepsi/Geldi/Gelmedi süzgeci, elle yoklama anahtarı.
class Etkinlik2AttendancePage extends StatefulWidget {
  const Etkinlik2AttendancePage({super.key, required this.session, required this.event, this.fromQr = false});

  /// QR sayfasından açıldıysa QR düğmesi geri döner; değilse QR sayfasını açar.
  final bool fromQr;

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik2AttendancePage> createState() => _Etkinlik2AttendancePageState();
}

class _Etkinlik2AttendancePageState extends State<Etkinlik2AttendancePage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  Object? _error;
  _Filter _filter = _Filter.all;
  final _busy = <int>{};

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.session.api.get('/events/$_id/attendance');
      if (!mounted) return;
      setState(() {
        _rows = (r is List ? r : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  int _uid(Map<String, dynamic> r) => (r['userId'] as num).toInt();

  /// İyimser güncelleme; hata olursa geri alınır.
  Future<void> _mark(Map<String, dynamic> r, bool present) async {
    final id = _uid(r);
    if (_busy.contains(id)) return;
    final before = r['present'] == true;
    setState(() {
      _busy.add(id);
      r['present'] = present;
    });
    try {
      await widget.session.api.put('/events/$_id/attendance/$id', {'present': present});
    } catch (e) {
      if (!mounted) return;
      setState(() => r['present'] = before);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showQr() {
    if (widget.fromQr) {
      Navigator.pop(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Etkinlik2QrPage(session: widget.session, event: widget.event)));
    }
  }

  List<Map<String, dynamic>> get _shown => _rows.where((r) {
        final p = r['present'] == true;
        return switch (_filter) {
          _Filter.all => true,
          _Filter.present => p,
          _Filter.absent => !p,
        };
      }).toList();

  String _sub(Map<String, dynamic> r) {
    final l = context.l10n;
    final parts = <String>[];
    final dep = r['department'] as String?;
    if (dep != null && dep.isNotEmpty) parts.add(dep);
    if (r['present'] == true) {
      final m = r['method'];
      if (m == 'QR') parts.add(l.etkinlik2MethodQr);
      if (m == 'MANUAL') parts.add(l.etkinlik2MethodManual);
      final at = DateTime.tryParse('${r['markedAt']}')?.toLocal();
      if (m == 'QR' && at != null) {
        parts.add('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
      }
    }
    if ((widget.event['createdBy'] as num?)?.toInt() == _uid(r)) parts.add(l.etkinlik2Organizer);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final total = _rows.length;
    final present = _rows.where((r) => r['present'] == true).length;
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      final shown = _shown;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          BuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.etkinlik2AttendanceLabel,
                      style: BuType.caption.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                  Text(l.etkinlik2PresentOf('$present', '$total'),
                      key: const ValueKey('et2-att-summary'),
                      style: BuType.title.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                  const SizedBox(height: 8),
                  Et2Progress(fraction: total == 0 ? 0 : present / total, height: 6),
                ]),
              ),
              const SizedBox(width: 14),
              Semantics(
                button: true,
                label: l.etkinlik2ShowQrSem,
                excludeSemantics: true,
                onTap: _showQr,
                child: Material(
                  color: t.soft,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showQr,
                    child: SizedBox(width: 48, height: 48, child: Icon(LucideIcons.qrCode, size: 22, color: t.pr)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(l.etkinlik2FilterAll, _Filter.all),
            _chip(l.etkinlik2FilterPresent, _Filter.present),
            _chip(l.etkinlik2FilterAbsent, _Filter.absent),
          ]),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(l.etkinlik2AttendanceEmpty, style: BuType.body.copyWith(color: t.mut))),
            )
          else
            BuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < shown.length; i++) _row(shown[i], top: i > 0),
              ]),
            ),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.eventFormAttendees, onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }

  Widget _chip(String label, _Filter f) {
    final t = context.bu;
    final on = _filter == f;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: () => setState(() => _filter = f),
      child: Material(
        color: on ? t.pr : t.sf,
        shape: StadiumBorder(side: BorderSide(color: on ? t.pr : t.bd, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _filter = f),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(label,
                style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: on ? t.onPr : t.ink)),
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> r, {required bool top}) {
    final t = context.bu;
    final name = '${r['displayName'] ?? ''}';
    final sub = _sub(r);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 10, bottom: 10),
      child: Row(children: [
        BuAvatar(name: name, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
            if (sub.isNotEmpty)
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
        Et2Toggle(
          key: ValueKey('et2-mark-${_uid(r)}'),
          value: r['present'] == true,
          label: context.l10n.etkinlik2MarkSem(name),
          onChanged: _busy.contains(_uid(r)) ? null : (v) => _mark(r, v),
        ),
      ]),
    );
  }
}
