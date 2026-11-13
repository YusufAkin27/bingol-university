import '../../core/analytics.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/feed_pager.dart';
import '../posts/feed_seen.dart';
import '../posts/post_actions.dart';
import '../posts/post_api.dart';
import '../posts/post_models.dart';
import '../posts/post_routes.dart';
import '../posts/block_bus.dart';
import 'discover_box.dart';
import 'discover_prefetch.dart';
import 'masonry_layout.dart';

export 'discover_box.dart' show DiscoverPostBox, discoverHeroTag, discoverBoxRatio;

/// Keşfet akışına dışarıdan gönderi eklemek/yenilemek için (örn. oluşturma sonrası).
class DiscoverFeedController {
  _DiscoverMasonryFeedState? _state;

  void insertPost(Post post) => _state?._insert(post);

  Future<void> refresh() async => _state?._refresh();
}

/// Keşfet: TEK karma akış (`GET /feed?scope=foryou`): fotoğraf ve video gönderileri iki sütun masonry ızgarada
/// KARIŞIK; her kutu foto/poster + sol altta yazar, sağ altta beğeni ([DiscoverPostBox]). Filtre yok.
///
/// * Her yenilemede (aşağı çekme, sekmeye 3 dk+ sonra dönüş, hata sonrası yeniden deneme) imleçsiz ilk sayfa AĞDAN gelir:
///   sunucu yeni tohumla, görülmemişleri önce verir; hepsi görüldüyse baştan karıştırır (`exhausted`). İstemci bunu
///   kesintisiz sürdürür: sonsuz kaydırma, "tükendi" ekranı YOK ([FeedPager]); aynı gönderi ekranda iki kez çıkmaz.
/// * Sayfa geldiği an, kullanıcı bakmadan ÖNCE yakındaki görseller ve videolar yerel diske indirilir ([DiscoverPrefetch]).
/// * Engelleme/gizlilik süzmesi sunucudadır. [header] akışla birlikte kayar. [inline] tam genişlikli bant olarak ilk
///   [inlineAfter] kutudan sonra masonry'yi böler. Kutuya dokununca gönderi akışı açılır: o gönderi ORTADA, ızgarada
///   ondan önceki gönderiler yukarıda, sonrakiler ve rastgele yenileri aşağıda ([PostStreamSeed]).
class DiscoverMasonryFeed extends StatefulWidget {
  const DiscoverMasonryFeed({
    super.key,
    required this.session,
    this.controller,
    this.header,
    this.onCompose,
    this.inline,
    this.inlineAfter = 4,
    this.tabActive = true,
  });

  /// Akış içi öneri bölümü (ör. "Tanıyor Olabilirsin").
  final Widget? inline;
  final int inlineAfter;

  final Session session;
  final DiscoverFeedController? controller;

  /// Akışla birlikte kayan üst alan (başlık satırı).
  final Widget? header;

  /// Boş durumdaki "Gönderi oluştur" düğmesi.
  final VoidCallback? onCompose;

  /// Sekme şu an görünür mü: gizliyken geçen süre [staleAfter]'i aşarsa görünür olunca akış yenilenir.
  final bool tabActive;

  /// Sekmeye dönüşte akışın yenilenmesi için gereken en kısa gizli kalma süresi.
  static const staleAfter = Duration(minutes: 3);

  /// Test kancası: saat (sahte zaman ilerletmek için).
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<DiscoverMasonryFeed> createState() => _DiscoverMasonryFeedState();
}

class _DiscoverMasonryFeedState extends State<DiscoverMasonryFeed> {
  // Sunucu varsayılanı 12 (en çok 30). Sıralama sunucudadır; istemci yeniden sıralamaz.
  static const _pageSize = 12;

  final _scroll = ScrollController();
  final _scrollKey = GlobalKey(); // yenilemede kaydırma durumu (ve denetleyici) taşınır, yeniden kurulmaz
  final List<Post> _items = [];
  late PostApi _api;
  late FeedSeenReporter _seen;
  late FeedPager _pager;
  late DiscoverPrefetch _prefetch;

  int _gen = 0;
  bool _loading = false;
  bool _loaded = false;
  int _scopeGen = 0; // yalnız yeniden yüklemede artar: ilk 6 kutunun kademeli girişi o zaman yeniden oynar
  int? _freshId; // az önce oluşturulup başa eklenen gönderi: girişi ayrıca (solma + yükselme) oynar
  Object? _error;
  Object? _moreError;
  bool _stale = false; // ağ yokken önbellekten gösterilen akış: çevrimdışı notu (Stitch v3)
  DateTime? _hiddenAt;
  int _maxBuilt = -1; // kullanıcının ulaştığı en uzak ızgara indeksi (önyükleme yakınlığı)
  Timer? _warmTimer;

  @override
  void initState() {
    super.initState();
    _api = PostApi(widget.session);
    _seen = FeedSeenReporter(_api);
    _pager = FeedPager(_api, size: _pageSize);
    _prefetch = DiscoverPrefetch(widget.session);
    widget.controller?._state = this;
    BlockBus.instance.addListener(_onBlocked);
    _scroll.addListener(_onScroll);
    if (!widget.tabActive) _hiddenAt = DiscoverMasonryFeed.debugNow();
    _reload();
  }

  @override
  void didUpdateWidget(DiscoverMasonryFeed old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    if (old.session != widget.session) {
      _seen.dispose();
      _api = PostApi(widget.session);
      _seen = FeedSeenReporter(_api);
      _pager = FeedPager(_api, size: _pageSize);
      _prefetch = DiscoverPrefetch(widget.session);
    }
    if (old.tabActive && !widget.tabActive) {
      _hiddenAt = DiscoverMasonryFeed.debugNow();
      unawaited(_seen.flush());
    } else if (!old.tabActive && widget.tabActive) {
      final at = _hiddenAt;
      _hiddenAt = null;
      // Uzun süre sonra dönüş: yeni gönderiler / yeni karışım için baştan, ağdan.
      if (at != null && DiscoverMasonryFeed.debugNow().difference(at) >= DiscoverMasonryFeed.staleAfter && _loaded && !_loading) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        unawaited(_refresh());
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    BlockBus.instance.removeListener(_onBlocked);
    _warmTimer?.cancel();
    _seen.dispose();
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

  /// Önyükleme: ulaşılan konumdan sonraki görseller + videolar (kısa gecikmeyle birleştirilir).
  void _schedulePrefetch() {
    _warmTimer?.cancel();
    _warmTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _prefetch.onItems(_items, from: _maxBuilt);
    });
  }

  /// Baştan yükler (ilk açılış, hata sonrası yeniden deneme): iskelet gösterilir.
  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _items.clear();
      _pager.reset();
      _maxBuilt = -1;
      _loaded = false;
      _scopeGen++;
      _freshId = null;
      _loading = false;
      _error = null;
      _moreError = null;
    });
    // Önbellekteki eski sayfa BİLEREK gösterilmez: yenileyen kişiye aynı gönderiler yine gelmesin (sunucu görülmüşleri
    // hariç tutar). Eski sayfa yalnız ağ yokken yedek olarak çizilir (_fetch).
    await _fetch(gen, replace: true);
  }

  /// Çekip yenile: görünen liste yerinde kalır, yeni sayfa gelince değişir (yeni tohum, imleçsiz).
  Future<void> _refresh() async {
    final gen = ++_gen;
    _pager.reset();
    await _fetch(gen, replace: true);
  }

  Future<void> _loadMore() async {
    if (_loading || _pager.ended || !_loaded) return;
    await _fetch(_gen);
  }

  Future<void> _fetch(int gen, {bool replace = false}) async {
    if (_loading && !replace) return;
    setState(() {
      _loading = true;
      if (!replace) _moreError = null;
    });
    try {
      final chunk = await _pager.next(replace ? const <int>{} : {for (final e in _items) e.id});
      if (!mounted || gen != _gen) return;
      setState(() {
        if (replace) {
          _items.clear();
          _maxBuilt = -1;
        }
        _items.addAll(chunk.items);
        _loaded = true;
        _loading = false;
        _error = null;
        _moreError = null;
        _stale = false;
      });
      _schedulePrefetch();
      // İçerik ekranı doldurmuyorsa kaydırma olmayacağından sonraki sayfayı kendimiz iste.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_pager.ended && _scroll.hasClients && _scroll.position.maxScrollExtent <= 0) _loadMore();
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      // Ağ yok ve hiç gönderi yüklenmedi: varsa önbellekteki eski ilk sayfayı yedek olarak göster.
      if (!_loaded && e is ApiError && e.isNetwork) {
        PostPage<Post>? cached;
        try {
          cached = await _api.peekFeed(scope: 'foryou', size: _pageSize);
        } catch (_) {
          cached = null;
        }
        if (!mounted || gen != _gen) return;
        if (cached != null && cached.items.isNotEmpty) {
          final page = cached;
          setState(() {
            _items
              ..clear()
              ..addAll(page.items);
            _pager.cursor = page.nextCursor;
            _pager.renew = !page.hasMore;
            _loaded = true;
            _loading = false;
            _stale = true;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        if (_loaded && e is ApiError && e.isNetwork) _stale = true;
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

  /// Engellenen yazarın bütün kutuları ızgaradan hemen düşer (yalnız tıklanan gönderi değil).
  void _onBlocked() {
    final uid = BlockBus.instance.lastBlocked;
    if (mounted) setState(() => _items.removeWhere((e) => e.author.id == uid));
  }

  void _removed(int id) {
    if (mounted) setState(() => _items.removeWhere((e) => e.id == id));
  }

  /// Gönderi akışı: tıklanan gönderi ORTADA; ızgarada ondan ÖNCEKİLER yukarıda, SONRAKİLER aşağıda, ızgaranın sonundan
  /// sonra sunucudan yeni (rastgele) sayfalar ([PostStreamSeed]). Akışta olan beğeni/düzenleme/silme (herhangi bir
  /// gönderi için) ızgaraya anında yansır; geri dönünce kaydırma konumu aynen kalır (bu liste yerinden oynamaz).
  Future<void> _open(Post p) async {
    final i = _items.indexWhere((e) => e.id == p.id);
    final seed = PostStreamSeed(
      before: i <= 0 ? const [] : List<Post>.of(_items.sublist(0, i)),
      items: i < 0 ? const [] : List<Post>.of(_items.sublist(i + 1)),
    );
    final r = await openPostDetail(context, widget.session, p.id,
        initial: p, heroTag: discoverHeroTag(p.id), stream: seed, onChanged: _changed, onDeleted: _removed);
    if (r != null) _changed(r);
  }

  /// Uzun basma: ⋯ düğmesiyle aynı alt sayfa (Düzenle/Sil; başkasının gönderisinde Profili gör/Şikâyet/Engelle).
  void _menu(Post p) => showPostActions(context,
      session: widget.session, post: p, share: true, onEdited: _changed, latest: () => _items.firstWhere((e) => e.id == p.id, orElse: () => p), onDeleted: () => _removed(p.id));

  bool _hasMenu(Post p) {
    final mine = p.mine || p.author.id == widget.session.userId;
    return !(mine && !p.canEdit && !p.canDelete);
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
      body = _masonry(context);
    }
    return BuRefreshIndicator(
      onRefresh: Analytics.pullRefresh(_refresh),
      child: BuStaggerScope(
        key: ValueKey('discover-scope-$_scopeGen'),
        child: CustomScrollView(
          key: _scrollKey,
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            if (_stale && _loaded && _items.isNotEmpty) const SliverToBoxAdapter(child: _OfflineNote(key: ValueKey('discoverOffline'))),
            body,
            SliverToBoxAdapter(child: _footer()),
            const SliverToBoxAdapter(child: SizedBox(height: kNavInset)),
          ],
        ),
      ),
    );
  }

  /// Masonry: bant yoksa tek ızgara; varsa ilk kutulardan sonra bant araya girer, masonry yeni bir ızgara olarak sürer.
  Widget _masonry(BuildContext context) {
    final inline = widget.inline;
    final n = _items.length;
    var split = n;
    if (inline != null) {
      final colW = masonryColumnWidth(MediaQuery.sizeOf(context).width - 2 * kMasonrySide);
      split = masonrySplitIndex([for (final p in _items) colW / discoverBoxRatio(p)], min: widget.inlineAfter);
    }
    return SliverMainAxisGroup(slivers: [
      _grid(0, split),
      if (inline != null) SliverToBoxAdapter(child: inline),
      if (split < n) _grid(split, n),
    ]);
  }

  /// `_items[from..to)` için tembel masonry ızgarası. İlk 6 kutu sırayla belirir (BuStaggerItem; kaydırınca geri gelenler ve
  /// yenileme tekrar oynatmaz).
  Widget _grid(int from, int to) {
    final items = _items.sublist(from, to);
    final index = {for (var i = 0; i < items.length; i++) 'discover-row-${items[i].id}': i};
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(kMasonrySide, 0, kMasonrySide, kMasonryGap),
      sliver: SliverGrid(
        gridDelegate: MasonryGridDelegate(ratios: [for (final p in items) discoverBoxRatio(p)]),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final p = items[i];
            _seen.mark(p.id);
            if (from + i > _maxBuilt) {
              _maxBuilt = from + i;
              _schedulePrefetch();
            }
            Widget box = DiscoverPostBox(
              key: ValueKey('discover-post-${p.id}'),
              session: widget.session,
              post: p,
              onOpen: _open,
              onChanged: _changed,
              onMenu: _hasMenu(p) ? _menu : null,
            );
            if (p.id == _freshId) box = _EntryRise(key: ValueKey('discover-fresh-${p.id}'), child: box);
            return BuStaggerItem(key: ValueKey('discover-row-${p.id}'), index: from + i, maxAnimated: _staggerBoxes, child: box);
          },
          childCount: items.length,
          findChildIndexCallback: (k) => k is ValueKey<String> ? index[k.value] : null,
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

/// Çevrimdışı notu (Stitch v3): warnSoft zemin, onWarnSoft 14/500, köşe 16, ikonsuz; altında eski gönderiler normal.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 0, BuSpace.page, BuSpace.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(BuRadius.md)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(context.l10n.p64FeedOffline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.onWarnSoft, fontSize: 14, fontWeight: BuType.emphasisWeight)),
        ),
      ),
    );
  }
}

/// Kademeli girişte animasyonlanan en çok kutu sayısı.
const int _staggerBoxes = 6;

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

/// Yükleniyor (Stitch v3 03): gerçek masonry ile aynı yerleşimde 6 iskelet kutu (oranlar 3:4, 1:1, 2:3, 4:5, 1:1, 3:4 =
/// 238/179/268/224/179/238 dp), düz tonal blok; kutu sol altında soluk avatar dairesi + tek çubuk. Parıltı yok.
class DiscoverFeedSkeleton extends StatelessWidget {
  const DiscoverFeedSkeleton({super.key});

  static const _ratios = [3 / 4, 1.0, 2 / 3, 4 / 5, 1.0, 3 / 4];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 2 * kMasonrySide;
    final colW = masonryColumnWidth(w);
    final heights = [for (final r in _ratios) colW / r];
    final placed = masonryPlace(heights);
    final cols = List.generate(kMasonryColumns, (_) => <Widget>[]);
    for (var i = 0; i < placed.length; i++) {
      cols[placed[i].column]
        ..add(SizedBox(height: heights[i], child: _SkeletonBox(height: heights[i])))
        ..add(const SizedBox(height: kMasonryGap));
    }
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Padding(
            key: const ValueKey('discoverSkeleton'),
            padding: const EdgeInsets.symmetric(horizontal: kMasonrySide),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var c = 0; c < cols.length; c++) ...[
                if (c > 0) const SizedBox(width: kMasonryGap),
                Expanded(child: Column(children: cols[c])),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final soft = context.bu.bd;
    return Stack(children: [
      BuSkeleton(height: height, radius: kDiscoverBoxRadius),
      PositionedDirectional(
        start: 9,
        bottom: 13,
        child: Row(children: [
          DecoratedBox(decoration: BoxDecoration(color: soft, shape: BoxShape.circle), child: const SizedBox(width: 26, height: 26)),
          const SizedBox(width: 5),
          DecoratedBox(
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(5)), child: const SizedBox(width: 70, height: 10)),
        ]),
      ),
    ]);
  }
}

/// Boş durum: sade, tek cümle, tek eylem (kart/gölge yok; sayfa zemininde durur).
class DiscoverEmptyCard extends StatelessWidget {
  const DiscoverEmptyCard({super.key, this.onCompose});

  final VoidCallback? onCompose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final parts = l.postViewFeedEmpty.split(RegExp(r'(?<=[.!?])\s+'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.huge, BuSpace.page, 0),
      child: Column(
        key: const ValueKey('discoverEmpty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stitch v3: illüstrasyon yok; ilk cümle başlık (18/600), ikinci cümle soluk gövde (15).
          Text(parts.first, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w400)),
          if (parts.length > 1) ...[
            BuGap.h6,
            Text(parts.sublist(1).join(' '), textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: t.mut, fontSize: 15)),
          ],
          if (onCompose != null) ...[
            BuGap.h24,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.xxl),
              child: BuButton(key: const ValueKey('discoverEmptyCompose'), label: l.discoverCompose, onPressed: onCompose),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hata / çevrimdışı: tek simge, tek cümle, Yeniden dene (kayıtlı veri yoksa gösterilir). Pasif "internet yok" şeridi YOK.
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
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.huge, BuSpace.page, 0),
      child: Column(
        key: const ValueKey('discoverError'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.p04FeedErrTitle, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w400)),
          BuGap.h6,
          Text(l.p04FeedErrBody, textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: t.mut, fontSize: 15)),
          BuGap.h8,
          TextButton(
            key: const ValueKey('discoverRetry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.ink),
            child: Text(l.postViewRetry, style: tt.labelLarge?.copyWith(color: t.ink, fontSize: 15, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
