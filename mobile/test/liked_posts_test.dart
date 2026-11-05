import 'package:bu_kampus/features/posts/liked_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

bool _isLikedTile(Widget w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('liked-') &&
    !(w.key as ValueKey<String>).value.contains('reel');

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Beğendiklerim: yalnız beğendiğim gönderiler ızgarada; segment Reels süzgeciyle istek gider', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final f = fakePosts(b, count: 6);
    f.likedIds.addAll(f.posts.take(3).map((p) => p['id'] as int));
    await tester.pumpWidget(buildApp(LikedPostsPage(session: makeSession(b))));
    await settle(tester, const Duration(milliseconds: 800));
    expect(b.requests.any((r) => r.contains('/posts/liked') && r.contains('kind=ALL')), isTrue);
    expect(find.byWidgetPredicate(_isLikedTile), findsNWidgets(3));
    expect(find.byKey(const ValueKey('likedSegments')), findsOneWidget);

    await tester.tap(find.text('Reels'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(b.requests.any((r) => r.contains('/posts/liked') && r.contains('kind=VIDEO')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beğendiklerim: hiç beğeni yoksa boş durum cümlesi', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    fakePosts(b, count: 4);
    await tester.pumpWidget(buildApp(LikedPostsPage(session: makeSession(b))));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('likedPostsEmpty')), findsOneWidget);
    expect(find.text('Henüz beğendiğin bir gönderi yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
