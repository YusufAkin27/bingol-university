import '../../posts/post_models.dart' show postMediaUrl, postMediaUrlOrNull;

/// Kampüs Forum modelleri: docs sözleşmesi `FORUM_API.md` (§2). Tüm `fromJson`lar null-güvenlidir; bilinmeyen
/// alanlar yok sayılır. Medya adresleri göreli gelirse mutlak adrese çevrilir (yetkili uç: Bearer gerekir).

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
double? _doubleOrNull(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
bool _bool(Object? v) => v == true;
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// Forum konu/yorum bağlantısı: paylaşım (`/s/f/{id}`, `/s/fc/{id}`).
String forumTopicLink(int topicId) => 'https://bukampus.com.tr/s/f/$topicId';
String forumCommentLink(int commentId) => 'https://bukampus.com.tr/s/fc/$commentId';

class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.sortOrder = 0,
    this.topicCount = 0,
    this.groupKey,
    this.groupName,
    this.groupOrder = 0,
  });

  factory ForumCategory.fromJson(Map<String, dynamic>? j) => ForumCategory(
        id: _int(j?['id']),
        slug: _str(j?['slug']) ?? '',
        name: _str(j?['name']) ?? '',
        sortOrder: _int(j?['sortOrder']),
        topicCount: _int(j?['topicCount']),
        groupKey: _str(j?['groupKey']),
        groupName: _str(j?['groupName']),
        groupOrder: _int(j?['groupOrder']),
      );

  final int id;
  final String slug;
  final String name;
  final int sortOrder;
  final int topicCount;

  /// Mantıksal grup (V1480; eski sunucu/grupsuz kategori: null). Kategori seçicide bölüm başlığıdır.
  final String? groupKey;
  final String? groupName;
  final int groupOrder;
}

/// Konu özetindeki kısa kategori bilgisi (`category:{id,name,slug}`).
class ForumCategoryRef {
  const ForumCategoryRef({required this.id, required this.name, this.slug = ''});

  factory ForumCategoryRef.fromJson(Map<String, dynamic>? j) =>
      ForumCategoryRef(id: _int(j?['id']), name: _str(j?['name']) ?? '', slug: _str(j?['slug']) ?? '');

  final int id;
  final String name;
  final String slug;
}

/// Yazar. Anonimde `userId/avatarUrl/department` null, `displayName` "Anonim #N", `anonymous: true`.
class ForumAuthor {
  const ForumAuthor({
    this.userId,
    this.displayName = '',
    this.avatarUrl,
    this.department,
    this.anonymous = false,
  });

  factory ForumAuthor.fromJson(Map<String, dynamic>? j) => ForumAuthor(
        userId: _intOrNull(j?['userId']),
        displayName: _str(j?['displayName']) ?? '',
        avatarUrl: _str(j?['avatarUrl']),
        department: _str(j?['department']),
        anonymous: _bool(j?['anonymous']),
      );

  final int? userId;
  final String displayName;
  final String? avatarUrl;
  final String? department;
  final bool anonymous;
}

/// Konu görseli / yükleme sonucu: `{id,url,thumbUrl,width,height}`.
class ForumImage {
  const ForumImage({required this.id, required this.url, this.thumbUrl, this.width, this.height});

  factory ForumImage.fromJson(Map<String, dynamic>? j) {
    final id = _int(j?['id']);
    return ForumImage(
      id: id,
      url: postMediaUrl(_str(j?['url']) ?? '/api/forum/media/$id'),
      thumbUrl: postMediaUrlOrNull(_str(j?['thumbUrl'])),
      width: _intOrNull(j?['width']),
      height: _intOrNull(j?['height']),
    );
  }

  final int id;
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;

  /// Genişlik/yükseklik; bilinmiyorsa 1.0; aşırı uç oranlar 0.5-1.91 arasına sıkıştırılır.
  double get aspect {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 1.0;
    return (w / h).clamp(0.5, 1.91);
  }
}

class ForumPollOption {
  const ForumPollOption({required this.id, required this.text, this.voteCount = 0, this.percent = 0});

  factory ForumPollOption.fromJson(Map<String, dynamic>? j) => ForumPollOption(
        id: _int(j?['id']),
        text: _str(j?['text']) ?? '',
        voteCount: _int(j?['voteCount']),
        percent: _doubleOrNull(j?['percent']) ?? 0,
      );

  final int id;
  final String text;
  final int voteCount;

  /// 0-100, 1 ondalık.
  final double percent;
}

class ForumPoll {
  const ForumPoll({
    required this.id,
    this.question,
    this.options = const [],
    this.totalVotes = 0,
    this.myOptionId,
    this.endsAt,
    this.closed = false,
    this.allowChangeVote = false,
    this.canVote = false,
  });

  factory ForumPoll.fromJson(Map<String, dynamic>? j) => ForumPoll(
        id: _int(j?['id']),
        question: _str(j?['question']),
        options: [for (final o in _maps(j?['options'])) ForumPollOption.fromJson(o)],
        totalVotes: _int(j?['totalVotes']),
        myOptionId: _intOrNull(j?['myOptionId']),
        endsAt: _str(j?['endsAt']),
        closed: _bool(j?['closed']),
        allowChangeVote: _bool(j?['allowChangeVote']),
        canVote: _bool(j?['canVote']),
      );

  final int id;
  final String? question;
  final List<ForumPollOption> options;
  final int totalVotes;
  final int? myOptionId;
  final String? endsAt;
  final bool closed;
  final bool allowChangeVote;
  final bool canVote;

  bool get voted => myOptionId != null;
}

/// Konu durumu (`status`): ACTIVE | REMOVED (diğer değerler ACTIVE sayılmaz, metin olarak korunur).
class TopicSummary {
  const TopicSummary({
    required this.id,
    this.title = '',
    this.bodyPreview = '',
    this.category,
    this.author = const ForumAuthor(),
    this.createdAt,
    this.editedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.followedByMe = false,
    this.thumbnail,
    this.imageCount = 0,
    this.hasPoll = false,
    this.pinned = false,
    this.locked = false,
    this.mine = false,
    this.canModerate = false,
    this.status = 'ACTIVE',
  });

  factory TopicSummary.fromJson(Map<String, dynamic>? j) => TopicSummary(
        id: _int(j?['id']),
        title: _str(j?['title']) ?? '',
        bodyPreview: _str(j?['bodyPreview']) ?? '',
        category: _map(j?['category']) == null ? null : ForumCategoryRef.fromJson(_map(j?['category'])),
        author: ForumAuthor.fromJson(_map(j?['author'])),
        createdAt: _str(j?['createdAt']),
        editedAt: _str(j?['editedAt']),
        likeCount: _int(j?['likeCount']),
        commentCount: _int(j?['commentCount']),
        likedByMe: _bool(j?['likedByMe']),
        savedByMe: _bool(j?['savedByMe']),
        followedByMe: _bool(j?['followedByMe']),
        thumbnail: _map(j?['thumbnail']) == null ? null : ForumImage.fromJson(_map(j?['thumbnail'])),
        imageCount: _int(j?['imageCount']),
        hasPoll: _bool(j?['hasPoll']),
        pinned: _bool(j?['pinned']),
        locked: _bool(j?['locked']),
        mine: _bool(j?['mine']),
        canModerate: _bool(j?['canModerate']),
        status: _str(j?['status']) ?? 'ACTIVE',
      );

  final int id;
  final String title;
  final String bodyPreview;
  final ForumCategoryRef? category;
  final ForumAuthor author;
  final String? createdAt;
  final String? editedAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;
  final bool followedByMe;
  final ForumImage? thumbnail;
  final int imageCount;
  final bool hasPoll;
  final bool pinned;
  final bool locked;
  final bool mine;
  final bool canModerate;
  final String status;

  bool get removed => status == 'REMOVED';
  bool get edited => (editedAt ?? '').isNotEmpty;

  TopicSummary copyWith({
    bool? likedByMe,
    int? likeCount,
    bool? savedByMe,
    bool? followedByMe,
    int? commentCount,
  }) =>
      TopicSummary(
        id: id,
        title: title,
        bodyPreview: bodyPreview,
        category: category,
        author: author,
        createdAt: createdAt,
        editedAt: editedAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        followedByMe: followedByMe ?? this.followedByMe,
        thumbnail: thumbnail,
        imageCount: imageCount,
        hasPoll: hasPoll,
        pinned: pinned,
        locked: locked,
        mine: mine,
        canModerate: canModerate,
        status: status,
      );
}

/// Konu detayı = özet + tam gövde, görseller, anket ve sahip yetkileri.
class TopicView extends TopicSummary {
  const TopicView({
    required super.id,
    super.title,
    super.bodyPreview,
    super.category,
    super.author,
    super.createdAt,
    super.editedAt,
    super.likeCount,
    super.commentCount,
    super.likedByMe,
    super.savedByMe,
    super.followedByMe,
    super.thumbnail,
    super.imageCount,
    super.hasPoll,
    super.pinned,
    super.locked,
    super.mine,
    super.canModerate,
    super.status,
    this.body = '',
    this.images = const [],
    this.poll,
    this.canEdit = false,
    this.canDelete = false,
    this.notificationsEnabled = true,
  });

  factory TopicView.fromJson(Map<String, dynamic>? j) {
    final s = TopicSummary.fromJson(j);
    final images = [for (final m in _maps(j?['images'])) ForumImage.fromJson(m)];
    return TopicView(
      id: s.id,
      title: s.title,
      bodyPreview: s.bodyPreview,
      category: s.category,
      author: s.author,
      createdAt: s.createdAt,
      editedAt: s.editedAt,
      likeCount: s.likeCount,
      commentCount: s.commentCount,
      likedByMe: s.likedByMe,
      savedByMe: s.savedByMe,
      followedByMe: s.followedByMe,
      thumbnail: s.thumbnail,
      imageCount: s.imageCount > 0 ? s.imageCount : images.length,
      hasPoll: s.hasPoll || _map(j?['poll']) != null,
      pinned: s.pinned,
      locked: s.locked,
      mine: s.mine,
      canModerate: s.canModerate,
      status: s.status,
      body: _str(j?['body']) ?? '',
      images: images,
      poll: _map(j?['poll']) == null ? null : ForumPoll.fromJson(_map(j?['poll'])),
      canEdit: _bool(j?['canEdit']),
      canDelete: _bool(j?['canDelete']),
      notificationsEnabled: j?['notificationsEnabled'] is bool ? j!['notificationsEnabled'] as bool : true,
    );
  }

  final String body;
  final List<ForumImage> images;
  final ForumPoll? poll;
  final bool canEdit;
  final bool canDelete;
  final bool notificationsEnabled;

  /// Listede göstermek için özet (liste ile detay aynı kart bileşenini kullanır).
  TopicSummary get summary => this;

  @override
  TopicView copyWith({
    bool? likedByMe,
    int? likeCount,
    bool? savedByMe,
    bool? followedByMe,
    int? commentCount,
    ForumPoll? poll,
    bool? notificationsEnabled,
  }) =>
      TopicView(
        id: id,
        title: title,
        bodyPreview: bodyPreview,
        category: category,
        author: author,
        createdAt: createdAt,
        editedAt: editedAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        followedByMe: followedByMe ?? this.followedByMe,
        thumbnail: thumbnail,
        imageCount: imageCount,
        hasPoll: hasPoll,
        pinned: pinned,
        locked: locked,
        mine: mine,
        canModerate: canModerate,
        status: status,
        body: body,
        images: images,
        poll: poll ?? this.poll,
        canEdit: canEdit,
        canDelete: canDelete,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}

/// Yorum (`CommentView`). Silinmiş ama yanıtı olan yorum: `deleted: true`, `author/body` null.
class ForumComment {
  const ForumComment({
    required this.id,
    required this.topicId,
    this.parentCommentId,
    this.depth = 0,
    this.author,
    this.body,
    this.anonymous = false,
    this.createdAt,
    this.editedAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.replyCount = 0,
    this.replyPreview = const [],
    this.mine = false,
    this.deleted = false,
    this.canModerate = false,
    this.topicAuthor = false,
    this.path = const [],
  });

  factory ForumComment.fromJson(Map<String, dynamic>? j) => ForumComment(
        id: _int(j?['id']),
        topicId: _int(j?['topicId']),
        parentCommentId: _intOrNull(j?['parentCommentId']),
        depth: _int(j?['depth']),
        author: _map(j?['author']) == null ? null : ForumAuthor.fromJson(_map(j?['author'])),
        body: _str(j?['body']),
        anonymous: _bool(j?['anonymous']),
        createdAt: _str(j?['createdAt']),
        editedAt: _str(j?['editedAt']),
        likeCount: _int(j?['likeCount']),
        likedByMe: _bool(j?['likedByMe']),
        savedByMe: _bool(j?['savedByMe']),
        replyCount: _int(j?['replyCount']),
        replyPreview: [for (final m in _maps(j?['replyPreview'])) ForumComment.fromJson(m)],
        mine: _bool(j?['mine']),
        deleted: _bool(j?['deleted']),
        canModerate: _bool(j?['canModerate']),
        topicAuthor: _bool(j?['topicAuthor']),
        path: j?['path'] is List ? [for (final e in j!['path'] as List) _int(e)] : const [],
      );

  final int id;
  final int topicId;
  final int? parentCommentId;
  final int depth;
  final ForumAuthor? author;
  final String? body;
  final bool anonymous;
  final String? createdAt;
  final String? editedAt;
  final int likeCount;
  final bool likedByMe;
  final bool savedByMe;
  final int replyCount;
  final List<ForumComment> replyPreview;
  final bool mine;
  final bool deleted;
  final bool canModerate;

  /// Konu sahibinin yorumu ("Yazar" etiketi; anonimlik sızdırmaz).
  final bool topicAuthor;

  /// Üst yorum kimlikleri (yalnız tek yorum ucunda; bağlantı/bildirimden açma).
  final List<int> path;

  bool get edited => (editedAt ?? '').isNotEmpty;

  ForumComment copyWith({
    bool? likedByMe,
    int? likeCount,
    bool? savedByMe,
    String? body,
    String? editedAt,
    int? replyCount,
    bool? deleted,
    List<ForumComment>? replyPreview,
  }) =>
      ForumComment(
        id: id,
        topicId: topicId,
        parentCommentId: parentCommentId,
        depth: depth,
        author: deleted == true ? null : author,
        body: deleted == true ? null : (body ?? this.body),
        anonymous: anonymous,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        replyCount: replyCount ?? this.replyCount,
        replyPreview: replyPreview ?? this.replyPreview,
        mine: mine,
        deleted: deleted ?? this.deleted,
        canModerate: canModerate,
        topicAuthor: topicAuthor,
        path: path,
      );
}

/// İmleçli sayfa: `{items, nextCursor}`.
class ForumPage<T> {
  const ForumPage({this.items = const [], this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  static ForumPage<T> parse<T>(Object? body, T Function(Map<String, dynamic>) map) {
    final m = body is Map ? body : const {};
    final c = m['nextCursor'];
    return ForumPage<T>(
      items: [for (final e in _maps(m['items'])) map(e)],
      nextCursor: c?.toString(),
    );
  }
}

/// Beğeni sonucu (`{liked, likeCount}`).
class ForumLikeResult {
  const ForumLikeResult({required this.liked, required this.likeCount});

  factory ForumLikeResult.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return ForumLikeResult(liked: _bool(m['liked']), likeCount: _int(m['likeCount']));
  }

  final bool liked;
  final int likeCount;
}

/// Forum bildirim tercihleri (`GET|PUT /forum/notification-prefs`). Moderasyon bildirimi kapatılamaz.
class ForumNotificationPrefs {
  const ForumNotificationPrefs({
    this.all = true,
    this.topicComments = true,
    this.commentReplies = true,
    this.likes = true,
    this.followedTopics = true,
  });

  factory ForumNotificationPrefs.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    bool b(String k) => m[k] is bool ? m[k] as bool : true;
    return ForumNotificationPrefs(
      all: b('all'),
      topicComments: b('topicComments'),
      commentReplies: b('commentReplies'),
      likes: b('likes'),
      followedTopics: b('followedTopics'),
    );
  }

  final bool all;
  final bool topicComments;
  final bool commentReplies;
  final bool likes;
  final bool followedTopics;

  Map<String, dynamic> toJson() => {
        'all': all,
        'topicComments': topicComments,
        'commentReplies': commentReplies,
        'likes': likes,
        'followedTopics': followedTopics,
      };

  ForumNotificationPrefs copyWith({bool? all, bool? topicComments, bool? commentReplies, bool? likes, bool? followedTopics}) =>
      ForumNotificationPrefs(
        all: all ?? this.all,
        topicComments: topicComments ?? this.topicComments,
        commentReplies: commentReplies ?? this.commentReplies,
        likes: likes ?? this.likes,
        followedTopics: followedTopics ?? this.followedTopics,
      );
}

/// Arama sonucu: konu özeti + eşleşme yeri (`matchedIn`: TITLE | BODY | COMMENT | CATEGORY) ve kesit.
class ForumSearchHit {
  const ForumSearchHit({required this.topic, this.matchedIn, this.snippet});

  factory ForumSearchHit.fromJson(Map<String, dynamic> j) =>
      ForumSearchHit(topic: TopicSummary.fromJson(j), matchedIn: _str(j['matchedIn']), snippet: _str(j['snippet']));

  final TopicSummary topic;
  final String? matchedIn;
  final String? snippet;
}

/// Kaydedilenler: konu ve yorum karışık (`GET /forum/me/saved`); `type` TOPIC | COMMENT.
class ForumSavedItem {
  const ForumSavedItem({required this.type, this.topic, this.comment});

  factory ForumSavedItem.fromJson(Map<String, dynamic> j) {
    final type = (_str(j['type']) ?? _str(j['targetType']) ?? 'TOPIC').toUpperCase();
    final c = _map(j['comment']);
    final t = _map(j['topic']);
    if (type == 'COMMENT') {
      return ForumSavedItem(
          type: 'COMMENT', comment: ForumComment.fromJson(c ?? j), topic: t == null ? null : TopicSummary.fromJson(t));
    }
    return ForumSavedItem(type: 'TOPIC', topic: TopicSummary.fromJson(t ?? j));
  }

  final String type;
  final TopicSummary? topic;
  final ForumComment? comment;
}

/// Kullanıcı özeti (`/forum/users/{id}/summary`).
class ForumUserSummary {
  const ForumUserSummary({this.topicCount = 0, this.commentCount = 0});

  factory ForumUserSummary.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return ForumUserSummary(topicCount: _int(m['topicCount']), commentCount: _int(m['commentCount']));
  }

  final int topicCount;
  final int commentCount;
}

/// Sıralama kipi; [wire] sunucuya giden değer.
enum ForumSort {
  forYou('FOR_YOU'),
  newest('NEWEST'),
  popular('POPULAR'),
  mostCommented('MOST_COMMENTED'),
  following('FOLLOWING');

  const ForumSort(this.wire);
  final String wire;
}

enum ForumCommentSort {
  best('BEST'),
  newest('NEWEST'),
  oldest('OLDEST');

  const ForumCommentSort(this.wire);
  final String wire;
}

/// Şikâyet hedef türleri (`POST /reports`).
const kForumReportTopic = 'FORUM_TOPIC';
const kForumReportComment = 'FORUM_COMMENT';
