import 'post_models.dart';

/// Gönderi sayfasının dikey akışı için tohum (Stitch v3 kesfet2): açılan gönderinin ALTINDA hangi gönderilerin
/// geleceğini ve akışın nereden sürdürüleceğini söyler. Akış `GET /feed` (`scope`) ile aynı imleçle sonsuz kaydırılır.
///
/// * Keşfet: kutuya dokunulunca masonry listesinin o kutudan SONRAKİ gönderileri + imleç ([primed] true).
/// * Derin bağlantı / push: tohum boştur ([PostStreamSeed.fresh]); sayfa, açılan gönderiyi aldıktan sonra akışın ilk
///   sayfasını kendisi ister. Akış alınamazsa yalnız o gönderi gösterilir (hata gösterilmez).
class PostStreamSeed {
  const PostStreamSeed({
    this.scope = 'top',
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.primed = true,
  });

  /// Akışı hiç yüklenmemiş tohum: ilk sayfa sayfanın kendisince istenir.
  const PostStreamSeed.fresh({this.scope = 'top'})
      : items = const [],
        cursor = null,
        hasMore = true,
        primed = false;

  /// `GET /feed` kapsamı (`top` | `popular`).
  final String scope;

  /// Açılan gönderiden sonraki, zaten yüklü gönderiler (sırayla).
  final List<Post> items;

  /// Sonraki sayfanın opak imleci (null: baştan).
  final String? cursor;

  /// Sunucuda daha gönderi olabilir mi.
  final bool hasMore;

  /// [items] / [cursor] gerçek bir akış durumu mu (false: sayfa ilk sayfayı kendisi ister).
  final bool primed;
}
