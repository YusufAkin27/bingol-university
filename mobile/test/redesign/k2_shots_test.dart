@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:bu_kampus/features/system/error_views.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/features/system/splash_screen.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// K2 (Paket 1: sistem tam ekranlari, seritler, hata ekranlari, izinler, QR tarayici) ekran goruntuleri.
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_mobile icinde):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/k2/uygulama' flutter test test/redesign/k2_shots_test.dart
/// Istege bagli: `K2_LANG=tr|en|ar`, `K2_ONLY=01,05`, `K2_MODES=light,dark,x13`.
const _dpr = 2.0;
String _lang = 'tr';

class _Scene {
  const _Scene(this.file, this.page, {this.after, this.settleMs = 700});
  final String file;
  final Widget Function() page;
  final Future<void> Function(WidgetTester t)? after;
  final int settleMs;
}

/// Ana Sayfa yerine duz zemin: seritler/kartlar ustunde calisir.
Widget _home({List<Widget> top = const [], List<Widget> stack = const []}) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: context.bu.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...top,
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
          ...stack,
        ],
      ),
    ),
  );
}

FakePermissionService _fakePerm(Map<AppPermission, PermState> m) => FakePermissionService(initial: m);

/// Kamera onizlemesi yerine koyu, fotografa benzer degrade.
Widget _fakeCam(BuildContext c) => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2E3A), Color(0xFF0D0F14)]),
      ),
    );

Future<void> _tapIn(WidgetTester t, Type parent, Type kind) async {
  final f = find.descendant(of: find.byType(parent), matching: find.byType(kind));
  if (f.evaluate().isEmpty) return;
  await t.tap(f.last);
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 400));
}

PushBannerCenter? _center;

final _scenes = <_Scene>[
  _Scene('01_splash', () => const SplashScreen(), settleMs: 300),
  _Scene('02_guncelleme_gerekli',
      () => UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '2.1.0', current: '2.0.3', onRetry: () {})),
  _Scene('03_bakim', () => MaintenanceScreen(onRetry: () {})),
  _Scene('04_baglanti_yok', () => OfflineScreen(onRetry: () {})),
  _Scene('05_erisim_kapali', () => AccessBlockedScreen(onRetry: () {})),
  // 06_serit_cevrimdisi KALDIRILDI (kullanici karari 2026-10-30): pasif "Internet baglantisi yok / Kayitli veriler
  // gosteriliyor / N mesaj gonderilecek / Son guncelleme" seritleri artik yok; bakim ve guncelleme seritleri (07) kalir.
  _Scene(
    '07_serit_bakim_duyuru',
    () => Builder(
      builder: (c) => _home(top: [
        GateNoticeStrip(icon: LucideIcons.wrench, text: c.l10n.sistemuiMaintBand, kind: GateNoticeKind.maintenance),
        GateNoticeStrip(
          icon: LucideIcons.megaphone,
          text: _lang == 'ar'
              ? 'ستُجرى صيانة مجدولة غدًا من الساعة 10:00 إلى 12:00.'
              : (_lang == 'en' ? 'Planned maintenance tomorrow between 10:00 and 12:00.' : 'Yarın 10.00-12.00 arası planlı bakım yapılacaktır.'),
          kind: GateNoticeKind.announcement,
          onClose: () {},
        ),
      ]),
    ),
  ),
  _Scene(
    '08_guncelleme_karti',
    () => _home(stack: [
      PositionedDirectional(
        start: 16,
        end: 16,
        bottom: 92,
        child: UpdateNotice(latest: '2.1.0', storeUrl: 'https://example.com', onClose: () {}),
      ),
    ]),
  ),
  _Scene(
    '09_push_karti',
    () => _home(),
    after: (t) async {
      final center = _center = PushBannerCenter(duration: const Duration(hours: 1));
      final item = BannerItem(key: 'conv-1', title: 'Elif Yıldız', body: 'Yarınki toplantıyı unutma', data: const {'conversationId': '1'});
      center.show(item, onTap: (_) {});
      center.show(item, onTap: (_) {});
      center.show(item, onTap: (_) {});
      await t.pump(const Duration(milliseconds: 400));
    },
  ),
  _Scene('10_hata_cizim', () => const RenderErrorView()),
  _Scene('11_hata_yapilandirma', () => const ConfigErrorView(origin: 'http://10.0.2.2:8080')),
  _Scene('12_izin_giris', () => PermissionsPage(service: _fakePerm({}), onFinished: () {})),
  _Scene(
    '13_izin_durumlar',
    () => PermissionsPage(
      service: _fakePerm({AppPermission.notifications: PermState.granted, AppPermission.contacts: PermState.permanentlyDenied}),
      onFinished: () {},
    ),
  ),
  _Scene(
    '14_izin_sheet',
    () => QrScanPage(permissionService: _fakePerm({AppPermission.camera: PermState.permanentlyDenied}), scannerBuilder: _fakeCam),
  ),
  _Scene(
    '15_qr_tara',
    () => QrScanPage(permissionService: _fakePerm({AppPermission.camera: PermState.granted}), scannerBuilder: _fakeCam),
  ),
  _Scene(
    '16_qr_izin_yok',
    () => QrScanPage(permissionService: _fakePerm({AppPermission.camera: PermState.permanentlyDenied}), scannerBuilder: _fakeCam),
    after: (t) async => _tapIn(t, BottomSheet, TextButton),
  ),
  _Scene(
    '17_qr_hata',
    () => QrScanPage(
      permissionService: _fakePerm({AppPermission.camera: PermState.permanentlyDenied}),
      scannerBuilder: _fakeCam,
      onSubmit: (code) async => _lang == 'ar' ? 'هذا الرمز يخص فعالية أخرى.' : (_lang == 'en' ? 'This code belongs to another event.' : 'Bu kod başka bir etkinliğe ait.'),
    ),
    after: (t) async {
      await _tapIn(t, BottomSheet, TextButton);
      await t.enterText(find.byType(TextField), 'K7M4QX');
      await t.pump();
      await t.tap(find.byType(BuButton).last, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
    },
  ),
  _Scene(
    '18_qr_hata_kamera',
    () => QrScanPage(
      permissionService: _fakePerm({AppPermission.camera: PermState.granted}),
      scannerBuilder: _fakeCam,
      onSubmit: (code) async => _lang == 'ar' ? 'هذا الرمز يخص فعالية أخرى.' : (_lang == 'en' ? 'This code belongs to another event.' : 'Bu kod başka bir etkinliğe ait.'),
    ),
    after: (t) async {
      await t.enterText(find.byType(TextField), 'K7M4QX');
      await t.pump();
      final submit = find.byIcon(LucideIcons.arrowRight);
      await t.tap(submit.last, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
    },
  ),
  _Scene(
    '19_qr_basari',
    () => QrScanPage(
      permissionService: _fakePerm({AppPermission.camera: PermState.permanentlyDenied}),
      scannerBuilder: _fakeCam,
      onSubmit: (code) async => null,
    ),
    after: (t) async {
      await _tapIn(t, BottomSheet, TextButton);
      await t.enterText(find.byType(TextField), 'K7M4QX');
      await t.pump();
      await t.tap(find.byType(BuButton).last, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
    },
  ),
];

Future<void> _loadMono() async {
  final f = File('C:/Windows/Fonts/consola.ttf');
  if (!f.existsSync()) return;
  final l = FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

Future<void> _loadFonts(bool arabic) async {
  await _loadMono();
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
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

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['K2_LANG'] ?? 'tr';
  final only = (Platform.environment['K2_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K2_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() async {
    mockSecureStorage();
    await _loadFonts(_lang == 'ar');
  });

  for (final v in variants) {
    for (final s in _scenes) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$_lang';
      testWidgets('k2 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
        tester.view.padding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.pumpWidget(_app(s.page(), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Navigator).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
        });
        await settle(tester, Duration(milliseconds: s.settleMs));
        if (s.after != null) {
          await s.after!(tester);
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
        _center?.hide();
        _center = null;
        await unmount(tester);
        await tester.pump(const Duration(seconds: 2));
        tester.takeException();
      });
    }
  }
}
