import 'package:latlong2/latlong.dart';

/// Kampüs haritası sözleşmesi (`GET /api/campus/map`, `/api/campus/places`). Alan adları sunucuyla birebir;
/// eksik/bozuk alanlar güvenle varsayılana düşer (harita bozuk veriyle çökmez).

double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

LatLng? _latLng(Object? v) {
  if (v is List && v.length >= 2) {
    final a = _num(v[0]), b = _num(v[1]);
    if (a != null && b != null) return LatLng(a, b);
  }
  if (v is Map) {
    final a = _num(v['lat']), b = _num(v['lng'] ?? v['lon']);
    if (a != null && b != null) return LatLng(a, b);
  }
  return null;
}

List<LatLng> _ring(Object? v) => [
      for (final e in (v is List ? v : const [])) ...[if (_latLng(e) != null) _latLng(e)!],
    ];

/// Karo kaynağı: `{urlTemplate, attribution, maxNativeZoom, userAgentHint}`.
class CampusTiles {
  const CampusTiles({
    required this.urlTemplate,
    this.attribution = '',
    this.maxNativeZoom = 19,
    this.userAgentHint = '',
  });

  final String urlTemplate;
  final String attribution;
  final int maxNativeZoom;
  final String userAgentHint;

  static CampusTiles? tryParse(Object? j) {
    if (j is! Map) return null;
    final url = j['urlTemplate'];
    if (url is! String || !url.contains('{z}') || !url.contains('{x}') || !url.contains('{y}')) return null;
    // Yalnız https karo adresi (düz http ağ dinleyicisine açık olur); yerel geliştirmede 10.0.2.2 serbest.
    final u = Uri.tryParse(url.replaceAll('{z}', '0').replaceAll('{x}', '0').replaceAll('{y}', '0').replaceAll('{s}', 'a'));
    if (u == null || u.host.isEmpty) return null;
    if (u.scheme != 'https' && !(u.scheme == 'http' && (u.host == '10.0.2.2' || u.host == 'localhost'))) return null;
    return CampusTiles(
      urlTemplate: url,
      attribution: (j['attribution'] as String?) ?? '',
      maxNativeZoom: (_num(j['maxNativeZoom']) ?? 19).round().clamp(1, 22),
      userAgentHint: (j['userAgentHint'] as String?) ?? '',
    );
  }
}

class CampusCategory {
  const CampusCategory({required this.key, required this.label, this.icon = '', this.color = ''});

  final String key;
  final String label;
  final String icon;
  final String color;

  static CampusCategory? tryParse(Object? j) {
    if (j is! Map) return null;
    final key = j['key'];
    if (key is! String || key.isEmpty) return null;
    final label = (j['label'] as String?)?.trim();
    return CampusCategory(
      key: key,
      label: (label == null || label.isEmpty) ? key : label,
      icon: (j['icon'] as String?) ?? '',
      color: (j['color'] as String?) ?? '',
    );
  }
}

/// Kampüs sınır kutusu (güney/batı/kuzey/doğu).
class CampusBounds {
  const CampusBounds(this.south, this.west, this.north, this.east);

  final double south, west, north, east;

  bool contains(LatLng p) => p.latitude >= south && p.latitude <= north && p.longitude >= west && p.longitude <= east;

  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);

  static CampusBounds? tryParse(Object? j) {
    if (j is! Map) return null;
    final s = _num(j['south']), w = _num(j['west']), n = _num(j['north']), e = _num(j['east']);
    if (s == null || w == null || n == null || e == null || s >= n || w >= e) return null;
    return CampusBounds(s, w, n, e);
  }
}

class CampusMapConfig {
  const CampusMapConfig({
    required this.version,
    required this.center,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.bounds,
    required this.boundary,
    required this.tiles,
    required this.categories,
    this.satelliteTiles,
  });

  final String version;
  final LatLng center;
  final double initialZoom, minZoom, maxZoom;
  final CampusBounds bounds;

  /// Kampüs sınırı (kapalı halka olarak çizilir; en az 3 nokta, yoksa boş).
  final List<LatLng> boundary;
  final CampusTiles tiles;

  /// Yalnız sunucu uydu karosu verirse (`tiles.satellite` ya da üst düzey `satelliteTiles`) dolu; katman düğmesi buna bağlıdır.
  final CampusTiles? satelliteTiles;
  final List<CampusCategory> categories;

  CampusCategory? category(String? key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// Bozuk/eksik gövdede null (çağıran hata durumuna düşer).
  static CampusMapConfig? tryParse(Object? j) {
    if (j is! Map) return null;
    final tiles = CampusTiles.tryParse(j['tiles']);
    final bounds = CampusBounds.tryParse(j['bounds']);
    if (tiles == null || bounds == null) return null;
    final zoom = j['zoom'] is Map ? j['zoom'] as Map : const {};
    final minZ = _num(zoom['min']) ?? 14;
    final maxZ = _num(zoom['max']) ?? 19;
    final initZ = (_num(zoom['initial']) ?? 16).clamp(minZ, maxZ).toDouble();
    final tilesMap = j['tiles'] as Map;
    return CampusMapConfig(
      version: '${j['version'] ?? ''}',
      center: _latLng(j['center']) ?? bounds.center,
      initialZoom: initZ,
      minZoom: minZ,
      maxZoom: maxZ,
      bounds: bounds,
      boundary: () {
        final r = _ring(j['boundary']);
        return r.length >= 3 ? r : const <LatLng>[];
      }(),
      tiles: tiles,
      satelliteTiles: CampusTiles.tryParse(tilesMap['satellite'] ?? j['satelliteTiles']),
      categories: [
        for (final c in (j['categories'] is List ? j['categories'] as List : const [])) ...[
          if (CampusCategory.tryParse(c) != null) CampusCategory.tryParse(c)!,
        ],
      ],
    );
  }
}

/// Yalnız https ve bingol.edu.tr (alt alanlar dahil) bağlantılar kabul edilir; sunucudan gelen başka adres atılır.
Uri? _safeWeb(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v.trim());
  if (u == null || u.scheme != 'https' || u.host.isEmpty) return null;
  final h = u.host.toLowerCase();
  return (h == 'bingol.edu.tr' || h.endsWith('.bingol.edu.tr')) ? u : null;
}

class CampusPlace {
  const CampusPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.point,
    this.summary = '',
    this.photoUrl,
    this.units = const [],
    this.footprint,
    this.sortKey = 0,
    this.webUrl,
    this.remote = false,
  });

  final int id;
  final String name;
  final String category;
  final LatLng point;
  final String summary;
  final String? photoUrl;

  /// Bölüm/birim adları (sunucuda `departments`; eski sözleşmede `units`). Boşsa "Birimler" satırı gizlenir.
  final List<String> units;

  /// Birim sayfası (yalnız https + bingol.edu.tr; aksi halde null). Dış tarayıcıda açılır.
  final Uri? webUrl;

  /// Ana yerleşke dışında (ör. Ilıcalar, Hayvan Hastanesi): haritada iğne yok, "Diğer yerleşkeler" grubunda listelenir.
  final bool remote;

  /// Bina izi (kapalı halka); yoksa null.
  final List<LatLng>? footprint;
  final int sortKey;

  static CampusPlace? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = _num(j['id'])?.toInt();
    final name = (j['name'] as String?)?.trim();
    final lat = _num(j['lat']), lng = _num(j['lng']);
    if (id == null || name == null || name.isEmpty || lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    final fp = _ring(j['footprint']);
    final photo = j['photoUrl'];
    return CampusPlace(
      id: id,
      name: name,
      category: (j['category'] as String?) ?? '',
      point: LatLng(lat, lng),
      summary: ((j['summary'] as String?) ?? '').trim(),
      photoUrl: photo is String && photo.isNotEmpty ? photo : null,
      units: [
        for (final u in (j['departments'] is List ? j['departments'] as List : (j['units'] is List ? j['units'] as List : const []))) ...[
          if (u is String && u.trim().isNotEmpty) u.trim(),
        ],
      ],
      footprint: fp.length >= 3 ? fp : null,
      sortKey: _num(j['sortKey'])?.toInt() ?? 0,
      webUrl: _safeWeb(j['webUrl']),
      remote: j['remote'] == true,
    );
  }

  static List<CampusPlace> parseList(Object? body) {
    final items = body is Map ? body['items'] : body;
    final out = <CampusPlace>[];
    for (final e in (items is List ? items : const [])) {
      final p = tryParse(e);
      if (p != null) out.add(p);
    }
    out.sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }
}
