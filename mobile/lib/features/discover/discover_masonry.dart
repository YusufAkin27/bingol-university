import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/like_button.dart';
import '../posts/post_actions.dart';
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
  const DiscoverMasonryFeed({super.key, required this.session, this.controller, this.header, this.scope = 'top', this.onCompose});

  final Session session;
  final DiscoverFeedController? controller;
  final Widget? header;
  final String scope;

  /// Boş durumdaki "Gönderi oluştur" düğmesi.
  final VoidCallback? onCompose;

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

  void _removed(int id) {
    if (mounted) setState(() => _items.removeWhere((e) => e.id == id));
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
      body = SliverToBoxAdapter(child: DiscoverErrorCard(offline: _error is ApiError && (_error as ApiError).isNetwork, onRetry: _reload));
    } else if (_items.isEmpty) {
      body = SliverToBoxAdapter(child: DiscoverEmptyCard(onCompose: widget.onCompose));
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
              onDeleted: _removed,
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

/// Yükleniyor (referans 12/1): iki sütun, değişken yükseklikli beyaz iskelet kartları (foto bloğu + iki satır +
/// avatar ve kalp çubuğu).
class DiscoverFeedSkeleton extends StatelessWidget {
  const DiscoverFeedSkeleton({super.key});

  static const _left = [180.0, 156.0, 200.0];
  static const _right = [230.0, 164.0, 190.0];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget card(double photo) => DecoratedBox(
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), boxShadow: BuElevation.of(context, 1)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuSkeleton(height: photo, radius: BuRadius.md),
              BuGap.h12,
              const BuSkeleton.line(width: 100, height: 11),
              BuGap.h6,
              const BuSkeleton.line(width: 64, height: 10),
              BuGap.h12,
              const Row(children: [
                BuSkeleton.circle(20),
                BuGap.w6,
                BuSkeleton.line(width: 46, height: 10),
                Spacer(),
                BuSkeleton.circle(14),
                BuGap.w4,
                BuSkeleton.line(width: 14, height: 10),
              ]),
            ]),
          ),
        );
    Widget col(List<double> hs) => Expanded(
          child: Column(children: [
            for (final h in hs) ...[card(h), BuGap.h12],
          ]),
        );
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Padding(
            key: const ValueKey('discoverSkeleton'),
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [col(_left), BuGap.w12, col(_right)]),
          ),
        ),
      ),
    );
  }
}

/// Boş durum (referans 12/2): kamera dairesi, "Henüz gönderi yok. İlk gönderiyi sen paylaş!", Gönderi oluştur.
class DiscoverEmptyCard extends StatelessWidget {
  const DiscoverEmptyCard({super.key, this.onCompose});

  final VoidCallback? onCompose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
      child: DecoratedBox(
        key: const ValueKey('discoverEmpty'),
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.xl), boxShadow: BuElevation.of(context, 1)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(LucideIcons.camera, size: 40, color: t.pr),
            ),
            BuGap.h20,
            Text(l.postViewFeedEmpty, textAlign: TextAlign.center, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            if (onCompose != null) ...[
              BuGap.h20,
              BuButton(key: const ValueKey('discoverEmptyCompose'), label: l.discoverCompose, icon: LucideIcons.camera, compact: true, onPressed: onCompose),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Hata / çevrimdışı (referans 12/3): ince gri şerit ("İnternet bağlantısı yok · Kayıtlı veriler gösteriliyor", yalnız ağ
/// hatasında) + sunucuya ulaşılamadı kartı ve Yeniden dene.
class DiscoverErrorCard extends StatelessWidget {
  const DiscoverErrorCard({super.key, required this.offline, required this.onRetry});

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
      child: Column(children: [
        if (offline)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              key: const ValueKey('discoverOfflineStrip'),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.wifiOff, size: 14, color: t.mut),
                    BuGap.w6,
                    Flexible(child: Text(l.p14OfflineStrip, textAlign: TextAlign.center, style: tt.labelSmall?.copyWith(color: t.ink))),
                  ]),
                ),
              ),
            ),
          ),
        DecoratedBox(
          key: const ValueKey('discoverError'),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.xl), boxShadow: BuElevation.of(context, 1)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(LucideIcons.wifiOff, size: 28, color: t.pr),
              ),
              BuGap.h12,
              Text(l.p04FeedErrTitle, textAlign: TextAlign.center, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              BuGap.h6,
              Text(l.p04FeedErrBody, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
              BuGap.h16,
              BuButton(key: const ValueKey('discoverRetry'), label: l.postViewRetry, icon: LucideIcons.refreshCw, compact: true, onPressed: onRetry),
            ]),
          ),
        ),
      ]),
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
    this.onDeleted,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post> onChanged;

  /// Gönderi silinince/engellenince (⋯ menüsünden) çağrılır; akıştan çıkarılmalı.
  final ValueChanged<int>? onDeleted;

  @override
  State<DiscoverPostCard> createState() => _DiscoverPostCardState();
}

class _DiscoverPostCardState extends State<DiscoverPostCard> {
  final _like = LikeController();
  final _cardKey = GlobalKey();
  final _menuKey = GlobalKey();
  bool _menuOpen = false;

  bool get _hasMenu {
    final p = widget.post;
    final mine = p.mine || p.author.id == widget.session.userId;
    return !(mine && !p.canEdit && !p.canDelete);
  }

  /// Uzun basma: ⋯ düğmesine dokunmakla aynı menü (kart karartmanın üstünde kalır).
  void _longPress() {
    if (!_hasMenu) return;
    final p = widget.post;
    showPostActions(context,
        session: widget.session,
        post: p,
        onEdited: widget.onChanged,
        onDeleted: () => widget.onDeleted?.call(p.id),
        anchorContext: _menuKey.currentContext,
        cardContext: _cardKey.currentContext,
        onOpenChanged: (v) {
          if (mounted) setState(() => _menuOpen = v);
        });
  }

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
        key: _cardKey,
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
                onLongPress: _longPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(14, 10, _hasMenu ? 6 : 14, 10),
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
                      if (_hasMenu)
                        PostMenuButton(
                          key: _menuKey,
                          session: widget.session,
                          post: p,
                          onChanged: widget.onChanged,
                          onDeleted: (id) => widget.onDeleted?.call(id),
                          active: _menuOpen,
                          cardKey: _cardKey,
                          onOpenChanged: (v) {
                            if (mounted) setState(() => _menuOpen = v);
                          },
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
                    onLongPress: _hasMenu ? _longPress : null,
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
