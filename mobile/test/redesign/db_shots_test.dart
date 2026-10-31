import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// DB grubu (kabuk, Ana Sayfa, Yemek, Bildirimler, Profil ve hesap) ekran goruntuleri (onceki/sonra).
/// Uretim: DB_OUT='C:/bu_qa/shots/tasarim/db/sonra' DB_W=390 flutter test test/redesign/db_shots_test.dart
/// Istege bagli: `DB_LANG=tr|en|ar`, `DB_ONLY=home,yemek`, `DB_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';
final double _w = double.tryParse(Platform.environment['DB_W'] ?? '') ?? 390;

String _today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String _day(int offset) {
  final n = DateTime.now().add(Duration(days: offset));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

const _user = {
  'id': 1,
  'email': 'ayse.yilmaz@ogr.bingol.edu.tr',
  'displayName': 'Ayşe Yılmaz',
  'faculty': 'Mühendislik-Mimarlık Fakültesi',
  'department': 'Bilgisayar Mühendisliği',
  'classYear': 3,
  'bio': 'Yazılım kulübünde ve kampüs etkinliklerinde yer alıyorum.',
  'showEmail': false,
  'language': 'tr',
};

const _prefs = {
  'news': true,
  'announcements': true,
  'events': true,
  'communities': false,
  'messages': true,
  'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
  'subtypes': {
    'MESSAGE_DIRECT': true,
    'MESSAGE_GROUP': true,
    'EVENT_REMINDER': true,
    'EVENT_UPDATE': true,
    'COMMUNITY_POST': true,
    'USER_FOLLOW': true,
    'POST_LIKE': true,
  },
};

class _Shot {
  const _Shot(this.group, this.file, this.build, {this.height = 844, this.data, this.loading = false});
  final String group;
  final String file;
  final Widget Function(FakeBackend b) build;
  final double height;
  final void Function(FakeBackend b)? data;
  final bool loading;
}

void _homeData(FakeBackend b) {
  b
    ..on('/me/summary', {'unreadNotifications': 3, 'unreadMessages': 2, 'communities': 2, 'upcomingEvents': 1})
    ..on('/menu/today', {
      'date': _today(),
      'items': ['Mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Cacık'],
    })
    ..on('/events/featured', {
      'id': 12,
      'source': 'USER',
      'title': 'Kampüste Sonbahar Fotoğraf Yürüyüşü',
      'startsAt': DateTime.now().add(const Duration(days: 2, hours: 3)).toUtc().toIso8601String(),
      'location': 'Merkez Kütüphane Önü',
      'communityName': 'Fotoğraf Kulübü',
      'goingCount': 14,
      'capacity': 40,
      'myRsvp': null,
    })
    ..on('/news?type=HABER*', {
      'items': [
        {'id': 1, 'type': 'HABER', 'title': 'Üniversitemizde Bahar Dönemi Kayıt Takvimi Açıklandı', 'publishedDate': _day(-1), 'imageUrl': null},
        {'id': 2, 'type': 'HABER', 'title': 'Teknoloji Transfer Ofisi Girişimcilik Buluşması', 'publishedDate': _day(-3), 'imageUrl': null},
        {'id': 3, 'type': 'HABER', 'title': 'Kütüphane Sınav Haftası Çalışma Saatleri', 'publishedDate': _day(-5), 'imageUrl': null},
      ],
      'totalPages': 1,
    });
}

List<Map<String, dynamic>> _month() => [
      for (var d = -2; d <= 6; d++)
        {
          'date': _day(d),
          'items': ['Mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Cacık'],
          'dishes': [
            {'name': 'Mercimek çorbası', 'kcal': 160},
            {'name': 'Orman kebabı', 'kcal': 420},
            {'name': 'Pirinç pilavı', 'kcal': 280},
            {'name': 'Cacık', 'kcal': null},
          ],
          'totalKcal': 860,
          'kcalComplete': false,
        },
    ];

Map<String, dynamic> _notifs() {
  final now = DateTime.now();
  return {
    'unreadCount': 2,
    'nextCursor': null,
    'items': [
      {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Ders ekleme-bırakma tarihleri duyuruldu', 'read': false, 'createdAt': now.toIso8601String()},
      {'id': 2, 'type': 'EVENT', 'title': 'Kariyer günleri yarın başlıyor', 'read': false, 'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String()},
      {'id': 3, 'type': 'COMMUNITY', 'title': 'Müzik Kulübü isteğiniz onaylandı', 'read': true, 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String()},
      {'id': 4, 'type': 'MESSAGE', 'title': 'Mehmet Kaya mesaj gönderdi', 'read': true, 'createdAt': now.subtract(const Duration(days: 3)).toIso8601String()},
      {'id': 5, 'type': 'ANNOUNCEMENT', 'title': 'Yemekhane yeni dönem fiyat bilgilendirmesi', 'read': true, 'createdAt': now.subtract(const Duration(days: 9)).toIso8601String()},
    ],
  };
}

void _profile(FakeBackend b) => b
  ..on('/users/me', _user)
  ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4})
  ..on('/notifications/preferences', _prefs)
  ..on('/users/me/privacy', {'showEmail': false, 'showFaculty': true, 'showDepartment': true, 'showBio': true});

final _shots = <_Shot>[
  _Shot('home', '01_ana_dolu', (b) => HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}), height: 1000, data: _homeData),
  _Shot('home', '02_ana_yukleniyor', (b) => HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}), data: _homeData, loading: true),
  _Shot('home', '03_ana_bos', (b) => HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}), height: 1000, data: (b) {
    b
      ..on('/menu/today', {'date': _today(), 'items': <Object>[]})
      ..on('/news?type=HABER*', {'items': <Object>[], 'totalPages': 0});
  }),
  _Shot('yemek', '10_yemek_dolu', (b) => MenuPage(session: makeSession(b)), data: (b) => b.on('/menu', _month())),
  _Shot('yemek', '11_yemek_bos', (b) => MenuPage(session: makeSession(b)), data: (b) => b.on('/menu', <Object>[])),
  _Shot('yemek', '12_yemek_hata', (b) => MenuPage(session: makeSession(b)), data: (b) => b.fail('/menu', status: 500)),
  _Shot('bildirim', '20_bildirim_dolu', (b) => NotificationsPage(session: makeSession(b)), data: (b) => b.on('/notifications', _notifs())),
  _Shot('bildirim', '21_bildirim_bos', (b) => NotificationsPage(session: makeSession(b)),
      data: (b) => b.on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]})),
  _Shot('bildirim', '22_bildirim_hata', (b) => NotificationsPage(session: makeSession(b)), data: (b) => b.fail('/notifications', status: 500)),
  _Shot('profil', '30_profil', (b) => ProfileTab(session: makeSession(b), themeController: ThemeController()), height: 900, data: _profile),
  _Shot('profil', '31_ayarlar', (b) => SettingsPage(session: makeSession(b), themeController: ThemeController()), height: 900, data: _profile),
  _Shot('profil', '32_gizlilik', (b) => PrivacyDataPage(session: makeSession(b)), data: _profile),
  _Shot('profil', '33_bildirim_tercihleri', (b) => NotificationPrefsPage(session: makeSession(b)), height: 1000, data: _profile),
  _Shot('profil', '34_verilerim', (b) => MyDataPage(session: makeSession(b)), data: _profile),
  _Shot('profil', '35_hesap_silme', (b) => DeleteAccountPage(session: makeSession(b)), height: 900, data: _profile),
  _Shot('profil', '36_hesap_guvenligi', (b) => AccountSecurityPage(session: makeSession(b)), data: _profile),
  _Shot('profil', '37_engellenenler', (b) => BlockedUsersPage(session: makeSession(b)),
      data: (b) => b.on('/users/me/blocks', [
            {'id': 5, 'displayName': 'Engellenen Kişi'},
            {'id': 6, 'displayName': 'Başka Bir Kullanıcı'},
          ])),
];

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
  final out = Platform.environment['DB_OUT'];
  final skip = out == null ? 'DB_OUT tanimli degil' : null;
  _lang = Platform.environment['DB_LANG'] ?? 'tr';
  final only = (Platform.environment['DB_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['DB_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.group == o || shot.file.startsWith(o))) continue;
      final name = '${shot.file}${v.$1}_$_lang';
      testWidgets('db $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        shot.data?.call(b);
        if (shot.loading) b.delay = const Duration(seconds: 4);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(Scaffold(body: shot.build(b)), v.$2, key, v.$3));
        if (!shot.loading) {
          await settle(tester, const Duration(milliseconds: 1200));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump(const Duration(milliseconds: 600));
        } else {
          await tester.pump(const Duration(milliseconds: 400));
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
        if (shot.loading) {
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(seconds: 30));
          }
        }
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
