import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_card.dart' show PostPhoto;
import 'post_models.dart';

/// Çoklu fotoğraf gönderisinin yana kaydırılabilir carousel'i (`PageView`).
///
/// - Sayfalar tembel kurulur (yalnız görünen sayfa; sürüklerken komşusu): ilk karede yalnız ilk fotoğraf yüklenir.
/// - Sağ üstte "2/5" hapı, altta küçük noktalar. RTL'de `PageView` yönü kendiliğinden aynalanır.
/// - Çift dokunma/ iki parmakla yakınlaştırma sarmalayıcıları (beğeni, [PinchZoomable]) dışarıdadır; tek parmaklı
///   yatay sürükleme yalnız bu görünümde kalır.
/// - Ekran okuyucu: her sayfa "Fotoğraf n/toplam".
/// - [heroTag] yalnız ilk sayfaya verilir (diğer sayfalarda uçuş eşleşmez).
class PostPhotoCarousel extends StatefulWidget {
  const PostPhotoCarousel({
    super.key,
    required this.session,
    required this.post,
    this.radius = BuRadius.md,
    this.aspectRatio = 4 / 5,
    this.progressive = false,
    this.heroTag,
    this.pageNotifier,
    this.initialPage = 0,
  });

  final Session session;
  final Post post;
  final double radius;
  final double aspectRatio;
  final bool progressive;
  final Object? heroTag;

  /// Geçerli sayfayı dışarıya bildirir (yakınlaştırma kopyası aynı fotoğrafı göstersin diye).
  final ValueNotifier<int>? pageNotifier;
  final int initialPage;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  late final PageController _pc = PageController(initialPage: widget.initialPage);
  late final ValueNotifier<int> _page = widget.pageNotifier ?? ValueNotifier<int>(widget.initialPage);

  @override
  void dispose() {
    _pc.dispose();
    if (widget.pageNotifier == null) _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.post.photos;
    final n = photos.length;
    final t = context.bu;
    final l = context.l10n;
    final tag = widget.heroTag;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tag != null ? 0 : widget.radius),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            key: ValueKey('post-carousel-${widget.post.id}'),
            controller: _pc,
            itemCount: n,
            onPageChanged: (i) {
              _page.value = i;
              buHaptic(BuHaptic.selection);
            },
            itemBuilder: (_, i) => PostPhoto(
              session: widget.session,
              post: widget.post,
              media: photos[i],
              radius: i == 0 ? widget.radius : 0,
              aspectRatio: widget.aspectRatio,
              progressive: widget.progressive || i > 0,
              heroTag: i == 0 ? tag : null,
              semanticLabel: l.postPhotoOfTotal((i + 1).toString(), n.toString()),
            ),
          ),
          // "2/5" hapı: sayıların yönü RTL'de de değişmez.
          PositionedDirectional(
            top: 12,
            end: 12,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (_, i, __) => ExcludeSemantics(
                  child: DecoratedBox(
                    key: const ValueKey('postCarouselPill'),
                    decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), borderRadius: BorderRadius.circular(BuRadius.pill)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text('${i + 1}/$n',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.onMedia, fontWeight: FontWeight.w400)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Noktalar.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _page,
                    builder: (_, i, __) => Row(
                      key: const ValueKey('postCarouselDots'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var k = 0; k < n; k++)
                          AnimatedContainer(
                            duration: BuMotion.of(context, BuMotion.short),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: k == i ? 7 : 5,
                            height: k == i ? 7 : 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.onMedia.withValues(alpha: k == i ? 1 : .55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Izgara/Keşfet karelerinin köşesindeki "çoklu fotoğraf" simgesi.
class PostMultiBadge extends StatelessWidget {
  const PostMultiBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      label: context.l10n.postMultiBadgeLabel,
      child: ExcludeSemantics(
        child: Icon(BuIcons.layers, key: const ValueKey('postMultiBadge'), size: size, color: t.onMedia),
      ),
    );
  }
}
