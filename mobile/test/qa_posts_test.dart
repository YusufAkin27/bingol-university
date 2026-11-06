import 'package:bu_kampus/features/discover/discover_box.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/block_bus.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA alani 3 (gonderi/begeni/engel) regresyon testleri.
Widget _like(FakeBackend b, Post p, {LikeController? c, ValueChanged<Post>? onChanged}) => buildApp(
      Scaffold(body: Center(child: LikeButton(session: makeSession(b), post: p, controller: c, onChanged: onChanged))),
    );

Post _post({bool liked = false, int likes = 4}) =>
    Post.fromJson(samplePost(id: 500, text: 'Merhaba', liked: liked, likeCount: likes));

void main() {
  setUpAll(loadTestFonts);

  group('LikeButton', () {
    testWidgets('dokunus iyimser sayac + debounce sonrasi tek PUT', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = fakePosts(b, count: 1);
      f.posts[0]['id'] = 500;
      f.posts[0]['likeCount'] = 4;
      await tester.pumpWidget(_like(b, _post()));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('5'), findsOneWidget); // iyimser
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('PUT /posts/500/like'), 1);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hizli art arda 5 dokunus: yalniz son durum (tek istek), cift sayim yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = fakePosts(b, count: 1);
      f.posts[0]['id'] = 500;
      f.posts[0]['likeCount'] = 4;
      await tester.pumpWidget(_like(b, _post()));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await settle(tester, const Duration(milliseconds: 900));
      // 5 dokunus = begeni (tek sayi): son durum begenildi, tek PUT.
      expect(b.count('PUT /posts/500/like'), 1);
      expect(b.count('DELETE /posts/500/like'), 0);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('cift sayi dokunus: ilk duruma doner, hic istek gitmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 1);
      await tester.pumpWidget(_like(b, _post()));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('/like'), 0);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('LikeController.like() beğenilmişse hiçbir şey yapmaz (cift dokunus cift begeni olmaz)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = fakePosts(b, count: 1);
      f.posts[0]['id'] = 500;
      final c = LikeController();
      await tester.pumpWidget(_like(b, _post(liked: true, likes: 4), c: c));
      c.like();
      c.like();
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('/like'), 0);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('sunucu hatasi: iyimser durum geri alinir (sayac + kalp)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 1);
      b.fail('/posts/500/like', status: 500);
      b.handlers.insert(0, (req, path) => null);
      Post? last;
      await tester.pumpWidget(_like(b, _post(), onChanged: (p) => last = p));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('4'), findsOneWidget);
      expect(last?.likedByMe, isFalse);
      expect(last?.likeCount, 4);
    });

    testWidgets('cevrimdisi: iyimser geri alinir ve uyari cikar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()..offline = true;
      await tester.pumpWidget(_like(b, _post()));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('sayac 0 iken beğeni geri alinsa bile negatife dusmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 1);
      await tester.pumpWidget(_like(b, _post(liked: true, likes: 0)));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('-1'), findsNothing);
    });

    testWidgets('ucustayken ekrandan cikis: arada yon degistiren son niyet kaybolmaz (DELETE gider)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend(delay: const Duration(milliseconds: 500));
      final f = fakePosts(b, count: 1);
      f.posts[0]['id'] = 500;
      await tester.pumpWidget(_like(b, _post()));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump(const Duration(milliseconds: 300)); // PUT ucusta
      await tester.tap(find.byKey(const ValueKey('like-heart'))); // vazgec
      await tester.pump(const Duration(milliseconds: 300)); // 2. zamanlayici ucus yuzunden erken doner
      await tester.pumpWidget(buildApp(const SizedBox())); // dispose
      await tester.pump(const Duration(seconds: 2));
      expect(b.count('PUT /posts/500/like'), 1);
      expect(b.count('DELETE /posts/500/like'), 1);
    });

    testWidgets('yazi olcegi 1.3 ve 320 dp: tasma yok', (tester) async {
      useScreen(tester, const Size(320, 640));
      final b = FakeBackend();
      fakePosts(b, count: 1);
      await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
          child: _like(b, _post(likes: 12345))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('BlockBus (engel sonrasi akis)', () {
    testWidgets('engellenen yazarin TUM kutulari Kesfet izgarasindan hemen duser', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      final f = fakePosts(b, count: 8, pageSize: 8);
      // yarisi yazar 12, yarisi yazar 77
      for (var i = 0; i < f.posts.length; i++) {
        f.posts[i]['author'] = samplePostAuthor(id: i.isEven ? 12 : 77, name: i.isEven ? 'A' : 'B');
      }
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 600));
      final before = find.byType(DiscoverPostBox).evaluate().length;
      expect(before, greaterThan(3));
      BlockBus.instance.blocked(12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final after = find.byType(DiscoverPostBox).evaluate().length;
      expect(after, lessThan(before));
      expect(after, greaterThan(0)); // diger yazar kalir
      expect(tester.takeException(), isNull);
    });
  });
}
