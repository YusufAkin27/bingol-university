@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/message_info_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';
import '../support/store_shots_images.dart';

/// Premium sohbet ekran goruntuleri (390x844, acik + koyu). Varsayilan `flutter test` ile CALISMAZ.
/// Uretim: `CHATQA_OUT=C:/bu_qa/shots/chat flutter test test/redesign/chat_premium_shots_test.dart`
const _dpr = 2.5;

String _at(int minAgo) => DateTime.now().subtract(Duration(minutes: minAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, bool mine, String? text,
        {int ago = 10,
        String? status,
        List<Map<String, dynamic>>? att,
        List<Map<String, dynamic>>? reactions,
        Map<String, dynamic>? replyTo,
        bool edited = false}) =>
    {
      'id': id,
      'conversationId': 1,
      'senderId': mine ? 1 : 11,
      if (text != null) 'text': text,
      'createdAt': _at(ago),
      if (status != null) 'status': status,
      if (att != null) 'attachments': att,
      if (reactions != null) 'reactions': reactions,
      if (replyTo != null) 'replyTo': replyTo,
      if (edited) 'edited': true,
    };

FakeBackend _be({bool textOnly = false}) {
  final all =
      [
        _m(1, false, 'Selam', ago: 58),
        _m(2, true, 'Merhaba, nasılsın?', ago: 56, status: 'READ'),
        _m(3, false, 'İyiyim 🙂', ago: 55),
        _m(4, false, 'Yarın kütüphanede ders çalışacağız, sen de gelir misin? Notlarını getirirsen çok iyi olur, ben de çıktıları alırım.', ago: 54),
        _m(5, true, 'Tamam', ago: 40, status: 'DELIVERED'),
        _m(6, true, 'Saat kaçta buluşalım?', ago: 39, status: 'DELIVERED'),
        _m(7, false, '14:30 uygun mu?', ago: 30, reactions: [
          {'emoji': '👍', 'count': 1}
        ]),
        _m(8, true, 'Olur, uygun', ago: 28, status: 'READ', replyTo: {'id': 7, 'senderId': 11, 'text': '14:30 uygun mu?'}, edited: true, reactions: [
          {'emoji': '👍', 'count': 1},
          {'emoji': '❤️', 'count': 2}
        ]),
        _m(9, false, null, ago: 20, att: [
          {'id': 50, 'kind': 'IMAGE', 'url': '/files/a1.jpg', 'thumbUrl': '/files/a1.jpg', 'width': 600, 'height': 750}
        ]),
        _m(10, true, 'Nasıl çıkmış?', ago: 18, status: 'SENT', att: [
          {'id': 51, 'kind': 'VIDEO', 'url': '/files/v1.mp4', 'thumbUrl': '/files/a3.jpg', 'width': 600, 'height': 750, 'durationMs': 42000}
        ]),
        _m(11, true, 'Kafede çalışıyorum', ago: 5, status: 'SENT', att: [
          {'id': 52, 'kind': 'IMAGE', 'url': '/files/a2.jpg', 'thumbUrl': '/files/a2.jpg', 'width': 600, 'height': 750}
        ]),
      ];
  final msgs = textOnly ? all.sublist(0, 8) : all;
  return FakeBackend()
    ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
    ..on('/conversations/1', {
      'conversation': {'id': 1},
      'members': [
        {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
        {'userId': 11, 'displayName': 'Ali Veli'},
      ],
    })
    ..on('/users/11/presence', {'online': true})
    ..on('/messages/reactions', {'emojis': <String>[]})
    ..on('/messages/10/info', {
      'message': all[9],
      'sentAt': _at(18),
      'deliveredAt': null,
      'readAt': null,
      'status': 'SENT',
      'replies': {'items': [all[7]], 'nextCursor': null},
    })
    ..on('/messages/8/info', {
      'message': all[7],
      'sentAt': _at(28),
      'deliveredAt': _at(27),
      'readAt': _at(26),
      'status': 'READ',
      'replies': {'items': <Object>[], 'nextCursor': null},
    });
}

Widget _page(FakeBackend be, {FakeMediaLibrary? lib}) => ChatDetailPage(
      session: makeSession(be),
      connectRealtime: false,
      mediaLibrary: lib,
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

Widget _app(Widget home, bool dark, GlobalKey key, {String lang = 'tr'}) => RepaintBoundary(
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

class _ShotLib extends FakeMediaLibrary {
  _ShotLib(super.all);
  @override
  Future<Uint8List?> thumb(GalleryItem item, int size) async => storeImageBytes(item.id.hashCode.abs());
}

_ShotLib _lib() => _ShotLib([
      FakeMediaLibrary.video('v1', ms: 42000),
      for (var i = 1; i <= 24; i++) GalleryItem(id: 'p$i', isVideo: false),
    ]);

class _Board {
  const _Board(this.name, this.build, {this.after});
  final String name;
  final Widget Function() build;
  final Future<void> Function(WidgetTester)? after;
}

Future<void> _pumpImages(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final out = Platform.environment['CHATQA_OUT'];
  final skip = out == null ? 'CHATQA_OUT tanimli degil' : null;
  final only = (Platform.environment['CHATQA_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  setUpAll(loadTestFonts);

  final boards = <_Board>[
    _Board('01_mesajlar', () => _page(_be(textOnly: true))),
    _Board('01b_medya', () => _page(_be())),
    _Board('02_artı_menu', () => _page(_be()), after: (t) async {
      await t.tap(find.byKey(const ValueKey('attachButton')));
      await t.pump(const Duration(milliseconds: 400));
    }),
    _Board('03_galeri_paneli', () => _page(_be(), lib: _lib()), after: (t) async {
      await t.tap(find.byKey(const ValueKey('attachButton')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('attachGallery')));
      await _pumpImages(t, 4);
      await t.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('galleryTile_p2')));
      await t.pump(const Duration(milliseconds: 400));
    }),
    _Board('04_galeri_genis', () => _page(_be(), lib: _lib()), after: (t) async {
      await t.tap(find.byKey(const ValueKey('attachButton')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('attachGallery')));
      await _pumpImages(t, 4);
      await t.fling(find.byKey(const ValueKey('sheetHandle')), const Offset(0, -500), 2000);
      await _pumpImages(t, 3);
    }),
    _Board('05_uzun_basma', () => _page(_be(textOnly: true)), after: (t) async {
      await t.longPress(find.text('Olur, uygun'));
      await t.pump(const Duration(milliseconds: 600));
    }),
    _Board('06_yanit_kutusu', () => _page(_be(textOnly: true)), after: (t) async {
      await t.longPress(find.text('Selam'));
      await t.pump(const Duration(milliseconds: 600));
      final reply = find.text('Yanıtla');
      if (reply.evaluate().isNotEmpty) {
        await t.tap(reply.first);
        await t.pump(const Duration(milliseconds: 500));
      }
    }),
    _Board('07_mesaj_bilgisi', () => MessageInfoPage(session: makeSession(_be()), message: _m(8, true, 'Olur, uygun', ago: 28, status: 'READ', edited: true), peerName: 'Ali Veli')),
    _Board('08_mesaj_bilgisi_gonderildi', () => MessageInfoPage(session: makeSession(_be()), message: _m(10, true, 'Nasıl çıkmış?', ago: 18, status: 'SENT'), peerName: 'Ali Veli')),
    _Board('09_duvar_kagidi_ayar', () => const ChatBackgroundSettingsPage()),
  ];

  for (final dark in [false, true]) {
    for (final b in boards) {
      final name = '${b.name}_${dark ? 'koyu' : 'acik'}_tr';
      if (only.isNotEmpty && !only.any((o) => b.name.startsWith(o))) continue;
      testWidgets('chatqa $name', skip: skip != null, (tester) async {
        mockSecureStorage();
        ChatBackgroundPrefs.debugReset();
        ChatWallpaper.debugResetCache();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        final key = GlobalKey();
        await HttpOverrides.runZoned(() async {
          await tester.pumpWidget(_app(b.build(), dark, key));
          await _pumpImages(tester);
          await settle(tester, const Duration(seconds: 1));
          if (b.after != null) await b.after!(tester);
          await _pumpImages(tester, 3);
          await tester.pump(const Duration(milliseconds: 400));
        }, createHttpClient: (c) => StoreImageHttpClient());
        debugNetworkImageHttpClientProvider = null;
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
      });
    }
  }
}
