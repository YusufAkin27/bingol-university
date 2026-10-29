import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// UI-K4: gonderi karti (referans grup 17) davranis ve durum testleri.
void main() {
  setUpAll(loadTestFonts);

  Post post({bool liked = false, int likes = 127, bool mine = false, bool edited = false}) {
    final j = samplePost(
        id: 1000, media: [samplePostMedia(id: 7)], text: 'Bahar geldi kampüse', liked: liked, likeCount: likes, mine: mine);
    if (edited) j['editedAt'] = '2026-10-26T10:00:00Z';
    return Post.fromJson(j);
  }

  testWidgets('kart: 4:5 fotograf, kalp + sayac, yorum/kaydet/paylas yok, duzenlendi etiketi', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    fakePosts(b);
    final s = makeSession(b);
    await tester.pumpWidget(p00App(
      SingleChildScrollView(child: PostCard(session: s, post: post(mine: true, edited: true), onChanged: (_) {}, onDeleted: (_) {})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final photo = tester.getSize(find.byType(AspectRatio).first);
    expect((photo.width / photo.height - 0.8).abs(), lessThan(0.01));
    expect(find.byKey(const ValueKey('like-heart')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-edited')), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    for (final i in [Icons.bookmark_border, Icons.bookmark, Icons.mode_comment_outlined, Icons.send, Icons.share]) {
      expect(find.byIcon(i), findsNothing);
    }
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('begeni: kirmizi dolu kalp, sayac eskiden yeniye gecer, cift dokunus karartir ve beyaz kalp cikar',
      (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    fakePosts(b);
    final s = makeSession(b);
    await tester.pumpWidget(p00App(
      SingleChildScrollView(child: PostCard(session: s, post: post(), onChanged: (_) {}, onDeleted: (_) {})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('like-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('127'), findsOneWidget); // eski sayi solarken
    expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '128');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('127'), findsNothing);

    // Cift dokunus: beyaz buyuk kalp (zaten begenilmis olsa da gosterilir).
    final photo = find.byKey(const ValueKey('post-photo-1000'));
    await tester.tap(photo);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(photo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final heart = tester.widget<Icon>(find.byKey(const ValueKey('double-tap-heart')));
    expect(heart.size, 88);
    expect(heart.color, Colors.white);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('beğeni basarisiz: geri alinir ve "Begeni kaydedilemedi" uyarisi + Tekrar dene gorunur', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend()..network('/posts/1000/like');
    final s = makeSession(b);
    await tester.pumpWidget(p00App(
      SingleChildScrollView(child: PostCard(session: s, post: post(), onChanged: (_) {}, onDeleted: (_) {})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('like-heart')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Beğeni kaydedilemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '127');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('kart ve iskelet: tr/en/ar x acik/koyu x 1.0/1.3 x 320/390 tasma yok', (tester) async {
    final b = FakeBackend();
    fakePosts(b);
    final s = makeSession(b);
    await p00Matrix(
      tester,
      () => ListView(children: [
        PostCard(session: s, post: post(mine: true, edited: true), onChanged: (_) {}, onDeleted: (_) {}),
        const PostCardSkeleton(),
      ]),
      settleMs: 300,
    );
  });
}
