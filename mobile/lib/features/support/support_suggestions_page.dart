import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show relativeTime;
import '../polls/anket_art.dart';
import '../polls/anket_widgets.dart';
import 'support_common.dart';
import 'support_feedback_page.dart';

/// Öneri panosu: yönetici onaylı öneriler, oy verme. Sayfa tabanlı (sort=top|new).
class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key, required this.session});

  final Session session;

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final List<Map<String, dynamic>> _items = [];
  int _sort = 0; // 0 en çok oy, 1 en yeni
  int _page = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  final Set<int> _voting = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset) {
      if (_more || _page + 1 >= _totalPages) return;
      setState(() => _more = true);
    }
    final page = reset ? 0 : _page + 1;
    try {
      final r = await widget.session.api.get('/suggestions?sort=${_sort == 0 ? 'top' : 'new'}&page=$page&size=20') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
        _page = page;
        _totalPages = (r['totalPages'] as num?)?.toInt() ?? 1;
        _error = null;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _toggleVote(Map<String, dynamic> s) async {
    final id = (s['id'] as num).toInt();
    if (_voting.contains(id)) return;
    final voted = s['votedByMe'] == true;
    final count = (s['voteCount'] as num?)?.toInt() ?? 0;
    buHaptic(voted ? BuHaptic.selection : BuHaptic.light);
    setState(() {
      _voting.add(id);
      s['votedByMe'] = !voted;
      s['voteCount'] = count + (voted ? -1 : 1);
    });
    try {
      final p = '/suggestions/$id/vote';
      if (voted) {
        await widget.session.api.delete(p);
      } else {
        await widget.session.api.put(p);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          s['votedByMe'] = voted;
          s['voteCount'] = count;
        });
        supportSnack(context, supportError(context, e), BuToastKind.error);
      }
    }
    if (mounted) setState(() => _voting.remove(id));
  }

  void _setSort(int i) {
    if (i == _sort) return;
    setState(() {
      _sort = i;
      _loading = true;
    });
    _load(reset: true);
  }

  void _add() => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FeedbackPage(session: widget.session, initialCategory: 'SUGGESTION')),
      );

  Future<void> _openDetail(Map<String, dynamic> s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => SuggestionDetailPage(item: s, onVote: () => _toggleVote(s))),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final failed = _error != null && _items.isEmpty;
    return BuPageScaffold(
      title: l.supportBoard,
      large: false,
      state: _loading ? BuViewState.loading : BuViewState.ready,
      onRefresh: () => _load(reset: true),
      loading: const _SuggestionsSkeleton(),
      bottomInset: 28,
      slivers: [
        if (_items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: Align(alignment: AlignmentDirectional.centerEnd, child: _AddButton(label: l.p13SugAdd, onTap: _add)),
            ),
          ),
        if (!failed && _items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: _SortTabs(labels: [l.p13SugSortTop, l.supportSortNew], icons: const [LucideIcons.flame, LucideIcons.clock], index: _sort, onChanged: _setSort),
            ),
          ),
        if (failed)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: BuCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bMd),
                    child: Row(children: [
                      AnketRoundIcon(LucideIcons.wifiOff, size: 44, bg: t.pr.withValues(alpha: .14), fg: t.pr),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.pollLoadFailedRetry, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: l.supportRetry,
                    excludeSemantics: true,
                    onTap: () => _load(reset: true),
                    child: Material(
                      color: t.ink,
                      borderRadius: BuRadius.bMd,
                      child: InkWell(
                        borderRadius: BuRadius.bMd,
                        onTap: () => _load(reset: true),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Center(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.refreshCw, size: 18, color: t.bg),
                              const SizedBox(width: 10),
                              Text(l.supportRetry, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.bg, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          )
        else if (_items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: BuCard(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(children: [
                    const AnketArtView(AnketArt.idea, size: 112),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(l.supportNoSuggestions, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                    ),
                    const SizedBox(height: 20),
                    BuButton(label: l.p13SugAdd, icon: LucideIcons.plus, onPressed: _add),
                  ]),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            sliver: SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => BuStaggerItem(
                index: i,
                child: _SuggestionTile(item: _items[i], onVote: () => _toggleVote(_items[i]), onOpen: () => _openDetail(_items[i])),
              ),
            ),
          ),
          if (_page + 1 < _totalPages)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: BuButton(label: l.supportMore, kind: BuButtonKind.outline, compact: true, busy: _more, onPressed: _load),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 0),
              child: Row(children: [
                ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
                const SizedBox(width: 8),
                Expanded(child: Text(l.p13SugApprovalNote, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, height: 1.4))),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// "+ Öneri ekle" düğmesi (sağ üst).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.pr,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.plus, size: 18, color: t.onPr),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.onPr, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sıralama anahtarı (En çok oy | En yeni): seçili parça koyu (ink) dolgu.
class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.labels, required this.icons, required this.index, required this.onChanged});

  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              label: labels[i],
              excludeSemantics: true,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                decoration: BoxDecoration(color: i == index ? t.ink : null, borderRadius: BorderRadius.circular(12)),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (i != index) buHaptic(BuHaptic.selection);
                      onChanged(i);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icons[i], size: 16, color: i == index ? t.bg : t.mut),
                            const SizedBox(width: 8),
                            Text(labels[i], maxLines: 1, style: tx.labelLarge!.copyWith(color: i == index ? t.bg : t.mut, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Öneri kartı: durum hapı + zaman, başlık, metin, sağ altta oy hapı.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item, required this.onVote, required this.onOpen});

  final Map<String, dynamic> item;
  final VoidCallback onVote;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final voted = item['votedByMe'] == true;
    final count = (item['voteCount'] as num?)?.toInt() ?? 0;
    final ago = relativeTime(item['createdAt'] as String?, context: context);
    return BuCard(
      onTap: onOpen,
      padding: const EdgeInsetsDirectional.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SupportFeedbackPill(item['status'] as String?),
            if (ago.isNotEmpty)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ExcludeSemantics(child: Icon(LucideIcons.history, size: 14, color: t.mut)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(ago, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Text('${item['subject'] ?? ''}', style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 6),
          Text('${item['message'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerEnd, child: VotePill(count: count, voted: voted, onTap: onVote)),
        ]),
      ),
    );
  }
}

/// Oy hapı: yukarı ok + sayı; oy verilince dolu marka rengi, aksi halde gri.
class VotePill extends StatelessWidget {
  const VotePill({super.key, required this.count, required this.voted, required this.onTap});

  final int count;
  final bool voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = voted ? t.onPr : t.ink;
    final d = BuMotion.of(context, BuMotion.short);
    return Semantics(
      button: true,
      toggled: voted,
      label: context.l10n.destekVoteLabel('$count'),
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .95,
        child: AnimatedContainer(
          duration: d,
          curve: BuMotion.standard,
          decoration: BoxDecoration(color: voted ? t.pr : t.sf2, borderRadius: BorderRadius.circular(16)),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 80),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.arrowUp, size: 18, color: fg),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: d,
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(a), child: c)),
                      child: Text('$count', key: ValueKey(count), style: tx.titleSmall!.copyWith(color: fg, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Öneri ayrıntısı (tasarım 35-05): durum hapı, başlık, tam metin, yönetici yanıtı, oy bloğu ve onay notu.
class SuggestionDetailPage extends StatefulWidget {
  const SuggestionDetailPage({super.key, required this.item, required this.onVote});

  final Map<String, dynamic> item;
  final Future<void> Function() onVote;

  @override
  State<SuggestionDetailPage> createState() => _SuggestionDetailPageState();
}

class _SuggestionDetailPageState extends State<SuggestionDetailPage> {
  bool _busy = false;

  Future<void> _vote() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onVote();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final it = widget.item;
    final voted = it['votedByMe'] == true;
    final count = (it['voteCount'] as num?)?.toInt() ?? 0;
    final resp = it['adminResponse'] as String?;
    return BuPageScaffold(
      title: l.supportBoard,
      large: false,
      bottomInset: 28,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: BuCard(
              padding: const EdgeInsetsDirectional.all(16),
              child: SizedBox(
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SupportFeedbackPill(it['status'] as String?),
                  const SizedBox(height: 14),
                  Semantics(header: true, child: Text('${it['subject'] ?? ''}', style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3))),
                  const SizedBox(height: 12),
                  Text('${it['message'] ?? ''}', style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.55)),
                  if (resp != null && resp.isNotEmpty) ...[const SizedBox(height: 14), SupportStaffReply(text: resp)],
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    toggled: voted,
                    label: l.destekVoteLabel('$count'),
                    excludeSemantics: true,
                    onTap: _vote,
                    child: Material(
                      color: t.sf2,
                      borderRadius: BuRadius.bLg,
                      child: InkWell(
                        borderRadius: BuRadius.bLg,
                        onTap: _vote,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
                          child: Row(children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: voted ? t.pr : t.sf, shape: BoxShape.circle),
                              child: Icon(LucideIcons.arrowUp, size: 24, color: voted ? t.onPr : t.ink),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$count', style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                                Text(voted ? l.p13SugVoted : l.p13SugVoteHint,
                                    style: tx.labelMedium!.copyWith(color: voted ? t.pr : t.mut, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            if (voted) Icon(LucideIcons.circleCheck, size: 24, color: t.pr),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.pr)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.p13SugApprovalNote, style: tx.labelMedium!.copyWith(color: t.mut, height: 1.4))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Öneri iskeleti: üç kart.
class _SuggestionsSkeleton extends StatelessWidget {
  const _SuggestionsSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
            child: Column(children: [
              const BuSkeleton(height: 52, radius: 16),
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                const BuCard(
                  padding: EdgeInsetsDirectional.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [BuSkeleton(width: 84, height: 24, radius: 12), Spacer(), BuSkeleton(width: 64, height: 14, radius: 7)]),
                    SizedBox(height: 14),
                    BuSkeleton.line(height: 16),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 200, height: 16),
                    SizedBox(height: 12),
                    BuSkeleton.line(height: 12),
                    SizedBox(height: 14),
                    Align(alignment: AlignmentDirectional.centerEnd, child: BuSkeleton(width: 84, height: 44, radius: 16)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      );
}
