import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/platform/device_calendar.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/alarm_service.dart';
import 'package:bu_kampus/features/academic/alarm_sheets.dart';
import 'package:bu_kampus/features/academic/calendar_sync.dart';
import 'package:bu_kampus/features/academic/calendar_sync_sheet.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../redesign/p00_support.dart';
import '../support/fake_app.dart';
import 'fakes.dart';

/// Arayuz: "Takvime ekle", "Ilk sinav alarmlarini kur", "Sabah alarmlarini kur" eylemleri, onizleme alt sayfalari,
/// iOS bildirim yedeginin farki ve 320/390 x 1.0/1.3 x tr/en/ar x acik/koyu tasma matrisi.
final _nov = DateTime.utc(2026, 11, 5, 6, 0); // Persembe 09:00 Istanbul

Map<String, dynamic> _ev(int id, String kind, String title, String startsAt, {String? endsAt}) =>
    {'id': id, 'kind': kind, 'title': title, 'startsAt': startsAt, if (endsAt != null) 'endsAt': endsAt};

FakeBackend _backend() {
  final b = FakeBackend();
  final f = fakeAcademic(b);
  f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
  f.addCourse('Algoritma Analizi', 3, '09:00', '10:45', room: 'B-204');
  f.addCourse('Ayrık Matematik', 3, '15:30', '17:15');
  f.addCourse('Fizik', 4, '10:00', '11:00');
  f.addCourse('Öğleden Sonra', 5, '13:00', '14:00');
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00');
  f.addExam('İkinci Sınav', '2026-11-18T12:30:00+03:00');
  f.addExam('Algoritma Final', '2026-12-21T14:00:00+03:00', type: 'FINAL');
  f.events = [
    _ev(1, 'VIZE', 'Ara sınavlar', '2026-11-17T21:00:00Z', endsAt: '2026-11-21T21:00:00Z'),
    _ev(2, 'DERS_KAYIT', 'Ders kayıt son günü', '2026-11-29T21:00:00Z'),
  ];
  return b;
}

Future<List<AcademicEvent>> _loader(DateTime from, DateTime to) async => [
      AcademicEvent.fromJson(_ev(1, 'VIZE', 'Ara sınavlar', '2026-11-17T21:00:00Z', endsAt: '2026-11-21T21:00:00Z')),
      AcademicEvent.fromJson(_ev(2, 'DERS_KAYIT', 'Ders kayıt son günü', '2026-11-29T21:00:00Z')),
    ];

Widget _scroll(Widget body) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), child: body);

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t, const Duration(milliseconds: 500));
}

void main() {
  setUpAll(loadTestFonts);
  late FakeDeviceCalendarBackend cal;
  late CalendarSyncService sync;

  setUp(() {
    academicClock = () => _nov;
    useFakeAlarms(now: () => _nov);
    cal = FakeDeviceCalendarBackend(state: CalAccess.notDetermined);
    sync = CalendarSyncService(backend: cal, store: MemoryCalendarSyncStore(), clock: () => _nov);
    CalendarSyncService.instance = sync;
    DeviceCalendarBackend.instance = cal;
    PermissionService.instance = FakePermissionService();
  });
  tearDown(() {
    academicClock = DateTime.now;
    resetAlarms();
    CalendarSyncService.instance = CalendarSyncService();
    DeviceCalendarBackend.instance = ChannelDeviceCalendarBackend();
    PermissionService.instance = SystemPermissionService();
  });

  group('Cihaz takvimine ekle', () {
    testWidgets('akademik takvim sayfasinda satir; dokununca izin gerekcesi + ekle', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(AcademicCalendarPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('Cihaz takvimine ekle'), findsOneWidget);
      await _tapText(t, 'Cihaz takvimine ekle');
      // alt sayfa: baslik + izin gerekcesi + dugme
      expect(find.textContaining('takvim erişimi gerekir'), findsOneWidget);
      expect(find.text('Takvime ekle'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('izin ver -> yaz -> ozet; ikinci calistirma cift kayit olusturmaz; sayfa satiri "N etkinlik" olur', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      await _tapText(t, 'Takvime ekle');
      expect(find.text('2 etkinlik eklendi, 0 güncellendi, 0 aynı kaldı.'), findsOneWidget);
      expect(cal.events, hasLength(2));
      expect(cal.requests, 1);
      // tum gun etkinlik + 08:00 hatirlatici
      expect(cal.events.values.every((s) => s.allDay && s.alarmDayMin == 480), isTrue);
      // yeniden ac: "Guncelle" ve mevcut sayisi
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      expect(find.text('Cihaz takviminde · 2 etkinlik'), findsOneWidget);
      await _tapText(t, 'Güncelle');
      expect(find.text('0 etkinlik eklendi, 0 güncellendi, 2 aynı kaldı.'), findsOneWidget);
      expect(cal.events, hasLength(2));
      expect(cal.creates, 2);
      await unmount(t);
    });

    testWidgets('izin reddedildi: anlasilir aciklama + Ayarlari ac; dugme pasif', (t) async {
      cal.state = CalAccess.denied;
      final perm = PermissionService.instance as FakePermissionService;
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      expect(find.textContaining('Takvim izni kapalı'), findsOneWidget);
      await _tapText(t, 'Takvime ekle');
      expect(cal.events, isEmpty);
      await _tapText(t, 'Ayarları aç');
      expect(perm.settingsOpened, 1);
      await unmount(t);
    });

    testWidgets('sistem istemi reddedilirse yazilmaz, aciklama gorunur', (t) async {
      cal = FakeDeviceCalendarBackend(state: CalAccess.notDetermined, onRequest: CalAccess.denied);
      sync = CalendarSyncService(backend: cal, store: MemoryCalendarSyncStore(), clock: () => _nov);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      await _tapText(t, 'Takvime ekle');
      expect(find.textContaining('Takvim izni kapalı'), findsOneWidget);
      expect(cal.events, isEmpty);
      await unmount(t);
    });

    testWidgets('birden cok takvim: secici gorunur, secilen takvime yazilir', (t) async {
      cal = FakeDeviceCalendarBackend(state: CalAccess.granted, calendars: const [
        DeviceCalendarInfo(id: 'c1', name: 'Kisisel', account: 'a@x.com', primary: true),
        DeviceCalendarInfo(id: 'c2', name: 'Okul', account: 'b@x.com'),
      ]);
      sync = CalendarSyncService(backend: cal, store: MemoryCalendarSyncStore(), clock: () => _nov);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      expect(find.text('Eklenecek takvim'), findsOneWidget);
      expect(find.text('Kisisel'), findsOneWidget);
      expect(find.text('BÜ Kampüs (yeni yerel takvim)'), findsOneWidget);
      await _tapText(t, 'Okul');
      await _tapText(t, 'Takvime ekle');
      expect(cal.events.values.every((s) => s.calendarId == 'c2'), isTrue);
      await unmount(t);
    });

    testWidgets('Takvimden kaldir: onay -> yalniz bizim etkinlikler silinir', (t) async {
      cal = FakeDeviceCalendarBackend(state: CalAccess.granted);
      sync = CalendarSyncService(backend: cal, store: MemoryCalendarSyncStore(), clock: () => _nov);
      cal.events['foreign'] = const DeviceEventSpec(calendarId: 'c1', title: 'Baska');
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      await _tapText(t, 'Takvime ekle');
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      await _tapText(t, 'Takvimden kaldır');
      expect(find.text('BÜ Kampüs etkinlikleri kaldırılsın mı?'), findsOneWidget);
      await _tapText(t, 'Takvimden kaldır', last: true);
      expect(find.text('2 etkinlik takvimden kaldırıldı.'), findsOneWidget);
      expect(cal.events.keys, ['foreign']);
      await unmount(t);
    });

    testWidgets('takvim yok: yerel BU Kampus takvimi olusturulup yazilir', (t) async {
      cal = FakeDeviceCalendarBackend(state: CalAccess.granted, calendars: const []);
      sync = CalendarSyncService(backend: cal, store: MemoryCalendarSyncStore(), clock: () => _nov);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(CalendarSyncSheetBody(key: UniqueKey(), loader: _loader, service: sync)));
      await settle(t);
      expect(find.textContaining('yerel bir takvim oluşturulacak'), findsOneWidget);
      await _tapText(t, 'Takvime ekle');
      expect(cal.events.values.every((s) => s.calendarId == 'new-BÜ Kampüs'), isTrue);
      await unmount(t);
    });
  });

  group('Sinav alarmlari', () {
    testWidgets('Android: eylem satiri + onizleme (ilk sinav 10:30 -> alarm 09:30; 12:30 icin alarm yok); ileri tarih ertelenir', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('İlk sınav alarmlarını kur'), findsOneWidget);
      await _tapText(t, 'İlk sınav alarmlarını kur');
      expect(find.text('Sınav günü alarmları'), findsOneWidget);
      expect(find.text('Sınav 10:30 → Alarm 09:30'), findsOneWidget);
      expect(find.text('12:30 sınavı için alarm yok'), findsOneWidget);
      expect(find.text('Sınav 14:00 → Alarm 13:00'), findsOneWidget);
      expect(find.textContaining('ileri tarihli tek seferlik alarmı desteklemez'), findsOneWidget);
      expect(find.text('2 alarmı kur'), findsOneWidget);
      // ikinci sinav satirini kapat -> 1 alarm
      await t.tap(find.byType(Switch).last);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('1 alarmı kur'), findsOneWidget);
      await _tapText(t, '1 alarmı kur');
      expect(find.text('1 alarm sınav gününden önce hatırlatılacak.'), findsOneWidget);
      expect(find.textContaining('Saat uygulaması'), findsWidgets);
      await unmount(t);
    });

    testWidgets('Android: 24 saat icindeki alarm dogrudan Saat uygulamasina kurulur', (t) async {
      academicClock = () => DateTime.utc(2026, 11, 17, 18, 0); // 17 Kasim 21:00 -> alarm 18 Kasim 09:30 (12.5 saat)
      final fake = useFakeAlarms(now: academicClock);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      await _tapText(t, 'İlk sınav alarmlarını kur');
      await _tapText(t, '2 alarmı kur');
      expect(find.text('1 alarm kuruldu. Saat uygulamasından kontrol edin.'), findsOneWidget);
      expect(fake.requests.single.key.startsWith('exam-'), isTrue);
      expect((fake.requests.single.hour, fake.requests.single.minute), (9, 30));
      expect(fake.requests.single.weekdays, isEmpty);
      await unmount(t);
    });

    testWidgets('iOS: Saat uygulamasina alarm eklenemez notu, bildirim etiketleri', (t) async {
      useFakeAlarms(clock: false, now: () => _nov);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('İlk sınav alarmlarını kur'), findsNothing);
      await _tapText(t, 'Sınavları bildirimle hatırlat');
      expect(find.text('Sınav günü bildirimleri'), findsOneWidget);
      expect(find.textContaining('Saat uygulamasına alarm eklemeye izin vermez'), findsOneWidget);
      expect(find.textContaining('ileri tarihli'), findsNothing); // iOS tarihli bildirim kurar, erteleme yok
      expect(find.text('2 bildirimi kur'), findsOneWidget);
      await _tapText(t, '2 bildirimi kur');
      expect(find.text('2 bildirim kuruldu.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yaklasan sinav yoksa eylem satiri yok', (t) async {
      final b = FakeBackend();
      fakeAcademic(b).addExam('Gecmis', '2026-10-01T10:00:00+03:00');
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('İlk sınav alarmlarını kur'), findsNothing);
      await unmount(t);
    });

    testWidgets('ertelenmis alarmin zamani gelince sayfada "Simdi kur" bandi cikar ve tek dokunusla kurulur', (t) async {
      // Alarm 18 Kasim 09:30. Simdi: 17 Kasim 20:30.
      final now = DateTime.utc(2026, 11, 17, 17, 30);
      academicClock = () => now;
      final fake = useFakeAlarms(now: () => now);
      final plans = [
        PendingExamAlarm(key: 'exam-1', alarmAtMs: DateTime.utc(2026, 11, 18, 6, 30).millisecondsSinceEpoch, examStartMs: DateTime.utc(2026, 11, 18, 7, 30).millisecondsSinceEpoch, title: 'Veri Yapıları Vize', label: 'Sınav 10:30: Veri Yapıları Vize')
      ];
      final store = MemoryAlarmStateStore()..value = AlarmState(pending: plans);
      AlarmService.instance = AlarmService(alarms: fake, store: store, reminders: null, gap: Duration.zero, clock: () => now);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('1 sınav alarmı kurulmaya hazır.'), findsOneWidget);
      await _tapText(t, 'Şimdi kur');
      expect(fake.requests, hasLength(1));
      expect((fake.requests.single.hour, fake.requests.single.minute), (9, 30));
      expect(find.text('1 sınav alarmı kurulmaya hazır.'), findsNothing);
      await unmount(t);
    });
  });

  group('Ders alarmlari', () {
    Future<void> openClassSheet(WidgetTester t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(TimetablePage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      final f = find.text('Sabah alarmlarını kur');
      await t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -200));
      await t.tap(f);
      await settle(t, const Duration(milliseconds: 600));
    }

    testWidgets('Android: onizleme (Car 09:00 -> alarm 08:00 her hafta; Per 10:00 -> 09:00; Cum ogleden sonra atlanir) ve kurulum', (t) async {
      final fake = useFakeAlarms(now: () => _nov);
      await openClassSheet(t);
      expect(find.text('Sabah ders alarmları'), findsOneWidget);
      expect(find.text('Ders 09:00 → Alarm 08:00 · her hafta'), findsOneWidget);
      expect(find.text('Ders 10:00 → Alarm 09:00 · her hafta'), findsOneWidget);
      expect(find.textContaining('Cuma: ilk ders öğleden sonra, alarm yok'), findsOneWidget);
      expect(find.text('2 alarmı kur'), findsOneWidget);
      await _tapText(t, '2 alarmı kur');
      expect(find.text('2 tekrarlı alarm kuruldu. Saat uygulamasından kontrol edin; silmek de oradan.'), findsOneWidget);
      expect(fake.requests.map((s) => '${s.hour}:${s.minute}:${s.weekdays}'), ['8:0:[3]', '9:0:[4]']);
      expect(fake.requests.every((s) => s.repeats), isTrue);
      await unmount(t);
    });

    testWidgets('ayni alarmlar tekrar kurulmak istenirse Saat cift alarm uyarisi + "Yine de kur"', (t) async {
      final fake = useFakeAlarms(now: () => _nov);
      await openClassSheet(t);
      await _tapText(t, '2 alarmı kur');
      // ikinci acilis
      await t.tap(find.text('Kapat').first);
      await settle(t, const Duration(milliseconds: 500));
      final f = find.text('Sabah alarmlarını kur');
      await t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -200));
      await t.tap(f);
      await settle(t, const Duration(milliseconds: 600));
      await _tapText(t, '2 alarmı kur');
      expect(find.textContaining('çift alarm olabilir'), findsOneWidget);
      expect(fake.requests, hasLength(2)); // henuz tekrar kurulmadi
      await _tapText(t, 'Yine de kur');
      expect(fake.requests, hasLength(4));
      await unmount(t);
    });

    testWidgets('iOS: eylem etiketi "bildirim", Saat notu', (t) async {
      useFakeAlarms(clock: false, now: () => _nov);
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(TimetablePage(session: makeSession(_backend())), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      final f = find.text('Sabah dersleri için bildirim kur');
      await t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -200));
      await t.tap(f);
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Sabah ders bildirimleri'), findsOneWidget);
      expect(find.textContaining('Saat uygulamasına alarm eklemeye izin vermez'), findsOneWidget);
      expect(find.text('2 bildirimi kur'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('sabah dersi yoksa bos durum, dugme yok', (t) async {
      final b = FakeBackend();
      final f = fakeAcademic(b);
      f.semester = {'id': 3, 'name': 'Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
      f.addCourse('Aksam', 2, '14:00', '15:00');
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(TimetablePage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 800));
      final a = find.text('Sabah alarmlarını kur');
      await t.dragUntilVisible(a, find.byType(ListView).first, const Offset(0, -200));
      await t.tap(a);
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Sabah dersi yok; alarm kurulmayacak.'), findsOneWidget);
      expect(find.textContaining('alarmı kur'), findsNothing);
      await unmount(t);
    });
  });

  group('tasma matrisi (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('sinav alarm onizlemesi', (t) async {
      final exams = [
        Exam(id: 1, title: 'Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları Vize Sınavı', startsAt: wallToInstant(2026, 11, 18, 10, 30), room: 'B-204'),
        Exam(id: 2, title: 'İkinci', startsAt: wallToInstant(2026, 11, 18, 12, 30)),
        Exam(id: 3, title: 'Gece', startsAt: wallToInstant(2026, 11, 20, 0, 30)),
      ];
      await p00Matrix(t, () => _scroll(ExamAlarmSheetBody(exams: exams, service: AlarmService.instance)), scaffold: true);
    });

    testWidgets('ders alarm onizlemesi', (t) async {
      final courses = [
        Course(id: 1, name: 'Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', sessions: const [
          CourseSession(dayOfWeek: 1, start: '08:15', end: '09:00'),
          CourseSession(dayOfWeek: 2, start: '14:00', end: '15:00'),
          CourseSession(dayOfWeek: 3, start: '09:15', end: '10:00'),
        ])
      ];
      await p00Matrix(t, () => _scroll(ClassAlarmSheetBody(courses: courses, semester: null, service: AlarmService.instance)), scaffold: true);
    });

    testWidgets('takvim yazma alt sayfasi (izin gerekcesi / reddedildi / coklu takvim)', (t) async {
      for (final access in [CalAccess.notDetermined, CalAccess.denied, CalAccess.granted]) {
        final be = FakeDeviceCalendarBackend(state: access, calendars: const [
          DeviceCalendarInfo(id: 'c1', name: 'Çok Uzun Bir Takvim Adı Kişisel Hesap', account: 'cok.uzun.bir.eposta.adresi@bingol.edu.tr', primary: true),
          DeviceCalendarInfo(id: 'c2', name: 'Okul'),
        ]);
        final svc = CalendarSyncService(backend: be, store: MemoryCalendarSyncStore(), clock: () => _nov);
        await p00Matrix(t, () => _scroll(CalendarSyncSheetBody(loader: _loader, service: svc)), scaffold: true);
      }
    });

    testWidgets('akademik takvim, sinavlar, ders programi sayfalari (yeni satirlarla)', (t) async {
      await p00Matrix(t, () => AcademicCalendarPage(session: makeSession(_backend())), scaffold: false, settleMs: 800);
      await p00Matrix(t, () => ExamsPage(session: makeSession(_backend())), scaffold: false, settleMs: 800);
      await p00Matrix(t, () => TimetablePage(session: makeSession(_backend())), scaffold: false, settleMs: 800);
    });
  });
}
