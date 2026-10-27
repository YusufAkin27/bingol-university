import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart' show relativeTime;
import 'post_api.dart';
import 'post_models.dart';
import 'post_routes.dart';

typedef PostMediaBuilder = Widget Function(BuildContext context, Post post);
typedef PostLikeBuilder = Widget Function(BuildContext context, Post post, ValueChanged<Post> onChanged);
typedef PostMenuBuilder = Widget Function(
    BuildContext context, Post post, ValueChanged<Post> onChanged, ValueChanged<int> onDeleted);

/// Akış gönderi kartı. Medya / beğeni / menü için `*Builder`lar verilmezse yerleşik basit karşılıklar kullanılır.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.session,
    required this.post,
    required this.onChanged,
    required this.onDeleted,
    this.onOpen,
    this.mediaBuilder,
    this.likeBuilder,
    this.menuBuilder,
    this.maxLines = 6,
    this.expandable = true,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;

  /// Karta / yorum sayısına dokununca (varsayılan: gönderi detayı).
  final ValueChanged<Post>? onOpen;
  final PostMediaBuilder? mediaBuilder;
  final PostLikeBuilder? likeBuilder;
  final PostMenuBuilder? menuBuilder;
  final int maxLines;

  /// false: metin kırpılmaz (detay sayfasında kullanılabilir).
  final bool expandable;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;

  Post get p => widget.post;

  void _open() {
    final cb = widget.onOpen;
    if (cb != null) {
      cb(p);
    } else {
      openPostDetail(context, widget.session, p.id, initial: p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final meta = [
      if ((p.author.department ?? '').isNotEmpty) p.author.department!,
      relativeTime(p.createdAt),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 0),
            child: Row(
              children: [
                BuAvatar(
                    name: p.author.displayName,
                    url: p.author.avatarUrl,
                    size: 40,
                    headers: postAuthHeaders(widget.session)),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openUserPosts(context, widget.session,
                        userId: p.author.id, name: p.author.displayName),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BuType.bodyStrong.copyWith(color: t.ink)),
                        if (meta.isNotEmpty)
                          Text(meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.caption.copyWith(color: t.mut)),
                      ],
                    ),
                  ),
                ),
                widget.menuBuilder?.call(context, p, widget.onChanged, widget.onDeleted) ??
                    _FallbackMenu(
                        session: widget.session, post: p, onChanged: widget.onChanged, onDeleted: widget.onDeleted),
              ],
            ),
          ),
          if (p.hasText) _text(t),
          if (p.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: widget.mediaBuilder?.call(context, p) ?? _FallbackMedia(session: widget.session, post: p),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                widget.likeBuilder?.call(context, p, widget.onChanged) ??
                    _FallbackLike(session: widget.session, post: p, onChanged: widget.onChanged),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _open,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.messageCircle, size: 19, color: t.mut),
                        const SizedBox(width: 6),
                        Text('${p.commentCount}', style: BuType.label.copyWith(color: t.mut)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(BuTokens t) {
    final style = BuType.body.copyWith(color: t.ink, height: 1.45);
    final text = p.text!.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: LayoutBuilder(builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        final overflow = widget.expandable && tp.didExceedMaxLines;
        tp.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _open,
              child: Text(
                text,
                maxLines: (_expanded || !widget.expandable) ? null : widget.maxLines,
                overflow: (_expanded || !widget.expandable) ? TextOverflow.clip : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (overflow && !_expanded)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('devamını oku', style: BuType.label.copyWith(color: t.pr)),
                ),
              ),
            if (p.editedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('düzenlendi', style: BuType.micro.copyWith(color: t.mut)),
              ),
          ],
        );
      }),
    );
  }
}

/// Yerleşik beğeni düğmesi (iyimser; M4 `likeBuilder` ile değiştirir).
class _FallbackLike extends StatefulWidget {
  const _FallbackLike({required this.session, required this.post, required this.onChanged});

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;

  @override
  State<_FallbackLike> createState() => _FallbackLikeState();
}

class _FallbackLikeState extends State<_FallbackLike> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    final before = widget.post;
    final want = !before.likedByMe;
    widget.onChanged(before.copyWith(
        likedByMe: want, likeCount: (before.likeCount + (want ? 1 : -1)).clamp(0, 1 << 30)));
    final api = PostApi(widget.session);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = want ? await api.like(before.id) : await api.unlike(before.id);
      widget.onChanged(before.copyWith(likedByMe: r.liked, likeCount: r.likeCount));
    } catch (e) {
      widget.onChanged(before);
      messenger?.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final liked = widget.post.likedByMe;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite : LucideIcons.heart, size: 19, color: liked ? t.pr : t.mut),
            const SizedBox(width: 6),
            Text('${widget.post.likeCount}', style: BuType.label.copyWith(color: liked ? t.pr : t.mut)),
          ],
        ),
      ),
    );
  }
}

/// Yerleşik ⋯ menüsü: Sil (yetkiliyse) ya da Şikâyet et (M4 `menuBuilder` ile değiştirir).
class _FallbackMenu extends StatelessWidget {
  const _FallbackMenu(
      {required this.session, required this.post, required this.onChanged, required this.onDeleted});

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;

  Future<void> _open(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.canDelete)
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('Sil'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            if (!post.mine)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikâyet et'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final api = PostApi(session);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (choice == 'delete') {
        await api.delete(post.id);
        onDeleted(post.id);
      } else {
        await api.report('FEED_POST', post.id, 'OTHER');
        messenger?.showSnackBar(const SnackBar(content: Text('Şikâyetiniz iletildi.')));
      }
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!post.canDelete && post.mine) return const SizedBox(width: 10);
    return IconButton(
      tooltip: 'Daha fazla',
      icon: Icon(LucideIcons.ellipsis, size: 20, color: context.bu.mut),
      onPressed: () => _open(context),
    );
  }
}

/// Yerleşik medya: tek görsel oran korunur; 2: yan yana; 3+: 2 sütun ızgara (+N). Video: poster + oynat rozeti.
class _FallbackMedia extends StatelessWidget {
  const _FallbackMedia({required this.session, required this.post});

  final Session session;
  final Post post;

  Widget _tile(BuildContext context, PostMedia m, {int extra = 0}) {
    final t = context.bu;
    final headers = postAuthHeaders(session);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.sf2),
        Image.network(
          m.thumbUrl ?? m.url,
          headers: headers,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: Icon(LucideIcons.image, color: t.mut)),
        ),
        if (m.isVideo)
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
          ),
        if (extra > 0)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text('+$extra', style: BuType.title.copyWith(color: Colors.white)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    if (media.length == 1) {
      return AspectRatio(aspectRatio: media.first.aspect, child: _tile(context, media.first));
    }
    final shown = media.take(4).toList();
    final extra = media.length - shown.length;
    if (media.length == 2) {
      return AspectRatio(
        aspectRatio: 2,
        child: Row(children: [
          Expanded(child: _tile(context, media[0])),
          const SizedBox(width: 2),
          Expanded(child: _tile(context, media[1])),
        ]),
      );
    }
    return AspectRatio(
      aspectRatio: 1.4,
      child: Column(children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 2),
          Expanded(
            child: Row(children: [
              for (var c = 0; c < 2; c++) ...[
                if (c > 0) const SizedBox(width: 2),
                Expanded(
                  child: r * 2 + c < shown.length
                      ? _tile(context, shown[r * 2 + c], extra: (r * 2 + c == 3) ? extra : 0)
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}
