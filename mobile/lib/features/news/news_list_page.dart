import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/academic_models.dart' show istanbulWall;
import '../profile/saved_news_page.dart';
import '../search/search_page.dart';
import 'icerik_parts.dart';
import 'news_detail_page.dart';
import 'news_tile.dart';
import 'unit_news.dart';

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
  final Set<int> _saving = {};

  late int _tab = _types.indexOf(widget.initialType).clamp(0, _types.length - 1);
  int _unitTick = 0; // "Bölümüm" şeridini yeniler
  int _gen = 0; // eski yanıtların yeni sekmeyi ezmesini önler
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  bool _maintenance = false;
  String? _lastSuccess; // ISO zaman damgası (bakım bandı: "Son güncelleme")
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
      String? last;
      if (r is Map && r['NEWS'] is Map) {
        final n = r['NEWS'] as Map;
        m = n['maintenance'] == true;
        last = n['lastSuccessAt'] as String?;
      }
      if (mounted) {
        setState(() {
          _maintenance = m;
          _lastSuccess = last;
        });
      }
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
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
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
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
    setState(() => _unitTick++);
    _loadStatus();
    _loadSavedIds();
    final gen = ++_gen;
    await _fetch(gen, replace: true);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_loaded || _error != null) return;
    await _fetch(_gen);
  }

  /// Altbilgi "Tekrar dene": hata bayrağı açıkken de çalışır (`_loadMore` hata varken geri döner).
  Future<void> _retryMore() async {
    if (_loading) return;
    await _fetch(_gen);
  }

  Future<void> _fetch(int gen, {bool replace = false}) async {
    if (_loading && !replace) return;
    setState(() {
      _loading = true;
      if (!replace) _error = null;
    });
    try {
      // Yenilemede sayfa sayacı başarıdan önce sıfırlanmaz (hatada kopya sayfa çekilmesin).
      final page = replace ? 0 : _page;
      final res = await widget.session.api.getResponse('/news?type=$_type&page=$page&size=$_pageSize', force: replace);
      final r = res.body as Map<String, dynamic>;
      final fresh = <Map<String, dynamic>>[
        for (final e in (r['items'] as List? ?? []))
          if (e is Map && e['id'] is num) Map<String, dynamic>.from(e),
      ];
      final total = (r['totalPages'] as num?)?.toInt() ?? 0;
      final next = page + 1;
      if (!mounted || gen != _gen) return;
      setState(() {
        if (replace) _items.clear();
        // Sayfa kaymasında (araya yeni haber girince) aynı kayıt iki kez gelmesin.
        final have = {for (final x in _items) (x['id'] as num).toInt()};
        _items.addAll(fresh.where((x) => have.add((x['id'] as num).toInt())));
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

  /// Kaydetme/kaldırma; kesinleşen "kayıtlı mı" durumunu döndürür (hatada eski durum: açık detay sayfası buna eşitlenir).
  Future<bool> _toggleSave(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    if (!_saving.add(id)) return _savedIds.contains(id); // çift dokunuşta ters istek yarışı olmasın
    try {
      return await _toggleSaveInner(n, id);
    } finally {
      _saving.remove(id);
    }
  }

  Future<bool> _toggleSaveInner(Map<String, dynamic> n, int id) async {
    final was = _savedIds.contains(id);
    setState(() => was ? _savedIds.remove(id) : _savedIds.add(id));
    try {
      if (was) {
        await widget.session.api.delete('/bookmarks/news/$id');
      } else {
        await widget.session.api.put('/bookmarks/news/$id');
      }
      Analytics.instance.action('bookmark', target: was ? 'remove' : 'add');
      if (mounted) {
        final l = context.l10n;
        BuToast.show(context, was ? l.p05UnsavedToast : l.p05SavedToast, kind: BuToastKind.success);
      }
      return !was;
    } catch (e) {
      if (!mounted) return was;
      setState(() => was ? _savedIds.add(id) : _savedIds.remove(id));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
      return was;
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(settings: const RouteSettings(name: 'news_detail'), 
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
        context, MaterialPageRoute<void>(settings: const RouteSettings(name: 'saved_news'), builder: (_) => SavedNewsPage(session: widget.session)));
    if (mounted) _loadSavedIds();
  }

  void _openSearch() => Navigator.push<void>(
      context, MaterialPageRoute<void>(settings: const RouteSettings(name: 'search'), builder: (_) => SearchPage(session: widget.session)));

  String _tabLabel(int i) {
    final l = context.l10n;
    return switch (i) { 0 => l.newsTypeNews, 1 => l.newsTypeAnnouncement, _ => l.newsTypeEvent };
  }

  /// "14:32" (bugün) ya da "20 Ekim 14:32"; ayrıştırılamazsa null.
  String? _lastUpdateText() {
    final inst = _lastSuccess == null ? null : DateTime.tryParse(_lastSuccess!);
    if (inst == null) return null;
    final d = istanbulWall(inst);
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final n = istanbulWall(DateTime.now());
    final today = d.year == n.year && d.month == n.month && d.day == n.day;
    return context.l10n.p63NewsLastUpdate(today ? hm : '${d.day} ${newsMonthName(context, d.month)} $hm');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final loading = !_loaded && _error == null;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık satırı: [geri] Haberler ... [ara] [favoriler]; 40 dp daireler (48 dp dokunma alanı), yan 20 dp.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                Navigator.canPop(context) ? 16 : 20, MediaQuery.paddingOf(context).top + 12, 16, 0),
            child: Row(children: [
              if (Navigator.canPop(context))
                IcerikIconButton(
                    icon: buDirIcon(context, BuIcons.arrowLeft), label: l.commonBack, shadow: true, onTap: () => Navigator.maybePop(context)),
              if (Navigator.canPop(context)) const SizedBox(width: 4),
              Expanded(
                child: Semantics(header: true, label: l.icerikNewsTitle, child: const SizedBox(height: 48)),
              ),
              IcerikIconButton(
                  key: const ValueKey('news-search'), icon: BuIcons.search, label: l.commonSearchHint, shadow: true, onTap: _openSearch),
              IcerikIconButton(
                  key: const ValueKey('news-favorites'), icon: BuIcons.bookmark, label: l.icerikFavorites, shadow: true, onTap: _openFavorites),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: IcerikUnderlineTabs(
              labels: [for (var i = 0; i < _types.length; i++) _tabLabel(i)],
              index: _tab,
              keyPrefix: 'news-tab-',
              semanticLabel: l.icerikNewsTypeTabs,
              onChanged: _selectTab,
            ),
          ),
          Expanded(
            child: BuSwapIn(
              loading: loading,
              skeleton: const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Padding(padding: EdgeInsets.only(top: 16), child: IcerikListSkeleton(featured: false)),
              ),
              child: BuRefreshIndicator(
                onRefresh: Analytics.pullRefresh(_refresh),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_maintenance)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: IcerikNotice(text: l.icerikMaintenance, icon: BuIcons.refreshCw, sub: _lastUpdateText()),
                        ),
                      ),
                    // Bölümüm: yalnız Duyuru sekmesinde; eşleşme/veri yoksa hiçbir şey çizilmez.
                    if (_type == 'DUYURU') SliverToBoxAdapter(child: UnitNewsStrip(session: widget.session, refresh: _unitTick)),
                    ..._slivers(),
                    SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _slivers() {
    final l = context.l10n;
    final t = context.bu;
    if (_error != null && !_loaded) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: IcerikErrorCard(title: l.p05ListErrorTitle, retryLabel: l.commonRetry, onRetry: _reload),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      // Boş: ortada soluk tek cümle (illüstrasyon yok).
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text(l.icerikNewsEmpty,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, color: t.mut)),
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
        label: l.icerikNewsList,
        sliver: BuStaggerScope(
          key: ValueKey('$_tab-$_gen'),
          child: SliverMainAxisGroup(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.separated(
                itemCount: rest.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, i) {
                  final n = rest[i];
                  return BuStaggerItem(
                    index: i,
                    child: NewsTile(
                      item: n,
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
              label: context.l10n.commonRetry, compact: true, kind: BuButtonKind.outline, onPressed: _retryMore),
        ),
      );
    }
    if (_loading && _page > 0) {
      return IcerikLoadMore(text: context.l10n.p05NewsLoadingMore);
    }
    return const SizedBox(height: 4);
  }
}
