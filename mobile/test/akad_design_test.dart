import 'package:bu_kampus/features/academic/academic_api.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/announcements_page.dart';
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminder_settings_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/semester_sheet.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Pazartesi 2026-11-02 08:00 (Istanbul).
final _now = DateTime.utc(2026, 11, 2, 5, 0);

Widget _app(Widget home, {Brightness br = Brightness.light, Size size = kPhoneSmall, String lang = 'tr'}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: br == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: child)),
      ),
    );

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

FakeBackend _backend() {
  final b = FakeBackend();
  final f = fakeAcademic(b)
    ..addCourse('Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', 1, '09:00', '10:50',
        room: 'Mühendislik Fakültesi Bilgisayar Laboratuvarı 2', instructor: 'Prof. Dr. Mehmet Ali Yıldırım Karaca', code: 'BIL4001')
    ..addCourse('Fizik', 1, '11:00', '12:00', color: 'green')
    ..addExam('Veri Yapıları Vize', '2026-11-04T10:00:00+03:00')
    ..addExam('Geçmiş Quiz', '2026-10-21T10:00:00+03:00', type: 'QUIZ')
    ..addAnnouncements(3);
  f.official = [
    {
      'id': 1,
      'title': 'Fizik Final',
      'type': 'FINAL',
      'courseCode': 'FIZ101',
      'department': 'Fizik',
      'grade': '1',
      'startsAt': '2026-11-20T09:00:00+03:00',
      'endsAt': '2026-11-20T10:00:00+03:00',
      'room': 'A-1',
      'note': 'Not',
    }
  ];
  f.events = [
    {
      'id': 1,
      'kind': 'VIZE',
      'title': 'Ara sınav haftası',
      'startsAt': '2026-11-09T00:00:00+03:00',
      'endsAt': '2026-11-13T23:59:00+03:00',
      'allDay': true,
    },
    {'id': 2, 'kind': 'DERS_KAYIT', 'title': 'Ders ekleme-bırakma sonu', 'startsAt': '2026-11-30T00:00:00+03:00', 'endsAt': null, 'allDay': true},
  ];
  return b;
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    academicClock = () => _now;
    ReminderService.platform = _Platform();
    ReminderService.store = MemoryReminderStore();
  });
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
  });

  final pages = <String, Widget Function(FakeBackend)>{
    'ders programi': (b) => TimetablePage(session: makeSession(b)),
    'ders formu': (b) => CourseFormPage(session: makeSession(b)),
    'sinavlar': (b) => ExamsPage(session: makeSession(b)),
    'resmi sinavlar': (b) => ExamsPage(session: makeSession(b), initialTab: 1),
    'sinav formu': (b) => ExamFormPage(session: makeSession(b), courses: const [Course(id: 1, name: 'Veri Yapıları ve Algoritmalar Uygulaması')]),
    'takvim': (b) => AcademicCalendarPage(session: makeSession(b)),
    'duyurular': (b) => AnnouncementsPage(session: makeSession(b)),
    'hatirlaticilar': (b) => ReminderSettingsPage(session: makeSession(b)),
  };

  for (final entry in pages.entries) {
    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('${entry.key} ${br.name} ${size.width.toInt()} tasma yok', (tester) async {
          useScreen(tester, size);
          final b = _backend();
          await tester.pumpWidget(_app(entry.value(b), br: br, size: size));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
    testWidgets('${entry.key} ar RTL 320 tasma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = _backend();
      await tester.pumpWidget(_app(entry.value(b), lang: 'ar'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);
      await unmount(tester);
    });
  }

  testWidgets('donem secici: Resmi etiketi, secili isaret, yeni donem dugmesi', (tester) async {
    useScreen(tester, kPhoneSmall);
    final b = _backend();
    final f = fakeAcademic(b);
    f.semester = {'id': 5, 'name': '2026-2027 Güz', 'startDate': '2026-09-14', 'endDate': '2027-01-15', 'current': true};
    final api = AcademicApi(makeSession(b));
    await tester.pumpWidget(_app(Scaffold(body: SemesterSheet(api: api, activeId: 5))));
    await settle(tester);
    expect(find.text('Dönem seç'), findsOneWidget);
    expect(find.text('2026-2027 Güz'), findsOneWidget);
    expect(find.text('Güncel'), findsOneWidget);
    expect(find.text('Yeni dönem ekle'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('ders programi: gun seridi tarihleri ve baslik', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = _backend();
    await tester.pumpWidget(_app(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
    await settle(tester);
    expect(find.text('Pzt, bugün'), findsOneWidget); // secili gun hapi
    expect(find.text('Takvime aktar (.ics)'), findsOneWidget);
    expect(find.text('Ders ekle'), findsOneWidget); // yuzen dugme
    await unmount(tester);
  });

  testWidgets('sinavlar: Yaklasan/Gecmis bolumleri ve Gecti hapi', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = _backend();
    await tester.pumpWidget(_app(ExamsPage(session: makeSession(b)), size: kPhoneMedium));
    await settle(tester);
    expect(find.text('Yaklaşan'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.text('Geçti'), findsOneWidget);
    expect(find.text('2 gün kaldı'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('duyurular: Sabit/Yeni etiketleri', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = _backend();
    await tester.pumpWidget(_app(AnnouncementsPage(session: makeSession(b)), size: kPhoneMedium));
    await settle(tester);
    expect(find.text('Sabitlenmiş'), findsWidgets);
    expect(find.text('Okunmamış'), findsWidgets);
    await unmount(tester);
  });
}
