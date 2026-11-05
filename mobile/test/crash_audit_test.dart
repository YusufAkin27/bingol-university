// CR-MB cokme denetimi (2026-11-05): kod incelemesinde bulunan cokme/yakalanmamis hata yollarinin regresyon testleri.
//  1) Yukleme istemcilerinde gecersiz UTF-8 hata govdesi FormatException sizdirmaz (ApiError olur).
//  2) STOMP: ikili/bozuk cerceve dinleyiciyi dusurmez; sonraki gecerli cerceve yine teslim edilir.
//  4) Oturum isareti: onceki oturum on planda olduyse (native cokme / ANR / bellek) tek UnexpectedTermination raporu.
//  3) Gorsel indirme: bildirilen boyutu asiri buyuk yanit belleğe toplanmaz (OOM = surec olumu), hata verir.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/crash/crash_reporter.dart';
import 'package:bu_kampus/core/error_log.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/realtime/stomp_client.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('yukleme istemcileri: gecersiz UTF-8 govde', () {
    // 0xFF/0xFE UTF-8'de gecersizdir (proxy / captive portal yanitlari tipik olarak Latin-1 gelir).
    final badBody = Uint8List.fromList([0x3c, 0xff, 0xfe, 0x80, 0x3e]);

    test('MultipartUploader: 502 + bozuk govde ApiError(502) olur, FormatException degil', () async {
      final s = makeSession(FakeBackend());
      final up = MultipartUploader(s, client: MockClient((_) async => http.Response.bytes(badBody, 502)));
      await expectLater(
        up.upload('/users/me/avatar', PreparedImage(Uint8List.fromList([1, 2, 3]), 'image/png')),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 502)),
      );
    });

    test('MultipartUploader: 200 + bozuk govde istisna firlatmaz (null sonuc)', () async {
      final s = makeSession(FakeBackend());
      final up = MultipartUploader(s, client: MockClient((_) async => http.Response.bytes(badBody, 200)));
      expect(await up.upload('/users/me/avatar', PreparedImage(Uint8List.fromList([1, 2, 3]), 'image/png')), isNull);
    });

    test('VideoUploader: 500 + bozuk govde ApiError(500) olur', () async {
      final s = makeSession(FakeBackend());
      final up = VideoUploader(s, client: MockClient((_) async => http.Response.bytes(badBody, 500)));
      final video = PreparedVideo(bytes: Uint8List.fromList([0, 0, 0, 24]), sizeBytes: 4, durationMs: 1000);
      await expectLater(
        up.upload('/posts', video),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 500)),
      );
    });
  });

  group('STOMP: ikili/bozuk cerceve', () {
    test('gecersiz UTF-8 ikili ileti yakalanmamis hata uretmez; ardindan gelen MESSAGE teslim edilir', () async {
      final http0 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http0.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((data) {
          if (data is String && data.startsWith('CONNECT')) {
            ws.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\x00');
          } else if (data is String && data.startsWith('SUBSCRIBE')) {
            ws.add(Uint8List.fromList([0xff, 0xfe, 0xfd, 0x80])); // bozuk UTF-8
            ws.add('MESSAGE\nsubscription:sub-0\ndestination:/x\n\nmerhaba\x00');
          }
        }, onError: (_) {}, onDone: () {});
      });
      final uncaught = <Object>[];
      final got = Completer<String>();
      StompClient? client;
      await runZonedGuarded(() async {
        client = StompClient(
          url: 'ws://127.0.0.1:${http0.port}/ws',
          host: '127.0.0.1',
          accessToken: () => 'tok',
          refreshToken: () async => 'tok',
          backoffUnit: const Duration(milliseconds: 20),
        );
        client!.subscribe('/x', (f) {
          if (!got.isCompleted) got.complete(f.body);
        });
        client!.connect();
        expect(await got.future.timeout(const Duration(seconds: 5)), 'merhaba');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }, (e, s) => uncaught.add(e));
      client?.dispose();
      await http0.close(force: true);
      expect(uncaught, isEmpty, reason: 'bozuk ikili cerceve FormatException ile dinleyiciyi dusurmemeli');
    });

    test('dispose sonrasi gec gelen kalici hata kapanmis denetleyiciye eklenmez (StateError yok)', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        // Token yoksa _open sessionExpired yayar; dispose edilmis istemcide bu StateError olurdu.
        final c = StompClient(
          url: 'ws://127.0.0.1:1/ws',
          host: '127.0.0.1',
          accessToken: () => null,
          refreshToken: () async => null,
        );
        c.dispose();
        c.connect(); // _wanted=true -> _open -> token yok -> sessionExpired
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }, (e, s) => uncaught.add(e));
      expect(uncaught, isEmpty);
    });
  });

  group('gorsel indirme: asiri buyuk yanit', () {
    late HttpServer server;
    setUp(() async {
      HttpOverrides.global = null; // gercek yerel HTTP (flutter_test varsayilani 400 doner)
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        // 1 GB bildir, birkac bayt yaz ve bekle: istemci govdeyi belleğe toplamaya CALISMAMALI.
        req.response.contentLength = 1024 * 1024 * 1024;
        req.response.add(List<int>.filled(16, 1));
        await req.response.flush();
      });
    });
    tearDown(() async => server.close(force: true));

    testWidgets('bildirilen boyut sinirini asan yanit hemen hata verir (zaman asimi degil)', (tester) async {
      await tester.runAsync(() async {
        final c = Completer<Object?>();
        final p = DiskNetworkImage('http://127.0.0.1:${server.port}/files/huge.bin', cache: ImageDiskCache.disabled());
        final stream = p.resolve(ImageConfiguration.empty);
        late ImageStreamListener l;
        l = ImageStreamListener((i, _) {
          if (!c.isCompleted) c.complete(true);
          stream.removeListener(l);
        }, onError: (e, s) {
          if (!c.isCompleted) c.complete(e);
          stream.removeListener(l);
        });
        stream.addListener(l);
        final r = await c.future.timeout(const Duration(seconds: 5), onTimeout: () => 'timeout');
        expect(r, isA<NetworkImageLoadException>());
        expect((r as NetworkImageLoadException).statusCode, HttpStatus.requestEntityTooLarge);
      });
    });
  });

  group('oturum isareti: on planda beklenmedik olum', () {
    late Directory dir;
    final sep = Platform.pathSeparator;

    String marker() {
      final f = File('${dir.path}${sep}session_marker.json');
      return f.existsSync() ? f.readAsStringSync() : '';
    }

    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 150 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    setUp(() async {
      mockSecureStorage();
      dir = await Directory.systemTemp.createTemp('crash_marker');
    });

    tearDown(() async {
      ErrorLog.instance.onScreenChanged = null;
      ErrorLog.instance.currentScreen = null;
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('on plandayken olen oturum: sonraki acilista sürüm + son ekranla tek rapor kuyruga girer', () async {
      final a = CrashReporter(active: true, osVersion: 'Android 14');
      await a.init(dir: dir, trackSession: true);
      ErrorLog.instance.currentScreen = 'chat_detail';
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await until(() => marker().contains('"fg":true') && marker().contains('chat_detail'));
      expect(marker(), contains('"fg":true'));
      expect(marker(), contains('chat_detail'));
      // Surec burada olur (dispose/paused yok) -> yeni acilis
      a.dispose();
      final b = CrashReporter(active: true, osVersion: 'Android 14');
      await b.init(dir: dir, trackSession: true);
      expect(b.pending, 1);
      final r = b.queue.single;
      expect(r['errorType'], CrashReporter.unexpectedExitType);
      expect(r['screen'], 'chat_detail');
      expect(r['fatal'], isTrue);
      expect(r['stackTrace'], isNotEmpty);
      expect(r.keys, isNot(contains('message')));
      expect(r.keys, isNot(contains('userId')));
      b.dispose();
    });

    test('arka plana gecip (temiz) kapanan oturum rapor uretmez; yeniden on plana gelince tekrar izlenir', () async {
      final a = CrashReporter(active: true);
      await a.init(dir: dir, trackSession: true);
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      a.didChangeAppLifecycleState(AppLifecycleState.paused);
      await until(() => marker().contains('"fg":false'));
      expect(marker(), contains('"fg":false'));
      a.dispose();
      final b = CrashReporter(active: true);
      await b.init(dir: dir, trackSession: true);
      expect(b.pending, 0);
      b.dispose();
    });

    test('inactive (son uygulamalar / izin penceresi) on plan sayilmaz: hizli kaydirarak kapatma sahte cokme degil', () async {
      final a = CrashReporter(active: true);
      await a.init(dir: dir, trackSession: true);
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      a.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await until(() => marker().contains('"fg":false'));
      a.dispose();
      final b = CrashReporter(active: true);
      await b.init(dir: dir, trackSession: true);
      expect(b.pending, 0);
      b.dispose();
    });

    test('rapor ayari kapaliyken isaret tutulmaz ve silinir; rapor uretilmez', () async {
      final a = CrashReporter(active: true);
      await a.init(dir: dir, trackSession: true);
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await until(() => marker().contains('"fg":true'));
      await a.setEnabled(false);
      expect(marker(), isEmpty);
      a.dispose();
      final b = CrashReporter(active: true);
      await b.init(dir: dir, trackSession: true);
      expect(b.enabled, isFalse);
      expect(b.pending, 0);
      expect(marker(), isEmpty);
      b.dispose();
    });

    test('etkin degilken (debug/test) ve trackSession yokken isaret dosyasi olusmaz', () async {
      final off = CrashReporter(active: false);
      await off.init(dir: dir, trackSession: true);
      final plain = CrashReporter(active: true);
      await plain.init(dir: dir);
      expect(marker(), isEmpty);
      off.dispose();
      plain.dispose();
    });

    test('bozuk isaret dosyasi acilisi bozmaz', () async {
      File('${dir.path}${sep}session_marker.json').writeAsStringSync('{bozuk');
      final a = CrashReporter(active: true);
      await a.init(dir: dir, trackSession: true);
      expect(a.pending, 0);
      a.dispose();
    });
  });
}
