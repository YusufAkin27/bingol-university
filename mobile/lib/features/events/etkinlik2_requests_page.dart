import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = _loading
        ? BuViewState.loading
        : _error != null
            ? BuViewState.error
            : BuViewState.ready;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuStaggerScope(
        child: BuPageScaffold(
          title: l.etkinlik2ManageRequests,
          state: state,
          error: _error,
          onRetry: _load,
          onRefresh: () => _load(silent: true),
          loading: const _RequestsSkeleton(),
          bottomInset: 32,
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
              sliver: SliverList.list(children: [
                Et2EventStrip(event: widget.event),
                const SizedBox(height: 12),
                _quotaCard(context),
                if (_full) ...[
                  const SizedBox(height: 12),
                  Et2Banner(
                    key: const ValueKey('et2-full-banner'),
                    icon: LucideIcons.triangleAlert,
                    text: l.etkinlik2ReqFullBanner,
                    warn: true,
                  ),
                ],
                Et2Label(l.etkinlik2ReqPendingHeader('${_pending.length}')),
                if (_pending.isEmpty)
                  BuCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: BuEmptyState(
                      compact: true,
                      illustration: BuIllustration.check,
                      title: l.etkinlik2ReqNone,
                      message: l.p16ReqNoneBody,
                    ),
                  ),
              ]),
            ),
            if (_pending.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, i) => BuStaggerItem(index: i, child: _pendingCard(c, _pending[i])),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
              sliver: SliverList.list(children: [
                if (_pendingNext != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: BuButton(
                        label: l.eventFormShowMore, kind: BuButtonKind.soft, compact: true, busy: _more, onPressed: _loadMore),
                  ),
                ],
                if (_answered.isNotEmpty) ...[
                  Et2Label(l.etkinlik2ReqAnsweredHeader),
                  BuCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < _answered.length; i++) _answeredRow(context, _answered[i], top: i > 0),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  bool get _full => _cap != null && (_going ?? 0) >= _cap!;

  Widget _quotaCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final cap = _cap;
    final going = _going ?? 0;
    final near = cap != null && cap > 0 && going / cap >= .85;
    final color = _full ? t.danger : (near ? t.warn : t.pr);
    return BuCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Et2IconBox(LucideIcons.users, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.etkinlik2ReqQuota, style: tx.titleSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
          ),
          // Sayı çifti her dilde soldan sağa okunur (Arapçada "9 / 14" ters dizilmesin).
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(cap == null ? '$going' : '$going / $cap',
                key: const ValueKey('et2-quota'), style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          ),
        ]),
        if (cap != null) ...[
          const SizedBox(height: 14),
          Et2Progress(fraction: cap == 0 ? 1 : going / cap, color: color),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Icon(cap == null ? LucideIcons.infinity : (_full ? LucideIcons.lock : LucideIcons.ticket), size: 16, color: _full ? t.danger : t.mut),
          const SizedBox(width: 8),
          Expanded(
            child: Text(cap == null ? l.etkinlik2ReqNoLimit : l.etkinlik2ReqSlotsLeft('${(cap - going).clamp(0, cap)}'),
                style: tx.bodyMedium!.copyWith(color: _full ? t.danger : t.mut, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  Widget _who(BuildContext context, Map<String, dynamic> a, {bool withNote = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final note = (a['note'] as String?)?.trim() ?? '';
    final dep = (a['department'] as String?) ?? '';
    final sub = withNote ? dep : [if (dep.isNotEmpty) dep, if (note.isNotEmpty) note].join(' · ');
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('${a['displayName'] ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
      ]),
    );
  }

  Widget _pendingCard(BuildContext context, Map<String, dynamic> a) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = '${a['displayName'] ?? ''}';
    final uid = _uid(a);
    final busy = _busy.contains(uid);
    final note = (a['note'] as String?)?.trim() ?? '';
    return BuCard(
      key: ValueKey('et2-req-$uid'),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          BuAvatar(name: name, url: fileUrl(a['avatarUrl'] as String?), size: 44),
          const SizedBox(width: 12),
          _who(context, a, withNote: true),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(child: Icon(LucideIcons.messageCircle, size: 16, color: t.mut)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(note, style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.4))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _DecisionButton(
              key: ValueKey('et2-reject-$uid'),
              label: l.etkinlik2Reject,
              sem: l.etkinlik2RejectSem(name),
              icon: LucideIcons.x,
              primary: false,
              onTap: busy ? null : () => _decide(a, false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DecisionButton(
              key: ValueKey('et2-approve-$uid'),
              label: l.etkinlik2Approve,
              sem: l.etkinlik2ApproveSem(name),
              icon: LucideIcons.check,
              primary: true,
              busy: busy,
              onTap: busy ? null : () => _decide(a, true),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _answeredRow(BuildContext context, Map<String, dynamic> a, {required bool top}) {
    final t = context.bu;
    final l = context.l10n;
    final ok = a['status'] == 'ACCEPTED';
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
      child: Row(children: [
        BuAvatar(name: '${a['displayName'] ?? ''}', url: fileUrl(a['avatarUrl'] as String?), size: 40),
        const SizedBox(width: 12),
        _who(context, a),
        const SizedBox(width: 8),
        ok
            ? Et2Tag(l.etkinlik2ApprovedTag, dark: true, icon: LucideIcons.check)
            : Et2Tag(l.etkinlik2RejectedTag, muted: true, icon: LucideIcons.x),
      ]),
    );
  }
}

/// Onayla / Reddet düğmesi: 48 dp, basınca küçülür; birincil dolu (marka), ikincil çerçeveli.
class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    super.key,
    required this.label,
    required this.sem,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final String sem;
  final IconData icon;
  final bool primary;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = primary ? t.onPr : t.ink;
    final radius = BorderRadius.circular(BuRadius.sm + 2);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: sem,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .97,
        enabled: onTap != null,
        child: Material(
          color: primary ? t.pr : t.sf,
          shape: RoundedRectangleBorder(borderRadius: radius, side: primary ? BorderSide.none : BorderSide(color: t.bd, width: 1.2)),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap == null
                ? null
                : () {
                    buHaptic(primary ? BuHaptic.medium : BuHaptic.selection);
                    onTap!();
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (busy)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else
                  Icon(icon, size: 18, color: primary ? t.onPr : t.mut),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// İstekler sayfası iskeleti: kontenjan kartı + iki başvuru kartı.
class _RequestsSkeleton extends StatelessWidget {
  const _RequestsSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), border: Border.all(color: t.bd)),
          child: child,
        );
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BuSkeleton(height: 60, radius: BuRadius.md),
          const SizedBox(height: 12),
          card(const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [BuSkeleton(width: 40, height: 40, radius: 12), SizedBox(width: 12), BuSkeleton.line(width: 110), Spacer(), BuSkeleton.line(width: 60, height: 20)]),
            SizedBox(height: 16),
            BuSkeleton(height: 8, radius: 4),
          ])),
          const SizedBox(height: 28),
          for (var i = 0; i < 2; i++) ...[
            card(const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                BuSkeleton.circle(44),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuSkeleton.line(width: 130), SizedBox(height: 8), BuSkeleton.line(width: 180)])),
              ]),
              SizedBox(height: 14),
              Row(children: [Expanded(child: BuSkeleton(height: 48, radius: 14)), SizedBox(width: 10), Expanded(child: BuSkeleton(height: 48, radius: 14))]),
            ])),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }
}
