import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart' show ImageSource;
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_text_rules.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

/// Yüklemeyi ağa gitmeden sahteler.
class _FakeUploader extends PostMediaUploader {
  _FakeUploader(super.session);
  int calls = 0;

  @override
  Future<PostMedia> upload(Uint8List bytes) async {
    calls++;
    return PostMedia.fromJson(samplePostMedia(id: 4242));
  }
}

bool _shareEnabled(WidgetTester tester) {
  final ink = find.descendant(of: find.byKey(const ValueKey('composeShare')), matching: find.byType(InkWell));
  return tester.widget<InkWell>(ink).onTap != null;
}

void main() {
  setUpAll(loadTestFonts);

  group('metin kurallari', () {
    test('kelime sayimi ve sinir', () {
      expect(postWordCount(''), 0);
      expect(postWordCount('  bir   iki '), 2);
      expect(postTextOk('bir iki uc dort bes alti yedi'), isTrue);
      expect(postTextOk('bir iki uc dort bes alti yedi sekiz'), isFalse);
      expect(postTextOk(''), isTrue);
      expect(postTextOk('a' * 61), isFalse);
    });
  });

  group('gonderi olustur', () {
    Future<(FakeBackend, FakePosts, _FakeUploader, List<ImageSource>)> open(WidgetTester tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b);
      final s = makeSession(b);
      final up = _FakeUploader(s);
      final asked = <ImageSource>[];
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: up,
        pickPhoto: (src) async {
          asked.add(src);
          return Uint8List.fromList(kFakePng);
        },
      )));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, fp, up, asked);
    }

    testWidgets('fotograf zorunlu: foto yokken paylas pasif, yalniz galeri/kamera secenegi var', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('composePicker')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePreview')), findsNothing);
      expect(_shareEnabled(tester), isFalse);
      // Metin yazmak foto olmadan paylasmayi acmaz.
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'merhaba');
      await tester.pump();
      expect(_shareEnabled(tester), isFalse);
      // Hashtag/anma/video/hikaye girisleri yok.
      expect(find.byIcon(Icons.videocam), findsNothing);
      noErr(tester);
    });

    testWidgets('tek fotograf secilince onizleme gelir ve paylas aktif olur', (tester) async {
      final (_, __, ___, asked) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(asked, [ImageSource.gallery]);
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePicker')), findsNothing);
      expect(_shareEnabled(tester), isTrue);
      // Kaldir: tekrar zorunlu duruma doner.
      await tester.tap(find.byKey(const ValueKey('composeRemove')));
      await tester.pump();
      expect(find.byKey(const ValueKey('composePicker')), findsOneWidget);
      expect(_shareEnabled(tester), isFalse);
      noErr(tester);
    });

    testWidgets('7 kelime siniri: canli sayac, 8. kelimede uyari ve paylas pasif', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      final field = find.byKey(const ValueKey('composeText'));
      expect(find.text('0/7 kelime'), findsOneWidget);
      await tester.enterText(field, 'bir iki uc dort bes');
      await tester.pump();
      expect(find.text('5/7 kelime'), findsOneWidget);
      expect(find.byKey(const ValueKey('composeLimitWarn')), findsNothing);
      expect(_shareEnabled(tester), isTrue);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi');
      await tester.pump();
      expect(find.text('7/7 kelime'), findsOneWidget);
      expect(_shareEnabled(tester), isTrue);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi sekiz');
      await tester.pump();
      expect(find.text('8/7 kelime'), findsOneWidget);
      expect(find.byKey(const ValueKey('composeLimitWarn')), findsOneWidget);
      expect(_shareEnabled(tester), isFalse);
      noErr(tester);
    });

    testWidgets('satir sonu yazilamaz', (tester) async {
      await open(tester);
      final field = find.byKey(const ValueKey('composeText'));
      await tester.enterText(field, 'bir\niki');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'biriki');
      noErr(tester);
    });

    testWidgets('paylas: once tek foto yuklenir, sonra mediaIds tek ogeyle gonderi olusur', (tester) async {
      final (b, fp, up, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'kisa not');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(up.calls, 1);
      final body = b.bodies['POST /posts'] as Map;
      expect(body['mediaIds'], [4242]);
      expect(body['text'], 'kisa not');
      expect(fp.posts.first['media'], hasLength(1));
      noErr(tester);
    });

    testWidgets('metinsiz de paylasilir (metin istege bagli)', (tester) async {
      final (b, _, __, ___) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      final body = b.bodies['POST /posts'] as Map;
      expect(body.containsKey('text'), isFalse);
      expect(body['mediaIds'], [4242]);
      noErr(tester);
    });
  });

  group('akis ve detay', () {
    test('video-only gonderi akistan gizlenir, cok gorselli gonderide yalniz ilk foto', () async {
      final b = FakeBackend();
      b.on('/feed*', {
        'items': [
          samplePost(id: 1, media: [samplePostMedia(id: 10, video: true)]),
          samplePost(id: 2, media: [samplePostMedia(id: 20, video: true), samplePostMedia(id: 21)]),
          samplePost(id: 3, media: [samplePostMedia(id: 30), samplePostMedia(id: 31)]),
        ],
        'nextCursor': null,
      });
      final page = await PostApi(makeSession(b)).feed();
      expect(page.items.map((p) => p.id), [2, 3]);
      expect(page.items[0].photo!.id, 21);
      expect(page.items[1].photo!.id, 30);
    });

    testWidgets('detay: foto + yazar + metin + begeni; yorum ve kaydet yok, yorum ucu cagrilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final p = samplePost(id: 91, text: 'Kisa bir not', media: [samplePostMedia(id: 910)], likeCount: 4);
      b.on('/posts/91', p);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: s, postId: 91, initial: Post.fromJson(p))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('post-photo-91')), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Kisa bir not'), findsOneWidget);
      expect(find.byKey(const ValueKey('like-heart')), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // yorum yazma alani yok
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(b.requests.any((r) => r.contains('/comments')), isFalse);
      noErr(tester);
    });

    testWidgets('begeni: kalbe dokununca iyimser artar ve PUT /posts/{id}/like gider', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final p = Post.fromJson(samplePost(id: 1000, text: 'Gonderi 1000', media: [samplePostMedia(id: 1)], likeCount: 4));
      await tester.pumpWidget(buildApp(Scaffold(
        body: ListView(children: [
          PostCard(session: s, post: p, onChanged: (_) {}, onDeleted: (_) {}),
        ]),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '4');
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '5');
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('PUT') && r.contains('/posts/1000/like')), isTrue);
      noErr(tester);
    });

    testWidgets('kullanici gonderileri: yorum/kaydet simgesi yok, yorum ucu cagrilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b), userId: 12, name: 'Ayşe Yılmaz')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostCard), findsWidgets);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(b.requests.any((r) => r.contains('/comments') || r.contains('/stories') || r.contains('/hashtags')), isFalse);
      noErr(tester);
    });
  });
}
