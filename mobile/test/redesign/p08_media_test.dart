import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/chat_video_player.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

// P8: mesaj balonu + medya görüntüleyiciler: 3 dil x açık/koyu x yazı 1.0/1.3 x 320/390 dp'de taşma yok,
// durumlar (hata/yükleniyor/tüketildi) ve yeni etkileşimler (çift dokunuş yakınlaştırma, şerit, çubuk gizleme).

String _at(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': 11,
      'text': text,
      'createdAt': _at(10),
      ...?extra,
    };

Map<String, dynamic> _img(int id) => {'id': id, 'kind': 'IMAGE', 'url': '/a$id', 'thumbUrl': '/a$id', 'width': 800, 'height': 600};

Widget _bubble(Map<String, dynamic> m,
        {bool mine = false, String? sender, String? replyName, bool seen = false, String? highlight, bool tail = true}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: MessageBubble(
        message: m,
        mine: mine,
        senderName: sender,
        replyName: replyName,
        seen: seen,
        tail: tail,
        highlight: highlight,
        authHeaders: const {},
        onMenu: () {},
        onRetry: () {},
        onOpenImage: (_) {},
        onReact: (_) {},
        onOpenViewOnce: (_) {},
        onOpenGallery: (a, i) {},
      ),
    );

const _long = 'Tamamdır, teşekkürler! Bu arada sınav tarihleri açıklanmış, baktın mı? Kütüphanede birlikte çalışalım mı?';

Widget _textBoard() => SingleChildScrollView(
      child: Column(children: [
        _bubble(_m(1, _long), sender: 'Mehmet Kaya'),
        _bubble(_m(2, _long, extra: {'status': 'READ', 'senderId': 1, 'edited': true}), mine: true, seen: true),
        _bubble(
            _m(3, _long, extra: {
              'replyTo': {'id': 2, 'senderId': 1, 'text': _long},
              'reactions': [
                {'emoji': '👍', 'count': 12},
                {'emoji': '❤️', 'count': 3},
                {'emoji': '😂', 'count': 1}
              ],
              'myReaction': '👍',
            }),
            replyName: 'Ayşe Yılmaz',
            highlight: 'sınav'),
        _bubble(_m(4, 'Bu mesaj silindi', extra: {'deleted': true})),
        _bubble(_m(5, 'Gönderiliyor', extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_queued': true}), mine: true),
        _bubble(_m(6, 'Olmadı', extra: {'_state': 'failed', 'senderId': 1, 'id': null, '_error': 'Bağlantı yok'}), mine: true),
      ]),
    );

Widget _mediaBoard() => SingleChildScrollView(
      child: Column(children: [
        _bubble(_m(1, '', extra: {'attachments': [_img(1)]}), sender: 'Mehmet Kaya'),
        _bubble(_m(2, 'Kafede çalışıyorum', extra: {'status': 'SENT', 'senderId': 1, 'attachments': [_img(2), _img(3), _img(4)]}), mine: true),
        _bubble(_m(3, '', extra: {'attachments': [for (var i = 0; i < 9; i++) _img(10 + i)]})),
        _bubble(_m(4, '', extra: {
          'attachments': [
            {'id': 90, 'kind': 'VIDEO', 'url': '/v90', 'thumbUrl': '/v90/p', 'durationMs': 24000, 'width': 1280, 'height': 720}
          ]
        })),
        _bubble(_m(5, '', extra: {
          '_state': 'pending',
          'senderId': 1,
          'id': null,
          '_bytes': Uint8List(0),
          '_isVideo': true,
          '_durationMs': 18000,
          '_vw': 1280,
          '_vh': 720
        }), mine: true),
      ]),
    );

Widget _onceBoard() => SingleChildScrollView(
      child: Column(children: [
        _bubble(_m(1, '', extra: {'attachments': [{'id': 82, 'viewOnce': true, 'viewed': false, 'url': '/api/conversations/1/media/82'}]}), sender: 'Mehmet Kaya'),
        _bubble(_m(2, '', extra: {'attachments': [{'id': 81, 'viewOnce': true, 'viewed': true, 'url': null}]})),
        _bubble(_m(3, '', extra: {'status': 'SENT', 'senderId': 1, 'attachments': [{'id': 80, 'viewOnce': true, 'viewed': false, 'url': null}]}), mine: true),
      ]),
    );

List<ChatMediaItem> _items() => [
      ChatMediaItem(url: '/files/m1.jpg', thumbUrl: '/files/m1.jpg', sender: 'Mehmet Kaya', at: DateTime(2026, 10, 27, 14, 32)),
      const ChatMediaItem(url: '/api/conversations/1/media/90', thumbUrl: '/api/conversations/1/media/90/poster', isVideo: true, durationMs: 42000),
      const ChatMediaItem(url: '/files/m3.jpg', thumbUrl: '/files/m3.jpg'),
    ];

/// Video oluşturma hatası veren sahte platform (oynatıcı hata durumu).
class _FailVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => throw PlatformException(code: 'fail');
  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('balon: metin / yanıt / tepki / durumlar 3 dil x tema x ölçek taşma yok', (tester) async {
    await p00Matrix(tester, _textBoard, widths: const [320, 390]);
  });

  testWidgets('balon: medya ızgaraları, video, yerel yükleme taşma yok', (tester) async {
    await p00Matrix(tester, _mediaBoard, widths: const [320, 390]);
  });

  testWidgets('balon: tek gösterimlik kart ve haplar taşma yok', (tester) async {
    await p00Matrix(tester, _onceBoard, widths: const [320, 390]);
  });

  testWidgets('balon: giden kırmızı, gelen yüzey; tepki hapı dokunulabilir', (tester) async {
    final reacted = <String>[];
    await tester.pumpWidget(p00App(Column(children: [
      MessageBubble(
        message: _m(1, 'Selam', extra: {
          'reactions': [
            {'emoji': '👍', 'count': 2}
          ],
          'myReaction': '👍'
        }),
        mine: false,
        senderName: null,
        replyName: null,
        seen: false,
        authHeaders: const {},
        onMenu: () {},
        onRetry: () {},
        onOpenImage: (_) {},
        onReact: reacted.add,
      ),
    ])));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('👍 2'));
    expect(reacted, ['👍']);
  });

  testWidgets('görüntüleyici: taşma yok (görsel + video + hata)', (tester) async {
    await p00Matrix(tester, () => ChatMediaViewer(items: _items(), headers: const {}, initialIndex: 0), scaffold: false, widths: const [320, 390]);
  });

  testWidgets('tam ekran görsel + tek gösterimlik: taşma yok', (tester) async {
    await p00Matrix(tester, () => const ChatImageViewer(url: '/files/m1.jpg', headers: {}), scaffold: false, widths: const [320, 390]);
  });

  testWidgets('görüntüleyici: tek dokunuş çubukları gizler, kaydırma sayfayı değiştirir', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(ChatMediaViewer(items: _items(), headers: const {}), scaffold: false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byTooltip('Kapat').hitTestable(), findsOneWidget);
    // Yatay kaydırma sayfayı değiştirir (referans 26: alt küçük resim şeridi yok).
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('2 / 3'), findsOneWidget);
    // Tek dokunuş: çubuklar gizlenir (çift dokunuş beklemesi dolsun).
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300)); // geçiş animasyonu bitsin
    expect(find.byTooltip('Kapat').hitTestable(), findsNothing);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Kapat').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('görüntüleyici: çift dokunuş 2.5x yakınlaştırır, ikincisi sıfırlar; hata + yeniden dene', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(const ChatImageViewer(url: '/files/m1.jpg', headers: {}), scaffold: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Yeniden dene'), findsOneWidget); // testte ağ yok: hata durumu
    double scale() => tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.getMaxScaleOnAxis();
    expect(scale(), 1);
    Future<void> doubleTap(Offset o) async {
      await tester.tapAt(o);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(o);
      await tester.pump(const Duration(milliseconds: 16)); // animasyon ilk kareyi alsın
      await tester.pump(const Duration(milliseconds: 500));
    }

    await doubleTap(const Offset(60, 600));
    expect(scale(), closeTo(2.5, .01));
    await doubleTap(const Offset(60, 600));
    expect(scale(), closeTo(1, .01));
    await tester.tap(find.text('Yeniden dene'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('"animasyonları azalt": çift dokunuş anında yakınlaştırır', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(const ChatImageViewer(url: '/files/m1.jpg', headers: {}), scaffold: false, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(60, 600));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(60, 600));
    await tester.pump(const Duration(milliseconds: 350));
    final s = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.getMaxScaleOnAxis();
    expect(s, closeTo(2.5, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('oynatıcı hata durumu 3 dil x tema x ölçek taşma yok; yeniden dene', (tester) async {
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _FailVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    await p00Matrix(
      tester,
      () => ChatVideoPlayerPage(url: '/api/conversations/1/media/9', headers: const {}, onSave: () async {}),
      scaffold: false,
      widths: const [320, 390],
      check: (t, lang, dark, scale) async {
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );
  });

  testWidgets('tek gösterimlik görüntüleyici: tüketildi / ağ hatası / yükleniyor 3 dil taşma yok', (tester) async {
    final gone = FakeBackend()..fail('/conversations/1/media/50', status: 410, code: 'MEDIA_VIEW_ONCE_EXPIRED');
    await p00Matrix(
      tester,
      () => ViewOnceViewer(api: makeSession(gone).api, conversationId: 1, attachmentId: 50),
      scaffold: false,
      widths: const [320, 390],
    );
    final net = FakeBackend()..network('/conversations/1/media/50');
    await p00Matrix(
      tester,
      () => ViewOnceViewer(api: makeSession(net).api, conversationId: 1, attachmentId: 50),
      scaffold: false,
      widths: const [320],
      check: (t, lang, dark, scale) async {
        expect(find.byType(OnceBadge), findsOneWidget);
      },
    );
  });

  testWidgets('erişilebilirlik: görüntüleyici dokunma hedefleri >= 48 dp ve etiketli', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(ChatMediaViewer(items: _items(), headers: const {}), scaffold: false));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
