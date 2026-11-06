@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';

/// Forum kategori genişletme ekran görüntüleri (ana sayfa çipleri + arama kutusu, kategori seçici, arama, boş durum).
/// Varsayılan `flutter test` ile ÇALIŞMAZ (ortam değişkeni yoksa atlanır). Üretim (C:\bu_mobile içinde):
///   FCAT_OUT='C:/.../shots' flutter test test/redesign/forum_categories_shots_test.dart
/// İsteğe bağlı: `FCAT_LANG=tr,ar`, `FCAT_DARK=0|1|both`, `FCAT_SCALE=1.3`, `FCAT_W=390`.
const _h = 844.0;
const _dpr = 2.0;

const _groups = {
  'genel': ('Genel', 'General', 'عام', 10),
  'akademik': ('Akademik', 'Academic', 'أكاديمي', 20),
  'kampus': ('Kampüs Yaşamı', 'Campus Life', 'الحياة الجامعية', 30),
  'hobi': ('Hobi & Eğlence', 'Hobbies & Fun', 'الهوايات والترفيه', 70),
};

List<Map<String, dynamic>> _cats(String lang) {
  const rows = [
    ('gundem', 'genel', 'Gündem', 'Trending', 'المستجدات', 12),
    ('serbest-kursu', 'genel', 'Serbest Kürsü', 'Open Floor', 'منبر حر', 4),
    ('oneri-sikayet', 'genel', 'Öneri & Şikâyet', 'Suggestions & Complaints', 'اقتراحات وشكاوى', 0),
    ('duyurular', 'genel', 'Duyurular', 'Announcements', 'الإعلانات', 0),
    ('dersler', 'akademik', 'Dersler', 'Courses', 'المقررات', 9),
    ('sinavlar-notlar', 'akademik', 'Sınavlar & Notlar', 'Exams & Grades', 'الامتحانات والدرجات', 3),
    ('cikmis-sorular', 'akademik', 'Çıkmış Sorular', 'Past Exam Questions', 'أسئلة الامتحانات السابقة', 0),
    ('hocalar-ders-secimi', 'akademik', 'Hocalar & Ders Seçimi', 'Instructors & Course Selection', 'الأساتذة واختيار المقررات', 0),
    ('staj', 'akademik', 'Staj', 'Internships', 'التدريب', 1),
    ('yuksek-lisans-akademik', 'akademik', 'Yüksek Lisans & Akademik Kariyer', 'Graduate Studies & Academic Career', 'الدراسات العليا والمسار الأكاديمي', 0),
    ('yemekhane', 'kampus', 'Yemekhane', 'Cafeteria', 'المطعم', 7),
    ('yurtlar', 'kampus', 'Yurtlar', 'Dormitories', 'السكن الجامعي', 2),
    ('kutuphane', 'kampus', 'Kütüphane', 'Library', 'المكتبة', 0),
    ('ikinci-el-ucretsiz', 'kampus', 'İkinci El & Ücretsiz', 'Second-Hand & Free', 'مستعمل ومجاني', 0),
    ('muzik', 'hobi', 'Müzik', 'Music', 'الموسيقى', 0),
    ('film-dizi', 'hobi', 'Film & Dizi', 'Movies & TV', 'الأفلام والمسلسلات', 5),
    ('oyun', 'hobi', 'Oyun', 'Gaming', 'الألعاب', 0),
    ('anime-manga', 'hobi', 'Anime & Manga', 'Anime & Manga', 'الأنمي والمانغا', 0),
  ];
  return [
    for (final (i, r) in rows.indexed)
      {
        'id': i + 1,
        'slug': r.$1,
        'name': lang == 'ar' ? r.$5 : (lang == 'en' ? r.$4 : r.$3),
        'sortOrder': i < 8 ? (i + 1) * 10 : 100 + i * 10,
        'topicCount': r.$6,
        'groupKey': r.$2,
        'groupName': lang == 'ar' ? _groups[r.$2]!.$3 : (lang == 'en' ? _groups[r.$2]!.$2 : _groups[r.$2]!.$1),
        'groupOrder': _groups[r.$2]!.$4,
      },
  ];
}

Widget _app(Widget home, String lang, bool dark, GlobalKey key, double scale) => RepaintBoundary(
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
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
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
  final out = Platform.environment['FCAT_OUT'];
  final skip = out == null;
  final langs = (Platform.environment['FCAT_LANG'] ?? 'tr').split(',');
  final darkMode = Platform.environment['FCAT_DARK'] ?? '0';
  final scale = double.tryParse(Platform.environment['FCAT_SCALE'] ?? '') ?? 1.0;
  final w = double.tryParse(Platform.environment['FCAT_W'] ?? '') ?? 390.0;
  final modes = darkMode == 'both' ? [false, true] : [darkMode == '1'];

  final shots = <String, Future<void> Function(WidgetTester t, FakeBackend b, String lang)>{
    '1_ana_sayfa': (t, b, lang) async {},
    '2_secici': (t, b, lang) async {
      await t.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(t);
    },
    '3_secici_arama': (t, b, lang) async {
      await t.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(t);
      await t.enterText(find.descendant(of: find.byKey(const ValueKey('forum-cat-search')), matching: find.byType(TextField)),
          lang == 'ar' ? 'مكتب' : 'MUZIK');
      await settle(t);
    },
    '4_secici_bos': (t, b, lang) async {
      await t.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(t);
      await t.enterText(find.descendant(of: find.byKey(const ValueKey('forum-cat-search')), matching: find.byType(TextField)), 'zzqx');
      await t.pump(const Duration(milliseconds: 500));
      await settle(t);
    },
  };

  for (final lang in langs) {
    setUpAll(() => _loadFonts(lang == 'ar'));
    for (final dark in modes) {
      for (final e in shots.entries) {
        final name = '${e.key}${dark ? '_koyu' : ''}_${lang}_w${w.toInt()}${scale != 1.0 ? '_x$scale' : ''}';
        testWidgets('ekran $name', skip: skip, (tester) async {
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(w * _dpr, _h * _dpr);
          addTearDown(tester.view.reset);
          final b = FakeBackend();
          final f = fakeForum(b, count: 8, categories: false);
          f.categories
            ..clear()
            ..addAll(_cats(lang));
          f.categorySearch = (q) => <Map<String, dynamic>>[];
          final s = makeSession(b);
          final key = GlobalKey();
          await tester.pumpWidget(_app(ForumHomePage(session: s), lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1200));
          await e.value(tester, b, lang);
          await settle(tester, const Duration(milliseconds: 700));
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: _dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            final file = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
            // ignore: avoid_print
            print('YAZILDI ${file.path} ${image.width}x${image.height}');
          });
          await unmount(tester);
        });
      }
    }
  }
}
