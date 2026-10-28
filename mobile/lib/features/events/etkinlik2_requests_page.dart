import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'etkinlik2_widgets.dart';

/// Katılım istekleri (organizatör): kontenjan sayacı, doluysa uyarı bandı, bekleyenler Onayla/Reddet,
/// yanıtlananlar. Sayfa bir karar verildiyse `true` ile kapanır (detay yenilensin).
class Etkinlik2RequestsPage extends StatefulWidget {
  const Etkinlik2RequestsPage({super.key, required this.session, required this.event});

  final Session session;
  final Map<String, dynamic> event;

  @override
  State<Etkinlik2RequestsPage> createState() => _Etkinlik2RequestsPageState();
}

class _Etkinlik2RequestsPageState extends State<Etkinlik2RequestsPage> {
  final _pending = <Map<String, dynamic>>[];
  final _answered = <Map<String, dynamic>>[];
  int? _pendingNext;
  int? _going;
  int? _cap;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  bool _changed = false;
  final _busy = <int>{};

  int get _id => (widget.event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _going = (widget.event['goingCount'] as num?)?.toInt();
    _cap = (widget.event['capacity'] as num?)?.toInt();
    _load();
  }

  List<Map<String, dynamic>> _items(dynamic r) =>
      ((r is Map ? r['items'] : null) as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = widget.session.api;
    try {
      final p = await api.get('/events/$_id/requests?status=PENDING&size=50');
      List<Map<String, dynamic>> ok = [], no = [];
      try {
        ok = _items(await api.get('/events/$_id/requests?status=ACCEPTED&size=50'));
        no = _items(await api.get('/events/$_id/requests?status=REJECTED&size=50'));
      } catch (_) {}
      await _refreshCounts();
      if (!mounted) return;
      setState(() {
        _pending
          ..clear()
          ..addAll(_items(p));
        _pendingNext = p is Map ? (p['nextCursor'] as num?)?.toInt() : null;
        _answered
          ..clear()
          ..addAll([
            for (final a in ok) {...a, 'status': 'ACCEPTED'},
            for (final a in no) {...a, 'status': 'REJECTED'},
          ]);
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

  Future<void> _refreshCounts() async {
    try {
      final r = await widget.session.api.get('/events/$_id');
      if (r is Map && mounted) {
        setState(() {
          _going = (r['goingCount'] as num?)?.toInt() ?? _going;
          _cap = (r['capacity'] as num?)?.toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_more || _pendingNext == null) return;
    setState(() => _more = true);
    try {
      final r = await widget.session.api.get('/events/$_id/requests?status=PENDING&size=50&cursor=$_pendingNext');
      if (!mounted) return;
      setState(() {
        _pending.addAll(_items(r));
        _pendingNext = r is Map ? (r['nextCursor'] as num?)?.toInt() : null;
      });
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  int _uid(Map<String, dynamic> a) => (a['userId'] as num).toInt();

  Future<void> _decide(Map<String, dynamic> a, bool approve) async {
    final uid = _uid(a);
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      final path = '/events/$_id/requests/$uid/${approve ? 'approve' : 'reject'}';
      await widget.session.api.post(path, approve ? <String, dynamic>{} : <String, dynamic>{});
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((x) => _uid(x) == uid);
        _answered.insert(0, {...a, 'status': approve ? 'ACCEPTED' : 'REJECTED'});
        _changed = true;
        if (approve && _going != null) _going = _going! + 1;
      });
      _toast(approve ? context.l10n.etkinlik2ApprovedToast : context.l10n.etkinlik2RejectedToast);
      _refreshCounts();
    } catch (e) {
      // EVENT_FULL vb.: istek bekleyen kalır.
      _toast(errorText(e));
      if (e is ApiError && e.code == 'EVENT_FULL') _refreshCounts();
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final cap = _cap;
    final going = _going ?? 0;
    final full = cap != null && going >= cap;
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
          BuCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(
                  child: Text(l.etkinlik2ReqQuota,
                      style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ),
                Text(cap == null ? '$going' : '$going / $cap',
                    key: const ValueKey('et2-quota'),
                    style: BuType.title.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              ]),
              if (cap != null) ...[
                const SizedBox(height: 8),
                Et2Progress(fraction: cap == 0 ? 1 : going / cap),
              ],
              const SizedBox(height: 6),
              Text(cap == null ? l.etkinlik2ReqNoLimit : l.etkinlik2ReqSlotsLeft('${(cap - going).clamp(0, cap)}'),
                  style: BuType.caption.copyWith(color: t.mut)),
            ]),
          ),
          if (full) ...[
            const SizedBox(height: 10),
            Et2Banner(
              key: const ValueKey('et2-full-banner'),
              icon: LucideIcons.triangleAlert,
              text: l.etkinlik2ReqFullBanner,
            ),
          ],
          Et2Label(l.etkinlik2ReqPendingHeader('${_pending.length}')),
          if (_pending.isEmpty)
            BuCard(
              child: Text(l.etkinlik2ReqNone, style: BuType.body.copyWith(color: t.mut)),
            )
          else
            BuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < _pending.length; i++) _pendingRow(_pending[i], top: i > 0),
              ]),
            ),
          if (_pendingNext != null) ...[
            const SizedBox(height: 10),
            BuButton(
                label: l.eventFormShowMore, kind: BuButtonKind.soft, compact: true, busy: _more, onPressed: _loadMore),
          ],
          if (_answered.isNotEmpty) ...[
            Et2Label(l.etkinlik2ReqAnsweredHeader),
            BuCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < _answered.length; i++) _answeredRow(_answered[i], top: i > 0),
              ]),
            ),
          ],
        ]),
      );
    }
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          BuHeader(
            title: l.etkinlik2ManageRequests,
            subtitle: '${widget.event['title'] ?? ''}',
            onBack: () => Navigator.pop(context, _changed),
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _who(Map<String, dynamic> a) {
    final t = context.bu;
    final note = a['note'] as String?;
    final sub = [
      if ((a['department'] as String?)?.isNotEmpty == true) a['department'] as String,
      if (note != null && note.trim().isNotEmpty) note.trim(),
    ].join(' · ');
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a['displayName'] ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
        if (sub.isNotEmpty)
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
      ]),
    );
  }

  Widget _pendingRow(Map<String, dynamic> a, {required bool top}) {
    final t = context.bu;
    final l = context.l10n;
    final name = '${a['displayName'] ?? ''}';
    final busy = _busy.contains(_uid(a));
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        BuAvatar(name: name, url: fileUrl(a['avatarUrl'] as String?), size: 40),
        const SizedBox(width: 10),
        _who(a),
        const SizedBox(width: 6),
        _action(
          key: ValueKey('et2-reject-${_uid(a)}'),
          label: l.etkinlik2Reject,
          sem: l.etkinlik2RejectSem(name),
          primary: false,
          onTap: busy ? null : () => _decide(a, false),
        ),
        const SizedBox(width: 6),
        _action(
          key: ValueKey('et2-approve-${_uid(a)}'),
          label: l.etkinlik2Approve,
          sem: l.etkinlik2ApproveSem(name),
          primary: true,
          onTap: busy ? null : () => _decide(a, true),
        ),
      ]),
    );
  }

  Widget _action({
    required Key key,
    required String label,
    required String sem,
    required bool primary,
    required VoidCallback? onTap,
  }) {
    final t = context.bu;
    return Semantics(
      key: key,
      button: true,
      enabled: onTap != null,
      label: sem,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: primary ? t.pr : t.sf,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: primary ? null : Border.all(color: t.bd, width: 1.5),
            ),
            child: Text(label,
                maxLines: 1,
                style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: primary ? t.onPr : t.ink)),
          ),
        ),
      ),
    );
  }

  Widget _answeredRow(Map<String, dynamic> a, {required bool top}) {
    final t = context.bu;
    final l = context.l10n;
    final ok = a['status'] == 'ACCEPTED';
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        BuAvatar(name: '${a['displayName'] ?? ''}', url: fileUrl(a['avatarUrl'] as String?), size: 40),
        const SizedBox(width: 10),
        _who(a),
        const SizedBox(width: 8),
        ok ? Et2Tag(l.etkinlik2ApprovedTag, dark: true) : Et2Tag(l.etkinlik2RejectedTag, muted: true),
      ]),
    );
  }
}
