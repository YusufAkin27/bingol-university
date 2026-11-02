import '../../core/api.dart';
import 'campus_models.dart';

/// Sunucu sözleşmesi katmanı: ekranlar yalnız bunu görür (testte sahte uygulama verilir).
abstract class CampusMapRepository {
  /// `GET /api/campus/map`. Bozuk gövdede [ApiError] (BAD_RESPONSE).
  Future<CampusMapConfig> loadConfig({bool force = false});

  /// `GET /api/campus/places?limit=` (tek istek; süzme/arama istemcide). [stale]: yanıt önbellekten (ağ yok).
  Future<({List<CampusPlace> items, bool stale})> loadPlaces({bool force = false});

  /// `GET /api/campus/places/{id}`; bulunamazsa null.
  Future<CampusPlace?> place(int id);
}

/// Tek HTTP katmanı [ApiClient] üzerinden (ETag/304 + disk önbelleği `CachePolicy`'de).
class ApiCampusMapRepository implements CampusMapRepository {
  ApiCampusMapRepository(this.api);

  final ApiClient api;

  /// Kampüs yerleri küçük veridir (yüzlerce kayıt); tek istekle alınır.
  static const placesPath = '/campus/places?limit=500';

  @override
  Future<CampusMapConfig> loadConfig({bool force = false}) async {
    final body = await api.get('/campus/map', force: force);
    final c = CampusMapConfig.tryParse(body);
    if (c == null) throw ApiError(0, 'BAD_RESPONSE', '');
    return c;
  }

  @override
  Future<({List<CampusPlace> items, bool stale})> loadPlaces({bool force = false}) async {
    final r = await api.getResponse(placesPath, force: force);
    return (items: CampusPlace.parseList(r.body), stale: r.fromCache);
  }

  @override
  Future<CampusPlace?> place(int id) async {
    try {
      return CampusPlace.tryParse(await api.get('/campus/places/$id'));
    } on ApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }
}
