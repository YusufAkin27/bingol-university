import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_models.dart';
import 'post_photo_viewer.dart';
import 'post_routes.dart';
import '../../core/academic_catalog.dart';

/// Gönderinin tek fotoğrafı: yetkili medya uçları için Bearer başlığı ile yüklenir. Oran varsayılan 4:5 (tasarım 17).
/// Çözümleme genişliği ekrana göre sınırlıdır (en çok 1080 px): bellek ve çözme süresi küçük kalır.
/// [progressive] açıkken (Keşfet akışı) önce küçük resim (`thumbUrl`) hemen gelir, tam boy sonra üstüne yumuşakça
/// belirir (hareket azaltılmışsa anında). Küçük resim yoksa düz zemin → tam boy geçişi yapılır.
class PostPhoto extends StatelessWidget {
  const PostPhoto({
    super.key,
    required this.session,
    required this.post,
    this.radius = BuRadius.lg,
    this.aspectRatio = 4 / 5,
    this.progressive = false,
    this.heroTag,
  });

  final Session session;
  final Post post;
  final double radius;
  final double aspectRatio;
  final bool progressive;

  /// Verilirse fotoğraf liste -> detay (ve detay -> tam ekran) geçişinde paylaşılan öğe (Hero) olarak uçar.
  /// Etiket aynı rota içinde benzersiz olmalı (kart + detay aynı etiketi, farklı rotalarda taşır).
  final Object? heroTag;

  /// Küçük resmin (sunucu: uzun kenar >= 480 px) çözüm genişliği.
  static const _thumbPx = 480;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = post.photo;
    if (m == null) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final headers = postAuthHeaders(session);
    final thumb = progressive ? m.thumbUrl : null;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(heroTag != null ? 0 : radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : 390.0;
          final px = (w * dpr).ceil().clamp(320, 1080);
          final fade = BuMotion.of(context, BuMotion.medium);
          return Semantics(
            image: true,
            label: context.l10n.postComposePhoto,
            child: ColoredBox(
              color: t.sf2,
              child: Stack(fit: StackFit.expand, children: [
                if (thumb != null)
                  Image(
                    image: persistentNetworkImage(thumb, headers: headers, cacheWidth: px < _thumbPx ? px : _thumbPx),
                    key: ValueKey('post-thumb-${post.id}'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    // Yer tutucu renk -> küçük resim -> tam boy: her basamak yumuşakça belirir (önbellekteyse anında).
                    frameBuilder: (context, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: BuMotion.standard, child: child),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                // Disk destekli: Keşfet fotoğrafları ikinci açılışta ağdan değil diskten gelir (çıkışta silinir).
                Image(
                  image: persistentNetworkImage(m.url, headers: headers, cacheWidth: px),
                  key: ValueKey('post-photo-${post.id}'),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: fade,
                          curve: BuMotion.standard,
                          child: child,
                        ),
                  errorBuilder: (_, __, ___) =>
                      thumb != null ? const SizedBox.shrink() : Center(child: Icon(LucideIcons.image, color: t.mut)),
                ),
              ]),
            ),
          );
        }),
      ),
    );
    final tag = heroTag;
    // Köşe yarıçapını BuHero yönetir (uçuşta kart -> tam genişlik arası yumuşak geçer).
    return tag == null ? photo : BuHero(tag: tag, radius: radius, child: photo);
  }
}

/// Yazar satırının ikincil çizgisi: "bölüm • zaman (• düzenlendi)" TEK satır, sığmazsa sondan kırpılır.
/// "Düzenlendi" rozet değil, satır içi sade metindir (anahtar `post-edited`).
class PostMetaLine extends StatelessWidget {
  const PostMetaLine({super.key, required this.department, required this.time, this.edited = false, this.style});

  final String department;
  final String time;
  final bool edited;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = [department, time].where((e) => e.isNotEmpty).join(' • ');
    if (parts.isEmpty && !edited) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: parts),
        if (edited)
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text(parts.isEmpty ? context.l10n.postViewEdited : ' • ${context.l10n.postViewEdited}',
                key: const ValueKey('post-edited'), maxLines: 1, style: style),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
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
    this.heroTag,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;
  final ValueChanged<int> onDeleted;

  /// Karta dokununca (varsayılan: gönderi detayı).
  final ValueChanged<Post>? onOpen;
  final bool detail;

  /// Fotoğrafın Hero etiketi (detayda: listeden gelen etiket). Liste kartında, [onOpen] yoksa, kimlikten türetilir.
  final Object? heroTag;

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

  Object? get _heroTag => widget.heroTag ?? (!widget.detail && widget.onOpen == null ? 'post-card-${p.id}' : null);

  void _open() {
    if (widget.detail) return;
    final cb = widget.onOpen;
    if (cb != null) {
      cb(p);
    } else {
      openPostDetail(context, widget.session, p.id, initial: p, heroTag: _heroTag);
    }
  }

  /// Detayda fotoğrafa dokunma: tam ekran görüntüleyici (yakınlaştırma + sürükleyerek kapatma).
  void _openViewer() => openPostPhotoViewer(context, widget.session, p, heroTag: _heroTag);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final dept = context.departmentName(p.author.department);
    final time = postRelativeTime(context, p.createdAt);
    final mine = p.mine || p.author.id == widget.session.userId;
    final hasMenu = !(mine && !p.canEdit && !p.canDelete);
    final detail = widget.detail;
    // Detay: fotoğraf ekran genişliğinde (kenarsız), metin satırları 20 kenar boşluklu (sayfa kenarı).
    const sidePad = BuSpace.pageH;
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BuAvatar(
                      name: p.author.displayName,
                      url: p.author.avatarUrl,
                      size: 40,
                      headers: postAuthHeaders(widget.session)),
                  BuGap.w12,
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => openUserPosts(context, widget.session,
                          userId: p.author.id, name: p.author.displayName),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.author.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleSmall?.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25)),
                            PostMetaLine(
                                department: dept,
                                time: time,
                                edited: p.editedAt != null,
                                style: tt.labelSmall?.copyWith(color: t.mut)),
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
                onTap: widget.detail ? _openViewer : _open,
                // Detayda fotoğraf ekran kenarlarına dayanır: köşe yuvarlağı ekran kenarında bozuk görünür.
                radius: detail ? 0 : BuRadius.lg,
                child: PostPhoto(
                  session: widget.session,
                  post: p,
                  radius: detail ? 0 : BuRadius.lg,
                  // Detayda küçük resim de kullanılır: Hero uçuşunda ve ilk açılışta boş kare görünmez.
                  progressive: detail,
                  heroTag: _heroTag,
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.only(
                  top: BuSpace.sm,
                  left: detail ? BuSpace.page : 0,
                  right: detail ? BuSpace.page : 0),
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
                BuSkeleton.circle(40),
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
