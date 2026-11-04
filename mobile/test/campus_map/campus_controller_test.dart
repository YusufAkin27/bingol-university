import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/features/campus_map/campus_local_store.dart';
import 'package:bu_kampus/features/campus_map/campus_location.dart';
import 'package:bu_kampus/features/campus_map/campus_map_controller.dart';
import 'package:bu_kampus/features/campus_map/campus_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../support/fake_app.dart';
import 'campus_fixtures.dart';

const _inside = LatLng(38.8991, 40.4861); // kampüs içinde, Mühendislik yakını
const _outside = LatLng(38.9800, 40.6000);

CampusMapController make(FakeCampusRepo repo, FakeCampusLocationService loc, {String? hint, int? placeId, DateTime Function()? now}) =>
    CampusMapController(repo: repo, location: loc, categoryHint: hint, initialPlaceId: placeId, now: now);

void main() {
  setUp(mockSecureStorage);

  group('yükleme durumları', () {
    test('hazır: ayar + yerler gelir', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService());
      expect(c.load, CampusLoad.loading);
      await c.start();
      expect(c.load, CampusLoad.ready);
      expect(c.places, hasLength(5));
      expect(c.config!.categories, hasLength(4));
      expect(c.filtered, hasLength(4), reason: 'uzak yerleşke haritada iğne olmaz');
      expect(c.remotes.map((p) => p.id), [5]);
      c.dispose();
    });

    test('ağ hatası -> error, yeniden dene -> ready', () async {
      final repo = FakeCampusRepo(error: networkError());
      final c = make(repo, FakeCampusLocationService());
      await c.start();
      expect(c.load, CampusLoad.error);
      repo.error = null;
      await c.refresh(force: true);
      expect(c.load, CampusLoad.ready);
      c.dispose();
    });

    test('503 -> bakım durumu', () async {
      final c = make(FakeCampusRepo(error: ApiError(503, 'MAINTENANCE', '')), FakeCampusLocationService());
      await c.start();
      expect(c.load, CampusLoad.maintenance);
      c.dispose();
    });

    test('bozuk gövde (BAD_RESPONSE) -> error, çökmez', () async {
      final c = make(FakeCampusRepo(error: ApiError(0, 'BAD_RESPONSE', '')), FakeCampusLocationService());
      await c.start();
      expect(c.load, CampusLoad.error);
      c.dispose();
    });

    test('boş yer listesi: ready ama liste boş', () async {
      final c = make(FakeCampusRepo(places: const []), FakeCampusLocationService());
      await c.start();
      expect(c.load, CampusLoad.ready);
      expect(c.nearby(), isEmpty);
      c.dispose();
    });

    test('önbellekten (bayat) gelen liste işaretlenir', () async {
      final c = make(FakeCampusRepo(stale: true), FakeCampusLocationService());
      await c.start();
      expect(c.stale, isTrue);
      c.dispose();
    });
  });

  group('kategori çipleri ve süzme', () {
    test('kategori seçimi listeyi süzer, Tümü geri getirir', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService());
      await c.start();
      c.selectCategory('faculty');
      expect(c.filtered.map((p) => p.id), [1, 4]);
      c.selectCategory(null);
      expect(c.filtered, hasLength(4));
      c.dispose();
    });

    test('ana sayfa çip ipucu ("Yemekhane") ilgili kategoriyi seçer', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService(), hint: 'Yemekhane');
      await c.start();
      expect(c.category, 'food');
      final f = make(FakeCampusRepo(), FakeCampusLocationService(), hint: 'Fakülteler');
      await f.start();
      expect(f.category, 'faculty');
      final k = make(FakeCampusRepo(), FakeCampusLocationService(), hint: 'kutuphane');
      await k.start();
      expect(k.category, 'library', reason: 'aksan duyarsız');
      final none = make(FakeCampusRepo(), FakeCampusLocationService(), hint: 'Havuz');
      await none.start();
      expect(none.category, isNull);
      for (final x in [c, f, k, none]) {
        x.dispose();
      }
    });

    test('süzgeç seçili yeri dışarıda bırakırsa seçim kalkar', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService());
      await c.start();
      c.select(2); // kütüphane
      c.selectCategory('faculty');
      expect(c.selectedId, isNull);
      c.dispose();
    });

    test('uzak yerleşke: iğne/seçim yok, mesafe yok, kategori süzgecinde de ayrı kalır', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(_inside));
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      final far = c.places.firstWhere((p) => p.id == 5);
      expect(c.isRemote(far), isTrue);
      expect(c.distanceTo(far), isNull, reason: 'kuş uçuşu mesafe uzak yerleşke için anlamsız');
      c.select(5);
      expect(c.selectedId, isNull);
      expect(c.nearby().any((p) => p.id == 5), isFalse);
      c.selectCategory('service');
      expect(c.filtered, isEmpty);
      expect(c.remotes.map((p) => p.id), [5]);
      c.dispose();
    });

    test('sunucu remote demese de sınır kutusunun dışındaki yer uzak sayılır', () async {
      final far = {'id': 9, 'name': 'Uzak Tesis', 'category': 'service', 'lat': 38.99, 'lng': 40.67};
      final repo = FakeCampusRepo(places: CampusPlace.parseList({'items': [far]}));
      final c = make(repo, FakeCampusLocationService());
      await c.start();
      expect(c.remotes, hasLength(1));
      expect(c.filtered, isEmpty);
      c.dispose();
    });

    test('derin bağlantı: placeId liste dışındaysa tek yer getirilip seçilir', () async {
      final repo = FakeCampusRepo(places: samplePlaces().sublist(0, 2));
      final c = make(repo, FakeCampusLocationService(), placeId: 1);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.selectedId, 1);
      expect(repo.placeCalls, 0, reason: 'listede varsa ek istek yok');
      c.dispose();
    });
  });

  group('konum izin akışları (sahte servis)', () {
    test('izin hiç sorulmadı -> promptNeeded; sistem istemi ÇIKMAZ', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.denied);
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      expect(c.loc, CampusLocState.promptNeeded);
      expect(loc.requests, 0, reason: 'açılışta kullanıcıya sormadan istem yok');
      expect(c.fix, isNull);
      c.dispose();
    });

    test('İzin ver -> granted + konum gelir; mesafe/yürüme istemcide hesaplanır', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.denied, fix: const CampusFix(_inside, accuracy: 12));
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      await c.requestLocation();
      expect(loc.requests, 1);
      expect(c.loc, CampusLocState.granted);
      expect(c.hasFix, isTrue);
      expect(c.userInside, isTrue);
      final first = c.nearby().first;
      expect(first.id, 1, reason: 'en yakın yer başta');
      expect(c.distanceTo(first)!, lessThan(60));
      expect(c.walkMinutesTo(first), 1);
      // akıştan yeni konum
      loc.emit(const CampusFix(LatLng(38.8981, 40.4870)));
      await Future<void>.delayed(Duration.zero);
      expect(c.nearby().first.id, 4);
      c.dispose();
    });

    test('reddedildi -> denied, harita yine çalışır (liste var, konum yok)', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.denied, onRequest: CampusPerm.denied);
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      await c.requestLocation();
      expect(c.loc, CampusLocState.denied);
      expect(c.load, CampusLoad.ready);
      expect(c.fix, isNull);
      expect(c.nearby(), hasLength(4), reason: 'sıra anahtarına göre');
      expect(c.distanceTo(c.places.first), isNull);
      c.dispose();
    });

    test('kalıcı reddedildi -> deniedForever (Ayarları aç bandı)', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await c.start();
      expect(c.loc, CampusLocState.deniedForever);
      await c.requestLocation();
      expect(c.loc, CampusLocState.deniedForever);
      c.dispose();
    });

    test('cihaz konum servisi kapalı -> serviceOff', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService(perm: CampusPerm.granted, enabled: false));
      await c.start();
      expect(c.loc, CampusLocState.serviceOff);
      expect(c.fix, isNull);
      c.dispose();
    });

    test('Şimdi değil: kart kalkar, yeniden sorulmaz', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.denied);
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      c.dismissPrompt();
      expect(c.loc, CampusLocState.denied);
      expect(c.promptDismissed, isTrue);
      await c.initLocation();
      expect(c.loc, CampusLocState.denied, reason: 'oturum içinde kart tekrar çıkmaz');
      c.dispose();
    });

    test('kampüs dışı konum: userInside=false (kampüs dışı bandı)', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(_outside));
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.userInside, isFalse);
      c.dispose();
    });

    test('YALNIZ ön plan: pause akışı keser, resume yeniden başlatır', () async {
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(_inside));
      final c = make(FakeCampusRepo(), loc);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      c.pause();
      final before = c.fix;
      loc.emit(const CampusFix(LatLng(38.8981, 40.4870)));
      await Future<void>.delayed(Duration.zero);
      expect(identical(c.fix, before), isTrue, reason: 'arka planda konum işlenmez');
      await c.resume();
      await Future<void>.delayed(Duration.zero);
      loc.emit(const CampusFix(LatLng(38.8984, 40.4857)));
      await Future<void>.delayed(Duration.zero);
      expect(c.nearby().first.id, 2);
      c.dispose();
    });
  });

  group('yerel favori', () {
    test('favori eklenir/çıkarılır ve kalıcıdır; clear siler', () async {
      final c = make(FakeCampusRepo(), FakeCampusLocationService());
      await c.start();
      await c.toggleFavorite(3);
      expect(c.isFavorite(3), isTrue);
      expect(await CampusLocalStore.loadFavorites(), {3});
      await c.toggleFavorite(3);
      expect(c.isFavorite(3), isFalse);
      expect(await CampusLocalStore.loadFavorites(), isEmpty);
      await c.toggleFavorite(1);
      await CampusLocalStore.clear();
      expect(await CampusLocalStore.loadFavorites(), isEmpty);
      c.dispose();
    });

    test('yeni denetleyici kayıtlı favorileri yükler', () async {
      await CampusLocalStore.saveFavorites({2, 4});
      final c = make(FakeCampusRepo(), FakeCampusLocationService());
      await c.start();
      expect(c.favorites, {2, 4});
      await CampusLocalStore.clear();
      c.dispose();
    });
  });

  group('son aramalar (yerel)', () {
    String fold(String s) => s.toLowerCase();

    test('en yeni başta, tekrarsız, en çok 8, çok kısa terim eklenmez', () {
      var r = <String>[];
      for (final t in ['a1', 'b2', 'c3']) {
        r = CampusLocalStore.pushRecent(r, t, fold);
      }
      expect(r, ['c3', 'b2', 'a1']);
      r = CampusLocalStore.pushRecent(r, 'B2', fold);
      expect(r, ['B2', 'c3', 'a1']);
      expect(CampusLocalStore.pushRecent(r, ' x ', fold), r);
      for (var i = 0; i < 12; i++) {
        r = CampusLocalStore.pushRecent(r, 'terim$i', fold);
      }
      expect(r, hasLength(CampusLocalStore.maxRecent));
      expect(r.first, 'terim11');
    });

    test('kaydet / yükle / temizle', () async {
      await CampusLocalStore.saveRecent(['Kütüphane', 'Yemekhane']);
      expect(await CampusLocalStore.loadRecent(), ['Kütüphane', 'Yemekhane']);
      await CampusLocalStore.saveRecent(const []);
      expect(await CampusLocalStore.loadRecent(), isEmpty);
    });
  });

  group('karo hataları', () {
    test('eşik aşılınca band, 30 sn sessizlikte ya da retry ile kalkar', () async {
      var now = DateTime(2026, 11, 2, 12);
      final c = make(FakeCampusRepo(), FakeCampusLocationService(), now: () => now);
      await c.start();
      for (var i = 0; i < CampusMapController.tileErrorThreshold - 1; i++) {
        c.noteTileError();
      }
      expect(c.tilesFailing, isFalse);
      c.noteTileError();
      expect(c.tilesFailing, isTrue);
      c.clearTileErrors();
      expect(c.tilesFailing, isFalse);
      // 20 sn'den eski hatalar sayılmaz
      for (var i = 0; i < 5; i++) {
        c.noteTileError();
      }
      now = now.add(const Duration(seconds: 25));
      c.noteTileError();
      expect(c.tilesFailing, isFalse);
      c.dispose();
    });
  });
}
