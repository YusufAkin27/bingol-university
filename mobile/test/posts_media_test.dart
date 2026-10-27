import 'dart:async';
import 'dart:convert';

import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart' show PlayBadge, DurationPill;
import 'package:bu_kampus/features/posts/post_media_gallery.dart';
import 'package:bu_kampus/features/posts/post_media_view.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/video_autoplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_app.dart';

/// Platform kanalı kullanmayan sahte video platformu.
class FakeVideoPlatform extends VideoPlayerPlatform {
  final created = <String>[];
  final disposed = <int>[];
  final calls = <String>[];
  final volumes = <double>[];
  int _next = 1;
  final _events = <int, StreamController<VideoEvent>>{};

  int count(String c) => calls.where((x) => x == c).length;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource.uri ?? '');
    final id = _next++;
    final sc = StreamController<VideoEvent>();
    sc.add(VideoEvent(
        eventType: VideoEventType.initialized, duration: const Duration(seconds: 42), size: const Size(1280, 720)));
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
  Future<void> setLooping(int playerId, bool looping) async => calls.add('loop');
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> setVolume(int playerId, double volume) async => volumes.add(volume);
  @override
  Future<void> seekTo(int playerId, Duration position) async => calls.add('seek');
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 3);
  @override
  Widget buildView(int playerId) => const SizedBox(key: ValueKey('fakeVideoView'));
}

PostMedia _img(int i) => PostMedia.fromJson(samplePostMedia(id: i));
PostMedia _vid(int i) => PostMedia.fromJson(samplePostMedia(id: i, video: true, durationMs: 42000));

List<PostMedia> _items(int n, {bool video = true}) =>
    [for (var i = 0; i < n; i++) (video && i == 1) ? _vid(100 + i) : _img(100 + i)];

Widget _view(Session s, List<PostMedia> media, Size size,
    {Brightness b = Brightness.light,
    void Function(int)? onOpen,
    VoidCallback? onDoubleTap,
    bool autoplay = false,
    VideoAutoplayController? ctrl}) {
  return buildApp(
    Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PostMediaView(
              session: s,
              media: media,
              onOpen: onOpen ?? (_) {},
              onDoubleTap: onDoubleTap,
              autoplay: autoplay,
              autoplayController: ctrl),
        ),
      ),
    ),
    brightness: b,
    size: size,
  );
}

Future<Map<String, dynamic>?> _call(FakeBackend b, String method, String path, [Object? body]) async {
  final req = http.Request(method, Uri.parse('http://localhost/api$path'));
  if (body != null) {
    req.headers['content-type'] = 'application/json';
    req.body = jsonEncode(body);
  }
  final res = await http.Response.fromStream(await b.client.send(req));
  if (res.bodyBytes.isEmpty) return {'_status': res.statusCode};
  try {
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    return j is Map<String, dynamic> ? {...j, '_status': res.statusCode} : {'_list': j, '_status': res.statusCode};
  } catch (_) {
    return {'_status': res.statusCode, '_bytes': res.bodyBytes.length, '_type': res.headers['content-type']};
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('PostMediaView', () {
    for (final n in [1, 2, 3, 4, 5, 10]) {
      for (final size in kPhoneSizes) {
        for (final dark in [false, true]) {
          testWidgets('$n oge ${size.width.toInt()} dp ${dark ? "koyu" : "acik"} tasma yok', (tester) async {
            useScreen(tester, size);
            final s = makeSession(FakeBackend());
            await tester.pumpWidget(_view(s, _items(n), size, b: dark ? Brightness.dark : Brightness.light));
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            final cells = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('postMediaCell'));
            expect(cells, findsNWidgets(n > 6 ? 6 : n));
            expect(find.byKey(const ValueKey('postMediaMore')), n > 6 ? findsOneWidget : findsNothing);
            if (n > 6) expect(find.text('+4'), findsOneWidget);
            if (n >= 2) expect(find.byType(PlayBadge), findsOneWidget);
            await unmount(tester);
          });
        }
      }
    }

    testWidgets('video hucresinde sure hapi ve oynat rozeti', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_view(makeSession(FakeBackend()), [_vid(7)], kPhoneMedium));
      await tester.pump();
      expect(find.byType(PlayBadge), findsOneWidget);
      expect(find.byType(DurationPill), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('dokununca onOpen(index); +N hucresi 5. dizini acar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final opened = <int>[];
      await tester.pumpWidget(_view(makeSession(FakeBackend()), _items(4), kPhoneMedium, onOpen: opened.add));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('postMediaCell2')));
      await tester.tap(find.byKey(const ValueKey('postMediaCell0')));
      expect(opened, [2, 0]);
      await unmount(tester);

      opened.clear();
      await tester.pumpWidget(_view(makeSession(FakeBackend()), _items(9), kPhoneMedium, onOpen: opened.add));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('postMediaMore')));
      expect(opened, [5]);
      expect(find.text('+3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cift dokunma geri cagrisi', (tester) async {
      useScreen(tester, kPhoneMedium);
      var dbl = 0;
      final opened = <int>[];
      await tester.pumpWidget(_view(makeSession(FakeBackend()), _items(1, video: false), kPhoneMedium,
          onOpen: opened.add, onDoubleTap: () => dbl++));
      await tester.pump();
      final c = find.byKey(const ValueKey('postMediaCell0'));
      await tester.tap(c);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(dbl, 1);
      expect(opened, isEmpty);
      await tester.tap(c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(opened, [0]);
      await unmount(tester);
    });

    testWidgets('yukleniyor yer tutucusu sonra hata ikonu', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_view(makeSession(FakeBackend()), [_img(1)], kPhoneMedium));
      expect(find.byKey(const ValueKey('postMediaLoading')), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('postMediaError')), findsOneWidget);
      expect(find.byKey(const ValueKey('postMediaLoading')), findsNothing);
      await unmount(tester);
    });

    testWidgets('tek ogede oran korunur (kare 1:1 ve cok uzun dikey kirpilir)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final tall = PostMedia.fromJson(samplePostMedia(id: 3, width: 500, height: 2000));
      await tester.pumpWidget(_view(makeSession(FakeBackend()), [tall], kPhoneMedium));
      await tester.pump();
      final h = tester.getSize(find.byKey(const ValueKey('postMediaCell0'))).height;
      final w = tester.getSize(find.byKey(const ValueKey('postMediaCell0'))).width;
      expect(h / w, closeTo(1 / 0.75, .01)); // en uzun: 0.75 oran
      await unmount(tester);
    });
  });

  group('VideoAutoplayController', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform previous;
    late VideoAutoplayController c;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      previous = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      c = VideoAutoplayController(observeLifecycle: false);
    });
    tearDown(() {
      c.dispose();
      VideoPlayerPlatform.instance = previous;
      PostPrefs.autoplay = true;
    });

    Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 30));

    void rep(Object k, double f, double d, {bool scrolling = false, bool enabled = true}) => c.report(k,
        uri: Uri.parse('http://x/$k'),
        headers: const {'Authorization': 'Bearer t'},
        visibleFraction: f,
        centerDistance: d,
        scrolling: scrolling,
        enabled: enabled);

    test('ekran ortasina en yakin ve %60+ gorunen tek video oynar', () async {
      rep('a', .9, 200);
      rep('b', .7, 50);
      rep('c', .5, 0); // yeterince gorunmuyor
      await idle();
      expect(c.activeKey, 'b');
      expect(platform.created, ['http://x/b']);
      expect(platform.count('play'), 1);
      expect(c.readyControllerFor('b'), isNotNull);
      expect(c.readyControllerFor('a'), isNull);
      expect(platform.volumes.last, 0); // sessiz
    });

    test('kaydirinca degisir, kaydirma sirasinda duraklar', () async {
      rep('a', .9, 100);
      rep('b', .3, 400);
      await idle();
      expect(c.activeKey, 'a');
      final p0 = platform.count('pause');
      rep('a', .5, 300);
      rep('b', .8, 80);
      await idle();
      expect(c.activeKey, 'b');
      expect(platform.count('pause'), greaterThan(p0)); // a durdu
      rep('b', .8, 80, scrolling: true);
      await idle();
      expect(c.activeKey, isNull);
      expect(platform.count('pause'), greaterThan(p0 + 0));
      rep('b', .8, 80);
      await idle();
      expect(c.activeKey, 'b');
      expect(platform.created.length, 2); // b yeniden olusturulmadi
    });

    test('en cok 2 denetleyici bellekte; ayar kapaliyken oynamaz', () async {
      for (final k in ['a', 'b', 'c']) {
        rep('a', k == 'a' ? .9 : .1, 0);
        rep('b', k == 'b' ? .9 : .1, 0);
        rep('c', k == 'c' ? .9 : .1, 0);
        await idle();
        expect(c.activeKey, k);
      }
      expect(c.controllerCount, 2);
      expect(platform.disposed.length, 1);
      PostPrefs.autoplay = false;
      rep('c', .9, 0);
      await idle();
      expect(c.activeKey, isNull);
    });

    test('enabled=false (sekme/rota gorunmez) ve uygulama arka plani durdurur', () async {
      rep('a', .9, 0);
      await idle();
      expect(c.activeKey, 'a');
      rep('a', .9, 0, enabled: false);
      await idle();
      expect(c.activeKey, isNull);
      rep('a', .9, 0);
      await idle();
      expect(c.activeKey, 'a');
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(c.activeKey, isNull);
      rep('a', .9, 0);
      await idle();
      expect(c.activeKey, isNull); // askida
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await idle();
      expect(c.activeKey, 'a');
    });

    test('ses ac/kapat ve unregister/dispose guvenli', () async {
      rep('a', .9, 0);
      await idle();
      c.toggleMuted();
      expect(c.muted, isFalse);
      await idle();
      expect(platform.volumes.last, 1);
      c.unregister('a');
      await idle();
      expect(c.activeKey, isNull);
      c.unregister('yok'); // zararsiz
      c.dispose();
      await idle();
      expect(platform.disposed, isNotEmpty);
      rep('x', 1, 0); // dispose sonrasi cagri istisna firlatmaz
      c = VideoAutoplayController(observeLifecycle: false); // tearDown icin
    });
  });

  group('PostMediaView otomatik oynatma', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform previous;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      previous = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });
    tearDown(() => VideoPlayerPlatform.instance = previous);

    testWidgets('gorunur video oynar, ekran disindaysa oynamaz, kaydirinca baslar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final ctrl = VideoAutoplayController(observeLifecycle: false);
      addTearDown(ctrl.dispose);
      final s = makeSession(FakeBackend());
      await tester.pumpWidget(buildApp(
        Scaffold(
          body: ListView(children: [
            const SizedBox(height: 1500),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PostMediaView(session: s, media: [_vid(7)], onOpen: (_) {}, autoplay: true, autoplayController: ctrl),
            ),
            const SizedBox(height: 1500),
          ]),
        ),
        size: kPhoneMedium,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(ctrl.activeKey, isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -1250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(ctrl.activeKey, 7);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('autoplayVideo')), findsOneWidget);
      expect(find.byType(PlayBadge), findsNothing);
      expect(find.byKey(const ValueKey('autoplayMute')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('autoplayMute')));
      await tester.pump();
      expect(ctrl.muted, isFalse);

      // Tekrar uzaga kaydir: durur.
      await tester.drag(find.byType(ListView), const Offset(0, 1250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(ctrl.activeKey, isNull);
      await unmount(tester);
    });
  });

  group('PostMediaGallery', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform previous;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      previous = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });
    tearDown(() => VideoPlayerPlatform.instance = previous);

    Future<void> openIt(WidgetTester tester, List<PostMedia> items,
        {int index = 0, List<String>? savedImages, List<String>? savedVideos, bool failSave = false}) async {
      useScreen(tester, kPhoneMedium);
      final s = makeSession(FakeBackend());
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => openPostMediaGallery(
                  context,
                  s,
                  items,
                  index,
                  saveImage: (u, h) async {
                    if (failSave) throw UnsupportedError('x');
                    savedImages?.add(u);
                  },
                  saveVideo: (u, h) async {
                    savedVideos?.add(u);
                  },
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('sayac, sayfalama, video sayfasi oynar ve sayfa degisince durur, kapat', (tester) async {
      await openIt(tester, _items(3));
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('galleryImage100')), findsOneWidget);

      await tester.drag(find.byKey(const ValueKey('galleryPages')), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2 / 3'), findsOneWidget);
      expect(platform.created.length, 1);
      expect(platform.count('play'), 1);
      expect(find.byKey(const ValueKey('galleryVideoSeek')), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);

      var pa = platform.count('pause');
      await tester.tap(find.byKey(const ValueKey('galleryVideoStage')));
      await tester.pump();
      expect(platform.count('pause'), greaterThan(pa)); // dokununca duraklat
      await tester.tap(find.byKey(const ValueKey('galleryVideoStage')));
      await tester.pump();
      expect(platform.count('play'), 2);
      pa = platform.count('pause');

      await tester.drag(find.byKey(const ValueKey('galleryPages')), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('3 / 3'), findsOneWidget);
      expect(platform.count('pause'), greaterThan(pa)); // video sayfasi terk edilince durdu

      await tester.tap(find.byKey(const ValueKey('galleryClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('galleryPages')), findsNothing);
      await unmount(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(platform.disposed, isNotEmpty);
    });

    testWidgets('baslangic dizini', (tester) async {
      await openIt(tester, _items(4), index: 3);
      expect(find.text('4 / 4'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kaydetme: gorsel ve video geri cagrilari, basarisizlikta mesaj', (tester) async {
      final imgs = <String>[];
      final vids = <String>[];
      await openIt(tester, _items(2), savedImages: imgs, savedVideos: vids);
      await tester.tap(find.byKey(const ValueKey('gallerySave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(imgs, [_items(2)[0].url]);
      expect(find.text('Galeriye kaydedildi'), findsOneWidget);

      await tester.drag(find.byKey(const ValueKey('galleryPages')), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('gallerySave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(vids, [_items(2)[1].url]);
      await unmount(tester);
    });

    testWidgets('kaydetme desteklenmiyorsa mesaj gosterir', (tester) async {
      await openIt(tester, _items(1, video: false), failSave: true);
      await tester.tap(find.byKey(const ValueKey('gallerySave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bu cihazda desteklenmiyor.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('asagi surukleyerek kapatma', (tester) async {
      await openIt(tester, _items(1, video: false));
      expect(find.byKey(const ValueKey('galleryPages')), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('galleryPages')), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('galleryPages')), findsNothing);
      await unmount(tester);
    });

    testWidgets('gorsel hatasi mesaji', (tester) async {
      await openIt(tester, _items(1, video: false));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('galleryImageError')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('fakePosts', () {
    test('feed sayfalama p2, popular sirasi, bos akis, hata', () async {
      final b = FakeBackend();
      final f = fakePosts(b, count: 12);
      final p1 = (await _call(b, 'GET', '/feed?scope=latest&size=10'))!;
      expect((p1['items'] as List).length, 10);
      expect(p1['nextCursor'], 'p2');
      final p2 = (await _call(b, 'GET', '/feed?scope=latest&cursor=p2&size=10'))!;
      expect((p2['items'] as List).length, 2);
      expect(p2['nextCursor'], isNull);
      final pop = (await _call(b, 'GET', '/feed?scope=popular&size=3'))!;
      final likes = [for (final p in pop['items'] as List) p['likeCount'] as int];
      expect(likes, [...likes]..sort((a, c) => c.compareTo(a)));
      f.emptyFeed = true;
      expect(((await _call(b, 'GET', '/feed'))!['items'] as List), isEmpty);
      f.emptyFeed = false;
      f.failFeed = true;
      expect((await _call(b, 'GET', '/feed'))!['_status'], 500);
    });

    test('gonderi olustur / getir / duzenle / sil', () async {
      final b = FakeBackend();
      final f = fakePosts(b);
      final created = (await _call(b, 'POST', '/posts', {'text': 'merhaba'}))!;
      expect(created['_status'], 201);
      expect(created['mine'], isTrue);
      expect(f.posts.first['id'], created['id']);
      expect((await _call(b, 'GET', '/posts/${created['id']}'))!['text'], 'merhaba');
      expect((await _call(b, 'PATCH', '/posts/${created['id']}', {'text': 'yeni'}))!['text'], 'yeni');
      expect((await _call(b, 'POST', '/posts', {}))!['_status'], 400);
      expect((await _call(b, 'DELETE', '/posts/${created['id']}'))!['_status'], 204);
      expect((await _call(b, 'GET', '/posts/${created['id']}'))!['_status'], 404);
      expect(((await _call(b, 'GET', '/posts/mine'))!['items'] as List), isEmpty);
    });

    test('begeni sayaci degisir ve idempotent', () async {
      final b = FakeBackend();
      final f = fakePosts(b);
      final id = f.posts.first['id'];
      final before = f.posts.first['likeCount'] as int;
      final r1 = (await _call(b, 'PUT', '/posts/$id/like'))!;
      expect(r1, containsPair('liked', true));
      expect(r1['likeCount'], before + 1);
      expect((await _call(b, 'PUT', '/posts/$id/like'))!['likeCount'], before + 1);
      expect((await _call(b, 'GET', '/posts/$id'))!['likedByMe'], isTrue);
      final r2 = (await _call(b, 'DELETE', '/posts/$id/like'))!;
      expect(r2, containsPair('liked', false));
      expect(r2['likeCount'], before);
      expect(((await _call(b, 'GET', '/posts/$id/likes'))!['items'] as List), isNotEmpty);
    });

    test('yorumlar: kok + onizleme, yanit, yazma, duzenleme, silme', () async {
      final b = FakeBackend();
      final f = fakePosts(b);
      final id = f.posts.first['id'] as int;
      f.seedComments(id);
      final list = (await _call(b, 'GET', '/posts/$id/comments?sort=new'))!;
      final items = list['items'] as List;
      expect(items.length, 3);
      expect(list['total'], 6);
      final withReplies = items.firstWhere((c) => (c['replyCount'] as int) > 0);
      expect((withReplies['previewReplies'] as List).length, 2);
      final replies = (await _call(b, 'GET', '/comments/${withReplies['id']}/replies'))!;
      expect((replies['items'] as List).length, 3);

      final c = (await _call(b, 'POST', '/posts/$id/comments', {'text': 'selam'}))!;
      expect(c['_status'], 201);
      expect(c['depth'], 0);
      final r = (await _call(b, 'POST', '/posts/$id/comments', {'text': 'yanit', 'parentId': c['id']}))!;
      expect(r['depth'], 1);
      expect(r['rootId'], c['id']);
      expect((await _call(b, 'PATCH', '/comments/${c['id']}', {'text': 'duzenli'}))!['text'], 'duzenli');
      // Yaniti olan yorum silinince "silindi" kalir.
      await _call(b, 'DELETE', '/comments/${c['id']}');
      final after = (await _call(b, 'GET', '/posts/$id/comments'))!;
      final kept = (after['items'] as List).firstWhere((x) => x['id'] == c['id']);
      expect(kept['deleted'], isTrue);
      expect(kept['text'], isNull);
      // Yanitsiz yorum listeden kalkar.
      await _call(b, 'DELETE', '/comments/${r['id']}');
      expect(f.comments[id]!.any((x) => x['id'] == r['id']), isFalse);
    });

    test('medya yukleme, bayt yanitlari ve yukleme hatasi', () async {
      final b = FakeBackend();
      final f = fakePosts(b);
      final up = (await _call(b, 'POST', '/posts/media', {}))!;
      expect(up['_status'], 201);
      expect(up['kind'], 'IMAGE');
      final img = (await _call(b, 'GET', '/posts/media/${up['id']}'))!;
      expect(img['_type'], 'image/png');
      expect(img['_bytes'], greaterThan(10));
      final videoPost = f.posts.firstWhere((p) => (p['media'] as List).any((m) => m['kind'] == 'VIDEO'));
      final vid = (videoPost['media'] as List).firstWhere((m) => m['kind'] == 'VIDEO');
      final v = (await _call(b, 'GET', '/posts/media/${vid['id']}'))!;
      expect(v['_type'], 'video/mp4');
      f.uploadError = 'VIDEO_TOO_LARGE';
      expect((await _call(b, 'POST', '/posts/media', {}))!['_status'], 413);
    });

    test('ornek veri uretecleri sozlesmeye uygun ve modelle ayrisir', () {
      final m = samplePostMedia(id: 5, video: true);
      final c = sampleComment(previewReplies: [sampleComment(id: 78, parentId: 77, depth: 1)]);
      final p = Post.fromJson(samplePost(media: [m], liked: true));
      expect(p.media.single.isVideo, isTrue);
      expect(p.media.single.durationMs, 12000);
      expect(p.likedByMe, isTrue);
      expect(PostComment.fromJson(c).previewReplies.single.depth, 1);
      expect(Post.fromJson(samplePost(mine: true)).canDelete, isTrue);
    });
  });
}
