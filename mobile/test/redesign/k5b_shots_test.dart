@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/contacts/contacts_service.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/chat_video_player.dart';
import 'package:bu_kampus/features/chat/contacts_match_page.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gal/gal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// K5 ikinci tur ekran goruntuleri: yeni sohbet / grup / rehberden kisi bul (referans 23) ve
/// sohbet goruntuleyicileri (referans 26).
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (Git Bash, ASCII yoldan):
///   STORE_SHOTS_OUT='C:/.../redesign/k5/yeni' flutter test test/redesign/k5b_shots_test.dart
/// Istege bagli: `K5B_LANG=tr|en|ar`, `K5B_ONLY=N01,V03`, `K5B_MODES=light,dark,x13`.
const _dpr = 2.5;

String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

enum _Img { ok, hang, err }

enum _Vid { ok, fail }

class _Board {
  const _Board(this.file, this.build, {this.height = 844, this.img = _Img.ok, this.after, this.settleMs = 1000, this.video = _Vid.ok});
  final String file;
  final Widget Function() build;
  final double height;
  final _Img img;
  final Future<void> Function(WidgetTester t)? after;
  final int settleMs;
  final _Vid video;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

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

GalException _gal(GalExceptionType t) => GalException(type: t, platformException: PlatformException(code: 'x'), stackTrace: StackTrace.empty);

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
    final id = _next++;
    final sc = StreamController<VideoEvent>();
    sc.add(VideoEvent(eventType: VideoEventType.initialized, duration: const Duration(seconds: 42), size: const Size(720, 1280)));
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
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 18);
  @override
  Widget buildView(int playerId) => Image.memory(storeImageBytes(5), fit: BoxFit.cover, gaplessPlayback: true);
}

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
// Yeni sohbet / grup / rehber

Map<String, dynamic> _u(int id, String name, String dept, {int avatar = 0}) => {
      'id': id,
      'displayName': name,
      'department': dept,
      'avatarUrl': avatar == 0 ? null : '/files/p$avatar.jpg',
    };

FakeBackend _searchBackend({bool empty = false}) => FakeBackend()
  ..on('/users/search*', {
    'items': empty
        ? <Object>[]
        : [
            _u(11, 'Mehmet Kaya', 'Makine Mühendisliği · 3. sınıf', avatar: 1),
            _u(12, 'Mehmet Demir', 'İktisat · 2. sınıf', avatar: 2),
            _u(13, 'Zeynep Kaya', 'Bilgisayar Mühendisliği · 4. sınıf', avatar: 3),
          ],
    'nextCursor': null,
  });

Widget _newChat({bool empty = false}) => NewChatPage(session: makeSession(_searchBackend(empty: empty)));

Future<void> _type(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField).last, q);
  await t.pump(const Duration(milliseconds: 350));
  await settle(t, const Duration(milliseconds: 400));
}

class _FakeContacts implements ContactsProvider {
  _FakeContacts(this.emails);
  final List<String> emails;
  @override
  Future<List<String>> readEmails() async => emails;
}

Map<String, dynamic> _match(String email, int id, String name, String dept, int avatar) =>
    {'hash': emailHash(email), 'userId': id, 'displayName': name, 'avatarUrl': '/files/p$avatar.jpg', 'faculty': 'Mühendislik Fakültesi', 'department': dept};

Widget _contactsReady({bool none = false, bool truncated = false}) {
  final people = [
    ('ahmet.yilmaz@bingol.edu.tr', 'Ahmet Yılmaz', 'Bilgisayar Mühendisliği · 4. sınıf'),
    ('merve.sahin@bingol.edu.tr', 'Merve Şahin', 'Hemşirelik · 2. sınıf'),
    ('burak.aydin@bingol.edu.tr', 'Burak Aydın', 'İktisadi ve İdari Bilimler · 3. sınıf'),
    ('sena.koc@bingol.edu.tr', 'Sena Koç', 'Moleküler Biyoloji ve Genetik · 1. sınıf'),
    ('murat.arslan@bingol.edu.tr', 'Murat Arslan', 'İnşaat Mühendisliği · 4. sınıf'),
  ];
  ContactsMatcher.resetLimiter();
  final be = FakeBackend()
    ..on('/users/contacts/match', {
      'matches': none ? <Object>[] : [for (var i = 0; i < people.length; i++) _match(people[i].$1, 20 + i, people[i].$2, people[i].$3, i + 1)],
    });
  return ContactsMatchPage(
    session: makeSession(be),
    provider: _FakeContacts(none ? ['x@bingol.edu.tr'] : [for (final p in people) p.$1, if (truncated) for (var i = 0; i < (contactsHourlyLimit + 1) * contactsChunkSize; i++) 'u$i@ogr.bingol.edu.tr']),
    permissions: FakePermissionService(initial: {AppPermission.contacts: PermState.granted}),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Goruntuleyiciler

List<ChatMediaItem> _items({bool videoAt2 = false}) => [
      const ChatMediaItem(url: '/files/m1.jpg', thumbUrl: '/files/m1.jpg', sender: 'Mehmet Kaya'),
      const ChatMediaItem(url: '/files/m2.jpg', thumbUrl: '/files/m2.jpg', sender: 'Ayşe Yılmaz'),
      if (videoAt2)
        const ChatMediaItem(url: '/api/conversations/1/media/90', thumbUrl: '/files/m6.jpg', isVideo: true, durationMs: 42000, sender: 'Mehmet Kaya')
      else
        const ChatMediaItem(url: '/files/m3.jpg', thumbUrl: '/files/m3.jpg'),
      const ChatMediaItem(url: '/files/m4.jpg', thumbUrl: '/files/m4.jpg'),
      const ChatMediaItem(url: '/files/m5.jpg', thumbUrl: '/files/m5.jpg'),
    ];

Widget _viewer({int index = 1, bool videoAt2 = false, Object? saveError}) => ChatMediaViewer(
      items: _items(videoAt2: videoAt2),
      headers: const {},
      initialIndex: index,
      saveImage: (u, h) async {
        if (saveError != null) throw saveError;
      },
      saveVideo: (u, h) async {},
    );

Widget _player() => ChatVideoPlayerPage(url: '/api/conversations/1/media/90', headers: const {}, durationMs: 42000);

FakeBackend _onceBackend({int status = 200, bool network = false}) {
  final be = FakeBackend();
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
  _Board('N01_yeni_sohbet', _newChat),
  _Board('N02_arama_sonuclari', _newChat, after: (t) => _type(t, 'mehmet')),
  _Board('N02b_arama_bos', () => _newChat(empty: true), after: (t) => _type(t, 'zzz')),
  _Board('N03_yeni_grup', _newChat, height: 1000, after: (t) async {
    await t.tap(find.text(_l.sohbetyNewGroup));
    await settle(t, const Duration(milliseconds: 400));
    await _type(t, 'mehmet');
    await t.tap(find.text('Mehmet Kaya'));
    await t.pump();
    await t.tap(find.text('Mehmet Demir'));
    await t.pump();
    await t.tap(find.text(_l.chatMiscCreateGroup));
    await settle(t, const Duration(milliseconds: 400));
  }),
  _Board('N04_rehber_izin', () => ContactsMatchPage(session: makeSession(FakeBackend()), permissions: FakePermissionService()), after: (t) async {
    await t.tap(find.text(_l.permNotNow));
  }),
  _Board('N05_rehber_hazir', () => _contactsReady(truncated: true), height: 960),
  _Board('N06_rehber_bos', () => _contactsReady(none: true)),
  _Board('N06b_rehber_yukleniyor', () => ContactsMatchPage(session: makeSession(FakeBackend(delay: const Duration(seconds: 3))), permissions: FakePermissionService(initial: {AppPermission.contacts: PermState.granted}), provider: _FakeContacts(['a@bingol.edu.tr'])), settleMs: 300),
  _Board('V01_gorsel', () => _viewer()),
  _Board('V02_gorsel_kaydedildi', () => _viewer(), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.download));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Board('V02b_gorsel_kaydedilemedi', () => _viewer(saveError: Exception('x')), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.download));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Board('V02d_galeri_izni_yok', () => _viewer(saveError: _gal(GalExceptionType.accessDenied)), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.download));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Board('V02e_alan_yok', () => _viewer(saveError: _gal(GalExceptionType.notEnoughSpace)), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.download));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Board('V02f_gorsel_yuklenemedi', () => _viewer(), img: _Img.err, settleMs: 700),
  _Board('V02c_gorsel_yukleniyor', () => _viewer(), img: _Img.hang, settleMs: 700),
  _Board('V03_video_poster', () => _viewer(index: 2, videoAt2: true)),
  _Board('V04_video_oynuyor', _player),
  _Board('V04b_video_duraklatildi', _player, after: (t) async {
    await t.tap(find.byKey(const ValueKey('videoStage')));
  }),
  _Board('V05_video_hata', _player, video: _Vid.fail, settleMs: 700),
  _Board('V06_tek_gosterimlik', () => _once(_onceBackend())),
  _Board('V06b_tek_tuketildi', () => _once(_onceBackend(status: 410))),
  _Board('V06c_tek_kendi', () => _once(_onceBackend(status: 403))),
  _Board('V06d_tek_ag_hatasi', () => _once(_onceBackend(network: true))),
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
  _lang = (Platform.environment['K5B_LANG'] ?? 'tr');
  final only = (Platform.environment['K5B_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K5B_MODES'] ?? 'light').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final b in _boards) {
      if (only.isNotEmpty && !only.any((o) => b.file.startsWith(o))) continue;
      final name = '${b.file}${v.suffix}_$_lang';
      testWidgets('k5b $name', skip: skip != null, (tester) async {
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
          if (b.img == _Img.ok) await _pumpImages(tester);
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
        await unmount(tester);
        await tester.pump(const Duration(seconds: 4));
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
