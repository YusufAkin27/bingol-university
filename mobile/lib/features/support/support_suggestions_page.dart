import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../polls/anket_flat.dart';
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
      title: l.p68SugTitle,
      large: false,
      state: _loading ? BuViewState.loading : BuViewState.ready,
      onRefresh: () => _load(reset: true),
      loading: const _SuggestionsSkeleton(),
      bottomInset: 28,
      slivers: [
        if (!failed && _items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _SortText(labels: [l.p68SugTop, l.p68SugNew], index: _sort, onChanged: _setSort),
            ),
          ),
        if (failed)
          SliverToBoxAdapter(child: AnketStateLine(text: l.pollLoadFailedRetry, actionLabel: l.supportRetry, onAction: () => _load(reset: true)))
        else if (_items.isEmpty)
          SliverToBoxAdapter(child: AnketStateLine(text: l.p68SugEmpty, actionLabel: l.p68SugSend, onAction: _add))
        else ...[
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (_, i) => BuStaggerItem(
              index: i,
              child: _SuggestionTile(item: _items[i], first: i == 0, onVote: () => _toggleVote(_items[i]), onOpen: () => _openDetail(_items[i])),
            ),
          ),
          if (_page + 1 < _totalPages)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48)),
                    onPressed: _more ? null : _load,
                    child: Text(l.supportMore, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  onPressed: _add,
                  child: Text(l.p68SugSend, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sıralama metinleri (Stitch v3 05): "En çok oylanan | Yeni"; seçili `pr` 500, diğeri muted; aralarında 1 dp dikey çizgi.
class _SortText extends StatelessWidget {
  const _SortText({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: kAnketPad),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) ExcludeSemantics(child: Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 4), color: t.bdStrong)),
          Semantics(
            button: true,
            selected: i == index,
            label: labels[i],
            excludeSemantics: true,
            onTap: () => onChanged(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i != index) buHaptic(BuHaptic.selection);
                onChanged(i);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    widthFactor: 1,
                    child: AnimatedDefaultTextStyle(
                      duration: BuMotion.of(context, BuMotion.short),
                      style: tx.bodyMedium!.copyWith(color: i == index ? t.pr : t.mut, fontWeight: i == index ? FontWeight.w500 : FontWeight.w400),
                      child: Text(labels[i], maxLines: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Öneri satırı (kartsız): solda başlık 18 sp/600, 2 satır muted gövde, altta muted durum; sağda 56x64 dikey oy kontrolü.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item, required this.onVote, required this.onOpen, this.first = false});

  final Map<String, dynamic> item;
  final VoidCallback onVote;
  final VoidCallback onOpen;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final voted = item['votedByMe'] == true;
    final count = (item['voteCount'] as num?)?.toInt() ?? 0;
    final status = supportFeedbackStatuses(l)[item['status']] ?? l.supportStNew;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, first ? 2 : 17, kAnketPad, 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['subject'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
                const SizedBox(height: 4),
                Text('${item['message'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
                const SizedBox(height: 7),
                Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.3)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          VotePill(count: count, voted: voted, onTap: onVote, vertical: true),
        ]),
      ),
    );
  }
}

/// Oy kontrolü: yukarı ok + sayı; 56x64 (dikey), r16, 1 dp çerçeve. Oy verilince `soft` zemin + `pr` çerçeve/yazı.
class VotePill extends StatelessWidget {
  const VotePill({super.key, required this.count, required this.voted, required this.onTap, this.vertical = false});

  /// Dikey: ok üstte, sayı altta (liste satırında sağ kenar).
  final bool vertical;
  final int count;
  final bool voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = voted ? t.pr : t.mut;
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
          decoration: BoxDecoration(
            color: voted ? t.soft : t.sf,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: voted ? t.pr : t.bd),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: vertical ? 62 : 46, minWidth: vertical ? 54 : 78), // 1 dp çerçeve dahil 56x64
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: vertical ? 8 : 16, vertical: vertical ? 6 : 0),
                  child: Flex(
                    direction: vertical ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.arrowUp, size: 20, color: voted ? t.pr : t.ink),
                      SizedBox(width: vertical ? 0 : 8, height: vertical ? 2 : 0),
                      AnimatedSwitcher(
                        duration: d,
                        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(a), child: c)),
                        child: Text('$count', key: ValueKey(count), style: tx.titleSmall!.copyWith(color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
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
      title: l.p68SugTitle,
      large: false,
      bottomInset: 28,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: Padding(
              padding: EdgeInsets.zero,
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

/// Öneri iskeleti: üç satır (başlık + gövde çubukları, sağda oy kutusu).
class _SuggestionsSkeleton extends StatelessWidget {
  const _SuggestionsSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Column(children: [
            for (var i = 0; i < 3; i++)
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 17, kAnketPad, 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.bu.bd))),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BuSkeleton.line(width: 230, height: 18),
                      SizedBox(height: 10),
                      BuSkeleton.line(height: 13),
                      SizedBox(height: 6),
                      BuSkeleton.line(width: 180, height: 13),
                    ]),
                  ),
                  SizedBox(width: 12),
                  BuSkeleton(width: 56, height: 64, radius: 16),
                ]),
              ),
          ]),
        ),
      );
}
