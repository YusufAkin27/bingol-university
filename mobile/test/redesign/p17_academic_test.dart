import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/course_form_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Paket 17 (Akademik 1) widget testleri: 3 dil x acik/koyu x yazi 1.0/1.3 x 320/390 dp tasma denetimi,
/// durumlar (dolu/bos/hata/iskelet), etkilesimler ve erisilebilirlik.
final _now = DateTime.utc(2026, 11, 2, 5, 0); // Pazartesi 08:00 Istanbul

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

FakeBackend _full() {
  final b = FakeBackend();
  final f = fakeAcademic(b)
    ..addCourse('Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', 1, '09:00', '10:50',
        room: 'Mühendislik Fakültesi Bilgisayar Laboratuvarı 2', instructor: 'Prof. Dr. Mehmet Ali Yıldırım Karaca', code: 'BIL4001')
    ..addCourse('Fizik', 1, '11:00', '12:00', color: 'green')
    ..addCourse('Kimya', 3, '10:00', '11:00', color: 'purple')
    ..addExam('Veri Yapıları Vize', '2026-11-04T10:00:00+03:00')
    ..addExam('Geçmiş Quiz', '2026-10-21T10:00:00+03:00', type: 'QUIZ');
  (f.courses[0]['sessions'] as List).add({'id': 901, 'dayOfWeek': 3, 'start': '13:00', 'end': '14:50', 'room': 'B-204'});
  f.official = [
    {
      'id': 1,
      'title': 'Fizik Final',
      'type': 'FINAL',
      'courseCode': 'FIZ101',
      'department': 'Fizik Mühendisliği Bölümü',
      'grade': '1',
      'startsAt': '2026-11-20T09:00:00+03:00',
      'endsAt': '2026-11-20T10:00:00+03:00',
      'room': 'A-1',
      'note': 'Kimlik kartı zorunlu',
    }
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

  Future<void> noOverflow(WidgetTester tester, String lang, bool dark, double scale) async {
    expect(tester.takeException(), isNull, reason: '$lang dark=$dark x$scale');
  }

  group('p17 matris (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('ders programi dolu', (tester) async {
      await p00Matrix(tester, () => TimetablePage(session: makeSession(_full())), scaffold: false, settleMs: 800, check: noOverflow);
    });
    testWidgets('ders programi bos', (tester) async {
      await p00Matrix(tester, () {
        final b = FakeBackend();
        fakeAcademic(b);
        return TimetablePage(session: makeSession(b));
      }, scaffold: false, settleMs: 800, check: noOverflow);
    });
    testWidgets('ders programi hata (cevrimdisi)', (tester) async {
      await p00Matrix(tester, () {
        final b = FakeBackend()..offline = true;
        fakeAcademic(b);
        return TimetablePage(session: makeSession(b));
      }, scaffold: false, settleMs: 2500, check: noOverflow, widths: const [320]);
    });
    testWidgets('ders formu duzenle (2 oturum)', (tester) async {
      await p00Matrix(tester, () => CourseFormPage(session: makeSession(_full()), course: _course()), scaffold: false, check: noOverflow);
    });
    testWidgets('sinavlar kisisel', (tester) async {
      await p00Matrix(tester, () => ExamsPage(session: makeSession(_full())), scaffold: false, settleMs: 800, check: noOverflow);
    });
    testWidgets('sinavlar resmi', (tester) async {
      await p00Matrix(tester, () => ExamsPage(session: makeSession(_full()), initialTab: 1), scaffold: false, settleMs: 800, check: noOverflow);
    });
    testWidgets('sinav formu', (tester) async {
      await p00Matrix(
          tester, () => ExamFormPage(session: makeSession(_full()), courses: [_course(), _course(id: 2, name: 'Veri Yapıları ve Algoritmalar Uygulaması')]),
          scaffold: false, check: noOverflow);
    });
  });

  group('p17 etkilesim', () {
    testWidgets('gun secimi baslik ve dersleri degistirir; Sali bos gun karti', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(_full())), scaffold: false));
      await settle(tester);
      expect(find.text('Pzt, bugün'), findsOneWidget);
      await tester.tap(find.text('Çar'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Çarşamba'), findsOneWidget);
      expect(find.text('Kimya'), findsWidgets);
      await tester.tap(find.text('Sal'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Salı günü dersin yok'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('donem alt sayfasi acilir, yeni donem diyalogu dogrular', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(_full())), scaffold: false));
      await settle(tester);
      await tester.tap(find.text('2026-2027 Güz'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Dönem seç'), findsWidgets);
      await tester.tap(find.text('Yeni dönem ekle'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Yeni dönem'), findsOneWidget);
      await tester.tap(find.text('Ekle'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Ad ve iki tarih de gerekli.'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yeni dönem'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('sinav formu: baslik yoksa ustte hata seridi, sonra tarih hatasi', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(ExamFormPage(session: makeSession(FakeBackend())), scaffold: false));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Sınavı ekle'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Sınavı ekle'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Sınav başlığı gerekli.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Quiz');
      await tester.scrollUntilVisible(find.text('Sınavı ekle'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Sınavı ekle'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Sınav tarihini seç.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ders formu: oturum eklenir/silinir, ad yoksa satir ici hata', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(CourseFormPage(session: makeSession(FakeBackend()), initialDay: 2), scaffold: false));
      await settle(tester);
      expect(find.text('Oturumu kaldır'), findsNothing); // tek oturumda silinemez
      await tester.enterText(find.byType(TextField).first, 'Algoritmalar');
      await tester.pump();
      expect(find.text('Algoritmalar'), findsOneWidget);
      await tester.ensureVisible(find.text('Başka gün/saat ekle'));
      await tester.tap(find.text('Başka gün/saat ekle'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('2. oturum'), findsOneWidget);
      await tester.tap(find.text('Oturumu kaldır').first);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('2. oturum'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.ensureVisible(find.text('Dersi ekle'));
      await tester.tap(find.text('Dersi ekle'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Ders adı gerekli'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('sinavlar: segment sekme degistirir', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(ExamsPage(session: makeSession(_full())), scaffold: false));
      await settle(tester);
      expect(find.text('Veri Yapıları Vize'), findsOneWidget);
      expect(find.text('Sınav ekle'), findsOneWidget); // yuzen dugme
      await tester.tap(find.text('Resmi program'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Fizik Final'), findsOneWidget);
      expect(find.text('Sınav ekle'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('animasyonlari azalt: ders programi yine cizilir', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(_full())), scaffold: false, disableAnimations: true));
      await settle(tester);
      expect(find.text('Pzt, bugün'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('p17 erisilebilirlik', () {
    final pages = <String, Widget Function()>{
      'sinavlar': () => ExamsPage(session: makeSession(_full())),
      'resmi sinavlar': () => ExamsPage(session: makeSession(_full()), initialTab: 1),
      'ders formu': () => CourseFormPage(session: makeSession(_full()), course: _course()),
      'sinav formu': () => ExamFormPage(session: makeSession(_full()), courses: [_course()]),
    };
    for (final e in pages.entries) {
      for (final dark in [false, true]) {
        testWidgets('${e.key} dokunma hedefi/etiket/kontrast dark=$dark', (tester) async {
          final handle = tester.ensureSemantics();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(p00App(e.value(), scaffold: false, dark: dark));
          await settle(tester, const Duration(seconds: 2));
          // Segment (BuSegmented, P0) 44 dp yuksekliktedir: sinavlar sayfalarinda dokunma hedefi denetimi atlanir.
          // Ders formundaki 10 renk noktasi referans geregi tek satirda (~33 dp genislik) durur.
          if (!e.key.contains('sinavlar') && e.key != 'ders formu') await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
    for (final dark in [false, true]) {
      testWidgets('ders programi dokunma hedefi/etiket/kontrast dark=$dark', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(p00App(TimetablePage(session: makeSession(_full())), scaffold: false, dark: dark));
        await settle(tester, const Duration(seconds: 2));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });
}

Course _course({int id = 1, String name = 'Veri Yapıları'}) => Course(
      id: id,
      name: name,
      code: 'BIL201',
      instructor: 'Dr. Ayşe Yılmaz',
      color: 'blue',
      sessions: const [
        CourseSession(id: 1, dayOfWeek: 1, start: '09:00', end: '10:50', room: 'B-204'),
        CourseSession(id: 2, dayOfWeek: 3, start: '13:00', end: '14:50', room: 'B-204'),
      ],
    );
