import 'package:bu_kampus/core/academic_catalog.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Çeviri alanlı küçük katalog (backend v2 biçimi). "Hukuk" iki fakültede ortak ad: ayrım denenir.
const _cat = <String, dynamic>{
  'version': 2,
  'faculties': [
    {
      'id': 'muhendislik',
      'name': 'Mühendislik Fakültesi',
      'nameEn': 'Faculty of Engineering',
      'nameAr': 'كلية الهندسة',
      'departments': [
        {
          'id': 'bilgisayar',
          'name': 'Bilgisayar Mühendisliği',
          'nameEn': 'Computer Engineering',
          'nameAr': 'هندسة الحاسوب',
        },
        {'id': 'ortak', 'name': 'Ortak Bölüm', 'nameEn': 'Shared (Engineering)', 'nameAr': 'مشترك (الهندسة)'},
      ],
    },
    {
      'id': 'egitim',
      'name': 'Eğitim Fakültesi',
      'nameEn': 'Faculty of Education',
      'nameAr': 'كلية التربية',
      'departments': [
        {'id': 'ortak2', 'name': 'Ortak Bölüm', 'nameEn': 'Shared (Education)', 'nameAr': 'مشترك (التربية)'},
        // çeviri eksik: Türkçeye düşmeli
        {'id': 'eksik', 'name': 'Çevirisiz Bölüm'},
      ],
    },
  ],
  'grades': [
    {'id': 'PREP', 'name': 'Hazırlık', 'nameEn': 'Prep year', 'nameAr': 'السنة التحضيرية'},
    {'id': '1', 'name': '1. sınıf', 'nameEn': 'Year 1', 'nameAr': 'السنة 1'},
  ],
};

const _en = Locale('en');
const _ar = Locale('ar');
const _tr = Locale('tr');

Future<AcademicCatalog> _loaded(Map<String, dynamic> json) async {
  final b = FakeBackend()..on('/catalog/academic', json);
  final cat = AcademicCatalog(makeSession(b, signedIn: false));
  await cat.load();
  expect(cat.ready, isTrue);
  return cat;
}

void main() {
  setUpAll(loadTestFonts);

  group('AcademicCatalog görünen ad', () {
    test('fakülte/bölüm adı dile göre; Türkçe kanonik değer değişmez', () async {
      final cat = await _loaded(_cat);
      expect(cat.facultyLabel('Mühendislik Fakültesi', _tr), 'Mühendislik Fakültesi');
      expect(cat.facultyLabel('Mühendislik Fakültesi', _en), 'Faculty of Engineering');
      expect(cat.facultyLabel('Mühendislik Fakültesi', _ar), 'كلية الهندسة');
      expect(cat.departmentLabel('Bilgisayar Mühendisliği', _en), 'Computer Engineering');
      expect(cat.departmentLabel('Bilgisayar Mühendisliği', _ar), 'هندسة الحاسوب');
      expect(cat.departmentLabel('Bilgisayar Mühendisliği', _tr), 'Bilgisayar Mühendisliği');
      // Kanonik adlar katalogda olduğu gibi kalır.
      expect(cat.faculties.map((f) => f.name), ['Mühendislik Fakültesi', 'Eğitim Fakültesi']);
      expect(cat.departments.first.name, 'Bilgisayar Mühendisliği');
    });

    test('arama aksan duyarsız: Türkçe kanonik ad ve seçili dildeki ad', () async {
      final cat = await _loaded(_cat);
      expect(cat.searchDepartments('MUHENDIS', locale: _en).map((d) => d.id), ['bilgisayar']);
      expect(cat.searchDepartments('computer', locale: _en).map((d) => d.id), ['bilgisayar']);
      expect(cat.searchDepartments('bilgisayar', locale: _en).map((d) => d.id), ['bilgisayar']);
      expect(cat.searchDepartments('الحاسوب', locale: _ar).map((d) => d.id), ['bilgisayar']);
      // Türkçe arayüzde İngilizce ad aranmaz (gürültü olmasın).
      expect(cat.searchDepartments('computer', locale: _tr), isEmpty);
      expect(cat.searchDepartments('computer'), isEmpty);
      expect(cat.searchFaculties('faculty of edu', locale: _en).map((f) => f.id), ['egitim']);
      expect(cat.searchFaculties('التربية', locale: _ar).map((f) => f.id), ['egitim']);
    });

    test('ortak bölüm adında fakülte ayrımı; bilinmeyen/eksik değerde Türkçeye düşer', () async {
      final cat = await _loaded(_cat);
      expect(cat.departmentLabel('Ortak Bölüm', _en, faculty: 'Eğitim Fakültesi'), 'Shared (Education)');
      expect(cat.departmentLabel('Ortak Bölüm', _en, faculty: 'Mühendislik Fakültesi'), 'Shared (Engineering)');
      expect(cat.departmentLabel('Ortak Bölüm', _ar), 'مشترك (الهندسة)'); // fakülte yoksa ilk eşleşme
      expect(cat.departmentLabel('Çevirisiz Bölüm', _en), 'Çevirisiz Bölüm');
      expect(cat.departmentLabel('Çevirisiz Bölüm', _ar), 'Çevirisiz Bölüm');
      expect(cat.departmentLabel('Uydurma Bölüm', _en), 'Uydurma Bölüm');
      expect(cat.facultyLabel('Uydurma Fakülte', _ar), 'Uydurma Fakülte');
      expect(cat.facultyLabel(null, _en), '');
      expect(cat.departmentLabel('', _en), '');
      // Büyük/küçük harf ve aksan farkı olsa da bulunur.
      expect(cat.facultyLabel('MÜHENDİSLİK FAKÜLTESİ', _en), 'Faculty of Engineering');
    });

    test('katalog yüklenmediyse Türkçe kanonik metin döner; sınıf adları dile göre', () async {
      final b = FakeBackend()..network('/catalog/academic');
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await cat.load();
      expect(cat.state, CatalogState.error);
      expect(cat.facultyLabel('Hukuk Fakültesi', _en), 'Hukuk Fakültesi');
      expect(cat.departmentLabel('Hukuk', _ar), 'Hukuk');

      final ok = await _loaded(_cat);
      final prep = ok.grades.firstWhere((g) => g.id == 'PREP');
      expect(prep.label('tr'), 'Hazırlık');
      expect(prep.label('en'), 'Prep year');
      expect(prep.label('ar'), 'السنة التحضيرية');
      expect(prep.label('de'), 'Hazırlık');
    });

    test('v1 yanıtı (çeviri alanı yok) çalışmaya devam eder', () async {
      final cat = await _loaded(kFakeAcademic);
      expect(cat.facultyLabel('Mühendislik Fakültesi', _en), 'Mühendislik Fakültesi');
      expect(cat.departmentLabel('Biyoloji', _ar), 'Biyoloji');
    });
  });

  group('Bağlam yardımcıları', () {
    Widget app(Locale locale, Session session) => MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AcademicCatalogScope(
            session: session,
            child: Builder(
              builder: (c) => Column(children: [
                Text('F:${c.facultyName('Mühendislik Fakültesi')}'),
                Text('D:${c.departmentName('Bilgisayar Mühendisliği', faculty: 'Mühendislik Fakültesi')}'),
                Text('U:${c.departmentOrFacultyName('', 'Eğitim Fakültesi')}'),
                Text('V:${c.departmentOrFacultyName('Bilgisayar Mühendisliği', null)}'),
              ]),
            ),
          ),
        );

    for (final (locale, f, d, u) in [
      (_en, 'Faculty of Engineering', 'Computer Engineering', 'Faculty of Education'),
      (_ar, 'كلية الهندسة', 'هندسة الحاسوب', 'كلية التربية'),
      (_tr, 'Mühendislik Fakültesi', 'Bilgisayar Mühendisliği', 'Eğitim Fakültesi'),
    ]) {
      testWidgets('${locale.languageCode}: yükleme sonrası görünen ad değişir', (tester) async {
        final b = FakeBackend()..on('/catalog/academic', _cat);
        final session = makeSession(b);
        await tester.pumpWidget(app(locale, session));
        await settle(tester, const Duration(milliseconds: 300));
        expect(find.text('F:$f'), findsOneWidget);
        expect(find.text('D:$d'), findsOneWidget);
        expect(find.text('U:$u'), findsOneWidget);
        expect(find.text('V:${locale == _en ? 'Computer Engineering' : locale == _ar ? 'هندسة الحاسوب' : 'Bilgisayar Mühendisliği'}'),
            findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('katalog gelmezse (ağ hatası) Türkçe kanonik metin kalır', (tester) async {
      final b = FakeBackend()..network('/catalog/academic');
      final session = makeSession(b);
      await tester.pumpWidget(app(_en, session));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('F:Mühendislik Fakültesi'), findsOneWidget);
      expect(find.text('D:Bilgisayar Mühendisliği'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kapsam yoksa Türkçe kanonik metin döner', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: _en,
        home: Builder(
          builder: (c) => Text('X:${c.facultyName('Hukuk Fakültesi')}|${c.departmentName('Hukuk')}'),
        ),
      ));
      expect(find.text('X:Hukuk Fakültesi|Hukuk'), findsOneWidget);
    });
  });
}
