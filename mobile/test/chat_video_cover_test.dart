import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/cache/video_cover_cache.dart';
import 'package:bu_kampus/core/platform/secure_view.dart';
import 'package:bu_kampus/core/platform/video_frame.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_info_media.dart';
import 'package:bu_kampus/features/chat/chat_media_gallery_page.dart';
import 'package:bu_kampus/features/chat/chat_video_cover.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/store_shots_images.dart';

// Video kapağı: poster varsa o; yoksa/yüklenemezse istemcinin ürettiği kare (önbellekli, tek üretim, en çok 2 eşzamanlı);
// üretilemezse koyu yer tutucu. Balon, bilgi sayfası medya şeridi, galeri Videolar sekmesi ve görüntüleyici aynı bileşeni kullanır.

/// Sahte kare üretici: çağrıları sayar, isteğe bağlı bekletir.
class _Frames implements VideoFrameSource {
  _Frames({this.bytes, this.gate});

  Uint8List? bytes;
  final calls = <String>[];
  final headersSeen = <Map<String, String>?>[];
  int running = 0;
  int maxRunning = 0;
  Completer<void>? gate;

  @override
  Future<Uint8List?> frame({
    String? path,
    String? url,
    Map<String, String>? headers,
    int positionMs = 500,
    int maxEdge = 720,
  }) async {
    calls.add(url ?? path ?? '');
    headersSeen.add(headers);
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      final g = gate;
      if (g != null) await g.future;
    } finally {
      running--;
    }
    return bytes;
  }
}

Map<String, dynamic> _video(int id, {String? thumb, int? ms = 24000}) => {
      'id': id,
      'kind': 'VIDEO',
      'url': '/api/conversations/1/media/$id',
      if (thumb != null) 'thumbUrl': thumb,
      if (ms != null) 'durationMs': ms,
      'width': 720,
      'height': 1280,
    };

void main() {
  setUpAll(loadTestFonts);

  late _Frames frames;
  late Uint8List png;

  setUp(() {
    png = storeImageBytes(0);
    frames = _Frames(bytes: png);
    VideoCoverCache.instance = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled());
  });

  tearDown(() {
    VideoCoverCache.instance = VideoCoverCache();
    debugNetworkImageHttpClientProvider = null;
  });

  group('VideoCoverCache', () {
    test('ayni video icin uc eszamanli istek TEK uretim yapar; sonraki istek bellekten gelir', () async {
      final c = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled());
      final r = await Future.wait([
        c.cover('https://x/v/1', const {'Authorization': 'Bearer t'}),
        c.cover('https://x/v/1', const {}),
        c.cover('https://x/v/1', const {}),
      ]);
      expect(r.every((b) => b != null && b.length == png.length), isTrue);
      expect(frames.calls, ['https://x/v/1']);
      expect(frames.headersSeen.single, {'Authorization': 'Bearer t'});
      expect(c.peek('https://x/v/1'), isNotNull);
      await c.cover('https://x/v/1', const {});
      expect(frames.calls, hasLength(1));
      expect(c.generated, 1);
    });

    test('esdegerli en cok 2 uretim: 5 video siraya girer', () async {
      frames.gate = Completer<void>();
      final c = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled());
      final fs = [for (var i = 0; i < 5; i++) c.cover('https://x/v/$i', const {})];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(frames.maxRunning, 2);
      expect(frames.calls, hasLength(2));
      frames.gate!.complete();
      final out = await Future.wait(fs);
      expect(out.every((b) => b != null), isTrue);
      expect(frames.calls, hasLength(5));
      expect(frames.maxRunning, 2);
    });

    test('uretim basarisiz: null doner, hata penceresinde yeniden denenmez; sure dolunca denenir', () async {
      frames.bytes = null;
      final c = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled(), retryAfter: const Duration(milliseconds: 50));
      expect(await c.cover('https://x/v/9', const {}), isNull);
      expect(c.recentlyFailed('https://x/v/9'), isTrue);
      expect(await c.cover('https://x/v/9', const {}), isNull);
      expect(frames.calls, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      frames.bytes = png;
      expect(await c.cover('https://x/v/9', const {}), isNotNull);
      expect(frames.calls, hasLength(2));
    });

    test('uretici istisna firlatsa bile cagirana sizmaz', () async {
      final c = VideoCoverCache(frames: _Throwing(), disk: ImageDiskCache.disabled());
      expect(await c.cover('https://x/v/3', const {}), isNull);
    });

    test('ekrandan cikan (wanted=false) ogenin bekleyen isi uretilmez ve hata sayilmaz', () async {
      frames.gate = Completer<void>();
      final c = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled(), maxConcurrent: 1);
      final first = c.cover('https://x/v/a', const {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      var visible = true;
      final second = c.cover('https://x/v/b', const {}, wanted: () => visible);
      visible = false;
      frames.gate!.complete();
      await first;
      expect(await second, isNull);
      expect(frames.calls, ['https://x/v/a']);
      expect(c.recentlyFailed('https://x/v/b'), isFalse);
    });

    test('diske yazilir: yeni ornek (uygulama yeniden acildi) ureticiye hic basvurmadan diskten alir', () async {
      final dir = await Directory.systemTemp.createTemp('vcover');
      try {
        final disk = ImageDiskCache(dirProvider: () async => dir);
        final a = VideoCoverCache(frames: frames, disk: disk);
        await a.cover('https://x/v/7', const {});
        await disk.settle();
        final dead = _Frames(bytes: null);
        final b = VideoCoverCache(frames: dead, disk: disk);
        final got = await b.cover('https://x/v/7', const {});
        expect(got, isNotNull);
        expect(dead.calls, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('bellek LRU: tavan asilinca en eski kapak dusurulur', () async {
      final c = VideoCoverCache(frames: frames, disk: ImageDiskCache.disabled(), memoryEntries: 2);
      for (final i in [1, 2, 3]) {
        await c.cover('https://x/v/$i', const {});
      }
      expect(c.peek('https://x/v/1'), isNull);
      expect(c.peek('https://x/v/3'), isNotNull);
    });
  });

  group('PlatformVideoFrames (kanal)', () {
    const ch = MethodChannel('test/video_frame');
    const vcCh = MethodChannel('video_compress');
    final log = <MethodCall>[];

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(vcCh, null);
      log.clear();
    });

    test('iOS: yerel dosya yolu kanala gider, baytlar doner', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async {
        log.add(call);
        return Uint8List.fromList([1, 2, 3]);
      });
      final f = PlatformVideoFrames(channel: ch, ios: true, android: false);
      final r = await f.frame(path: '/tmp/a.mp4', positionMs: 500);
      expect(r, [1, 2, 3]);
      expect(log.single.method, 'frame');
      final a = log.single.arguments as Map;
      expect(a['path'], '/tmp/a.mp4');
      expect(a['url'], isNull);
      expect(a['positionMs'], 500);
      expect(a['maxEdge'], 720);
    });

    test('iOS: ag adresi + yetkili basliklar kanala gider', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async {
        log.add(call);
        return Uint8List.fromList([9]);
      });
      final f = PlatformVideoFrames(channel: ch, ios: true, android: false);
      await f.frame(url: 'https://x/api/conversations/1/media/5', headers: const {'Authorization': 'Bearer t'});
      final a = log.single.arguments as Map;
      expect(a['url'], 'https://x/api/conversations/1/media/5');
      expect(a['headers'], {'Authorization': 'Bearer t'});
      expect(a['path'], isNull);
    });

    test('iOS: yerel taraf yok (MissingPlugin) / hata / bos yanit -> null, istisna yok', () async {
      final f = PlatformVideoFrames(channel: ch, ios: true, android: false);
      expect(await f.frame(path: '/tmp/a.mp4'), isNull); // isleyici yok
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async => throw PlatformException(code: 'X'));
      expect(await f.frame(path: '/tmp/a.mp4'), isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async => null);
      expect(await f.frame(url: 'https://x/v'), isNull);
    });

    test('Android: ag adresi video_compress kanalindaki getByteFrameUrl ile alinir', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(vcCh, (call) async {
        log.add(call);
        return Uint8List.fromList([7, 7]);
      });
      final f = PlatformVideoFrames(channel: ch, ios: false, android: true);
      final r = await f.frame(url: 'https://x/v/1', headers: const {'Authorization': 'Bearer t'});
      expect(r, [7, 7]);
      expect(log.single.method, 'getByteFrameUrl');
      expect((log.single.arguments as Map)['headers'], {'Authorization': 'Bearer t'});
    });

    test('baska platform / bos girdi: kanal cagrilmaz, null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async {
        log.add(call);
        return Uint8List.fromList([1]);
      });
      expect(await PlatformVideoFrames(channel: ch, ios: false, android: false).frame(path: '/a.mp4'), isNull);
      expect(await PlatformVideoFrames(channel: ch, ios: true, android: false).frame(), isNull);
      expect(log, isEmpty);
    });
  });

  group('ChatSecureView: guvenli katman kapisi', () {
    const ch = MethodChannel('test/bu_secure_gate');
    final args = <Object?>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async {
        if (call.method == 'enable') {
          args.add(call.arguments);
          return {'secureLayer': false, 'captured': false};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
      args.clear();
    });

    test('varsayilan KAPALI (TestFlight cokmesi sonrasi): katman denenmez, BU_SECURE_LAYER=true ile acilir', () async {
      expect(ChatSecureView.layerTrickDefault, isFalse);
      final v = ChatSecureView(channel: ch, isIOS: true);
      final st = await v.enable();
      expect((args.single as Map)['layerTrick'], false);
      expect(st.layerRequested, isFalse);
      // Bayrak kapali: aciliş meşru ama koruma iddia edilmez.
      expect(v.allowsViewOnce(st), isTrue);
      expect(v.isProtected(st), isFalse);
      await v.disable();
    });

    test('bayrak ACIK + katman kurulamadi: acilis ENGELLI', () async {
      final v = ChatSecureView(channel: ch, isIOS: true, layerTrick: true);
      final st = await v.enable();
      expect((args.single as Map)['layerTrick'], true);
      expect(st.layerRequested, isTrue);
      expect(v.allowsViewOnce(st), isFalse);
      await v.disable();
    });

    test('bayrak ACIK + yerel kopru yok/zaman asimi: acilis ENGELLI; Android her zaman serbest', () async {
      final v = ChatSecureView(channel: const MethodChannel('test/yok'), isIOS: true, layerTrick: true);
      final st = await v.enable();
      expect(st.secureLayer, isFalse);
      expect(v.allowsViewOnce(st), isFalse);
      await v.disable();
      final a = ChatSecureView(isIOS: false, layerTrick: true);
      expect(a.allowsViewOnce(await a.enable()), isTrue);
      expect(a.isProtected(const SecureStatus()), isTrue);
    });

    test('acikca kapatilirse layerTrick=false gider', () async {
      final v = ChatSecureView(channel: ch, isIOS: true);
      await v.enable(layerTrick: false);
      expect((args.single as Map)['layerTrick'], false);
      await v.disable();
    });

    test('acikca istenirse layerTrick=true gider', () async {
      final v = ChatSecureView(channel: ch, isIOS: true);
      await v.enable(layerTrick: true);
      expect((args.single as Map)['layerTrick'], true);
      await v.disable();
    });
  });

  group('ChatVideoCover', () {
    Future<void> pumpCover(WidgetTester tester, Widget cover, {Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(Center(child: SizedBox(width: 120, height: 120, child: cover)), brightness: b, size: size));
      await settle(tester, const Duration(milliseconds: 500));
    }

    testWidgets('poster YOKSA kare uretilir ve gosterilir; ikinci kutu ayni kareyi yeniden uretmeden alir', (tester) async {
      await pumpCover(tester, const ChatVideoCover(videoUrl: '/api/conversations/1/media/5', headers: {'Authorization': 'Bearer t'}));
      expect(frames.calls, hasLength(1));
      expect(frames.calls.single, endsWith('/api/conversations/1/media/5'));
      expect(frames.headersSeen.single, {'Authorization': 'Bearer t'});
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpCover(tester, const ChatVideoCover(videoUrl: '/api/conversations/1/media/5', headers: {}));
      expect(frames.calls, hasLength(1)); // paylasilan onbellek
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsOneWidget);
    });

    testWidgets('poster VARSA gosterilir, kare URETILMEZ', (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      await pumpCover(
          tester,
          const ChatVideoCover(
              videoUrl: '/api/conversations/1/media/5', posterUrl: '/api/conversations/1/media/5/thumb', headers: {}));
      debugNetworkImageHttpClientProvider = null; // test bitmeden sifirla (flutter invariant)
      expect(frames.calls, isEmpty);
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('poster indirilemezse (404/ag hatasi) video karesi uretilir', (tester) async {
      // Varsayilan test ag yigini 400 doner: poster hata verir (adres, imageCache'te onceki testten kalmasin diye ayri).
      await pumpCover(
          tester,
          const ChatVideoCover(
              videoUrl: '/api/conversations/1/media/55', posterUrl: '/api/conversations/1/media/55/broken-thumb', headers: {}));
      expect(frames.calls, hasLength(1));
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsOneWidget);
    });

    testWidgets('uretim hatasi: koyu yer tutucu, cokme yok', (tester) async {
      frames.bytes = null;
      await pumpCover(tester, const ChatVideoCover(videoUrl: '/api/conversations/1/media/6', headers: {}));
      expect(frames.calls, hasLength(1));
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('videoUrl null: yalniz yer tutucu, uretim yok', (tester) async {
      await pumpCover(tester, const ChatVideoCover(videoUrl: null, headers: {}));
      expect(frames.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Video kapagi her yerde', () {
    Future<void> pumpDetail(WidgetTester tester, Size size, Brightness b, {double scale = 1}) async {
      final be = FakeBackend()
        ..on('/conversations/1/messages?size=30', {
          'items': [
            // poster YOK (iPhone'dan eski gonderim)
            {
              'id': 12,
              'conversationId': 1,
              'senderId': 11,
              'text': '',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'attachments': [_video(90)]
            },
          ],
          'nextCursor': null,
        })
        ..on('/conversations/1', {
          'conversation': {'id': 1},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Mehmet Kaya'},
          ],
        })
        ..on('/users/11/presence', {'online': true})
        ..on('/messages/reactions', {'emojis': ['👍']});
      useScreen(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildApp(
          ChatDetailPage(
            session: makeSession(be),
            connectRealtime: false,
            conversation: const {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Mehmet Kaya',
              'peer': {'id': 11, 'displayName': 'Mehmet Kaya'},
            },
          ),
          brightness: b,
          size: size));
      await settle(tester, const Duration(milliseconds: 700));
    }

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final b in Brightness.values) {
        testWidgets('balon: posteri olmayan video kapak uretir, sure rozeti var, tasma yok (${size.width.toInt()} dp x1.3 ${b.name})',
            (tester) async {
          await pumpDetail(tester, size, b, scale: 1.3);
          expect(frames.calls, hasLength(1));
          expect(find.byKey(const ValueKey('videoCoverGenerated')), findsOneWidget);
          expect(find.text('0:24'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }

    testWidgets('balon: uretim basarisizsa koyu yer tutucu + sure rozeti kalir, cokme yok', (tester) async {
      frames.bytes = null;
      await pumpDetail(tester, kPhoneMedium, Brightness.dark);
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsNothing);
      expect(find.text('0:24'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    Map<String, dynamic> msg(int id, {String? thumb}) => {
          'id': id,
          'senderId': 2,
          'createdAt': '2026-10-20T10:${(id % 60).toString().padLeft(2, '0')}:00Z',
          'attachments': [
            {
              'id': id,
              'kind': 'VIDEO',
              'durationMs': 42000,
              'url': '/api/conversations/5/media/$id',
              if (thumb != null) 'thumbUrl': thumb,
            }
          ],
        };

    testWidgets('galeri Videolar sekmesi: posteri olmayan videolar icin kapak uretilir (en cok 2 eszamanli, paylasimli)', (tester) async {
      frames.gate = Completer<void>();
      final be = FakeBackend()
        ..on('/conversations/5/messages?size=40', {
          'items': [for (var i = 6; i > 0; i--) msg(i)],
          'nextCursor': null,
        });
      useScreen(tester, kPhoneSmall);
      final feed = ChatMediaFeed(api: makeSession(be).api, conversationId: 5, senderName: (m) => null)..load(first: true);
      await tester.pumpWidget(buildApp(
          ChatMediaGalleryPage(feed: feed, headers: const {'Authorization': 'Bearer t'}, onOpen: (items, i) {}, initialTab: 1),
          size: kPhoneSmall));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('0:42'), findsWidgets);
      expect(frames.maxRunning, lessThanOrEqualTo(2));
      expect(frames.calls.length, lessThanOrEqualTo(2));
      frames.gate!.complete();
      await settle(tester, const Duration(milliseconds: 600));
      expect(frames.calls.toSet().length, frames.calls.length); // ayni video iki kez uretilmez
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsWidgets);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('bilgi sayfasi medya seridi: poster olmayan video kartinda kapak, sure rozeti; video adresi gorsel olarak YUKLENMEZ',
        (tester) async {
      final be = FakeBackend()
        ..on('/conversations/5/messages?size=40', {
          'items': [msg(3), msg(2), msg(1, thumb: '/api/conversations/5/media/1/thumb')],
          'nextCursor': null,
        });
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      final feed = ChatMediaFeed(api: makeSession(be).api, conversationId: 5, senderName: (m) => null)..load(first: true);
      await tester.pumpWidget(buildApp(
          Scaffold(
            body: ListenableBuilder(
              listenable: feed,
              builder: (c, _) => ChatInfoMediaStrip(feed: feed, headers: const {}, onOpen: (i) {}, onSeeAll: () {}),
            ),
          ),
          brightness: Brightness.dark,
          size: kPhoneSmall));
      await settle(tester, const Duration(milliseconds: 600));
      debugNetworkImageHttpClientProvider = null;
      // 2 video poster'siz -> 2 uretim; 1 video poster'li -> uretim yok.
      expect(frames.calls, hasLength(2));
      expect(find.byKey(const ValueKey('videoCoverGenerated')), findsNWidgets(2));
      expect(find.text('0:42'), findsNWidgets(3));
      // Video adresi `Image.network` ile gorsel olarak istenmedi.
      expect(feed.items.where((i) => i.isVideo).length, 3);
      expect(feed.items.where((i) => i.thumbUrl == i.url), isEmpty);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}

class _Throwing implements VideoFrameSource {
  @override
  Future<Uint8List?> frame({String? path, String? url, Map<String, String>? headers, int positionMs = 500, int maxEdge = 720}) {
    throw StateError('boom');
  }
}
