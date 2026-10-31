import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_api.dart';
import 'post_card.dart';
import 'post_routes.dart';
import 'post_models.dart';

/// Bir kullanıcının gönderileri (imleçli sayfalama). [userId] null ya da kendi kimliğim ise `GET /posts/mine`.
class UserPostsPage extends StatefulWidget {
  const UserPostsPage({super.key, required this.session, this.userId, this.name});

  final Session session;
  final int? userId;
  final String? name;

  bool get isMine => userId == null || userId == session.userId;

  @override
  State<UserPostsPage> createState() => _UserPostsPageState();
}

class _UserPostsPageState extends State<UserPostsPage> {
  final _items = <Post>[];
  final _scroll = ScrollController();
  String? _cursor;
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

  Future<PostPage<Post>> _fetch(String? cursor) =>
      widget.isMine ? _api.minePosts(cursor: cursor) : _api.userPosts(widget.userId!, cursor: cursor);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _fetch(null);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _cursor = r.hasMore ? r.nextCursor : null;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await _fetch(_cursor);
      if (!mounted) return;
      setState(() {
        final seen = _items.map((e) => e.id).toSet();
        _items.addAll(r.items.where((e) => !seen.contains(e.id)));
        _cursor = r.hasMore ? r.nextCursor : null;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  void _changed(Post p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i >= 0) setState(() => _items[i] = p);
  }


  Future<void> _open(Post p) async {
    final r = await openPostDetail(context, widget.session, p.id, initial: p);
    if (!mounted) return;
    if (r != null) {
      _changed(r);
    } else {
      _load(silent: true); // silinmiş olabilir
    }
  }

  Future<void> _compose() async {
    final p = await openComposePost(context, widget.session);
    if (p != null && mounted && widget.isMine) {
      setState(() => _items.insert(0, p));
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
        title: l.postViewPosts,
        large: false,
        state: state,
        controller: _scroll,
        onRefresh: () => _load(silent: true),
        loading: const Padding(
          key: ValueKey('userPostsSkeleton'),
          padding: EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 0),
          child: PostCardSkeleton(),
        ),


        empty: _EmptyCard(mine: widget.isMine, onCompose: _compose),
        bottomInset: MediaQuery.paddingOf(context).bottom + 24,
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
              itemBuilder: (c, i) => _GridTile(
                key: ValueKey('upost-${_items[i].id}'),
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

/// 3 sütun ızgara karesi: fotoğraf + altta kalp ve sayı.
class _GridTile extends StatelessWidget {
  const _GridTile({super.key, required this.session, required this.post, required this.onOpen});

  final Session session;
  final Post post;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = post.photo;
    return Semantics(
      button: true,
      label: [if ((post.text ?? '').isNotEmpty) post.text!, '${post.likeCount}'].join(', '),
      excludeSemantics: true,
      child: BuPressable(
        scale: .97,
        onTap: () => onOpen(post),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.md),
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: t.sf2),
            if (m != null)
              BuImage(m.thumbUrl ?? m.url, headers: postAuthHeaders(session), maxDecodeWidth: 400)
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(post.text ?? '',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.ink, height: 1.3)),
              ),
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
                    Icon(Icons.favorite, size: 14, color: t.pr),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${post.likeCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
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

/// Boş durum: kart/gölge yok; simge, tek cümle, (yalnız kendi gönderilerimde) tek eylem.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.mine, required this.onCompose});

  final bool mine;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.xxxl, BuSpace.page, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          key: const ValueKey('userPostsEmpty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
              child: Icon(LucideIcons.camera, size: 28, color: t.mut),
            ),
            BuGap.h16,
            Text(l.postViewNoPosts, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            if (mine) ...[
              BuGap.h24,
              BuButton(key: const ValueKey('userPostsCompose'), label: l.discoverCompose, compact: true, onPressed: onCompose),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hata satırı: kart/kırmızı daire yok; tek cümle + yenile (48 dp).
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('userPostsError'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 0),
      child: Row(children: [
        Expanded(
          child: Text(context.l10n.p04PostsLoadFail, style: tt.bodyLarge?.copyWith(color: t.mut)),
        ),
        BuGap.w8,
        Material(
          color: t.sf2,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('userPostsRetry'),
            customBorder: const CircleBorder(),
            onTap: onRetry,
            child: SizedBox.square(dimension: 48, child: Icon(LucideIcons.refreshCw, size: 20, color: t.ink)),
          ),
        ),
      ]),
    );
  }
}
