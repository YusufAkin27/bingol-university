import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/avatar_preview.dart';
import '../posts/like_button.dart';
import '../posts/post_card.dart';
import '../posts/post_models.dart';
import '../posts/post_video.dart';
import '../profile/user_profile_page.dart' show openUserProfile;

/// Kutu köşesi (BuRadius.md) ve fotoğraf oran aralığı (genişlik/yükseklik): 1:1 (kare) .. 2:3 (en dik).
const double kDiscoverBoxRadius = BuRadius.md;
const double kDiscoverRatioMax = 1.0;
const double kDiscoverRatioMin = 2 / 3;

/// Boyutu bilinmeyen gönderi için güvenli oran: gönderi kırpması 4:5 olduğundan en olası değer (kutu zıplamaz).
const double kDiscoverRatioDefault = 4 / 5;

/// Keşfet fotoğrafının Hero etiketi (kutu ve gönderi sayfası aynı etiketi kullanır).
String discoverHeroTag(int postId) => 'discover-post-$postId';

/// Kutunun oranı (genişlik/yükseklik): gönderinin gerçek foto oranı 1:1 .. 2:3 arasına kıstırılır (yatay foto 1:1 olarak
/// kırpılır); boyut bilinmiyorsa 4:5; fotoğrafsız (eski/metin) kayıt kare.
double discoverBoxRatio(Post p) {
  final m = p.photo;
  if (m == null) return kDiscoverRatioMax;
  final w = m.width, h = m.height;
  if (w == null || h == null || w <= 0 || h <= 0) return kDiscoverRatioDefault;
  return (w / h).clamp(kDiscoverRatioMin, kDiscoverRatioMax);
}

/// Keşfet kutusu (Stitch v3 kesfet2 A): fotoğraf kutuyu tam kaplar (`BoxFit.cover`, köşe 16, gölge/çerçeve yok); alt %42'de
/// yalnız okunaklılık için gradyan; SOL ALT yazar avatarı + ad (dokununca yazar), SAĞ ALT açık yüzey hapı içinde kalp +
/// sayı: beğenmemişse BOŞ çizgi kalp, beğenmişse DOLU KIRMIZI kalp (dokununca beğenir / geri alır; beyaz kalp YOK).
/// Gönderi metni kutuda yoktur (yalnız gönderi sayfasında; ekran okuyucu etiketinde vardır). Kutu boyutunu üst öğe (masonry
/// ızgarası) verir. Dokunma: gönderi sayfası; uzun basma: gönderi menüsü ([onMenu]).
class DiscoverPostBox extends StatelessWidget {
  const DiscoverPostBox({
    super.key,
    required this.session,
    required this.post,
    required this.onOpen,
    required this.onChanged,
    this.onMenu,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post> onChanged;

  /// Uzun basma (⋯ menüsüyle aynı alt sayfa); null ise uzun basma yok (kendi gönderisi, işlem yetkisiz).
  final ValueChanged<Post>? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final p = post;
    final name = p.author.displayName;
    final text = (p.text ?? '').trim();
    final dur = p.video?.durationMs ?? 0;
    final label = [if (p.isVideo) context.l10n.postComposeVideo, if (text.isNotEmpty) text, name].join(', ');
    const radius = BorderRadius.all(Radius.circular(kDiscoverBoxRadius));
    final photo = p.photo;
    return BuPressable(
      scale: .98,
      pressedOpacity: 1,
      semanticLabel: label,
      onTap: () => onOpen(p),
      onLongPress: onMenu == null ? null : () => onMenu!(p),
      child: Stack(fit: StackFit.expand, children: [
        if (photo != null)
          PostPhoto(
            session: session,
            post: p,
            radius: kDiscoverBoxRadius,
            aspectRatio: discoverBoxRatio(p),
            thumbOnly: true,
            heroTag: discoverHeroTag(p.id),
          )
        else
          DecoratedBox(decoration: BoxDecoration(color: t.sf2, borderRadius: radius)),
        // Alt %42 gradyan (yalnız okunaklılık): scrim %0 -> %28 -> %62. Tek DecoratedBox; fotoğraf zaten köşeli kırpıldığından
        // yalnız alt köşeler yuvarlanır (ağır kırpma/blur yok).
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: .42,
            widthFactor: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('discoverBoxScrim'),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kDiscoverBoxRadius)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .28), t.scrim.withValues(alpha: .62)],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Video gönderi: yalnız sağ üstte sade süre hapı (oynat simgeli; otomatik oynatma yok, gönderi akışında oynar).
        if (p.isVideo)
          PositionedDirectional(
              top: 8, end: 8, child: IgnorePointer(child: dur > 0 ? DurationChip(durationMs: dur) : const PostPlayBadge(size: 28))),
        PositionedDirectional(
          start: 9,
          end: 8,
          bottom: 0,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: _AuthorLabel(session: session, post: p)),
            // Kalp + sayı asla kırpılmaz: ad sütunu esnektir. Hap açık yüzeyli: kalp çizgi `ink`, beğenilince kırmızı dolu.
            LikeButton(
              session: session,
              post: p,
              tile: true,
              pill: true,
              compact: true,
              size: 18,
              a11yCount: (n) => context.l10n.p04LikeCount('$n'),
              onChanged: onChanged,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Sol alt yazar etiketi: 26 dp avatar (+1,5 dp beyaz %45 halka) + ad (13/600, tek satır, ellipsis). Dokunma alanı en az
/// 44 dp yüksekliğinde; dokununca yazarın gönderileri/profili açılır.
class _AuthorLabel extends StatelessWidget {
  const _AuthorLabel({required this.session, required this.post});

  final Session session;
  final Post post;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = post.author.displayName;
    // Dokunma: kullanıcı profili; uzun basma: blur büyük fotoğraf önizlemesi.
    return AvatarPreviewTap(
      key: ValueKey('discover-author-${post.id}'),
      session: session,
      url: post.author.avatarUrl,
      name: name,
      onTap: () => openUserProfile(context, session, userId: post.author.id, name: name, avatarUrl: post.author.avatarUrl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(children: [
          DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.onMedia.withValues(alpha: .45), width: 1.5)),
            // DecoratedBox kenarlığı içeriği büyütmez: halka avatarın DIŞINDA kalsın diye 1,5 dp iç boşluk (toplam 29 dp).
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: BuAvatar(name: name, url: post.author.avatarUrl, size: 26, headers: postAuthHeaders(session)),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: t.onMedia, fontSize: 13, fontWeight: FontWeight.w600, height: 1.25)),
          ),
        ]),
      ),
    );
  }
}
