import '../../core/session.dart';
import 'post_models.dart';

/// Gönderi uçları (docs/POSTS_DESIGN.md). Tek HTTP katmanı `session.api`; GET'ler her istekte sunucuya
/// doğrulatılır (ETag/If-None-Match), yani bayat veri sunulmaz. Hatalar `ApiError` olarak fırlar.
/// Medya yükleme (`POST /posts/media`) `post_media_uploader.dart` içindedir.
class PostApi {
  PostApi(this.session);

  final Session session;

  String _q(Map<String, Object?> p) {
    final parts = <String>[
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  Future<PostPage<Post>> _posts(String path, Map<String, Object?> q) async {
    final r = await session.api.get('$path${_q(q)}');
    return PostPage.parse(r, Post.fromJson);
  }

  /// `scope`: `latest` | `popular`.
  Future<PostPage<Post>> feed({String scope = 'latest', String? cursor, int size = 10}) =>
      _posts('/feed', {'scope': scope, 'cursor': cursor, 'size': size});

  Future<Post> get(int id) async => Post.fromJson((await session.api.get('/posts/$id')) as Map<String, dynamic>?);

  Future<Post> create({String? text, List<int> mediaIds = const []}) async {
    final r = await session.api.post('/posts', {
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
    });
    return Post.fromJson(r as Map<String, dynamic>?);
  }

  Future<Post> update(int id, String text) async =>
      Post.fromJson((await session.api.patch('/posts/$id', {'text': text})) as Map<String, dynamic>?);

  Future<void> delete(int id) => session.api.delete('/posts/$id');

  Future<LikeResult> like(int id) async =>
      LikeResult.fromJson((await session.api.put('/posts/$id/like')) as Map<String, dynamic>?);

  Future<LikeResult> unlike(int id) async =>
      LikeResult.fromJson((await session.api.delete('/posts/$id/like')) as Map<String, dynamic>?);

  Future<PostPage<PostLiker>> likers(int id, {String? cursor, int size = 30}) async {
    final r = await session.api.get('/posts/$id/likes${_q({'cursor': cursor, 'size': size})}');
    return PostPage.parse(r, PostLiker.fromJson);
  }

  /// Yalnız kök yorumlar. `sort`: `new` | `top`.
  Future<PostPage<PostComment>> comments(int postId, {String sort = 'new', String? cursor, int size = 20}) async {
    final r = await session.api.get('/posts/$postId/comments${_q({'sort': sort, 'cursor': cursor, 'size': size})}');
    return PostPage.parse(r, PostComment.fromJson);
  }

  Future<PostPage<PostComment>> replies(int commentId, {String? cursor, int size = 20}) async {
    final r = await session.api.get('/comments/$commentId/replies${_q({'cursor': cursor, 'size': size})}');
    return PostPage.parse(r, PostComment.fromJson);
  }

  Future<PostComment> addComment(int postId, String text, {int? parentId}) async {
    final r = await session.api.post('/posts/$postId/comments', {
      'text': text,
      if (parentId != null) 'parentId': parentId,
    });
    return PostComment.fromJson(r as Map<String, dynamic>?);
  }

  Future<PostComment> editComment(int id, String text) async =>
      PostComment.fromJson((await session.api.patch('/comments/$id', {'text': text})) as Map<String, dynamic>?);

  Future<void> deleteComment(int id) => session.api.delete('/comments/$id');

  Future<PostPage<Post>> userPosts(int userId, {String? cursor, int size = 10}) =>
      _posts('/users/$userId/posts', {'cursor': cursor, 'size': size});

  Future<PostPage<Post>> minePosts({String? cursor, int size = 10}) =>
      _posts('/posts/mine', {'cursor': cursor, 'size': size});

  /// `targetType`: `FEED_POST` | `FEED_COMMENT`; `reason`: SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION, OTHER.
  Future<void> report(String targetType, int targetId, String reason, {String? note}) =>
      session.api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
}
