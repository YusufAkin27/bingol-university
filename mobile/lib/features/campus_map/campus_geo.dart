import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

import 'campus_models.dart';

/// Konum/mesafe/arama hesapları: HEPSİ istemcide, saf fonksiyonlar (konum sunucuya gitmez).

const _distance = Distance();

/// İki nokta arası kuş uçuşu mesafe (metre).
double meters(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

/// Yürüme hızı: 80 m/dk (sabit; sunucudan gelmez). En az 1 dk.
const walkMetersPerMinute = 80.0;

int walkMinutes(double meters) => math.max(1, (meters / walkMetersPerMinute).ceil());

/// "120 m" / "1,2 km". Yüzün üstündeki metreler 10'a yuvarlanır (sahte kesinlik yok).
String formatDistance(double m, {String lang = 'tr'}) {
  if (m < 995) {
    final r = m < 100 ? m.round() : (m / 10).round() * 10;
    return '${math.max(r, 1)} m';
  }
  final km = (m / 100).round() / 10;
  final s = km.toStringAsFixed(1);
  return '${lang == 'en' ? s : s.replaceAll('.', lang == 'ar' ? '٫' : ',')} km';
}

/// Nokta çokgenin içinde mi (ışın atma). Çokgen <3 köşeliyse false.
bool pointInPolygon(LatLng p, List<LatLng> poly) {
  if (poly.length < 3) return false;
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final yi = poly[i].latitude, xi = poly[i].longitude;
    final yj = poly[j].latitude, xj = poly[j].longitude;
    final hit = (yi > p.latitude) != (yj > p.latitude) &&
        p.longitude < (xj - xi) * (p.latitude - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi;
    if (hit) inside = !inside;
  }
  return inside;
}

/// Kullanıcı kampüsün içinde mi: sınır çokgeni varsa o, yoksa sınır kutusu.
bool insideCampus(LatLng p, CampusMapConfig c) => c.boundary.length >= 3 ? pointInPolygon(p, c.boundary) : c.bounds.contains(p);

/// Kamera sınırı dışındaki bir noktayı sınır kutusuna sıkıştırır.
LatLng clampToBounds(LatLng p, CampusBounds b) =>
    LatLng(p.latitude.clamp(b.south, b.north).toDouble(), p.longitude.clamp(b.west, b.east).toDouble());

/// Arama için Türkçe normalleştirme: küçük harf + aksan katlama (ı/İ->i, ş->s, ğ->g, ü->u, ö->o, ç->c).
/// Karakter sayısı KORUNUR (1:1), böylece eşleşme aralığı özgün metne taşınabilir (vurgulama).
String normalizeTr(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(switch (ch) {
      'İ' || 'I' || 'ı' || 'i' => 'i',
      'Ş' || 'ş' => 's',
      'Ğ' || 'ğ' => 'g',
      'Ü' || 'ü' => 'u',
      'Ö' || 'ö' => 'o',
      'Ç' || 'ç' => 'c',
      'Â' || 'â' => 'a',
      'Î' || 'î' => 'i',
      'Û' || 'û' => 'u',
      _ => ch.toLowerCase(),
    });
  }
  return b.toString();
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// [name] içinde [query]'nin (normalleştirilmiş) ilk geçtiği aralık; yoksa null. Özgün metindeki konumdur.
({int start, int end})? matchRange(String name, String query) {
  final q = _squash(normalizeTr(query));
  if (q.isEmpty) return null;
  final n = normalizeTr(name);
  final i = n.indexOf(q);
  return i < 0 ? null : (start: i, end: i + q.length);
}

/// Arama skoru (küçük = iyi); eşleşme yoksa null. Ad önek < ad kelime başı < ad içi < birim < özet.
int? searchScore(CampusPlace p, String query) {
  final q = _squash(normalizeTr(query));
  if (q.isEmpty) return null;
  final n = normalizeTr(p.name);
  if (n.startsWith(q)) return 0;
  if (n.contains(' $q') || n.contains('-$q')) return 1;
  if (n.contains(q)) return 2;
  if (p.units.any((u) => normalizeTr(u).contains(q))) return 3;
  if (normalizeTr(p.summary).contains(q)) return 4;
  return null;
}

/// Sonuçlar skora, sonra sıra anahtarına/ada göre. [maxResults] ile kırpılır.
List<CampusPlace> searchPlaces(List<CampusPlace> all, String query, {int maxResults = 60}) {
  final scored = <(int, CampusPlace)>[];
  for (final p in all) {
    final s = searchScore(p, query);
    if (s != null) scored.add((s, p));
  }
  scored.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    if (c != 0) return c;
    final k = a.$2.sortKey.compareTo(b.$2.sortKey);
    return k != 0 ? k : a.$2.name.compareTo(b.$2.name);
  });
  return [for (final e in scored.take(maxResults)) e.$2];
}

/// Mesafeye göre sıralı kopya ([from] yoksa sıra anahtarı).
List<CampusPlace> sortByDistance(List<CampusPlace> list, LatLng? from) {
  final out = [...list];
  if (from == null) return out;
  final d = {for (final p in out) p.id: meters(from, p.point)};
  out.sort((a, b) => d[a.id]!.compareTo(d[b.id]!));
  return out;
}

/// Basit ızgara kümeleme: ekran izdüşümünde [cellPx] hücrelerine düşen yerler tek küme olur.
/// [keep] kimlikli yer (seçili) hiçbir zaman kümelenmez.
class CampusCluster {
  const CampusCluster(this.members, this.center);

  final List<CampusPlace> members;
  final LatLng center;

  bool get isSingle => members.length == 1;
  CampusPlace get first => members.first;
}

List<CampusCluster> clusterPlaces(
  List<CampusPlace> places,
  Offset Function(LatLng) project, {
  double cellPx = 44,
  int? keep,
}) {
  final cells = <String, List<CampusPlace>>{};
  final out = <CampusCluster>[];
  for (final p in places) {
    if (p.id == keep) {
      out.add(CampusCluster([p], p.point));
      continue;
    }
    final o = project(p.point);
    final key = '${(o.dx / cellPx).floor()}:${(o.dy / cellPx).floor()}';
    (cells[key] ??= []).add(p);
  }
  for (final members in cells.values) {
    if (members.length == 1) {
      out.add(CampusCluster(members, members.first.point));
    } else {
      final lat = members.fold<double>(0, (s, p) => s + p.point.latitude) / members.length;
      final lng = members.fold<double>(0, (s, p) => s + p.point.longitude) / members.length;
      out.add(CampusCluster(members, LatLng(lat, lng)));
    }
  }
  return out;
}

/// Ölçek çubuğu için metre/piksel (Web Mercator, 256 px karo).
double metersPerPixel(double lat, double zoom) => 156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);

/// 1-2-5 dizisinden, [maxPx] içine sığan en uzun "güzel" uzunluk (metre) ve piksel karşılığı.
({double meters, double px}) niceScale(double mPerPx, {double maxPx = 96}) {
  const steps = <double>[5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000];
  var best = steps.first;
  for (final s in steps) {
    if (s / mPerPx <= maxPx) best = s;
  }
  return (meters: best, px: best / mPerPx);
}

/// Cihaz harita uygulamasına YALNIZ hedef koordinat (+ad) gider; kullanıcının konumu eklenmez.
/// [ios]: Apple Haritalar https bağlantısı; aksi halde Android `geo:`/Google Haritalar https.
Uri directionsUri(LatLng to, {required bool ios}) => ios
    ? Uri.https('maps.apple.com', '/', {'daddr': '${to.latitude},${to.longitude}', 'dirflg': 'w'})
    : Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '${to.latitude},${to.longitude}', 'travelmode': 'walking'});

/// "Haritada aç": noktayı gösterir (rota değil).
Uri showOnMapUri(LatLng at, String label, {required bool ios}) => ios
    ? Uri.https('maps.apple.com', '/', {'ll': '${at.latitude},${at.longitude}', 'q': label})
    : Uri.parse('geo:${at.latitude},${at.longitude}?q=${at.latitude},${at.longitude}(${Uri.encodeComponent(label)})');

/// Paylaşım bağlantısı: yer koordinatı (kampüs binası; kişisel veri değil).
Uri shareUri(LatLng at) => Uri.https('www.openstreetmap.org', '/', {
      'mlat': at.latitude.toStringAsFixed(6),
      'mlon': at.longitude.toStringAsFixed(6),
    }).replace(fragment: 'map=19/${at.latitude.toStringAsFixed(6)}/${at.longitude.toStringAsFixed(6)}');
