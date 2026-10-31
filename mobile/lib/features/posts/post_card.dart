import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_models.dart';
import 'post_routes.dart';

/// Gönderinin tek fotoğrafı: yetkili medya uçları için Bearer başlığı ile yüklenir. Oran 4:5 (tasarım 17).
class PostPhoto extends StatelessWidget {
  const PostPhoto({
    super.key,
    required this.session,
    required this.post,
    this.radius = BuRadius.lg,
    this.aspectRatio = 4 / 5,
  });

  final Session session;
  final Post post;
  final double radius;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = post.photo;
    if (m == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Semantics(
          image: true,
          label: context.l10n.postComposePhoto,
          child: ColoredBox(
            color: t.sf2,
            // Disk destekli: Keşfet fotoğrafları ikinci açılışta ağdan değil diskten gelir (çıkışta silinir).
            child: Image(
              image: persistentNetworkImage(m.url, headers: postAuthHeaders(session), cacheWidth: 1000),
              key: ValueKey('post-photo-${post.id}'),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Center(child: Icon(LucideIcons.image, color: t.mut)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gönderi kartı: yazar, tek fotoğraf, beğeni, kısa metin (tasarım 17). Fotoğrafa çift dokunuş beğenir.
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

/// Kartın ortak yüzeyi: beyaz, 20 köşe, hafif gölge (koyu temada tonal, çizgisiz).
class _CardSurface extends StatelessWidget {
  const _CardSurface({super.key, required this.child, this.flat = false});

  final Widget child;

  /// Düz: yüzey ve gölge yok (gönderi detayı sayfa zeminine tam genişlikte oturur).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.bu.sf,
        borderRadius: BorderRadius.circular(BuRadius.lg),
        boxShadow: BuElevation.of(context, 1),
      ),
      child: child,
    );
  }
}

class _PostCardState extends State<PostCard> {
  final _like = LikeController();
  final _cardKey = GlobalKey();
  bool _menuOpen = false;

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
    final tt = Theme.of(context).textTheme;
    final meta = [
      if ((p.author.department ?? '').isNotEmpty) p.author.department!,
      postRelativeTime(context, p.createdAt),
    ].where((e) => e.isNotEmpty).join(' • ');
    final mine = p.mine || p.author.id == widget.session.userId;
    final hasMenu = !(mine && !p.canEdit && !p.canDelete);
    final detail = widget.detail;
    // Detay: fotoğraf ekran genişliğinde (kenarsız), metin satırları 16 kenar boşluklu (referans 10/5-6).
    const sidePad = EdgeInsetsDirectional.symmetric(horizontal: BuSpace.lg);
    return _CardSurface(
      key: _cardKey,
      flat: detail,
      child: Padding(
        padding: detail
            ? const EdgeInsetsDirectional.only(bottom: BuSpace.lg)
            : const EdgeInsetsDirectional.fromSTEB(
                BuSpace.xl, BuSpace.xl, BuSpace.xl, BuSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: detail ? sidePad : EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuAvatar(
                      name: p.author.displayName,
                      url: p.author.avatarUrl,
                      size: 44,
                      headers: postAuthHeaders(widget.session)),
                  BuGap.w12,
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
                                style: tt.titleLarge?.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2)),
                            if (meta.isNotEmpty)
                              Text(meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(color: t.mut)),
                            if (p.editedAt != null) ...[
                              BuGap.h4,
                              DecoratedBox(
                                decoration: BoxDecoration(
                                    color: t.sf2,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: Text(context.l10n.postViewEdited,
                                      key: const ValueKey('post-edited'),
                                      maxLines: 1,
                                      style: tt.labelSmall?.copyWith(
                                          color: t.mut,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasMenu)
                    Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: PostMenuButton(
                        session: widget.session,
                        post: p,
                        onChanged: widget.onChanged,
                        onDeleted: widget.onDeleted,
                        active: _menuOpen,
                        cardKey: _cardKey,
                        onOpenChanged: (v) {
                          if (mounted) setState(() => _menuOpen = v);
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (p.photo != null) ...[
              BuGap.h16,
              DoubleTapLike(
                onLike: _like.like,
                onTap: widget.detail ? null : _open,
                radius: BuRadius.lg,
                child: PostPhoto(session: widget.session, post: p),
              ),
            ],
            Padding(
              padding: EdgeInsets.only(
                  top: BuSpace.sm,
                  left: detail ? BuSpace.lg : 0,
                  right: detail ? BuSpace.lg : 0),
              child: LikeButton(
                  session: widget.session,
                  post: p,
                  controller: _like,
                  onChanged: widget.onChanged),
            ),
            if (p.hasText)
              Padding(
                padding: detail ? sidePad : EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics:
                      true, // fotoğrafın kendi dokunma hedefi var
                  onTap: _open,
                  child: Text(p.text!.trim(),
                      key: const ValueKey('post-text'),
                      maxLines: widget.detail ? null : 2,
                      overflow: widget.detail
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(color: t.ink, height: 1.4)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yüklenirken gönderi kartı iskeleti (tasarım 17, ekran 6): avatar + iki satır, 4:5 blok, kalp + sayaç, metin satırları.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const BuSkeletonScope(
      child: _CardSurface(
        child: Padding(
          padding: EdgeInsetsDirectional.all(BuSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                BuSkeleton.circle(44),
                BuGap.w12,
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuSkeleton.line(width: 120, height: 12),
                        BuGap.h8,
                        BuSkeleton.line(width: 84, height: 10),
                      ]),
                ),
                BuSkeleton.circle(28),
              ]),
              BuGap.h16,
              AspectRatio(
                aspectRatio: 4 / 5,
                child: BuSkeleton(height: double.infinity, radius: BuRadius.lg),
              ),
              BuGap.h16,
              Row(children: [
                BuSkeleton.circle(24),
                BuGap.w8,
                BuSkeleton.line(width: 32, height: 12),
              ]),
              BuGap.h12,
              BuSkeleton.line(height: 12),
              BuGap.h8,
              BuSkeleton.line(width: 180, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
