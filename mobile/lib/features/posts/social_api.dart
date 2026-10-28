import '../../core/session.dart';
import 'post_models.dart';
import 'social_models.dart';

/// Takip uçları (kaydetme, etiket ve hikâye uçları kaldırıldı). Tek HTTP katmanı `session.api`.
class SocialApi {
  SocialApi(this.session);

  final Session session;

  String _q(Map<String, Object?> p) {
    final parts = <String>[
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // ---------- Takip ----------

  /// Takip sayaçları ve ilişki bayrakları ayrı bir uçta değil, profil yanıtındadır
  /// (`GET /users/{id}`: followerCount, followingCount, followedByMe, followsMe).
  Future<FollowStats> followStats(int userId) async {
    final r = await session.api.get('/users/$userId');
    return FollowStats.fromJson(r is Map ? Map<String, dynamic>.from(r) : null);
  }

  /// `POST /users/{id}/follow` -> `{following, followerCount}`.
  Future<FollowResult> follow(int userId) async =>
      FollowResult.fromJson(await session.api.post('/users/$userId/follow'));

  /// `DELETE /users/{id}/follow` -> `{following, followerCount}`.
  Future<FollowResult> unfollow(int userId) async =>
      FollowResult.fromJson(await session.api.delete('/users/$userId/follow'));

  Future<PostPage<SocialUser>> followers(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/followers${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<PostPage<SocialUser>> following(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/following${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<List<SocialUser>> followSuggestions({int size = 20}) async {
    final r = await session.api.get('/users/me/follow-suggestions${_q({'size': size})}');
    return [for (final m in socialItems(r)) SocialUser.fromJson(m)];
  }
}
