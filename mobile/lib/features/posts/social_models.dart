import 'post_models.dart';

/// Gönderi sosyal özellikleri modelleri (kaydetme, etiket, takip, hikâye). Tüm `fromJson`lar null-güvenlidir.

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
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

class TrendingTag {
  const TrendingTag({required this.tag, this.postCount = 0});

  factory TrendingTag.fromJson(Map<String, dynamic>? j) =>
      TrendingTag(tag: (_str(j?['tag']) ?? _str(j?['name']) ?? '').replaceFirst('#', ''), postCount: _int(j?['postCount'] ?? j?['count']));

  final String tag;
  final int postCount;
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

enum StoryKind { image, video, text }

class Story {
  const Story({
    required this.id,
    required this.kind,
    this.media,
    this.caption,
    this.bodyText,
    this.background,
    this.viewCount = 0,
    this.seen = false,
    this.createdAt,
    this.expiresAt,
  });

  factory Story.fromJson(Map<String, dynamic>? j) {
    final k = _str(j?['kind']);
    final m = _map(j?['media']);
    return Story(
      id: _int(j?['id']),
      kind: k == 'VIDEO' ? StoryKind.video : (k == 'TEXT' ? StoryKind.text : StoryKind.image),
      media: m == null ? null : PostMedia.fromJson(m),
      caption: _str(j?['caption']),
      bodyText: _str(j?['bodyText']),
      background: _str(j?['background']),
      viewCount: _int(j?['viewCount']),
      seen: j?['seen'] == true || j?['viewedByMe'] == true,
      createdAt: _str(j?['createdAt']),
      expiresAt: _str(j?['expiresAt']),
    );
  }

  final int id;
  final StoryKind kind;
  final PostMedia? media;
  final String? caption;
  final String? bodyText;

  /// `#RRGGBB` (metin hikâyesi arka planı).
  final String? background;
  final int viewCount;
  final bool seen;
  final String? createdAt;
  final String? expiresAt;

  Story copyWith({bool? seen, int? viewCount}) => Story(
        id: id,
        kind: kind,
        media: media,
        caption: caption,
        bodyText: bodyText,
        background: background,
        viewCount: viewCount ?? this.viewCount,
        seen: seen ?? this.seen,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
}

/// Hikâye şeridindeki bir kullanıcı halkası.
class StoryGroup {
  const StoryGroup({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.hasUnseen = false,
    this.mine = false,
    this.count = 0,
  });

  factory StoryGroup.fromJson(Map<String, dynamic>? j, {int? selfId}) {
    final u = _map(j?['author']) ?? _map(j?['user']) ?? j;
    final id = _int(u?['id'] ?? u?['userId']);
    return StoryGroup(
      userId: id,
      displayName: _str(u?['displayName']) ?? '',
      avatarUrl: _str(u?['avatarUrl']),
      hasUnseen: j?['hasUnseen'] == true || j?['unseen'] == true,
      mine: j?['mine'] == true || (selfId != null && id == selfId),
      count: _int(j?['count'] ?? j?['storyCount']),
    );
  }

  final int userId;
  final String displayName;
  final String? avatarUrl;
  final bool hasUnseen;
  final bool mine;
  final int count;

  StoryGroup copyWith({bool? hasUnseen}) => StoryGroup(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        hasUnseen: hasUnseen ?? this.hasUnseen,
        mine: mine,
        count: count,
      );

  /// Görülmemiş halkalar önce, kendi hikâyen en başta; sıra korunur (kararlı).
  static List<StoryGroup> ordered(List<StoryGroup> all) {
    final mine = all.where((g) => g.mine).toList();
    final rest = all.where((g) => !g.mine).toList();
    return [...mine, ...rest.where((g) => g.hasUnseen), ...rest.where((g) => !g.hasUnseen)];
  }
}
