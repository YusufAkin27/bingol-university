import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../posts/like_button.dart';
import '../posts/post_api.dart';
import '../posts/post_card.dart';
import '../posts/post_models.dart';
import '../posts/post_routes.dart';

/// Keşfet akışına dışarıdan gönderi eklemek/yenilemek için (örn. oluşturma sonrası).
class DiscoverFeedController {
  _DiscoverMasonryFeedState? _state;

  void insertPost(Post post) => _state?._insert(post);

  Future<void> refresh() async => _state?._refresh();
}

/// Keşfet: yalnız öğrenci gönderileri, tek sütun akış (dosya adı eski masonry düzeninden kalmadır). İmleçli sonsuz
/// kaydırma, çekip yenileme, iskelet / hata / boş durumları. Engelleme/gizlilik süzmesi sunucudadır (`/feed`).
/// [header] akışla birlikte kayar (başlık, arama, çipler, öneriler). [scope] değişince akış baştan yüklenir.
class DiscoverMasonryFeed extends StatefulWidget {
  const DiscoverMasonryFeed({super.key, required this.session, this.controller, this.header, this.scope = 'top'});

  final Session session;
  final DiscoverFeedController? controller;
  final Widget? header;
  final String scope;

  @override
  State<DiscoverMasonryFeed> createState() => _DiscoverMasonryFeedState();
}

class _DiscoverMasonryFeedState extends State<DiscoverMasonryFeed> {
  // Sunucu varsayılanı 12 (en çok 30). Sıralama sunucudadır; istemci yeniden sıralamaz.
  static const _pageSize = 12;

  final _scroll = ScrollController();
  final List<Post> _items = [];
  late PostApi _api;

  int _gen = 0;
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  Object? _moreError;

  @override
  void initState() {
    super.initState();
    _api = PostApi(widget.session);
    widget.controller?._state = this;
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void didUpdateWidget(DiscoverMasonryFeed old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    if (old.session != widget.session) _api = PostApi(widget.session);
    if (old.scope != widget.scope) _reload();
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

  void _insert(Post p) {
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.id == p.id);
      _items.insert(0, p);
      _loaded = true;
      _error = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
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
      // nextCursor opaktır: aynen geri gönderilir. Puan yenilenince (hint=RANK_REFRESHED) kopya gelebilir;
      // id ile tekilleştirme aşağıda zaten yapılır.
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
      // İçerik ekranı doldurmuyorsa kaydırma olmayacağından sonraki sayfayı kendimiz iste.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasMore && _scroll.hasClients && _scroll.position.maxScrollExtent <= 0) _loadMore();
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      // Bozuk/başka kapsamın imleci: akışı baştan (imleçsiz) yükle.
      if (e is ApiError && e.code == 'POST_CURSOR_INVALID' && _cursor != null) {
        _loading = false;
        await _reload();
        return;
      }
      setState(() {
        _loading = false;
        if (!_loaded) {
          _error = e;
        } else if (replace) {
          BuToast.show(context, errorText(e), kind: BuToastKind.error);
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

  Future<void> _open(Post p) async {
    final r = await openPostDetail(context, widget.session, p.id, initial: p);
    if (r != null) _changed(r);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (!_loaded && _error == null) {
      body = const SliverToBoxAdapter(child: DiscoverFeedSkeleton());
    } else if (_error != null && !_loaded) {
      body = SliverToBoxAdapter(child: SizedBox(height: 360, child: ErrorView(error: _error!, onRetry: _reload)));
    } else if (_items.isEmpty) {
      body = SliverToBoxAdapter(
        child: SizedBox(height: 320, child: EmptyView(icon: LucideIcons.messageSquareText, text: context.l10n.postViewFeedEmpty)),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
        sliver: SliverList.separated(
          itemCount: _items.length,
          separatorBuilder: (_, __) => BuGap.h20,
          itemBuilder: (_, i) {
            final p = _items[i];
            return DiscoverPostCard(
              key: ValueKey('discover-post-${p.id}'),
              session: widget.session,
              post: p,
              onOpen: _open,
              onChanged: _changed,
            );
          },
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          body,
          SliverToBoxAdapter(child: _footer()),
          const SliverToBoxAdapter(child: SizedBox(height: kNavInset)),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: BuButton(label: context.l10n.postViewRetry, compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
        ),
      );
    }
    if (_loading && _loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: BuSkeletonScope(child: BuSkeleton.line(width: 120))),
      );
    }
    return BuGap.h4;
  }
}

/// Yükleniyor: tek sütun, iki gönderi kartı iskeleti (avatar + iki satır, 4:3 foto, beğeni + metin).
class DiscoverFeedSkeleton extends StatelessWidget {
  const DiscoverFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card() => DecoratedBox(
          decoration: BoxDecoration(
            color: context.bu.sf,
            borderRadius: BorderRadius.circular(BuRadius.lg),
            boxShadow: BuElevation.of(context, 1),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(14),
                child: Row(children: [
                  BuSkeleton.circle(36),
                  BuGap.w12,
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BuSkeleton.line(width: 110, height: 12),
                      BuGap.h6,
                      BuSkeleton.line(width: 72, height: 10),
                    ]),
                  ),
                ]),
              ),
              AspectRatio(aspectRatio: 4 / 3, child: BuSkeleton(height: double.infinity, radius: 0)),
              Padding(
                padding: EdgeInsets.all(BuSpace.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 90, height: 12),
                  BuGap.h12,
                  BuSkeleton.line(height: 12),
                ]),
              ),
            ],
          ),
        );
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Padding(
            key: const ValueKey('discoverSkeleton'),
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
            child: Column(children: [card(), BuGap.h20, card()]),
          ),
        ),
      ),
    );
  }
}

/// Akış kartı (Keşfet referansı): yazar satırı (avatar, ad • zaman, bölüm), tam genişlik 4:3 fotoğraf, beğeni sayacı
/// ("N beğeni") ve "ad metin" alt yazısı. Yorum, kaydet, paylaş yok. Fotoğrafa çift dokunuş beğenir.
class DiscoverPostCard extends StatefulWidget {
  const DiscoverPostCard({
    super.key,
    required this.session,
    required this.post,
    required this.onOpen,
    required this.onChanged,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post> onChanged;

  @override
  State<DiscoverPostCard> createState() => _DiscoverPostCardState();
}

class _DiscoverPostCardState extends State<DiscoverPostCard> {
  final _like = LikeController();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final p = widget.post;
    final name = p.author.displayName;
    final dept = (p.author.department ?? '').trim();
    final time = postRelativeTime(context, p.createdAt);
    final text = (p.text ?? '').trim();
    final label = [if (text.isNotEmpty) text, name].join(', ');
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(BuRadius.lg),
          boxShadow: BuElevation.of(context, 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openUserPosts(context, widget.session, userId: p.author.id, name: name),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      BuAvatar(name: name, url: p.author.avatarUrl, size: 36, headers: postAuthHeaders(widget.session)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1.25)),
                              ),
                              if (time.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle),
                                    child: const SizedBox.square(dimension: 4),
                                  ),
                                ),
                                Flexible(
                                  child: Text(time,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(color: t.mut, height: 1.25)),
                                ),
                              ],
                            ]),
                            if (dept.isNotEmpty)
                              Text(dept,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(color: t.mut)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              if (p.photo != null)
                Semantics(
                  button: true,
                  onTap: () => widget.onOpen(p),
                  label: label,
                  child: DoubleTapLike(
                    onLike: _like.like,
                    onTap: () => widget.onOpen(p),
                    child: PostPhoto(session: widget.session, post: p, radius: 0, aspectRatio: 4 / 3),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.lg, BuSpace.xs, BuSpace.lg, BuSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LikeButton(
                      session: widget.session,
                      post: p,
                      controller: _like,
                      compact: true,
                      size: 24,
                      countLabel: (n) => l.p04LikeCount('$n'),
                      onChanged: widget.onChanged,
                    ),
                    if (text.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: () => widget.onOpen(p),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(text: ' $text'),
                          ]),
                          key: const ValueKey('post-text'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: t.ink, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
