import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import 'campus_geo.dart';
import 'campus_local_store.dart';
import 'campus_location.dart';
import 'campus_models.dart';
import 'campus_repository.dart';

enum CampusLoad { loading, ready, error, maintenance }

/// Konum kartı/bandı durumu. [promptNeeded]: izin henüz sorulmadı (tasarımdaki "Konumunuzu kullanalım mı?" kartı).
enum CampusLocState { unknown, promptNeeded, granted, denied, deniedForever, serviceOff, unsupported }

/// Harita ekranlarının durumu (saf Dart; widget bağımlılığı yok, testi kolay).
/// Konum yalnız bellekte tutulur: sunucuya gitmez, diske yazılmaz, loglanmaz.
class CampusMapController extends ChangeNotifier {
  CampusMapController({
    required this.repo,
    CampusLocationService? location,
    this.categoryHint,
    this.initialPlaceId,
    DateTime Function()? now,
  })  : _location = location ?? CampusLocationService.instance,
        _now = now ?? DateTime.now;

  final CampusMapRepository repo;
  final CampusLocationService _location;
  final DateTime Function() _now;

  /// Kısayol/çipten gelen kategori ipucu ("Yemekhane"): etiketi eşleşen kategori seçilir.
  final String? categoryHint;
  final int? initialPlaceId;

  CampusLoad load = CampusLoad.loading;
  CampusMapConfig? config;
  List<CampusPlace> places = const [];

  /// Yer listesi/ayar önbellekten (ağ yok) sunuluyor.
  bool stale = false;

  String? category; // null = Tümü
  int? selectedId;
  Set<int> favorites = {};

  CampusLocState loc = CampusLocState.unknown;
  CampusFix? fix;

  /// "Şimdi değil": bu oturumda izin kartını tekrar gösterme.
  bool promptDismissed = false;

  bool _disposed = false;
  bool _paused = false;
  StreamSubscription<CampusFix>? _sub;

  // --- veri ---------------------------------------------------------------

  Future<void> start() async {
    favorites = await CampusLocalStore.loadFavorites();
    promptDismissed = await CampusLocalStore.loadPromptDismissed();
    await refresh();
    if (load == CampusLoad.ready) await initLocation();
  }

  Future<void> refresh({bool force = false}) async {
    load = CampusLoad.loading;
    _notify();
    try {
      final results = await Future.wait([repo.loadConfig(force: force), repo.loadPlaces(force: force)]);
      config = results[0] as CampusMapConfig;
      final p = results[1] as ({List<CampusPlace> items, bool stale});
      places = p.items;
      stale = p.stale;
      load = CampusLoad.ready;
      _applyHints();
    } on ApiError catch (e) {
      load = (e.status == 503 || e.code == 'MAINTENANCE') ? CampusLoad.maintenance : CampusLoad.error;
    } catch (_) {
      load = CampusLoad.error;
    }
    _notify();
    if (load == CampusLoad.ready && initialPlaceId != null && selectedId == null) unawaited(_selectInitial());
  }

  void _applyHints() {
    final hint = categoryHint;
    if (hint == null || category != null || config == null) return;
    final h = normalizeTr(hint).trim();
    if (h.isEmpty) return;
    for (final c in config!.categories) {
      final l = normalizeTr(c.label), k = normalizeTr(c.key);
      if (l.contains(h) || h.contains(l) || k.contains(h)) {
        category = c.key;
        return;
      }
    }
  }

  Future<void> _selectInitial() async {
    final id = initialPlaceId!;
    if (places.any((p) => p.id == id)) {
      select(id);
      return;
    }
    try {
      final p = await repo.place(id);
      if (p != null && !_disposed) {
        places = [...places, p];
        select(p.id);
      }
    } catch (_) {}
  }

  /// Ana yerleşke dışındaki yer mi (sunucu `remote` ya da kamera sınır kutusunun dışında).
  bool isRemote(CampusPlace p) {
    final c = config;
    return p.remote || (c != null && !c.bounds.contains(p.point));
  }

  /// Haritada iğneyle gösterilen yerler: ana yerleşke, kategori süzgecine uyanlar.
  List<CampusPlace> get filtered => [
        for (final p in places)
          if (!isRemote(p) && (category == null || p.category == category)) p,
      ];

  /// "Diğer yerleşkeler" grubu (haritada iğnesi yok; yalnız liste/arama/detay).
  List<CampusPlace> get remotes => [
        for (final p in places)
          if (isRemote(p) && (category == null || p.category == category)) p,
      ];

  CampusPlace? get selected {
    for (final p in places) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  CampusCategory? categoryOf(CampusPlace p) => config?.category(p.category);

  void selectCategory(String? key) {
    if (category == key) return;
    category = key;
    // Süzgeç seçili yeri dışarıda bırakıyorsa seçim kalkar.
    final s = selected;
    if (s != null && key != null && s.category != key) selectedId = null;
    _notify();
  }

  void select(int? id) {
    if (id != null && places.any((p) => p.id == id && isRemote(p))) return; // uzak yerleşkenin haritada iğnesi yok
    if (selectedId == id) return;
    selectedId = id;
    _notify();
  }

  /// Mesafeye göre (konum varsa) sıralı liste; sırasıyla [limit] kadar.
  List<CampusPlace> nearby({int? limit, bool all = false}) {
    final src = all ? [for (final p in places) if (!isRemote(p)) p] : filtered;
    final sorted = sortByDistance(src, fix?.point);
    return limit == null ? sorted : sorted.take(limit).toList();
  }

  /// Uzak yerleşkelerde kuş uçuşu mesafe/yürüme süresi anlamsızdır: null.
  double? distanceTo(CampusPlace p) => (fix == null || isRemote(p)) ? null : meters(fix!.point, p.point);

  int? walkMinutesTo(CampusPlace p) {
    final d = distanceTo(p);
    return d == null ? null : walkMinutes(d);
  }

  bool get hasFix => fix != null;

  /// Kullanıcı kampüs sınırları içinde mi (konum yoksa null).
  bool? get userInside {
    final f = fix, c = config;
    if (f == null || c == null) return null;
    return insideCampus(f.point, c);
  }

  bool isFavorite(int id) => favorites.contains(id);

  Future<void> toggleFavorite(int id) async {
    favorites = {...favorites};
    if (!favorites.remove(id)) favorites.add(id);
    _notify();
    await CampusLocalStore.saveFavorites(favorites);
  }

  // --- konum ----------------------------------------------------------------

  /// Sayfa açılışında: istem ÇIKARMADAN durumu okur; izin varsa akışı başlatır.
  Future<void> initLocation() async {
    final perm = await _location.permission();
    if (_disposed) return;
    switch (perm) {
      case CampusPerm.granted:
        await _startTracking();
      case CampusPerm.denied:
        loc = promptDismissed ? CampusLocState.denied : CampusLocState.promptNeeded;
        _notify();
      case CampusPerm.deniedForever:
        loc = CampusLocState.deniedForever;
        _notify();
      case CampusPerm.unsupported:
        loc = CampusLocState.unsupported;
        _notify();
    }
  }

  /// Kullanıcı "İzin ver" / "Konumum" dedi: gerekirse sistem istemi gösterir.
  Future<void> requestLocation() async {
    var perm = await _location.permission();
    if (perm == CampusPerm.denied) perm = await _location.request();
    if (_disposed) return;
    switch (perm) {
      case CampusPerm.granted:
        await _startTracking();
      case CampusPerm.denied:
        loc = CampusLocState.denied;
        _notify();
      case CampusPerm.deniedForever:
        loc = CampusLocState.deniedForever;
        _notify();
      case CampusPerm.unsupported:
        loc = CampusLocState.unsupported;
        _notify();
    }
  }

  void dismissPrompt() {
    promptDismissed = true;
    unawaited(CampusLocalStore.savePromptDismissed());
    if (loc == CampusLocState.promptNeeded) loc = CampusLocState.denied;
    _notify();
  }

  Future<void> _startTracking() async {
    if (!await _location.serviceEnabled()) {
      loc = CampusLocState.serviceOff;
      await _sub?.cancel();
      _sub = null;
      fix = null;
      _notify();
      return;
    }
    loc = CampusLocState.granted;
    _notify();
    if (_paused) return;
    await _sub?.cancel();
    _sub = _location.positions().listen((f) {
      fix = f;
      _notify();
    }, onError: (_) {});
    final first = await _location.current();
    if (first != null && fix == null && !_disposed) {
      fix = first;
      _notify();
    }
  }

  /// Uygulama arka plana gitti: konum akışı durur (YALNIZ ön plan).
  void pause() {
    _paused = true;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Ön plana dönüş: ayarlardan izin/servis değişmiş olabilir, yeniden okunur.
  Future<void> resume() async {
    _paused = false;
    if (load == CampusLoad.ready) await initLocation();
  }

  // --- karo hataları ---------------------------------------------------------------

  final List<DateTime> _tileErrors = [];

  /// Son 20 sn içinde en az [tileErrorThreshold] karo hatası: harita karoları yüklenemiyor.
  static const tileErrorThreshold = 6;
  bool tilesFailing = false;
  Timer? _tileTimer;

  void noteTileError() {
    final t = _now();
    _tileErrors
      ..removeWhere((e) => t.difference(e) > const Duration(seconds: 20))
      ..add(t);
    // Hata akışı kesilince (karolar yeniden geliyor) band kendiliğinden kalkar.
    _tileTimer?.cancel();
    _tileTimer = Timer(const Duration(seconds: 30), clearTileErrors);
    if (!tilesFailing && _tileErrors.length >= tileErrorThreshold) {
      tilesFailing = true;
      _notify();
    }
  }

  void clearTileErrors() {
    _tileTimer?.cancel();
    _tileErrors.clear();
    if (tilesFailing) {
      tilesFailing = false;
      _notify();
    }
  }

  // --- yardımcı -------------------------------------------------------------------

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tileTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// Test/kamera için: kampüs merkezi.
  LatLng? get center => config?.center;
}
