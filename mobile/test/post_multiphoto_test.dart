import 'dart:typed_data';

import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_carousel.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_photo_viewer.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Çoklu fotoğraflı gönderi: model, carousel, kart, ızgara rozeti, oluşturucu (seçici sınırı, sıra, yükleme).
class _CountingUploader extends PostMediaUploader {
  _CountingUploader(super.session);
  final uploaded = <int>[];
  int _next = 700;

  @override
  Future<PostMedia> upload(Uint8List bytes) async {
    final id = _next++;
    uploaded.add(id);
    return PostMedia.fromJson(samplePostMedia(id: id));
  }
}

Post _multi({int n = 3, int id = 2000}) => Post.fromJson(samplePost(
      id: id,
      text: 'Gezi',
      media: [for (var i = 0; i < n; i++) {...samplePostMedia(id: 10 + i), 'position': i}],
    ));

void _noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: $e');
}

void main() {
  setUpAll(loadTestFonts);

  group('model', () {
    test('photos/isMulti/position: sunucu sirasi korunur, tek fotografta carousel yok', () {
      final m = _multi(n: 3);
      expect(m.isMulti, isTrue);
      expect(m.photos.map((e) => e.id), [10, 11, 12]);
      expect(m.photos.map((e) => e.position), [0, 1, 2]);
      expect(m.photo!.id, 10); // eski istemci/paylasim karti: ilk fotograf
      final one = Post.fromJson(samplePost(id: 1, media: [samplePostMedia(id: 5)]));
      expect(one.isMulti, isFalse);
      expect(one.photos, hasLength(1));
      expect(one.photos.first.position, 0); // position alani yoksa 0
    });

    test('video gonderisi coklu degildir', () {
      final v = Post.fromJson({...samplePost(id: 3, media: [samplePostMedia(id: 9, video: true)]), 'type': 'VIDEO'});
      expect(v.isVideo, isTrue);
      expect(v.isMulti, isFalse);
      expect(v.photos, isEmpty);
    });
  });

  group('carousel', () {
    Future<FakeBackend> pumpCard(WidgetTester tester, Post p, {TextDirection dir = TextDirection.ltr}) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 1);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Scaffold(
        body: Directionality(
          textDirection: dir,
          child: ListView(children: [PostCard(session: s, post: p, onChanged: (_) {}, onDeleted: (_) {})]),
        ),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      return b;
    }

    String pill(WidgetTester tester) => (find.descendant(of: find.byKey(const ValueKey('postCarouselPill')), matching: find.byType(Text)).evaluate().first.widget as Text).data!;

    testWidgets('3 fotograf: hap 1/3, yana kaydirinca 2/3; ilk karede yalniz ilk fotograf yuklenir (tembel)', (tester) async {
      final p = _multi();
      await pumpCard(tester, p);
      expect(find.byKey(const ValueKey('post-carousel-2000')), findsOneWidget);
      expect(pill(tester), '1/3');
      expect(find.byKey(const ValueKey('post-photo-2000')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-photo-2000-11')), findsNothing);
      expect(find.byKey(const ValueKey('post-photo-2000-12')), findsNothing);
      await tester.drag(find.byKey(const ValueKey('post-carousel-2000')), const Offset(-300, 0));
      await settle(tester, const Duration(milliseconds: 500));
      expect(pill(tester), '2/3');
      expect(find.byKey(const ValueKey('post-photo-2000-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-photo-2000-12')), findsNothing);
      _noErr(tester);
    });

    testWidgets('ekran okuyucu: Fotograf 2/3 etiketi', (tester) async {
      final h = tester.ensureSemantics();
      await pumpCard(tester, _multi());
      expect(find.bySemanticsLabel('Fotoğraf 1/3'), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('post-carousel-2000')), const Offset(-300, 0));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('Fotoğraf 2/3'), findsOneWidget);
      h.dispose();
      _noErr(tester);
    });

    testWidgets('tek fotograf: eski gorunum (carousel/hap/nokta yok)', (tester) async {
      await pumpCard(tester, Post.fromJson(samplePost(id: 2001, text: 'Tek', media: [samplePostMedia(id: 1)])));
      expect(find.byKey(const ValueKey('post-photo-2001')), findsOneWidget);
      expect(find.byType(PostPhotoCarousel), findsNothing);
      expect(find.byKey(const ValueKey('postCarouselPill')), findsNothing);
      expect(find.byKey(const ValueKey('postCarouselDots')), findsNothing);
      _noErr(tester);
    });

    testWidgets('RTL: kaydirma yonu aynalanir (soldan saga surukleme sonraki fotografa gider)', (tester) async {
      await pumpCard(tester, _multi(), dir: TextDirection.rtl);
      expect(pill(tester), '1/3');
      await tester.drag(find.byKey(const ValueKey('post-carousel-2000')), const Offset(300, 0));
      await settle(tester, const Duration(milliseconds: 500));
      expect(pill(tester), '2/3');
      _noErr(tester);
    });

    testWidgets('cift dokunma carousel uzerinde de begenir (tek PUT)', (tester) async {
      final b = await pumpCard(tester, _multi());
      final c = tester.getCenter(find.byKey(const ValueKey('post-carousel-2000')));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await settle(tester, const Duration(milliseconds: 1200));
      expect(b.count('PUT /posts/2000/like'), 1);
      _noErr(tester);
    });
  });

  testWidgets('tam ekran goruntuleyici: kaydirma + sayac', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    fakePosts(b, count: 1);
    final s = makeSession(b);
    await tester.pumpWidget(buildApp(PostPhotoViewer(session: s, post: _multi())));
    await settle(tester, const Duration(milliseconds: 300));
    expect((tester.widget(find.byKey(const ValueKey('postViewerCounter'))) as Text).data, '1/3');
    await tester.drag(find.byKey(const ValueKey('postViewerPager')), const Offset(-300, 0));
    await settle(tester, const Duration(milliseconds: 500));
    expect((tester.widget(find.byKey(const ValueKey('postViewerCounter'))) as Text).data, '2/3');
    _noErr(tester);
  });

  testWidgets('profil izgarasi: coklu gonderi kosesinde rozet, tekte yok', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final f = fakePosts(b, count: 2);
    f.posts[0]['media'] = [for (var i = 0; i < 3; i++) samplePostMedia(id: 40 + i)];
    f.posts[1]['media'] = [samplePostMedia(id: 50)];
    await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b), userId: 12, name: 'Ayşe Yılmaz')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('postMultiBadge')), findsOneWidget);
    _noErr(tester);
  });

  group('olusturucu', () {
    Future<(FakeBackend, _CountingUploader, List<int>)> open(WidgetTester tester, {List<Uint8List> Function(int limit)? more}) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final up = _CountingUploader(s);
      final limits = <int>[];
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: up,
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        pickPhoto: (src) async => Uint8List.fromList(kFakePng),
        pickPhotos: (limit) async {
          limits.add(limit);
          return more != null ? more(limit) : [for (var i = 0; i < 3; i++) Uint8List.fromList(kFakePng)];
        },
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, up, limits);
    }

    String count(WidgetTester tester) => (tester.widget(find.byKey(const ValueKey('composePhotoCount'))) as Text).data!;

    testWidgets('tek fotografta yalniz "ekle" var; ekleyince sayac ve serit; secici kalan hakki alir', (tester) async {
      final (_, _, limits) = await open(tester);
      expect(count(tester), '1/10 fotoğraf');
      expect(find.byKey(const ValueKey('composeReorder')), findsNothing);
      expect(find.byKey(const ValueKey('composeRemove-0')), findsNothing); // tek fotografta silme yok (degistir var)
      await tester.tap(find.byKey(const ValueKey('composeAddPhotos')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(limits, [9]);
      expect(count(tester), '4/10 fotoğraf');
      expect(find.byKey(const ValueKey('composeReorder')), findsOneWidget);
      _noErr(tester);
    });

    testWidgets('10 fotograf sinirinda ekle kalkar; fazla secim kirpilir', (tester) async {
      final (_, _, limits) = await open(tester, more: (limit) => [for (var i = 0; i < limit + 3; i++) Uint8List.fromList(kFakePng)]);
      await tester.tap(find.byKey(const ValueKey('composeAddPhotos')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(limits, [9]);
      expect(count(tester), '10/10 fotoğraf');
      expect(find.byKey(const ValueKey('composeAddPhotos')), findsNothing);
      _noErr(tester);
    });

    testWidgets('kaldir: sayac azalir; paylas sirayla yukler ve mediaIds liste gonderir', (tester) async {
      final (b, up, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeAddPhotos')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(count(tester), '4/10 fotoğraf');
      await tester.tap(find.byKey(const ValueKey('composeRemove-3')));
      await tester.pump();
      expect(count(tester), '3/10 fotoğraf');
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(up.uploaded, [700, 701, 702]);
      final sent = (b.bodies['POST /posts'] as Map)['mediaIds'] as List;
      expect(sent, [700, 701, 702]);
      _noErr(tester);
    });
  });

  group('sunucu sozlesmesi', () {
    test('PostApi.create: mediaIds sirayla, tek mediaId eski cagri hala calisir', () async {
      final b = FakeBackend();
      fakePosts(b);
      final api = PostApi(makeSession(b));
      await api.create(mediaIds: [3, 1, 2], text: 'x');
      expect((b.bodies['POST /posts'] as Map)['mediaIds'], [3, 1, 2]);
      await api.create(mediaId: 9);
      expect((b.bodies['POST /posts'] as Map)['mediaIds'], [9]);
    });
  });
}
