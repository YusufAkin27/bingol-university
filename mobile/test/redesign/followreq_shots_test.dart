@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_requests_page.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_requests_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// FOLLOWREQ-MB ekran goruntuleri (Stitch referansi yok). Varsayilan `flutter test` ile CALISMAZ.
/// Uretim: `STORE_SHOTS_OUT='C:/bu_qa/shots/followreq' flutter test test/redesign/followreq_shots_test.dart`
/// Istege bagli: `FR_LANG=tr|en|ar`, `FR_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';

String _iso(Duration ago) => DateTime.now().subtract(ago).toUtc().toIso8601String();

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.after});
  final String file;
  final Widget Function(Session s) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
}

void _base(FakeBackend b) {
  b
    ..on('/me/summary', {'unreadNotifications': 2, 'unreadMessages': 3, 'communities': 3, 'events': 4, 'bookmarks': 12})
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım, satranç ve kampüs etkinlikleri.',
      'showEmail': false,
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94});
}

Map<String, dynamic> _req(int id, String name, String dept, Duration ago) =>
    {'userId': id, 'displayName': name, 'department': dept, 'requestedAt': _iso(ago)};

void _requests(FakeBackend b, {bool empty = false}) {
  b
    ..on('/users/me/follow-requests/count', {'count': empty ? 0 : 3})
    ..on('/users/me/follow-requests*', {
      'items': empty
          ? <Object>[]
          : [
              _req(31, 'Selin Kaya', 'Hukuk', const Duration(minutes: 12)),
              _req(32, 'Burak Çelik Çok Uzun Bir Soyadı', 'Bilgisayar Mühendisliği', const Duration(hours: 5)),
              _req(33, 'Zeynep Demir', 'Tıp', const Duration(days: 2)),
            ],
      'nextCursor': null,
      'total': empty ? 0 : 3,
    });
}

Map<String, dynamic> _conv(int id, String type, String name, String text) => {
      'id': id,
      'type': type,
      'requestState': 'PENDING',
      if (type == 'DIRECT') 'peer': {'id': 60 + id, 'displayName': name} else 'title': name,
      'lastMessage': {
        'id': 900 + id,
        'conversationId': id,
        'senderId': 60 + id,
        'text': text,
        'attachments': const [],
        'createdAt': _iso(const Duration(minutes: 30)),
      },
    };

final _shots = <_Shot>[
  _Shot('01_gizlilik_gizli_hesap', (s) => PrivacyDataPage(session: s),
      setup: (b) => b
        ..on('/users/me/privacy', {'avatar': 'EVERYONE', 'bio': 'SHARED_CONTEXT', 'privateAccount': true})
        ..on('/users/me', {'id': 1, 'showEmail': false})),
  _Shot('02_gizli_hesap_kapat_sheet', (s) => PrivacyDataPage(session: s),
      setup: (b) => b
        ..on('/users/me/privacy', {'avatar': 'EVERYONE', 'privateAccount': true})
        ..on('/users/me', {'id': 1, 'showEmail': false}),
      after: (t) async {
        await t.tap(find.byKey(const ValueKey('privacy-private-switch')));
      }),
  _Shot('03_takip_istekleri', (s) => FollowRequestsPage(session: s), setup: _requests),
  _Shot('04_takip_istekleri_bos', (s) => FollowRequestsPage(session: s), setup: (b) => _requests(b, empty: true)),
  _Shot('05_kilitli_profil', (s) => UserProfilePage(session: s, userId: 2), setup: (b) {
    _base(b);
    b.on('/users/2', {
      'id': 2,
      'displayName': 'Mert Kaya',
      'department': 'Bilgisayar Mühendisliği',
      'bio': 'Yazılım ve müzik.',
      'isPrivate': true,
      'locked': true,
      'followState': 'NONE',
    });
  }),
  _Shot('06_kilitli_profil_istek_gonderildi', (s) => UserProfilePage(session: s, userId: 2), setup: (b) {
    _base(b);
    b.on('/users/2', {
      'id': 2,
      'displayName': 'Mert Kaya',
      'department': 'Bilgisayar Mühendisliği',
      'isPrivate': true,
      'locked': true,
      'followState': 'REQUESTED',
    });
  }),
  _Shot('07_takipciler_uc_durum', (s) => FollowListPage(session: s, userId: 7, followers: true, name: 'Ayşe Kaya'), setup: (b) {
    _base(b);
    b
      ..on('/users/7/followers*', {
        'items': [
          {'id': 11, 'displayName': 'Emre Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'followState': 'FOLLOWING'},
          {'id': 12, 'displayName': 'Selin Kaya Çok Uzun Bir Soyadı Olan Öğrenci', 'department': 'Hukuk', 'followState': 'REQUESTED', 'isPrivate': true},
          {'id': 13, 'displayName': 'Burak Çelik', 'department': 'Tıp', 'followState': 'NONE'},
        ],
        'nextCursor': null,
        'total': 3,
      })
      ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0});
  }),
  _Shot('08_takibi_birak_gizli_sheet', (s) => UserProfilePage(session: s, userId: 2), setup: (b) {
    _base(b);
    b.on('/users/2', {
      'id': 2,
      'displayName': 'Mert Kaya',
      'department': 'Bilgisayar Mühendisliği',
      'followerCount': 40,
      'followingCount': 10,
      'isPrivate': true,
      'locked': false,
      'followState': 'FOLLOWING',
    });
  }, after: (t) async {
    await t.tap(find.byKey(const ValueKey('followButton')));
  }),
  _Shot('09_mesaj_istekleri', (s) => MessageRequestsPage(session: s), setup: (b) {
    b
      ..on('/conversations/requests/count', {'count': 2})
      ..on('/conversations/requests*', {
        'items': [
          _conv(41, 'DIRECT', 'Zeynep Demir', 'Merhaba, ders notları için yazıyorum'),
          _conv(42, 'GROUP', 'Proje Grubu', 'Gruba hoş geldin'),
        ],
        'nextCursor': null,
      });
  }),
  _Shot('10_sohbet_listesi_mesaj_istekleri_satiri', (s) => ChatTab(session: s, connectRealtime: false), setup: (b) {
    b
      ..on('/conversations/requests/count', {'count': 2})
      ..on('/conversations/unread-count', {'total': 1})
      ..on('/conversations*', {
        'items': [
          {
            'id': 1,
            'type': 'DIRECT',
            'peer': {'id': 11, 'displayName': 'Mehmet Kaya'},
            'unreadCount': 1,
            'lastMessage': {
              'id': 100,
              'conversationId': 1,
              'senderId': 11,
              'text': 'Yarınki ders notlarını atar mısın?',
              'attachments': const [],
              'createdAt': _iso(const Duration(minutes: 5)),
            },
          },
        ],
        'nextCursor': null,
      });
  }),
  _Shot('11_bildirimler_takip_istekleri_satiri', (s) => NotificationsPage(session: s), setup: (b) {
    b
      ..on('/users/me/follow-requests/count', {'count': 3})
      ..on('/notifications', {
        'unreadCount': 2,
        'nextCursor': null,
        'items': [
          {
            'id': 1,
            'type': 'FOLLOW_REQUEST',
            'title': 'Yeni takip isteği',
            'body': 'Selin Kaya seni takip etmek istiyor',
            'read': false,
            'createdAt': _iso(const Duration(minutes: 12)),
            'data': {'targetType': 'FOLLOW_REQUESTS'},
          },
          {
            'id': 2,
            'type': 'FOLLOW_ACCEPTED',
            'title': 'İstek kabul edildi',
            'body': 'Mert Kaya takip isteğini kabul etti',
            'read': false,
            'createdAt': _iso(const Duration(hours: 3)),
            'data': {'targetType': 'USER', 'targetId': 2},
          },
          {'id': 3, 'type': 'EVENT', 'title': 'Kariyer günleri yarın', 'body': 'Saat 10:00', 'read': true, 'createdAt': _iso(const Duration(days: 1))},
        ],
      });
  }),
  _Shot('12_profil_sekmesi_takip_istekleri_satiri', (s) => ProfileTab(session: s, themeController: ThemeController()), setup: (b) {
    _base(b);
    _requests(b);
  }),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, _lang),
        darkTheme: BuTheme.forLocale(Brightness.dark, _lang),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(_lang),
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

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null;
  _lang = Platform.environment['FR_LANG'] ?? 'tr';
  final modes = (Platform.environment['FR_MODES'] ?? 'light,dark').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];
  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      final name = '${shot.file}${v.$1}_$_lang';
      testWidgets('followreq $name', skip: skip, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final b = FakeBackend();
        shot.setup?.call(b);
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(session), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
        });
        await settle(tester, const Duration(milliseconds: 1000));
        if (shot.after != null) {
          await shot.after!(tester);
          await settle(tester, const Duration(milliseconds: 800));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}
