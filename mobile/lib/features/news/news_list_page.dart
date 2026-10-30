import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/saved_news_page.dart';
import '../search/search_page.dart';
import 'icerik_parts.dart';
import 'news_detail_page.dart';
import 'news_tile.dart';

/// Haber listesi (Ic2): Haber / Duyuru / Etkinlik sekmeleri, favoriler ve arama kısayolları,
/// kaynak bakımda bandı. Veri: `GET /news?type=&page=&size=`, `GET /status`, `/bookmarks/news/*`.
class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key, required this.session, this.initialType = 'HABER'});

  final Session session;

  /// 'HABER' | 'DUYURU' | 'ETKINLIK'
  final String initialType;

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  static const _types = ['HABER', 'DUYURU', 'ETKINLIK'];
  static const _tabIcons = [LucideIcons.newspaper, LucideIcons.megaphone, LucideIcons.calendar];
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  final Set<int> _savedIds = {};

  late int _tab = _types.indexOf(widget.initialType).clamp(0, _types.length - 1);
  int _gen = 0; // eski yanıtların yeni sekmeyi ezmesini önler
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  bool _maintenance = false;
  Object? _error;

  String get _type => _types[_tab];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadStatus();
    _loadSavedIds();
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadStatus() async {
    try {
      final r = await widget.session.api.get('/status');
      var m = false;
      if (r is Map && r['NEWS'] is Map) m = (r['NEWS'] as Map)['maintenance'] == true;
      if (mounted) setState(() => _maintenance = m);
    } catch (_) {}
  }

  Future<void> _loadSavedIds() async {
    try {
      final r = await widget.session.api.get('/bookmarks/news/ids') as Map<String, dynamic>;
      final ids = (r['ids'] as List).map((e) => (e as num).toInt());
      if (mounted) {
        setState(() => _savedIds
          ..clear()
          ..addAll(ids));
      }
    } catch (_) {}
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _reload();
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loaded = false;
      _error = null;
      _loading = false;
    });
    await _fetch(gen);
  }

  Future<void> _refresh() async {
    _loadStatus();
    _loadSavedIds();
    final gen = ++_gen;
    _page = 0;
    await _fetch(gen, replace: true);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_loaded || _error != null) return;
    await _fetch(_gen);
  }

  Future<void> _fetch(int gen, {bool replace = false}) async {
    if (_loading && !replace) return;
    setState(() {
      _loading = true;
      if (!replace) _error = null;
    });
    try {
      final res = await widget.session.api.getResponse('/news?type=$_type&page=$_page&size=$_pageSize', force: replace);
      final r = res.body as Map<String, dynamic>;
      final fresh = <Map<String, dynamic>>[
        for (final e in (r['items'] as List? ?? [])) e as Map<String, dynamic>,
      ];
      final total = (r['totalPages'] as num?)?.toInt() ?? 0;
      final next = _page + 1;
      if (!mounted || gen != _gen) return;
      setState(() {
        if (replace) _items.clear();
        _items.addAll(fresh);
        _page = next;
        _hasMore = next < total;
        _loaded = true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        if (replace && _loaded) {
          BuToast.show(context, errorText(e), kind: BuToastKind.error);
        } else {
          _error = e;
        }
      });
    }
  }

  Future<void> _toggleSave(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    final was = _savedIds.contains(id);
    setState(() => was ? _savedIds.remove(id) : _savedIds.add(id));
    try {
      if (was) {
        await widget.session.api.delete('/bookmarks/news/$id');
      } else {
        await widget.session.api.put('/bookmarks/news/$id');
      }
      if (mounted) {
        final l = context.l10n;
        BuToast.show(context, was ? l.p05UnsavedToast : l.p05SavedToast, kind: BuToastKind.success);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => was ? _savedIds.add(id) : _savedIds.remove(id));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NewsDetailPage(
          session: widget.session,
          item: n,
          saved: _savedIds.contains(id),
          onToggleSave: () => _toggleSave(n),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openFavorites() async {
    await Navigator.push<void>(
        context, MaterialPageRoute<void>(builder: (_) => SavedNewsPage(session: widget.session)));
    if (mounted) _loadSavedIds();
  }

  void _openSearch() => Navigator.push<void>(
      context, MaterialPageRoute<void>(builder: (_) => SearchPage(session: widget.session)));

  String _tabLabel(int i) {
    final l = context.l10n;
    return switch (i) { 0 => l.newsTypeNews, 1 => l.newsTypeAnnouncement, _ => l.newsTypeEvent };
  }

  /// Hata ve boş durum kartları listenin içinde çizilir (sekme şeridi görünür kalır).
  BuViewState get _view => (!_loaded && _error == null) ? BuViewState.loading : BuViewState.ready;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BuPageScaffold(
      title: l.icerikNewsTitle,
      large: false,
      state: _view,
      error: _error,
      onRetry: _reload,
      onRefresh: _refresh,
      controller: _scroll,
      bottomInset: MediaQuery.paddingOf(context).bottom + 16,
      actions: [
        IcerikIconButton(
            key: const ValueKey('news-search'), icon: LucideIcons.search, label: l.commonSearchHint, onTap: _openSearch),
        IcerikIconButton(
            key: const ValueKey('news-favorites'),
            icon: LucideIcons.bookmark,
            label: l.icerikFavorites,
            onTap: _openFavorites),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: IcerikTabs(
            labels: [for (var i = 0; i < _types.length; i++) _tabLabel(i)],
            icons: _tabIcons,
            index: _tab,
            keyPrefix: 'news-tab-',
            raised: true,
            semanticLabel: l.icerikNewsTypeTabs,
            onChanged: _selectTab,
          ),
        ),
      ),
      banner: _maintenance
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: IcerikNotice(text: l.icerikMaintenance, icon: LucideIcons.triangleAlert),
            )
          : null,
      loading: const IcerikListSkeleton(featured: false),
      slivers: _slivers(),
    );
  }

  List<Widget> _slivers() {
    final l = context.l10n;
    if (_error != null && !_loaded) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: IcerikErrorCard(
                title: l.p05ListErrorTitle, body: l.p05ListErrorBody, retryLabel: l.commonRetry, onRetry: _reload),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: IcerikCard(
              shadow: false,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: BuEmptyState(
                  illustration: BuIllustration.document, title: l.icerikNewsEmpty, message: l.p05NewsEmptyBody, compact: true),
            ),
          ),
        ),
      ];
    }
    final rest = _items;
    return [
      SliverSemantics(
        container: true,
        explicitChildNodes: true,
        label: context.l10n.icerikNewsList,
        sliver: BuStaggerScope(
          key: ValueKey('$_tab-$_gen'),
          child: SliverMainAxisGroup(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverList.separated(
                itemCount: rest.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final n = rest[i];
                  return BuStaggerItem(
                    index: i,
                    child: NewsTile(
                      item: n,
                      thumbSize: 72,
                      saved: _savedIds.contains((n['id'] as num).toInt()),
                      onToggleSave: () => _toggleSave(n),
                      onTap: () => _open(n),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _footer()),
          ]),
        ),
      ),
    ];
  }

  Widget _footer() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: BuButton(
              label: context.l10n.commonRetry, compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
        ),
      );
    }
    if (_loading && _page > 0) {
      return IcerikLoadMore(text: context.l10n.p05NewsLoadingMore);
    }
    return const SizedBox(height: 4);
  }
}
