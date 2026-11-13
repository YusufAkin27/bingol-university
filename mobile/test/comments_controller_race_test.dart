import 'dart:async';

import 'package:bu_kampus/features/posts/comments/comment_models.dart';
import 'package:bu_kampus/features/posts/comments/comments_api.dart';
import 'package:bu_kampus/features/posts/comments/comments_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sayfalama yarisi: sonraki sayfa yuklenirken siralama degisirse `loadingMore` takili kalmamali.
class _Api implements CommentsApi {
  final pageGate = Completer<void>();

  PostComment c(int id) => PostComment(id: id, postId: 1, body: 'y$id');

  @override
  Future<CommentPageData> list(int postId, {String sort = 'top', String? cursor, int size = 20}) async {
    if (cursor != null) {
      await pageGate.future;
      return CommentPageData([c(50)], null);
    }
    return CommentPageData([c(sort == 'top' ? 1 : 2)], 'next-$sort');
  }

  @override
  Future<CommentPageData> replies(int commentId, {String? cursor, int size = 20}) async => const CommentPageData([], null);
  @override
  Future<PostComment> add(int postId, String body, {int? parentId, required String idempotencyKey}) async => c(9);
  @override
  Future<void> delete(int commentId) async {}
  @override
  Future<void> setLiked(int commentId, bool liked) async {}
}

void main() {
  test('siralama degisince suren loadMore loadingMore bayragini takili birakmaz', () async {
    final api = _Api();
    final cc = CommentsController(api: api, postId: 1, initialCount: 2, me: const CommentAuthor(userId: 1, displayName: 'Ben'));
    await cc.load();
    expect(cc.hasMore, isTrue);
    final more = cc.loadMore(); // sayfa 2 kapida bekler
    expect(cc.loadingMore, isTrue);
    cc.setSort('new'); // yeni yukleme: eski loadMore gecersiz
    await Future<void>.delayed(Duration.zero);
    api.pageGate.complete();
    await more;
    await Future<void>.delayed(Duration.zero);
    expect(cc.loadingMore, isFalse);
    expect(cc.roots.map((e) => e.id), [2]);
    expect(cc.hasMore, isTrue);
    cc.dispose();
  });
}
