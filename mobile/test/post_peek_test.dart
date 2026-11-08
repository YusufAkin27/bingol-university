import 'package:bu_kampus/features/discover/discover_box.dart';
import 'package:bu_kampus/features/posts/comments/comment_button.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  mediaTapTest();
  outsideTapTest();
  testWidgets('kesfet kutusu: uzun basinca on izleme acilir, disina dokununca kapanir; Ac gonderiyi acar', (tester) async {
    useScreen(tester, const Size(390, 844));
    final s = makeSession(FakeBackend());
    final p = Post.fromJson(samplePost(id: 7, text: 'On izleme metni ❤'));
    Post? opened;
    await tester.pumpWidget(buildApp(Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: 220,
          child: DiscoverPostBox(session: s, post: p, onOpen: (x) => opened = x, onChanged: (_) {}, onMenu: (_) {}),
        ),
      ),
    )));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.byType(DiscoverPostBox));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('postPeek')), findsOneWidget);
    expect(find.byKey(const ValueKey('peekMenu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('peekOpen')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(opened?.id, 7);
    expect(find.byKey(const ValueKey('postPeek')), findsNothing);
  });
}

void outsideTapTest() {
  testWidgets('on izleme: kartin disina dokununca kapanir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final s = makeSession(FakeBackend());
    final p = Post.fromJson(samplePost(id: 8, text: 'x'));
    await tester.pumpWidget(buildApp(Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: 220,
          child: DiscoverPostBox(session: s, post: p, onOpen: (_) {}, onChanged: (_) {}),
        ),
      ),
    )));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.byType(DiscoverPostBox));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('postPeek')), findsOneWidget);
    await tester.tapAt(const Offset(195, 820));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('postPeek')), findsNothing);
  });
}

void mediaTapTest() {
  testWidgets('on izleme: medyaya dokununca gonderi acilir; begeni ve yorum dugmeleri var', (tester) async {
    useScreen(tester, const Size(390, 844));
    final s = makeSession(FakeBackend());
    final p = Post.fromJson(samplePost(id: 9, text: 'y'));
    Post? opened;
    await tester.pumpWidget(buildApp(Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: 220,
          child: DiscoverPostBox(session: s, post: p, onOpen: (x) => opened = x, onChanged: (_) {}),
        ),
      ),
    )));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.byType(DiscoverPostBox));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LikeButton), findsWidgets);
    expect(find.byType(CommentButton), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('peekMedia')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(opened?.id, 9);
    expect(find.byKey(const ValueKey('postPeek')), findsNothing);
  });
}
