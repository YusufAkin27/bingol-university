import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show relativeTime;
import 'club_detail_parts.dart';
import 'club_ref_widgets.dart';
import 'kulup_widgets.dart' show KulupAvatar;

/// Kulübe gelen katılma istekleri: avatar + ad + cevaplar, Onayla / Reddet.
/// Pop sonucu: en az bir istek karara bağlandıysa true (kulüp sayfası sayıları yeniler).
class ClubRequestsPage extends StatefulWidget {
  const ClubRequestsPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<ClubRequestsPage> createState() => _ClubRequestsPageState();
}

class _ClubRequestsPageState extends State<ClubRequestsPage> {
  final _items = <Map<String, dynamic>>[];
  int? _next;
  bool _loading = true;
  bool _paging = false;
  Object? _error;
  bool _changed = false;
  final _busy = <int>{};
  // Karara bağlanan, çıkış animasyonu süren istekler (animasyon bitince listeden düşer).
  final _leaving = <int>{};
  int _gen = 0;

  String get _base => '/communities/${widget.communityId}';

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _paging = !reset;
      if (reset) _error = null;
    });
    try {
      final cursor = (!reset && _next != null) ? '&cursor=$_next' : '';
      final r = await widget.session.api.get('$_base/requests?include=answers&size=20$cursor') as Map;
      if (!mounted || gen != _gen) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll((r['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        _next = (r['nextCursor'] as num?)?.toInt();
        _loading = false;
        _paging = false;
      });
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _error = e;
          _loading = false;
          _paging = false;
        });
      }
    }
  }

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    final uid = (r['userId'] as num).toInt();
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      await widget.session.api.post('$_base/requests/$uid/${approve ? 'approve' : 'reject'}');
      if (!mounted) return;
      setState(() {
        _leaving.add(uid);
        _changed = true;
      });
      buHaptic(approve ? BuHaptic.medium : BuHaptic.light);
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  void _gone(Map<String, dynamic> r) {
    if (!mounted) return;
    setState(() {
      _items.remove(r);
      _leaving.remove((r['userId'] as num).toInt());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final state = _loading && _items.isEmpty
        ? BuViewState.loading
        : _error != null && _items.isEmpty
            ? BuViewState.error
            : _items.isEmpty
                ? BuViewState.empty
                : BuViewState.ready;
    final waiting = _items.length - _leaving.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: l.clubMgmtRequestsTitle,
        large: false,
        state: state,
        error: _error,
        onRetry: () => _load(reset: true),
        onRefresh: () => _load(reset: true),
        loading: const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 4, shrinkWrap: true),
        empty: BuEmptyState(
          illustration: BuIllustration.check,
          title: l.clubMgmtNoPending,
          message: l.p11RequestsEmptyAll,
        ),
        slivers: [
          if (waiting > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                child: Text(l.clubMgmtWaitingCount('$waiting${_next != null ? '+' : ''}'),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
              ),
            ),
          BuStaggerScope(
            child: SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final r = _items[i];
                  final uid = (r['userId'] as num).toInt();
                  return BuStaggerItem(
                    index: i,
                    child: _RequestTile(
                      key: ValueKey(uid),
                      request: r,
                      busy: _busy.contains(uid),
                      leaving: _leaving.contains(uid),
                      onApprove: () => _decide(r, true),
                      onReject: () => _decide(r, false),
                      onGone: () => _gone(r),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_paging) const SliverToBoxAdapter(child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1, shrinkWrap: true)),
          if (_next != null && !_paging)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
                child: BuButton(
                  label: l.clubMgmtMoreRequests,
                  icon: LucideIcons.history,
                  kind: BuButtonKind.soft,
                  onPressed: _loading ? null : () => _load(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Başvuru kartı: avatar + ad, cevap kutusu, Reddet / Onayla. Karar verilince küçülerek kaybolur.
class _RequestTile extends StatefulWidget {
  const _RequestTile({
    super.key,
    required this.request,
    required this.busy,
    required this.leaving,
    required this.onApprove,
    required this.onReject,
    required this.onGone,
  });

  final Map<String, dynamic> request;
  final bool busy;
  final bool leaving;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onGone;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  late final Animation<double> _size = CurvedAnimation(parent: _c, curve: BuMotion.emphasized);

  @override
  void didUpdateWidget(_RequestTile old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _exit();
  }

  Future<void> _exit() async {
    _c.duration = BuMotion.of(context, BuMotion.medium);
    if (_c.duration == Duration.zero) {
      // Hareket azaltılmış: yapı sırasında setState çağrılmasın diye çerçeve sonrasına bırak.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onGone();
      });
      return;
    }
    await _c.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final r = widget.request;
    final answers = (r['answers'] as List?)?.whereType<Map>().toList() ?? const [];
    final off = widget.busy || widget.leaving;
    final sub = clubMemberSubtitle(context, r);
    final when = relativeTime((r['requestedAt'] ?? r['createdAt'] ?? r['joinedAt'])?.toString(), context: context);
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _size,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BuCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KulupAvatar(name: r['displayName']?.toString(), url: r['avatarUrl']?.toString(), size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((r['displayName'] ?? l.clubMgmtUser).toString(),
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                          if (sub.isNotEmpty)
                            Text(sub, style: tx.bodySmall!.copyWith(color: t.mut)),
                        ],
                      ),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
                        child: Text(when, maxLines: 1, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                if (answers.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < answers.length; i++) ...[
                          if (i > 0) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: t.bd),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: ExcludeSemantics(child: Icon(LucideIcons.circleHelp, size: 14, color: t.mut)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: Text((answers[i]['question'] ?? '').toString(), style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text((answers[i]['answer'] ?? '').toString(), style: tx.bodyLarge!.copyWith(height: 1.4, color: t.ink)),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ClubBtn(label: l.clubMgmtReject, icon: LucideIcons.x, onPressed: off ? null : widget.onReject)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClubBtn(
                        kind: ClubBtnKind.primary,
                        icon: LucideIcons.check,
                        busy: widget.busy,
                        label: widget.busy ? l.kulupdetayApproving : l.clubMgmtApprove,
                        onPressed: off ? null : widget.onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
