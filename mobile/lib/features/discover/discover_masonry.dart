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
import '../../core/academic_catalog.dart';

/// Keşfet akışına dışarıdan gönderi eklemek/yenilemek için (örn. oluşturma sonrası).
class DiscoverFeedController {
  _DiscoverMasonryFeedState? _state;

  void insertPost(Post post) => _state?._insert(post);

  Future<void> refresh() async => _state?._refresh();
}

/// Keşfet: yalnız öğrenci gönderileri, tek sütun akış (dosya adı eski masonry düzeninden kalmadır). İmleçli sonsuz
/// kaydırma, çekip yenileme, iskelet / hata / boş durumları. Engelleme/gizlilik süzmesi sunucudadır (`/feed`).
/// [header] akışla birlikte kayar (başlık, çipler). [scope] değişince akış baştan yüklenir; daha önce görülen
/// kapsam önbellekten anında çizilir, arka planda doğrulanır. [inline] akışın [inlineAfter]. gönderisinden sonra
/// (az gönderi varsa sonunda) araya girer; yalnız oraya kaydırılınca kurulur (ağ isteği de o zaman).
class DiscoverMasonryFeed extends StatefulWidget {
  const DiscoverMasonryFeed({
    super.key,
    required this.session,
    this.controller,
    this.header,
    this.scope = 'top',
    this.onCompose,
    this.inline,
    this.inlineAfter = 3,
  });

  /// Akış içi öneri bölümü (ör. "Tanıyor Olabilirsin").
  final Widget? inline;
  final int inlineAfter;

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
  final _scrollKey = GlobalKey(); // kapsam anahtarı değişince kaydırma durumu (ve denetleyici) taşınır, yeniden kurulmaz
  final List<Post> _items = [];
  late PostApi _api;

  int _gen = 0;
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  int _scopeGen = 0; // yalnız kapsam değişince artar: ilk 6 kartın kademeli girişi o zaman yeniden oynar (yenilemede değil)
  int? _freshId; // az önce oluşturulup başa eklenen gönderi: girişi ayrıca (solma + yükselme) oynar
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
      _freshId = p.id;
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
      _scopeGen++;
      _freshId = null;
      _loading = false;
      _error = null;
      _moreError = null;
    });
    // Önbellekte bu kapsamın ilk sayfası varsa hemen çiz (iskelet görünmez), sonra ağdan doğrula.
    PostPage<Post>? cached;
    try {
      cached = await _api.peekFeed(scope: widget.scope, size: _pageSize);
    } catch (_) {
      cached = null;
    }
    if (!mounted || gen != _gen) return;
    if (cached != null && cached.items.isNotEmpty) {
      final page = cached;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loaded = true;
      });
      await _fetch(gen, replace: true, quiet: true);
      return;
    }
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

  /// [quiet]: arka plan doğrulaması; hata olursa görünen (önbellekten gelen) liste olduğu gibi kalır.
  Future<void> _fetch(int gen, {bool replace = false, bool quiet = false}) async {
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
        } else if (quiet) {
          // Önbellekten çizilmiş liste olduğu gibi kalır.
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
    final r = await openPostDetail(context, widget.session, p.id, initial: p, heroTag: discoverHeroTag(p.id));
    if (r != null) _changed(r);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (!_loaded && _error == null) {
      body = const SliverToBoxAdapter(child: DiscoverFeedSkeleton());
    } else if (_error != null && !_loaded) {
      body = SliverToBoxAdapter(
          child: _EntryRise(child: DiscoverErrorCard(offline: _error is ApiError && (_error as ApiError).isNetwork, onRetry: _reload)));
    } else if (_items.isEmpty) {
      body = SliverToBoxAdapter(child: _EntryRise(child: DiscoverEmptyCard(onCompose: widget.onCompose)));
    } else {
      final inline = widget.inline;
      final at = _items.length < widget.inlineAfter ? _items.length : widget.inlineAfter;
      final count = _items.length + (inline == null ? 0 : 1);
      // Kartlar yan boşluğu kendisi taşır; araya giren öneri şeridi kenardan kenara kayabilsin diye liste dolgusuz.
      // İlk 6 kart sırayla belirir (BuStaggerItem; kaydırınca geri gelenler ve yenileme tekrar oynatmaz).
      body = SliverList.separated(
        itemCount: count,
        separatorBuilder: (_, __) => BuGap.h16,
        itemBuilder: (_, i) {
          if (inline != null && i == at) return inline;
          final p = _items[inline != null && i > at ? i - 1 : i];
          Widget card = Padding(
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
            child: DiscoverPostCard(
              key: ValueKey('discover-post-${p.id}'),
              session: widget.session,
              post: p,
              onOpen: _open,
              onChanged: _changed,
              onDeleted: _removed,
            ),
          );
          if (p.id == _freshId) card = _EntryRise(key: ValueKey('discover-fresh-${p.id}'), child: card);
          return BuStaggerItem(key: ValueKey('discover-row-${p.id}'), index: i, maxAnimated: _staggerCards, child: card);
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: BuStaggerScope(
        key: ValueKey('discover-scope-$_scopeGen'),
        child: CustomScrollView(
          key: _scrollKey,
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            body,
            SliverToBoxAdapter(child: _footer()),
            const SliverToBoxAdapter(child: SizedBox(height: kNavInset)),
          ],
        ),
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

/// Kademeli girişte animasyonlanan en çok kart sayısı.
const int _staggerCards = 6;

/// Keşfet fotoğrafının Hero etiketi (kart ve gönderi detayı aynı etiketi kullanır).
String discoverHeroTag(int postId) => 'discover-post-$postId';

/// Tek seferlik giriş: solma + hafif yükselme (yalnız opacity/transform, 250 ms). Hareket azaltılmışsa anında.
class _EntryRise extends StatefulWidget {
  const _EntryRise({super.key, required this.child});

  final Widget child;

  @override
  State<_EntryRise> createState() => _EntryRiseState();
}

class _EntryRiseState extends State<_EntryRise> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late Animation<double> _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    if (BuMotion.reduced(context)) return;
    final c = AnimationController(vsync: this, duration: BuMotion.medium)..forward();
    _curve = CurvedAnimation(parent: c, curve: BuMotion.emphasizedDecelerate);
    _c = c;
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, 16 * (1 - _curve.value)), child: child),
      ),
    );
  }
}

/// Kart içi kenar boşluğu ve fotoğraf oranı (iskelet ile gerçek kart aynı ölçüde: yerleşim kaymaz).
const double _cardPad = 10;
const double kDiscoverPhotoRatio = 4 / 5;

/// Yükleniyor: gerçek kartla aynı ölçüde iki kart iskeleti (yazar satırı, 4:5 fotoğraf, beğeni + alt yazı).
class DiscoverFeedSkeleton extends StatelessWidget {
  const DiscoverFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget card() => DecoratedBox(
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), boxShadow: BuElevation.of(context, 1)),
          child: const Padding(
            padding: EdgeInsets.all(_cardPad),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 48,
                child: Row(children: [
                  BuSkeleton.circle(36),
                  BuGap.w12,
                  BuSkeleton.line(width: 120, height: 12),
                ]),
              ),
              AspectRatio(aspectRatio: kDiscoverPhotoRatio, child: BuSkeleton(radius: BuRadius.sm)),
              BuGap.h16,
              BuSkeleton.line(width: 72, height: 12),
              BuGap.h8,
              BuSkeleton.line(width: 200, height: 12),
              BuGap.h8,
            ]),
          ),
        );
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Padding(
            key: const ValueKey('discoverSkeleton'),
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg),
            child: Column(children: [card(), BuGap.h16, card()]),
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

/// Hata / çevrimdışı (referans 12/3): sunucuya ulaşılamadı kartı ve Yeniden dene (kayıtlı veri yoksa gösterilir).
/// Pasif "internet yok" şeridi YOK.
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

/// Akış kartı: yazar satırı (avatar, ad • zaman, bölüm), sabit 4:5 fotoğraf (gönderi kırpma oranıyla aynı: hiçbir şey
/// kesilmez), beğeni sayacı ve "ad metin" alt yazısı. Yorum, kaydet, paylaş yok. Fotoğrafa çift dokunuş beğenir.
/// Fotoğraf önce küçük resimle gelir, tam boy üstüne yumuşakça belirir (bkz. `PostPhoto.progressive`).
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
    final dept = context.departmentName((p.author.department ?? '').trim());
    final time = postRelativeTime(context, p.createdAt);
    final text = (p.text ?? '').trim();
    final label = [if (text.isNotEmpty) text, name].join(', ');
    // Ad tek başına satırda (kırpılmaz); bölüm ve zaman ikinci satırda.
    final sub = [if (dept.isNotEmpty) dept, if (time.isNotEmpty) time].join(' • ');
    return Semantics(
      container: true,
      child: DecoratedBox(
        key: _cardKey,
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(BuRadius.lg),
          boxShadow: BuElevation.of(context, 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openUserPosts(context, widget.session, userId: p.author.id, name: name),
                onLongPress: _longPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(children: [
                    BuAvatar(name: name, url: p.author.avatarUrl, size: 36, headers: postAuthHeaders(widget.session)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1.25)),
                          if (sub.isNotEmpty)
                            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: t.mut)),
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
              if (p.photo != null)
                Semantics(
                  button: true,
                  onTap: () => widget.onOpen(p),
                  label: label,
                  child: DoubleTapLike(
                    onLike: _like.like,
                    onTap: () => widget.onOpen(p),
                    onLongPress: _hasMenu ? _longPress : null,
                    radius: BuRadius.sm,
                    child: PostPhoto(
                      session: widget.session,
                      post: p,
                      radius: BuRadius.sm,
                      aspectRatio: kDiscoverPhotoRatio,
                      progressive: true,
                      heroTag: discoverHeroTag(p.id),
                    ),
                  ),
                ),
              BuGap.h4,
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
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 4, end: 4),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () => widget.onOpen(p),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' $text'),
                      ]),
                      key: const ValueKey('post-text'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(color: t.ink, height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
