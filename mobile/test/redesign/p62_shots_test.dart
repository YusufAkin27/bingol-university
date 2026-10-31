import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// MENU grubu Stitch v3 BIREBIR ekran goruntuleri (390 x 844, dpr 2): referans PNG ile yan yana kiyas icin.
/// Uretim: P62_OUT='C:/bu_qa/shots/tasarim/p3/birebir/menu' P62_MODES=light,dark flutter test test/redesign/p62_shots_test.dart
String _d(int o) {
  final n = DateTime.now().add(Duration(days: o));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

class _Scene {
  const _Scene(this.file, this.build, this.data, {this.height = 844});
  final String file;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b) data;
  final double height;
}

class _PrefsOnly extends StatelessWidget {
  const _PrefsOnly({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => Column(children: [
        BuHeader(title: context.l10n.profil1Notifications, onBack: () {}),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [NotificationPrefsGroup(session: session)],
          ),
        ),
      ]);
}

final _scenes = <_Scene>[
  _Scene('10_yemek', (b) => MenuPage(session: makeSession(b)), (b) {
    b.on('/menu', [
      for (var o = -2; o <= 6; o++)
        {
          'date': _d(o),
          'items': ['Mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Cacık'],
          'dishes': [
            {'name': 'Mercimek çorbası', 'kcal': 160},
            {'name': 'Orman kebabı', 'kcal': 420},
            {'name': 'Pirinç pilavı', 'kcal': 280},
            {'name': 'Cacık', 'kcal': 70},
          ],
          'totalKcal': 930,
          'kcalComplete': true,
        },
    ]);
  }),
  _Scene('11_yemek_bayat', (b) => MenuPage(session: makeSession(b)), (b) {
    b
      ..on('/menu', [
        for (var o = -2; o <= 6; o++)
          {
            'date': _d(o),
            'items': ['Kuru fasulye', 'Bulgur pilavı', 'Turşu'],
            'dishes': [
              {'name': 'Kuru fasulye', 'kcal': 290},
              {'name': 'Bulgur pilavı', 'kcal': 260},
              {'name': 'Turşu', 'kcal': null},
            ],
            'totalKcal': 550,
            'kcalComplete': false,
          },
      ])
      ..on('/status', {'MENU': {'maintenance': true}});
  }),
  _Scene('12_yemek_bos', (b) => MenuPage(session: makeSession(b)), (b) {
    b
      ..on('/menu', <Object>[])
      ..on('/status', {'MENU': {'maintenance': true}});
  }),
  _Scene('13_bildirimler', (b) => NotificationsPage(session: makeSession(b)), (b) {
    final now = DateTime.now();
    b.on('/notifications', {
      'unreadCount': 2,
      'nextCursor': null,
      'items': [
        {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Ders ekleme-bırakma tarihleri duyuruldu', 'body': 'Güz dönemi ders ekleme ve bırakma işlemleri başladı.', 'read': false, 'createdAt': now.toIso8601String()},
        {'id': 2, 'type': 'EVENT', 'title': 'Kariyer Günleri yarın başlıyor', 'body': 'Konferans salonunda düzenlenecek oturum detayları.', 'read': false, 'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String()},
        {'id': 3, 'type': 'COMMUNITY', 'title': 'Müzik Kulübü isteğiniz onaylandı', 'body': 'Kulüp etkinliklerine artık katılabilirsiniz.', 'read': true, 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String()},
        {'id': 4, 'type': 'MESSAGE', 'title': 'Mehmet Kaya mesaj gönderdi', 'body': 'Notları paylaştım kontrol edebilir misin?', 'read': true, 'createdAt': now.subtract(const Duration(days: 9)).toIso8601String()},
      ],
    });
  }),
  _Scene('14_bildirimler_bos', (b) => NotificationsPage(session: makeSession(b)),
      (b) => b.on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]})),
  // Push durumu test ortaminda okunamaz (Firebase yok): referanstaki "izin verildi" karti yerine yalniz gruplar cizilir.
  _Scene('15_bildirim_tercihleri', (b) => _PrefsOnly(session: makeSession(b)), (b) {
    b.on('/notifications/preferences', {
      'news': true,
      'announcements': true,
      'events': true,
      'communities': false,
      'messages': true,
      'polls': true,
      'academicAnnouncements': true,
      'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
      'subtypes': {'MESSAGE_DIRECT': true, 'MESSAGE_GROUP': true, 'EVENT_UPDATE': true, 'COMMUNITY_POST': true},
    });
  }, height: 1000),
];

void main() {
  final out = Platform.environment['P62_OUT'];
  final modes = (Platform.environment['P62_MODES'] ?? 'light').split(',');
  final lang = Platform.environment['P62_LANG'] ?? 'tr';
  const dpr = 2.0;

  setUpAll(() async {
    if (lang != 'ar') return loadTestFonts();
    final f = FontLoader('Inter');
    for (final n in ['arial.ttf', 'arialbd.ttf']) {
      final file = File('C:/Windows/Fonts/$n');
      if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await f.load();
    await loadIconFonts();
  });

  for (final dark in [false, true]) {
    if (!modes.contains(dark ? 'dark' : 'light')) continue;
    for (final sc in _scenes) {
      testWidgets('p62 ${sc.file} ${dark ? 'koyu' : 'acik'} $lang', skip: out == null, (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(390 * dpr, sc.height * dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
        addTearDown(() => LocaleController.current = null);
        final b = FakeBackend();
        sc.data(b);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
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
            home: Scaffold(body: sc.build(b)),
          ),
        ));
        await settle(tester, const Duration(milliseconds: 1500));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/${sc.file}${dark ? '_koyu' : ''}_$lang.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}
