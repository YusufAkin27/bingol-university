import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../news/icerik_parts.dart' show IcerikNotice;
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/post_routes.dart';
import 'recent_searches.dart';
import 'user_search_result_tile.dart';

/// Genel arama sonuç sekmeleri.
enum GlobalSearchTab { all, users, posts, reels }

/// Tam ekran genel arama (Keşfet arama ikonu): geri + yuvarlak arama alanı, sekmeler Tümü | Kullanıcılar | Gönderiler |
/// Reels. 300 ms bekletmeli, sayfalı; boş/hata/yükleniyor durumları; kullanıcıya özel arama geçmişi (cihazda,
/// çıkışta silinir). Gizli/engellenmiş/askıdaki hesaplar sunucuda elenir. Haber/kulüp/etkinlik araması ayrı
/// `SearchPage`'dedir (Ana Sayfa).
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, required this.session, this.initialQuery, this.initialTab = GlobalSearchTab.all});

  final Session session;
  final String? initialQuery;
  final GlobalSearchTab initialTab;

  /// Keşfet arama ikonu bunu açar: `Navigator.push(context, GlobalSearchScreen.route(session))`.
  static Route<void> route(Session session, {String? initialQuery, GlobalSearchTab initialTab = GlobalSearchTab.all}) =>
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'global_search'),
        builder: (_) => GlobalSearchScreen(session: session, initialQuery: initialQuery, initialTab: initialTab),
      );

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

/// Gönderi/reel arama sonucu.
class SearchPostHit {
  const SearchPostHit({required this.id, required this.author, this.text, this.imageUrl, this.likes});

  factory SearchPostHit.fromJson(Map<dynamic, dynamic> h) => SearchPostHit(
        id: (h['targetId'] as num).toInt(),
        author: '${h['title'] ?? ''}'.trim(),
        text: (h['snippet'] as String?)?.trim(),
        imageUrl: (h['imageUrl'] is String && (h['imageUrl'] as String).isNotEmpty) ? h['imageUrl'] as String : null,
        likes: (h['likeCount'] as num?)?.toInt(),
      );

  final int id;
  final String author;
  final String? text;
  final String? imageUrl;
  final int? likes;
}

/// Bir sekmenin sayfalı durumu.
class _Paged<T> {
  final List<T> items = [];
  String? cursor;
  bool loading = false;
  bool loaded = false;
  bool done = false;
  bool preview = false; // "Tümü" sekmesi için küçük ilk sayfa
  bool unsupported = false; // sunucu bu türü bilmiyor (Reels araması henüz yoksa)
  Object? error;
  bool moreError = false;
  DateTime? cooldownUntil;
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  static const _pageSize = 20;
  static const _previewUsers = 5;
  static const _previewGrid = 4;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _seq = 0;

  late GlobalSearchTab _tab = widget.initialTab;
  String _query = '';
  List<String> _recent = [];
  var _users = _Paged<SearchUser>();
  var _posts = _Paged<SearchPostHit>();
  var _reels = _Paged<SearchPostHit>();

  bool get _active => _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadRecent();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.length >= 2) {
      _ctrl.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start(q));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ---------- geçmiş ----------

  Future<void> _loadRecent() async {
    final list = await RecentSearches.load();
    if (mounted && list.isNotEmpty) setState(() => _recent = list);
  }

  Future<void> _saveRecent(String q) async {
    q = q.trim();
    if (q.length < 2) return;
    final list = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())].take(RecentSearches.max).toList();
    if (mounted) setState(() => _recent = list);
    await RecentSearches.save(list);
  }

  Future<void> _removeRecent(int i) async {
    final list = [..._recent]..removeAt(i);
    setState(() => _recent = list);
    list.isEmpty ? await RecentSearches.clear() : await RecentSearches.save(list);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    await RecentSearches.clear();
  }

  // ---------- arama ----------

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      _seq++;
      setState(() {
        _query = '';
        _reset();
      });
      return;
    }
    if (q == _query) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _start(q));
  }

  void _submit(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) return;
    Analytics.instance.action('search_submit');
    _saveRecent(q);
    if (q != _query) _start(q);
  }

  void _useRecent(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _debounce?.cancel();
    Analytics.instance.action('search_submit', target: 'recent');
    _saveRecent(q);
    _start(q);
  }

  void _reset() {
    _users = _Paged<SearchUser>();
    _posts = _Paged<SearchPostHit>();
    _reels = _Paged<SearchPostHit>();
  }

  void _start(String q) {
    if (!mounted) return;
    _seq++;
    setState(() {
      _query = q;
      _reset();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadTab(_tab);
  }

  void _selectTab(GlobalSearchTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_active) _loadTab(tab);
  }

  /// Sekmenin gereken sayfalarını başlatır ("Tümü": üç küçük önizleme).
  void _loadTab(GlobalSearchTab tab) {
    switch (tab) {
      case GlobalSearchTab.all:
        if (!_users.loaded && !_users.loading) _loadUsers(preview: true);
        if (!_posts.loaded && !_posts.loading) _loadPosts(reels: false, preview: true);
        if (!_reels.loaded && !_reels.loading) _loadPosts(reels: true, preview: true);
      case GlobalSearchTab.users:
        _loadUsers();
      case GlobalSearchTab.posts:
        _loadPosts(reels: false);
      case GlobalSearchTab.reels:
        _loadPosts(reels: true);
    }
  }

  void _onScroll() {
    if (_tab == GlobalSearchTab.all || !_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      switch (_tab) {
        case GlobalSearchTab.users:
          _loadUsers();
        case GlobalSearchTab.posts:
          _loadPosts(reels: false);
        case GlobalSearchTab.reels:
          _loadPosts(reels: true);
        case GlobalSearchTab.all:
          break;
      }
    }
  }

  bool _cooling(_Paged p) => p.cooldownUntil != null && DateTime.now().isBefore(p.cooldownUntil!);

  String? _cursorOf(Object? r) {
    final c = r is Map ? r['nextCursor'] : null;
    return c == null ? null : '$c';
  }

  Future<void> _loadUsers({bool preview = false}) async {
    if (!preview && _users.preview) setState(() => _users = _Paged<SearchUser>());
    final p = _users;
    if (p.loading || p.done || _query.isEmpty || _cooling(p)) return;
    final seq = _seq;
    final q = _query;
    setState(() {
      p.loading = true;
      p.error = null;
      p.moreError = false;
      p.preview = preview;
    });
    try {
      final size = preview ? _previewUsers : _pageSize;
      final c = p.cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(p.cursor!)}';
      final r = await widget.session.api.get('/users/search?q=${Uri.encodeQueryComponent(q)}&size=$size$c');
      if (!mounted || seq != _seq || p != _users) return;
      final fresh = <SearchUser>[
        for (final u in (r is Map ? r['items'] : null) as List? ?? const [])
          if (u is Map && u['id'] is num) SearchUser.fromJson(u),
      ];
      final seen = p.items.map((e) => e.id).toSet();
      setState(() {
        p.items.addAll(fresh.where((e) => seen.add(e.id)));
        p.cursor = _cursorOf(r);
        p.done = p.cursor == null || fresh.isEmpty;
        p.loaded = true;
        p.loading = false;
      });
    } catch (e) {
      _fail(p, e, seq, () => p != _users);
    }
  }

  Future<void> _loadPosts({required bool reels, bool preview = false}) async {
    var p = reels ? _reels : _posts;
    if (!preview && p.preview) {
      p = _Paged<SearchPostHit>();
      reels ? _reels = p : _posts = p;
      setState(() {});
    }
    if (p.loading || p.done || _query.isEmpty || _cooling(p) || p.unsupported) return;
    final seq = _seq;
    final q = _query;
    final page = p;
    setState(() {
      page.loading = true;
      page.error = null;
      page.moreError = false;
      page.preview = preview;
    });
    try {
      final limit = preview ? _previewGrid + 2 : _pageSize;
      final c = page.cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(page.cursor!)}';
      final type = reels ? 'REELS' : 'POSTS';
      final r = await widget.session.api.get('/search?q=${Uri.encodeQueryComponent(q)}&type=$type&limit=$limit$c');
      if (!mounted || seq != _seq || page != (reels ? _reels : _posts)) return;
      final fresh = <SearchPostHit>[];
      for (final g in (r is Map ? r['groups'] : null) as List? ?? const []) {
        for (final h in (g is Map ? g['items'] : null) as List? ?? const []) {
          if (h is Map && h['targetId'] is num) fresh.add(SearchPostHit.fromJson(h));
        }
      }
      final seen = page.items.map((e) => e.id).toSet();
      setState(() {
        page.items.addAll(fresh.where((e) => seen.add(e.id)));
        page.cursor = _cursorOf(r);
        page.done = page.cursor == null || fresh.isEmpty;
        page.loaded = true;
        page.loading = false;
      });
    } catch (e) {
      // Reels araması sunucuda henüz yoksa (türü tanımaz): hata değil, "desteklenmiyor" durumu.
      if (reels && e is ApiError && e.status >= 400 && e.status < 500 && e.status != 429 && e.status != 401 && e.status != 403) {
        if (mounted && seq == _seq && page == _reels) {
          setState(() {
            page.unsupported = true;
            page.loaded = true;
            page.loading = false;
            page.done = true;
          });
        }
        return;
      }
      _fail(page, e, seq, () => page != (reels ? _reels : _posts));
    }
  }

  void _fail(_Paged p, Object e, int seq, bool Function() stale) {
    if (!mounted || seq != _seq || stale()) return;
    setState(() {
      p.loading = false;
      if (e is ApiError && e.status == 429) {
        p.cooldownUntil = DateTime.now().add(Duration(seconds: e.retryAfter ?? 15));
        BuToast.show(context, context.l10n.searchTooMany, kind: BuToastKind.warning);
      }
      if (p.loaded) {
        p.moreError = true;
      } else {
        p.error = e;
      }
    });
  }

  void _retry(GlobalSearchTab tab) {
    switch (tab) {
      case GlobalSearchTab.all:
        _users = _Paged<SearchUser>();
        _posts = _Paged<SearchPostHit>();
        _reels = _Paged<SearchPostHit>();
      case GlobalSearchTab.users:
        _users = _Paged<SearchUser>();
      case GlobalSearchTab.posts:
        _posts = _Paged<SearchPostHit>();
      case GlobalSearchTab.reels:
        _reels = _Paged<SearchPostHit>();
    }
    setState(() {});
    _loadTab(tab);
  }

  Future<void> _refresh() async {
    final seq = _seq + 1;
    _start(_query);
    // Yenileme göstergesi ilk sayfa gelene kadar sürer.
    for (var i = 0; i < 40 && mounted && _seq == seq; i++) {
      final busy = switch (_tab) {
        GlobalSearchTab.all => _users.loading || _posts.loading || _reels.loading,
        GlobalSearchTab.users => _users.loading,
        GlobalSearchTab.posts => _posts.loading,
        GlobalSearchTab.reels => _reels.loading,
      };
      if (!busy) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _openPost(SearchPostHit h) {
    _saveRecent(_query);
    openPostDetail(context, widget.session, h.id);
  }

  // ---------- görünüm ----------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12, MediaQuery.paddingOf(context).top + 12, 16, 0),
          child: Row(children: [
            BuIconButton(icon: buDirIcon(context, BuIcons.arrowLeft), tooltip: l.commonBack, onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 8),
            Expanded(child: _SearchField(controller: _ctrl, hint: l.srSearchHint, onChanged: _onChanged, onSubmitted: _submit)),
          ]),
        ),
        Semantics(
          container: true,
          label: l.srSearchTabsLabel,
          child: _TabChips(
            labels: [l.searchAll, l.srTabUsers, l.srTabPosts, l.srTabReels],
            selected: _tab.index,
            onSelected: (i) => _selectTab(GlobalSearchTab.values[i]),
          ),
        ),
        Expanded(
          child: BuFadeThrough(
            child: KeyedSubtree(
              key: ValueKey('$_active-${_tab.name}'),
              child: _active ? _results(t) : _suggestions(t),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _suggestions(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(l.srSearchPrompt, style: tx.bodyMedium!.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
        ),
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.searchRecent, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: _clearRecent,
              child: Text(l.searchClearRecent, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.pr)),
            ),
          ]),
          for (var i = 0; i < _recent.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    key: ValueKey('recent-$i'),
                    onTap: () => _useRecent(_recent[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(children: [
                        const SizedBox(width: 4),
                        Icon(BuIcons.clock, size: 18, color: t.mut),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_recent[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 15, color: t.ink)),
                        ),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.p05SearchRemoveRecent,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => _removeRecent(i),
                  icon: Icon(BuIcons.x, size: 16, color: t.mut),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _results(BuTokens t) {
    final l = context.l10n;
    final pad = EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24);
    switch (_tab) {
      case GlobalSearchTab.all:
        final ps = [_users, _posts, _reels];
        final waiting = ps.any((p) => !p.loaded && p.error == null && !p.unsupported);
        final hasAny = _users.items.isNotEmpty || _posts.items.isNotEmpty || _reels.items.isNotEmpty;
        if (!hasAny) {
          if (waiting) return const BuSkeletonList(itemCount: 7);
          // Kullanıcı + gönderi ikisi de hata verdiyse genel hata.
          if (_users.error != null && _posts.error != null) return _errorState(_users.error!, () => _retry(GlobalSearchTab.all));
          return _emptyState();
        }
        return _scrollBody(pad, [
          if (_users.items.isNotEmpty) ...[
            _sectionHeader(t, l.srTabUsers, GlobalSearchTab.users, more: _users.items.length >= _previewUsers || !_users.done),
            SliverList.builder(
              itemCount: _users.items.length.clamp(0, _previewUsers),
              itemBuilder: (_, i) => _userTile(_users.items[i]),
            ),
          ],
          if (_posts.items.isNotEmpty) ...[
            _sectionHeader(t, l.srTabPosts, GlobalSearchTab.posts, more: _posts.items.length > _previewGrid || !_posts.done),
            _grid(_posts.items.take(_previewGrid).toList(), reel: false),
          ],
          if (_reels.items.isNotEmpty) ...[
            _sectionHeader(t, l.srTabReels, GlobalSearchTab.reels, more: _reels.items.length > _previewGrid || !_reels.done),
            _grid(_reels.items.take(_previewGrid).toList(), reel: true),
          ],
        ]);
      case GlobalSearchTab.users:
        final p = _users;
        if (p.error != null) return _errorState(p.error!, () => _retry(_tab));
        if (!p.loaded) return const BuSkeletonList(itemCount: 7);
        if (p.items.isEmpty) return _emptyState();
        return _scrollBody(pad, [
          SliverList.builder(itemCount: p.items.length, itemBuilder: (_, i) => _userTile(p.items[i])),
          _footer(p, () => _loadUsers()),
        ]);
      case GlobalSearchTab.posts:
      case GlobalSearchTab.reels:
        final reels = _tab == GlobalSearchTab.reels;
        final p = reels ? _reels : _posts;
        if (p.unsupported) return _emptyState(message: l.srReelsUnavailable);
        if (p.error != null) return _errorState(p.error!, () => _retry(_tab));
        if (!p.loaded) return const BuSkeletonList(variant: BuSkeletonVariant.grid, itemCount: 6);
        if (p.items.isEmpty) return _emptyState();
        return _scrollBody(pad, [
          _grid(p.items, reel: reels),
          _footer(p, () => _loadPosts(reels: reels)),
        ]);
    }
  }

  Widget _scrollBody(EdgeInsets pad, List<Widget> slivers) => RefreshIndicator(
        color: context.bu.pr,
        backgroundColor: context.bu.sf3,
        onRefresh: _refresh,
        child: CustomScrollView(
          key: ValueKey('results-${_tab.name}'),
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [...slivers, SliverPadding(padding: pad)],
        ),
      );

  Widget _userTile(SearchUser u) => UserSearchResultTile(
        session: widget.session,
        user: u,
        query: _query,
        onOpen: () => _saveRecent(_query),
      );

  Widget _sectionHeader(BuTokens t, String title, GlobalSearchTab tab, {required bool more}) {
    final tx = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: tx.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink)),
            ),
          ),
          if (more)
            TextButton(
              key: ValueKey('see-all-${tab.name}'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => _selectTab(tab),
              child: Text(context.l10n.srSeeAll, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.pr)),
            ),
        ]),
      ),
    );
  }

  Widget _grid(List<SearchPostHit> items, {required bool reel}) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .78,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => SearchPostTile(
            key: ValueKey('search-${reel ? 'reel' : 'post'}-${items[i].id}'),
            hit: items[i],
            reel: reel,
            headers: postAuthHeaders(widget.session),
            onTap: () => _openPost(items[i]),
          ),
        ),
      );

  Widget _footer(_Paged p, VoidCallback retry) {
    if (p.moreError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            if (_cooling(p))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.l10n.searchTooMany,
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.mut)),
              ),
            BuButton(
              label: context.l10n.commonRetry,
              compact: true,
              kind: BuButtonKind.outline,
              onPressed: () {
                p.cooldownUntil = null;
                retry();
              },
            ),
          ]),
        ),
      );
    }
    if (p.loading) {
      return const SliverToBoxAdapter(child: BuSkeletonList(itemCount: 2, shrinkWrap: true, padding: EdgeInsets.fromLTRB(20, 8, 20, 8)));
    }
    return const SliverToBoxAdapter(child: SizedBox(height: 4));
  }

  Widget _emptyState({String? message}) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
      children: [
        Text(message ?? l.searchNoResults,
            textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink)),
        if (message == null) ...[
          const SizedBox(height: 8),
          Text(l.p05SearchNoResultsBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut)),
        ],
      ],
    );
  }

  Widget _errorState(Object error, VoidCallback onRetry) {
    final limited = error is ApiError && error.status == 429;
    if (limited) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        IcerikNotice(text: context.l10n.searchTooMany, icon: BuIcons.clock),
        const SizedBox(height: 12),
        BuButton(label: context.l10n.commonRetry, kind: BuButtonKind.outline, compact: true, onPressed: onRetry),
      ]);
    }
    return BuErrorState(error: error, title: context.l10n.p05SearchErrorTitle, onRetry: onRetry, compact: true);
  }
}

/// Gönderi/reel sonuç karosu: görsel + alt gradyan + yazar adı + beğeni; reel için sağ üstte oynat rozeti.
class SearchPostTile extends StatelessWidget {
  const SearchPostTile({super.key, required this.hit, required this.reel, required this.onTap, this.headers});

  final SearchPostHit hit;
  final bool reel;
  final VoidCallback onTap;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final label = [
      l.srPostByAuthor(hit.author),
      if ((hit.text ?? '').isNotEmpty) hit.text!,
      if (reel) l.srVideoBadge,
      if (hit.likes != null) l.srLikeCount('${hit.likes}'),
    ].join(', ');
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .98,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            BuImage(hit.imageUrl, headers: headers, fit: BoxFit.cover, placeholderIcon: reel ? BuIcons.video : BuIcons.image, maxDecodeWidth: 600),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .66)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 24, 10, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(hit.author,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.onMedia)),
                    ),
                    if (hit.likes != null) ...[
                      const SizedBox(width: 6),
                      Icon(BuIcons.heart, size: 13, color: t.onMedia),
                      const SizedBox(width: 3),
                      Text('${hit.likes}', style: tx.labelMedium!.copyWith(fontSize: 12, color: t.onMedia)),
                    ],
                  ]),
                ),
              ),
            ),
            if (reel)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: t.scrim.withValues(alpha: .5), shape: BoxShape.circle),
                  child: Icon(BuIcons.playFilled, size: 14, color: t.onMedia),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Arama alanı: 48 dp yuvarlak, sol büyüteç, sağda temizle (X); odakta marka çerçevesi; açılışta klavye.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged, required this.onSubmitted});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: BuMotion.of(context, BuMotion.short),
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 14),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: focused ? t.pr : t.bdStrong, width: focused ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(BuIcons.search, size: 18, color: t.mut),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const ValueKey('globalSearchField'),
            controller: widget.controller,
            focusNode: _focus,
            autofocus: true,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.search,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 14, color: t.mut),
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, v, _) => v.text.isEmpty
              ? const SizedBox(width: 14)
              : IconButton(
                  key: const ValueKey('globalSearchClear'),
                  tooltip: l.searchClear,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                  icon: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                    child: Icon(BuIcons.x, size: 14, color: t.mut),
                  ),
                ),
        ),
      ]),
    );
  }
}

/// Sekme çipleri (4): yatay kaydırılır, seçili çip görünür kaydırılır; seçili = `soft` zemin + marka metni.
class _TabChips extends StatefulWidget {
  const _TabChips({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_TabChips> createState() => _TabChipsState();
}

class _TabChipsState extends State<_TabChips> {
  late final List<GlobalKey> _keys = [for (final _ in widget.labels) GlobalKey()];

  @override
  void didUpdateWidget(_TabChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _keys[widget.selected].currentContext;
        if (!mounted || c == null) return;
        Scrollable.ensureVisible(c, alignment: .5, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.emphasized);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (var i = 0; i < widget.labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              key: _keys[i],
              selected: i == widget.selected,
              child: BuPressable(
                key: ValueKey('global-search-tab-$i'),
                onTap: () {
                  BuHaptics.selection();
                  widget.onSelected(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: AnimatedContainer(
                      duration: BuMotion.of(context, BuMotion.short),
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == widget.selected ? t.soft : t.sf,
                        borderRadius: BorderRadius.circular(BuRadius.pill),
                        border: Border.all(color: i == widget.selected ? t.soft : t.bd),
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: BuMotion.of(context, BuMotion.short),
                        style: tx.labelLarge!.copyWith(
                          fontSize: 13,
                          fontWeight: i == widget.selected ? FontWeight.w600 : FontWeight.w400,
                          color: i == widget.selected ? t.pr : t.ink,
                        ),
                        child: Text(widget.labels[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
