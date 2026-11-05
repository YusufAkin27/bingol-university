import 'post_models.dart';

/// Gönderi sayfasının dikey akışı için tohum (Instagram Keşfet gibi): açılan gönderinin ÜSTÜNDE ve ALTINDA hangi
/// gönderilerin olacağını ve akışın nasıl sürdürüleceğini söyler.
///
/// * Keşfet: ızgaranın tıklanan kutudan ÖNCEKİ gönderileri [before] (yukarı kaydırınca görünür), SONRAKİLERİ [items]
///   (aşağıda). Izgaranın sonundan sonra sayfa, `GET /feed` ile YENİ oturum tohumuyla (rastgele, görülmemişler önce)
///   sonsuz sayfalar ([hasMore] true iken).
/// * Derin bağlantı / push: tohum boştur ([PostStreamSeed.fresh]); sayfa, açılan gönderiyi aldıktan sonra akışın ilk
///   sayfasını kendisi ister. Akış alınamazsa yalnız o gönderi gösterilir (hata gösterilmez).
class PostStreamSeed {
  const PostStreamSeed({
    this.scope = 'foryou',
    this.before = const [],
    this.items = const [],
    this.hasMore = true,
    this.primed = true,
  });

  /// Akışı hiç yüklenmemiş tohum: ilk sayfa sayfanın kendisince istenir.
  const PostStreamSeed.fresh({this.scope = 'foryou'})
      : before = const [],
        items = const [],
        hasMore = true,
        primed = false;

  /// `GET /feed` kapsamı (Keşfet: `foryou`).
  final String scope;

  /// Açılan gönderiden ÖNCEKİ gönderiler, ızgara sırasıyla (yukarıdan aşağıya); akışta açılan gönderinin üstündedir.
  final List<Post> before;

  /// Açılan gönderiden sonraki, zaten yüklü gönderiler (sırayla).
  final List<Post> items;

  /// Sunucudan sayfa istenebilir mi (false: yalnız [before]/[items] gösterilir).
  final bool hasMore;

  /// [items] gerçek bir akış durumu mu (false: sayfa ilk sayfayı kendisi ister).
  final bool primed;
}
