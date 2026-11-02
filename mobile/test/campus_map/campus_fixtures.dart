import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/features/campus_map/campus_models.dart';
import 'package:bu_kampus/features/campus_map/campus_repository.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/painting.dart';

/// 1x1 saydam PNG: testte ağ yerine karo olarak kullanılır.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class NoTiles extends TileProvider {
  NoTiles() : super();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_png);
}

/// Sözleşme gövdeleri (GET /api/campus/map ve /places) örneği: gerçek ana yerleşke (harita.bingol.edu.tr) civarı.
Map<String, Object?> campusMapJson({bool satellite = false}) => {
      'version': '2026-11-02',
      'center': {'lat': 38.8995, 'lng': 40.4875},
      'zoom': {'initial': 16, 'min': 14, 'max': 19},
      'bounds': {'south': 38.894, 'west': 40.474, 'north': 38.908, 'east': 40.498},
      'boundary': [
        [38.8945, 40.4780],
        [38.9070, 40.4770],
        [38.9075, 40.4960],
        [38.8950, 40.4965],
      ],
      'tiles': {
        'urlTemplate': 'https://tiles.kampus.example/{z}/{x}/{y}.png',
        'attribution': '© OpenStreetMap contributors',
        'maxNativeZoom': 19,
        'userAgentHint': 'BuKampus/2',
        if (satellite) 'satellite': {'urlTemplate': 'https://sat.example.bingol.edu.tr/{z}/{x}/{y}.jpg', 'attribution': 'Sat', 'maxNativeZoom': 18},
      },
      'categories': [
        {'key': 'faculty', 'label': 'Fakülteler', 'icon': 'graduation-cap', 'color': '#C0392B'},
        {'key': 'food', 'label': 'Yemekhane', 'icon': 'utensils', 'color': '#1E7A50'},
        {'key': 'library', 'label': 'Kütüphane', 'icon': 'library', 'color': '#1F4E96'},
        {'key': 'service', 'label': 'Hizmet', 'icon': 'bilinmeyen-simge', 'color': '#000000'},
      ],
    };

Map<String, Object?> campusPlacesJson() => {
      'items': [
        {
          'id': 1,
          'name': 'Mühendislik Fakültesi',
          'category': 'faculty',
          'lat': 38.8990,
          'lng': 40.4860,
          'summary': 'Mühendislik bölümleri.',
          'photoUrl': null,
          'departments': ['Bilgisayar Mühendisliği', 'İnşaat Mühendisliği', 'Makine Mühendisliği'],
          'webUrl': 'https://muh.bingol.edu.tr',
          'remote': false,
          'footprint': [
            [38.8989, 40.4859],
            [38.8989, 40.4862],
            [38.8992, 40.4862],
            [38.8992, 40.4859],
          ],
          'sortKey': 10,
        },
        {'id': 2, 'name': 'Merkez Kütüphane', 'category': 'library', 'lat': 38.8984, 'lng': 40.4857, 'summary': '', 'photoUrl': null, 'departments': [], 'footprint': null, 'sortKey': 20},
        {'id': 3, 'name': 'Merkezi Kafeterya', 'category': 'food', 'lat': 38.8980, 'lng': 40.4888, 'summary': '', 'photoUrl': null, 'departments': [], 'footprint': null, 'sortKey': 30},
        {'id': 4, 'name': 'Fen Edebiyat Fakültesi', 'category': 'faculty', 'lat': 38.8980, 'lng': 40.4869, 'summary': '', 'photoUrl': null, 'departments': [], 'webUrl': 'http://kotu.example.com/x', 'footprint': null, 'sortKey': 40},
        // Ana yerleşke dışı: haritada iğne yok, "Diğer yerleşkeler" grubunda.
        {'id': 5, 'name': 'Hayvan Hastanesi', 'category': 'service', 'lat': 38.9197, 'lng': 40.4694, 'summary': '', 'photoUrl': null, 'departments': [], 'webUrl': 'https://hayvanhastanesi.bingol.edu.tr', 'remote': true, 'footprint': null, 'sortKey': 50},
        // Bozuk kayıtlar atlanmalı:
        {'id': 7, 'name': '', 'category': 'faculty', 'lat': 38.88, 'lng': 40.49},
        {'id': 6, 'name': 'Koordinatsız', 'category': 'faculty'},
      ],
    };

CampusMapConfig sampleConfig({bool satellite = false}) => CampusMapConfig.tryParse(campusMapJson(satellite: satellite))!;

List<CampusPlace> samplePlaces() => CampusPlace.parseList(campusPlacesJson());

/// Testte sunucu yerine geçen depo.
class FakeCampusRepo implements CampusMapRepository {
  FakeCampusRepo({this.config, this.places, this.error, this.stale = false, this.delay = Duration.zero});

  CampusMapConfig? config;
  List<CampusPlace>? places;
  Object? error;
  bool stale;
  Duration delay;
  int loads = 0;
  int placeCalls = 0;

  @override
  Future<CampusMapConfig> loadConfig({bool force = false}) async {
    loads++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return config ?? sampleConfig();
  }

  @override
  Future<({List<CampusPlace> items, bool stale})> loadPlaces({bool force = false}) async {
    if (error != null) throw error!;
    return (items: places ?? samplePlaces(), stale: stale);
  }

  @override
  Future<CampusPlace?> place(int id) async {
    placeCalls++;
    for (final p in places ?? samplePlaces()) {
      if (p.id == id) return p;
    }
    return null;
  }
}

ApiError networkError() => ApiError(0, 'NETWORK', '');
