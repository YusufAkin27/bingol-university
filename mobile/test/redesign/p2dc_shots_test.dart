import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_models.dart' show Post;
import 'package:bu_kampus/features/posts/post_photo_viewer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuStaggerItem;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// P2-DC ara kare ekran goruntuleri: animasyonun ortasindaki gercek durumlar (Kesfet giris, cift dokunus kalbi,
/// tam ekran gorunturu zoom/surukleme, sohbet balonu girisi, sohbet listesi girisi).
/// Uretim: P2DC_OUT='C:/bu_qa/shots/tasarim/p2/dc' flutter test test/redesign/p2dc_shots_test.dart
/// Istege bagli: `P2DC_LANG=tr|ar`, `P2DC_MODES=light,dark`.
const _dpr = 2.5;
String _lang = 'tr';

const _authors = [
  ('Emre Kaya', 'Çim Alan', 2),
  ('Zeynep Arslan', 'Kütüphane', 4),
  ('Kaan Çelik', 'Kafeterya', 6),
];

Map<String, dynamic> _post(int i) {
  final a = _authors[i % _authors.length];
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: 40 + i, width: 1200, height: 900)],
    text: const ['Güneşli ve huzurlu bir sonbahar günü', 'Kütüphane merdivenlerinde nöbet', 'Vize haftasında kahve molası'][i % 3],
    likeCount: const [284, 512, 189][i % 3],
    authorId: 20 + i,
    authorName: a.$1,
    createdAt: DateTime.now().subtract(Duration(hours: a.$3)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = a.$2;
  return p;
}

Widget _app(Widget home, bool dark, GlobalKey key) {
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

Future<void> _snap(WidgetTester tester, GlobalKey key, String out, String name) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: _dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory(out)..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
    // ignore: avoid_print
    print('YAZILDI ${dir.path}/$name.png ${image.width}x${image.height}');
  });
}

void main() {
  final out = Platform.environment['P2DC_OUT'];
  final skip = out == null ? 'P2DC_OUT tanimli degil' : null;
  final outDir = out ?? '';
  _lang = Platform.environment['P2DC_LANG'] ?? 'tr';
  final modes = (Platform.environment['P2DC_MODES'] ?? 'light').split(',');
  final variants = <(String, bool)>[
    if (modes.contains('light')) ('', false),
    if (modes.contains('dark')) ('_koyu', true),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    void viewSetup(WidgetTester tester, {double h = 844}) {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = Size(390 * _dpr, h * _dpr);
      tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
      addTearDown(tester.view.reset);
    }

    testWidgets('p2dc kesfet giris ara kareleri ${v.$1} $_lang', skip: skip != null, (tester) async {
      viewSetup(tester);
      final b = FakeBackend()
        ..on('/feed*', {'items': [for (var i = 0; i < 3; i++) _post(i)], 'nextCursor': null, 'hint': null})
        ..on('/users/me/follow-suggestions*', {'items': <Object>[]});
      final session = makeSession(b)..api.lang = _lang;
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null)), v.$2, key));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
      });
      var n = 0;
      while (find.byType(BuStaggerItem).evaluate().isEmpty && n++ < 60) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 1));
      var t = 0;
      for (final ms in [70, 110, 180, 600]) {
        await tester.pump(Duration(milliseconds: ms - t));
        t = ms;
        await _snap(tester, key, outDir, 'kesfet_giris_${ms}ms${v.$1}_$_lang');
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
      // Cift dokunus: ilk kartin fotografina; 140 ms sonra buyuk kalp.
      final photo = find.byKey(const ValueKey('post-photo-500')).first;
      final at = tester.getCenter(photo);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await _snap(tester, key, outDir, 'cift_dokunus_kalp${v.$1}_$_lang');
      await tester.pump(const Duration(milliseconds: 900));
      await _snap(tester, key, outDir, 'cift_dokunus_sonra${v.$1}_$_lang');
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('p2dc gorunturu zoom ve surukleme ${v.$1} $_lang', skip: skip != null, (tester) async {
      viewSetup(tester);
      final b = FakeBackend();
      final post = Post.fromJson(_post(0));
      final session = makeSession(b)..api.lang = _lang;
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => openPostPhotoViewer(c, session, post), child: const Text('ac'))))), v.$2, key));
      await tester.tap(find.text('ac'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 500));
      await _snap(tester, key, outDir, 'gorunturu_acik${v.$1}_$_lang');
      // Surukleme: 140 dp asagi (arka plan acilir).
      final g = await tester.startGesture(tester.getCenter(find.byType(InteractiveViewer)));
      await g.moveBy(const Offset(0, 60));
      await g.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 16));
      await _snap(tester, key, outDir, 'gorunturu_surukleme${v.$1}_$_lang');
      await g.cancel();
      await tester.pump(const Duration(milliseconds: 500));
      // Cift dokunus: yakinlastirma tamam.
      final c = tester.getCenter(find.byType(InteractiveViewer)) + const Offset(40, -60);
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _snap(tester, key, outDir, 'gorunturu_zoom${v.$1}_$_lang');
      await tester.pump(const Duration(milliseconds: 300));
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('p2dc sohbet balon girisi ${v.$1} $_lang', skip: skip != null, (tester) async {
      viewSetup(tester, h: 520);
      final key = GlobalKey();
      Map<String, dynamic> m(int id, String text, bool mine, {Duration age = Duration.zero, String? status}) => {
            'id': id,
            'conversationId': 1,
            'senderId': mine ? 1 : 11,
            'text': text,
            'status': status,
            'createdAt': DateTime.now().subtract(age).toUtc().toIso8601String(),
          };
      Widget bubble(Map<String, dynamic> msg, bool mine, {bool seen = false}) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: MessageBubble(
              message: msg,
              mine: mine,
              senderName: null,
              replyName: null,
              seen: seen,
              authHeaders: const {},
              onMenu: () {},
              onRetry: () {},
              onOpenImage: (_) {},
              onReact: (_) {},
            ),
          );
      final texts = _lang == 'ar'
          ? ['مرحبا، كيف حالك؟', 'بخير، شكرا لك', 'هل أنت في المكتبة اليوم؟', 'نعم، أراك بعد قليل']
          : ['Merhaba, nasılsın?', 'İyiyim, sen?', 'Bugün kütüphanede misin?', 'Evet, birazdan görüşürüz'];
      await tester.pumpWidget(_app(
          Scaffold(
              body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    bubble(m(1, texts[0], false, age: const Duration(hours: 2)), false),
                    bubble(m(2, texts[1], true, age: const Duration(hours: 2), status: 'READ'), true, seen: true),
                    bubble(m(3, texts[2], false), false),
                    bubble(m(4, texts[3], true, status: 'SENT'), true),
                  ]))),
          v.$2,
          key));
      await tester.pump(const Duration(milliseconds: 1));
      var t = 0;
      for (final ms in [60, 110, 400]) {
        await tester.pump(Duration(milliseconds: ms - t));
        t = ms;
        await _snap(tester, key, outDir, 'sohbet_balon_${ms}ms${v.$1}_$_lang');
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('p2dc sohbet listesi giris ${v.$1} $_lang', skip: skip != null, (tester) async {
      viewSetup(tester);
      Map<String, dynamic> row(int id, String title, String text, {int unread = 0, String type = 'DIRECT'}) => {
            'id': id,
            'type': type,
            'title': title,
            if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
            'unreadCount': unread,
            'lastMessage': {
              'id': 100 + id,
              'conversationId': id,
              'senderId': 10 + id,
              'text': text,
              'attachments': const [],
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          };
      final b = FakeBackend()
        ..on('/conversations/unread-count', {'total': 3})
        ..on('/conversations*', {
          'items': [
            row(1, 'Mehmet Kaya', 'Yarınki ders notlarını atar mısın?', unread: 2),
            row(2, 'Zeynep Demir', 'Tamamdır, teşekkürler'),
            row(3, 'Edebiyat Kulübü', 'Toplantı perşembe 17:00', unread: 1, type: 'CLUB'),
            row(4, 'Ahmet Yıldız', 'Görüşürüz'),
            row(5, 'Ece Yılmaz', 'Laboratuvar raporu hazır mı?'),
          ],
          'nextCursor': null,
        });
      final session = makeSession(b)..api.lang = _lang;
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(ChatTab(session: session, connectRealtime: false), v.$2, key));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
      });
      var n = 0;
      while (find.byType(BuStaggerItem).evaluate().isEmpty && n++ < 60) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 1));
      var t = 0;
      for (final ms in [80, 160, 700]) {
        await tester.pump(Duration(milliseconds: ms - t));
        t = ms;
        await _snap(tester, key, outDir, 'sohbet_liste_${ms}ms${v.$1}_$_lang');
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
