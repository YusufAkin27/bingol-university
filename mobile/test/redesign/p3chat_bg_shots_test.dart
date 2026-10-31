@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';

/// P3-CHAT sohbet arka planı ekran görüntüleri (konuşma + ayarlar). Varsayılan `flutter test` ile ÇALIŞMAZ.
/// Üretim: `P3BG_OUT=C:/bu_qa/shots/tasarim/chat_bg/sonra flutter test test/redesign/p3chat_bg_shots_test.dart`
/// `P3BG_PLAIN=1`: duvar kağıdı kapalı ("önceki" görünüm). `P3BG_LANG=tr|en|ar`.
const _dpr = 2.5;

String _at(int minAgo) => DateTime.now().subtract(Duration(minutes: minAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, int sender, String text, int ago, {List<Map<String, dynamic>>? reactions}) =>
    {'id': id, 'conversationId': 1, 'senderId': sender, 'text': text, 'createdAt': _at(ago), 'attachments': const [], 'reactions': reactions ?? const []};

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

Widget _conversation() {
  final be = FakeBackend()
    ..on('/conversations/1/messages*', {
      'items': [
        _m(6, 1, 'Tamam, o zaman 14.00\'te kütüphanede görüşürüz.', 3),
        _m(5, 11, 'Ben de notlarımı getiririm, birlikte çalışırız.', 5, reactions: [
          {'emoji': '👍', 'count': 2}
        ]),
        _m(4, 11, 'Yarınki sınav için kaynakları gördün mü?', 7),
        _m(3, 1, 'Selam! Evet, ders notları duyuru sayfasında.', 45),
        _m(2, 11, 'Merhaba, yarın derste görüşelim mi?', 50),
        _m(1, 1, 'Günaydın.', 1500),
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
    ..on('/users/11/presence', {'online': false})
    ..on('/messages/reactions', {'emojis': <String>[]});
  return ChatDetailPage(
    session: makeSession(be),
    connectRealtime: false,
    mediaLibrary: FakeMediaLibrary.photos(8),
    ensureAccess: (c, p, {rationale}) async => true,
    conversation: const {
      'id': 1,
      'type': 'DIRECT',
      'title': 'Ali Veli',
      'peer': {'id': 11, 'displayName': 'Ali Veli'},
    },
  );
}

void main() {
  final out = Platform.environment['P3BG_OUT'];
  final skip = out == null ? 'P3BG_OUT tanimli degil' : null;
  final lang = Platform.environment['P3BG_LANG'] ?? 'tr';
  final plain = Platform.environment['P3BG_PLAIN'] == '1';
  setUpAll(loadTestFonts);

  final boards = <(String, Widget Function(), double, Future<void> Function(WidgetTester)?)>[
    ('konusma', _conversation, 844, null),
    ('ayarlar', () => const ChatBackgroundSettingsPage(), 844, null),
    ('giris_yazarken', _conversation, 844, (t) async {
      await t.enterText(find.byKey(const ValueKey('composerField')), 'Yarın sınavdan önce notları birlikte gözden geçirelim mi? Kütüphane 3. katta saat 10.00 gibi buluşabiliriz.');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }),
    ('arti_menusu', _conversation, 844, (t) async {
      await t.tap(find.byKey(const ValueKey('attachButton')));
      await t.pump();
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      }
    }),
  ];
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      for (final b in boards) {
        if (scale != 1.0 && b.$1 != 'konusma') continue;
        if (plain && b.$1 == 'ayarlar') continue;
        final name = '${b.$1}_${dark ? 'koyu' : 'acik'}${scale == 1.0 ? '' : '_x1.3'}_$lang';
        testWidgets('p3bg $name', skip: skip != null, (tester) async {
          mockSecureStorage();
          ChatBackgroundPrefs.debugReset();
          ChatWallpaper.debugResetCache();
          if (plain) await tester.runAsync(() => ChatBackgroundPrefs.instance.set(ChatBgStyle.plain));
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(390 * _dpr, b.$3 * _dpr);
          tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(_app(b.$2(), dark, key, lang, scale));
          // Varlık duvar kağıdı gerçek asenkron çözülür: ara ara gerçek zaman bekle.
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
            await tester.pump(const Duration(milliseconds: 120));
          }
          await settle(tester, const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 400));
          if (b.$4 != null) await b.$4!(tester);
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
