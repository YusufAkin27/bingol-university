import '../../../core/session.dart';

/// Sessize alınmış (kimliği bilinen) kullanıcı satırı (`GET /api/forum/mutes`). Sessize alma/geri alma
/// `ForumApi.muteUser`, bu yalnız LİSTE ucudur.
class ForumMutedUser {
  const ForumMutedUser({required this.userId, required this.displayName, this.avatarUrl});

  final int userId;
  final String displayName;
  final String? avatarUrl;

  static ForumMutedUser? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final user = raw['user'] is Map ? raw['user'] as Map : raw;
    final id = user['userId'] ?? user['id'] ?? raw['mutedUserId'];
    final n = id is num ? id.toInt() : int.tryParse('${id ?? ''}');
    if (n == null || n <= 0) return null;
    final name = '${user['displayName'] ?? user['name'] ?? ''}'.trim();
    final avatar = user['avatarUrl'];
    return ForumMutedUser(userId: n, displayName: name, avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null);
  }
}

/// Sessize alınanlar. Sunucu düz liste ya da `{items}` döndürebilir (sözleşmede biçim sabitlenmemiş: ikisi de kabul).
Future<List<ForumMutedUser>> fetchForumMutes(Session session, {bool force = false}) async {
  final r = await session.api.get('/forum/mutes', force: force);
  final raw = r is Map ? r['items'] : r;
  return [
    if (raw is List)
      for (final e in raw)
        if (ForumMutedUser.tryParse(e) case final m?) m
  ];
}
