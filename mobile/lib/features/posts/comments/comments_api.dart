import 'dart:math' as math;

import '../../../core/session.dart';
import 'comment_models.dart';

/// Yorum uçları. Arayüz [CommentsController]'dan ayrıdır (testte sahte verilebilir).
/// Tek HTTP katmanı `session.api`. Hatalar `ApiError` olarak fırlar.
abstract class CommentsApi {
  /// Üst düzey yorumlar. [sort]: `top` | `new`.
  Future<CommentPageData> list(int postId, {String sort = 'top', String? cursor, int size = 20});

  /// Bir yorumun yanıtları (eskiden yeniye).
  Future<CommentPageData> replies(int commentId, {String? cursor, int size = 20});

  /// Yeni yorum / yanıt. [idempotencyKey] aynı gönderi niyetinde sabit kalır (yeniden denemede çift kayıt olmaz).
  Future<PostComment> add(int postId, String body, {int? parentId, required String idempotencyKey});

  Future<void> delete(int commentId);

  /// İdempotent: `PUT|DELETE /comments/{id}/like`.
  Future<void> setLiked(int commentId, bool liked);
}

String newCommentKey() {
  final r = math.Random.secure();
  return 'c${List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join()}';
}

class HttpCommentsApi implements CommentsApi {
  HttpCommentsApi(this.session);

  final Session session;

  String _q(Map<String, Object?> p) {
    final parts = [
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  @override
  Future<CommentPageData> list(int postId, {String sort = 'top', String? cursor, int size = 20}) async =>
      CommentPageData.fromJson(await session.api
          .get('/posts/$postId/comments${_q({'sort': sort, 'cursor': cursor, 'size': size})}', force: cursor == null));

  @override
  Future<CommentPageData> replies(int commentId, {String? cursor, int size = 20}) async =>
      CommentPageData.fromJson(await session.api
          .get('/comments/$commentId/replies${_q({'cursor': cursor, 'size': size})}', force: cursor == null));

  @override
  Future<PostComment> add(int postId, String body, {int? parentId, required String idempotencyKey}) async {
    final r = await session.api.post('/posts/$postId/comments', {'body': body, 'parentId': parentId}, true,
        {'Idempotency-Key': idempotencyKey});
    return PostComment.fromJson(r is Map ? Map<String, dynamic>.from(r) : const {});
  }

  @override
  Future<void> delete(int commentId) => session.api.delete('/comments/$commentId');

  @override
  Future<void> setLiked(int commentId, bool liked) async {
    liked ? await session.api.put('/comments/$commentId/like') : await session.api.delete('/comments/$commentId/like');
  }
}
