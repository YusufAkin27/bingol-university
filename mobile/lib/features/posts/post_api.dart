import '../../core/session.dart';
import 'post_models.dart';

/// Gönderi uçları (tek fotoğraf + kısa metin + beğeni). Tek HTTP katmanı `session.api`; GET'ler her istekte
/// sunucuya doğrulatılır (ETag/If-None-Match). Hatalar `ApiError` olarak fırlar.
/// Fotoğraf yükleme (`POST /posts/media`) `post_media_uploader.dart` içindedir.
/// Kaldırılan uçlar (yorum, kaydetme, etiket, hikâye) sunucuda 410 `FEATURE_REMOVED` döner; çağrılmaz.
Map<String, dynamic>? _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

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

  /// Video-only eski gönderiler akıştan ayıklanır (`nextCursor` sunucudan olduğu gibi kalır).
  Future<PostPage<Post>> _posts(String path, Map<String, Object?> q) async {
    final r = await session.api.get('$path${_q(q)}');
    final page = PostPage.parse(r, Post.fromJson);
    return PostPage<Post>(
      items: [for (final p in page.items) if (!p.hiddenInFeed) p],
      nextCursor: page.nextCursor,
      total: page.total,
    );
  }

  /// `scope`: `latest` | `popular`.
  Future<PostPage<Post>> feed({String scope = 'latest', String? cursor, int size = 10}) =>
      _posts('/feed', {'scope': scope, 'cursor': cursor, 'size': size});

  Future<Post> get(int id) async => Post.fromJson(_m(await session.api.get('/posts/$id')));

  /// Tek fotoğraf ([mediaId], önce `POST /posts/media` ile yüklenir) + isteğe bağlı kısa metin.
  Future<Post> create({String? text, required int mediaId}) async {
    final r = await session.api.post('/posts', {
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'mediaIds': [mediaId],
    });
    return Post.fromJson(_m(r));
  }

  Future<Post> update(int id, String text) async =>
      Post.fromJson(_m(await session.api.patch('/posts/$id', {'text': text})));

  Future<void> delete(int id) => session.api.delete('/posts/$id');

  Future<LikeResult> like(int id) async =>
      LikeResult.fromJson(_m(await session.api.put('/posts/$id/like')));

  Future<LikeResult> unlike(int id) async =>
      LikeResult.fromJson(_m(await session.api.delete('/posts/$id/like')));

  Future<PostPage<Post>> userPosts(int userId, {String? cursor, int size = 10}) =>
      _posts('/users/$userId/posts', {'cursor': cursor, 'size': size});

  Future<PostPage<Post>> minePosts({String? cursor, int size = 10}) =>
      _posts('/posts/mine', {'cursor': cursor, 'size': size});

  /// `targetType`: `FEED_POST`; `reason`: SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION, OTHER.
  Future<void> report(String targetType, int targetId, String reason, {String? note}) =>
      session.api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
}
