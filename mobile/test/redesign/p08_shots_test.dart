@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/chat_video_player.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// P8 ekran goruntuleri: mesaj balonu + medya goruntuleyiciler (gorsel, video, tek gosterimlik, tam ekran gorsel).
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_mobile, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p08/sonraki' flutter test test/redesign/p08_shots_test.dart
/// Istege bagli: `P08_LANG=tr|ar` (varsayilan tr; Arapca icin Windows Arial yuklenir), `P08_ONLY=01,05`,
/// `P08_MODES=light,dark,x13`.
const _dpr = 2.5;

String _lang = 'tr';
String s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

enum _Img { ok, hang, err }

class _Board {
  const _Board(this.file, this.build, {this.height = 844, this.img = _Img.ok, this.after, this.settleMs = 1000, this.drainMs = 0, this.video = _Vid.ok});
  final String file;
  final Widget Function() build;
  final double height;
  final _Img img;
  final Future<void> Function(WidgetTester t)? after;
  final int settleMs;
  final int drainMs;
  final _Vid video;
}

enum _Vid { ok, hang, fail }

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

// ---------------------------------------------------------------------------------------------------------------
// Ag gorseli sahteleri

class _HangClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Completer<HttpClientRequest>().future;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Completer<HttpClientRequest>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ErrClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => throw const SocketException('yok');
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => throw const SocketException('yok');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------------------------------------------
// Sahte video platformu: kare olarak uretilmis sahne gosterir

class _FakeVideoPlatform extends VideoPlayerPlatform {
  _FakeVideoPlatform(this.mode);
  final _Vid mode;
  int _next = 1;
  final _events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (mode == _Vid.fail) throw PlatformException(code: 'fail', message: 'kaynak yok');
    if (mode == _Vid.hang) return Completer<int?>().future;
    final id = _next++;
    final sc = StreamController<VideoEvent>();
    sc.add(VideoEvent(eventType: VideoEventType.initialized, duration: const Duration(seconds: 42), size: const Size(1280, 720)));
    _events[id] = sc;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async => _events[playerId]?.close();
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 14);
  @override
  Widget buildView(int playerId) => Image.memory(storeImageBytes(1), fit: BoxFit.cover, gaplessPlayback: true);
}

// ---------------------------------------------------------------------------------------------------------------
// Uygulama sarmalayici

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

// ---------------------------------------------------------------------------------------------------------------
// Mesaj verisi

String _at(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, String text, {Map<String, dynamic>? extra, int ago = 30}) => {
      'id': id,
      'conversationId': 1,
      'senderId': 11,
      'text': text,
      'createdAt': _at(ago),
      ...?extra,
    };

Map<String, dynamic> _img(int id, {int w = 800, int h = 600}) =>
    {'id': id, 'kind': 'IMAGE', 'url': '/a$id', 'thumbUrl': '/a$id', 'width': w, 'height': h};

Map<String, dynamic> _vid(int id) => {
      'id': id,
      'kind': 'VIDEO',
      'url': '/api/conversations/1/media/$id',
      'thumbUrl': '/api/conversations/1/media/$id/poster$id',
      'durationMs': 24000,
      'width': 1280,
      'height': 720,
    };

Widget _bubble(
  Map<String, dynamic> m, {
  bool mine = false,
  String? sender,
  String? replyName,
  bool replyMine = false,
  bool seen = false,
  bool tail = true,
  String? highlight,
}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: MessageBubble(
        message: m,
        mine: mine,
        senderName: sender,
        replyName: replyName,
        replyMine: replyMine,
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

class _Chat extends StatelessWidget {
  const _Chat(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 44, bottom: 20),
        children: children,
      ),
    );
  }
}

Widget _boardText() => _Chat([
      _bubble(_m(1, s('Selam! Yarınki ders kaçta başlıyor?', 'Hi! What time does tomorrow\'s class start?', 'مرحبا! متى يبدأ درس الغد؟'), ago: 50), sender: s('Mehmet Kaya', 'Mehmet Kaya', 'محمد كايا')),
      _bubble(_m(2, s('Saat 10.00\'da, B-204 dersliğinde.', 'At 10.00, in room B-204.', 'الساعة 10.00 في القاعة B-204.'), extra: {'status': 'READ', 'senderId': 1}, ago: 48), mine: true, seen: true, tail: false),
      _bubble(_m(3, s('Not defterini getirmeyi unutma 😄', 'Don\'t forget your notebook 😄', 'لا تنس دفتر ملاحظاتك 😄'), extra: {'status': 'DELIVERED', 'senderId': 1}, ago: 47), mine: true),
      _bubble(
          _m(4, s('Tamamdır, teşekkürler! Bu arada sınav tarihleri açıklanmış, baktın mı?', 'Great, thanks! By the way, the exam dates are out, have you seen them?', 'تمام، شكرا! بالمناسبة تم الإعلان عن مواعيد الامتحانات، هل رأيتها؟'),
              extra: {
                'replyTo': {'id': 3, 'senderId': 1, 'text': s('Not defterini getirmeyi unutma 😄', 'Don\'t forget your notebook 😄', 'لا تنس دفتر ملاحظاتك 😄')},
                'reactions': [
                  {'emoji': '👍', 'count': 2},
                  {'emoji': '❤️', 'count': 1}
                ],
                'myReaction': '👍',
              },
              ago: 40),
          replyName: s('Ayşe Yılmaz', 'Ayşe Yılmaz', 'عائشة يلماز'),
          replyMine: true),
      const SizedBox(height: 8),
      _bubble(_m(5, s('Evet, ilk sınav 12 Aralık\'ta. Kütüphanede birlikte çalışalım mı?', 'Yes, the first exam is on December 12. Shall we study together at the library?', 'نعم، أول امتحان في 12 كانون الأول. هل ندرس معا في المكتبة؟'), extra: {'status': 'SENT', 'senderId': 1, 'edited': true}, ago: 30), mine: true),
      _bubble(_m(6, s('Bu mesaj silindi', 'This message was deleted', 'تم حذف هذه الرسالة'), extra: {'deleted': true}, ago: 20)),
      _bubble(_m(7, s('Gönderiliyor...', 'Sending...', 'جار الإرسال...'), extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_queued': true}, ago: 1), mine: true),
      _bubble(_m(8, s('Ulaşmadı mı?', 'Did it fail?', 'هل فشل؟'), extra: {'_state': 'failed', 'senderId': 1, 'id': null, '_error': s('Bağlantı yok', 'No connection', 'لا يوجد اتصال')}, ago: 1), mine: true),
      _bubble(_m(9, s('Kütüphane saatleri uzatıldı, sınav haftası boyunca 24 saat açık.', 'Library hours extended, open 24 hours during exam week.', 'تم تمديد ساعات المكتبة، مفتوحة 24 ساعة في أسبوع الامتحانات.'), ago: 5), highlight: s('kütüphane', 'library', 'المكتبة')),
    ]);

Widget _boardMedia() => _Chat([
      _bubble(_m(1, '', extra: {'attachments': [_img(1, w: 800, h: 600)]}, ago: 60), sender: s('Mehmet Kaya', 'Mehmet Kaya', 'محمد كايا')),
      _bubble(_m(2, s('Kafede çalışıyorum ☕', 'Studying at the cafe ☕', 'أدرس في المقهى ☕'), extra: {'status': 'READ', 'senderId': 1, 'attachments': [_img(2, w: 600, h: 800)]}, ago: 55), mine: true, seen: true),
      _bubble(_m(3, '', extra: {'attachments': [_img(3), _img(4)]}, ago: 40)),
      _bubble(_m(4, '', extra: {'status': 'DELIVERED', 'senderId': 1, 'attachments': [_img(5), _img(6), _img(7)]}, ago: 35), mine: true),
      _bubble(_m(5, '', extra: {'attachments': [for (var i = 0; i < 9; i++) _img(10 + i)]}, ago: 20)),
      _bubble(_m(6, '', extra: {'attachments': [_vid(90)], 'status': 'SENT'}, ago: 10)),
      _bubble(_m(7, s('Etkinlikten kısa bir video', 'A short clip from the event', 'مقطع قصير من الفعالية'), extra: {'status': 'READ', 'senderId': 1, 'attachments': [_vid(91)]}, ago: 5), mine: true, seen: true),
    ]);

Widget _boardLocal() {
  final bytes = storeImageBytes(2);
  final progress = ValueNotifier<double>(.46);
  return _Chat([
    _bubble(_m(1, '', extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_bytes': bytes, '_progress': progress}, ago: 1), mine: true),
    _bubble(_m(2, '', extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_bytes': bytes, '_isVideo': true, '_durationMs': 18000, '_vw': 1280, '_vh': 720}, ago: 1), mine: true),
    _bubble(
        _m(3, '', extra: {
          '_state': 'pending',
          'senderId': 1,
          'id': null,
          '_localItems': [
            for (var i = 0; i < 5; i++) {'bytes': storeImageBytes(i), 'video': i == 1, 'durationMs': 1000}
          ]
        }, ago: 1),
        mine: true),
  ]);
}

Widget _boardOnce() => _Chat([
      _bubble(_m(1, '', extra: {'attachments': [{'id': 82, 'viewOnce': true, 'viewed': false, 'url': '/api/conversations/1/media/82'}]}, ago: 20), sender: s('Mehmet Kaya', 'Mehmet Kaya', 'محمد كايا')),
      _bubble(_m(2, '', extra: {'attachments': [{'id': 81, 'viewOnce': true, 'viewed': true, 'url': null}]}, ago: 18)),
      _bubble(_m(3, '', extra: {'status': 'SENT', 'senderId': 1, 'attachments': [{'id': 80, 'viewOnce': true, 'viewed': false, 'url': null}]}, ago: 10), mine: true),
      _bubble(_m(4, '', extra: {'status': 'READ', 'senderId': 1, 'attachments': [{'id': 83, 'viewOnce': true, 'viewed': true, 'url': null}]}, ago: 8), mine: true, seen: true),
      _bubble(_m(5, '', extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_viewOnce': true}, ago: 1), mine: true),
      _bubble(_m(6, 'Bu mesaj kaldırıldı', extra: {'removed': true}, ago: 1)),
    ]);

// ---------------------------------------------------------------------------------------------------------------
// Goruntuleyiciler

List<ChatMediaItem> _items() => [
      ChatMediaItem(url: '/files/m1.jpg', thumbUrl: '/files/m1.jpg', sender: 'Mehmet Kaya', at: DateTime(2026, 10, 27, 14, 32)),
      ChatMediaItem(url: '/files/m2.jpg', thumbUrl: '/files/m2.jpg', sender: s('Ben', 'Me', 'أنا'), at: DateTime(2026, 10, 27, 14, 40)),
      ChatMediaItem(url: '/files/m3.jpg', thumbUrl: '/files/m3.jpg', sender: 'Mehmet Kaya', at: DateTime(2026, 10, 28, 9, 5)),
      const ChatMediaItem(url: '/files/m4.jpg', thumbUrl: '/files/m4.jpg'),
    ];

Widget _viewer({int index = 1, bool videoFirst = false}) => ChatMediaViewer(
      items: videoFirst
          ? [
              const ChatMediaItem(url: '/api/conversations/1/media/90', thumbUrl: '/api/conversations/1/media/90/poster3', isVideo: true, durationMs: 42000, sender: 'Mehmet Kaya'),
              ..._items(),
            ]
          : _items(),
      headers: const {},
      initialIndex: index,
      saveImage: (u, h) async {},
      saveVideo: (u, h) async {},
    );

Widget _player() => ChatVideoPlayerPage(
      url: '/api/conversations/1/media/90',
      headers: const {},
      durationMs: 42000,
      onSave: () async {},
    );

FakeBackend _onceBackend({int status = 200, bool network = false, Duration delay = Duration.zero}) {
  final be = FakeBackend(delay: delay);
  if (network) {
    be.network('/conversations/1/media/50');
  } else if (status == 200) {
    be.onBytes('/conversations/1/media/50', storeImageBytes(5));
  } else {
    be.fail('/conversations/1/media/50', status: status, code: status == 410 ? 'MEDIA_VIEW_ONCE_EXPIRED' : 'MEDIA_VIEW_ONCE_OWN');
  }
  return be;
}

Widget _once(FakeBackend be) => ViewOnceViewer(api: makeSession(be).api, conversationId: 1, attachmentId: 50);

final _boards = <_Board>[
  const _Board('01_balon_metin', _boardText, height: 920),
  const _Board('02_balon_medya', _boardMedia, height: 1500),
  const _Board('03_balon_yukleniyor', _boardLocal, height: 760, settleMs: 700),
  const _Board('04_balon_tek_gosterimlik', _boardOnce, height: 640),
  const _Board('05_balon_gorsel_yukleniyor', _boardMedia, height: 1500, img: _Img.hang, settleMs: 700),
  const _Board('06_balon_gorsel_hata', _boardMedia, height: 1500, img: _Img.err, settleMs: 700),
  _Board('10_goruntuleyici_foto', () => _viewer()),
  _Board('11_goruntuleyici_video', () => _viewer(index: 0, videoFirst: true)),
  _Board('12_goruntuleyici_yukleniyor', () => _viewer(), img: _Img.hang, settleMs: 700),
  _Board('13_goruntuleyici_hata', () => _viewer(), img: _Img.err, settleMs: 700),
  _Board('14_goruntuleyici_cubuksuz', () => _viewer(), after: (t) async {
    await t.tapAt(const Offset(195, 400));
  }),
  const _Board('20_video_oynuyor', _player),
  _Board('21_video_duraklatildi', _player, after: (t) async {
    await t.tap(find.byKey(const ValueKey('videoStage')));
  }),
  const _Board('22_video_yukleniyor', _player, video: _Vid.hang, settleMs: 700),
  const _Board('23_video_hata', _player, video: _Vid.fail, settleMs: 700),
  _Board('30_tek_foto_acik', () => _once(_onceBackend())),
  _Board('31_tek_foto_tuketildi', () => _once(_onceBackend(status: 410))),
  _Board('32_tek_foto_ag_hatasi', () => _once(_onceBackend(network: true))),
  _Board('33_tek_foto_yukleniyor', () => _once(_onceBackend(delay: const Duration(seconds: 3))), settleMs: 500, drainMs: 3500),
  _Board('34_tek_foto_kendi', () => _once(_onceBackend(status: 403))),
  _Board('40_tam_ekran_gorsel', () => const ChatImageViewer(url: '/files/m6.jpg', headers: {})),
  _Board('41_tam_ekran_yukleniyor', () => const ChatImageViewer(url: '/files/m6.jpg', headers: {}), img: _Img.hang, settleMs: 700),
  _Board('42_tam_ekran_hata', () => const ChatImageViewer(url: '/files/m6.jpg', headers: {}), img: _Img.err, settleMs: 700),
];

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await settle(tester, const Duration(milliseconds: 500));
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['P08_LANG'] ?? 'tr');
  final only = (Platform.environment['P08_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P08_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_koyu_x1.3', true, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final b in _boards) {
      if (only.isNotEmpty && !only.any((o) => b.file.startsWith(o))) continue;
      final name = '${b.file}${v.suffix}_$_lang';
      testWidgets('p08 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, b.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        debugNetworkImageHttpClientProvider = switch (b.img) {
          _Img.ok => () => StoreImageHttpClient(),
          _Img.hang => () => _HangClient(),
          _Img.err => () => _ErrClient(),
        };
        final previous = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = _FakeVideoPlatform(b.video);
        addTearDown(() => VideoPlayerPlatform.instance = previous);

        final key = GlobalKey();
        await tester.pumpWidget(_app(b.build(), v.dark, key, v.scale));
        await settle(tester, Duration(milliseconds: b.settleMs));
        if (b.img == _Img.ok) await _pumpImages(tester);
        if (b.after != null) {
          await b.after!(tester);
          await settle(tester, const Duration(milliseconds: 600));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height}');
        });
        if (b.drainMs > 0) await settle(tester, Duration(milliseconds: b.drainMs));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
