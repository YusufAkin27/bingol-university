import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_models.dart';
import 'post_routes.dart';

/// Gönderinin tek fotoğrafı: yetkili medya uçları için Bearer başlığı ile yüklenir.
class PostPhoto extends StatelessWidget {
  const PostPhoto({super.key, required this.session, required this.post, this.radius = 16});

  final Session session;
  final Post post;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = post.photo;
    if (m == null) return const SizedBox.shrink();
    final ar = m.aspect.clamp(0.75, 1.25).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: ar,
        child: Semantics(
          image: true,
          label: context.l10n.postComposePhoto,
          child: ColoredBox(
            color: t.sf2,
            child: Image.network(
              m.url,
              key: ValueKey('post-photo-${post.id}'),
              headers: postAuthHeaders(session),
              cacheWidth: 1000,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Center(child: Icon(LucideIcons.image, color: t.mut)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gönderi kartı: yazar, tek fotoğraf, kısa metin, beğeni. Fotoğrafa çift dokunuş beğenir.
/// [detail] true: metin kırpılmaz, dokununca yeni sayfa açılmaz (detay sayfasında kullanılır).
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.session,
    required this.post,
    required this.onChanged,
    required this.onDeleted,
    this.onOpen,
    this.detail = false,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;

  /// Karta dokununca (varsayılan: gönderi detayı).
  final ValueChanged<Post>? onOpen;
  final bool detail;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _like = LikeController();

  Post get p => widget.post;

  void _open() {
    if (widget.detail) return;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = [
      if ((p.author.department ?? '').isNotEmpty) p.author.department!,
      postRelativeTime(context, p.createdAt),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .22 : .06), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 0),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                ),
                PostMenuButton(
                    session: widget.session, post: p, onChanged: widget.onChanged, onDeleted: widget.onDeleted),
              ],
            ),
          ),
          if (p.photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: DoubleTapLike(
                onLike: _like.like,
                onTap: widget.detail ? null : _open,
                child: PostPhoto(session: widget.session, post: p),
              ),
            ),
          if (p.hasText)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true, // fotoğrafın kendi dokunma hedefi var
                onTap: _open,
                child: Text(p.text!.trim(),
                    key: const ValueKey('post-text'),
                    maxLines: widget.detail ? null : 2,
                    overflow: widget.detail ? TextOverflow.clip : TextOverflow.ellipsis,
                    style: BuType.body.copyWith(color: t.ink, height: 1.4)),
              ),
            ),
          if (p.editedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
              child: Text(context.l10n.postViewEdited, style: BuType.micro.copyWith(color: t.mut)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
            child: LikeButton(
                session: widget.session, post: p, controller: _like, onChanged: widget.onChanged),
          ),
        ],
      ),
    );
  }
}
