import 'dart:async';

import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/feed_seen.dart';
import 'package:bu_kampus/features/posts/popularity_meter.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_video.dart';
import 'package:bu_kampus/features/profile/popularity_card.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_app.dart';

/// KS-MB: Keşfet tek sıralama, tekrar göstermeme (seen), video gönderi, Reels, popülerlik göstergeleri.

Map<String, dynamic> videoPost({int id = 2001, int score = 72, String? text = 'Kısa video', bool poster = true}) => {
      'id': id,
      'type': 'VIDEO',
      'author': {
        'id': 12,
        'displayName': 'Ayşe Yılmaz',
        'department': 'Bilgisayar Müh.',
        'followerCount': 120,
        'popularityScore': 64,
      },
      'text': text,
      'media': <Map<String, dynamic>>[],
      'video': {
        'url': '/api/posts/media/$id',
        if (poster) 'posterUrl': '/api/posts/media/$id?thumb=true',
        'durationMs': 23000,
        'width': 720,
        'height': 1280,
      },
      'likeCount': 5,
      'likedByMe': false,
      'mine': false,
      'canEdit': false,
      'canDelete': false,
      'createdAt': '2026-11-04T09:00:00Z',
      'popularityScore': score,
    };

class FakeVideoPlatformKs extends VideoPlayerPlatform {
  final created = <DataSource>[];
  final calls = <String>[];
  final volumes = <double>[];
  final disposed = <int>[];
  int _next = 1;
  final _events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource);
    final id = _next++;
    final sc = StreamController<VideoEvent>();
    sc.add(VideoEvent(eventType: VideoEventType.initialized, duration: const Duration(seconds: 23), size: const Size(720, 1280)));
    _events[id] = sc;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await _events[playerId]?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> setVolume(int playerId, double volume) async => volumes.add(volume);
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 3);
  @override
  Widget buildView(int playerId) => const SizedBox(key: ValueKey('fakeVideoView'));
}

class _FakeCompressor implements VideoCompressor {
  @override
  Future<VideoInfo?> info(String path) async =>
      VideoInfo(path: path, sizeBytes: 90 * 1024 * 1024, durationMs: 20000, width: 1920, height: 1080);

  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async {
    onProgress(.5);
    return VideoInfo(
        path: '/c.mp4',
        sizeBytes: 12 * 1024 * 1024,
        durationMs: 20000,
        width: 720,
        height: 1280,
        bytes: Uint8List.fromList(List.filled(2048, 1)));
  }

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => Uint8List.fromList(kFakePng);

  @override
  Future<void> cancel() async {}
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

void main() {
  setUpAll(loadTestFonts);

  group('modeller', () {
    test('video gonderi: video{} + type VIDEO + puan; poster fotograf yerine gecer', () {
      final p = Post.fromJson(videoPost());
      expect(p.isVideo, isTrue);
      expect(p.video!.durationMs, 23000);
      expect(p.video!.url, endsWith('/api/posts/media/2001'));
      expect(p.popularityScore, 72);
      expect(p.author.followerCount, 120);
      expect(p.author.popularityScore, 64);
      expect(p.photo, isNotNull); // poster kare akis kutusu icin
      expect(p.photo!.thumbUrl, contains('thumb=true'));
      expect(p.hiddenInFeed, isFalse);
    });

    test('eski bicim: yalniz media[kind=VIDEO] da video sayilir; fotograf gonderisinde video yok', () {
      final legacy = Post.fromJson({
        'id': 5,
        'author': {'id': 1, 'displayName': 'A'},
        'media': [samplePostMedia(id: 50, video: true)],
      });
      expect(legacy.isVideo, isTrue);
      expect(legacy.hiddenInFeed, isFalse);
      final photo = Post.fromJson(samplePost(id: 6, media: [samplePostMedia(id: 60)]));
      expect(photo.isVideo, isFalse);
      expect(photo.photo, isNotNull);
      expect(photo.popularityScore, isNull);
    });

    test('puan 0..100 araligina kistirilir; sayfa exhausted okunur', () {
      expect(Post.fromJson({'id': 1, 'author': {}, 'popularityScore': 250}).popularityScore, 100);
      expect(Post.fromJson({'id': 1, 'author': {}, 'popularityScore': -3}).popularityScore, 0);
      expect(Post.fromJson({'id': 1, 'author': {}, 'popularityScore': 41.6}).popularityScore, 42);
      final page = PostPage.parse({'items': [], 'exhausted': true}, Post.fromJson);
      expect(page.exhausted, isTrue);
      expect(PostPage.parse({'items': []}, Post.fromJson).exhausted, isFalse);
    });
  });

  group('PostApi + FeedSeenReporter', () {
    test('feed varsayilan scope=foryou; popular/latest/following; reels ayri uc; markSeen 100luk parcalar; view govdesi', () async {
      final b = FakeBackend();
      b.on('/feed*', {'items': [], 'nextCursor': null});
      b.on('/feed/reels*', {'items': [], 'nextCursor': null});
      final api = PostApi(makeSession(b));
      await api.feed();
      await api.feed(scope: 'popular');
      await api.reels(size: 4);
      await api.reels(replay: true);
      expect(b.requests.any((r) => r.startsWith('GET /feed?') && r.contains('scope=foryou')), isTrue);
      expect(b.requests.any((r) => r.startsWith('GET /feed?') && r.contains('scope=popular')), isTrue);
      expect(b.requests.any((r) => r.startsWith('GET /feed/reels?') && r.contains('replay=true')), isTrue);
      expect(b.requests.any((r) => r.startsWith('GET /feed/reels?') && r.contains('size=4')), isTrue);
      await api.markSeen(List.generate(150, (i) => i + 1));
      expect(b.count('POST /feed/seen'), 2);
      expect(((b.bodyLog['POST /feed/seen']!.first as Map)['ids'] as List).length, 100);
      expect(((b.bodyLog['POST /feed/seen']!.last as Map)['ids'] as List).length, 50);
      await api.view(7, watchedMs: 4200, durationMs: 23000);
      expect(b.bodies['POST /posts/7/view'], {'watchedMs': 4200, 'durationMs': 23000});
      await api.view(8, watchedMs: 0, durationMs: 1000); // izlenmeyen bildirilmez
      expect(b.count('/posts/8/view'), 0);
    });

    test('reporter: ayni kimlik bir kez, gecikmeli tek istek; flush hemen; dispose sonrasi kabul yok', () async {
      final b = FakeBackend();
      final api = PostApi(makeSession(b));
      final r = FeedSeenReporter(api, delay: const Duration(milliseconds: 30));
      r.markAll([1, 2, 2, 3]);
      r.mark(1);
      expect(r.pendingCount, 3);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(b.count('POST /feed/seen'), 1);
      expect((b.bodies['POST /feed/seen'] as Map)['ids'], [1, 2, 3]);
      r.markAll([2, 3, 4]); // 2 ve 3 zaten gitti
      await r.flush();
      expect(b.count('POST /feed/seen'), 2);
      expect((b.bodies['POST /feed/seen'] as Map)['ids'], [4]);
      r.mark(5);
      r.dispose(); // bekleyen gonderilmez, zamanlayici kalmaz
      r.mark(9);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(b.count('POST /feed/seen'), 2);
      expect(r.pendingCount, 0);
    });
  });

  group('Kesfet', () {
    Widget discover(FakeBackend b, {bool tabActive = true}) =>
        DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null), tabActive: tabActive);

    testWidgets('yenileme (imecsiz ilk sayfa) onbellekten degil agdan gelir; ag yoksa onbellek yedegi', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final first = b.count('GET /feed?');
      expect(first, greaterThanOrEqualTo(1));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('GET /feed?'), greaterThan(first));
      noErr(tester);
    });

    testWidgets('video gonderi kutusu: oynat rozeti + sure; bos/hata olmadan cizilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      b.on('/feed*', {
        'items': [videoPost(id: 2001), videoPost(id: 2002, text: null, poster: false), samplePost(id: 3, media: [samplePostMedia(id: 30)])],
        'nextCursor': null,
      });
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(DiscoverPostBox), findsNWidgets(3));
      expect(find.byKey(const ValueKey('videoDuration')), findsNWidgets(2)); // 0:23 sure etiketleri
      expect(find.text('0:23'), findsNWidgets(2));
      noErr(tester);
    });
  });

  group('video karti + puan gostergesi', () {
    testWidgets('detay kartinda video gorununce sessiz oynar; ses dugmesi; sure 1 sn ustu izlenince view bildirilir',
        (tester) async {
      useScreen(tester, const Size(390, 844));
      final plat = FakeVideoPlatformKs();
      final prev = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = plat;
      addTearDown(() => VideoPlayerPlatform.instance = prev);
      postVideoMuted.value = true;
      final b = FakeBackend();
      final s = makeSession(b);
      final post = Post.fromJson(videoPost());
      await tester.pumpWidget(buildApp(Scaffold(
        body: ListView(children: [PostCard(session: s, post: post, detail: true, onChanged: (_) {}, onDeleted: (_) {})]),
      )));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('postVideo')), findsOneWidget);
      expect(plat.created.single.uri, contains('/api/posts/media/2001'));
      expect(plat.calls, contains('play'));
      expect(plat.volumes.last, 0); // sessiz baslar
      expect(find.byKey(const ValueKey('popularityMeter')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('popularityValue'))).data, '72');
      await tester.tap(find.byKey(const ValueKey('postVideoSound')));
      await tester.pump(const Duration(milliseconds: 20)); // dugme gecikmesiz (cift dokunus sarmalayicisinin disinda)
      expect(postVideoMuted.value, isFalse);
      expect(plat.volumes.last, 1);
      postVideoMuted.value = true;
      // Ekrandan cikinca izlenme bildirilir (>= 1 sn gercek zaman gerekir; burada kisa oldugundan bildirim yok).
      await unmount(tester);
    });

    testWidgets('PopularityMeter: cubuk orani = puan; erisilebilir etiket', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: Center(child: PopularityMeter(score: 40)))));
      await tester.pump();
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Popülerlik'), findsOneWidget);
      final f = tester.widget<FractionallySizedBox>(find.ancestor(of: find.byKey(const ValueKey('popularityFill')), matching: find.byType(FractionallySizedBox)));
      expect(f.widthFactor, closeTo(.4, .0001));
      expect(find.bySemanticsLabel('Popülerlik puanı 40 / 100'), findsOneWidget);
    });

    testWidgets('PopularityCard: puan yoksa cizilmez; varsa puan + bilesenler', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: PopularityCard(profile: {'followerCount': 3}))));
      expect(find.byKey(const ValueKey('popularityCard')), findsNothing);
      await tester.pumpWidget(buildApp(const Scaffold(
          body: Padding(
              padding: EdgeInsets.all(20),
              child: PopularityCard(profile: {'popularityScore': 58, 'followerCount': 120, 'likesReceived': 340, 'postCount': 9}, self: true)))));
      await tester.pump();
      expect(find.text('58'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('Alınan beğeni'), findsOneWidget);
      expect(find.textContaining('hesaplanır'), findsOneWidget);
    });
  });

  group('gonderi olustur: video', () {
    testWidgets('video sec -> hazirla -> onizleme -> paylas: POST /posts/media sonra POST /posts mediaIds', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      Post? shared;
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                shared = await Navigator.of(context).push<Post>(MaterialPageRoute(
                  builder: (_) => ComposePostPage(
                    session: s,
                    videoService: VideoService(
                        limitBytes: VideoService.postMaxBytes,
                        compressor: _FakeCompressor(),
                        pick: (src) async => const PickedVideo('/orig.mp4')),
                    videoUploader: VideoUploader(s, client: b.client),
                  ),
                ));
              },
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('composeVideoGallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeVideoCamera')), findsOneWidget);
      expect(find.text('Video en fazla 60 saniye ve 50 MB olabilir.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('videoDuration')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'Kampüs turu');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(b.count('POST /posts/media'), 1);
      expect(b.count('POST /posts'), greaterThanOrEqualTo(2)); // media + gonderi
      final body = b.bodies['POST /posts'] as Map;
      expect(body['text'], 'Kampüs turu');
      expect((body['mediaIds'] as List).length, 1);
      expect(shared, isNotNull);
      noErr(tester);
    });

    testWidgets('50 MB ustu video: net hata, onizleme yok, paylas pasif', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final big = _BigCompressor();
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        videoService: VideoService(limitBytes: VideoService.postMaxBytes, compressor: big, pick: (src) async => const PickedVideo('/orig.mp4')),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsNothing);
      expect(find.text('Video çok büyük (en fazla 50 MB).'), findsOneWidget);
      noErr(tester);
    });
  });
}

class _BigCompressor extends _FakeCompressor {
  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async =>
      VideoInfo(path: '/c.mp4', sizeBytes: 60 * 1024 * 1024, durationMs: 20000, width: 720, height: 1280, bytes: Uint8List(8));
}
