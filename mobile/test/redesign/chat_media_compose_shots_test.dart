@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/platform/secure_view.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/chat/media_preview_page.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';
import '../support/store_shots_images.dart';

/// Sohbet medya onizleme + tek gonderimlik ekran goruntuleri. Varsayilan `flutter test` ile CALISMAZ.
/// Uretim: `CHATMEDIA_OUT=C:/bu_qa/shots/chat_media flutter test test/redesign/chat_media_compose_shots_test.dart`
const _dpr = 2.5;

MediaPick _pick(String key, int variant) => MediaPick(
      key: key,
      isVideo: false,
      thumb: (_) async => storeImageBytes(variant),
      imageBytes: () async => storeImageBytes(variant),
    );

Widget _app(Widget home, bool dark, GlobalKey key, Size size, double scale, {String lang = 'tr'}) => RepaintBoundary(
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

class _Board {
  const _Board(this.name, this.build, {this.after});
  final String name;
  final Widget Function() build;
  final Future<void> Function(WidgetTester)? after;
}

Map<String, dynamic> _once(int id, int sender, String text) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': DateTime.now().subtract(Duration(minutes: 600 - id)).toUtc().toIso8601String(),
      'attachments': [
        {'id': 50 + id, 'kind': 'IMAGE', 'viewOnce': true, 'viewed': false, 'thumbUrl': null, 'url': sender == 1 ? null : '/api/conversations/1/media/${50 + id}'},
      ],
    };

void main() {
  final out = Platform.environment['CHATMEDIA_OUT'];
  final skip = out == null ? 'CHATMEDIA_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  final boards = <_Board>[
    _Board('01_onizleme', () => MediaPreviewPage(picks: [_pick('a', 1), _pick('b', 2), _pick('c', 3)])),
    _Board('02_onizleme_aciklama_tek', () => MediaPreviewPage(picks: [_pick('a', 1), _pick('b', 2), _pick('c', 3)]), after: (t) async {
      await t.tap(find.byKey(const ValueKey('onceButton_0')));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byKey(const ValueKey('previewCaption')), 'Kampüste bugün hava çok güzel');
      await t.pump(const Duration(milliseconds: 300));
    }),
    _Board('03_onizleme_klavye', () => MediaPreviewPage(picks: [_pick('a', 1), _pick('b', 2)]), after: (t) async {
      await t.tap(find.byKey(const ValueKey('previewCaption')));
      await t.enterText(find.byKey(const ValueKey('previewCaption')), 'Uzun bir açıklama metni burada yazılıyor ve alan genişliği doldurur');
      t.view.viewInsets = const FakeViewPadding(bottom: 280 * _dpr);
      await t.pump(const Duration(milliseconds: 400));
    }),
    _Board('04_balon_tek_gonderimlik', () {
      final be = FakeBackend()
        ..on('/conversations/1/messages?size=30', {
          'items': [
            _once(3, 1, 'GİZLİ açıklama balonda görünmemeli'),
            _once(2, 11, 'GİZLİ açıklama balonda görünmemeli'),
          ],
          'nextCursor': null,
        })
        ..on('/conversations/1', {
          'conversation': {'id': 1},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Ali Veli'},
          ],
        })
        ..on('/users/11/presence', {'online': true})
        ..on('/messages/reactions', {'emojis': <String>[]});
      return ChatDetailPage(
        session: makeSession(be),
        connectRealtime: false,
        mediaLibrary: FakeMediaLibrary.photos(2),
        ensureAccess: (c, p, {rationale}) async => true,
        conversation: const {
          'id': 1,
          'type': 'DIRECT',
          'title': 'Ali Veli',
          'peer': {'id': 11, 'displayName': 'Ali Veli'},
        },
      );
    }),
    _Board('05_goruntuleyici_aciklama', () {
      final be = FakeBackend()..onBytes('/conversations/1/media/50', storeImageBytes(4), once: true);
      return ViewOnceViewer(
        api: makeSession(be).api,
        conversationId: 1,
        attachmentId: 50,
        caption: 'Kampüste bugün hava çok güzel, kütüphanenin önünde buluşalım mı?',
        secureView: ChatSecureView(isIOS: false),
      );
    }),
  ];

  final sizes = <(String, Size, double)>[
    ('390', const Size(390, 844), 1.0),
    ('320', const Size(320, 640), 1.0),
    ('320x13', const Size(320, 640), 1.3),
  ];

  for (final dark in [false, true]) {
    for (final sz in sizes) {
      for (final b in boards) {
        final name = '${b.name}_${dark ? 'koyu' : 'acik'}_${sz.$1}';
        testWidgets('chatmedia $name', skip: skip != null, (tester) async {
          mockSecureStorage();
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(sz.$2.width * _dpr, sz.$2.height * _dpr);
          tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.platformDispatcher.textScaleFactorTestValue = sz.$3;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final key = GlobalKey();
          await tester.pumpWidget(_app(b.build(), dark, key, sz.$2, sz.$3));
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
            await tester.pump(const Duration(milliseconds: 150));
          }
          await settle(tester, const Duration(milliseconds: 600));
          if (b.after != null) await b.after!(tester);
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
            await tester.pump(const Duration(milliseconds: 150));
          }
          await tester.pump(const Duration(milliseconds: 400));
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: _dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            File('${dir.path}/$name.png').writeAsBytesSync(Uint8List.view(data.buffer));
          });
        });
      }
    }
  }
}
