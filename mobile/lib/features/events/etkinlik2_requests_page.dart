import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_models.dart' show postRelativeTime;
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = _loading ? BuViewState.loading : BuViewState.ready;
    final showError = _error != null;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuStaggerScope(
        child: BuPageScaffold(
          title: l.etkinlik2ManageRequests,
          large: false,
          state: state,
          onRefresh: () => _load(silent: true),
          loading: const _RequestsSkeleton(),
          bottomInset: 32,
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              sliver: SliverList.list(children: [
                // Kontenjan dolduysa üstteki uyarı kartı sayacın yerini alır (referans).
                if (!(_full && !showError)) _quotaCard(context),
                if (showError) ...[
                  const SizedBox(height: 12),
                  Et2ErrorRow(
                    key: const ValueKey('et2-req-error'),
                    title: l.p16ReqErrTitle,
                    sub: errorText(_error!),
                    retryLabel: l.commonRetry,
                    onRetry: _load,
                  ),
                ] else ...[
                  if (_full) _fullBanner(context),
                  if (_pending.isNotEmpty) Et2SectionTitle(l.p16ReqPendingTitle, count: _pending.length),
                  if (_pending.isEmpty) _empty(context),
                ],
              ]),
            ),
            if (!showError && _pending.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (c, i) => BuStaggerItem(index: i, child: _pendingCard(c, _pending[i])),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
              sliver: SliverList.list(children: [
                if (!showError && _pendingNext != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: BuButton(
                        label: l.eventFormShowMore, kind: BuButtonKind.soft, compact: true, busy: _more, onPressed: _loadMore),
                  ),
                ],
                if (!showError && _answered.isNotEmpty) ...[
                  Et2SectionTitle(l.etkinlik2ReqAnsweredHeader, count: _answered.length, soft: false),
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

  Widget _quotaCard(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final cap = _cap;
    final going = _going ?? 0;
    final caption = Text(l.p16ReqQuotaStatus.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tx.labelSmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: t.mut,
            letterSpacing: Localizations.localeOf(context).languageCode == 'ar' ? 0 : .6));
    return BuCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          cap == null ? const Et2IconBox(LucideIcons.users, size: 40) : Et2IconBox(LucideIcons.armchair, size: 40, tint: t.tint(1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              caption,
              Text(cap == null ? l.p16ReqUnlimitedTitle : l.etkinlik2ReqSlotsLeft('${(cap - going).clamp(0, cap)}'),
                  key: const ValueKey('et2-quota'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
            ]),
          ),
          const SizedBox(width: 8),
          if (cap == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.infinity, size: 16, color: t.pr),
                const SizedBox(width: 6),
                Text(l.etkinlik2Unlimited, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ]),
            )
          else
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              // Sayı çifti her dilde soldan sağa okunur (Arapçada "9 / 14" ters dizilmesin).
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('$going / $cap', style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
              ),
              Text(l.p16ReqRegistered, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
        ]),
        if (cap != null) ...[
          const SizedBox(height: 14),
          Et2Progress(fraction: cap == 0 ? 1 : going / cap, color: t.pr),
        ],
      ]),
    );
  }

  Widget _fullBanner(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('et2-full-banner'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ExcludeSemantics(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
                child: Icon(LucideIcons.info, size: 16, color: t.onPr),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.p16ReqFullTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(l.p16ReqFullPeople('${_going ?? 0}', '${_cap ?? 0}'),
                    style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.onPr)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 38),
            child: Text(l.p16ReqFullBody, style: tx.bodyMedium!.copyWith(height: 1.4, color: t.ink)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 28),
              child: Semantics(
                button: true,
                label: l.p16ReqRaiseQuota,
                excludeSemantics: true,
                onTap: _raiseQuota,
                child: BuPressable(
                  onTap: _raiseQuota,
                  haptic: BuHaptic.selection,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 10),
                      Text(l.p16ReqRaiseQuota, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
                      const SizedBox(width: 6),
                      Icon(buDirIcon(context, LucideIcons.arrowRight), size: 16, color: t.danger),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
      child: Column(children: [
        const BuIllustrationView(BuIllustration.check, size: 140),
        const SizedBox(height: 12),
        Text(l.etkinlik2ReqNone, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: 6),
        Text(l.p16ReqEmptyBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        const SizedBox(height: 20),
        Et2GreyButton(
          key: const ValueKey('et2-req-back'),
          label: l.p16ReqBackToEvent,
          icon: buDirIcon(context, LucideIcons.arrowLeft),
          compact: true,
          onPressed: () => Navigator.pop(context, _changed),
        ),
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
    final dep = context.departmentName((a['department'] as String?) ?? '', faculty: a['faculty'] as String?);
    final email = (a['email'] as String?) ?? '';
    final ago = postRelativeTime(context, (a['createdAt'] ?? a['appliedAt'] ?? a['requestedAt']) as String?);
    final full = _full;
    return BuCard(
      key: ValueKey('et2-req-$uid'),
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Et2Initials(name: name, url: fileUrl(a['avatarUrl'] as String?), size: 48, seed: uid),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ),
                if (ago.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(ago, style: tx.labelSmall!.copyWith(color: t.mut)),
                ],
              ]),
              if (dep.isNotEmpty) Text(dep, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    ExcludeSemantics(child: Icon(LucideIcons.mail, size: 13, color: t.mut)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                  ]),
                ),
            ]),
          ),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ExcludeSemantics(child: Icon(LucideIcons.messageSquare, size: 13, color: t.mut)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l.p16ReqNoteLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('"$note"', style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.4)),
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
              onTap: (busy || full) ? null : () => _decide(a, true),
            ),
          ),
        ]),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ExcludeSemantics(child: Icon(LucideIcons.lock, size: 13, color: t.danger)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(l.p16ReqCantApprove,
                    textAlign: TextAlign.center, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: t.danger)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _answeredRow(BuildContext context, Map<String, dynamic> a, {required bool top}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final ok = a['status'] == 'ACCEPTED';
    final name = '${a['displayName'] ?? ''}';
    final dep = context.departmentName((a['department'] as String?) ?? '', faculty: a['faculty'] as String?);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: t.bd)) : null),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Row(children: [
        Et2Initials(name: name, url: fileUrl(a['avatarUrl'] as String?), size: 44, seed: _uid(a) + 1),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
            if (dep.isNotEmpty) Text(dep, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        const SizedBox(width: 8),
        ok
            ? Et2Tag(l.etkinlik2ApprovedTag, dark: true, icon: LucideIcons.circleCheck)
            : Et2Tag(l.etkinlik2RejectedTag, danger: true, icon: LucideIcons.circleX),
      ]),
    );
  }
}

/// Onayla / Reddet düğmesi: 48 dp; birincil dolu (marka), ikincil sönük dolu. [onTap] null ise (kontenjan dolu) soluk.
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
    final off = onTap == null && !busy;
    final bg = primary ? (off ? t.pr.withValues(alpha: .16) : t.pr) : t.sf2;
    final fg = primary ? (off ? t.mut.withValues(alpha: .7) : t.onPr) : t.ink;
    final radius = BorderRadius.circular(BuRadius.md);
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
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: radius),
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
                  Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
          child: child,
        );
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          card(const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              BuSkeleton(width: 40, height: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 90, height: 10),
                  SizedBox(height: 8),
                  BuSkeleton.line(width: 130, height: 18),
                ]),
              ),
              BuSkeleton.line(width: 56, height: 18),
            ]),
            SizedBox(height: 16),
            BuSkeleton(height: 8, radius: 4),
          ])),
          const SizedBox(height: 28),
          for (var i = 0; i < 2; i++) ...[
            card(const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                BuSkeleton(width: 48, height: 48, radius: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton.line(width: 130),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 180),
                  ]),
                ),
              ]),
              SizedBox(height: 14),
              Row(children: [
                Expanded(child: BuSkeleton(height: 48, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: BuSkeleton(height: 48, radius: 16)),
              ]),
            ])),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }
}
