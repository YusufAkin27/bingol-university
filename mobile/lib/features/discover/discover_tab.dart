import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart';
import '../search/search_page.dart';

/// Keşfet sekmesi: haber / duyuru / etkinlik akışı ve kaydedilenler.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.session, required this.typeRequest});

  final Session session;

  /// Ana sayfadaki "Tümü" bağlantıları buraya 'HABER' | 'DUYURU' | 'ETKINLIK' yazar; sekme filtreyi seçer ve değeri null'lar.
  final ValueNotifier<String?> typeRequest;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  static const _types = ['HABER', 'DUYURU', 'ETKINLIK', 'SAVED'];
  static const _labels = ['Haberler', 'Duyurular', 'Etkinlikler', 'Kaydedilenler'];
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  final Set<int> _savedIds = {};

  int _tab = 0;
  int _gen = 0; // eski yanıtların yeni sekmeyi ezmesini önler
  int _page = 0;
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  bool _maintenance = false;
  String? _maintenanceText;
  Object? _error;

  String get _type => _types[_tab];
  bool get _isSaved => _type == 'SAVED';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.typeRequest.addListener(_onTypeRequest);
    _consumeRequest(initial: true);
    _loadStatus();
    _loadSavedIds();
    _reload();
  }

  @override
  void didUpdateWidget(DiscoverTab old) {
    super.didUpdateWidget(old);
    if (old.typeRequest != widget.typeRequest) {
      old.typeRequest.removeListener(_onTypeRequest);
      widget.typeRequest.addListener(_onTypeRequest);
    }
  }

  @override
  void dispose() {
    widget.typeRequest.removeListener(_onTypeRequest);
    _scroll.dispose();
    super.dispose();
  }

  void _onTypeRequest() => _consumeRequest();

  void _consumeRequest({bool initial = false}) {
    final v = widget.typeRequest.value;
    if (v == null) return;
    final i = _types.indexOf(v);
    widget.typeRequest.value = null;
    if (i < 0 || i == 3) return;
    if (initial) {
      _tab = i;
    } else if (i != _tab) {
      _selectTab(i);
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadStatus() async {
    try {
      final r = await widget.session.api.get('/status');
      var m = false;
      String? msg;
      if (r is Map && r['NEWS'] is Map) {
        final news = r['NEWS'] as Map;
        m = news['maintenance'] == true;
        final text = news['maintenanceMessage'];
        if (m && text is String && text.trim().isNotEmpty) msg = text.trim();
      }
      if (mounted) {
        setState(() {
          _maintenance = m;
          _maintenanceText = msg;
        });
      }
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

  /// İlk sayfayı yeniden çeker (sekme değişimi, çekmeyle yenile, yeniden dene).
  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _items.clear();
      _page = 0;
      _cursor = null;
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
    _cursor = null;
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
    final api = widget.session.api;
    try {
      final fresh = <Map<String, dynamic>>[];
      bool more;
      int? nextCursor;
      int nextPage = _page;
      if (_isSaved) {
        final c = _cursor == null ? '' : '&cursor=$_cursor';
        final r = await api.get('/bookmarks?size=$_pageSize$c') as Map<String, dynamic>;
        for (final b in (r['items'] as List? ?? [])) {
          final news = (b as Map<String, dynamic>)['news'];
          if (news is Map<String, dynamic>) fresh.add(news);
        }
        nextCursor = (r['nextCursor'] as num?)?.toInt();
        more = nextCursor != null;
      } else {
        final r = await api.get('/news?type=$_type&page=$_page&size=$_pageSize') as Map<String, dynamic>;
        for (final e in (r['items'] as List? ?? [])) {
          fresh.add(e as Map<String, dynamic>);
        }
        final total = (r['totalPages'] as num?)?.toInt() ?? 0;
        nextPage = _page + 1;
        more = nextPage < total;
      }
      if (!mounted || gen != _gen) return;
      setState(() {
        if (replace) _items.clear();
        _items.addAll(fresh);
        _cursor = nextCursor;
        _page = nextPage;
        _hasMore = more;
        _loaded = true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        if (replace && _loaded) {
          // Yenileme başarısız: mevcut liste kalır, yalnızca uyarı.
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
    final idx = _items.indexOf(n);
    setState(() {
      if (was) {
        _savedIds.remove(id);
        if (_isSaved) _items.remove(n);
      } else {
        _savedIds.add(id);
      }
    });
    try {
      if (was) {
        await widget.session.api.delete('/bookmarks/news/$id');
      } else {
        await widget.session.api.put('/bookmarks/news/$id');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (was) {
          _savedIds.add(id);
          if (_isSaved && idx >= 0) _items.insert(idx.clamp(0, _items.length), n);
        } else {
          _savedIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    await Navigator.push(
      context,
      MaterialPageRoute(
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

  Widget _body(BuTokens t) {
    if (!_loaded && _error == null) return const LoadingView();
    if (_error != null && !_loaded) {
      return ErrorView(error: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [
            SizedBox(
              height: 320,
              child: EmptyView(
                icon: _isSaved ? LucideIcons.bookmark : LucideIcons.newspaper,
                text: _isSaved
                    ? 'Henüz kaydettiğiniz bir haber yok.'
                    : 'Bu kategoride henüz içerik yok.',
              ),
            ),
          ],
        ),
      );
    }

    final featured = !_isSaved;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, kNavInset),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) return _footer(t);
          final n = _items[i];
          final id = (n['id'] as num).toInt();
          final saved = _savedIds.contains(id);
          final Widget w = (featured && i == 0)
              ? NewsFeaturedCard(
                  item: n, saved: saved, onTap: () => _open(n), onToggleSave: () => _toggleSave(n))
              : NewsTile(
                  item: n, saved: saved, onTap: () => _open(n), onToggleSave: () => _toggleSave(n));
          return Padding(
            padding: EdgeInsets.only(bottom: i == 0 && featured ? 14 : 10),
            child: w,
          );
        },
      ),
    );
  }

  Widget _footer(BuTokens t) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: BuButton(label: 'Yeniden dene', compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Keşfet',
            actions: [
              BuIconButton(
                icon: LucideIcons.search,
                tooltip: 'Ara',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SearchPage(session: widget.session)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(
                child: BuChip(label: _labels[i], selected: i == _tab, onTap: () => _selectTab(i)),
              ),
            ),
          ),
          if (_maintenance && !_isSaved)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StaleBanner(
                  text: _maintenanceText ?? 'Kaynak site şu an bakımda. Veriler güncel olmayabilir.'),
            ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }
}
