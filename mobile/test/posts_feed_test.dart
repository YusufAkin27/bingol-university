import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_feed_view.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(40).join(String.fromCharCode(10))}');
}

Widget feed(FakeBackend b, {String scope = 'latest', PostFeedController? c}) =>
    Scaffold(body: PostFeedView(session: makeSession(b), scope: scope, controller: c));

Widget discover(FakeBackend b, [ValueNotifier<String?>? req]) {
  final r = req ?? ValueNotifier<String?>(null);
  return DiscoverTab(session: makeSession(b), typeRequest: r);
}

void main() {
  setUpAll(loadTestFonts);

  group('modeller', () {
    test('Post.fromJson: bos/null alanlar cokmez', () {
      final p = Post.fromJson({'id': 5});
      expect(p.id, 5);
      expect(p.author.displayName, '');
      expect(p.media, isEmpty);
      expect(p.text, isNull);
      expect(p.likedByMe, isFalse);
      expect(p.hasText, isFalse);
      final z = Post.fromJson(null);
      expect(z.id, 0);
    });

    test('Post.fromJson: dolu + copyWith', () {
      final p = Post.fromJson(samplePost(
          id: 9, text: 'Merhaba', media: [samplePostMedia(id: 3), samplePostMedia(id: 4, video: true)]));
      expect(p.media.length, 2);
      expect(p.media[1].isVideo, isTrue);
      expect(p.media[0].isVideo, isFalse);
      expect(p.media[0].url, startsWith('http'));
      expect(p.media[0].thumbUrl, contains('thumb=true'));
      expect(p.media[0].aspect, closeTo(1080 / 1350, 0.001));
      final q = p.copyWith(likedByMe: true, likeCount: 10, commentCount: 7, text: 'Yeni', editedAt: 'x');
      expect(q.likedByMe, isTrue);
      expect(q.likeCount, 10);
      expect(q.commentCount, 7);
      expect(q.text, 'Yeni');
      expect(q.editedAt, 'x');
      expect(q.author.id, p.author.id);
    });

    test('PostMedia.aspect: boyut yok -> 1, asiri oran sikistirilir', () {
      expect(PostMedia.fromJson({'id': 1, 'kind': 'IMAGE'}).aspect, 1.0);
      expect(PostMedia.fromJson({'id': 1, 'width': 4000, 'height': 100}).aspect, 1.91);
      expect(PostMedia.fromJson({'id': 1, 'width': 100, 'height': 4000}).aspect, 0.5);
    });

    test('PostComment / PostPage / LikeResult / PostLiker', () {
      final c = PostComment.fromJson({
        'id': 7,
        'postId': 1,
        'text': null,
        'deleted': true,
        'previewReplies': [
          {'id': 8, 'postId': 1}
        ],
      });
      expect(c.deleted, isTrue);
      expect(c.text, isNull);
      expect(c.previewReplies.single.id, 8);
      expect(c.children, isEmpty);
      expect(c.replyToUser, isNull);
      final pg = PostPage.parse({'items': [{'id': 1}], 'nextCursor': 'abc', 'total': 4}, Post.fromJson);
      expect(pg.items.single.id, 1);
      expect(pg.hasMore, isTrue);
      expect(pg.total, 4);
      expect(PostPage.parse(null, Post.fromJson).items, isEmpty);
      expect(PostPage.parse({'items': null, 'nextCursor': null}, Post.fromJson).hasMore, isFalse);
      expect(LikeResult.fromJson({'liked': true, 'likeCount': 5}).likeCount, 5);
      expect(LikeResult.fromJson(null).liked, isFalse);
      expect(PostLiker.fromJson({'id': 2}).displayName, '');
    });
  });

  group('akis', () {
    testWidgets('yukleniyor (iskelet) -> dolu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 200));
      fakePosts(b);
      await tester.pumpWidget(buildApp(feed(b)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Gönderi 1000'), findsNothing);
      expect(find.byType(PostCard), findsNothing);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderi 1000'), findsOneWidget);
      expect(find.byType(PostCard), findsWidgets);
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=latest')), isTrue);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('bos akis', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, empty: true);
      await tester.pumpWidget(buildApp(feed(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('Henüz gönderi yok'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('hata -> yeniden dene veriyi getirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakePosts(b)..failFeed = true;
      await tester.pumpWidget(buildApp(feed(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Yeniden dene'), findsOneWidget);
      f.failFeed = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Gönderi 1000'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('ag hatasi -> yeniden dene gorunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..offline = true;
      fakePosts(b);
      await tester.pumpWidget(buildApp(feed(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Yeniden dene'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('sayfalama: sona kaydirinca imecle ikinci sayfa', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, count: 25, withMedia: false);
      await tester.pumpWidget(buildApp(feed(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.where((r) => r.contains('/feed')).length, 1);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('cursor=p2')), isTrue);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('cekip yenile: ilk sayfa tekrar istenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(feed(b)));
      await settle(tester, const Duration(milliseconds: 500));
      final before = b.count('/feed');
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('/feed'), greaterThan(before));
      expect(find.text('Gönderi 1000'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('scope degisince yeniden yuklenir (popular)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      var scope = 'latest';
      late StateSetter set;
      await tester.pumpWidget(buildApp(StatefulBuilder(builder: (c, s) {
        set = s;
        return feed(b, scope: scope);
      })));
      await settle(tester, const Duration(milliseconds: 500));
      set(() => scope = 'popular');
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.any((r) => r.contains('scope=popular')), isTrue);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('controller.insertPost: yeni gonderi basa eklenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      final c = PostFeedController();
      await tester.pumpWidget(buildApp(feed(b, c: c)));
      await settle(tester, const Duration(milliseconds: 500));
      c.insertPost(Post.fromJson(samplePost(id: 5555, text: 'Yeni eklenen', mine: true)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Yeni eklenen'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('dispose sonrasi gec yanit istisna uretmez', (tester) async {
      final b = FakeBackend(delay: const Duration(seconds: 2));
      fakePosts(b);
      final c = PostFeedController();
      await tester.pumpWidget(buildApp(feed(b, c: c)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      c.insertPost(Post.fromJson(samplePost())); // bagli degil: yok sayilir
      noErr(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok | ${br.name} ${size.width.toInt()}', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          final f = fakePosts(b, count: 8);
          f.posts[0]['text'] = 'Çok uzun bir gönderi metni, satır sonu olmadan sürer gider. ' * 12;
          f.posts[0]['author'] = samplePostAuthor(
              name: 'Çok Uzun Bir Kullanıcı Adı Soyadı Burada',
              department: 'Bilgisayar ve Yazılım Mühendisliği Bölümü Uzun Ad');
          await tester.pumpWidget(buildApp(feed(b), brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 600));
          expect(find.text('devamını oku'), findsOneWidget);
          noErr(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('kart', () {
    Widget host(Post p, void Function(Post) onChanged, {FakeBackend? b}) => Scaffold(
          body: SingleChildScrollView(
            child: PostCard(
              session: makeSession(b ?? FakeBackend()),
              post: p,
              onChanged: onChanged,
              onDeleted: (_) {},
              onOpen: (_) {},
            ),
          ),
        );

    testWidgets('uzun metin 6 satir + devamini oku genisletir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final p = Post.fromJson(samplePost(text: 'Uzun satır içeriği burada devam eder. ' * 40));
      await tester.pumpWidget(buildApp(host(p, (_) {})));
      await tester.pump();
      expect(find.text('devamını oku'), findsOneWidget);
      final h1 = tester.getSize(find.byType(PostCard)).height;
      await tester.tap(find.text('devamını oku'));
      await tester.pump();
      expect(find.text('devamını oku'), findsNothing);
      expect(tester.getSize(find.byType(PostCard)).height, greaterThan(h1));
      noErr(tester);
    });

    testWidgets('kisa metinde devamini oku yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final p = Post.fromJson(samplePost(text: 'Kısa'));
      await tester.pumpWidget(buildApp(host(p, (_) {})));
      await tester.pump();
      expect(find.text('devamını oku'), findsNothing);
      expect(find.text('Kısa'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('begeni iyimser guncellenir, sunucu sayisini uygular', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 300));
      final f = fakePosts(b, withMedia: false);
      f.posts.first['likeCount'] = 3;
      var post = Post.fromJson(f.posts.first);
      late StateSetter set;
      await tester.pumpWidget(buildApp(StatefulBuilder(builder: (c, s) {
        set = s;
        return host(post, (p) => s(() => post = p), b: b);
      })));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.heart));
      await tester.pump();
      expect(post.likedByMe, isTrue);
      expect(find.text('4'), findsOneWidget); // istek bitmeden
      await settle(tester, const Duration(milliseconds: 600));
      expect(post.likeCount, 4);
      expect(b.requests.any((r) => r.startsWith('PUT /posts/1000/like')), isTrue);
      set(() {});
      noErr(tester);
    });

    testWidgets('begeni hatasinda geri alinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      // Sahte backend'de olmayan gönderi: 404 POST_NOT_FOUND.
      var post = Post.fromJson(samplePost(id: 777, likeCount: 3));
      await tester.pumpWidget(buildApp(StatefulBuilder(
          builder: (c, s) => host(post, (p) => s(() => post = p), b: b))));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.heart));
      await settle(tester, const Duration(milliseconds: 500));
      expect(post.likedByMe, isFalse);
      expect(post.likeCount, 3);
      noErr(tester);
    });

    testWidgets('medya yerlesimleri (1,2,3,6) tasma yapmaz', (tester) async {
      for (final n in [1, 2, 3, 6]) {
        useScreen(tester, kPhoneSmall);
        final media = [for (var i = 0; i < n; i++) samplePostMedia(id: 100 + i, video: i == 1)];
        final p = Post.fromJson(samplePost(text: 'm$n', media: media));
        await tester.pumpWidget(buildApp(host(p, (_) {}), size: kPhoneSmall));
        await tester.pump();
        noErr(tester);
      }
    });
  });

  group('kesfet segmenti', () {
    testWidgets('varsayilan Gonderiler; haber istegi atilmaz; Yeni/Populer cipleri', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderiler'), findsOneWidget);
      expect(find.text('Haberler'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('Popüler'), findsOneWidget);
      expect(find.text('Gönderi 1000'), findsOneWidget);
      expect(b.count('/news'), 0);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Populer cipi scope=popular ister', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Popüler'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=popular')), isTrue);
      await tester.tap(find.text('Yeni'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.where((r) => r.contains('scope=latest')).length, greaterThanOrEqualTo(2));
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Haberler segmenti mevcut haber akisini gosterir; geri donunce gonderiler korunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/news*', newsPage([newsItem(1), newsItem(2)]));
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 500));
      final feedReqs = b.count('/feed');
      await tester.tap(find.text('Haberler'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Haber başlığı 1'), findsOneWidget);
      expect(find.text('Gönderi 1000'), findsNothing); // diger segment gorunmez
      expect(find.text('Kaydedilenler'), findsOneWidget);
      await tester.tap(find.text('Gönderiler'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönderi 1000'), findsOneWidget);
      expect(b.count('/feed'), feedReqs); // yeniden yuklenmedi
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('typeRequest (Ana sayfa Tumu) Haberler segmentine gecirir ve sifirlanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/news*', newsPage([newsItem(1, type: 'DUYURU')]));
      fakePosts(b, withMedia: false);
      final r = ValueNotifier<String?>(null);
      addTearDown(r.dispose);
      await tester.pumpWidget(buildApp(discover(b, r)));
      await settle(tester, const Duration(milliseconds: 500));
      r.value = 'DUYURU';
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.value, isNull);
      expect(b.requests.any((q) => q.contains('type=DUYURU')), isTrue);
      expect(find.text('Haber başlığı 1'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('+ dugmesi gorunur', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(discover(b), size: kPhoneSmall));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byTooltip('Gönderi oluştur'), findsOneWidget);
      expect(find.byType(BuSegmented), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });
}
