// Takip modelleri. Tüm `fromJson`lar null-güvenlidir.

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// `{items:[...]}` ya da düz liste gövdesinden satırları çıkarır.
List<Map<String, dynamic>> socialItems(Object? body) => body is Map ? _maps(body['items']) : _maps(body);

/// Takip ilişkisi (sunucu `followState`): `NONE | REQUESTED | FOLLOWING | SELF`. Düğmenin TEK kaynağıdır.
/// Eski sunucu yanıtında alan yoksa [followStateOf] `followedByMe` bayrağından türetir.
enum FollowState { none, requested, following, self }

/// `followState` metnini çözer; bilinmeyen/eksik değerde [fallbackFollowing] (eski `followedByMe`) kullanılır.
FollowState followStateOf(Object? v, {bool fallbackFollowing = false}) {
  if (v is String) {
    switch (v.trim().toUpperCase()) {
      case 'FOLLOWING':
        return FollowState.following;
      case 'REQUESTED':
        return FollowState.requested;
      case 'SELF':
        return FollowState.self;
      case 'NONE':
        return FollowState.none;
    }
  }
  return fallbackFollowing ? FollowState.following : FollowState.none;
}

/// Küçük kullanıcı kartı (öneri, takipçi satırı, hikâye izleyeni).
class SocialUser {
  const SocialUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.department,
    this.followedByMe = false,
    this.followState = FollowState.none,
    this.hasFollowState = false,
    this.isPrivate = false,
    this.locked = false,
    this.at,
  });

  factory SocialUser.fromJson(Map<String, dynamic>? j) {
    final legacy = j?['followedByMe'] == true || j?['following'] == true;
    final st = followStateOf(j?['followState'], fallbackFollowing: legacy);
    return SocialUser(
      id: _int(j?['id'] ?? j?['userId']),
      displayName: _str(j?['displayName']) ?? '',
      avatarUrl: _str(j?['avatarUrl']),
      department: _str(j?['department']),
      followedByMe: st == FollowState.following,
      followState: st,
      hasFollowState: j?['followState'] is String,
      isPrivate: j?['isPrivate'] == true,
      locked: j?['locked'] == true,
      at: _str(j?['viewedAt'] ?? j?['followedAt']),
    );
  }

  final int id;
  final String displayName;
  final String? avatarUrl;
  final String? department;

  /// Eski bayrak: yalnız `followState == FOLLOWING`.
  final bool followedByMe;

  /// `NONE | REQUESTED | FOLLOWING | SELF` (alan yoksa `followedByMe`'den türetilir).
  final FollowState followState;

  /// Sunucu `followState` gönderdi mi (arama satırında düğme yalnız o zaman çizilir).
  final bool hasFollowState;

  /// Gizli hesap.
  final bool isPrivate;

  /// Gizli ve görüntüleyen takipçi/kendisi değil: gönderiler ve listeler boş gelir.
  final bool locked;

  /// İzlenme / takip zamanı (varsa).
  final String? at;
}

/// Takip et/bırak yanıtı: `{following, followerCount, followState}`. Gizli hesapta `followState` REQUESTED döner.
class FollowResult {
  const FollowResult({this.following, this.followerCount, this.followState});

  factory FollowResult.fromJson(Object? j) {
    if (j is! Map) return const FollowResult();
    final c = j['followerCount'];
    final fs = j['followState'];
    return FollowResult(
      following: j['following'] is bool ? j['following'] as bool : null,
      followerCount: c is num ? c.toInt() : null,
      followState: fs is String ? followStateOf(fs) : null,
    );
  }

  final bool? following;
  final int? followerCount;

  /// Sunucunun kesin ilişki durumu (yoksa null: istemci kendi tahminini korur).
  final FollowState? followState;
}

/// Bir kullanıcının takip özeti.
class FollowStats {
  const FollowStats({
    this.followers = 0,
    this.following = 0,
    this.followState = FollowState.none,
    this.followsMe = false,
    this.isPrivate = false,
    this.locked = false,
  });

  factory FollowStats.fromJson(Map<String, dynamic>? j) => FollowStats(
        followers: _int(j?['followerCount'] ?? j?['followers']),
        following: _int(j?['followingCount'] ?? _intOrNull(j?['following'])),
        followState: followStateOf(j?['followState'], fallbackFollowing: j?['followedByMe'] == true),
        followsMe: j?['followsMe'] == true,
        isPrivate: j?['isPrivate'] == true,
        locked: j?['locked'] == true,
      );

  final int followers;
  final int following;

  /// Tek kaynak: ilişki durumu.
  final FollowState followState;
  final bool followsMe;
  final bool isPrivate;
  final bool locked;

  bool get followedByMe => followState == FollowState.following;

  FollowStats copyWith({int? followers, FollowState? followState, bool? locked}) => FollowStats(
        followers: followers ?? this.followers,
        following: following,
        followState: followState ?? this.followState,
        followsMe: followsMe,
        isPrivate: isPrivate,
        locked: locked ?? this.locked,
      );
}
