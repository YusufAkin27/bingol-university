@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// ICONS-MIGRATE-2: ikon gecisi sonrasi temsili ekranlar (acik/koyu). Varsayilan `flutter test` ile CALISMAZ.
/// Uretim: `STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/ikon_sonra' flutter test test/redesign/ikon_sonra_shots_test.dart`
const _dpr = 2.0;

String _iso(Duration ago) => DateTime.now().subtract(ago).toUtc().toIso8601String();

class _Shot {
  const _Shot(this.file, this.build, {this.setup});
  final String file;
  final Widget Function(Session s) build;
  final void Function(FakeBackend b)? setup;
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
    });
}

Map<String, dynamic> _post(int i) {
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: i % 8, width: 1080, height: i.isEven ? 1440 : 1080)],
    text: 'Kampüsten kare $i',
    likeCount: 120 + i * 17,
    liked: i % 3 == 0,
    authorId: 20 + i,
    authorName: ['Emre Kaya', 'Zeynep Arslan', 'Mert Demir', 'Elif Yıldız'][i % 4],
    createdAt: _iso(Duration(hours: i + 2)),
  );
  (p['author'] as Map)['department'] = 'Bilgisayar Mühendisliği';
  return p;
}

Widget _navShot(int idx, int badge) {
  final n = ValueNotifier<int>(badge);
  return Scaffold(
    body: const SizedBox.expand(),
    bottomNavigationBar: FloatingNav(index: idx, onChanged: (_) {}, chatBadge: n, avatarName: 'Ayşe Kaya'),
  );
}

final _shots = <_Shot>[
  _Shot('01_alt_bar_ana_sayfa', (s) => _navShot(0, 0)),
  _Shot('02_alt_bar_kesfet', (s) => _navShot(1, 0)),
  _Shot('03_alt_bar_sohbet_rozet', (s) => _navShot(2, 3)),
  _Shot('04_alt_bar_kulupler', (s) => _navShot(3, 0)),
  _Shot('05_ayarlar', (s) => SettingsPage(session: s, themeController: ThemeController()), setup: _base),
  _Shot('06_sohbet_listesi', (s) => ChatTab(session: s, connectRealtime: false), setup: (b) {
    b
      ..on('/conversations/requests/count', {'count': 2})
      ..on('/conversations/unread-count', {'total': 3})
      ..on('/conversations*', {
        'items': [
          for (var i = 1; i <= 4; i++)
            {
              'id': i,
              'type': 'DIRECT',
              'peer': {'id': 10 + i, 'displayName': ['Mehmet Kaya', 'Zeynep Demir', 'Burak Çelik', 'Selin Öztürk'][i - 1]},
              'unreadCount': i == 1 ? 3 : 0,
              'mutedForever': i == 3,
              'lastMessage': {
                'id': 100 + i,
                'conversationId': i,
                'senderId': 10 + i,
                'text': 'Yarınki ders notlarını atar mısın?',
                'attachments': const [],
                'createdAt': _iso(Duration(minutes: 5 * i)),
              },
            },
        ],
        'nextCursor': null,
      });
  }),
  _Shot('07_profil', (s) => ProfileTab(session: s, themeController: ThemeController()), setup: _base),
  _Shot('08_kesfet', (s) => DiscoverTab(session: s, typeRequest: ValueNotifier<String?>(null)), setup: (b) {
    b
      ..on('/feed*', {'items': [for (var i = 0; i < 8; i++) _post(i)], 'nextCursor': null, 'hint': null})
      ..on('/users/me/follow-suggestions*', {'items': <Object>[]});
  }),
  _Shot('09_bildirimler', (s) => NotificationsPage(session: s), setup: (b) {
    b
      ..on('/users/me/follow-requests/count', {'count': 3})
      ..on('/notifications', {
        'unreadCount': 2,
        'nextCursor': null,
        'items': [
          {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Ders ekleme-bırakma tarihleri duyuruldu', 'body': 'Güz dönemi işlemleri başladı.', 'read': false, 'createdAt': _iso(const Duration(minutes: 12))},
          {'id': 2, 'type': 'EVENT', 'title': 'Kariyer Günleri yarın başlıyor', 'body': 'Konferans salonunda.', 'read': false, 'createdAt': _iso(const Duration(minutes: 40))},
          {'id': 3, 'type': 'COMMUNITY', 'title': 'Müzik Kulübü isteğiniz onaylandı', 'body': 'Etkinliklere katılabilirsiniz.', 'read': true, 'createdAt': _iso(const Duration(days: 1))},
        ],
      });
  }),
];

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
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null;
  setUpAll(loadTestFonts);

  for (final dark in [false, true]) {
    for (final shot in _shots) {
      final name = '${shot.file}${dark ? '_koyu' : ''}';
      testWidgets('ikon_sonra $name', skip: skip, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final b = FakeBackend();
        shot.setup?.call(b);
        final session = makeSession(b)..api.lang = 'tr';
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(session), dark, key));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await settle(tester, const Duration(milliseconds: 1000));
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
        debugNetworkImageHttpClientProvider = null; // test bitmeden sifirlanmali (invariant)
      });
    }
  }
}
