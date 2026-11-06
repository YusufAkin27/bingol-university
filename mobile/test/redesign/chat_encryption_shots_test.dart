@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_security_page.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';

/// Sohbet güvenliği ekran görüntüleri (bildirim + güvenlik sayfası + bilgi satırı). Varsayılan `flutter test` ile ÇALIŞMAZ.
/// Üretim: `CHATENC_OUT=C:/bu_qa/shots/chatenc flutter test test/redesign/chat_encryption_shots_test.dart`
/// `CHATENC_LANG=tr|en|ar`.
const _dpr = 2.5;

String _at(int minAgo) => DateTime.now().subtract(Duration(minutes: minAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, int sender, String text, int ago) =>
    {'id': id, 'conversationId': 1, 'senderId': sender, 'text': text, 'createdAt': _at(ago), 'attachments': const [], 'reactions': const []};

Widget _app(Widget home, bool dark, GlobalKey key, String lang, double scale) => RepaintBoundary(
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
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: home,
      ),
    );

FakeBackend _be() => FakeBackend()
  ..on('/conversations/1/messages*', {
    'items': [
      _m(4, 1, 'Tamam, o zaman 14.00\'te kütüphanede görüşürüz.', 3),
      _m(3, 11, 'Ben de notlarımı getiririm.', 5),
      _m(2, 1, 'Selam! Evet, ders notları duyuru sayfasında.', 45),
      _m(1, 11, 'Merhaba, yarın derste görüşelim mi?', 50),
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
  ..on('/conversations/1/media*', {'items': <Map<String, dynamic>>[], 'nextCursor': null})
  ..on('/users/11/presence', {'online': false})
  ..on('/messages/reactions', {'emojis': <String>[]});

Widget _detail(Map<String, dynamic> conv) => ChatDetailPage(
      session: makeSession(_be()),
      connectRealtime: false,
      mediaLibrary: FakeMediaLibrary.photos(8),
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: conv,
    );

const _dm = {'id': 1, 'type': 'DIRECT', 'title': 'Ali Veli', 'peer': {'id': 11, 'displayName': 'Ali Veli'}};
const _group = {'id': 1, 'type': 'GROUP', 'title': 'Proje Grubu', 'memberCount': 3};
const _club = {'id': 1, 'type': 'CLUB', 'title': 'Satranç Kulübü', 'communityId': 5, 'memberCount': 3};

void main() {
  final out = Platform.environment['CHATENC_OUT'];
  final skip = out == null ? 'CHATENC_OUT tanimli degil' : null;
  final lang = Platform.environment['CHATENC_LANG'] ?? 'tr';
  setUpAll(loadTestFonts);

  final boards = <(String, Widget Function(), double)>[
    ('konusma_dm', () => _detail(_dm), 844),
    ('konusma_grup', () => _detail(_group), 844),
    ('konusma_oda', () => _detail(_club), 844),
    ('guvenlik_sayfasi', () => ChatSecurityPage(session: makeSession(FakeBackend())), 2300),
    ('bilgi_dm', () => ChatInfoPage(session: makeSession(_be()), conversation: Map.of(_dm), members: const [
          {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
          {'userId': 11, 'displayName': 'Ali Veli'},
        ]), 844),
  ];
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      for (final b in boards) {
        if (scale != 1.0 && b.$1 != 'konusma_grup' && b.$1 != 'guvenlik_sayfasi') continue;
        final name = '${b.$1}_${dark ? 'koyu' : 'acik'}${scale == 1.0 ? '' : '_x1.3'}_$lang';
        testWidgets('chatenc $name', skip: skip != null, (tester) async {
          mockSecureStorage();
          ChatBackgroundPrefs.debugReset();
          ChatWallpaper.debugResetCache();
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(390 * _dpr, b.$3 * _dpr);
          tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(_app(b.$2(), dark, key, lang, scale));
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
            await tester.pump(const Duration(milliseconds: 120));
          }
          await settle(tester, const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 400));
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: _dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
          });
          await tester.runAsync(() => ChatBackgroundPrefs.clear());
        });
      }
    }
  }
}
