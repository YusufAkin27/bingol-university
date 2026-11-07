import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_api.dart';
import 'post_card.dart';
import 'post_carousel.dart' show PostMultiBadge;
import 'post_models.dart';
import 'post_routes.dart';

/// Ayarlar > Beğendiklerim: beğendiğim gönderiler ve Reels (beğeni anına göre, imleçli sayfalama).
/// Üstte Tümü | Gönderiler | Reels segmenti; dokununca gönderi detayı açılır, beğeniyi geri alırsam listeden düşer.
class LikedPostsPage extends StatefulWidget {
  const LikedPostsPage({super.key, required this.session});

  final Session session;

  @override
  State<LikedPostsPage> createState() => _LikedPostsPageState();
}

class _LikedPostsPageState extends State<LikedPostsPage> {
  static const _kinds = ['ALL', 'PHOTO', 'VIDEO'];

  final _items = <Post>[];
  final _scroll = ScrollController();
  String? _cursor;
  int _tab = 0;
  int _gen = 0; // sekme değişince eski yanıtı yok saymak için
  bool _loading = true;
  bool _more = false;
  Object? _error;

  late final PostApi _api = PostApi(widget.session);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _api.likedPosts(kind: _kinds[_tab]);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _cursor = r.hasMore ? r.nextCursor : null;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    final gen = _gen;
    setState(() => _more = true);
    try {
      final r = await _api.likedPosts(kind: _kinds[_tab], cursor: _cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        final seen = _items.map((e) => e.id).toSet();
        _items.addAll(r.items.where((e) => !seen.contains(e.id)));
        _cursor = r.hasMore ? r.nextCursor : null;
        _more = false;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _more = false);
    }
  }

  void _switch(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _items.clear();
      _cursor = null;
      _error = null;
      _loading = true;
    });
    _load();
  }

  Future<void> _open(Post p) async {
    final r = await openPostDetail(context, widget.session, p.id, initial: p);
    if (!mounted) return;
    if (r == null) {
      _load(silent: true); // silinmiş olabilir
    } else if (!r.likedByMe) {
      setState(() => _items.removeWhere((e) => e.id == r.id)); // beğeni geri alındı
    } else {
      final i = _items.indexWhere((e) => e.id == r.id);
      if (i >= 0) setState(() => _items[i] = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = _error != null && _items.isEmpty && !_loading;
    final state = _loading
        ? BuViewState.loading
        : failed
            ? BuViewState.ready
            : _items.isEmpty
                ? BuViewState.empty
                : BuViewState.ready;
    return BuStaggerScope(
      child: BuPageScaffold(
        title: l.profileLiked,
        large: false,
        state: state,
        controller: _scroll,
        onRefresh: () => _load(silent: true),
        loading: const Padding(
          key: ValueKey('likedPostsSkeleton'),
          padding: EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 0),
          child: PostCardSkeleton(),
        ),
        empty: _Empty(text: _tab == 2 ? l.likedEmptyReels : l.likedEmpty),
        bottomInset: MediaQuery.paddingOf(context).bottom + 24,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: BuSegmented(
                key: const ValueKey('likedSegments'),
                items: [l.likedAll, l.srTabPosts, l.srTabReels],
                index: _tab,
                onChanged: _switch,
              ),
            ),
          ),
        ),
        slivers: [
          if (failed) SliverToBoxAdapter(child: _ErrorRow(onRetry: _load)),
          SliverPadding(
            padding: BuSpace.pageH,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 4 / 5,
              ),
              itemCount: _items.length,
              itemBuilder: (c, i) => _Tile(
                key: ValueKey('liked-${_items[i].id}'),
                session: widget.session,
                post: _items[i],
                onOpen: _open,
              ),
            ),
          ),
          if (_more)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.fromLTRB(BuSpace.page, 12, BuSpace.page, 0), child: PostCardSkeleton()),
            ),
        ],
      ),
    );
  }
}

/// 3 sütun ızgara karesi: fotoğraf (Reels'te kapak + oynat simgesi) ve altta kalp + sayı.
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.session, required this.post, required this.onOpen});

  final Session session;
  final Post post;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cover = post.isVideo ? (post.video?.posterUrl ?? post.photo?.thumbUrl) : (post.photo?.thumbUrl ?? post.photo?.url);
    return Semantics(
      button: true,
      label: [if (post.hasText) post.text!, '${post.likeCount}'].join(', '),
      excludeSemantics: true,
      child: BuPressable(
        scale: .97,
        onTap: () => onOpen(post),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.md),
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: t.sf2),
            if (cover != null) BuImage(cover, headers: postAuthHeaders(session), maxDecodeWidth: 400),
            if (post.isVideo)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(BuIcons.playFilled, key: const ValueKey('liked-reel-badge'), size: 18, color: t.onMedia),
              ),
            if (post.isMulti)
              const PositionedDirectional(top: 8, end: 8, child: IgnorePointer(child: PostMultiBadge())),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [t.scrim.withValues(alpha: .6), t.scrim.withValues(alpha: 0)]),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                  child: Row(children: [
                    Icon(BuIcons.heartFilled, size: 14, color: t.heart),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${post.likeCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.onMedia, fontWeight: FontWeight.w400)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Boş durum: kart/gölge yok; simge + tek cümle.
class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.xxxl, BuSpace.page, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          key: const ValueKey('likedPostsEmpty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
              child: Icon(BuIcons.heart, size: 28, color: t.mut),
            ),
            BuGap.h16,
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// Hata satırı: tek cümle + yenile (48 dp).
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      key: const ValueKey('likedPostsError'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 0),
      child: Row(children: [
        Expanded(child: Text(context.l10n.p04PostsLoadFail, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.mut))),
        BuGap.w8,
        Material(
          color: t.sf2,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('likedPostsRetry'),
            customBorder: const CircleBorder(),
            onTap: onRetry,
            child: SizedBox.square(dimension: 48, child: Icon(BuIcons.refreshCw, size: 20, color: t.ink)),
          ),
        ),
      ]),
    );
  }
}
