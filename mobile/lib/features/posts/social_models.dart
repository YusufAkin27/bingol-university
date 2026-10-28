// Takip modelleri. Tüm `fromJson`lar null-güvenlidir.

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// `{items:[...]}` ya da düz liste gövdesinden satırları çıkarır.
List<Map<String, dynamic>> socialItems(Object? body) => body is Map ? _maps(body['items']) : _maps(body);

/// Küçük kullanıcı kartı (öneri, takipçi satırı, hikâye izleyeni).
class SocialUser {
  const SocialUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.department,
    this.followedByMe = false,
    this.at,
  });

  factory SocialUser.fromJson(Map<String, dynamic>? j) => SocialUser(
        id: _int(j?['id'] ?? j?['userId']),
        displayName: _str(j?['displayName']) ?? '',
        avatarUrl: _str(j?['avatarUrl']),
        department: _str(j?['department']),
        followedByMe: j?['followedByMe'] == true || j?['following'] == true,
        at: _str(j?['viewedAt'] ?? j?['followedAt']),
      );

  final int id;
  final String displayName;
  final String? avatarUrl;
  final String? department;
  final bool followedByMe;

  /// İzlenme / takip zamanı (varsa).
  final String? at;
}

/// Takip et/bırak yanıtı: `{following, followerCount}`.
class FollowResult {
  const FollowResult({this.following, this.followerCount});

  factory FollowResult.fromJson(Object? j) {
    if (j is! Map) return const FollowResult();
    final c = j['followerCount'];
    return FollowResult(following: j['following'] is bool ? j['following'] as bool : null, followerCount: c is num ? c.toInt() : null);
  }

  final bool? following;
  final int? followerCount;
}

/// Bir kullanıcının takip özeti.
class FollowStats {
  const FollowStats({this.followers = 0, this.following = 0, this.followedByMe = false, this.followsMe = false});

  factory FollowStats.fromJson(Map<String, dynamic>? j) => FollowStats(
        followers: _int(j?['followerCount'] ?? j?['followers']),
        following: _int(j?['followingCount'] ?? _intOrNull(j?['following'])),
        followedByMe: j?['followedByMe'] == true,
        followsMe: j?['followsMe'] == true,
      );

  final int followers;
  final int following;
  final bool followedByMe;
  final bool followsMe;

  FollowStats copyWith({int? followers, bool? followedByMe}) => FollowStats(
        followers: followers ?? this.followers,
        following: following,
        followedByMe: followedByMe ?? this.followedByMe,
        followsMe: followsMe,
      );
}
