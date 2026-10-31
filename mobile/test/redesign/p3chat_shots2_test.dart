@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';

/// P3-CHAT ek ekran goruntuleri: sohbet listesi, sohbet bilgisi (birebir/grup/oda), galeri, yeni sohbet, arka plan ayari.
/// Varsayilan `flutter test` ile CALISMAZ. Uretim: `P3S2_OUT=C:/bu_qa/shots/tasarim/chat_bg/sonra flutter test test/redesign/p3chat_shots2_test.dart`
const _dpr = 2.5;

String _at(int minAgo) => DateTime.now().subtract(Duration(minutes: minAgo)).toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String type, String title,
        {int unread = 0, bool muted = false, String text = '', String? sender, int senderId = 0, int ago = 5, String? status, List<Map<String, dynamic>>? att, bool deleted = false}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'muted': muted,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': senderId == 0 ? 10 + id : senderId,
        if (sender != null) 'senderName': sender,
        'text': text,
        'attachments': att ?? const [],
        if (status != null) 'status': status,
        if (deleted) 'deleted': true,
        'createdAt': _at(ago),
      },
    };

FakeBackend _listBe() => FakeBackend()
  ..on('/conversations/unread-count', {'total': 3})
  ..on('/conversations*', {
    'items': [
      _row(1, 'DIRECT', 'Zeynep Demir', unread: 3, text: 'Kütüphane 3. katta mısın, notlarını alabilir miyim?', ago: 3),
      _row(2, 'CLUB', 'Fotoğrafçılık Kulübü', unread: 12, muted: true, sender: 'Ahmet', text: 'Toplantı 18.00\'de Teknoloji Binası\'nda', ago: 20),
      _row(3, 'DIRECT', 'Emre Can', text: 'Tamamdır, yarın görüşürüz', senderId: 1, status: 'READ', ago: 60 * 26),
      _row(4, 'EVENT', 'Kariyer Günleri Söyleşisi', sender: 'Moderatör', text: 'CV hazırlama sunumu başlıyor', ago: 60 * 27),
      _row(5, 'DIRECT', 'Selin Kaya', att: [
        {'id': 1, 'kind': 'IMAGE', 'url': '/x.jpg'}
      ], ago: 60 * 70),
      _row(6, 'DIRECT', 'Berkan Yıldız', deleted: true, ago: 60 * 72),
    ],
    'nextCursor': null,
  });

FakeBackend _infoBe() => FakeBackend()
  ..on('/conversations/5/messages?size=40', {
    'items': [
      for (var i = 1; i <= 6; i++)
        {
          'id': i,
          'senderId': i.isEven ? 1 : 2,
          'createdAt': '2026-10-20T10:0$i:00Z',
          'attachments': [
            {'id': i, 'kind': 'IMAGE', 'url': '/api/conversations/5/media/$i', 'thumbUrl': '/api/conversations/5/media/$i/thumb'}
          ],
        }
    ],
    'nextCursor': null,
  })
  ..on('/users*', {'items': <Object>[], 'nextCursor': null});

Widget _info(Map<String, dynamic> conv, {int members = 3}) => ChatInfoPage(
      session: makeSession(_infoBe()),
      conversation: conv,
      members: [
        for (var i = 1; i <= members; i++) {'userId': i, 'displayName': i == 1 ? 'Ayşe Yılmaz' : 'Üye $i', 'role': i == 2 ? 'ADMIN' : 'MEMBER'}
      ],
      subtitle: 'çevrimiçi',
      onOpenRoom: () {},
    );

Widget _app(Widget home, bool dark, GlobalKey key) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, 'tr'),
        darkTheme: BuTheme.forLocale(Brightness.dark, 'tr'),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('tr'),
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

void main() {
  final out = Platform.environment['P3S2_OUT'];
  final skip = out == null ? 'P3S2_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  final boards = <(String, Widget Function(), Future<void> Function(WidgetTester)?)>[
    ('liste', () => ChatTab(session: makeSession(_listBe()), connectRealtime: false), null),
    ('bilgi_birebir', () => _info({'id': 5, 'type': 'DIRECT', 'peer': {'id': 2, 'displayName': 'Mehmet Kaya', 'department': 'Makine Mühendisliği'}}, members: 2), null),
    ('bilgi_grup', () => _info({'id': 5, 'type': 'GROUP', 'title': 'Proje Grubu', 'memberCount': 8, 'admin': true}, members: 5), null),
    ('bilgi_oda', () => _info({'id': 5, 'type': 'CLUB', 'title': 'Robotik Kulübü', 'memberCount': 86, 'communityId': 3}, members: 4), null),
    (
      'galeri',
      () => MediaPickerPage(library: FakeMediaLibrary.photos(18, videos: [FakeMediaLibrary.video('v1')]), ensureAccess: (c, p, {rationale}) async => true),
      (t) async {
        await t.tap(find.byKey(const ValueKey('galleryTile_p1')));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('galleryTile_p2')));
        await t.pump(const Duration(milliseconds: 400));
      }
    ),
    ('yeni_sohbet', () => NewChatPage(session: makeSession(_infoBe())), null),
    ('ayarlar', () => const ChatBackgroundSettingsPage(), null),
  ];

  for (final dark in [false, true]) {
    for (final b in boards) {
      final name = '${b.$1}_${dark ? 'koyu' : 'acik'}_tr';
      testWidgets('p3s2 $name', skip: skip != null, (tester) async {
        mockSecureStorage();
        ChatBackgroundPrefs.debugReset();
        ChatWallpaper.debugResetCache();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_app(b.$2(), dark, key));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 120));
        }
        await settle(tester, const Duration(seconds: 1));
        if (b.$3 != null) await b.$3!(tester);
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
      });
    }
  }
}
