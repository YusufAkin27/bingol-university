@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Paket 17 (Akademik 1) ekran goruntuleri: ders programi, ders formu, sinavlar, sinav formu, donem alt sayfasi,
/// yeni donem diyalogu, silme/cakisma onaylari, saat/tarih secici; tum durumlar (dolu, bos, iskelet, hata).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p17/sonraki' flutter test test/redesign/p17_shots_test.dart
/// Istege bagli: `P17_LANG=tr|en|ar`, `P17_ONLY=01,05`, `P17_MODES=light,dark,x13` (varsayilan light).
const _dpr = 2.5;

// Pazartesi 2026-11-02 08:00 Istanbul; "ders suruyor" sahnesi icin 09:30.
final _morning = DateTime.utc(2026, 11, 2, 5, 0);
final _inClass = DateTime.utc(2026, 11, 2, 6, 30);

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

FakeAcademic _rich(FakeBackend b) {
  final f = _fa(b);
  f.addCourse('Veri Yapıları ve Algoritmalar', 1, '09:00', '10:50', room: 'B-204', instructor: 'Dr. Ayşe Yılmaz', code: 'BIL201');
  f.addCourse('Matematik II', 1, '11:00', '12:50', room: 'A-101', instructor: 'Prof. Dr. Mehmet Kaya', code: 'MAT102', color: 'red');
  f.addCourse('Fizik Laboratuvarı', 1, '14:00', '15:50', room: 'Lab-3', instructor: 'Dr. Elif Demir', code: 'FIZ110', color: 'green');
  f.addCourse('İşletim Sistemleri', 3, '10:00', '11:50', room: 'B-210', instructor: 'Doç. Dr. Can Öztürk', code: 'BIL305', color: 'purple');
  (f.courses[0]['sessions'] as List).add({'id': 900, 'dayOfWeek': 3, 'start': '13:00', 'end': '14:50', 'room': 'B-204'});
  f.addExam('Veri Yapıları Vize', '2026-11-04T10:00:00+03:00', courseId: f.courses[0]['id'] as int);
  f.exams.last['courseName'] = 'Veri Yapıları ve Algoritmalar';
  f.addExam('Matematik II Quiz', '2026-11-09T13:30:00+03:00', type: 'QUIZ');
  f.addExam('Fizik Final', '2026-12-21T09:00:00+03:00', type: 'FINAL');
  f.addExam('Geçmiş Quiz', '2026-10-21T10:00:00+03:00', type: 'QUIZ');
  f.official = [
    {
      'id': 1,
      'title': 'Fizik I Final',
      'type': 'FINAL',
      'courseCode': 'FIZ101',
      'department': 'Fizik',
      'grade': '1',
      'startsAt': '2026-11-20T09:00:00+03:00',
      'endsAt': '2026-11-20T10:30:00+03:00',
      'room': 'A-1',
      'note': 'Kimlik kartı zorunlu'
    },
    {
      'id': 2,
      'title': 'Matematik II Bütünleme',
      'type': 'BUT',
      'courseCode': 'MAT102',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '1',
      'startsAt': '2026-11-25T14:00:00+03:00',
      'endsAt': null,
      'room': null,
      'note': null
    },
  ];
  return f;
}

class _Scene {
  const _Scene(this.file, this.build, {this.setup, this.after, this.now, this.height = 844, this.settleMs = 900});
  final String file;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
  final DateTime? now;
  final double height;
  final int settleMs;
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

Future<void> _tapTip(WidgetTester t, String tip) async {
  await t.tap(find.byTooltip(tip).first);
  await settle(t, const Duration(milliseconds: 700));
}

final _scenes = <_Scene>[
  _Scene('01_ders_programi', (b) => TimetablePage(session: makeSession(b)), setup: _rich),
  _Scene('02_ders_programi_derste', (b) => TimetablePage(session: makeSession(b)), setup: _rich, now: _inClass),
  _Scene('03_ders_programi_carsamba', (b) => TimetablePage(session: makeSession(b)), setup: _rich, after: (t) => _tapText(t, _dayShort('Çar'))),
  _Scene('04_ders_programi_bos', (b) => TimetablePage(session: makeSession(b)), setup: (b) => _fa(b)),
  _Scene('05_ders_programi_iskelet', (b) => TimetablePage(session: makeSession(b)), setup: (b) {
    _rich(b);
    b.delay = const Duration(seconds: 6);
  }, settleMs: 300),
  _Scene('06_ders_programi_hata', (b) => TimetablePage(session: makeSession(b)), setup: (b) {
    _fa(b);
    b.offline = true;
  }, settleMs: 2500),
  _Scene('07_donem_alt_sayfasi', (b) => TimetablePage(session: makeSession(b)), setup: _rich, after: (t) => _tapText(t, '2026-2027 Güz')),
  _Scene('08_yeni_donem_diyalogu', (b) => TimetablePage(session: makeSession(b)), setup: _rich, after: (t) async {
    await _tapText(t, '2026-2027 Güz');
    await _tapText(t, _acadTimeAddSemester);
  }),
  _Scene('09_ders_formu_yeni', (b) => CourseFormPage(session: makeSession(b), initialDay: 1), setup: (b) => _fa(b)),
  _Scene('10_ders_formu_duzenle', (b) {
    final c = Course.fromJson(_reg[b]!.courses.first);
    return CourseFormPage(session: makeSession(b), course: c, allCourses: [c]);
  }, setup: _rich, height: 1250),
  _Scene('11_ders_formu_silme_onayi', (b) {
    final c = Course.fromJson(_reg[b]!.courses.first);
    return CourseFormPage(session: makeSession(b), course: c, allCourses: [c]);
  }, setup: _rich, after: (t) => _tapTip(t, _acadTimeDeleteCourse)),
  _Scene('12_ders_formu_cakisma', (b) => CourseFormPage(session: makeSession(b), initialDay: 1, allCourses: _courses(b)), setup: _rich, after: (t) async {
    await t.enterText(find.byType(TextField).first, 'Kimya');
    await t.pump();
    await _tapText(t, _acadTimeAddCourseBtn);
  }),
  _Scene('13_ders_formu_saat_secici', (b) => CourseFormPage(session: makeSession(b), initialDay: 1),
      setup: (b) => _fa(b),
      after: (t) async {
        await t.tap(find.text('09:00').first);
        await settle(t, const Duration(milliseconds: 900));
      }),
  _Scene('14_sinavlar', (b) => ExamsPage(session: makeSession(b)), setup: _rich),
  _Scene('15_sinavlar_bos', (b) => ExamsPage(session: makeSession(b)), setup: (b) => _fa(b)),
  _Scene('16_sinavlar_resmi', (b) => ExamsPage(session: makeSession(b), initialTab: 1), setup: _rich),
  _Scene('17_sinavlar_resmi_bos', (b) => ExamsPage(session: makeSession(b), initialTab: 1), setup: (b) {
    _fa(b).profileComplete = false;
  }),
  _Scene('18_sinavlar_iskelet', (b) => ExamsPage(session: makeSession(b)), setup: (b) {
    _rich(b);
    b.delay = const Duration(seconds: 6);
  }, settleMs: 300),
  _Scene('19_sinavlar_hata', (b) => ExamsPage(session: makeSession(b)), setup: (b) {
    _fa(b);
    b.offline = true;
  }, settleMs: 2500),
  _Scene('20_sinav_formu', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _rich),
  _Scene('21_sinav_formu_hata', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _rich, after: (t) async {
    await t.enterText(find.byType(TextField).first, 'Quiz 1');
    await t.pump();
    await _tapText(t, _acadFormAdd);
  }),
  _Scene('22_sinav_formu_tarih_secici', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _rich, after: (t) async {
    await t.tap(find.text(_acadFormPickDate).first);
    await settle(t, const Duration(milliseconds: 900));
  }),
  _Scene('23_sinav_formu_duzenle_silme', (b) {
    final e = Exam.fromJson(_reg[b]!.exams.first);
    return ExamFormPage(session: makeSession(b), exam: e, courses: _courses(b));
  }, setup: _rich, after: (t) => _tapTip(t, _acadFormDeleteTitle)),
];

// Etiketler tr'dir (sahneler tr'de yazildi); en/ar'da dokunma sahneleri metinle bulunamazsa atlanir.
String _acadTimeAddSemester = 'Yeni dönem ekle';
String _acadTimeDeleteCourse = 'Dersi sil';
String _acadTimeAddCourseBtn = 'Dersi ekle';
String _acadFormAdd = 'Sınavı ekle';
String _acadFormPickDate = 'Tarih seç';
String _acadFormDeleteTitle = 'Sınavı sil';
String _dayShort(String tr) => tr;

List<Course> _courses(FakeBackend b) => [for (final c in _reg[b]?.courses ?? const <Map<String, dynamic>>[]) Course.fromJson(c)];

final _reg = Expando<FakeAcademic>();

FakeAcademic _fa(FakeBackend b) => _reg[b] = fakeAcademic(b);

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
  final lang = Platform.environment['P17_LANG'] ?? 'tr';
  final only = (Platform.environment['P17_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P17_MODES'] ?? 'light').split(',');
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
  });

  for (final v in variants) {
    for (final s in _scenes) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$lang';
      testWidgets('p17 $name', skip: skip != null, (tester) async {
        academicClock = () => s.now ?? _morning;
        ReminderService.platform = _Platform();
        ReminderService.store = MemoryReminderStore();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final b = FakeBackend();
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
        // Gecikmeli (iskelet) sahnelerde bekleyen zamanlayicilari bosalt.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 7));
        }
      });
    }
  }
}
