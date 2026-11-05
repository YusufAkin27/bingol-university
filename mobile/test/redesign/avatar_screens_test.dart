import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_requests_page.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/home/home_suggestions.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/search/user_search_result_tile.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu_default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Varsayilan profil avatari: fotografsiz kullanicilarla ekranlar. Tasma/regresyon testleri HER kosuda calisir
/// (320/390 dp x 1.0/1.3 yazi, acik+koyu); PNG yalniz `STORE_SHOTS_OUT='C:/bu_qa/shots/avatar'` verilirse yazilir
/// (390 dp, acik + koyu).
String _iso(Duration ago) => DateTime.now().subtract(ago).toUtc().toIso8601String();

class _Screen {
  const _Screen(this.file, this.build, this.setup);
  final String file;
  final Widget Function(Session s) build;
  final void Function(FakeBackend b) setup;
}

Map<String, dynamic> _conv(int id, String type, String name, String text, {int unread = 0}) => {
      'id': id,
      'type': type,
      if (type == 'DIRECT') 'peer': {'id': 60 + id, 'displayName': name} else 'title': name,
      'unreadCount': unread,
      'lastMessage': {
        'id': 900 + id,
        'conversationId': id,
        'senderId': 60 + id,
        'text': text,
        'attachments': const [],
        'createdAt': _iso(Duration(minutes: 5 * id)),
      },
    };

final _screens = <_Screen>[
  _Screen('01_sohbet_listesi', (s) => ChatTab(session: s, connectRealtime: false), (b) {
    b
      ..on('/conversations/requests/count', {'count': 0})
      ..on('/conversations/unread-count', {'total': 3})
      ..on('/conversations*', {
        'items': [
          _conv(1, 'DIRECT', 'Mehmet Kaya', 'Yarınki ders notlarını atar mısın?', unread: 2),
          _conv(2, 'DIRECT', 'Zeynep Demir Çok Uzun Bir Soyadı Olan Öğrenci', 'Tamamdır, teşekkürler'),
          _conv(3, 'GROUP', 'Proje Grubu', 'Toplantı 15:00 de'),
          _conv(4, 'DIRECT', 'Burak Şahin', 'Görüşürüz'),
        ],
        'nextCursor': null,
      });
  }),
  _Screen('02_mesaj_istekleri', (s) => MessageRequestsPage(session: s), (b) {
    b
      ..on('/conversations/requests/count', {'count': 2})
      ..on('/conversations/requests*', {
        'items': [
          {..._conv(41, 'DIRECT', 'Zeynep Demir', 'Merhaba, ders notları için yazıyorum'), 'requestState': 'PENDING'},
          {..._conv(42, 'GROUP', 'Proje Grubu', 'Gruba hoş geldin'), 'requestState': 'PENDING'},
        ],
        'nextCursor': null,
      });
  }),
  _Screen('03_takipciler', (s) => FollowListPage(session: s, userId: 7, followers: true, name: 'Ayşe Kaya'), (b) {
    b
      ..on('/users/me', {'id': 1, 'displayName': 'Ayşe Kaya'})
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
  _Screen(
      '04_arama_kisi_satirlari',
      (s) => Scaffold(
            body: SafeArea(
              child: ListView(children: [
                for (final (i, n) in ['Emre Yılmaz', 'Selin Kaya Çok Uzun Bir Soyadı Olan Öğrenci', 'Burak Çelik'].indexed)
                  UserSearchResultTile(
                    session: s,
                    query: 'e',
                    user: SearchUser(id: 20 + i, name: n, department: 'Bilgisayar Mühendisliği', classYear: 2),
                  ),
              ]),
            ),
          ),
      (b) {}),
  _Screen(
      '05_ana_sayfa_oneriler',
      (s) => Scaffold(body: SafeArea(child: ListView(children: [HomeSuggestions(session: s)]))),
      (b) {
        b.on('/users/me/follow-suggestions*', {
          'items': [
            for (final (i, n) in ['Deniz Aksoy', 'Elif Yıldız', 'Kerem Aksoy Uzun Soyadlı Kişi'].indexed)
              {'id': 31 + i, 'displayName': n, 'department': 'Bilgisayar Müh.', 'followState': 'NONE'},
          ],
          'nextCursor': null,
        });
      }),
  _Screen('06_profil', (s) => ProfileTab(session: s, themeController: ThemeController()), (b) {
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
  }),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  setUpAll(loadTestFonts);

  Future<void> run(WidgetTester tester, _Screen sc,
      {required double width, required double height, required double dpr, required bool dark, required double scale, String? png}) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(width * dpr, height * dpr);
    tester.view.padding = FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
    tester.view.viewPadding = FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
    addTearDown(tester.view.reset);
    final b = FakeBackend();
    sc.setup(b);
    final session = makeSession(b);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    final key = GlobalKey();
    await tester.pumpWidget(_app(sc.build(session), dark, key, scale));
    await settle(tester, const Duration(milliseconds: 600));
    // Varlik gorseli gercek asenkron IO ister: bir kez cozulsun, sonra kare ciz.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await settle(tester, const Duration(milliseconds: 600));
    final err = tester.takeException();
    if (err != null) fail('Istisna: $err');
    // Fotografsiz kullanicilar: varsayilan avatar gorseli cizilmeli.
    expect(find.byType(BuDefaultAvatar), findsWidgets, reason: sc.file);
    if (png != null) {
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory(out!)..createSync(recursive: true);
        File('${dir.path}/$png.png').writeAsBytesSync(data.buffer.asUint8List());
      });
    }
    await unmount(tester);
  }

  for (final sc in _screens) {
    for (final w in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final dark in [false, true]) {
          final name = '${sc.file} ${w.toInt()}dp x$scale ${dark ? 'koyu' : 'acik'}';
          testWidgets('avatar tasma yok: $name', (tester) async {
            await run(tester, sc, width: w, height: 760, dpr: 1, dark: dark, scale: scale);
          });
        }
      }
    }
    if (out != null) {
      for (final dark in [false, true]) {
        testWidgets('avatar goruntu: ${sc.file} ${dark ? 'koyu' : 'acik'}', (tester) async {
          await run(tester, sc,
              width: 390, height: 844, dpr: 2.5, dark: dark, scale: 1.0, png: '${sc.file}_${dark ? 'koyu' : 'acik'}');
        });
      }
    }
  }
}
