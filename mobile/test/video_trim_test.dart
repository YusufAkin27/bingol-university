import 'dart:typed_data';

import 'package:bu_kampus/core/platform/video_frame.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/platform/video_trim.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_video_limits.dart';
import 'package:bu_kampus/features/posts/video_trim_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

class _Frames implements VideoFrameSource {
  int calls = 0;
  @override
  Future<Uint8List?> frame({String? path, String? url, Map<String, String>? headers, int positionMs = 500, int maxEdge = 720}) async {
    calls++;
    return Uint8List.fromList(kFakePng);
  }
}

/// Orijinal (/orig.mp4) 90 sn, kirpilmis dosya 45 sn; gerisi (kisa video) `shortMs`.
class _Compressor implements VideoCompressor {
  _Compressor({this.origMs = 90000});
  final int origMs;
  @override
  Future<VideoInfo?> info(String path) async => VideoInfo(
      path: path, sizeBytes: 8 * 1024 * 1024, durationMs: path == '/orig.mp4' ? origMs : 45000, width: 1920, height: 1080);

  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async => VideoInfo(
      path: '/c.mp4', sizeBytes: 5 * 1024 * 1024, durationMs: 45000, width: 720, height: 1280, bytes: Uint8List.fromList(List.filled(2048, 1)));

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => Uint8List.fromList(kFakePng);

  @override
  Future<void> cancel() async {}
}

class _FakeTrim implements VideoTrimService {
  _FakeTrim({this.supported = true, this.fail = false});
  @override
  final bool supported;
  final bool fail;
  final calls = <({String path, int startMs, int endMs, int maxMs})>[];
  final discarded = <String>[];
  var _n = 0;

  @override
  Future<String> trim({required String path, required int startMs, required int endMs, int maxMs = 0}) async {
    calls.add((path: path, startMs: startMs, endMs: endMs, maxMs: maxMs));
    if (fail) throw VideoException('FAILED');
    return '/trimmed${++_n}.mp4';
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

void main() {
  setUpAll(loadTestFonts);

  group('TrimWindow', () {
    test('baslangic: ilk max kadar; kisa videoda tamami', () {
      expect(TrimWindow(totalMs: 90000, maxMs: 60000).range, const VideoTrimRange(0, 60000));
      expect(TrimWindow(totalMs: 20000, maxMs: 60000).range, const VideoTrimRange(0, 20000));
    });

    test('aralik hicbir zaman max den uzun / min den kisa olmaz; tutamac sinirda durur', () {
      final w = TrimWindow(totalMs: 120000, maxMs: 60000);
      w.moveEnd(100000); // 0..60000 ile sinirli
      expect(w.end, 60000);
      w.moveStart(30000);
      expect(w.range, const VideoTrimRange(30000, 60000));
      w.moveEnd(100000); // baslangic 30000 -> en cok 90000
      expect(w.end, 90000);
      w.moveStart(0); // en cok 60 sn: end-max = 30000
      expect(w.start, 30000);
      w.moveStart(89500); // en az 1 sn
      expect(w.length, PostVideoLimits.minTrimMs);
      w.moveEnd(0);
      expect(w.length, PostVideoLimits.minTrimMs);
    });

    test('shift uzunlugu korur ve [0,toplam] disina cikmaz', () {
      final w = TrimWindow(totalMs: 90000, maxMs: 60000);
      w.shift(-5000);
      expect(w.range, const VideoTrimRange(0, 60000));
      w.shift(50000);
      expect(w.range, const VideoTrimRange(30000, 90000));
      w.shift(1000);
      expect(w.range, const VideoTrimRange(30000, 90000));
    });

    test('VideoTrimRange.coversAll', () {
      expect(const VideoTrimRange(0, 20000).coversAll(20000), isTrue);
      expect(const VideoTrimRange(0, 19990).coversAll(20000), isTrue);
      expect(const VideoTrimRange(1000, 20000).coversAll(20000), isFalse);
    });

    test('PostVideoLimits.needsTrim: 60 sn + tolerans', () {
      expect(PostVideoLimits.maxDurationMs, 60000);
      expect(PostVideoLimits.needsTrim(60400), isFalse);
      expect(PostVideoLimits.needsTrim(61000), isTrue);
    });
  });

  group('PlatformVideoTrimService (kanal)', () {
    const ch = MethodChannel('bu_kampus/video_trim');
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));

    test('trim: bagimsiz degiskenleri kanala iletir, yeni yolu dondurur', () async {
      MethodCall? seen;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
        seen = c;
        return '/cache/video_trim/trim_1.mp4';
      });
      final out = await PlatformVideoTrimService(channel: ch, supported: true).trim(path: '/a.mp4', startMs: 1000, endMs: 31000, maxMs: 60000);
      expect(out, '/cache/video_trim/trim_1.mp4');
      expect(seen!.method, 'trim');
      expect(seen!.arguments, {'path': '/a.mp4', 'startMs': 1000, 'endMs': 31000, 'maxMs': 60000});
    });

    test('hata kodlari VideoException a cevrilir', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async => throw PlatformException(code: 'FAILED'));
      final s = PlatformVideoTrimService(channel: ch, supported: true);
      await expectLater(s.trim(path: '/a.mp4', startMs: 0, endMs: 5000), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'FAILED')));
      // kanal yok (masaustu/test): MissingPluginException -> UNSUPPORTED
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
      await expectLater(s.trim(path: '/a.mp4', startMs: 0, endMs: 5000), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'UNSUPPORTED')));
      // gecersiz aralik
      await expectLater(s.trim(path: '/a.mp4', startMs: 5000, endMs: 5000), throwsA(isA<VideoException>()));
    });

    test('desteklenmeyen platform: UNSUPPORTED, supported false', () async {
      final s = PlatformVideoTrimService(channel: ch, supported: false);
      expect(s.supported, isFalse);
      await expectLater(s.trim(path: '/a.mp4', startMs: 0, endMs: 5000), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'UNSUPPORTED')));
    });
  });

  group('VideoTrimPage', () {
    Future<List<VideoTrimRange?>> open(WidgetTester tester,
        {int total = 90000, bool mandatory = true, VideoTrimRange? initial, _Frames? frames}) async {
      useScreen(tester, const Size(390, 844));
      final results = <VideoTrimRange?>[];
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => results.add(await Navigator.of(c).push<VideoTrimRange>(MaterialPageRoute(
                  builder: (_) => VideoTrimPage(
                      path: '/orig.mp4', durationMs: total, mandatory: mandatory, initial: initial, frames: frames ?? _Frames())))),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
      return results;
    }

    String sel(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('trimSelected'))).data!;

    testWidgets('uzun video: aralik en cok 1:00, zorunlu kirpma ipucu, kucuk resim seridi dolar', (tester) async {
      final fr = _Frames();
      await open(tester, frames: fr);
      expect(sel(tester), '1:00');
      expect(find.textContaining('çok uzun'), findsOneWidget);
      expect(fr.calls, 8);
      expect(find.byKey(const ValueKey('trimHandleStart')), findsOneWidget);
      expect(find.byKey(const ValueKey('trimHandleEnd')), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      noErr(tester);
    });

    testWidgets('bitis tutamacini sola surukleyince sure kisalir; saga surukleyince 1:00 da kalir', (tester) async {
      await open(tester);
      final r = tester.getRect(find.byKey(const ValueKey('trimTimeline')));
      final endX = r.left + r.width * (60 / 90);
      var g = await tester.startGesture(Offset(endX, r.center.dy));
      await g.moveBy(const Offset(-6, 0));
      await g.moveBy(const Offset(-60, 0));
      await g.up();
      await tester.pump();
      // 66 px ~ 66/r.width * 90 sn
      final expected = 60 - 66 / r.width * 90;
      expect(sel(tester), anyOf(_clock(expected - 1), _clock(expected), _clock(expected + 1)));
      // saga: baslangic 0 -> en cok 1:00
      final endX2 = r.left + r.width * ((60 - 66 / r.width * 90) / 90);
      g = await tester.startGesture(Offset(endX2, r.center.dy));
      await g.moveBy(const Offset(6, 0));
      await g.moveBy(const Offset(300, 0));
      await g.up();
      await tester.pump();
      expect(sel(tester), '1:00');
      noErr(tester);
    });

    testWidgets('orta kisimdan surukleyince pencere kayar (sure 1:00 kalir); Bitti aralik dondurur', (tester) async {
      final results = await open(tester);
      final r = tester.getRect(find.byKey(const ValueKey('trimTimeline')));
      final g = await tester.startGesture(Offset(r.left + r.width * .3, r.center.dy));
      await g.moveBy(const Offset(8, 0));
      await g.moveBy(const Offset(40, 0));
      await g.up();
      await tester.pump();
      expect(sel(tester), '1:00');
      await tester.tap(find.byKey(const ValueKey('trimDone')));
      await settle(tester, const Duration(milliseconds: 500));
      final range = results.single!;
      expect(range.durationMs, 60000);
      expect(range.startMs, greaterThan(5000));
      expect(range.endMs, lessThanOrEqualTo(90000));
      noErr(tester);
    });

    testWidgets('kapatinca null; zorunlu degilken ipucu "bolum sec" ve baslangicta tum video', (tester) async {
      final results = await open(tester, total: 20000, mandatory: false);
      expect(sel(tester), '0:20');
      expect(find.textContaining('çok uzun'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trimClose')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(results, [null]);
      noErr(tester);
    });

    testWidgets('onceki aralikla acilir (yeniden duzenleme)', (tester) async {
      await open(tester, initial: const VideoTrimRange(10000, 40000), mandatory: false);
      expect(sel(tester), '0:30');
      noErr(tester);
    });

    testWidgets('erisilebilirlik: tutamaklar kaydirici, artir/azalt 1 sn', (tester) async {
      final sem = tester.ensureSemantics();
      await open(tester);
      final h = tester.getSemantics(find.byKey(const ValueKey('trimHandleEnd')));
      final d = h.getSemanticsData();
      expect(d.label, 'Bitiş');
      expect(d.hasAction(SemanticsAction.increase) && d.hasAction(SemanticsAction.decrease), isTrue);
      h.owner!.performAction(h.id, SemanticsAction.decrease);
      await tester.pump();
      expect(sel(tester), '0:59');
      sem.dispose();
      noErr(tester);
    });
  });

  group('gonderi olustur: video kirpma', () {
    Future<(FakeBackend, _FakeTrim)> openCompose(WidgetTester tester, {int origMs = 90000, bool supported = true, bool fail = false}) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final trim = _FakeTrim(supported: supported, fail: fail);
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        videoService: VideoService(
            limitBytes: PostVideoLimits.maxBytes,
            limitMs: PostVideoLimits.maxDurationMs,
            compressor: _Compressor(origMs: origMs),
            pick: (src) async => const PickedVideo('/orig.mp4')),
        videoUploader: VideoUploader(s, client: b.client),
        trimService: trim,
        trimFrames: _Frames(),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, trim);
    }

    bool shareEnabled(WidgetTester tester) {
      final ink = find.descendant(of: find.byKey(const ValueKey('composeShare')), matching: find.byType(InkWell));
      return tester.widget<InkWell>(ink).onTap != null;
    }

    testWidgets('60 sn den uzun video: kirpma ekrani zorunlu acilir; vazgecilirse paylasim kapali, "Videoyu kirp" ile geri acilir', (tester) async {
      final (_, trim) = await openCompose(tester);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VideoTrimPage), findsOneWidget);
      expect(find.textContaining('çok uzun'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trimClose')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(VideoTrimPage), findsNothing);
      expect(find.byKey(const ValueKey('composeVideoTooLong')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsNothing);
      expect(shareEnabled(tester), isFalse);
      expect(trim.calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('composeTrimCta')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VideoTrimPage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('kirpinca: motor aralikla cagrilir, onizleme + Duzenle gorunur, paylas acilir ve gonderi olusur', (tester) async {
      final (b, trim) = await openCompose(tester);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('trimDone')));
      await settle(tester, const Duration(milliseconds: 1000));
      expect(trim.calls, hasLength(1));
      expect(trim.calls.single.path, '/orig.mp4');
      expect(trim.calls.single.startMs, 0);
      expect(trim.calls.single.endMs, 60000);
      expect(trim.calls.single.maxMs, 60000);
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeVideoEdit')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeVideoTooLong')), findsNothing);
      expect(shareEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(b.count('POST /posts/media'), 1);
      expect((b.bodies['POST /posts'] as Map)['mediaIds'], hasLength(1));
      noErr(tester);
    });

    testWidgets('Duzenle: onceki aralikla yeniden acilir, yeniden keser ve eski gecici dosyayi siler', (tester) async {
      final (_, trim) = await openCompose(tester);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('trimDone')));
      await settle(tester, const Duration(milliseconds: 1000));
      await tester.tap(find.byKey(const ValueKey('composeVideoEdit')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VideoTrimPage), findsOneWidget);
      expect(find.textContaining('çok uzun'), findsNothing, reason: 'duzenleme zorunlu degil');
      await tester.tap(find.byKey(const ValueKey('trimDone')));
      await settle(tester, const Duration(milliseconds: 1000));
      expect(trim.calls, hasLength(2));
      expect(trim.calls.last.path, '/orig.mp4', reason: 'her zaman ozgun dosyadan kesilir');
      expect(trim.discarded, ['/trimmed1.mp4']);
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('kisa video: kirpma ekrani acilmaz ama Duzenle ile istege bagli kirpilabilir; tum video secilirse kesme yok', (tester) async {
      final (_, trim) = await openCompose(tester, origMs: 20000);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VideoTrimPage), findsNothing);
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      expect(shareEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('composeVideoEdit')));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('trimDone'))); // tum video
      await settle(tester, const Duration(milliseconds: 800));
      expect(trim.calls, isEmpty);
      expect(find.byKey(const ValueKey('composeVideoPreview')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('kirpma motoru yoksa (desteklenmeyen platform) uzun video icin net hata, Duzenle gizli', (tester) async {
      await openCompose(tester, supported: false);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(VideoTrimPage), findsNothing);
      expect(find.byKey(const ValueKey('composeVideoTooLong')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeError')), findsOneWidget);
      expect(shareEnabled(tester), isFalse);
      noErr(tester);
    });

    testWidgets('kesme basarisiz: hata satiri, paylasim kapali, tekrar denenebilir', (tester) async {
      final (_, trim) = await openCompose(tester, fail: true);
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('trimDone')));
      await settle(tester, const Duration(milliseconds: 1000));
      expect(trim.calls, hasLength(1));
      expect(find.byKey(const ValueKey('composeError')), findsOneWidget);
      expect(shareEnabled(tester), isFalse);
      expect(find.byKey(const ValueKey('composeVideoTooLong')), findsOneWidget);
      noErr(tester);
    });
  });
}

Object _clock(double sec) {
  final s = sec.round().clamp(0, 5999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
