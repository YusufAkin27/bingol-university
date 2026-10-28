import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
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
      final r = await widget.session.api.get('/news?type=$_type&page=$_page&size=$_pageSize') as Map<String, dynamic>;
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
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
    } catch (e) {
      if (!mounted) return;
      setState(() => was ? _savedIds.add(id) : _savedIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
            child: Row(children: [
              IcerikIconButton(
                  icon: buDirIcon(context, LucideIcons.arrowLeft),
                  label: l.commonBack,
                  onTap: () => Navigator.maybePop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.icerikNewsTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.display.copyWith(fontSize: 28, letterSpacing: -.5, height: 1.15, color: t.ink)),
                ),
              ),
              const SizedBox(width: 12),
              IcerikIconButton(
                  key: const ValueKey('news-favorites'),
                  icon: LucideIcons.bookmark,
                  label: l.icerikFavorites,
                  onTap: _openFavorites),
              const SizedBox(width: 10),
              IcerikIconButton(
                  key: const ValueKey('news-search'), icon: LucideIcons.search, label: l.commonSearchHint, onTap: _openSearch),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Semantics(
              container: true,
              label: l.icerikNewsTypeTabs,
              child: Row(children: [
                for (var i = 0; i < _types.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _TypeTab(label: _tabLabel(i), on: i == _tab, onTap: () => _selectTab(i), index: i)),
                ],
              ]),
            ),
          ),
          if (_maintenance)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _MaintenanceBanner(text: l.icerikMaintenance),
            ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (!_loaded && _error == null) return const LoadingView();
    if (_error != null && !_loaded) return ErrorView(error: _error!, onRetry: _reload);
    final bottom = MediaQuery.of(context).padding.bottom + 24;
    if (_items.isEmpty) {
      return RefreshIndicator(
        color: t.pr,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 320, child: EmptyView(icon: LucideIcons.newspaper, text: context.l10n.icerikNewsEmpty)),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      label: context.l10n.icerikNewsList,
      explicitChildNodes: true,
      child: RefreshIndicator(
        color: t.pr,
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == _items.length) return _footer();
            final n = _items[i];
            return NewsTile(item: n, onTap: () => _open(n));
          },
        ),
      ),
    );
  }

  Widget _footer() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: BuButton(
              label: context.l10n.commonRetry, compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    return const SizedBox(height: 4);
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({required this.label, required this.on, required this.onTap, required this.index});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('news-tab-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.pr : t.sf,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: on ? t.pr : t.bd),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BuType.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: on ? t.onPr : t.mut)),
        ),
      ),
    );
  }
}

class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = icerikWarnColors(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(LucideIcons.circleAlert, size: 18, color: c.fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: BuType.body.copyWith(fontSize: 13, height: 1.4, color: c.fg))),
        ]),
      ),
    );
  }
}
