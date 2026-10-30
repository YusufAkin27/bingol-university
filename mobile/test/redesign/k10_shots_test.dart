@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/announcements_page.dart';
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminder_settings_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// K10 (Stitch 43-45) ekran goruntuleri: akademik giris, ders programi, formlar, sinavlar, takvim, duyuru, hatirlatma.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/k10/uygulama' flutter test test/redesign/k10_shots_test.dart
/// Istege bagli: `K10_LANG=tr|en|ar`, `K10_ONLY=01,05`, `K10_MODES=light,dark,x13` (varsayilan light).
const _dpr = 2.0;

// Persembe 2026-11-05 09:30 Istanbul ("Veri Yapilari" suruyor).
final _thu = DateTime.utc(2026, 11, 5, 6, 30);

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

final _reg = Expando<FakeAcademic>();

FakeAcademic _fa(FakeBackend b) => _reg[b] = fakeAcademic(b);

FakeAcademic _rich(FakeBackend b) {
  final f = _fa(b);
  f.addCourse('Veri Yapıları', 4, '09:00', '11:50', room: 'B-204', instructor: 'Doç. Dr. Ahmet Yılmaz', code: 'BİL 301', color: 'red');
  f.addCourse('Algoritma Analizi', 4, '13:00', '14:50', room: 'D-102', instructor: 'Dr. Öğr. Üyesi Elif Demir', code: 'BİL 305', color: 'indigo');
  f.addCourse('Bilgisayar Ağları', 4, '07:30', '08:20', room: 'Lab-3', instructor: 'Öğr. Gör. Mehmet Kurt', code: 'BİL 309', color: 'indigo');
  f.addCourse('Yazılım Mühendisliği', 1, '09:00', '10:50', room: 'D-204', code: 'BİL 315', color: 'indigo');
  f.addCourse('Ayrık Matematik', 2, '13:30', '15:20', room: 'D-102', code: 'MAT 203', color: 'indigo');
  f.addCourse('Veritabanı Sistemleri', 5, '11:00', '12:50', room: 'Lab-3', code: 'BİL 321', color: 'indigo');
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00', courseId: f.courses[0]['id'] as int);
  f.exams.last['courseName'] = 'Veri Yapıları';
  f.addExam('Algoritma Analizi Quiz', '2026-11-05T15:00:00+03:00', type: 'QUIZ');
  f.exams.last['room'] = 'Mühendislik B-102 Derslik';
  f.exams.last['note'] = 'Sıralama Algoritmaları';
  f.addExam('Sayısal Mantık Ödevi 1', '2026-10-24T10:00:00+03:00', type: 'ODEV');
  f.official = [
    {'id': 1, 'title': 'Türk Dili I', 'type': 'VIZE', 'courseCode': 'TÜR101', 'department': 'Ortak Zorunlu Ders', 'startsAt': '2026-11-20T14:00:00+03:00', 'room': 'Merkezi Derslikler A-101'},
    {'id': 2, 'title': 'Atatürk İlkeleri ve İnkılap Tarihi I', 'type': 'VIZE', 'courseCode': 'AİİT101', 'startsAt': '2026-11-21T10:00:00+03:00', 'room': 'Merkezi Derslikler B-205'},
    {'id': 3, 'title': 'Yabancı Dil I (İngilizce)', 'type': 'FINAL', 'courseCode': 'YDİ101', 'startsAt': '2026-11-22T15:30:00+03:00', 'room': 'İİBF D-104'},
  ];
  f.events = [
    {'id': 1, 'kind': 'SINAV', 'title': 'Ara Sınavlar Başlangıcı', 'startsAt': '2026-11-17T21:00:00Z', 'endsAt': '2026-11-27T21:00:00Z'},
    {'id': 2, 'kind': 'DERS_KAYIT', 'title': 'Final Sınavları', 'startsAt': '2026-11-24T21:00:00Z'},
    {'id': 3, 'kind': 'TATIL', 'title': 'Yarıyıl Tatili', 'startsAt': '2027-01-24T21:00:00Z'},
  ];
  f.addAnnouncements(3);
  return f;
}

FakeAcademic _calendar(FakeBackend b) {
  final f = _fa(b);
  f.events = [
    {'id': 1, 'kind': 'DONEM_BASLANGIC', 'title': '2026-2027 Güz Yarıyılı Ders Başlangıcı', 'note': 'Tüm lisans ve önlisans programlarında güz dönemi örgün eğitim dersleri başlar.', 'startsAt': '2026-10-04T21:00:00Z'},
    {'id': 2, 'kind': 'DERS_KAYIT', 'title': 'Ders Kayıtları ve Danışman Onayları', 'note': 'Öğrenci Bilgi Sistemi (ÖBS) üzerinden ders seçimi ve akademik danışman onayı tamamlanmalıdır.', 'startsAt': '2026-09-27T21:00:00Z', 'endsAt': '2026-10-01T21:00:00Z'},
    {'id': 3, 'kind': 'RESMI_TATIL', 'title': 'Cumhuriyet Bayramı Arifesi Tatili', 'note': 'Saat 13:00 itibarıyla üniversite genelinde idari ve akademik faaliyetler tatil edilecektir.', 'startsAt': '2026-10-27T21:00:00Z', 'allDay': false},
    {'id': 4, 'kind': 'RESMI_TATIL', 'title': 'Cumhuriyet Bayramı', 'note': '29 Ekim Cumhuriyet Bayramı kapsamında tüm yerleşkelerde tam gün resmi tatil uygulanır.', 'startsAt': '2026-10-28T21:00:00Z'},
    {'id': 5, 'kind': 'TATIL', 'title': 'Senato Kararı ile İdari İzin', 'note': 'Üniversite Senatosu kararı uyarınca bayram tatiliyle birleştirilen idari izin günü.', 'startsAt': '2026-10-29T21:00:00Z'},
  ];
  return f;
}

class _Scene {
  const _Scene(this.file, this.build, {this.setup, this.after, this.now, this.height = 844, this.settleMs = 900, this.perm});
  final String file;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
  final DateTime? now;
  final double height;
  final int settleMs;
  final PermState? perm;
}

Future<void> _tapText(WidgetTester t, String text, {int skip = 0}) async {
  final f = find.text(text);
  await t.ensureVisible(f.at(skip));
  await t.tap(f.at(skip));
  await settle(t, const Duration(milliseconds: 700));
}

/// [path] (ve altindaki) isteklere 503 doner (akademik bakim).
void _maint(FakeBackend b, String path) => b.handlers.insert(
    0,
    (req, p) => p == path || p.startsWith('$path/')
        ? const FakeResult.json({'code': 'MAINTENANCE', 'message': 'Akademik hizmetler bakımda. Daha sonra tekrar deneyin.'}, status: 503)
        : null);

List<Course> _courses(FakeBackend b) => [for (final c in _reg[b]?.courses ?? const <Map<String, dynamic>>[]) Course.fromJson(c)];

final _scenes = <_Scene>[
  // ---- 43
  _Scene('01_hub_dolu', (b) => AcademicHubPage(session: makeSession(b)), setup: _rich, now: _thu, height: 900),
  _Scene('02_hub_bos', (b) => AcademicHubPage(session: makeSession(b)), setup: (b) {
    final f = _fa(b)
      ..profileComplete = false
      ..unread = 0;
    f.semester = null;
  }, height: 1130),
  _Scene('02b_hub_bakim', (b) => AcademicHubPage(session: makeSession(b)), setup: (b) {
    _fa(b);
    _maint(b, '/timetable');
  }, height: 700),
  _Scene('03_ders_programi', (b) => TimetablePage(session: makeSession(b)), setup: _rich, now: _thu, height: 1340),
  _Scene('04a_ders_donem_yok', (b) => TimetablePage(session: makeSession(b)), setup: (b) => _fa(b).semester = null, height: 520),
  _Scene('04b_ders_yok', (b) => TimetablePage(session: makeSession(b)), setup: (b) => _fa(b), height: 560),
  _Scene('04c_gun_bos', (b) => TimetablePage(session: makeSession(b)), setup: _rich, now: _thu, height: 1000, after: (t) => _tapText(t, 'Cum')),
  _Scene('05a_ders_hata', (b) => TimetablePage(session: makeSession(b)), setup: (b) {
    _fa(b);
    b.offline = true;
  }, settleMs: 2500, height: 500),
  _Scene('05b_ders_bayat', (b) => TimetablePage(session: makeSession(b)), setup: _rich, now: _thu, height: 700, after: (t) async {
    final b = _lastBackend!;
    b.offline = true;
    await t.fling(find.byType(Scrollable).first, const Offset(0, 500), 1200);
    await settle(t, const Duration(seconds: 3));
  }),
  _Scene('06_donem_sheet', (b) => TimetablePage(session: makeSession(b)), setup: (b) {
    _rich(b);
    final f = _reg[b]!;
    f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-14', 'endDate': '2027-01-15', 'current': true};
  }, now: _thu, after: (t) => _tapText(t, '2026-2027 Güz')),
  // ---- 44
  _Scene('07_ders_formu', (b) => CourseFormPage(session: makeSession(b), initialDay: 1), setup: (b) => _fa(b), height: 1200),
  _Scene('08a_ders_formu_hata', (b) => CourseFormPage(session: makeSession(b), initialDay: 4), setup: (b) => _fa(b), height: 1250, after: (t) async {
    await t.ensureVisible(find.text('Dersi ekle'));
    await t.tap(find.text('Dersi ekle'));
    await settle(t, const Duration(milliseconds: 600));
  }),
  _Scene('08b_ders_formu_cakisma', (b) => CourseFormPage(session: makeSession(b), initialDay: 4, allCourses: _courses(b)), setup: _rich, height: 1250, after: (t) async {
    await t.enterText(find.byType(TextField).first, 'Kimya');
    await t.pump();
    await t.ensureVisible(find.text('Dersi ekle'));
    await t.tap(find.text('Dersi ekle'));
    await settle(t, const Duration(milliseconds: 700));
  }),
  _Scene('09_sinavlar', (b) => ExamsPage(session: makeSession(b)), setup: _rich, now: _thu, height: 1000),
  _Scene('10_sinavlar_resmi', (b) => ExamsPage(session: makeSession(b), initialTab: 1), setup: (b) {
    _rich(b);
    _reg[b]!.profileComplete = false;
  }, now: _thu, height: 1000),
  _Scene('11a_sinav_formu', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _rich, height: 1250),
  _Scene('11b_sinav_formu_hata', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _rich, height: 1250, after: (t) async {
    await t.ensureVisible(find.text('Sınavı ekle'));
    await t.tap(find.text('Sınavı ekle'));
    await settle(t, const Duration(milliseconds: 600));
  }),
  _Scene('11c_sinav_duzenle', (b) {
    final e = Exam.fromJson(_reg[b]!.exams.first);
    return ExamFormPage(session: makeSession(b), exam: e, courses: _courses(b));
  }, setup: _rich, height: 1000),
  _Scene('12a_sinavlar_bos', (b) => ExamsPage(session: makeSession(b)), setup: (b) => _fa(b), height: 780),
  _Scene('12b_sinavlar_bakim', (b) => ExamsPage(session: makeSession(b)), setup: (b) {
    _fa(b);
    _maint(b, '/timetable/exams');
  }, height: 500),
  _Scene('12c_sinavlar_resmi_bos', (b) => ExamsPage(session: makeSession(b), initialTab: 1), setup: (b) => _fa(b), height: 600),
  // ---- 45
  _Scene('13_takvim_ay', (b) => AcademicCalendarPage(session: makeSession(b)), setup: _calendar, now: DateTime.utc(2026, 10, 15, 8), height: 1500),
  _Scene('14_takvim_gun', (b) => AcademicCalendarPage(session: makeSession(b)), setup: (b) {
    final f = _calendar(b);
    f.events = [f.events[3]];
  }, now: DateTime.utc(2026, 10, 14, 8), height: 1200, after: (t) => _tapText(t, '14')),
  _Scene('14b_takvim_bos_ay', (b) => AcademicCalendarPage(session: makeSession(b)), setup: (b) => _fa(b), now: DateTime.utc(2026, 10, 14, 8), height: 800),
  _Scene('15_duyurular', (b) => AnnouncementsPage(session: makeSession(b)), setup: (b) {
    final f = _fa(b);
    f.pageSize = 10;
    f.announcements.addAll([
      {
        'id': 1,
        'title': '2026-2027 Güz Dönemi Final Sınav Takvimi Taslağı',
        'body': 'Mühendislik Fakültesi Bilgisayar Mühendisliği Bölümü güz yarıyılı final sınav tarihleri taslağı askıya çıkarılmıştır.',
        'department': 'Bilgisayar Mühendisliği',
        'faculty': 'Bilgisayar Müh. Bölüm Bşk.',
        'pinned': true,
        'publishAt': '2026-10-15T11:20:00+03:00',
        'read': false,
      },
      {
        'id': 2,
        'title': 'Kütüphane Çalışma Salonları 7/24 Hizmet Düzenlemesi',
        'body': 'Merkezi kütüphane vize ve final haftalarında öğrencilerin kullanımına kesintisiz açık tutulacaktır.',
        'faculty': 'Kütüphane & Dokümantasyon D.B.',
        'pinned': false,
        'publishAt': '2026-10-14T09:45:00+03:00',
        'read': false,
      },
      {
        'id': 3,
        'title': 'Staj Defteri Teslim Tarihleri ve Komisyon Değerlendirmesi',
        'body': 'Yaz stajını tamamlayan 3. ve 4. sınıf öğrencilerinin staj evraklarını en geç 30 Ekim tarihine kadar teslim etmesi gerekmektedir.',
        'department': 'Bilgisayar Mühendisliği',
        'faculty': 'Staj & Kariyer Komisyonu',
        'pinned': false,
        'publishAt': '2026-10-12T10:00:00+03:00',
        'read': true,
      },
    ]);
  }, now: DateTime.utc(2026, 10, 15, 8), height: 1000),
  _Scene('15b_duyurular_bos', (b) => AnnouncementsPage(session: makeSession(b)), setup: (b) => _fa(b), height: 600),
  _Scene('16_duyuru_detay', (b) => AnnouncementDetailPage(session: makeSession(b), id: 1), setup: (b) {
    final f = _fa(b);
    f.announcements.add({
      'id': 1,
      'title': '2026-2027 Güz Dönemi Final Programı Yayınlandı',
      'body':
          'Değerli öğrencilerimiz, 2026-2027 Eğitim-Öğretim Yılı Güz Yarıyılı final sınav programı fakülte yönetim kurulu kararı doğrultusunda kesinleşmiştir.\n\nSınav çakışması bulunan veya mazeret bildirecek öğrencilerin ilgili formları bölüm sekreterliğine 3 iş günü içerisinde elden teslim etmesi zorunludur. Sınav salonlarında öğrenci kimlik kartlarının hazır bulundurulması gerekmektedir.',
      'pinned': true,
      'publishAt': '2026-10-14T11:30:00+03:00',
      'attachmentUrl': 'https://www.bingol.edu.tr/files/Guz_Final_Programi_v2.pdf',
      'read': false,
    });
  }, now: DateTime.utc(2026, 10, 15, 8), height: 960),
  _Scene('17_hatirlatma', (b) => ReminderSettingsPage(session: makeSession(b)), setup: (b) => _fa(b), height: 900),
  _Scene('18_hatirlatma_izin_yok', (b) => ReminderSettingsPage(session: makeSession(b)), setup: (b) => _fa(b), height: 1100, perm: PermState.denied),
];

FakeBackend? _lastBackend;

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
  final lang = Platform.environment['K10_LANG'] ?? 'tr';
  final only = (Platform.environment['K10_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K10_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(lang == 'ar'));
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
    PermissionService.instance = SystemPermissionService();
  });

  for (final v in variants) {
    for (final s in _scenes) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$lang';
      testWidgets('k10 $name', skip: skip != null, (tester) async {
        academicClock = () => s.now ?? DateTime.utc(2026, 11, 2, 5, 0);
        ReminderService.platform = _Platform();
        ReminderService.store = MemoryReminderStore();
        PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: s.perm ?? PermState.granted});
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
        _lastBackend = b;
        s.setup?.call(b);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: p00App(s.build(b), lang: lang, dark: v.$2, scale: v.$3, scaffold: false)));
        await settle(tester, Duration(milliseconds: s.settleMs));
        if (s.after != null) {
          await s.after!(tester);
          await settle(tester, const Duration(milliseconds: 900));
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
        await unmount(tester);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 7));
        }
      });
    }
  }
}
