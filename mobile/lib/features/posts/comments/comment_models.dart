/// Gönderi / Reels yorumları: veri modeli (2026-11-07 kullanıcı kararıyla yorum geri geldi).
/// Sunucu sözleşmesi (CommentView) yalnız burada okunur; alanlar eksik/bozuksa güvenli varsayılanlara düşer,
/// sözleşme değişirse tek yerde düzeltilir.
library;

/// Yorum metni üst sınırı (sunucu: 500; aşımda 422 `COMMENT_TOO_LONG`).
const int kCommentMaxLength = 500;

/// Kalan karakter sayacı yalnız son [kCommentCounterAt] karakterde görünür.
const int kCommentCounterAt = 50;

/// Yerel gönderim durumu (sunucudan gelen yorumlar her zaman [none]).
enum CommentSendState { none, sending, failed }

int _int(Object? v) => v is num ? v.toInt() : 0;

class CommentAuthor {
  const CommentAuthor({required this.userId, required this.displayName, this.avatarUrl, this.username});

  factory CommentAuthor.fromJson(Map<String, dynamic> j) => CommentAuthor(
        userId: _int(j['userId'] ?? j['id']),
        displayName: j['displayName'] is String ? j['displayName'] as String : '',
        avatarUrl: j['avatarUrl'] is String && (j['avatarUrl'] as String).isNotEmpty ? j['avatarUrl'] as String : null,
        username: j['username'] is String && (j['username'] as String).isNotEmpty ? j['username'] as String : null,
      );

  final int userId;
  final String displayName;
  final String? avatarUrl;
  final String? username;

  /// Listede görünen ad: kullanıcı adı varsa o, yoksa görünen ad.
  String get handle => username ?? displayName;
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    this.author,
    this.body,
    this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.replyCount = 0,
    this.mine = false,
    this.canDelete = false,
    this.deleted = false,
    this.sendState = CommentSendState.none,
    this.pendingKey,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) {
    final a = j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : null;
    final deleted = j['deleted'] == true;
    return PostComment(
      id: _int(j['id']),
      postId: _int(j['postId']),
      parentId: j['parentId'] is num ? (j['parentId'] as num).toInt() : null,
      author: deleted || a == null ? null : CommentAuthor.fromJson(a),
      body: deleted ? null : (j['body'] is String ? j['body'] as String : null),
      createdAt: j['createdAt'] is String ? j['createdAt'] as String : null,
      likeCount: _int(j['likeCount']),
      likedByMe: j['likedByMe'] == true,
      replyCount: _int(j['replyCount']),
      mine: j['mine'] == true,
      canDelete: j['canDelete'] == true || j['mine'] == true,
      deleted: deleted,
    );
  }

  final int id;
  final int postId;
  final int? parentId;

  /// Silinmiş yorumda null ("Bu yorum silindi" yer tutucusu çizilir).
  final CommentAuthor? author;
  final String? body;
  final String? createdAt;
  final int likeCount;
  final bool likedByMe;
  final int replyCount;
  final bool mine;
  final bool canDelete;
  final bool deleted;

  /// Yalnız yerel: iyimser eklenen yorumun durumu; [pendingKey] aynı gönderi niyetinin Idempotency-Key değeri.
  final CommentSendState sendState;
  final String? pendingKey;

  bool get isReply => parentId != null;

  /// Henüz sunucuya yazılmamış (iyimser) yorum.
  bool get isLocal => id < 0;

  PostComment copyWith({
    int? likeCount,
    bool? likedByMe,
    int? replyCount,
    bool? deleted,
    bool clearContent = false,
    CommentSendState? sendState,
  }) =>
      PostComment(
        id: id,
        postId: postId,
        parentId: parentId,
        author: clearContent ? null : author,
        body: clearContent ? null : body,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        replyCount: replyCount ?? this.replyCount,
        mine: mine,
        canDelete: canDelete,
        deleted: deleted ?? this.deleted,
        sendState: sendState ?? this.sendState,
        pendingKey: pendingKey,
      );
}

class CommentPageData {
  const CommentPageData(this.items, this.nextCursor);

  factory CommentPageData.fromJson(Object? body) {
    final m = body is Map ? body : const {};
    final raw = m['items'] is List ? m['items'] as List : const [];
    return CommentPageData([
      for (final e in raw)
        if (e is Map) PostComment.fromJson(Map<String, dynamic>.from(e)),
    ], m['nextCursor']?.toString());
  }

  final List<PostComment> items;
  final String? nextCursor;
}
