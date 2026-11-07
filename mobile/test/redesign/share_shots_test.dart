@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// SH-MB ekran görüntüleri: paylaşım alt sayfası, sohbet paylaşım kartları, Paylaş düğmeleri (GERÇEK ekranlar + sahte API).
///
/// Varsayılan `flutter test` ile ÇALIŞMAZ (ortam değişkeni yoksa atlanır). Üretim:
///   SHARE_SHOTS_OUT='C:/bu_qa/shots/share' flutter test test/redesign/share_shots_test.dart
const _dpr = 2.0;

String _lang = 'tr';

class _V {
  const _V(this.suffix, {this.dark = false, this.scale = 1.0, this.w = 390.0, this.h = 844.0, this.lang = 'tr'});
  final String suffix;
  final bool dark;
  final double scale;
  final double w;
  final double h;
  final String lang;
}

Widget _app(Widget home, _V v, GlobalKey key) {
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, v.lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, v.lang),
      themeMode: v.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(v.lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(v.scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _loadFonts(bool arabic) async {
  await loadTestFonts();
  if (!arabic) return;
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
}

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

FakeBackend _be() => FakeBackend()
  ..on('/conversations?size=50', {
    'items': [
      {'id': 1, 'type': 'DIRECT', 'peer': {'id': 11, 'displayName': 'Ali Veli'}},
      {'id': 2, 'type': 'DIRECT', 'peer': {'id': 12, 'displayName': 'Zeynep Kaya'}},
      {'id': 3, 'type': 'CLUB', 'title': 'Müzik Kulübü', 'memberCount': 48},
      {'id': 4, 'type': 'DIRECT', 'peer': {'id': 14, 'displayName': 'Mert Demir'}},
      {'id': 5, 'type': 'GROUP', 'title': 'Bilgisayar 3. Sınıf', 'memberCount': 31},
      {'id': 6, 'type': 'DIRECT', 'peer': {'id': 16, 'displayName': 'Elif Aydın'}},
      {'id': 7, 'type': 'DIRECT', 'peer': {'id': 17, 'displayName': 'Burak Şen'}},
    ],
    'nextCursor': null,
  })
  ..on('/users/12', {'id': 12, 'displayName': 'Ayşe Yılmaz', 'isPrivate': false})
  ..on('/users/search*', {
    'items': [
      {'id': 77, 'displayName': 'Ali Kaya', 'department': 'Bilgisayar'},
      {'id': 11, 'displayName': 'Ali Veli'},
    ],
    'nextCursor': null,
  });

Map<String, dynamic> _msg(int id, bool mine, Map<String, dynamic> share, {String text = '', int minute = 0}) => {
      'id': id,
      'text': text,
      'senderId': mine ? 1 : 11,
      'createdAt': '2026-11-05T10:${(10 + minute).toString().padLeft(2, '0')}:00Z',
      'status': 'READ',
      'share': share,
    };

Widget _chatCards(BuildContext context) {
  final t = context.bu;
  final msgs = <(bool, Map<String, dynamic>)>[
    (false, _msg(1, false, {'type': 'POST', 'id': 7, 'title': 'Güz akşamı kampüs', 'subtitle': 'Ayşe Yılmaz', 'imageUrl': 'https://img.invalid/a.jpg', 'available': true})),
    (true, _msg(2, true, {'type': 'REEL', 'id': 8, 'title': 'Kampüs turu', 'subtitle': 'Mert Demir', 'imageUrl': 'https://img.invalid/b.jpg', 'available': true}, text: 'Bunu çok sevdim', minute: 1)),
    (false, _msg(3, false, {'type': 'NEWS', 'id': 9, 'title': 'Rektörümüz öğrencilerle bir araya geldi: kampüs yaşamı konuşuldu', 'subtitle': 'bingol.edu.tr', 'imageUrl': 'https://img.invalid/c.jpg', 'available': true}, minute: 2)),
    (true, _msg(4, true, {'type': 'NEWS', 'id': 10, 'kind': 'DUYURU', 'title': 'Güz dönemi ders ekleme-bırakma tarihleri açıklandı', 'subtitle': 'bingol.edu.tr', 'available': true}, minute: 3)),
    (false, _msg(5, false, {'type': 'EVENT', 'id': 11, 'title': 'Kampüs Tanıtım Günü', 'subtitle': 'Müzik Kulübü', 'imageUrl': 'https://img.invalid/d.jpg', 'available': true}, text: 'Gelecek misin?', minute: 4)),
    (true, _msg(6, true, {'type': 'POST', 'id': 12, 'title': 'Silinmiş', 'available': false}, minute: 5)),
  ];
  return Scaffold(
    backgroundColor: t.bg,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final m in msgs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MessageBubble(
                message: m.$2,
                mine: m.$1,
                senderName: null,
                replyName: null,
                statusLine: 'seen',
                authHeaders: const {},
                onMenu: () {},
                onRetry: () {},
                onOpenImage: (_) {},
                onReact: (_) {},
                onOpenShare: (_) {},
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _postPage(FakeBackend b, {bool priv = false}) {
  final p = Post.fromJson({
    ...samplePost(id: 91, text: 'Güz akşamı kampüs', media: [samplePostMedia(id: 5)]),
    'author': {...samplePostAuthor(id: 12, name: 'Ayşe Yılmaz'), if (priv) 'isPrivate': true},
  });
  return Scaffold(
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(12), children: [PostCard(session: makeSession(b), post: p, onChanged: (_) {}, onDeleted: (_) {})])),
  );
}

void main() {
  final out = Platform.environment['SHARE_SHOTS_OUT'];
  final skip = out == null ? 'SHARE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;

  setUpAll(() => _loadFonts(true));

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name, _V v) async {
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
  }

  void prep(WidgetTester tester, _V v) {
    debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = Size(v.w * _dpr, v.h * _dpr);
    tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
    tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
    addTearDown(tester.view.reset);
    LocaleController.current = LocaleController(deviceLocales: () => [Locale(v.lang)])..pref = v.lang;
    addTearDown(() => LocaleController.current = null);
  }

  final variants = <_V>[
    const _V(''),
    const _V('_koyu', dark: true),
    const _V('_320_x1.3', w: 320, h: 640, scale: 1.3),
    const _V('_ar', lang: 'ar'),
  ];

  for (final v in variants) {
    // Paylaşım alt sayfası: varsayılan, seçim + not, arama, gizli hesap.
    testWidgets('paylasim sayfasi ${v.suffix}', skip: skip != null, (tester) async {
      prep(tester, v);
      final key = GlobalKey();
      final b = _be();
      await tester.pumpWidget(_app(_postPage(b), v, key));
      await settle(tester, const Duration(milliseconds: 500));
      await _pumpImages(tester);
      await tester.tap(find.byKey(const ValueKey('post-share-91')));
      await settle(tester, const Duration(milliseconds: 900));
      await _pumpImages(tester);
      await shoot(tester, key, '01_paylasim_sayfasi${v.suffix}', v);

      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('share-pick-c3')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(find.byKey(const ValueKey('share-note')), v.lang == 'ar' ? 'انظر إلى هذا' : 'Buna bak, çok güzel');
      await settle(tester, const Duration(milliseconds: 300));
      await shoot(tester, key, '02_paylasim_secili_not${v.suffix}', v);

      // Arama
      await tester.enterText(find.byType(TextField).first, 'ali');
      await settle(tester, const Duration(milliseconds: 900));
      await shoot(tester, key, '03_paylasim_arama${v.suffix}', v);
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('paylasim sayfasi gizli hesap ${v.suffix}', skip: skip != null || v.suffix == '_320_x1.3', (tester) async {
      prep(tester, v);
      final key = GlobalKey();
      final b = _be();
      await tester.pumpWidget(_app(_postPage(b, priv: true), v, key));
      await settle(tester, const Duration(milliseconds: 500));
      await _pumpImages(tester);
      await tester.tap(find.byKey(const ValueKey('post-share-91')));
      await settle(tester, const Duration(milliseconds: 900));
      await _pumpImages(tester);
      await shoot(tester, key, '04_paylasim_gizli_hesap${v.suffix}', v);
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('sohbet kartlari ${v.suffix}', skip: skip != null, (tester) async {
      prep(tester, v);
      final key = GlobalKey();
      await tester.pumpWidget(_app(Builder(builder: _chatCards), v, key));
      await settle(tester, const Duration(milliseconds: 600));
      await _pumpImages(tester);
      await shoot(tester, key, '10_sohbet_kartlari${v.suffix}', v);
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }

  const light = _V('');
  testWidgets('haber detayi paylas dugmesi', skip: skip != null, (tester) async {
    prep(tester, light);
    final key = GlobalKey();
    final b = _be()..on('/news/1', {'id': 1, 'content': 'Bingöl Üniversitesi yeni akademik yılın ilk haftasında öğrencilerle bir araya geldi.', 'url': 'https://www.bingol.edu.tr/haber/1'});
    await tester.pumpWidget(_app(
        NewsDetailPage(
            session: makeSession(b),
            item: {'id': 1, 'type': 'HABER', 'title': 'Rektörümüz öğrencilerle bir araya geldi', 'imageUrl': 'https://img.invalid/n1.jpg', 'url': 'https://www.bingol.edu.tr/haber/1'},
            saved: false),
        light,
        key));
    await settle(tester, const Duration(milliseconds: 900));
    await _pumpImages(tester);
    await shoot(tester, key, '20_haber_paylas_dugmesi', light);
    await tester.tap(find.byKey(const ValueKey('news-share')));
    await settle(tester, const Duration(milliseconds: 900));
    await _pumpImages(tester);
    await shoot(tester, key, '21_haber_paylasim_sayfasi', light);
    await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('etkinlik detayi paylas dugmesi', skip: skip != null, (tester) async {
    prep(tester, light);
    final key = GlobalKey();
    final s = DateTime.now().add(const Duration(days: 2));
    final b = _be()
      ..on('/events/5', {
        'id': 5,
        'title': 'Kariyer Günleri',
        'description': 'Sektörden konuklarla kariyer sohbetleri.',
        'startsAt': s.toUtc().toIso8601String(),
        'endsAt': s.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'location': 'Konferans Salonu',
        'communityId': 7,
        'communityName': 'Müzik Kulübü',
        'goingCount': 3,
        'capacity': 50,
        'myRsvp': null,
        'status': 'ACTIVE',
        'joinPolicy': 'OPEN',
        'canManage': false,
        'createdBy': 2,
      })
      ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false})
      ..on('/events/5/admission', {'eventId': 5, 'mode': 'OPEN', 'questions': <Object>[]});
    await tester.pumpWidget(_app(EventDetailPage(session: makeSession(b), eventId: 5), light, key));
    await settle(tester, const Duration(milliseconds: 900));
    await _pumpImages(tester);
    await shoot(tester, key, '22_etkinlik_paylas_dugmesi', light);
    await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('reels paylas dugmesi', skip: skip != null, (tester) async {
    prep(tester, light);
    final p = FakeVideoPlatformKs();
    final prev = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = p;
    addTearDown(() => VideoPlayerPlatform.instance = prev);
    final key = GlobalKey();
    final b = _be()..on('/feed/reels*', {'items': [videoPost(id: 7)], 'nextCursor': null});
    await tester.pumpWidget(_app(Scaffold(body: ReelsFeed(session: makeSession(b), active: true)), light, key));
    await settle(tester, const Duration(milliseconds: 900));
    await _pumpImages(tester);
    await shoot(tester, key, '23_reels_paylas_dugmesi', light);
    await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
  });
}
