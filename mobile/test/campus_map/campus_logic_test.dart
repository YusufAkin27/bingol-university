import 'package:bu_kampus/features/campus_map/campus_geo.dart';
import 'package:bu_kampus/features/campus_map/campus_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'campus_fixtures.dart';

void main() {
  group('modeller (JSON)', () {
    test('harita ayarı sözleşme alanlarıyla ayrıştırılır', () {
      final c = sampleConfig();
      expect(c.version, '2026-11-02');
      expect(c.center.latitude, closeTo(38.8995, 1e-9));
      expect((c.initialZoom, c.minZoom, c.maxZoom), (16.0, 14.0, 19.0));
      expect(c.bounds.south, 38.894);
      expect(c.boundary, hasLength(4));
      expect(c.tiles.urlTemplate, contains('{z}'));
      expect(c.tiles.maxNativeZoom, 19);
      expect(c.categories.map((e) => e.key), ['faculty', 'food', 'library', 'service']);
      expect(c.category('food')!.label, 'Yemekhane');
      expect(c.satelliteTiles, isNull, reason: 'uydu karosu yalnız sunucu verirse');
    });

    test('uydu karosu tiles.satellite ile gelirse okunur', () {
      expect(sampleConfig(satellite: true).satelliteTiles!.maxNativeZoom, 18);
    });

    test('bozuk/eksik harita ayarı null döner (çökmez)', () {
      expect(CampusMapConfig.tryParse(null), isNull);
      expect(CampusMapConfig.tryParse({'tiles': {}}), isNull);
      final j = campusMapJson();
      (j['tiles'] as Map)['urlTemplate'] = 'https://x.example/tile.png'; // {z}{x}{y} yok
      expect(CampusMapConfig.tryParse(j), isNull);
      final k = campusMapJson();
      (k['bounds'] as Map)['south'] = 99.0; // south >= north
      expect(CampusMapConfig.tryParse(k), isNull);
    });

    test('düz http karo adresi reddedilir (yalnız yerel geliştirme serbest)', () {
      expect(CampusTiles.tryParse({'urlTemplate': 'http://tiles.evil.example/{z}/{x}/{y}.png'}), isNull);
      expect(CampusTiles.tryParse({'urlTemplate': 'http://10.0.2.2:8080/t/{z}/{x}/{y}.png'}), isNotNull);
    });

    test('sınır çokgeni 3 noktadan azsa boş kalır, yer listesi sıra anahtarına göre', () {
      final j = campusMapJson()..['boundary'] = [[38.90, 40.49], [38.91, 40.5]];
      expect(CampusMapConfig.tryParse(j)!.boundary, isEmpty);
      final places = samplePlaces();
      expect(places.map((p) => p.id), [1, 2, 3, 4, 5], reason: 'adı boş ve koordinatsız kayıtlar atlanır');
      expect(places.first.units, hasLength(3));
      expect(places.first.footprint, hasLength(4));
      expect(places[1].footprint, isNull);
    });

    test('departments / webUrl / remote: yalnız https + bingol.edu.tr bağlantı kabul edilir', () {
      final ps = samplePlaces();
      expect(ps.first.units, ['Bilgisayar Mühendisliği', 'İnşaat Mühendisliği', 'Makine Mühendisliği']);
      expect(ps.first.webUrl.toString(), 'https://muh.bingol.edu.tr');
      expect(ps.firstWhere((p) => p.id == 4).webUrl, isNull, reason: 'http ve yabancı alan adı atılır');
      expect(ps.firstWhere((p) => p.id == 5).remote, isTrue);
      expect(ps.first.remote, isFalse);
      for (final bad in ['https://bingol.edu.tr.evil.example/x', 'https://evil.example/bingol.edu.tr', 'javascript:alert(1)', 'ftp://a.bingol.edu.tr', '']) {
        expect(CampusPlace.tryParse({'id': 1, 'name': 'X', 'lat': 38.9, 'lng': 40.4, 'webUrl': bad})!.webUrl, isNull, reason: bad);
      }
      expect(CampusPlace.tryParse({'id': 1, 'name': 'X', 'lat': 38.9, 'lng': 40.4, 'webUrl': 'https://www.bingol.edu.tr/x'})!.webUrl, isNotNull);
      // eski sözleşme: units
      expect(CampusPlace.tryParse({'id': 1, 'name': 'X', 'lat': 38.9, 'lng': 40.4, 'units': ['A']})!.units, ['A']);
    });

    test('yer koordinat aralığı denetlenir', () {
      expect(CampusPlace.tryParse({'id': 1, 'name': 'X', 'lat': 120, 'lng': 40}), isNull);
      expect(CampusPlace.tryParse({'id': 1, 'name': 'X', 'lat': '38.5', 'lng': '40.5'}), isNotNull, reason: 'sayı metni de kabul');
    });
  });

  group('mesafe / yürüme', () {
    test('kuş uçuşu mesafe ve 80 m/dk yürüme süresi', () {
      const a = LatLng(38.8850, 40.4970), b = LatLng(38.8859, 40.4970); // ~100 m
      final d = meters(a, b);
      expect(d, closeTo(100, 3));
      expect(walkMinutes(d), 2, reason: '100 m / 80 = 1.25 -> yukarı yuvarla');
      expect(walkMinutes(280), 4, reason: 'tasarım örneği: 4 dk (280 m)');
      expect(walkMinutes(5), 1, reason: 'en az 1 dk');
      expect(walkMinutes(0), 1);
    });

    test('mesafe metni', () {
      expect(formatDistance(42), '42 m');
      expect(formatDistance(124), '120 m', reason: '100 üstü 10 m yuvarlanır');
      expect(formatDistance(999), '1,0 km', reason: '995 m ve üstü km gösterilir (1000 m yazılmaz)');
      expect(formatDistance(1234), '1,2 km');
      expect(formatDistance(1234, lang: 'en'), '1.2 km');
      expect(formatDistance(1234, lang: 'ar'), '1٫2 km');
    });

    test('mesafeye göre sıralama; konum yoksa sıra korunur', () {
      final ps = samplePlaces();
      const here = LatLng(38.8981, 40.4870); // Fen Edebiyat yakını
      expect(sortByDistance(ps, here).first.id, 4);
      expect(sortByDistance(ps, null).map((p) => p.id), ps.map((p) => p.id));
    });
  });

  group('sınır / dışarısı mantığı', () {
    final c = sampleConfig();

    test('çokgenin içi/dışı', () {
      expect(insideCampus(const LatLng(38.8995, 40.4875), c), isTrue);
      expect(insideCampus(const LatLng(38.9200, 40.4875), c), isFalse, reason: 'kuzeyde dışarıda');
      expect(insideCampus(const LatLng(38.8995, 40.4600), c), isFalse, reason: 'batıda dışarıda');
    });

    test('sınır çokgeni yoksa sınır kutusu kullanılır', () {
      final j = campusMapJson()..['boundary'] = <Object>[];
      final nb = CampusMapConfig.tryParse(j)!;
      expect(insideCampus(const LatLng(38.8995, 40.4875), nb), isTrue);
      expect(insideCampus(const LatLng(38.870, 40.4875), nb), isFalse);
    });

    test('kamera sınırı: dışarıdaki nokta kutuya sıkıştırılır', () {
      final p = clampToBounds(const LatLng(39.5, 41.0), c.bounds);
      expect((p.latitude, p.longitude), (c.bounds.north, c.bounds.east));
      expect(c.bounds.contains(p), isTrue);
      expect(c.bounds.contains(const LatLng(39.5, 41.0)), isFalse);
    });

    test('çokgen <3 köşe: içeride sayılmaz', () {
      expect(pointInPolygon(const LatLng(1, 1), const [LatLng(0, 0), LatLng(2, 2)]), isFalse);
    });
  });

  group('arama (Türkçe normalleştirme)', () {
    test('aksan ve büyük/küçük harf duyarsız', () {
      expect(normalizeTr('MÜHENDİSLİK'), 'muhendislik');
      expect(normalizeTr('Işık Çağrı Şeker Öğün Ğ'), 'isik cagri seker ogun g');
      expect(normalizeTr('mühendislik'), normalizeTr('MUHENDISLIK'));
      expect(normalizeTr('İstasyon'), normalizeTr('ıstasyon'));
    });

    test('karakter sayısı korunur (vurgu aralığı özgün metne taşınır)', () {
      const s = 'İÇ Işık Öğretim';
      expect(normalizeTr(s).length, s.length);
      final r = matchRange('Mühendislik-Mimarlık Fakültesi', 'mü')!;
      expect((r.start, r.end), (0, 2));
      expect(matchRange('Fen-Edebiyat', 'edeb')!.start, 4);
      expect(matchRange('Kütüphane', 'xyz'), isNull);
      expect(matchRange('Kütüphane', '  '), isNull);
    });

    test('sıralama: ad öneki > kelime başı > ad içi > birim > özet', () {
      final ps = samplePlaces();
      final r = searchPlaces(ps, 'muh');
      expect(r.first.id, 1);
      // "fak" iki fakülteyi bulur, kütüphaneyi bulmaz
      expect(searchPlaces(ps, 'fak').map((p) => p.id).toSet(), {1, 4});
      expect(searchPlaces(ps, 'hayvan').map((p) => p.id), [5], reason: 'uzak yerleşke de aranır');
      // birim adından bulma
      expect(searchPlaces(ps, 'bilgisayar').map((p) => p.id), [1]);
      // özetten bulma
      expect(searchPlaces(ps, 'muhendislik bolumleri').map((p) => p.id), [1]);
      expect(searchPlaces(ps, 'zzz'), isEmpty);
      expect(searchPlaces(ps, '   '), isEmpty);
    });

    test('yalnız kampüs yerleri aranır: kampüs dışı kayıt listede yoksa bulunmaz', () {
      expect(searchPlaces(samplePlaces(), 'istanbul'), isEmpty);
    });
  });

  group('kümeleme / ölçek / bağlantılar', () {
    Offset proj(LatLng p) => Offset(p.longitude * 100000, p.latitude * 100000);

    test('yakın yerler tek kümede, uzaklar ayrı; seçili asla kümelenmez', () {
      final ps = samplePlaces();
      final all = clusterPlaces(ps, proj, cellPx: 5000);
      expect(all.length, lessThan(ps.length));
      expect(all.fold<int>(0, (s, c) => s + c.members.length), ps.length);
      final kept = clusterPlaces(ps, proj, cellPx: 5000, keep: 1);
      expect(kept.any((c) => c.isSingle && c.first.id == 1), isTrue);
      final none = clusterPlaces(ps, proj, cellPx: 1);
      expect(none.every((c) => c.isSingle), isTrue);
    });

    test('ölçek çubuğu: 1-2-5 dizisi ve en çok maxPx', () {
      final s = niceScale(metersPerPixel(38.885, 17), maxPx: 96);
      expect(s.px, lessThanOrEqualTo(96));
      expect([5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000], contains(s.meters));
      expect(metersPerPixel(0, 0), closeTo(156543.03, 1));
    });

    test('yol tarifi bağlantısına YALNIZ hedef koordinat girer', () {
      const to = LatLng(38.885, 40.497);
      final a = directionsUri(to, ios: false);
      expect(a.host, 'www.google.com');
      expect(a.queryParameters['destination'], '38.885,40.497');
      expect(a.queryParameters.keys, containsAll(['api', 'destination', 'travelmode']));
      expect(a.queryParameters.containsKey('origin'), isFalse);
      final i = directionsUri(to, ios: true);
      expect(i.host, 'maps.apple.com');
      expect(i.queryParameters.containsKey('saddr'), isFalse);
      expect(showOnMapUri(to, 'Kütüphane', ios: false).scheme, 'geo');
      expect(showOnMapUri(to, 'Kütüphane', ios: true).host, 'maps.apple.com');
      expect(shareUri(to).toString(), contains('mlat=38.885000'));
    });
  });
}
