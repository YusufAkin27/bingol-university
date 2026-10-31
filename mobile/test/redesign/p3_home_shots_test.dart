import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_layout_sheet.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// P3-HOME Stitch v3 birebir ekran görüntüleri (Stitch ile yan yana kıyas için).
/// Üretim: P3H_OUT='C:/bu_qa/shots/tasarim/p3/home/birebir' P3H_W=390 P3H_LANG=tr P3H_MODES=light,dark,x13 \
///   flutter test test/redesign/p3_home_shots_test.dart
const _dpr = 2.5;
String _lang = 'tr';
final double _w = double.tryParse(Platform.environment['P3H_W'] ?? '') ?? 390;

String _day(int offset) {
  final n = DateTime.now().add(Duration(days: offset));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

void _data(FakeBackend b) {
  final wall = istanbulWall(academicClock());
  b
    ..on('/me/summary', {'unreadNotifications': 3, 'unreadMessages': 2})
    ..on('/menu/today', {
      'date': _day(0),
      'items': ['Süzme mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Mevsim salata'],
      'dishes': [
        {'name': 'Süzme mercimek çorbası', 'kcal': 160},
        {'name': 'Orman kebabı', 'kcal': 380},
        {'name': 'Pirinç pilavı', 'kcal': 220},
        {'name': 'Mevsim salata', 'kcal': 100},
      ],
      'totalKcal': 860,
      'kcalComplete': true,
    })
    ..on('/timetable', {
      'semester': null,
      'courses': [
        {
          'id': 1,
          'name': 'Veri Yapıları',
          'instructor': 'Prof. Dr. M. Kaya',
          'sessions': [
            {'dayOfWeek': wall.weekday, 'start': '10:00', 'end': '11:30', 'room': 'B-204'}
          ],
        },
        {
          'id': 2,
          'name': 'Veritabanı Sistemleri',
          'instructor': 'Doç. Dr. S. Demir',
          'sessions': [
            {'dayOfWeek': wall.weekday, 'start': '13:30', 'end': '15:00', 'room': 'Lab 3'}
          ],
        },
      ],
    })
    ..on('/timetable/exams/upcoming*', {
      'items': [
        {'id': 5, 'title': 'Vize', 'courseName': 'Algoritmalar', 'startsAt': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String()},
      ]
    })
    ..on('/events/featured', {
      'id': 12,
      'source': 'USER',
      'title': 'Yapay Zeka ve Kariyer Sohbeti',
      'startsAt': DateTime.now().add(const Duration(days: 2, hours: 3)).toUtc().toIso8601String(),
      'location': 'Merkez Kütüphane Önü',
      'communityName': 'Bilişim ve İnovasyon Kulübü',
      'goingCount': 14,
    })
    ..on('/news?type=HABER*', {
      'items': [
        {'id': 1, 'type': 'HABER', 'title': 'Kütüphane vize dönemi çalışma saatleri güncellendi', 'publishedDate': _day(-3), 'imageUrl': null},
        {'id': 2, 'type': 'HABER', 'title': 'Güz dönemi festivali duyuruldu', 'publishedDate': _day(-5), 'imageUrl': null},
      ],
    })
    ..on('/news?type=DUYURU*', {
      'items': [
        {'id': 3, 'type': 'DUYURU', 'title': 'Erasmus+ 2024-2025 Bahar dönemi öğrenci hareketliliği başvuru sonuçları ilan edildi.', 'publishedDate': _day(-6)},
        {'id': 4, 'type': 'DUYURU', 'title': 'Merkezi yemekhanede tek kullanımlık plastik bardak uygulaması kaldırılmıştır.', 'publishedDate': _day(-8)},
        {'id': 5, 'type': 'DUYURU', 'title': 'Öğrenci kimlik kartı yenileme talepleri için son gün 15 Kasım.', 'publishedDate': _day(-11)},
      ],
    });
}

class _Shot {
  const _Shot(this.file, this.build, {this.height = 1700, this.loading = false, this.layout, this.after});
  final String file;
  final Widget Function(FakeBackend b) build;
  final double height;
  final bool loading;
  final HomeLayout? layout;
  final Future<void> Function(WidgetTester tester)? after;
}

Widget _home(FakeBackend b) => HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {});

final _shots = <_Shot>[
  _Shot('01_ana_sayfa', _home),
  _Shot('02_iskelet', _home, loading: true, height: 844),
  _Shot('03_tum_gizli', _home, height: 844, layout: _allHidden()),
  _Shot('05_duzenle', (b) => HomeLayoutPage(controller: HomeLayoutController(uid: 1)), height: 900),
  _Shot('07_secici', (b) {
    final c = HomeLayoutController(uid: 1);
    return Builder(builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showHomeShortcutsSheet(context, c));
      return const SizedBox.expand();
    });
  }, height: 900),
];

HomeLayout _allHidden() {
  var v = HomeLayout.defaults;
  for (final s in HomeSection.values) {
    v = v.setVisible(s, false);
  }
  return v;
}

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
      home: Scaffold(body: home),
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
  final out = Platform.environment['P3H_OUT'];
  final skip = out == null ? 'P3H_OUT tanimli degil' : null;
  _lang = Platform.environment['P3H_LANG'] ?? 'tr';
  final modes = (Platform.environment['P3H_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final shot in _shots) {
      final name = '${shot.file}${v.$1}_$_lang';
      testWidgets('p3home $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, shot.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        final prevClock = academicClock;
        academicClock = () {
          final n = DateTime.now();
          return DateTime.utc(n.year, n.month, n.day, 5); // 08:00 İstanbul: dersler henüz başlamadı
        };
        addTearDown(() => academicClock = prevClock);

        mockSecureStorage();
        await HomeLayoutStore.clear();
        if (shot.layout != null) await HomeLayoutStore.save(shot.layout!, 1);
        final b = FakeBackend();
        _data(b);
        if (shot.loading) b.delay = const Duration(seconds: 4);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final key = GlobalKey();
        await tester.pumpWidget(_app(shot.build(b), v.$2, key, v.$3));
        if (!shot.loading) {
          await settle(tester, const Duration(milliseconds: 1500));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump(const Duration(milliseconds: 900));
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
        await HomeLayoutStore.clear();
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
