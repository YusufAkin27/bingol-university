import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Anket listesi (Stitch v3 01): metin sekmeleri Açık | Katıldıklarım | Kapanan, kartsız satırlar, imleçli sayfalama.
/// [communityId] verilirse tek kulüp (sekmesiz). [canCreate] true ise başlıkta `pr` "+ Yeni" (yalnız [communityId] ile).
/// İlk açılışta iskelet gösterilir; boş/hata durumları tek soluk satır + metin düğmesidir (ikon/kart yok).
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
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Semantics(
              button: true,
              label: l.pollCreate,
              excludeSemantics: true,
              onTap: _create,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _create,
                child: Text('+ ${l.p68New}', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.pr, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
      slivers: [
        if (!club) SliverToBoxAdapter(child: AnketTextTabs(labels: labels, index: _tab, onChanged: _select)),
        SliverToBoxAdapter(child: club ? const Padding(padding: EdgeInsets.only(top: 8), child: AnketRule()) : const Padding(padding: EdgeInsets.only(top: 2), child: AnketRule())),
        if (!_loaded && _error == null)
          const SliverToBoxAdapter(child: _PollListSkeleton())
        else if (failed)
          SliverToBoxAdapter(
            child: AnketStateLine(text: l.pollLoadFailedRetry, actionLabel: l.commonRetry, onAction: () => _load(reset: true)),
          )
        else if (_loaded && _items.isEmpty)
          SliverToBoxAdapter(child: _empty(l))
        else
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final p = _items[i];
              return BuStaggerItem(index: i, child: PollCard(poll: p, first: i == 0, onTap: () => _open(p)));
            },
          ),
        SliverToBoxAdapter(child: _footer(l.pollLoadFailedRetry, l.commonRetry)),
      ],
    );
  }

  Widget _empty(AppLocalizations l) {
    if (widget.communityId != null) {
      return AnketStateLine(text: l.pollClubEmpty, actionLabel: l.pollSeeAll, onAction: () => openPollList(context, widget.session));
    }
    return AnketStateLine(text: switch (_tab) { 0 => l.pollEmptyOpen, 1 => l.pollEmptyMine, _ => l.pollEmptyClosed });
  }

  Widget _footer(String failed, String retryLabel) {
    if (_loading && _items.isNotEmpty) {
      return const BuSkeletonScope(child: AnketSkeletonRow());
    }
    if (_error != null && _items.isNotEmpty) {
      return AnketStateLine(text: failed, actionLabel: retryLabel, onAction: _load, padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 12, kAnketPad, 0));
    }
    return const SizedBox.shrink();
  }
}

/// İlk yükleme iskeleti: gerçek satırla aynı düzen (başlık + meta çubuğu, ayraçlı).
class _PollListSkeleton extends StatelessWidget {
  const _PollListSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Column(children: [
            AnketSkeletonRow(titleWidth: 240),
            AnketSkeletonRow(titleWidth: 200),
            AnketSkeletonRow(titleWidth: 260),
          ]),
        ),
      );
}
