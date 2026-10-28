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

  Future<FollowStats> followStats(int userId) async =>
      FollowStats.fromJson((await session.api.get('/users/$userId/follow-stats')) as Map<String, dynamic>?);

  Future<void> follow(int userId) => session.api.put('/users/$userId/follow');

  Future<void> unfollow(int userId) => session.api.delete('/users/$userId/follow');

  Future<PostPage<SocialUser>> followers(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/followers${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<PostPage<SocialUser>> following(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/following${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<List<SocialUser>> followSuggestions({int size = 20}) async {
    final r = await session.api.get('/users/me/follow-suggestions${_q({'size': size})}');
    return [for (final m in socialItems(r)) SocialUser.fromJson(m)];
  }
}
