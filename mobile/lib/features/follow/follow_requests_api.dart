import '../../core/session.dart';
import '../posts/post_models.dart' show PostPage;

/// Gelen takip isteği satırı (`GET /users/me/follow-requests`): yalnız GİZLİ hesaplar istek alır.
class FollowRequest {
  const FollowRequest({required this.userId, required this.displayName, this.avatarUrl, this.department, this.requestedAt});

  factory FollowRequest.fromJson(Map<String, dynamic> j) {
    final id = j['userId'] ?? j['id'];
    String? s(Object? v) => v is String && v.isNotEmpty ? v : null;
    return FollowRequest(
      userId: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      displayName: s(j['displayName']) ?? '',
      avatarUrl: s(j['avatarUrl']),
      department: s(j['department']),
      requestedAt: s(j['requestedAt']),
    );
  }

  final int userId;
  final String displayName;
  final String? avatarUrl;
  final String? department;
  final String? requestedAt;
}

/// Takip isteği uçları (tek HTTP katmanı `session.api`).
class FollowRequestsApi {
  FollowRequestsApi(this.session);

  final Session session;

  /// `GET /users/me/follow-requests?size=&cursor=` (imleçli sayfa).
  Future<PostPage<FollowRequest>> list({String? cursor, int size = 30}) async {
    final q = 'size=$size${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
    return PostPage.parse(await session.api.get('/users/me/follow-requests?$q', force: true), FollowRequest.fromJson);
  }

  /// `GET /users/me/follow-requests/count` -> `{count}`; alınamazsa null.
  Future<int?> count() async {
    final r = await session.api.get('/users/me/follow-requests/count', force: true);
    final c = r is Map ? r['count'] : null;
    return c is num ? c.toInt() : null;
  }

  static int? _count(Object? r) {
    final c = r is Map ? r['count'] : null;
    return c is num ? c.toInt() : null;
  }

  /// `POST /users/me/follow-requests/{userId}/accept` -> `{count}` (kalan bekleyen istek sayısı; yoksa null).
  Future<int?> accept(int userId) async => _count(await session.api.post('/users/me/follow-requests/$userId/accept'));

  /// `POST /users/me/follow-requests/{userId}/decline` -> `{count}`.
  Future<int?> decline(int userId) async => _count(await session.api.post('/users/me/follow-requests/$userId/decline'));
}
