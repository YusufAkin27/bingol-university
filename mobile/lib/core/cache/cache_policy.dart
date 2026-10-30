/// Hangi GET uçları diske yazılır ve ne kadar süre geçerlidir.
///
/// Taze tutma süresi ([freshFor]): önbellekteki yanıt bu süreden genç ise AĞA HİÇ GİDİLMEZ (ekranlar her açılışta
/// aynı veriyi yeniden çekmesin); süre dolunca ETag/304 ile doğrulanır. Kullanıcı çekip yenilerse (`force`) süre yok sayılır.
///
/// Karar: yalnız herkese açık ya da kullanıcının kendi "listeleme/profil" verisi diske gider.
/// Diske YAZILMAYANLAR: sohbet mesajları ve sohbet listesi (son mesaj önizlemesi içerir),
/// auth uçları, doğrulama/QR kodları, destek talepleri, engellenenler, veri dışa aktarma,
/// sunum/durum uçları. Bunlar yalnızca oturum boyunca bellekte (ETag LRU) kalır.
class CachePolicy {
  const CachePolicy._();

  static const _hour = Duration(hours: 1);
  static const _day = Duration(days: 1);

  /// (yol deseni, ömür). Sıra önemlidir: ilk eşleşen kazanır.
  static final List<(RegExp, Duration)> _rules = [
    (RegExp(r'^/menu/today$'), _day * 2),
    (RegExp(r'^/menu($|/)'), _day * 7),
    (RegExp(r'^/news($|/)'), _day * 7),
    (RegExp(r'^/catalog/'), _day * 30),
    (RegExp(r'^/faq($|/)'), _day * 30),
    (RegExp(r'^/legal($|/)'), _day * 30),
    (RegExp(r'^/communities/categories$'), _day),
    (RegExp(r'^/communities(/\d+)?$'), _day * 3),
    (RegExp(r'^/events/(featured|calendar)$'), _day),
    (RegExp(r'^/events(/\d+)?$'), _day),
    (RegExp(r'^/me/communities$'), _day * 3),
    (RegExp(r'^/me/summary$'), _day),
    (RegExp(r'^/users/me$'), _day * 3),
    (RegExp(r'^/timetable($|/)'), _day * 7),
    (RegExp(r'^/exams($|/)'), _day * 7),
    (RegExp(r'^/bookmarks($|/)'), _day),
    (RegExp(r'^/notifications$'), _day),
    (RegExp(r'^/discover($|/)'), _hour * 12),
    (RegExp(r'^/posts($|/)'), _hour * 12),
  ];

  /// Sabit veri (akademik katalog, sözleşmeler, SSS, kategoriler): günde bir doğrulanır.
  static const staticFresh = Duration(hours: 24);

  /// Günlük veri (menü, haber/duyuru, etkinlik/kulüp listeleri): 20 dk. Canlı veri (sohbet, bildirim, özet,
  /// takvim/sınav, favori, profil) için TANIMSIZ: her açılışta doğrulanır.
  static const dailyFresh = Duration(minutes: 20);

  static final List<(RegExp, Duration)> _fresh = [
    (RegExp(r'^/catalog/'), staticFresh),
    (RegExp(r'^/faq($|/)'), staticFresh),
    (RegExp(r'^/legal($|/(?!acceptance-status))'), staticFresh), // onay durumu canlı: her seferinde sorulur
    (RegExp(r'^/communities/categories$'), staticFresh),
    (RegExp(r'^/menu($|/)'), dailyFresh),
    (RegExp(r'^/news($|/)'), dailyFresh),
    (RegExp(r'^/events/(featured|calendar)$'), dailyFresh),
    (RegExp(r'^/events$'), dailyFresh),
    (RegExp(r'^/communities$'), dailyFresh),
  ];

  /// Ağa gitmeden doğrudan sunulabilecek süre; canlı uçlar için null.
  static Duration? freshFor(String path) {
    final p = _pathOnly(path);
    for (final (re, d) in _fresh) {
      if (re.hasMatch(p)) return d;
    }
    return null;
  }

  /// Bayat veri hiçbir koşulda sunulmayan uçlar (anlık doğruluk gerekir ya da yoklama niteliğinde).
  static final RegExp _noStale = RegExp(
      r'^/(status|app/|auth/|users/\d+/presence|events/\d+/checkin-code|events/\d+/attendance|events/\d+/my-attendance|users/me/export)');

  static String _pathOnly(String path) {
    final q = path.indexOf('?');
    return q < 0 ? path : path.substring(0, q);
  }

  /// Diske yazılabilirse ömrü, yoksa null.
  static Duration? diskTtl(String path) {
    final p = _pathOnly(path);
    for (final (re, ttl) in _rules) {
      if (re.hasMatch(p)) return ttl;
    }
    return null;
  }

  /// Ağ yokken bellekteki/diskteki eski yanıt dönebilir mi.
  static bool allowsStale(String path) => !_noStale.hasMatch(_pathOnly(path));
}
