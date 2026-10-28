import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../posts/post_api.dart';
import '../posts/post_models.dart';
import '../posts/post_routes.dart';

/// Keşfet akışına dışarıdan gönderi eklemek/yenilemek için (örn. oluşturma sonrası).
class DiscoverFeedController {
  _DiscoverMasonryFeedState? _state;

  void insertPost(Post post) => _state?._insert(post);

  Future<void> refresh() async => _state?._refresh();
}

// Tasarımdaki sabit tonlar (avatar ve metin kartı zeminleri; koyu temada da beyaz yazıyla okunur).
const List<Color> kDiscoverTones = [
  Color(0xFF2F4FA8),
  Color(0xFF8A5200),
  Color(0xFF1F7A4A),
  Color(0xFFC62A20),
  Color(0xFF6B3FA0),
  Color(0xFF0F6E7A),
];

Color discoverTone(int seed) => kDiscoverTones[seed.abs() % kDiscoverTones.length];

/// Keşfet: yalnız öğrenci gönderileri, iki sütunlu masonry akışı. İmleçli sonsuz kaydırma, çekip yenileme,
/// iskelet / hata / boş durumları. Engelleme/gizlilik süzmesi sunucudadır (`/feed`).
class DiscoverMasonryFeed extends StatefulWidget {
  const DiscoverMasonryFeed({super.key, required this.session, this.controller});

  final Session session;
  final DiscoverFeedController? controller;

  @override
  State<DiscoverMasonryFeed> createState() => _DiscoverMasonryFeedState();
}

class _DiscoverMasonryFeedState extends State<DiscoverMasonryFeed> {
  // Sunucu varsayılanı 12 (en çok 30). Sıralama (scope=top) sunucudadır; istemci yeniden sıralamaz.
  static const _pageSize = 12;
  static const _gap = 12.0;

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
      final page = await _api.feed(scope: 'top', cursor: replace ? null : _cursor, size: _pageSize);
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

  Future<void> _open(Post p) async {
    final r = await openPostDetail(context, widget.session, p.id, initial: p);
    if (r != null) _changed(r);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && _error == null) return const DiscoverMasonrySkeleton();
    if (_error != null && !_loaded) return ErrorView(error: _error!, onRetry: _reload);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [
            SizedBox(height: 320, child: EmptyView(icon: LucideIcons.messageSquareText, text: context.l10n.postViewFeedEmpty)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, kNavInset),
        child: LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - _gap) / 2;
          // Kart her zaman o an kısa olan sütuna yerleşir (sayfa eklenince mevcut yerleşim değişmez).
          final cols = <List<Widget>>[[], []];
          final heights = [0.0, 0.0];
          for (final p in _items) {
            final h = DiscoverPostCard.heightFor(p, w);
            final k = heights[0] <= heights[1] ? 0 : 1;
            heights[k] += h + _gap;
            cols[k].add(Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: DiscoverPostCard(
                key: ValueKey('discover-post-${p.id}'),
                session: widget.session,
                post: p,
                width: w,
                onOpen: _open,
                onChanged: _changed,
              ),
            ));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: w, child: Column(children: cols[0])),
                  const SizedBox(width: _gap),
                  SizedBox(width: w, child: Column(children: cols[1])),
                ],
              ),
              _footer(),
            ],
          );
        }),
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
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    return const SizedBox(height: 4);
  }
}

/// Yükleniyor: iki sütun, değişken yükseklikli gri kartlar.
class DiscoverMasonrySkeleton extends StatelessWidget {
  const DiscoverMasonrySkeleton({super.key});

  static const _left = [236.0, 172.0, 210.0];
  static const _right = [176.0, 244.0, 176.0];

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget col(List<double> hs) => Expanded(
          child: Column(children: [
            for (final h in hs)
              Container(
                height: h,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(20)),
              ),
          ]),
        );
    return Semantics(
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
          child: Row(
            key: const ValueKey('discoverSkeleton'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [col(_left), const SizedBox(width: 12), col(_right)],
          ),
        ),
      ),
    );
  }
}

/// Masonry kartı: görselli gönderide görsel + alt degrade (başlık, avatar, kullanıcı adı, beğeni);
/// görselsiz gönderide renkli zeminde alıntı metin.
class DiscoverPostCard extends StatefulWidget {
  const DiscoverPostCard({
    super.key,
    required this.session,
    required this.post,
    required this.width,
    required this.onOpen,
    required this.onChanged,
  });

  final Session session;
  final Post post;
  final double width;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post> onChanged;

  /// Kart yüksekliği: görselde en-boy oranından (tasarımdaki 170-250 aralığı), metinde uzunluktan.
  static double heightFor(Post p, double w) {
    if (p.media.isNotEmpty) {
      final ar = p.media.first.aspect.clamp(0.66, 1.25).toDouble();
      return (w / ar).clamp(150.0, 250.0);
    }
    final len = (p.text ?? '').trim().length;
    return (150 + len * 0.55).clamp(150.0, 230.0);
  }

  @override
  State<DiscoverPostCard> createState() => _DiscoverPostCardState();
}

class _DiscoverPostCardState extends State<DiscoverPostCard> {
  static const _debounce = Duration(milliseconds: 250);

  late bool _liked = widget.post.likedByMe;
  late int _count = widget.post.likeCount;
  // Sunucunun son onayladığı durum (late DEĞİL: ilk dokunuştan önce başlangıç değerini almalı).
  late bool _confirmedLiked;
  late int _confirmedCount;
  Timer? _timer;
  bool _inflight = false;

  bool get _pending => _timer != null || _inflight;

  @override
  void initState() {
    super.initState();
    _confirmedLiked = _liked;
    _confirmedCount = _count;
  }

  @override
  void didUpdateWidget(DiscoverPostCard old) {
    super.didUpdateWidget(old);
    if (!_pending && (widget.post.likedByMe != _liked || widget.post.likeCount != _count)) {
      _liked = _confirmedLiked = widget.post.likedByMe;
      _count = _confirmedCount = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    final flush = _timer != null;
    _timer?.cancel();
    if (flush && _liked != _confirmedLiked) {
      final id = widget.post.id;
      final api = PostApi(widget.session);
      unawaited((_liked ? api.like(id) : api.unlike(id)).then<void>((_) {}).catchError((_) {}));
    }
    super.dispose();
  }

  // Mevcut beğeni mantığıyla aynı: iyimser güncelle, 250 ms birleştir, hata olursa onaylı duruma dön.
  void _toggle() {
    final v = !_liked;
    setState(() {
      _liked = v;
      _count = (_confirmedCount + (v == _confirmedLiked ? 0 : (v ? 1 : -1))).clamp(0, 1 << 31);
    });
    widget.onChanged(widget.post.copyWith(likedByMe: _liked, likeCount: _count));
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    if (_inflight || _liked == _confirmedLiked) return;
    final want = _liked;
    _inflight = true;
    try {
      final api = PostApi(widget.session);
      final r = want ? await api.like(widget.post.id) : await api.unlike(widget.post.id);
      _confirmedLiked = r.liked;
      _confirmedCount = r.likeCount;
      _inflight = false;
      if (!mounted) return;
      if (_timer == null && _liked == want) {
        setState(() {
          _liked = r.liked;
          _count = r.likeCount;
        });
        widget.onChanged(widget.post.copyWith(likedByMe: _liked, likeCount: _count));
      } else if (_timer == null && _liked != _confirmedLiked) {
        await _flush();
      }
    } catch (e) {
      _inflight = false;
      if (!mounted) return;
      setState(() {
        _liked = _confirmedLiked;
        _count = _confirmedCount;
      });
      widget.onChanged(widget.post.copyWith(likedByMe: _liked, likeCount: _count));
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(errorText(e).isEmpty ? context.l10n.postViewLikeFailed : errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final p = widget.post;
    final h = DiscoverPostCard.heightFor(p, widget.width);
    final hasMedia = p.media.isNotEmpty;
    final name = p.author.displayName;
    final text = (p.text ?? '').trim();
    final caption = hasMedia ? text : '';
    final l = context.l10n;
    final label = [if (text.isNotEmpty) text, name].join(', ');

    return Semantics(
      container: true,
      child: SizedBox(
        width: widget.width,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x73171E33), blurRadius: 22, offset: Offset(0, 10), spreadRadius: -14)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              Positioned.fill(
                child: Semantics(
                  button: true,
                  onTap: () => widget.onOpen(p),
                  excludeSemantics: true,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onOpen(p),
                    child: hasMedia ? _image(t, p, h) : _quote(p, text),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: hasMedia
                            ? const [Color(0xE00A0E1C), Color(0x9E0A0E1C), Color(0x000A0E1C)]
                            : const [Color(0x66000000), Color(0x00000000)],
                        stops: hasMedia ? const [0, .55, 1] : const [0, 1],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: 10, end: 2, top: hasMedia ? 44 : 20, bottom: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (caption.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(bottom: 2, end: 8),
                              child: Text(
                                caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: BuType.bodyStrong.copyWith(color: Colors.white, fontSize: 13, height: 1.3),
                              ),
                            ),
                          Row(children: [
                            _avatar(p),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BuType.label.copyWith(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            _likeButton(_liked ? l.postViewUnlike : l.postViewLike),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _image(BuTokens t, Post p, double h) {
    final m = p.media.first;
    final src = m.isVideo ? m.thumbUrl : (m.thumbUrl ?? m.url);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cw = (widget.width * dpr).round().clamp(64, 1200);
    Widget ph([IconData? icon, Key? key]) => Container(
          key: key,
          color: t.sf2,
          alignment: Alignment.center,
          child: icon == null ? null : Icon(icon, color: t.mut, size: 24),
        );
    final img = src == null
        ? ph(LucideIcons.video)
        : Image.network(
            src,
            headers: postAuthHeaders(widget.session),
            fit: BoxFit.cover,
            width: widget.width,
            height: h,
            cacheWidth: cw,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => (sync || frame != null) ? child : ph(null, const ValueKey('discoverImgLoading')),
            errorBuilder: (context, e, s) => ph(LucideIcons.imageOff, const ValueKey('discoverImgError')),
          );
    return Stack(fit: StackFit.expand, children: [
      img,
      if (m.isVideo)
        const Center(child: Icon(LucideIcons.play, color: Colors.white, size: 30, shadows: [Shadow(color: Colors.black45, blurRadius: 10)])),
    ]);
  }

  Widget _quote(Post p, String text) {
    final tone = discoverTone(p.author.id + p.id);
    return Container(
      key: const ValueKey('discoverQuote'),
      color: tone,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 58),
      alignment: AlignmentDirectional.topStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“', style: BuType.display.copyWith(color: Colors.white.withValues(alpha: .55), fontSize: 34, height: .9)),
          Expanded(
            child: Text(
              text,
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
              style: BuType.bodyStrong.copyWith(color: Colors.white, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Post p) {
    final a = p.author;
    final has = (a.avatarUrl ?? '').isNotEmpty;
    final initial = a.displayName.trim().isEmpty ? '?' : String.fromCharCode(a.displayName.trim().runes.first).toUpperCase();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: has ? null : discoverTone(a.id),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: has
          ? BuAvatar(name: a.displayName, url: a.avatarUrl, size: 24, headers: postAuthHeaders(widget.session))
          : Text(initial, style: BuType.micro.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }

  Widget _likeButton(String action) {
    return Semantics(
      button: true,
      label: '$action, $_count',
      excludeSemantics: true,
      child: InkResponse(
        key: const ValueKey('discover-like'),
        onTap: _toggle,
        radius: 24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 6),
              _liked
                  ? const Icon(Icons.favorite, size: 16, color: Color(0xFFFF6A5F))
                  : const Icon(LucideIcons.heart, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text('$_count', key: const ValueKey('discover-like-count'), style: BuType.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
