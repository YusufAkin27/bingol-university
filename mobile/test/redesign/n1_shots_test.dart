@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// N1 ekran goruntuleri: Stitch 48 (takip, profil duzenle), 49 (ayarlar, hesap, gizlilik), 08 (verilerim, hesap sil).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/n1/uygulama' flutter test test/redesign/n1_shots_test.dart
/// Istege bagli: `N1_LANG=tr|en|ar`, `N1_ONLY=01,05`, `N1_MODES=light,dark,x13` (varsayilan light).
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

/// Sahte kirpma: ya hata firlatir ya da hic tamamlanmaz (yukleniyor durumu).
Future<Uint8List?> _failCrop(ImageSource _) => Future<Uint8List?>.error(ImageException('TOO_LARGE'));
Future<Uint8List?> _hangCrop(ImageSource _) => Completer<Uint8List?>().future;

// ---------------------------------------------------------------------------------------------------------------
// Sahte veri

const _names = ['Mehmet Demir', 'Zeynep Kaya', 'Burak Şahin', 'Ayşe Nur Çelik', 'Emre Yılmaz'];
const _depts = [
  'Bilgisayar Mühendisliği',
  'Moleküler Biyoloji ve Genetik',
  'İktisadi ve İdari Bilimler',
  'İlahiyat Fakültesi',
  'Diş Hekimliği Fakültesi',
];

List<Map<String, dynamic>> _people({int n = 5, int offset = 0, bool reasons = false}) => [
      for (var i = 0; i < n; i++)
        {
          'id': 20 + i + offset,
          'displayName': _names[(i + offset) % _names.length],
          'department': _depts[(i + offset) % _depts.length],
          'classYear': 1 + (i + 2) % 4,
          'followedByMe': !reasons && const [false, true, true, false, true][i % 5],
          if (!reasons) 'followsMe': const [true, true, false, true, true][i % 5],
          if (reasons) 'reason': _s('Aynı bölümden 14 ortak takipçi', 'Same department, 14 mutual', 'نفس القسم، 14 مشتركًا'),
        },
    ];

void _follow(FakeBackend b) {
  b
    ..on('/users/7/followers*', {'items': _people(), 'nextCursor': null, 'total': 128})
    ..on('/users/7/following*', {'items': _people(offset: 2), 'nextCursor': null, 'total': 94});
}

Map<String, dynamic> _profile({String name = 'Elif Yıldız', String dept = 'Bilgisayar Mühendisliği'}) => {
      'id': 1,
      'displayName': name,
      'email': 'elif.yildiz@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': dept,
      'grade': '3',
      'bio': _s('Bilgisayar mühendisliği öğrencisiyim. Kampüs kütüphanesinde ve inovasyon kulübünde aktifim.',
          'I am a computer engineering student.', 'أنا طالب هندسة حاسوب.'),
      'showEmail': true,
      'language': _lang,
    };

void _privacy(FakeBackend b) {
  b
    ..on('/users/me/privacy', {
      'avatar': 'EVERYONE',
      'bio': 'SHARED_CONTEXT',
      'faculty': 'EVERYONE',
      'department': 'EVERYONE',
      'classYear': 'SHARED_CONTEXT',
    })
    ..on('/users/me', {'id': 1, 'showEmail': false})
    ..on('/users/me/blocks*', {'items': <Object>[]});
}

void _settings(FakeBackend b) => b.on('/users/me', {'id': 1, 'showEmail': true, 'language': _lang});

FakeResult? Function(dynamic, String) _failOn(String method, String path, int status, String code, String message) =>
    (req, p) => (req.method == method && p == path)
        ? FakeResult.json({'code': code, 'message': message}, status: status)
        : null;

Future<void> _enter(WidgetTester t, Finder f, String text) async {
  await t.enterText(f, text);
  await t.pump();
}

void _profileBase(FakeBackend b) {
  b
    ..on('/me/summary', {'unreadNotifications': 2, 'unreadMessages': 3, 'communities': 8, 'events': 19, 'bookmarks': 12})
    ..on('/users/me', {..._profile(name: 'Defne Kaya'), 'email': 'defne.kaya@bingol.edu.tr', 'bio': '', 'showEmail': false})
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false});
}

/// Profil sekmesi + yuzen hap gezinme (Profil secili).
Widget _profileShell(Session s, {int index = 4, int badge = 3}) => Scaffold(
      extendBody: true,
      body: ProfileTab(session: s, themeController: ThemeController()),
      bottomNavigationBar: FloatingNav(index: index, onChanged: (_) {}, chatBadge: ValueNotifier<int>(badge)),
    );

// ---------------------------------------------------------------------------------------------------------------

final _shots = <_Shot>[
  // ---- 48: takip
  _Shot('01_takipciler', (b, s) => FollowListPage(session: s, userId: 7, followers: true, name: 'Elif Yıldız'),
      setup: _follow),
  _Shot('02_takip_edilenler', (b, s) => FollowListPage(session: s, userId: 7, followers: false, name: 'Elif Yıldız'),
      setup: _follow),
  _Shot('03_takip_arama_sonucsuz', (b, s) => FollowListPage(session: s, userId: 7, followers: false, name: 'Elif Yıldız'),
      setup: _follow, after: (t) async => _enter(t, find.byType(TextField).first, 'Mehmet Ali K.')),
  _Shot('04_takip_hata', (b, s) => FollowListPage(session: s, userId: 7, followers: false, name: 'Elif Yıldız'),
      setup: (b) => b.fail('/users/7/following', status: 500, code: 'SERVER_ERROR', message: 'Sunucuyla iletişim kurulurken bir aksama yaşandı.')),
  _Shot('05_takip_bos', (b, s) => FollowListPage(session: s, userId: 7, followers: true, name: 'Elif Yıldız'),
      setup: (b) => b
        ..on('/users/7/followers*', {'items': <Object>[], 'nextCursor': null, 'total': 0})
        ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0})),
  _Shot('05b_takip_edilenler_bos', (b, s) => FollowListPage(session: s, userId: 7, followers: false, name: 'Elif Yıldız'),
      setup: (b) => b
        ..on('/users/7/followers*', {'items': <Object>[], 'nextCursor': null, 'total': 0})
        ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0})),
  _Shot('06_oneriler', (b, s) => FollowSuggestionsPage(session: s),
      setup: (b) => b.on('/users/me/follow-suggestions*', {'items': _people(n: 3, reasons: true)})),
  _Shot('07_oneriler_iskelet', (b, s) => FollowSuggestionsPage(session: s), setup: (b) {
    b.on('/users/me/follow-suggestions*', {'items': _people(n: 3, reasons: true)});
    b.delay = const Duration(seconds: 4);
  }, leaveLoading: true),
  _Shot('08_oneriler_bos', (b, s) => FollowSuggestionsPage(session: s),
      setup: (b) => b.on('/users/me/follow-suggestions*', {'items': <Object>[]})),
  // ---- 48: profil duzenle
  _Shot('09_profil_duzenle', (b, s) => EditProfilePage(session: s, profile: _profile()), height: 1000),
  _Shot('10_profil_duzenle_hatalar', (b, s) => EditProfilePage(
        session: s,
        profile: _profile(name: 'E', dept: ''),
        cropPhoto: _failCrop,
      ), height: 1100, after: (t) async {
    await t.tap(find.byKey(const ValueKey('avatar-camera')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text(_s('Galeriden seç', 'Choose from gallery', 'اختيار من المعرض')).first);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    // bolum alani bos birakilarak dogrulama hatasi
    await t.tap(find.byKey(const ValueKey('edit-save')));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('11_profil_duzenle_yukleniyor', (b, s) => EditProfilePage(
        session: s,
        profile: _profile(),
        cropPhoto: _hangCrop,
      ), height: 1000, after: (t) async {
    await t.tap(find.byKey(const ValueKey('avatar-camera')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text(_s('Galeriden seç', 'Choose from gallery', 'اختيار من المعرض')).first);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
  }, leaveLoading: true),
  _Shot('12_degisiklikleri_at', (b, s) => EditProfilePage(session: s, profile: _profile()), after: (t) async {
    await _enter(t, find.byKey(const ValueKey('edit-name')), 'Elif Yıldız Demir');
    await t.tap(find.byIcon(LucideIcons.arrowLeft).first);
    await t.pump(const Duration(milliseconds: 500));
  }),
  // ---- 49: ayarlar
  _Shot('13_ayarlar', (b, s) => SettingsPage(session: s, themeController: ThemeController(), localeController: LocaleController.current),
      setup: _settings, height: 900),
  _Shot('14_dil_sheet', (b, s) => SettingsPage(session: s, themeController: ThemeController(), localeController: LocaleController.current),
      setup: _settings, after: (t) async {
    await t.tap(find.byKey(const ValueKey('settings-language')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('15_hesap_guvenlik', (b, s) => AccountSecurityPage(session: s), height: 900),
  _Shot('16_hesap_guvenlik_hatalar', (b, s) => AccountSecurityPage(session: s), height: 900, after: (t) async {
    await _enter(t, find.byKey(const ValueKey('sec-current')), 'eskiSifre1');
    await _enter(t, find.byKey(const ValueKey('sec-new')), 'eskiSifre1');
    await _enter(t, find.byKey(const ValueKey('sec-repeat')), 'baskaSifre2');
    await t.tap(find.byKey(const ValueKey('sec-submit')));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('17_gizlilik', (b, s) => PrivacyDataPage(session: s), setup: _privacy, height: 1100),
  _Shot('18_gizlilik_hata', (b, s) => PrivacyDataPage(session: s), setup: (b) {
    _privacy(b);
    b.handlers.add(_failOn('PATCH', '/users/me/privacy', 500, 'SERVER_ERROR', ''));
  }, height: 1100, after: (t) async {
    await t.tap(find.text(_s('Yalnızca ben', 'Only me', 'أنا فقط')).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  // ---- 08: verilerim, hesabi sil
  _Shot('19_verilerim', (b, s) => MyDataPage(session: s)),
  _Shot('20_verilerim_sinir', (b, s) => MyDataPage(session: s), height: 960, setup: (b) {
    b.handlers.add(_failOn('GET', '/users/me/export', 429, 'RATE_LIMITED', _s('Günde en fazla 3 kez veri indirebilirsiniz.', 'You can download your data up to 3 times a day.', 'يمكنك تنزيل بياناتك 3 مرات يوميًا.')));
  }, after: (t) async {
    await t.tap(find.byKey(const ValueKey('my-data-download')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('20b_verilerim_toast_sinir', (b, s) => MyDataPage(session: s), height: 1000, setup: (b) {
    // Test ortaminda yerel paylasim kodu yok: sahte teslim (gercek ExportShare dosya/kanal kullanir).
    ExportShare.deliver = (json, title) async => true;
    ExportShare.purge = () async {};
    var n = 0;
    b.handlers.add((req, path) {
      if (req.method != 'GET' || path != '/users/me/export') return null;
      n++;
      return n == 1
          ? const FakeResult.json({'profile': {'id': 1}})
          : FakeResult.json({'code': 'RATE_LIMITED', 'message': _s('Günde en fazla 3 kez veri indirebilirsiniz.', 'You can download your data up to 3 times a day.', 'يمكنك تنزيل بياناتك 3 مرات يوميًا.')}, status: 429);
    });
  }, after: (t) async {
    await t.tap(find.byKey(const ValueKey('my-data-download')));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('my-data-download')));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('21_hesabi_sil', (b, s) => DeleteAccountPage(session: s), height: 900),
  _Shot('22_hesabi_sil_onayli', (b, s) => DeleteAccountPage(session: s), height: 900, after: (t) async {
    await t.scrollUntilVisible(find.byKey(const ValueKey('delete-ack')), 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('delete-ack')));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('23_silmeyi_onayla', (b, s) => DeleteAccountPage(session: s), setup: (b) {
    b.handlers.add(_failOn('DELETE', '/users/me', 403, 'WRONG_PASSWORD', ''));
  }, after: (t) async {
    await t.scrollUntilVisible(find.byKey(const ValueKey('delete-ack')), 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('delete-ack')));
    await t.pump(const Duration(milliseconds: 300));
    await t.scrollUntilVisible(find.byKey(const ValueKey('delete-continue')), 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('delete-continue')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await _enter(t, find.byKey(const ValueKey('delete-password')), 'yanlis1234');
    await t.tap(find.byKey(const ValueKey('delete-submit')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  // ---- Profil sekmesi + gezinme
  _Shot('30_profil', (b, s) => _profileShell(s), setup: _profileBase, height: 1500),
  _Shot('31_profil_ust', (b, s) => _profileShell(s), setup: _profileBase),
  _Shot('32_profil_yukleniyor', (b, s) => _profileShell(s), setup: (b) {
    _profileBase(b);
    b.delay = const Duration(seconds: 4);
  }, leaveLoading: true),
  _Shot('33_profil_hata', (b, s) => _profileShell(s),
      setup: (b) => b.fail('/users/me', status: 500, code: 'SERVER_ERROR', message: 'Bağlantı koptu')),
  _Shot('36_profil_alt', (b, s) => _profileShell(s), setup: _profileBase, after: (t) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('34_gezinme_ana', (b, s) => _profileShell(s, index: 0, badge: 7), setup: _profileBase),
  _Shot('35_gezinme_sohbet', (b, s) => _profileShell(s, index: 2, badge: 0), setup: _profileBase),
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
  _lang = Platform.environment['N1_LANG'] ?? 'tr';
  final only = (Platform.environment['N1_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['N1_MODES'] ?? 'light').split(',');
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
      testWidgets('n1 $name', skip: skip != null, (tester) async {
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
        if (shot.leaveLoading) {
          // Zincirleme istekler (profil -> istatistik) bitsin: bekleyen zamanlayici kalmasin.
          await tester.pump(const Duration(seconds: 90));
          await tester.pump(const Duration(seconds: 90));
        }
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
