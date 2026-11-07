import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_comments.dart';

/// Yorumların gönderi detayına (önizleme + alt sayfa), bildirim derin bağlantısına ve push eşlemesine bağlanışı.
void main() {
  setUpAll(loadTestFonts);

  Map<String, dynamic> post({int count = 3}) =>
      samplePost(id: 91, text: 'Kisa bir not', media: [samplePostMedia(id: 910)], likeCount: 4, commentCount: count);

  testWidgets('detay: onizleme en iyi 2 yorum + "tumunu gor"; dokununca alt sayfa; sayac guncellenir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final f = CommentsFake(b);
    f.roots.addAll([
      commentView(1, postId: 91, body: 'Birinci yorum'),
      commentView(2, postId: 91, body: 'Ikinci yorum'),
      commentView(3, postId: 91, body: 'Ucuncu yorum'),
    ]);
    final p = post();
    b.on('/posts/91', p);
    await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 91, initial: Post.fromJson(p))));
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.requests.any((r) => r.startsWith('GET /posts/91/comments') && r.contains('size=2')), isTrue);
    expect(find.text('Birinci yorum'), findsOneWidget);
    expect(find.text('Ucuncu yorum'), findsNothing);
    expect(find.text('3 yorumun tümünü gör'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('commentsViewAll')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Ucuncu yorum'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('commentInput')), 'Yeni');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('commentSend')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(f.bodies.single['body'], 'Yeni');
    // Alt sayfa kapanir; karttaki sayac 4 olur.
    await tester.tapAt(const Offset(195, 20));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('4 yorumun tümünü gör'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detay: yorum dugmesi alt sayfayi acar; yorum yoksa "Yorum ekle" satiri', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    CommentsFake(b);
    final p = post(count: 0);
    b.on('/posts/91', p);
    await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 91, initial: Post.fromJson(p))));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('commentsViewAll')), findsNothing);
    expect(find.text('Yorum ekle…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post-comments-91')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('commentsEmpty')), findsOneWidget);
    expect(find.text('İlk yorumu sen yaz'), findsOneWidget);
  });

  testWidgets('bildirim derin baglantisi: openCommentId ile alt sayfa acilir ve yorum vurgulanir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final f = CommentsFake(b);
    f.roots.addAll([commentView(1, postId: 91, body: 'Eski yorum'), commentView(5, postId: 91, body: 'Hedef yorum')]);
    final p = post(count: 2);
    b.on('/posts/91', p);
    await tester.pumpWidget(
        buildApp(PostDetailPage(session: makeSession(b), postId: 91, initial: Post.fromJson(p), openCommentId: 5)));
    await settle(tester, const Duration(milliseconds: 1000));
    expect(find.byKey(const ValueKey('commentsScroll')), findsOneWidget);
    expect(b.requests.any((r) => r.contains('sort=new')), isTrue);
    expect(find.text('Hedef yorum'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  group('push eslemesi', () {
    test('postId + commentId gonderiyi ilgili yorumda acar', () {
      final t = resolvePushTarget({'type': 'COMMENT_LIKE', 'targetType': 'COMMENT', 'targetId': '77', 'postId': '91', 'commentId': '77'});
      expect(t, const PushTarget(PushDest.post, id: 91, commentId: 77));
      final r = resolvePushTarget({'type': 'COMMENT_REPLY', 'postId': '91', 'commentId': '12'});
      expect(r.dest, PushDest.post);
      expect(r.commentId, 12);
      expect(resolvePushTarget({'type': 'POST_COMMENT', 'targetType': 'FEED_POST', 'targetId': '91', 'commentId': '3'}),
          const PushTarget(PushDest.post, id: 91, commentId: 3));
    });

    test('gonderi kimligi olmayan COMMENT hedefi yorum kimligini gonderi sanmaz', () {
      expect(resolvePushTarget({'type': 'COMMENT_LIKE', 'targetType': 'COMMENT', 'targetId': '77'}).dest, PushDest.notifications);
    });
  });
}
