import '../../core/session.dart';

/// Birim (fakülte/bölüm) duyurusunun eki. Dosya sunucuya kopyalanmaz; yalnız dış bağlantı olarak açılır.
class UnitNewsAttachment {
  const UnitNewsAttachment({required this.name, required this.url, required this.type});

  final String name;
  final String url;

  /// `PDF | DOC | XLS | PPT | OTHER`.
  final String type;

  /// Geçersiz ya da `https` olmayan ek atlanır (null).
  static UnitNewsAttachment? tryParse(Object? j) {
    if (j is! Map) return null;
    final url = j['url'];
    if (url is! String || !_isHttps(url)) return null;
    final name = j['name'];
    final type = j['type'];
    return UnitNewsAttachment(
      name: name is String && name.trim().isNotEmpty ? name.trim() : url.split('/').last,
      url: url,
      type: type is String && type.isNotEmpty ? type.toUpperCase() : 'OTHER',
    );
  }
}

bool _isHttps(String url) => Uri.tryParse(url)?.scheme == 'https';

/// `GET /news/unit` satırı / `GET /news/unit/{id}` detayı (sözleşme: docs/UNIT_NEWS_API.md).
class UnitNewsItem {
  const UnitNewsItem({
    required this.id,
    required this.title,
    this.summary,
    this.publishedDate,
    this.sourceName,
    this.unitName,
    this.url,
    this.attachments = const [],
    this.body,
  });

  final int id;
  final String title;
  final String? summary;
  final String? publishedDate;
  final String? sourceName;
  final String? unitName;
  final String? url;
  final List<UnitNewsAttachment> attachments;

  /// Yalnız detayda; düz metin, paragraflar `\n\n` ile ayrılır.
  final String? body;

  /// Şeritte görünen kaynak adı: bölüm akışından geleni bölüm adı, genel akıştan geleni kaynak (fakülte) adı.
  String? get sourceLabel {
    final u = unitName?.trim() ?? '';
    if (u.isNotEmpty) return u;
    final s = sourceName?.trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  /// Kimliği ya da başlığı olmayan satır atlanır (null).
  static UnitNewsItem? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = _str(j['title']);
    if (id is! num || title == null) return null;
    final att = j['attachments'];
    return UnitNewsItem(
      id: id.toInt(),
      title: title,
      summary: _str(j['summary']),
      publishedDate: _str(j['publishedDate']),
      sourceName: _str(j['sourceName']),
      unitName: _str(j['unitName']),
      url: _str(j['url']),
      attachments: att is List ? [for (final a in att) UnitNewsAttachment.tryParse(a)].whereType<UnitNewsAttachment>().toList() : const [],
      body: j['body'] is String ? j['body'] as String : null,
    );
  }
}

/// "Bölümümden" uçları. Şerit sessizdir: bölüm yoksa, boşsa ya da hata olursa [list] boş döner (hata sızdırmaz).
class UnitNewsApi {
  const UnitNewsApi(this.session);

  final Session session;

  /// Profilde bölüm var mı (`GET /users/me`). Yoksa `/news/unit` hiç çağrılmaz. Okunamazsa false.
  Future<bool> hasDepartment({bool force = false}) async {
    try {
      final me = await session.api.get('/users/me', force: force);
      final d = me is Map ? me['department'] : null;
      return d is String && d.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// `GET /news/unit?limit=10`; en yeni önce. Boş/hatalı/beklenmeyen yanıt: boş liste.
  Future<List<UnitNewsItem>> list({int limit = 10, bool force = false}) async {
    try {
      final r = await session.api.get('/news/unit?limit=$limit', force: force);
      if (r is! List) return const [];
      return [for (final e in r) UnitNewsItem.tryParse(e)].whereType<UnitNewsItem>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// `GET /news/unit/{id}`; hata çağırana gider (detay sayfası yeniden dene gösterir).
  Future<UnitNewsItem> detail(int id) async {
    final r = await session.api.get('/news/unit/$id');
    final item = UnitNewsItem.tryParse(r);
    if (item == null) throw const FormatException('unit news');
    return item;
  }
}
