import 'dart:async';
import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/permissions/ensure_permission.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/bubble_text_meta.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_media.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

const _mb = 1024 * 1024;

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
      ...?extra,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {'items': items, 'nextCursor': null};

// 1x1 PNG
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Map<String, dynamic> _videoAtt({int id = 60, int durationMs = 42000}) => {
      'id': id,
      'kind': 'VIDEO',
      'url': '/api/conversations/1/media/$id',
      'thumbUrl': '/api/conversations/1/media/$id/poster',
      'durationMs': durationMs,
      'sizeBytes': 5 * _mb,
      'width': 1280,
      'height': 720,
    };

FakeBackend _backend(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', _page(msgs))
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': ['👍']});

class FakeCompressor implements VideoCompressor {
  VideoInfo? infoResult;
  VideoInfo? compressResult;
  Completer<VideoInfo?>? gate;
  bool cancelled = false;
  int compressCalls = 0;

  @override
  Future<VideoInfo?> info(String path) async => infoResult;

  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async {
    compressCalls++;
    onProgress(0.4);
    if (gate != null) return gate!.future;
    return compressResult;
  }

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => _png;

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (gate != null && !gate!.isCompleted) gate!.complete(null);
  }
}

VideoInfo _origBig({int durationMs = 20000}) =>
    VideoInfo(path: '/orig.mp4', sizeBytes: 90 * _mb, durationMs: durationMs, width: 1920, height: 1080);

VideoInfo _compressed({int size = 12 * _mb}) => VideoInfo(
    path: '/c.mp4',
    sizeBytes: size,
    durationMs: 20000,
    width: 1280,
    height: 720,
    bytes: Uint8List.fromList(List.filled(4096, 1)));

VideoService _svc(FakeCompressor c) => VideoService(compressor: c, pick: (s) async => const PickedVideo('/orig.mp4'));

class FakeVideoPlatform extends VideoPlayerPlatform {
  final created = <DataSource>[];
  final disposed = <int>[];
  final seeks = <Duration>[];
  final calls = <String>[];
  bool failCreate = false;
  int _next = 1;
  final _events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (failCreate) throw PlatformException(code: 'fail', message: 'kaynak yok');
    created.add(options.dataSource);
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
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async => seeks.add(position);
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 3);
  @override
  Widget buildView(int playerId) => const SizedBox(key: ValueKey('fakeVideoView'));
}

/// Sunucu yanıtı, istekteki clientId ile eşleşsin (yerel baloncuk sunucu mesajıyla birleşsin).
void _echoClientId(FakeBackend be, Map<String, dynamic> reply) {
  final cid = (be.bodies['POST /conversations/1/messages'] as Map)['clientId'];
  be.on('/conversations/1/messages', {...reply, 'clientId': cid});
}

Future<void> _pump(WidgetTester tester, Widget page, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

ChatDetailPage _detail(
  Session s, {
  ChatRealtime? rt,
  VideoService? video,
  http.Client? upload,
  Future<bool> Function(BuildContext, AppPermission, {String? rationale})? access,
  MediaCameraLauncher? camera,
}) =>
    ChatDetailPage(
      session: s,
      connectRealtime: false,
      realtime: rt,
      videoService: video,
      uploadClient: upload,
      ensureAccess: access ?? (c, p, {rationale}) async => true,
      mediaLibrary: FakeMediaLibrary.photos(2, videos: [FakeMediaLibrary.video('v1', ms: 20000)]),
      openCamera: camera,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

Finder _bubbleOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(MessageBubble)).first;

Color? _iconColor(WidgetTester tester, Finder bubble, IconData icon) {
  final f = find.descendant(of: bubble, matching: find.byIcon(icon));
  expect(f, findsOneWidget, reason: 'ikon $icon');
  return tester.widget<Icon>(f).color;
}

Widget _harness(Map<String, dynamic> m, {bool mine = true, bool rtl = false, Brightness b = Brightness.light, Size size = kPhoneSmall, bool seen = false}) {
  Widget bubble = MessageBubble(
    message: m,
    mine: mine,
    senderName: null,
    replyName: null,
    seen: seen,
    authHeaders: const {},
    onMenu: () {},
    onRetry: () {},
    onOpenImage: (_) {},
    onReact: (_) {},
  );
  if (rtl) bubble = Directionality(textDirection: TextDirection.rtl, child: bubble);
  return buildApp(Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: bubble)), brightness: b, size: size);
}

/// Meta ile metnin gerçek glif kutuları kesişmemeli; meta baloncuğun içinde kalmalı.
/// Dönüş: meta metnin yanında mı (true) altında mı (false).
bool _expectNoOverlap(WidgetTester tester, {required String reason}) {
  final tm = find.byType(BubbleTextMeta);
  final para = tester.renderObject<RenderParagraph>(find.descendant(of: tm, matching: find.byType(RichText)).first);
  final len = para.text.toPlainText().length;
  final boxes = para.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: len));
  final origin = para.localToGlobal(Offset.zero);
  final meta = tester.getRect(find.descendant(of: tm, matching: find.byType(Row)).first);
  final whole = tester.getRect(tm);
  expect(boxes, isNotEmpty);
  var maxBottom = 0.0;
  for (final b in boxes) {
    final r = b.toRect().shift(origin);
    maxBottom = r.bottom > maxBottom ? r.bottom : maxBottom;
    expect(r.deflate(.5).overlaps(meta), isFalse, reason: '$reason: glif $r meta $meta ile cakisti');
  }
  expect(meta.left, greaterThanOrEqualTo(whole.left - .01), reason: reason);
  expect(meta.right, lessThanOrEqualTo(whole.right + .01), reason: reason);
  expect(meta.bottom, lessThanOrEqualTo(whole.bottom + .01), reason: reason);
  expect(meta.top, greaterThanOrEqualTo(whole.top - .01), reason: reason);
  return meta.top < maxBottom - 2;
}

void main() {
  setUpAll(loadTestFonts);

  group('Tikler', () {
    for (final b in Brightness.values) {
      testWidgets('SENT tek tik gri, DELIVERED cift tik gri, READ cift tik kirmizi (${b.name})', (tester) async {
        final tk = b == Brightness.dark ? BuTokens.dark : BuTokens.light;
        final be = _backend([
          _msg(4, 1, 'okundu mesaj', extra: {'status': 'READ'}),
          _msg(3, 1, 'iletildi mesaj', extra: {'status': 'DELIVERED'}),
          _msg(2, 1, 'gonderildi mesaj', extra: {'status': 'SENT'}),
          _msg(1, 11, 'karsi mesaj'),
        ]);
        await _pump(tester, _detail(makeSession(be)), b: b);
        expect(_iconColor(tester, _bubbleOf('gonderildi mesaj'), LucideIcons.check), tk.onPr.withValues(alpha: .75));
        expect(_iconColor(tester, _bubbleOf('iletildi mesaj'), LucideIcons.checkCheck), tk.onPr.withValues(alpha: .75));
        expect(_iconColor(tester, _bubbleOf('okundu mesaj'), LucideIcons.checkCheck), tk.onPr);
        // Karşı tarafın mesajında tik yok.
        expect(find.descendant(of: _bubbleOf('karsi mesaj'), matching: find.byType(Icon)), findsNothing);
        // Giden baloncuk zemini marka kırmızısı (t.pr); gelen t.sf.
        bool hasBg(Finder bubble, Color c) => find
            .descendant(
                of: bubble,
                matching: find.byWidgetPredicate(
                    (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == c))
            .evaluate()
            .isNotEmpty;
        expect(hasBg(_bubbleOf('okundu mesaj'), tk.pr), isTrue);
        expect(hasBg(_bubbleOf('karsi mesaj'), tk.sf), isTrue);
        // Yazılı durum metni yok.
        expect(find.textContaining('görüldü', findRichText: true), findsNothing);
        expect(find.textContaining('Okundu', findRichText: true), findsNothing);
        expect(find.textContaining('Gönderiliyor', findRichText: true), findsNothing);
        _ok(tester);
        await unmount(tester);
      });
    }

    testWidgets('gonderilirken saat ikonu, sunucu cevabindan sonra tek tik', (tester) async {
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..on('/conversations/1/messages', _msg(9, 1, 'Selam', extra: {'status': 'SENT'}));
      await _pump(tester, _detail(makeSession(be)));
      be.delay = const Duration(milliseconds: 500);
      await tester.enterText(find.byType(TextField), 'Selam');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Gönder'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(LucideIcons.clock), findsOneWidget);
      _echoClientId(be, _msg(9, 1, 'Selam', extra: {'status': 'SENT'}));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byIcon(LucideIcons.clock), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('receipt olayi: delivered -> read ilerler, geri gitmez', (tester) async {
      final s = makeSession(_backend([
        _msg(5, 1, 'bes', extra: {'status': 'SENT'}),
        _msg(4, 1, 'dort', extra: {'status': 'SENT'}),
        _msg(1, 11, 'karsi'),
      ]));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
      Map<String, dynamic> ev(String kind, int upTo) =>
          {'type': 'receipt', 'conversationId': 1, 'kind': kind, 'upToMessageId': upTo};

      rt.debugEmitMessageEvent(ev('delivered', 4));
      await settle(tester, const Duration(milliseconds: 400));
      expect(_iconColor(tester, _bubbleOf('dort'), LucideIcons.checkCheck), BuTokens.light.onPr.withValues(alpha: .75));
      expect(find.descendant(of: _bubbleOf('bes'), matching: find.byIcon(LucideIcons.check)), findsOneWidget);

      rt.debugEmitMessageEvent(ev('read', 5));
      await settle(tester, const Duration(milliseconds: 400));
      expect(_iconColor(tester, _bubbleOf('dort'), LucideIcons.checkCheck), BuTokens.light.onPr);
      expect(_iconColor(tester, _bubbleOf('bes'), LucideIcons.checkCheck), BuTokens.light.onPr);

      // Geri gitmez: eski/aşağı durum ve başka sohbet yok sayılır.
      rt.debugEmitMessageEvent(ev('delivered', 5));
      rt.debugEmitMessageEvent({...ev('read', 5), 'conversationId': 2, 'status': 'SENT'});
      rt.debugEmitMessageEvent({...ev('delivered', 5), 'status': 'SENT'});
      await settle(tester, const Duration(milliseconds: 400));
      expect(_iconColor(tester, _bubbleOf('bes'), LucideIcons.checkCheck), BuTokens.light.onPr);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('gecikmis liste yaniti ilerlemis durumu geri almaz', (tester) async {
      final be = _backend([
        _msg(5, 1, 'bes', extra: {'status': 'SENT'}),
        _msg(1, 11, 'karsi'),
      ]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      rt.debugEmitMessageEvent({'type': 'receipt', 'conversationId': 1, 'kind': 'read', 'upToMessageId': 5});
      await settle(tester, const Duration(milliseconds: 300));
      // 20 sn'lik yoklama aynı eski (SENT) sayfayı döndürür.
      await settle(tester, const Duration(seconds: 22));
      expect(_iconColor(tester, _bubbleOf('bes'), LucideIcons.checkCheck), BuTokens.light.onPr);
      await unmount(tester);
    });

    testWidgets('iletildi ack: 1 sn debounce, yalniz en yuksek id ilerleyince', (tester) async {
      final be = _backend([_msg(10, 11, 'karsi'), _msg(9, 1, 'ben')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(be.count('POST /conversations/1/delivered'), 0); // 1 sn dolmadi
      await settle(tester, const Duration(milliseconds: 1200));
      expect(be.count('POST /conversations/1/delivered'), 1);
      expect((be.bodies['POST /conversations/1/delivered'] as Map)['lastMessageId'], 10);

      // Yeni mesaj yok -> yoklamalar yeni ack üretmez.
      await settle(tester, const Duration(seconds: 6));
      expect(be.count('POST /conversations/1/delivered'), 1);

      // Hızlı iki mesaj tek ack olur (en yükseği).
      rt.debugEmitMessage(_msg(11, 11, 'on bir'));
      await tester.pump(const Duration(milliseconds: 200));
      rt.debugEmitMessage(_msg(12, 11, 'on iki'));
      await settle(tester, const Duration(milliseconds: 1500));
      expect(be.count('POST /conversations/1/delivered'), 2);
      expect((be.bodies['POST /conversations/1/delivered'] as Map)['lastMessageId'], 12);

      // Kendi mesajım ack tetiklemez.
      rt.debugEmitMessage(_msg(13, 1, 'ben yine'));
      await settle(tester, const Duration(milliseconds: 1500));
      expect(be.count('POST /conversations/1/delivered'), 2);
      await unmount(tester);
    });

    test('ReceiptEvent: durum yoksa turden turetilir', () {
      expect(ReceiptEvent(1, 'delivered', 3, null).effectiveStatus, 'DELIVERED');
      expect(ReceiptEvent(1, 'read', 3, null).effectiveStatus, 'READ');
      expect(ReceiptEvent(1, 'read', 3, 'DELIVERED').effectiveStatus, 'DELIVERED');
    });
  });

  group('Saat ve metin cakismasi', () {
    Map<String, dynamic> mine(String text, {String status = 'READ'}) => _msg(5, 1, text, extra: {'status': status});

    testWidgets('kisa mesaj: saat metnin yaninda (ayni satir)', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_harness(mine('Selam')));
      await tester.pump();
      expect(_expectNoOverlap(tester, reason: 'kisa'), isTrue); // yan yana
      _ok(tester);
    });

    testWidgets('son satir doluysa meta alt satira iner', (tester) async {
      useScreen(tester, kPhoneSmall);
      // 320 dp: metin alani ~221 dp. Son satırı neredeyse dolduran uzun kelimeler.
      await tester.pumpWidget(_harness(mine('${'a' * 31} ${'b' * 29}')));
      await tester.pump();
      _expectNoOverlap(tester, reason: 'dolu son satir');
      _ok(tester);
    });

    for (final rtl in [false, true]) {
      for (final b in Brightness.values) {
        testWidgets('tarama 320 dp ${rtl ? 'RTL' : 'LTR'} ${b.name}: hicbir uzunlukta cakisma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          var inline = 0, wrapped = 0;
          const ltrWords = ['merhaba', 'kampüs', 'ab', 'selam', 'toplantı'];
          const arWords = ['مرحبا', 'بكم', 'في', 'جامعة', 'بينغول'];
          final words = rtl ? arWords : ltrWords;
          for (var n = 1; n <= 36; n += 1) {
            final text = List.generate(n, (i) => words[i % words.length]).join(' ');
            await tester.pumpWidget(_harness(mine(text, status: n.isEven ? 'DELIVERED' : 'READ'), rtl: rtl, b: b));
            await tester.pump();
            final side = _expectNoOverlap(tester, reason: 'n=$n');
            side ? wrapped++ : inline++;
          }
          for (var k = 5; k <= 70; k += 5) {
            await tester.pumpWidget(_harness(mine('x' * k), rtl: rtl, b: b));
            await tester.pump();
            _expectNoOverlap(tester, reason: 'x*$k');
          }
          expect(inline, greaterThan(0));
          expect(wrapped, greaterThan(0));
          _ok(tester);
        });
      }
    }

    testWidgets('gelen mesaj, duzenlendi etiketi ve pending saat ikonu ile de cakisma yok (390 dp)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final m = _msg(5, 11, 'Bu mesaj biraz daha uzun bir metin ve düzenlenmiş olarak işaretli', extra: {'edited': true});
      await tester.pumpWidget(_harness(m, mine: false, size: kPhoneMedium));
      await tester.pump();
      _expectNoOverlap(tester, reason: 'gelen');
      final p = {..._msg(6, 1, 'Gönderiliyor kısa'), '_state': 'pending', 'id': null};
      await tester.pumpWidget(_harness(p, size: kPhoneMedium));
      await tester.pump();
      _expectNoOverlap(tester, reason: 'pending');
      expect(find.byIcon(LucideIcons.clock), findsOneWidget);
      _ok(tester);
    });

    testWidgets('durum degisince ikon gecis animasyonu biter, tek ikon kalir', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_harness(mine('Selam', status: 'SENT')));
      await tester.pump();
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      await tester.pumpWidget(_harness(mine('Selam', status: 'READ')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });
  });

  group('Video: hazirlama kurallari', () {
    test('60 sn ustu reddedilir', () async {
      final c = FakeCompressor()..infoResult = _origBig(durationMs: 75000);
      await expectLater(
          _svc(c).prepare(const PickedVideo('/orig.mp4')), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'TOO_LONG')));
      expect(c.compressCalls, 0);
    });

    test('sikistirma sonrasi 40 MB ustu reddedilir', () async {
      final c = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed(size: 41 * _mb);
      await expectLater(
          _svc(c).prepare(const PickedVideo('/orig.mp4')), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'TOO_LARGE')));
    });

    test('sikistirma basarisizsa ozgun uygunsa o kullanilir, degilse reddedilir', () async {
      final ok = FakeCompressor()
        ..infoResult = const VideoInfo(path: '/o.mp4', sizeBytes: 30 * _mb, durationMs: 30000, width: 1920, height: 1080);
      final v = await _svc(ok).prepare(const PickedVideo('/o.mp4'));
      expect(v.path, '/o.mp4');
      final big = FakeCompressor()..infoResult = _origBig();
      await expectLater(
          _svc(big).prepare(const PickedVideo('/orig.mp4')), throwsA(isA<VideoException>().having((e) => e.code, 'code', 'TOO_LARGE')));
    });

    test('kucuk ve <=1280 px video yeniden kodlanmaz; poster alinir', () async {
      final c = FakeCompressor()
        ..infoResult = const VideoInfo(path: '/s.mp4', sizeBytes: 3 * _mb, durationMs: 9000, width: 1280, height: 720);
      final v = await _svc(c).prepare(const PickedVideo('/s.mp4'));
      expect(c.compressCalls, 0);
      expect(v.poster, isNotNull);
      expect(v.durationMs, 9000);
    });

    test('sikistirma ilerlemeyi bildirir ve 1.0 ile biter; orijinal 720p kaliteyi korur', () async {
      final c = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed();
      final seen = <double>[];
      final v = await _svc(c).prepare(const PickedVideo('/orig.mp4'), onProgress: seen.add);
      expect(seen.first, 0.4);
      expect(seen.last, 1.0);
      expect(v.path, '/c.mp4');
      expect(v.width, 1280);
    });

    test('iptal: CANCELLED', () async {
      final c = FakeCompressor()
        ..infoResult = _origBig()
        ..gate = Completer<VideoInfo?>();
      final cancel = VideoCancel();
      final f = _svc(c).prepare(const PickedVideo('/orig.mp4'), cancel: cancel);
      final check = expectLater(f, throwsA(isA<VideoException>().having((e) => e.code, 'code', 'CANCELLED')));
      await Future<void>.delayed(Duration.zero);
      await cancel.cancel();
      await check;
      expect(c.cancelled, isTrue);
    });

    test('yukleme: file(video/mp4) + poster(image/jpeg) govdesi ve ilerleme', () async {
      final seenReq = <String>[];
      final client = MockClient((req) async {
        final body = latin1.decode(req.bodyBytes);
        seenReq.add(body);
        return http.Response('{"id":88}', 200, headers: {'content-type': 'application/json'});
      });
      final s = makeSession(FakeBackend());
      final up = VideoUploader(s, client: client);
      final progress = <double>[];
      final res = await up.upload(
        '/conversations/1/media',
        PreparedVideo(bytes: Uint8List.fromList(List.filled(100000, 7)), sizeBytes: 100000, durationMs: 1000, poster: _png),
        onProgress: progress.add,
      ) as Map;
      expect(res['id'], 88);
      final body = seenReq.single;
      expect(body, contains('name="file"'));
      expect(body, contains('filename="video.mp4"'));
      expect(body.toLowerCase(), contains('content-type: video/mp4'));
      expect(body, contains('name="poster"'));
      expect(body, contains('filename="poster.jpg"'));
      expect(body.toLowerCase(), contains('content-type: image/jpeg'));
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    });

    test('yukleme: sunucu hata kodlari ApiError olur (413 VIDEO_TOO_LARGE)', () async {
      final client = MockClient((req) async => http.Response(
          jsonEncode({'code': 'VIDEO_TOO_LARGE', 'message': 'Video en fazla 40 MB olabilir.'}), 413,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      final up = VideoUploader(makeSession(FakeBackend()), client: client);
      await expectLater(
          up.upload('/conversations/1/media', PreparedVideo(bytes: Uint8List(10), sizeBytes: 10, durationMs: 1)),
          throwsA(isA<ApiError>().having((e) => e.code, 'code', 'VIDEO_TOO_LARGE').having((e) => e.status, 'status', 413)));
    });
  });

  group('Video: sohbet akisi', () {
    /// Ek düğmesi -> galeri -> videoyu seç -> "Gönder".
    Future<void> openVideoSheet(WidgetTester tester, [String? _]) async {
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('galleryTile_v1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pickerSend')));
      await tester.pump();
    }

    testWidgets('ek dugmesi dogrudan galeriyi acar; galeriden video: hazirla, yukle (poster+video), attachmentIds ile gonder', (tester) async {
      final comp = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed();
      final captured = <String>[];
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        captured.add('${req.method} ${req.url.path} ${latin1.decode(req.bodyBytes)}');
        return http.Response('{"id":88}', 200, headers: {'content-type': 'application/json'});
      });
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..on('/conversations/1/messages', _msg(9, 1, '', extra: {'status': 'SENT', 'attachments': [_videoAtt(id: 88, durationMs: 20000)]}));
      await _pump(tester, _detail(makeSession(be), video: _svc(comp), upload: client));
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      for (final l in ['Galeriden seç', 'Fotoğraf çek', 'Galeriden video seç', 'Video çek']) {
        expect(find.text(l), findsNothing); // eski 4'lü menü yok, doğrudan galeri
      }
      expect(find.text('Galeri'), findsOneWidget);
      be.delay = const Duration(milliseconds: 500);
      await tester.tap(find.byKey(const ValueKey('galleryTile_v1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pickerSend')));
      await settle(tester, const Duration(milliseconds: 800)); // seçici kapanır, yükleme başlar
      // Yerel baloncuk: poster + dairesel ilerleme + süre hapı (yükleme sürerken).
      expect(find.byKey(const ValueKey('uploadProgress')), findsOneWidget);
      expect(find.text('0:20'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      _echoClientId(be, _msg(9, 1, '', extra: {'status': 'SENT', 'attachments': [_videoAtt(id: 88, durationMs: 20000)]}));
      await settle(tester, const Duration(seconds: 2));
      final req = captured.single;
      expect(req, startsWith('POST /api/conversations/1/media'));
      expect(req, contains('filename="video.mp4"'));
      expect(req, contains('name="poster"'));
      final body = be.bodies['POST /conversations/1/messages'] as Map;
      expect(body['attachmentIds'], [88]);
      expect(body.containsKey('viewOnce'), isFalse);
      // Sunucu mesajı: oynat rozeti + süre hapı, tek tik.
      expect(find.byType(PlayBadge), findsOneWidget);
      expect(find.text('0:20'), findsOneWidget);
      expect(find.byKey(const ValueKey('uploadProgress')), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('60 sn ustu video: uyari, yukleme yok', (tester) async {
      final comp = FakeCompressor()..infoResult = _origBig(durationMs: 90000);
      final be = _backend([_msg(1, 11, 'Merhaba')]);
      await _pump(tester, _detail(makeSession(be), video: _svc(comp), upload: be.client));
      await openVideoSheet(tester, 'Galeriden video seç');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Video en fazla 60 saniye olabilir'), findsOneWidget);
      expect(be.count('POST /conversations/1/media'), 0);
      expect(find.byKey(const ValueKey('videoPrepare')), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('40 MB ustu: uyari, yukleme yok', (tester) async {
      final comp = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed(size: 45 * _mb);
      final be = _backend([_msg(1, 11, 'Merhaba')]);
      await _pump(tester, _detail(makeSession(be), video: _svc(comp), upload: be.client));
      await openVideoSheet(tester, 'Galeriden video seç');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Video çok büyük, daha kısa bir video seçin'), findsOneWidget);
      expect(be.count('POST /conversations/1/media'), 0);
      await unmount(tester);
    });

    testWidgets('hazirlama penceresi yuzde gosterir, Iptal sikistirmayi durdurur', (tester) async {
      final comp = FakeCompressor()
        ..infoResult = _origBig()
        ..gate = Completer<VideoInfo?>();
      final be = _backend([_msg(1, 11, 'Merhaba')]);
      await _pump(tester, _detail(makeSession(be), video: _svc(comp), upload: be.client));
      await openVideoSheet(tester, 'Galeriden video seç');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('videoPrepare')), findsOneWidget);
      expect(find.text('Video hazırlanıyor… %40'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(comp.cancelled, isTrue);
      expect(find.byKey(const ValueKey('videoPrepare')), findsNothing);
      expect(be.count('POST /conversations/1/media'), 0);
      expect(find.byType(SnackBar), findsNothing); // iptal hata değildir
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('kamera kisayolu: video cek -> onizleme (tek gonderimlik dugmesi yok) -> yukle', (tester) async {
      final comp = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed();
      final client = MockClient((req) async =>
          http.Response('{"id":90}', 200, headers: {'content-type': 'application/json'}));
      var opened = 0;
      final be = _backend([_msg(1, 11, 'Merhaba')])
        ..on('/conversations/1/messages', _msg(9, 1, '', extra: {'status': 'SENT', 'attachments': [_videoAtt(id: 90, durationMs: 20000)]}));
      await _pump(
        tester,
        _detail(makeSession(be), video: _svc(comp), upload: client, camera: (c) async {
          opened++;
          return fakeVideoPick('cam1');
        }),
      );
      await tester.tap(find.byKey(const ValueKey('cameraShortcut')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(opened, 1);
      expect(find.byKey(const ValueKey('onceButton_0')), findsNothing); // videoda tek gönderimlik yok
      expect(find.text('1/1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(seconds: 2));
      final body = be.bodies['POST /conversations/1/messages'] as Map;
      expect(body['attachmentIds'], [90]);
      expect(body.containsKey('viewOnce'), isFalse);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('yukleme basarisiz: Yeniden dene gorunur (413 VIDEO_TOO_LARGE sunucu metni)', (tester) async {
      final comp = FakeCompressor()
        ..infoResult = _origBig()
        ..compressResult = _compressed();
      final client = MockClient((req) async => http.Response(
          jsonEncode({'code': 'VIDEO_TOO_LARGE', 'message': 'Video en fazla 40 MB olabilir.'}), 413,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      final be = _backend([_msg(1, 11, 'Merhaba')]);
      await _pump(tester, _detail(makeSession(be), video: _svc(comp), upload: client));
      await openVideoSheet(tester, 'Galeriden video seç');
      await settle(tester, const Duration(seconds: 1));
      expect(find.textContaining('Video en fazla 40 MB olabilir.'), findsOneWidget);
      expect(find.textContaining('Yeniden dene'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });
  });

  group('Video: baloncuk ve oynatici', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform previous;

    setUp(() {
      previous = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });
    tearDown(() => VideoPlayerPlatform.instance = previous);

    testWidgets('baloncuk: oynat ikonu + sure hapi + saat/tik pill (metinsiz video)', (tester) async {
      final be = _backend([
        _msg(2, 1, '', extra: {'status': 'READ', 'attachments': [_videoAtt()]}),
        _msg(1, 11, ''),
      ]);
      await _pump(tester, _detail(makeSession(be)));
      expect(find.byType(PlayBadge), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
      // Saat/tik görselin sağ altında: okundu tiki beyaz.
      final tick = tester.widget<Icon>(find.byIcon(LucideIcons.checkCheck));
      expect(tick.color, Colors.white);
      final pill = tester.getRect(find.byType(PlayBadge));
      final tickRect = tester.getRect(find.byIcon(LucideIcons.checkCheck));
      final dur = tester.getRect(find.text('0:42'));
      expect(dur.left, lessThan(tickRect.left)); // süre solda, tik sağda
      expect(dur.overlaps(tickRect), isFalse);
      expect(pill.overlaps(tickRect), isFalse);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('baloncuga dokununca oynatici: Authorization basligi, otomatik oynat, dokun duraklat, kapat dispose', (tester) async {
      final be = _backend([
        _msg(2, 11, '', extra: {'attachments': [_videoAtt()]}),
      ]);
      final s = makeSession(be)..api.tokens = Tokens('acc', 'ref');
      await _pump(tester, _detail(s));
      await tester.tap(find.byType(PlayBadge));
      await settle(tester, const Duration(milliseconds: 600));
      expect(platform.created, hasLength(1));
      expect(platform.created.single.uri, endsWith('/api/conversations/1/media/60'));
      expect(platform.created.single.httpHeaders['Authorization'], 'Bearer acc');
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(find.byKey(const ValueKey('videoSeek')), findsOneWidget);
      expect(find.text('0:42'), findsWidgets); // toplam süre etiketi
      expect(platform.calls.last, 'play'); // otomatik oynat
      // Oynarken oynat ikonu yok; dokununca duraklar ve ikon çıkar.
      expect(find.byKey(const ValueKey('videoPlayIcon')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('videoStage')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(platform.calls.last, 'pause');
      expect(find.byKey(const ValueKey('videoPlayIcon')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('videoStage')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(platform.calls.last, 'play');
      // İlerleme çubuğu sürüklenince sarar.
      await tester.drag(find.byKey(const ValueKey('videoSeek')), const Offset(60, 0));
      await settle(tester, const Duration(milliseconds: 300));
      expect(platform.seeks, isNotEmpty);
      // Kapat: denetleyici dispose edilir.
      await tester.tap(find.byTooltip('Kapat'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(platform.disposed, [1]);
      expect(find.byType(VideoPlayer), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('oynatici hata: Video oynatilamadi + Yeniden dene', (tester) async {
      platform.failCreate = true;
      final be = _backend([
        _msg(2, 11, '', extra: {'attachments': [_videoAtt()]}),
      ]);
      await _pump(tester, _detail(makeSession(be)));
      await tester.tap(find.byType(PlayBadge));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Video oynatılamadı'), findsOneWidget);
      platform.failCreate = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Video oynatılamadı'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat'));
      await settle(tester, const Duration(milliseconds: 500));
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('galeri gorunumunde video ogesi: poster + oynat; dokununca oynatici', (tester) async {
      final items = [
        ChatMediaItem.tryFromAttachment(_videoAtt())!,
        ChatMediaItem.tryFromAttachment({'id': 1, 'kind': 'IMAGE', 'url': '/a', 'thumbUrl': '/a'})!,
      ];
      expect(items.first.isVideo, isTrue);
      expect(items.first.durationMs, 42000);
      expect(items.first.thumbUrl, endsWith('/poster'));
      expect(items.last.isVideo, isFalse);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatMediaViewer(items: items, headers: const {})));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('viewerVideoPage')), findsOneWidget);
      expect(find.byType(PlayBadge), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('viewerVideoPage')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(VideoPlayer), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat').last);
      await settle(tester, const Duration(milliseconds: 500));
      await unmount(tester);
    });

    test('galleryAttachments videoyu listeler; tek gosterimlik hala hic', () {
      final m = {
        'attachments': [
          _videoAtt(),
          {'id': 2, 'url': '/b', 'viewOnce': true},
          {'id': 3, 'kind': 'IMAGE', 'url': '/c'},
        ],
      };
      final g = galleryAttachments(m);
      expect(g.map((a) => a['id']), [60, 3]);
      expect(isVideoAttachment(g.first), isTrue);
      expect(isVideoAttachment(g.last), isFalse);
    });

    test('attachmentPreviewLabel', () {
      expect(attachmentPreviewLabel({'attachments': [_videoAtt()]}), 'Video');
      expect(attachmentPreviewLabel({'attachments': [{'id': 1, 'kind': 'IMAGE'}]}), 'Fotoğraf');
      expect(attachmentPreviewLabel({'attachments': [{'id': 1, 'viewOnce': true}]}), 'Fotoğraf (tek gösterimlik)');
      expect(attachmentPreviewLabel({'text': 'x'}), '');
      expect(formatMediaDuration(42000), '0:42');
      expect(formatMediaDuration(65000), '1:05');
      expect(formatMediaDuration(3725000), '1:02:05');
    });
  });

  group('Tasma matrisi', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('${size.width.toInt()} dp ${b.name}: karisik mesajlarda tasma yok', (tester) async {
          final be = _backend([
            _msg(9, 1, 'Çok uzun bir giden mesaj: ${'kelime ' * 18}', extra: {'status': 'READ'}),
            _msg(8, 1, '', extra: {'status': 'DELIVERED', 'attachments': [_videoAtt()]}),
            _msg(7, 11, 'Altyazılı video', extra: {'attachments': [_videoAtt(id: 61, durationMs: 3725000)]}),
            _msg(6, 1, 'Kısa', extra: {'status': 'SENT'}),
            _msg(5, 11, 'مرحبا بكم في جامعة بينغول وهذا نص أطول قليلا من المعتاد'),
            _msg(4, 1, '', extra: {
              'status': 'READ',
              'attachments': [
                {'id': 70, 'kind': 'IMAGE', 'url': '/a', 'thumbUrl': '/a', 'width': 800, 'height': 600},
                {'id': 71, 'kind': 'IMAGE', 'url': '/b', 'thumbUrl': '/b', 'width': 600, 'height': 800},
                _videoAtt(id: 72),
              ]
            }),
            _msg(3, 1, '', extra: {
              'status': 'SENT',
              'attachments': [
                {'id': 80, 'viewOnce': true, 'viewed': false, 'url': null}
              ]
            }),
            _msg(2, 1, 'Yanıt', extra: {
              'status': 'READ',
              'edited': true,
              'replyTo': {'id': 1, 'senderId': 11, 'text': 'Alıntılanan uzun mesaj ${'x' * 40}'}
            }),
            _msg(1, 11, 'Merhaba'),
          ]);
          await _pump(tester, _detail(makeSession(be)), b: b, size: size);
          expect(find.text('Kısa'), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });
}
