@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Paket 18 ekran goruntuleri: kabuk (gezinme), Profil sekmesi, takip listesi/onerileri, kullanici gonderileri.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p3/profile/onceki' flutter test test/redesign/p18_shots_test.dart
/// Istege bagli: `P3P_LANG=tr|en|ar`, `P3P_ONLY=01,05`, `P3P_MODES=light,dark,x13` (varsayilan light,dark).
const _dpr = 2.5;
String _lang = 'tr';

String _s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.after, this.height = 844, this.leaveLoading = false});
  final String file;
  final Widget Function(FakeBackend b, Session s) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
  final double height;
  final bool leaveLoading;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

// ---------------------------------------------------------------------------------------------------------------
// Sahte veri

const _names = ['Emre Yılmaz', 'Selin Kaya', 'Burak Çelik', 'Zeynep Demir', 'Mehmet Aksoy', 'Elif Şahin', 'Can Öztürk'];
const _depts = [
  'Bilgisayar Mühendisliği',
  'İktisat',
  'Hukuk',
  'Tıp',
  'Elektrik-Elektronik Mühendisliği',
  'Psikoloji',
  'Mimarlık',
];

void _base(FakeBackend b) {
  b
    ..on('/me/summary', {
      'unreadNotifications': 2,
      'unreadMessages': 3,
      'communities': 3,
      'events': 4,
      'bookmarks': 12,
      'upcomingEvents': 2,
    })
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'email': 'seed.ayse@bingol.edu.tr',
      'faculty': _s('Mühendislik Fakültesi', 'Faculty of Engineering', 'كلية الهندسة'),
      'department': _s('Bilgisayar Mühendisliği', 'Computer Engineering', 'هندسة الحاسوب'),
      'grade': '3',
      'bio': _s('Yazılım, satranç ve kampüs etkinlikleri.', 'Software, chess and campus events.',
          'البرمجة والشطرنج وفعاليات الحرم الجامعي.'),
      'showEmail': false,
      'language': _lang,
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false})
    ..on('/users/me/privacy', {
      'avatar': 'EVERYONE',
      'bio': 'SHARED_CONTEXT',
      'department': 'EVERYONE',
      'faculty': 'ONLY_ME',
      'classYear': 'SHARED_CONTEXT',
      'avatarHiddenByModeration': false,
    })
    ..on('/users/me/blocks*', [
      for (var i = 0; i < 3; i++) {'id': 40 + i, 'displayName': _names[i + 2], 'department': _depts[i + 2]},
    ])
    ..on('/me/communities*', {
      'items': [
        for (var i = 0; i < 3; i++)
          {
            'id': 5 + i,
            'name': ['Satranç Kulübü', 'Yazılım Topluluğu', 'Fotoğraf Kulübü'][i],
            'category': 'SOCIAL',
            'memberCount': 40 + i * 12,
            'myRole': i == 0 ? 'ADMIN' : 'MEMBER',
          },
      ],
      'nextCursor': null,
    })
    ..on('/status', {
      'NEWS': {'maintenance': false},
      'MENU': {'maintenance': false},
    });
}

Map<String, dynamic> _other() => {
      'id': 2,
      'displayName': 'Mehmet Kaya',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'classYear': 3,
      'bio': 'Merhaba, ben Mehmet. Kampüste robotik ve müzik.',
      'avatarUrl': null,
      'email': 'mehmet@bingol.edu.tr',
    };

List<Map<String, dynamic>> _people(int n, {bool followsMe = true, int offset = 0}) => [
      for (var i = 0; i < n; i++)
        {
          'id': 20 + i + offset,
          'displayName': _names[(i + offset) % _names.length],
          'department': _depts[(i + offset) % _depts.length],
          'followedByMe': i % 3 == 0,
          if (followsMe) 'followsMe': i % 2 == 0,
        },
    ];

void _follow(FakeBackend b) {
  b
    ..on('/users/7/followers*', {'items': _people(7), 'nextCursor': null, 'total': 128})
    ..on('/users/7/following*', {'items': _people(5, offset: 2), 'nextCursor': null, 'total': 94});
}

// ---------------------------------------------------------------------------------------------------------------
// Ekranlar

Future<void> _tapIcon(WidgetTester t, IconData icon) async {
  await t.scrollUntilVisible(find.byIcon(icon), 200, scrollable: find.byType(Scrollable).first);
  await t.pump();
  await t.tap(find.byIcon(icon).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Widget _tab(Session s) => ProfileTab(session: s, themeController: ThemeController());

final _shots = <_Shot>[
  _Shot('01_profil', (b, s) => _tab(s), setup: _base),
  _Shot('02_profil_uzun', (b, s) => _tab(s), setup: _base, height: 1500),
  _Shot('03_profil_yukleniyor', (b, s) => _tab(s), setup: (b) {
    _base(b);
    b.delay = const Duration(seconds: 4);
  }, leaveLoading: true),
  _Shot('04_profil_hata', (b, s) => _tab(s), setup: (b) {
    _base(b);
    b.fail('/users/me', status: 500, code: 'SERVER_ERROR', message: 'Sunucu hatası');
  }),
  _Shot('05_profil_cikis', (b, s) => _tab(s), setup: _base, after: (t) async {
    final f = find.byKey(const ValueKey('profile-signout'));
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('06_baskasi', (b, s) => UserProfilePage(session: s, userId: 2, initialName: 'Mehmet'), setup: (b) {
    _base(b);
    b.on('/users/2', _other());
    b.on('/users/2/presence', {'online': true});
  }, height: 1100),
  _Shot('07_duzenle', (b, s) => EditProfilePage(session: s, profile: {
        'id': 1,
        'displayName': 'Ayşe Kaya',
        'email': 'seed.ayse@bingol.edu.tr',
        'faculty': 'Mühendislik Fakültesi',
        'department': 'Bilgisayar Mühendisliği',
        'grade': '3',
        'bio': 'Yazılım, satranç ve kampüs etkinlikleri.',
      }), setup: _base, height: 1500),
  _Shot('08_gizlilik', (b, s) => PrivacyDataPage(session: s), setup: _base, height: 1300),
  _Shot('09_hesap_guvenligi', (b, s) => AccountSecurityPage(session: s), setup: _base),
  _Shot('10_verilerim', (b, s) => MyDataPage(session: s), setup: _base),
  _Shot('11_hesap_sil', (b, s) => DeleteAccountPage(session: s), setup: _base, height: 1100),
  _Shot('12_engellenenler', (b, s) => BlockedUsersPage(session: s), setup: _base),
  _Shot('13_engellenenler_bos', (b, s) => BlockedUsersPage(session: s), setup: (b) {
    _base(b);
    b.on('/users/me/blocks*', <Object>[]);
  }),
  _Shot('14_ayarlar', (b, s) => SettingsPage(session: s, themeController: ThemeController()), setup: _base, height: 1000),
  _Shot('15_takipciler', (b, s) => FollowListPage(session: s, userId: 7, followers: true, name: 'Ayşe Demir'), setup: _follow),
  _Shot('16_oneriler', (b, s) => FollowSuggestionsPage(session: s), setup: (b) {
    b.on('/users/me/follow-suggestions*', {'items': _people(7, followsMe: false)});
  }),
  _Shot('17_kuluplerim', (b, s) => MyClubsPage(session: s), setup: _base),
  _Shot('18_etkinliklerim', (b, s) => MyEventsPage(session: s), setup: _base),
  _Shot('19_kayitli_haberler', (b, s) => SavedNewsPage(session: s), setup: _base),
];

// ---------------------------------------------------------------------------------------------------------------

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
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

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['P3P_LANG'] ?? 'tr';
  final only = (Platform.environment['P3P_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P3P_MODES'] ?? 'light,dark').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
      final name = '${shot.file}${v.suffix}_$_lang';
      testWidgets('p3p $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        shot.setup?.call(b);
        final session = makeSession(b)..api.lang = _lang;
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(b, session), v.dark, key, v.scale));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
        });
        await settle(tester, const Duration(milliseconds: 900));
        // Aga bagli gorseller (gonderi kucuk resimleri) yuklensin.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 150));
        if (shot.after != null) {
          await shot.after!(tester);
          await settle(tester, const Duration(milliseconds: 700));
        }
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
        if (shot.leaveLoading) await tester.pump(const Duration(seconds: 90));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
