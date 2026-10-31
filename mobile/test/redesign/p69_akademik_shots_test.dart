@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/announcements_page.dart';
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

/// P69 Akademik Stitch v3 BIREBIR ekran goruntuleri (390 x referans yuksekligi, dpr 2).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_verify_acad\mobile icinde):
///   STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/acad/birebir_akademik' flutter test test/redesign/p69_akademik_shots_test.dart
/// Istege bagli: `P69_LANG=tr|en|ar`, `P69_ONLY=01,05`, `P69_MODES=light,dark,x13`.
const _dpr = 2.0;
final _lang = Platform.environment['P69_LANG'] ?? 'tr';

// Carsamba 2026-10-28 11:20 Istanbul (ders programi), Persembe 2026-11-05 09:00 (hub/sinavlar/takvim), 14 Ekim 10:00 (duyuru).
final _wed = DateTime.utc(2026, 10, 28, 8, 20);
final _nov = DateTime.utc(2026, 11, 5, 6, 0);
final _oct14 = DateTime.utc(2026, 10, 14, 7, 0);

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

final _reg = Expando<FakeAcademic>();
FakeAcademic _fa(FakeBackend b) => _reg[b] = fakeAcademic(b);

FakeAcademic _week(FakeBackend b) {
  final f = _fa(b);
  f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
  f.addCourse('Veri Tabanı Yönetimi', 3, '09:00', '10:45', room: 'A-102', code: 'BM-205');
  f.addCourse('Algoritma Analizi', 3, '11:00', '12:45', room: 'B-204', code: 'BM-201', instructor: 'Prof. Dr. M. Eren');
  f.addCourse('Nesne Yönelimli Programlama', 3, '13:30', '15:15', room: 'Laboratuvar 3', code: 'BM-203');
  f.addCourse('Ayrık Matematik', 3, '15:30', '17:15', room: 'Amfi 1', code: 'MAT-105');
  return f;
}

FakeAcademic _exams(FakeBackend b) {
  final f = _week(b);
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00');
  f.addExam('Algoritma Analizi Vize', '2026-11-21T14:00:00+03:00');
  f.exams.last['room'] = 'B-101';
  f.addExam('Ayrık Matematik Vize', '2026-11-24T09:30:00+03:00');
  f.exams.last['room'] = 'Amfi 2';
  return f;
}

FakeAcademic _cal(FakeBackend b) {
  final f = _exams(b);
  f.events = [
    {'id': 1, 'kind': 'VIZE', 'title': 'Ara sınavlar başlangıcı', 'startsAt': '2026-11-17T21:00:00Z'},
    {'id': 2, 'kind': 'VIZE', 'title': 'Ara sınavlar bitişi', 'startsAt': '2026-11-24T21:00:00Z'},
    {'id': 3, 'kind': 'DERS_KAYIT', 'title': 'Ders kayıt son günü', 'startsAt': '2026-11-29T21:00:00Z'},
    {'id': 4, 'kind': 'DERS_KAYIT', 'title': 'Ders ekleme/bırakma son günü', 'startsAt': '2026-12-14T21:00:00Z'},
  ];
  return f;
}

FakeAcademic _ann(FakeBackend b) {
  final f = _fa(b);
  f.pageSize = 20;
  const dept = 'Bilgisayar Mühendisliği';
  f.announcements.addAll([
    {'id': 500, 'title': 'Güz dönemi staj başvuruları', 'body': 'x', 'department': dept, 'pinned': true, 'publishAt': '2026-10-12T10:00:00+03:00', 'read': false, 'attachmentUrl': 'https://www.bingol.edu.tr/files/staj.pdf'},
    {'id': 501, 'title': 'Veri Yapıları laboratuvar grupları açıklandı', 'body': 'x', 'department': dept, 'publishAt': '2026-10-11T10:00:00+03:00', 'read': false},
    {'id': 502, 'title': 'Yapay Zeka ve Veri Bilimi semineri', 'body': 'x', 'department': dept, 'publishAt': '2026-10-07T10:00:00+03:00', 'read': true},
    {'id': 503, 'title': 'Bölüm danışmanlık saatleri güncellendi', 'body': 'x', 'department': dept, 'publishAt': '2026-09-30T10:00:00+03:00', 'read': true},
  ]);
  f.unread = 2;
  return f;
}

class _Scene {
  const _Scene(this.file, this.build, {this.setup, this.after, this.now, this.height = 884, this.settleMs = 900, this.perm = PermState.granted, this.store});
  final String file;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
  final DateTime? now;
  final double height;
  final int settleMs;
  final PermState perm;
  final ReminderSettings? store;
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

final _detailBody = 'Güz yarıyılı zorunlu ve isteğe bağlı staj başvuruları başlamıştır.\n'
    'Staj yapacak öğrencilerin staj kabul formunu eksiksiz doldurarak bölüm sekreterliğine elden veya e-posta yoluyla teslim etmeleri gerekmektedir.\n\n'
    'Başvuru sürecinde dikkat edilmesi gereken temel hususlar aşağıda belirtilmiştir:\n\n'
    '- Staj başlangıç tarihinden en az 15 gün önce başvuru evrakları teslim edilmelidir.\n'
    '- SGK giriş bildirgeleri staj başlangıcından 3 gün önce sistemden indirilebilir olacaktır.\n'
    '- Staj defterleri ve değerlendirme formu dönem başlangıcının ilk haftası teslim edilir.';

final _scenes = <_Scene>[
  _Scene('01_hub', (b) => AcademicHubPage(session: makeSession(b)), setup: (b) {
    _exams(b)
      ..addAnnouncements(2)
      ..addCourse('Algoritma Analizi', 4, '13:00', '14:45', room: 'B-204');
  }, now: _nov),
  _Scene('01b_hub_bos', (b) => AcademicHubPage(session: makeSession(b)), setup: (b) => _fa(b), now: _nov),
  _Scene('02_ders_programi', (b) => TimetablePage(session: makeSession(b)), setup: _week, now: _wed),
  _Scene('02b_ders_programi_bos', (b) => TimetablePage(session: makeSession(b)), setup: (b) => _fa(b), now: _wed),
  _Scene('03_sinavlar', (b) => ExamsPage(session: makeSession(b)), setup: _exams, now: _nov),
  _Scene('03b_sinavlar_bos', (b) => ExamsPage(session: makeSession(b)), setup: (b) => _fa(b), now: _nov),
  _Scene('03c_okul_programi', (b) => ExamsPage(session: makeSession(b), initialTab: 1), setup: (b) {
    _fa(b).official = [
      {'id': 1, 'title': 'Türk Dili I', 'type': 'VIZE', 'courseCode': 'TÜR101', 'department': 'Bilgisayar Mühendisliği', 'startsAt': '2026-11-20T14:00:00+03:00', 'room': 'A-101'},
      {'id': 2, 'title': 'Fizik I', 'type': 'FINAL', 'courseCode': 'FİZ101', 'startsAt': '2026-11-21T10:00:00+03:00', 'room': 'B-205', 'note': 'Kimlik zorunlu'},
    ];
  }, now: _nov),
  _Scene('04_sinav_ekle', (b) => ExamFormPage(session: makeSession(b), courses: _courses(b)), setup: _week, now: _nov, after: (t) async {
    await t.scrollUntilVisible(find.text('Kaydet'), 300, scrollable: find.byType(Scrollable).first);
    await _tapText(t, 'Kaydet');
    await t.drag(find.byType(Scrollable).first, const Offset(0, 800));
  }, height: 960),
  _Scene('05_akademik_takvim', (b) => AcademicCalendarPage(session: makeSession(b)), setup: _cal, now: _nov, height: 989, after: (t) => _tapText(t, '18')),
  _Scene('06_bolum_duyurulari', (b) => AnnouncementsPage(session: makeSession(b)), setup: _ann, now: _oct14),
  _Scene('06b_duyuru_bos', (b) => AnnouncementsPage(session: makeSession(b)), setup: (b) => _fa(b), now: _oct14),
  _Scene('07_hatirlatmalar', (b) => ReminderSettingsPage(session: makeSession(b)), setup: (b) => _fa(b), store: const ReminderSettings(classLeadMin: 15)),
  _Scene('08_hatirlatmalar_izin_kapali', (b) => ReminderSettingsPage(session: makeSession(b)), setup: (b) => _fa(b), perm: PermState.denied, store: const ReminderSettings(classLeadMin: 15)),
  _Scene('09_duyuru_detay', (b) => AnnouncementDetailPage(session: makeSession(b), id: 500), setup: (b) {
    _ann(b);
    b.handlers.insert(
        0,
        (req, p) => p == '/announcements/500'
            ? FakeResult.json({
                'id': 500,
                'title': 'Güz dönemi staj başvuruları',
                'body': _detailBody,
                'department': 'Bilgisayar Mühendisliği',
                'pinned': true,
                'publishAt': '2026-10-12T10:00:00+03:00',
                'attachmentUrl': 'https://www.bingol.edu.tr/files/staj.pdf',
                'read': true,
              })
            : null);
  }, now: _oct14),
];

List<Course> _courses(FakeBackend b) => [for (final c in _reg[b]?.courses ?? const <Map<String, dynamic>>[]) Course.fromJson(c)];

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
  final only = (Platform.environment['P69_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P69_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double, double)>[
    if (modes.contains('light')) ('', false, 1.0, 390),
    if (modes.contains('dark')) ('_koyu', true, 1.0, 390),
    if (modes.contains('x13')) ('_x1.3_320', false, 1.3, 320),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
    PermissionService.instance = SystemPermissionService();
  });

  for (final v in variants) {
    for (final s in _scenes) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$_lang';
      testWidgets('p69 $name', skip: skip != null, (tester) async {
        academicClock = () => s.now ?? _nov;
        ReminderService.platform = _Platform();
        ReminderService.store = MemoryReminderStore(s.store ?? const ReminderSettings());
        PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: s.perm});
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, s.height * _dpr);
        // Stitch cercevesi durum cubuksuz: ust guvenli alan 0 (olculer icerik ustunden).
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final b = FakeBackend();
        s.setup?.call(b);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: p00App(s.build(b), lang: _lang, dark: v.$2, scale: v.$3, scaffold: false)));
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
      });
    }
  }
}
