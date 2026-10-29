import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'anket_widgets.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Anket listesi (tasarım 31): Açık | Katıldıklarım | Kapanan, imleçli sayfalama. [communityId] verilirse tek kulüp.
/// [canCreate] true ise başlıkta "+" (kulüp anketi oluştur; yalnız [communityId] ile). İlk açılışta iskelet gösterilir.
class PollListPage extends StatefulWidget {
  const PollListPage({super.key, required this.session, this.communityId, this.title, this.canCreate = false});

  final Session session;
  final int? communityId;
  final String? title;
  final bool canCreate;

  @override
  State<PollListPage> createState() => _PollListPageState();
}

class _PollListPageState extends State<PollListPage> {
  static const _scopes = ['open', 'mine', 'closed'];

  late final PollApi _api = PollApi(widget.session);
  final _scroll = ScrollController();
  final List<Poll> _items = [];
  int _tab = 0;
  int _gen = 0;
  int? _openCount;
  String? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final gen = reset ? ++_gen : _gen;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = false;
        _loaded = false;
      }
    });
    try {
      final page = await _api.list(
          scope: widget.communityId != null ? 'community:${widget.communityId}' : _scopes[_tab], cursor: _cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loaded = true;
        _loading = false;
        if (_tab == 0 && widget.communityId == null && !_hasMore) _openCount = _items.length;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _load(reset: true);
  }

  Future<void> _open(Poll p) async {
    final changed = await openPollDetail(context, widget.session, p.id, initial: p);
    if (changed == true && mounted) _load(reset: true);
  }

  Future<void> _create() async {
    final p = await openPollForm(context, widget.session, communityId: widget.communityId!);
    if (p != null && mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final club = widget.communityId != null;
    final labels = [l.pollTabOpen, l.pollTabMine, l.pollTabClosed];
    final failed = _error != null && _items.isEmpty;
    final net = _error is ApiError && (_error! as ApiError).isNetwork;
    return BuPageScaffold(
      title: widget.title ?? l.pollListTitle,
      large: false,
      state: BuViewState.ready,
      onRefresh: () => _load(reset: true),
      controller: _scroll,
      bottomInset: 28,
      actions: [
        if (club && widget.canCreate)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Semantics(
              button: true,
              label: l.pollCreate,
              excludeSemantics: true,
              onTap: _create,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Material(
                    color: t.pr,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _create,
                      child: SizedBox(width: 40, height: 40, child: Icon(LucideIcons.plus, size: 22, color: t.onPr)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      banner: failed
          ? Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
              child: AnketErrorBanner(
                title: l.pollLoadFailedRetry,
                body: net ? l.p13PollErrBody : errorText(_error!),
                retryLabel: l.commonRetry,
                onRetry: () => _load(reset: true),
              ),
            )
          : null,
      slivers: [
        if (!club)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
              child: AnketTabs(labels: labels, index: _tab, onChanged: _select, badge: _openCount),
            ),
          ),
        if (_tab == 2 && !club && _loaded && _items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: AnketHeading(title: l.p13PollArchiveHeading, trailing: _hasMore ? null : l.p13PollArchiveCount('${_items.length}')),
            ),
          ),
        if (!_loaded && _error == null)
          const SliverToBoxAdapter(child: _PollListSkeleton())
        else if (_loaded && _items.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0), child: _empty(l)))
        else
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            sliver: SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = _items[i];
                return BuStaggerItem(index: i, child: PollCard(poll: p, onTap: () => _open(p)));
              },
            ),
          ),
        SliverToBoxAdapter(child: _footer(l.pollLoadFailedRetry)),
      ],
    );
  }

  Widget _empty(AppLocalizations l) {
    if (widget.communityId != null) {
      return BuCard(
        padding: const EdgeInsetsDirectional.all(12),
        child: AnketClubEmpty(
          title: l.pollClubEmpty,
          body: l.p13PollClubEmptyBody,
          linkLabel: l.pollSeeAll,
          onLink: () => openPollList(context, widget.session),
        ),
      );
    }
    return switch (_tab) {
      0 => AnketEmptyCard(tag: l.pollTabOpen, tagIcon: LucideIcons.vote, icon: LucideIcons.vote, title: l.pollEmptyOpen, body: l.p13PollEmptyOpenBody),
      1 => AnketEmptyCard(
          tag: l.pollTabMine, tagIcon: LucideIcons.userCheck, icon: LucideIcons.listChecks, title: l.pollEmptyMine, body: l.p13PollEmptyMineBody),
      _ => AnketEmptyCard(
          tag: l.pollTabClosed, tagIcon: LucideIcons.archive, icon: LucideIcons.archive, title: l.pollEmptyClosed, body: l.p13PollEmptyClosedBody),
    };
  }

  Widget _footer(String retryLabel) {
    if (_loading && _items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
        child: BuSkeletonScope(child: _PollSkeletonCard()),
      );
    }
    if (_error != null && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(child: BuButton(label: retryLabel, kind: BuButtonKind.soft, compact: true, onPressed: _load)),
      );
    }
    return const SizedBox.shrink();
  }
}

/// İlk yükleme iskeleti: gerçek kartla aynı düzen (çipler, başlık, açıklama, meta).
class _PollListSkeleton extends StatelessWidget {
  const _PollListSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
            child: Column(children: [
              _PollSkeletonCard(),
              SizedBox(height: 12),
              _PollSkeletonCard(),
              SizedBox(height: 12),
              _PollSkeletonCard(),
            ]),
          ),
        ),
      );
}

class _PollSkeletonCard extends StatelessWidget {
  const _PollSkeletonCard();

  @override
  Widget build(BuildContext context) => const BuCard(
        padding: EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              BuSkeleton(width: 64, height: 24, radius: 12),
              SizedBox(width: 8),
              BuSkeleton(width: 84, height: 24, radius: 12),
              Spacer(),
              BuSkeleton(width: 72, height: 24, radius: 12),
            ]),
            SizedBox(height: 14),
            BuSkeleton.line(height: 18),
            SizedBox(height: 8),
            BuSkeleton.line(width: 190, height: 18),
            SizedBox(height: 14),
            Row(children: [
              BuSkeleton.line(width: 84, height: 12),
              SizedBox(width: 16),
              BuSkeleton.line(width: 56, height: 12),
              Spacer(),
              BuSkeleton(width: 84, height: 40, radius: 14),
            ]),
          ],
        ),
      );
}
