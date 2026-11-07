import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/pinch_zoomable.dart';
import 'comments/comment_button.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_carousel.dart';
import 'post_models.dart';
import 'post_rich_text.dart';
import 'avatar_preview.dart';
import 'post_routes.dart';
import 'post_video.dart';
import '../share/share_button.dart' show PostShareButton;
import '../../core/academic_catalog.dart';
import '../profile/user_profile_page.dart' show openUserProfile;

/// Gönderinin tek fotoğrafı: yetkili medya uçları için Bearer başlığı ile yüklenir. Oran varsayılan 4:5 (tasarım 17).
/// Çözümleme genişliği ekrana göre sınırlıdır (en çok 1080 px): bellek ve çözme süresi küçük kalır.
/// [progressive] açıkken (Keşfet akışı) önce küçük resim (`thumbUrl`) hemen gelir, tam boy sonra üstüne yumuşakça
/// belirir (hareket azaltılmışsa anında). Küçük resim yoksa düz zemin → tam boy geçişi yapılır.
class PostPhoto extends StatelessWidget {
  const PostPhoto({
    super.key,
    required this.session,
    required this.post,
    this.radius = BuRadius.md,
    this.aspectRatio = 4 / 5,
    this.progressive = false,
    this.thumbOnly = false,
    this.heroTag,
    this.zoomLayer = false,
    this.media,
    this.semanticLabel,
  });

  final Session session;
  final Post post;

  /// Çoklu fotoğraf gönderisinde gösterilecek fotoğraf (null = gönderinin ilk fotoğrafı).
  final PostMedia? media;

  /// Ekran okuyucu etiketi (null = "Fotoğraf"); carousel "Fotoğraf 2/5" verir.
  final String? semanticLabel;
  final double radius;
  final double aspectRatio;
  final bool progressive;

  /// İki parmakla yakınlaştırma kopyası ([PinchZoomable] kök katmanı): anahtarlar ayrışır (kartla çakışmaz) ve
  /// yüklü görselin üstüne yüksek çözünürlüklü katman biner (aynı disk önbelleğinden, ek ağ isteği yok).
  final bool zoomLayer;

  /// Yakınlaştırma kopyasının yüksek çözünürlüklü katmanı (px).
  static const _zoomPx = 2048;

  /// Küçük kutu (Keşfet masonry): yalnız küçük resim (`thumbUrl`, yoksa tam boy) yüklenir; tam boy hiç indirilmez
  /// (bellek ve veri tasarrufu). [progressive] yok sayılır.
  final bool thumbOnly;

  /// Verilirse fotoğraf liste -> detay (ve detay -> tam ekran) geçişinde paylaşılan öğe (Hero) olarak uçar.
  /// Etiket aynı rota içinde benzersiz olmalı (kart + detay aynı etiketi, farklı rotalarda taşır).
  final Object? heroTag;

  /// Küçük resmin (sunucu: uzun kenar >= 480 px) çözüm genişliği.
  static const _thumbPx = 480;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = media ?? post.photo;
    if (m == null) return const SizedBox.shrink();
    // Anahtar son eki: ilk fotoğraf eski anahtarı korur; sonraki fotoğraflar medya kimliğiyle ayrışır.
    final kid = (media != null && media!.id != post.photo?.id) ? '${post.id}-${media!.id}' : '${post.id}';
    final label = semanticLabel ?? context.l10n.postComposePhoto;
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
          if (thumbOnly) {
            final src = m.thumbUrl ?? m.url;
            return Semantics(
              image: true,
              label: label,
              child: ColoredBox(
                color: t.sf2,
                child: Image(
                  image: persistentNetworkImage(src, headers: headers, cacheWidth: px),
                  key: ValueKey(m.thumbUrl != null ? 'post-thumb-$kid' : 'post-photo-$kid'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, sync) =>
                      sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: BuMotion.standard, child: child),
                  errorBuilder: (_, __, ___) => Center(child: Icon(BuIcons.image, color: t.mut)),
                ),
              ),
            );
          }
          return Semantics(
            image: true,
            label: label,
            child: ColoredBox(
              color: t.sf2,
              child: Stack(fit: StackFit.expand, children: [
                if (thumb != null)
                  Image(
                    image: persistentNetworkImage(thumb, headers: headers, cacheWidth: px < _thumbPx ? px : _thumbPx),
                    key: ValueKey('${zoomLayer ? 'zoom-' : ''}post-thumb-$kid'),
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
                  key: ValueKey('${zoomLayer ? 'zoom-' : ''}post-photo-$kid'),
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
                      thumb != null ? const SizedBox.shrink() : Center(child: Icon(BuIcons.image, color: t.mut)),
                ),
                // Yakınlaştırma kopyası: kart çözünürlüğü anında görünür, yüksek çözünürlük hazır olunca üstüne biner.
                if (zoomLayer)
                  Image(
                    image: persistentNetworkImage(m.url, headers: headers, cacheWidth: _zoomPx),
                    key: ValueKey('zoom-hires-$kid'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: BuMotion.standard, child: child),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
  const PostMetaLine({super.key, required this.department, required this.time, this.edited = false, this.style, this.separator = ' • '});

  final String department;
  final String time;
  final bool edited;
  final TextStyle? style;
  final String separator;

  @override
  Widget build(BuildContext context) {
    final parts = [department, time].where((e) => e.isNotEmpty).join(separator);
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

/// Kartın ortak yüzeyi: `sf` + 1 dp `bd` kenarlık, 16 köşe, gölge yok.
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
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: context.bu.bd),
      ),
      child: child,
    );
  }
}

class _PostCardState extends State<PostCard> {
  final _like = LikeController();
  final _video = PostVideoController();
  final _cardKey = GlobalKey();
  bool _menuOpen = false;

  Post get p => widget.post;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Object? get _heroTag => widget.heroTag ?? (!widget.detail && widget.onOpen == null ? 'post-card-${p.id}' : null);

  /// Fotoğraf: iki parmakla kök katmanda yakınlaşır (kopya: yüksek çözünürlüklü, aynı önbellek, Hero yok).
  Widget _pinchPhoto({required Widget child, required double radius}) => PinchZoomable(
        overlayBuilder: (_) {
          final photos = p.photos;
          // Çoklu gönderide yakınlaşan kopya, o an görünen fotoğraftır.
          final cur = p.isMulti ? photos[_page.value.clamp(0, photos.length - 1)] : null;
          return PostPhoto(session: widget.session, post: p, media: cur, radius: radius, progressive: true, zoomLayer: true);
        },
        child: child,
      );

  /// Çoklu fotoğraf carousel'inde geçerli sayfa (yakınlaştırma kopyası için).
  final _page = ValueNotifier<int>(0);

  /// Gönderi fotoğrafı: çoklu ise yana kaydırılabilir carousel, değilse tek fotoğraf (eski görünüm aynen).
  Widget _photoView({required double radius, required bool progressive}) => p.isMulti
      ? PostPhotoCarousel(
          session: widget.session,
          post: p,
          radius: radius,
          progressive: progressive,
          heroTag: _heroTag,
          pageNotifier: _page,
        )
      : PostPhoto(session: widget.session, post: p, radius: radius, progressive: progressive, heroTag: _heroTag);

  void _open() {
    if (widget.detail) return;
    final cb = widget.onOpen;
    if (cb != null) {
      cb(p);
    } else {
      openPostDetail(context, widget.session, p.id, initial: p, heroTag: _heroTag);
    }
  }

  /// Gönderi detayı (Stitch v3 01): yazar satırı (40 dp avatar, ad 15/600, "bölüm · zaman" 13 mut, ⋯), 20 dp kenar içinde
  /// 4:5 fotoğraf (köşe 16, kart/gölge yok), altında kalp 22 + sayı 15/600 + "·" + metin 15, 6 dp altta "düzenlendi" 12 mut.
  Widget _buildDetail(BuildContext context, {required bool mine, required bool hasMenu}) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final dept = context.departmentName(p.author.department);
    final time = postRelativeTime(context, p.createdAt);
    final text = (p.text ?? '').trim();
    return Padding(
      key: _cardKey,
      padding: const EdgeInsetsDirectional.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 4, BuSpace.xs, 12),
            child: Row(children: [
              // Avatar: dokunma = profil, uzun basma = blur büyük fotoğraf önizlemesi.
              AvatarPreviewTap(
                session: widget.session,
                url: p.author.avatarUrl,
                name: p.author.displayName,
                onTap: () => openUserProfile(context, widget.session,
                    userId: p.author.id, name: p.author.displayName, avatarUrl: p.author.avatarUrl),
                // 40 dp avatar, 44 dp dokunma alanı (erişilebilirlik); metin konumu değişmesin diye boşluk 8 dp.
                child: Semantics(
                  label: p.author.displayName,
                  child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: BuAvatar(name: p.author.displayName, url: p.author.avatarUrl, size: 40, headers: postAuthHeaders(widget.session))),
                  ),
                ),
              ),
              BuGap.w8,
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openUserProfile(context, widget.session,
                      userId: p.author.id, name: p.author.displayName, avatarUrl: p.author.avatarUrl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: BuSize.touch),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(color: t.ink, fontSize: 15, fontWeight: FontWeight.w400, height: 1.25)),
                        PostMetaLine(
                            department: dept,
                            time: time,
                            separator: ' · ',
                            style: tt.bodySmall?.copyWith(color: t.mut, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasMenu)
                PostMenuButton(
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
            ]),
          ),
          if (p.isVideo)
            Padding(
              padding: BuSpace.pageH,
              child: Stack(children: [
                DoubleTapLike(
                  onLike: _like.like,
                  // Tek dokunuş: oynat/duraklat (ikon kısa görünüp solar); ses ayrı düğmeyle (varsayılan sessiz).
                  onTap: _video.toggle,
                  radius: 16,
                  // İki parmakla yakınlaştırma (video: o anki kare kopyalanır, oynatıcı ikinci kez kurulmaz).
                  child: PinchZoomable(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: postVideoCardRatio(p),
                        child: PostVideoView(
                            session: widget.session, post: p, handleTap: false, showControls: false, controller: _video, flashIcon: true),
                      ),
                    ),
                  ),
                ),
                // Düğme çift dokunuş sarmalayıcısının DIŞINDA: dokunma gecikmez.
                const PositionedDirectional(end: 0, bottom: 0, child: PostVideoSoundButton()),
              ]),
            )
          else if (p.photo != null)
            Padding(
              padding: BuSpace.pageH,
              child: DoubleTapLike(
                onLike: _like.like,
                // Tek dokunuş tam ekran açmaz (tam ekran modu yok); yalnız çift dokunuş beğenir.
                radius: 16,
                child: _pinchPhoto(
                  radius: 16,
                  child: _photoView(radius: 16, progressive: true),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 3, BuSpace.page, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              LikeButton(session: widget.session, post: p, controller: _like, compact: true, size: 22, detail: true, onChanged: widget.onChanged),
              CommentButton(
                  session: widget.session,
                  postId: p.id,
                  count: p.commentCount ?? 0,
                  onCountChanged: (n) => widget.onChanged(p.copyWith(commentCount: n))),
              if (text.isNotEmpty) ...[
                Text('·', style: tt.bodyLarge?.copyWith(color: t.mut, fontSize: 15)),
                BuGap.w8,
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    child: PostRichText(
                        key: const ValueKey('post-text'),
                        session: widget.session,
                        text: text,
                        mentions: p.mentions,
                        style: tt.bodyLarge?.copyWith(color: t.ink, fontSize: 15, height: 1.4)),
                  ),
                ),
              ] else
                const Spacer(),
              PostShareButton(session: widget.session, post: p),
            ]),
          ),
          if (p.editedAt != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 6, BuSpace.page, 0),
              child: Text(context.l10n.postViewEdited,
                  key: const ValueKey('post-edited'), style: tt.bodySmall?.copyWith(color: t.mut, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final dept = context.departmentName(p.author.department);
    final time = postRelativeTime(context, p.createdAt);
    final mine = p.mine || p.author.id == widget.session.userId;
    final hasMenu = !(mine && !p.canEdit && !p.canDelete);
    final detail = widget.detail;
    if (detail) return _buildDetail(context, mine: mine, hasMenu: hasMenu);
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
                                    fontWeight: FontWeight.w400,
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
                onTap: widget.detail ? null : _open,
                // Detayda fotoğraf ekran kenarlarına dayanır: köşe yuvarlağı ekran kenarında bozuk görünür.
                radius: detail ? 0 : BuRadius.md,
                child: _pinchPhoto(
                  radius: detail ? 0 : BuRadius.md,
                  child: Stack(alignment: Alignment.center, children: [
                    // Detayda küçük resim de kullanılır: Hero uçuşunda ve ilk açılışta boş kare görünmez.
                    _photoView(radius: detail ? 0 : BuRadius.md, progressive: detail),
                    if (p.isVideo) const IgnorePointer(child: PostPlayBadge()),
                  ]),
                ),
              ),
            ] else if (p.isVideo) ...[
              BuGap.h16,
              GestureDetector(
                key: const ValueKey('post-video-teaser'),
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BuRadius.md),
                  child: AspectRatio(
                    aspectRatio: postVideoCardRatio(p),
                    child: ColoredBox(color: t.sf2, child: Center(child: Icon(BuIcons.playFilled, color: t.mut, size: 32))),
                  ),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.only(
                  top: BuSpace.sm,
                  left: detail ? BuSpace.page : 0,
                  right: detail ? BuSpace.page : 0),
              child: Row(children: [
                LikeButton(
                    session: widget.session,
                    post: p,
                    controller: _like,
                    onChanged: widget.onChanged),
                CommentButton(
                    session: widget.session,
                    postId: p.id,
                    count: p.commentCount ?? 0,
                    onCountChanged: (n) => widget.onChanged(p.copyWith(commentCount: n))),
                const Spacer(),
                PostShareButton(session: widget.session, post: p),
              ]),
            ),
            if (p.hasText)
              Padding(
                padding: detail ? sidePad : EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics:
                      true, // fotoğrafın kendi dokunma hedefi var
                  onTap: _open,
                  child: PostRichText(
                      key: const ValueKey('post-text'),
                      session: widget.session,
                      text: p.text!.trim(),
                      mentions: p.mentions,
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
    // Stitch v3: kart yüzeyi/gölge yok; yazar iskeleti + 4:5 blok (köşe 16) + kalp/metin çubuğu.
    return const BuSkeletonScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            BuSkeleton.circle(40),
            BuGap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton.line(width: 120, height: 12),
                BuGap.h8,
                BuSkeleton.line(width: 84, height: 10),
              ]),
            ),
          ]),
          BuGap.h16,
          AspectRatio(aspectRatio: 4 / 5, child: BuSkeleton(height: double.infinity, radius: 16)),
          BuGap.h12,
          BuSkeleton.line(width: 180, height: 12),
        ],
      ),
    );
  }
}
