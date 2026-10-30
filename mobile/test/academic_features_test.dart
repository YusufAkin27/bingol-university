import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/announcements_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminder_settings_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Pazartesi 2026-11-02 08:00 (İstanbul) = 05:00Z.
final _now = DateTime.utc(2026, 11, 2, 5, 0);

CourseSession _s(int day, String a, String b) => CourseSession(dayOfWeek: day, start: a, end: b);
Course _c(int id, String name, List<CourseSession> s, {String color = 'blue'}) => Course(id: id, name: name, color: color, sessions: s);

class _RecordingPlatform implements ReminderPlatform {
  List<PlannedReminder> last = const [];
  int calls = 0;
  String? shared;

  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {
    last = items;
    calls++;
  }

  @override
  Future<bool> shareText(String text, String subject) async {
    shared = text;
    return true;
  }
}

/// Tembel ListView'de düğmeyi görünür yapar.
Future<void> toBottom(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus(); // imleç kaydırmayı geri çekmesin
  await settle(tester, const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(find.text(text), 300, scrollable: find.descendant(of: find.byType(Scaffold).last, matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(find.text(text));
  await settle(tester, const Duration(milliseconds: 500));
}

void main() {
  setUpAll(loadTestFonts);
  late _RecordingPlatform platform;
  setUp(() {
    academicClock = () => _now;
    platform = _RecordingPlatform();
    ReminderService.platform = platform;
    ReminderService.store = MemoryReminderStore();
  });
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
  });

  group('mantik', () {
    test('cakisma: bitisik dersler cakismaz, ic ice gecenler cakisir', () {
      expect(sessionsOverlap(_s(1, '09:00', '10:00'), _s(1, '10:00', '11:00')), isFalse);
      expect(sessionsOverlap(_s(1, '09:00', '10:50'), _s(1, '10:00', '11:00')), isTrue);
      expect(sessionsOverlap(_s(1, '09:00', '10:50'), _s(2, '09:00', '10:50')), isFalse);
      final existing = [_c(1, 'A', [_s(1, '09:00', '10:50')])];
      expect(findConflicts(existing, [_s(1, '10:00', '11:00')]).length, 1);
      expect(findConflicts(existing, [_s(1, '10:00', '11:00')], excludeCourseId: 1), isEmpty);
      expect(selfConflicts([_s(1, '09:00', '10:00'), _s(1, '09:30', '11:00'), _s(2, '09:00', '10:00')]), [(0, 1)]);
    });

    test('gunun dersleri, donem kisiti ve siradaki ders', () {
      final sem = Semester(id: 1, name: 'Guz', startDate: DateTime.utc(2026, 9, 14), endDate: DateTime.utc(2027, 1, 15));
      final courses = [
        _c(1, 'Veri', [_s(1, '13:00', '14:50'), _s(3, '09:00', '10:00')]),
        _c(2, 'Mat', [_s(1, '09:00', '10:50')]),
      ];
      final now = istanbulWall(_now);
      final today = slotsForDay(courses, sem, now, nowWall: now);
      expect(today.map((e) => e.course.name), ['Mat', 'Veri']);
      expect(today.every((e) => e.status == SlotStatus.upcoming), isTrue);
      final next = nextSlot(courses, sem, now)!;
      expect(next.slot.course.name, 'Mat');
      expect(next.minutesUntil, 60);
      // 09:30'da Mat sürüyor.
      final mid = DateTime.utc(2026, 11, 2, 9, 30);
      expect(slotsForDay(courses, sem, mid, nowWall: mid).first.status, SlotStatus.ongoing);
      // donem disinda bos
      expect(slotsForDay(courses, sem, DateTime.utc(2027, 2, 1)), isEmpty);
    });

    test('hatirlatma plani: ders oncesi dakika ve sinav 1 gun/1 saat', () {
      final courses = [_c(1, 'Mat', [_s(1, '09:00', '10:50'), _s(1, '07:30', '08:20')])];
      final exam = Exam(id: 9, title: 'Vize', type: 'VIZE', startsAt: DateTime.utc(2026, 11, 4, 7, 0)); // 10:00 Istanbul
      final plan = planReminders(
        courses: courses,
        semester: null,
        exams: [exam],
        settings: const ReminderSettings(classLeadMin: 15),
        now: _now,
        horizonDays: 8,
      );
      // 07:30 dersi 07:15 (=04:15Z) gecmis: atlanir. 09:00 dersi 08:45 Istanbul = 05:45Z.
      expect(plan.first.at, DateTime.utc(2026, 11, 2, 5, 45));
      expect(plan.first.title, 'Mat');
      expect(plan.where((p) => p.title.startsWith('Vize')).map((p) => p.at), [DateTime.utc(2026, 11, 3, 7, 0), DateTime.utc(2026, 11, 4, 6, 0)]);
      expect(plan.map((p) => p.at).toList(), [...plan.map((p) => p.at)]..sort());
      expect(plan.map((p) => p.id).toSet().length, plan.length, reason: 'kimlikler benzersiz');
      final off = planReminders(
          courses: courses,
          semester: null,
          exams: [exam],
          settings: const ReminderSettings(classEnabled: false, examDayBefore: false),
          now: _now);
      expect(off.length, 1);
    });

    test('geri sayim ve ICS', () {
      expect(countdownText(DateTime.utc(2026, 11, 4, 5), _now), '2 gün kaldı');
      expect(countdownText(DateTime.utc(2026, 11, 2, 9), _now), '4 saat kaldı');
      expect(countdownText(DateTime.utc(2026, 11, 1), _now), isNull);
      final sem = Semester(id: 1, name: 'Guz', startDate: DateTime.utc(2026, 9, 14), endDate: DateTime.utc(2027, 1, 15));
      final ics = buildIcs([
        const Course(id: 1, name: 'Veri, Yapıları', instructor: 'Dr. A', sessions: [CourseSession(dayOfWeek: 3, start: '09:00', end: '10:50', room: 'B-204')])
      ], sem, const [], now: _now);
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('DTSTART;TZID=Europe/Istanbul:20260916T090000')); // 14 Eylul Pazartesi -> ilk Carsamba 16 Eylul
      expect(ics, contains('RRULE:FREQ=WEEKLY;UNTIL=20270115T205900Z'));
      expect(ics, contains('SUMMARY:Veri\\, Yapıları'));
      expect(ics, contains('LOCATION:B-204'));
    });

    test('ISO ayrisma: ofsetsiz Istanbul varsayilir', () {
      expect(parseInstant('2026-11-02T10:00'), DateTime.utc(2026, 11, 2, 7));
      expect(parseInstant('2026-11-02T10:00:00+03:00'), DateTime.utc(2026, 11, 2, 7));
      expect(fmtInstant(DateTime.utc(2026, 11, 2, 7)), '2 Kasım 2026 · 10:00');
    });
  });

  group('ders programi', () {
    testWidgets('bugunun dersleri, siradaki ders karti, gun sekmeleri', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)
        ..addCourse('Veri Yapıları', 1, '09:00', '10:50', room: 'B-204', instructor: 'Dr. Ayşe Yılmaz', code: 'BIL201')
        ..addCourse('Fizik', 3, '13:00', '14:50');
      expect(f.courses.length, 2);
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('SIRADAK'), findsOneWidget);
      expect(find.text('1 sa sonra'), findsOneWidget);
      expect(find.text('Derslik B-204'), findsOneWidget);
      expect(find.text('Dr. Ayşe Yılmaz'), findsWidgets);
      expect(find.text('2026-2027 Güz'), findsOneWidget);
      // Çarşamba sekmesi
      await tester.tap(find.text('Çar'));
      await tester.pump();
      expect(find.text('13:00 - 14:50'), findsOneWidget);
      // Salı: ders yok
      await tester.tap(find.text('Sal'));
      await tester.pump();
      expect(find.textContaining('Salı günü dersin yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bos durum ve yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b);
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('Henüz ders eklemedin'), findsOneWidget);
      expect(find.text('İlk dersini ekle'), findsOneWidget);
      await unmount(tester);

      final b2 = FakeBackend()..offline = true;
      fakeAcademic(b2);
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b2)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsOneWidget);
      b2.offline = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.textContaining('Henüz ders eklemedin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ders ekle: form gonderilir ve liste yenilenir; hatirlatma planlanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b);
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('İlk dersini ekle'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Algoritmalar');
      await tester.tap(find.text('Pzt').last);
      await tester.pump();
      await toBottom(tester, 'Dersi ekle');
      await tester.tap(find.text('Dersi ekle'));
      await settle(tester, const Duration(seconds: 2));
      final body = b.bodies['POST /timetable/courses']! as Map;
      expect(body['name'], 'Algoritmalar');
      expect(body['force'], false);
      expect((body['sessions'] as List).single, containsPair('dayOfWeek', 1));
      expect(body['semesterId'], 3);
      expect(find.text('Algoritmalar'), findsWidgets);
      expect(platform.calls, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('yerel cakisma uyarisi: "Yine de kaydet" force=true gonderir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)..addCourse('Veri Yapıları', 1, '09:00', '10:50');
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byTooltip('Ders ekle'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Matematik');
      await toBottom(tester, 'Dersi ekle');
      await tester.tap(find.text('Dersi ekle')); // varsayilan Pzt 09:00-10:50 -> cakisir
      await settle(tester);
      expect(find.text('Ders çakışması'), findsOneWidget);
      expect(find.textContaining('Veri Yapıları'), findsWidgets);
      expect(b.bodies.containsKey('POST /timetable/courses'), isFalse);
      await tester.tap(find.text('Yine de kaydet'));
      await settle(tester, const Duration(seconds: 2));
      expect((b.bodies['POST /timetable/courses']! as Map)['force'], true);
      expect(f.courses.length, 2);
      await unmount(tester);
    });

    testWidgets('sunucu 409 COURSE_CONFLICT: onaydan sonra force ile tekrar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)..conflictOnce = true;
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('İlk dersini ekle'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Kimya');
      await toBottom(tester, 'Dersi ekle');
      await tester.tap(find.text('Dersi ekle'));
      await settle(tester);
      expect(find.textContaining('çakışıyor'), findsOneWidget);
      await tester.tap(find.text('Yine de kaydet'));
      await settle(tester, const Duration(seconds: 2));
      expect(f.courses.single['name'], 'Kimya');
      await unmount(tester);
    });

    testWidgets('ders sil', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)..addCourse('Fizik', 1, '09:00', '10:50');
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('Fizik').at(1)); // sıradaki ders kartı değil, gün akışındaki kart
      await settle(tester);
      await tester.tap(find.byTooltip('Dersi sil'));
      await settle(tester);
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(seconds: 2));
      expect(f.courses, isEmpty);
      expect(find.textContaining('Henüz ders eklemedin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ICS paylasimi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b).addCourse('Fizik', 1, '09:00', '10:50');
      await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('Takvime aktar (.ics)'));
      await settle(tester);
      expect(platform.shared, contains('SUMMARY:Fizik'));
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('matris ${br.name} ${size.width.toInt()}', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          fakeAcademic(b)
            ..addCourse('Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', 1, '09:00', '10:50',
                room: 'Mühendislik Fakültesi Bilgisayar Laboratuvarı 2', instructor: 'Prof. Dr. Mehmet Ali Yıldırım Karaca', code: 'BIL4001')
            ..addCourse('Fizik', 1, '11:00', '12:00', color: 'red');
          await tester.pumpWidget(buildApp(TimetablePage(session: makeSession(b)), brightness: br, size: size));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('sinavlar', () {
    testWidgets('yaklasan sinav geri sayim; resmi program ve profil uyarisi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)..addExam('Veri Yapıları Vize', '2026-11-04T10:00:00+03:00');
      f.official = [
        {
          'id': 1,
          'title': 'Fizik Final',
          'type': 'FINAL',
          'courseCode': 'FIZ101',
          'department': 'Fizik',
          'grade': '1',
          'startsAt': '2026-11-20T09:00:00+03:00',
          'endsAt': null,
          'room': 'A-1',
          'note': null,
        }
      ];
      f.profileComplete = false;
      await tester.pumpWidget(buildApp(ExamsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Veri Yapıları Vize'), findsOneWidget);
      expect(find.text('2 gün kaldı'), findsOneWidget);
      await tester.tap(find.text('Resmi program'));
      await settle(tester);
      expect(find.text('Fizik Final'), findsOneWidget);
      expect(find.textContaining('Profilinde bölüm bilgisi yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bos durum ve sinav ekleme formu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b);
      await tester.pumpWidget(buildApp(ExamsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('Kişisel sınav eklemedin'), findsOneWidget);
      await tester.tap(find.text('Sınav ekle'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Quiz 1');
      await tester.tap(find.text('Sınavı ekle'));
      await settle(tester);
      expect(find.text('Sınav tarihini seç.'), findsOneWidget); // tarih zorunlu
      await unmount(tester);
    });
  });

  group('akademik takvim', () {
    testWidgets('ay gorunumu, olay listesi ve gun secimi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b).events = [
        {
          'id': 1,
          'kind': 'VIZE',
          'title': 'Ara sınav haftası',
          'startsAt': '2026-11-09T00:00:00+03:00',
          'endsAt': '2026-11-13T23:59:00+03:00',
          'allDay': true,
          'scopeDepartment': null,
          'note': null
        },
        {
          'id': 2,
          'kind': 'RESMI_TATIL',
          'title': 'Atatürk\'ü Anma Günü',
          'startsAt': '2026-11-10T00:00:00+03:00',
          'endsAt': null,
          'allDay': true,
        },
      ];
      await tester.pumpWidget(buildApp(AcademicCalendarPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Kasım 2026'), findsOneWidget);
      expect(b.requests, contains('GET /academic/calendar?month=2026-11'));
      expect(find.text('Ara sınav haftası'), findsWidgets);
      await tester.tap(find.bySemanticsLabel(RegExp(r'^10 Kasım')));
      await tester.pump();
      expect(find.text('Atatürk\'ü Anma Günü'), findsWidgets);
      await tester.tap(find.byTooltip('Sonraki ay'));
      await settle(tester);
      expect(find.text('Aralık 2026'), findsOneWidget);
      expect(b.requests, contains('GET /academic/calendar?month=2026-12'));
      await unmount(tester);
    });
  });

  group('duyurular', () {
    testWidgets('imlecli sayfalama, okunmamis nokta, detay okundu yapar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeAcademic(b)..pageSize = 3;
      f.addAnnouncements(5);
      await tester.pumpWidget(buildApp(AnnouncementsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Duyuru 1'), findsOneWidget);
      expect(b.requests.first, contains('scope=mine'));
      await settle(tester); // kisa liste: sonraki sayfa kendiliginden istenir
      expect(b.requests.any((r) => r.contains('cursor=3')), isTrue);
      expect(find.text('Duyuru 5'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Duyuru 5'));
      await settle(tester);
      expect(find.text('Tam metin Duyuru 5'), findsOneWidget);
      expect(f.announcements.last['read'], true);
      await unmount(tester);
    });

    testWidgets('Tumu sekmesi scope=all ister; bos durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b);
      await tester.pumpWidget(buildApp(AnnouncementsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('Bölümünle ilgili duyuru yok'), findsOneWidget);
      await tester.tap(find.text('Tümü'));
      await settle(tester);
      expect(b.requests.any((r) => r.contains('scope=all')), isTrue);
      await unmount(tester);
    });
  });

  group('giris ve hatirlatma ayarlari', () {
    testWidgets('akademik giris: rozet ve ozetler', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      final f = fakeAcademic(b)..addCourse('Fizik', 1, '10:00', '11:00');
      f.addAnnouncements(3);
      await tester.pumpWidget(buildApp(AcademicHubPage(session: makeSession(b)), size: kPhoneSmall));
      await settle(tester);
      expect(find.text('Ders programı'), findsOneWidget);
      expect(find.text('Sıradaki: Fizik 10:00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('3 okunmamış'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('3 okunmamış'), findsOneWidget);
      expect(platform.calls, greaterThan(0)); // acilista hatirlatmalar kuruldu
      await unmount(tester);
    });

    testWidgets('ayar degisince saklanir ve plan yeniden kurulur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b).addCourse('Fizik', 1, '10:00', '11:00');
      final store = ReminderService.store as MemoryReminderStore;
      await tester.pumpWidget(buildApp(ReminderSettingsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('30 dk'));
      await settle(tester, const Duration(seconds: 1));
      expect(store.value.classLeadMin, 30);
      expect(platform.last.first.at, DateTime.utc(2026, 11, 2, 6, 30)); // 10:00 - 30 dk (Istanbul) = 06:30Z
      await tester.tap(find.byType(Switch).last);
      await settle(tester);
      expect(store.value.examHourBefore, false);
      await unmount(tester);
    });
  });
}
