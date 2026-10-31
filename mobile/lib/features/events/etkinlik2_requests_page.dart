import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_widgets.dart' show ClubPageHeader, ClubTextTabs, ClubsLogo;
import 'etkinlik2_settings_page.dart';
import 'etkinlik2_widgets.dart';
import '../../core/academic_catalog.dart';

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

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && !_loading) {
        _toast(errorText(e), error: true);
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
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
      _toast(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    BuToast.show(context, m, kind: error ? BuToastKind.error : BuToastKind.success);
  }

  int _uid(Map<String, dynamic> a) => (a['userId'] as num).toInt();

  Future<void> _decide(Map<String, dynamic> a, bool approve) async {
    final uid = _uid(a);
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      final path = '/events/$_id/requests/$uid/${approve ? 'approve' : 'reject'}';
      await widget.session.api.post(path, <String, dynamic>{});
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
      _toast(errorText(e), error: true);
      if (e is ApiError && e.code == 'EVENT_FULL') _refreshCounts();
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  int _tab = 0; // 0 Bekleyen, 1 Onaylanan, 2 Reddedilen

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final showError = _error != null;
    final approved = _answered.where((a) => a['status'] == 'ACCEPTED').toList();
    final rejected = _answered.where((a) => a['status'] == 'REJECTED').toList();
    final list = switch (_tab) { 0 => _pending, 1 => approved, _ => rejected };
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          ClubPageHeader(title: l.p51EvReqTitle),
          Expanded(
            child: BuSwapIn(
              loading: _loading,
              skeleton: const SingleChildScrollView(primary: false, physics: NeverScrollableScrollPhysics(), child: _RequestsSkeleton()),
              child: RefreshIndicator(
                onRefresh: () => _load(silent: true),
                child: BuStaggerScope(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _quotaLine(context),
                      const SizedBox(height: 16),
                      ClubTextTabs(
                        labels: [
                          '${l.p51EvTabPending} ${_pending.length}',
                          '${l.p51EvTabApproved} ${approved.length}',
                          '${l.p51EvTabRejected} ${rejected.length}',
                        ],
                        index: _tab,
                        hairlineInset: 20,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Et2ErrorRow(
                            key: const ValueKey('et2-req-error'),
                            title: l.p16ReqErrTitle,
                            sub: errorText(_error!),
                            retryLabel: l.commonRetry,
                            onRetry: _load,
                          ),
                        )
                      else ...[
                        if (list.isEmpty) _empty(context),
                        for (var i = 0; i < list.length; i++)
                          BuStaggerItem(index: i, child: _tab == 0 ? _pendingRow(context, list[i]) : _answeredRow(context, list[i])),
                        if (_tab == 0 && _pendingNext != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Center(child: BuButton(label: l.eventFormShowMore, kind: BuButtonKind.soft, compact: true, busy: _more, onPressed: _loadMore)),
                          ),
                        if (_cap != null) _quotaNote(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  bool get _full => _cap != null && (_going ?? 0) >= _cap!;

  /// "Kontenjanı artır": ayarlar sayfasını açar; dönüşte listeyi yeniler.
  Future<void> _raiseQuota() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Etkinlik2SettingsPage(
          session: widget.session,
          event: {...widget.event, 'goingCount': _going, 'capacity': _cap},
        ),
      ),
    );
    if (mounted) {
      _changed = true;
      _load(silent: true);
    }
  }

  /// "Kontenjan 40 · 31 onaylı" + sağda "9 boş yer" (nokta) ve ince marka çubuğu; sınırsızsa yalnız metin.
  Widget _quotaLine(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final cap = _cap;
    final going = _going ?? 0;
    if (cap == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Text('${l.etkinlik2Unlimited} · ${l.p51EvQuotaGoing('$going')}', key: const ValueKey('et2-quota'), style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
      );
    }
    final left = (cap - going).clamp(0, cap);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Directionality(
              textDirection: Directionality.of(context),
              child: Text(l.p51EvQuota('$cap', '$going'), key: const ValueKey('et2-quota'), style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
            ),
          ),
          ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: left == 0 ? t.danger : t.pr, shape: BoxShape.circle))),
          const SizedBox(width: 6),
          Text(l.etkinlik2ReqSlotsLeft('$left'), style: tx.bodySmall!.copyWith(color: t.mut)),
        ]),
        const SizedBox(height: 8),
        Et2Progress(fraction: cap == 0 ? 1 : going / cap, height: 6),
      ]),
    );
  }

  /// Amber not (ikonsuz): dolunca "Kontenjanı artır" bağlantısıyla.
  Widget _quotaNote(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Semantics(
        container: true,
        liveRegion: _full,
        child: Container(
          key: _full ? const ValueKey('et2-full-banner') : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_full ? l.p16ReqFullBody : l.p51EvQuotaNote, style: tx.bodyMedium!.copyWith(height: 1.4, color: t.onWarnSoft, fontWeight: FontWeight.w500)),
            if (_full)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
                onPressed: _raiseQuota,
                child: Text(l.p16ReqRaiseQuota, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.etkinlik2ReqNone, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
        const SizedBox(height: 4),
        Text(l.p16ReqEmptyBody, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        TextButton(
          key: const ValueKey('et2-req-back'),
          style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
          onPressed: () => Navigator.pop(context, _changed),
          child: Text(l.p16ReqBackToEvent, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  String _depClass(Map<String, dynamic> a) {
    final dep = context.departmentName((a['department'] as String?) ?? '', faculty: a['faculty'] as String?);
    final y = (a['classYear'] as num?)?.toInt();
    return [if (dep.isNotEmpty) dep, if (y != null && y > 0) context.l10n.profileGradeYear('$y')].join(' · ');
  }

  /// Bekleyen başvuru satırı (kartsız): baş harf dairesi, ad, muted bölüm · sınıf (tek satır), sağda muted "Reddet" + marka "Onayla".
  Widget _pendingRow(BuildContext context, Map<String, dynamic> a) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = '${a['displayName'] ?? ''}';
    final uid = _uid(a);
    final busy = _busy.contains(uid);
    final note = (a['note'] as String?)?.trim() ?? '';
    final sub = _depClass(a);
    final full = _full;
    Widget action(Key key, String label, String sem, Color color, VoidCallback? onTap) => Semantics(
          button: true,
          enabled: onTap != null,
          label: sem,
          excludeSemantics: true,
          onTap: onTap,
          child: BuPressable(
            key: key,
            onTap: onTap,
            haptic: BuHaptic.selection,
            enabled: onTap != null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Center(
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: onTap == null ? color.withValues(alpha: .4) : color)),
                ),
              ),
            ),
          ),
        );
    return Container(
      key: ValueKey('et2-req-$uid'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        ClubsLogo(name: name, id: uid, url: fileUrl(a['avatarUrl'] as String?), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w500, color: t.ink)),
              if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('"$note"', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontStyle: FontStyle.italic)),
                ),
            ]),
          ),
        ),
        action(ValueKey('et2-reject-$uid'), l.etkinlik2Reject, l.etkinlik2RejectSem(name), t.mut, busy ? null : () => _decide(a, false)),
        action(ValueKey('et2-approve-$uid'), l.etkinlik2Approve, l.etkinlik2ApproveSem(name), t.pr, (busy || full) ? null : () => _decide(a, true)),
      ]),
    );
  }

  Widget _answeredRow(BuildContext context, Map<String, dynamic> a) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final ok = a['status'] == 'ACCEPTED';
    final name = '${a['displayName'] ?? ''}';
    final sub = _depClass(a);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 12),
      child: Row(children: [
        ClubsLogo(name: name, id: _uid(a), url: fileUrl(a['avatarUrl'] as String?), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w500, color: t.ink)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(ok ? l.etkinlik2ApprovedTag : l.etkinlik2RejectedTag, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ok ? t.ok : t.danger)),
      ]),
    );
  }
}

/// İstekler sayfası iskeleti: kontenjan satırı + satır iskeletleri.
class _RequestsSkeleton extends StatelessWidget {
  const _RequestsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BuSkeleton.line(width: 180, height: 14),
          const SizedBox(height: 10),
          const BuSkeleton(height: 6, radius: 3),
          const SizedBox(height: 32),
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Row(children: [
                BuSkeleton.circle(40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton.line(width: 130),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 180, height: 10),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
