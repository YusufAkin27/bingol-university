import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'post_api.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_media_gallery.dart';
import 'post_media_view.dart';
import 'post_models.dart';
import 'post_routes.dart';

/// Dışarıdan akışa gönderi eklemek/yenilemek için (örn. oluşturma sonrası).
class PostFeedController {
  _PostFeedViewState? _state;

  /// Yeni gönderiyi akışın başına ekler.
  void insertPost(Post post) => _state?._insert(post);

  /// İlk sayfayı yeniden çeker.
  Future<void> refresh() async => _state?._refresh();

  /// Listenin başına kaydırır.
  void scrollToTop() => _state?._toTop();
}

/// Keşfet > Gönderiler: `scope` (latest | popular) akışı, imleçli sonsuz kaydırma, çekip yenileme.
class PostFeedView extends StatefulWidget {
  const PostFeedView({
    super.key,
    required this.session,
    this.scope = 'latest',
    this.controller,
    this.mediaBuilder,
    this.likeBuilder,
    this.menuBuilder,
    this.emptyBuilder,
    this.header,
  });

  final Session session;
  final String scope;

  /// Akış boşken gösterilecek özel içerik (örn. Takip: önerilen kişiler). Verilmezse varsayılan boş görünüm.
  final WidgetBuilder? emptyBuilder;

  /// Listenin ilk öğesi olarak kaydırılan üst bölüm (hikâye şeridi, trend etiketler). Hata ekranı dışında hep görünür.
  final Widget? header;
  final PostFeedController? controller;
  final PostMediaBuilder? mediaBuilder;
  final PostLikeBuilder? likeBuilder;
  final PostMenuBuilder? menuBuilder;

  @override
  State<PostFeedView> createState() => _PostFeedViewState();
}

class _PostFeedViewState extends State<PostFeedView> {
  static const _pageSize = 10;

  final _scroll = ScrollController();
  final List<Post> _items = [];
  late PostApi _api;

  int _gen = 0; // kapsam değişiminde eski yanıtları eler
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  Object? _error; // ilk yükleme hatası
  Object? _moreError; // sonraki sayfa hatası

  @override
  void initState() {
    super.initState();
    _api = PostApi(widget.session);
    widget.controller?._state = this;
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void didUpdateWidget(PostFeedView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    if (old.session != widget.session) _api = PostApi(widget.session);
    if (old.scope != widget.scope) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _reload();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) _loadMore();
  }

  void _toTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _insert(Post p) {
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.id == p.id);
      _items.insert(0, p);
      _loaded = true;
      _error = null;
    });
    _toTop();
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _loaded = false;
      _loading = false;
      _error = null;
      _moreError = null;
    });
    await _fetch(gen);
  }

  Future<void> _refresh() async {
    final gen = ++_gen;
    _cursor = null;
    await _fetch(gen, replace: true);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_loaded) return;
    await _fetch(_gen);
  }

  Future<void> _fetch(int gen, {bool replace = false}) async {
    if (_loading && !replace) return;
    setState(() {
      _loading = true;
      if (!replace) _moreError = null;
    });
    try {
      final page = await _api.feed(scope: widget.scope, cursor: replace ? null : _cursor, size: _pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        if (replace) _items.clear();
        final seen = {for (final e in _items) e.id};
        _items.addAll(page.items.where((e) => seen.add(e.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loaded = true;
        _loading = false;
        _error = null;
        _moreError = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        if (!_loaded) {
          _error = e;
        } else if (replace) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
        } else {
          _moreError = e;
        }
      });
    }
  }

  void _changed(Post p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i < 0 || !mounted) return;
    setState(() => _items[i] = p);
  }

  void _deleted(int id) {
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == id));
  }

  Future<void> _open(Post p) async {
    final r = await openPostDetail(context, widget.session, p.id, initial: p);
    if (r != null) _changed(r);
  }

  // Varsayılan parçalar: M5 medya görünümü, M4 beğeni düğmesi ve işlem menüsü.
  Widget _media(BuildContext c, Post p) => PostMediaView(
        session: widget.session,
        media: p.media,
        autoplay: true,
        onOpen: (i) => openPostMediaGallery(c, widget.session, p.media, i),
      );

  Widget _like(BuildContext c, Post p, ValueChanged<Post> cb) =>
      LikeButton(session: widget.session, post: p, onChanged: cb);

  Widget _menu(BuildContext c, Post p, ValueChanged<Post> cb, ValueChanged<int> del) =>
      PostMenuButton(session: widget.session, post: p, onChanged: cb, onDeleted: del);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final header = widget.header;
    if (!_loaded && _error == null) return _FeedSkeleton(header: header);
    if (_error != null && !_loaded) {
      final err = ErrorView(error: _error!, onRetry: _reload);
      return header == null ? err : Column(children: [header, Expanded(child: err)]);
    }
    if (_items.isEmpty && widget.emptyBuilder != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [if (header != null) header, widget.emptyBuilder!(context)],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [
            if (header != null) header,
            const SizedBox(
              height: 320,
              child: EmptyView(
                  icon: LucideIcons.messageSquareText, text: 'Henüz gönderi yok. İlk gönderiyi sen paylaş!'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, kNavInset),
        itemCount: _items.length + 1 + (header == null ? 0 : 1),
        itemBuilder: (context, i) {
          if (header != null) {
            if (i == 0) return header;
            i--;
          }
          if (i == _items.length) return _footer(t);
          final p = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              key: ValueKey('post-${p.id}'),
              session: widget.session,
              post: p,
              onChanged: _changed,
              onDeleted: _deleted,
              onOpen: _open,
              mediaBuilder: widget.mediaBuilder ?? _media,
              likeBuilder: widget.likeBuilder ?? _like,
              menuBuilder: widget.menuBuilder ?? _menu,
            ),
          );
        },
      ),
    );
  }

  Widget _footer(BuTokens t) {
    if (_moreError != null) {
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
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(6)),
        );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        if (header != null) header!,
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(120, 12), const SizedBox(height: 6), bar(80, 10)]),
                ]),
                const SizedBox(height: 14),
                bar(double.infinity, 12),
                const SizedBox(height: 8),
                bar(220, 12),
                const SizedBox(height: 14),
                Container(height: 120, decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12))),
              ],
            ),
          ),
      ],
    );
  }
}
