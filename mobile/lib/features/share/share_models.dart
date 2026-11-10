/// Paylaşım modelleri ve bağlantı biçimi (sözleşme: sunucu `share:{type,id}` + `https://bukampus.com.tr/s/{t}/{id}`).
///
/// Saf Dart: UI'siz test edilir. Bağlantı biçimi sunucudaki `GET /s/{t}/{id}` (OpenGraph önizleme + mağaza yönlendirmesi)
/// ve AASA/assetlinks ile birebir aynı olmalıdır.
library;

/// Paylaşılabilir içerik türü. `apiName` sunucunun `share.type` değeri, `code` bağlantıdaki harftir.
enum ShareType {
  post('POST', 'p'),
  reel('REEL', 'r'),
  news('NEWS', 'n'),
  event('EVENT', 'e'),

  /// Kampüs Forum konusu / yorumu (`/s/f/{id}`, `/s/fc/{id}`; yorumda `id` yorum kimliğidir).
  forumTopic('FORUM_TOPIC', 'f'),
  forumComment('FORUM_COMMENT', 'fc'),

  /// Kullanıcı profili (`/s/u/{kullanıcıKimliği}`; QR kodu da bu bağlantıyı taşır).
  user('USER', 'u');

  const ShareType(this.apiName, this.code);

  final String apiName;
  final String code;

  static ShareType? fromApi(Object? v) {
    final s = '${v ?? ''}'.trim().toUpperCase();
    for (final t in ShareType.values) {
      if (t.apiName == s) return t;
    }
    // Sunucu ileride duyuruyu ayrı tür olarak yollarsa haber ekranına gider.
    if (s == 'ANNOUNCEMENT') return ShareType.news;
    return null;
  }

  static ShareType? fromCode(String? c) {
    for (final t in ShareType.values) {
      if (t.code == c) return t;
    }
    return null;
  }
}

/// Herkese açık bağlantı kökü (önizleme sayfası + evrensel bağlantı).
const String kShareOrigin = 'https://bukampus.com.tr';

/// Özel şema (evrensel bağlantı çalışmazsa yedek): `bukampus://s/{t}/{id}`.
const String kShareScheme = 'bukampus';

/// Kimlik üst sınırı: JS güvenli tamsayı (sunucu Long; taşan değer geçersiz sayılır).
const int _kMaxId = 9007199254740991;

/// Bir içeriğe işaret eden hedef (derin bağlantıdan ya da sohbet kartından).
class ShareTarget {
  const ShareTarget(this.type, this.id);

  final ShareType type;
  final int id;

  /// `https://bukampus.com.tr/s/p/12`
  String get url => '$kShareOrigin/s/${type.code}/$id';

  @override
  bool operator ==(Object other) => other is ShareTarget && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'ShareTarget(${type.apiName}, $id)';
}

/// Gelen bağlantıyı hedefe çevirir; tanınmayan/bozuk bağlantıda null (hiçbir koşulda exception fırlatmaz).
/// Kabul: `https://bukampus.com.tr/s/{t}/{id}` (ve `www.`), `bukampus://s/{t}/{id}`, `bukampus:///s/{t}/{id}`.
ShareTarget? parseShareLink(Object? raw) {
  try {
    final Uri? u = raw is Uri ? raw : (raw is String ? Uri.tryParse(raw.trim()) : null);
    if (u == null) return null;
    final scheme = u.scheme.toLowerCase();
    List<String> seg;
    if (scheme == 'https' || scheme == 'http') {
      final host = u.host.toLowerCase();
      if (host != 'bukampus.com.tr' && host != 'www.bukampus.com.tr') return null;
      if (u.userInfo.isNotEmpty) return null;
      seg = u.pathSegments.where((s) => s.isNotEmpty).toList();
    } else if (scheme == kShareScheme) {
      // bukampus://s/p/12 -> host "s", yol "/p/12"; bukampus:///s/p/12 -> yol "/s/p/12".
      seg = [if (u.host.isNotEmpty) u.host, ...u.pathSegments.where((s) => s.isNotEmpty)];
    } else {
      return null;
    }
    if (seg.length != 3 || seg[0] != 's') return null;
    final type = ShareType.fromCode(seg[1]);
    if (type == null) return null;
    final idText = seg[2];
    if (!RegExp(r'^[0-9]{1,16}$').hasMatch(idText)) return null;
    final id = int.tryParse(idText);
    if (id == null || id <= 0 || id > _kMaxId) return null;
    return ShareTarget(type, id);
  } catch (_) {
    return null;
  }
}

/// Mesajdaki paylaşım önizlemesi (`MessageView.share`). Alanlar eksik/bozuksa null döner.
class ShareInfo {
  const ShareInfo({
    required this.type,
    required this.id,
    this.title,
    this.subtitle,
    this.category,
    this.imageUrl,
    this.available = true,
    this.isAnnouncement = false,
    this.isVideo = false,
  });

  final ShareType type;
  final int id;
  final String? title;
  final String? subtitle;

  /// Forum konusunda kategori adı (kartın üst satırı; sunucu `categoryName`/`category` verirse); diğer türlerde null.
  final String? category;
  final String? imageUrl;

  /// false: içerik silinmiş / gizlenmiş / erişilemez.
  final bool available;

  /// Haber türünün duyuru olduğu (sunucu `newsType`/`kind` verirse; etiket "Duyuru" olur).
  final bool isAnnouncement;

  /// Gönderi videoysa (oynat rozeti). `REEL` türü her zaman videodur.
  final bool isVideo;

  ShareTarget get target => ShareTarget(type, id);

  bool get showPlay => type == ShareType.reel || isVideo;

  static ShareInfo? fromMessage(Map<String, dynamic>? m) {
    if (m == null) return null;
    final s = m['share'];
    if (s is! Map) return null;
    final type = ShareType.fromApi(s['type']);
    final rawId = s['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('${rawId ?? ''}');
    if (type == null || id == null || id <= 0) return null;
    String? str(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    // `kind`: haberde HABER|DUYURU|ETKINLIK, gönderi/Reels'te PHOTO|VIDEO (docs/SHARING.md 4.2).
    final kind = '${s['kind'] ?? ''}'.toUpperCase();
    return ShareInfo(
      type: type,
      id: id,
      title: str(s['title']),
      subtitle: str(s['subtitle']),
      category: str(s['categoryName'] ?? s['category']),
      imageUrl: str(s['imageUrl']),
      available: s['available'] != false,
      isAnnouncement: type == ShareType.news && (kind == 'DUYURU' || kind == 'ANNOUNCEMENT'),
      isVideo: kind == 'VIDEO',
    );
  }
}

/// Paylaşılmak üzere olan içerik (paylaşım sayfasının üstündeki önizleme kartı + dış paylaşım metni).
class ShareContent {
  const ShareContent({
    required this.type,
    required this.id,
    this.title,
    this.source,
    this.imageUrl,
    this.imageHeaders,
    this.isVideo = false,
    this.isAnnouncement = false,
    this.restricted = false,
    this.authorId,
  });

  final ShareType type;
  final int id;
  final String? title;

  /// Başkasının gönderisinde yazar kimliği: gizli hesap bilgisi gönderide yoksa paylaşım sayfası `GET /users/{id}` ile
  /// doğrular (alınamazsa bağlantı kopyalama/harici paylaşım kapalı kalır).
  final int? authorId;

  /// Kaynak/yazar satırı (yazar adı, kulüp, "Bingöl Üniversitesi"...).
  final String? source;
  final String? imageUrl;
  final Map<String, String>? imageHeaders;
  final bool isVideo;
  final bool isAnnouncement;

  /// Gizli hesap gönderisi: bağlantı kopyalama ve harici paylaşım kapalıdır, yalnız kişiyle mesajla paylaşılır.
  final bool restricted;

  ShareTarget get target => ShareTarget(type, id);

  String get url => target.url;

  bool get showPlay => type == ShareType.reel || isVideo;

  /// Harici uygulamalara giden metin: başlık + bağlantı (önizleme bağlantının OG sayfasından gelir).
  String externalText() {
    final t = (title ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return url;
    final short = t.runes.length > 120 ? '${String.fromCharCodes(t.runes.take(119))}…' : t;
    return '$short\n$url';
  }
}

/// Sohbette mesaj metni olarak gelen paylaşım bağlantısı (yedek metin) mi? Kartın altında yinelenmesin diye gizlenir.
bool isShareLinkText(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return false;
  return parseShareLink(t) != null;
}
