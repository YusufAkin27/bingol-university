import 'dart:typed_data';

import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/courses/course_widgets.dart';
import 'package:bu_kampus/features/courses/my_course_detail_page.dart';
import 'package:bu_kampus/features/courses/my_courses_api.dart';
import 'package:bu_kampus/features/courses/my_courses_models.dart';
import 'package:bu_kampus/features/courses/my_courses_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _course(int id, String name, {int present = 8, int absent = 1, bool atRisk = false, bool over = false, Object? limit = const {'type': 'COUNT', 'value': 4}}) => {
      'courseId': id,
      'courseName': name,
      'code': 'MAT$id',
      'term': '2026-GUZ',
      'academicianName': 'Dr. Ayşe Demir',
      'presentCount': present,
      'absentCount': absent,
      'sessionCount': present + absent,
      'limit': limit,
      'atRisk': atRisk,
      'overLimit': over,
    };

Map<String, dynamic> _notice(int id, String type, {String? title, String? note, String? eventAt, List<Map<String, dynamic>> files = const [], int? courseId, String? courseName}) => {
      'id': id,
      'type': type,
      'title': title,
      'note': note,
      'eventAt': eventAt,
      'createdAt': '2026-11-10T08:00:00Z',
      'files': files,
      if (courseId != null) 'courseId': courseId,
      if (courseName != null) 'courseName': courseName,
    };

double _y(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;

void main() {
  setUpAll(loadTestFonts);

  Future<FakeBackend> openList(WidgetTester tester, FakeBackend be) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(MyCoursesPage(session: makeSession(be)), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    return be;
  }

  group('Derslerim listesi', () {
    testWidgets('dersler, devam sayıları ve sınır gösterilir', (tester) async {
      final be = FakeBackend()
        ..on('/my-courses', [_course(1, 'Matematik 101'), _course(2, 'Fizik 102', present: 5, absent: 2)])
        ..on('/my-courses/upcoming', []);
      await openList(tester, be);
      expect(find.text('Matematik 101'), findsOneWidget);
      expect(find.text('Fizik 102'), findsOneWidget);
      expect(find.text('Katıldığın: 8 · Devamsız: 1'), findsOneWidget);
      expect(find.text('Devamsızlık sınırı: 4 ders'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('course-status')), findsNothing);
      expect(find.text('Yaklaşanlar'), findsNothing);
    });

    testWidgets('ders yoksa boş durum', (tester) async {
      final be = FakeBackend()
        ..on('/my-courses', [])
        ..on('/my-courses/upcoming', []);
      await openList(tester, be);
      expect(find.byKey(const ValueKey('my-courses-empty')), findsOneWidget);
      expect(find.text('Henüz bir derse kayıtlı değilsin'), findsOneWidget);
    });

    testWidgets('hata: açıklayıcı metin ve yeniden dene, sonra liste gelir', (tester) async {
      final be = FakeBackend()..fail('/my-courses', status: 500)..on('/my-courses/upcoming', []);
      await openList(tester, be);
      expect(find.byKey(const ValueKey('my-courses-empty')), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      be.on('/my-courses', [_course(1, 'Matematik 101')]);
      final retry = find.text('Yeniden dene');
      await tester.tap(retry.first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Matematik 101'), findsOneWidget);
    });

    testWidgets('sınıra yakın ve sınır aşıldı: metinle vurgulanır, yüzdeli sınır', (tester) async {
      final be = FakeBackend()
        ..on('/my-courses', [
          _course(1, 'Matematik 101', absent: 3, atRisk: true),
          _course(2, 'Fizik 102', absent: 5, over: true, limit: {'type': 'PERCENT', 'value': 30}),
        ])
        ..on('/my-courses/upcoming', []);
      await openList(tester, be);
      expect(find.byKey(const ValueKey('course-status')), findsNWidgets(2));
      expect(find.text('Devamsızlık sınırına yaklaştın'), findsOneWidget);
      expect(find.text('Devamsızlık sınırını aştın'), findsOneWidget);
      expect(find.text('Devamsızlık sınırı: %30'), findsOneWidget);
      final over = tester.widget<Text>(find.text('Devamsızlık sınırını aştın'));
      expect(over.style!.color, BuTokens.light.danger);
      final risk = tester.widget<Text>(find.text('Devamsızlık sınırına yaklaştın'));
      expect(risk.style!.color, BuTokens.light.warn);
    });

    testWidgets('yaklaşanlar en yakın tarihe göre sıralanır; iptal, derslik değişikliği ve bilinmeyen tür çökmez', (tester) async {
      final be = FakeBackend()
        ..on('/my-courses', [_course(1, 'Matematik 101')])
        ..on('/my-courses/upcoming', [
          _notice(1, 'ASSIGNMENT', title: 'Ödev 3', eventAt: '2026-12-05T10:00:00Z', courseId: 1, courseName: 'Matematik 101'),
          _notice(2, 'EXAM', title: 'Vize', eventAt: '2026-11-20T10:00:00Z', courseId: 1, courseName: 'Matematik 101'),
          _notice(3, 'LESSON_CANCELLED', eventAt: '2026-11-25T10:00:00Z', courseId: 1, courseName: 'Matematik 101'),
          _notice(4, 'ROOM_CHANGED', title: 'B-204', eventAt: '2026-11-26T10:00:00Z', courseId: 1, courseName: 'Matematik 101'),
          _notice(5, 'SOMETHING_NEW', title: 'Yeni tür', eventAt: '2026-11-27T10:00:00Z', courseId: 1, courseName: 'Matematik 101'),
        ]);
      await openList(tester, be);
      expect(find.text('Yaklaşanlar'), findsOneWidget);
      expect(_y(tester, 'upcoming-2'), lessThan(_y(tester, 'upcoming-3')));
      expect(_y(tester, 'upcoming-3'), lessThan(_y(tester, 'upcoming-4')));
      expect(_y(tester, 'upcoming-4'), lessThan(_y(tester, 'upcoming-5')));
      expect(_y(tester, 'upcoming-5'), lessThan(_y(tester, 'upcoming-1')));
      expect(find.text('Ders iptal'), findsOneWidget);
      expect(find.text('Derslik değişti: B-204'), findsOneWidget);
      expect(find.text('Yeni tür'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ders ayrıntısı ve ekler', () {
    FakeBackend backend(List<Map<String, dynamic>> notices) => FakeBackend()
      ..on('/my-courses', [_course(3, 'Matematik 101', atRisk: true)])
      ..on('/my-courses/3/notices*', notices);

    Future<void> openDetail(WidgetTester tester, FakeBackend be) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MyCourseDetailPage(session: makeSession(be), courseId: 3), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
    }

    const file = {'id': 5, 'name': 'odev3.pdf', 'contentType': 'application/pdf', 'sizeBytes': 1536000};

    testWidgets('ders özeti ve ekli duyurular gösterilir; ek satırında ad ve okunur boyut', (tester) async {
      final be = backend([
        _notice(11, 'ASSIGNMENT', title: 'Ödev 3', note: 'Cuma teslim.', eventAt: '2026-12-05T10:00:00Z', files: [file]),
        _notice(10, 'EXAM', title: 'Vize', eventAt: '2026-11-20T10:00:00Z'),
      ]);
      await openDetail(tester, be);
      expect(be.count('GET /my-courses/3/notices'), 1);
      expect(find.text('Matematik 101'), findsOneWidget);
      expect(find.text('Devamsızlık sınırına yaklaştın'), findsOneWidget);
      expect(find.text('Ödev 3'), findsOneWidget);
      expect(find.textContaining('Son teslim'), findsOneWidget);
      expect(find.textContaining('Sınav zamanı'), findsOneWidget);
      expect(find.byKey(const ValueKey('notice-file-5')), findsOneWidget);
      expect(find.text('odev3.pdf'), findsOneWidget);
      expect(find.text('1.5 MB'), findsOneWidget);
    });

    testWidgets('MATERIAL tarihsiz gösterilir', (tester) async {
      final be = backend([_notice(12, 'MATERIAL', title: 'Hafta 4 notları', note: 'Okuyun.')]);
      await openDetail(tester, be);
      expect(find.text('Hafta 4 notları'), findsOneWidget);
      expect(find.text('Ders materyali'), findsOneWidget);
      expect(find.textContaining('Son teslim'), findsNothing);
      expect(find.textContaining('Sınav zamanı'), findsNothing);
      expect(find.textContaining('Ders zamanı'), findsNothing);
    });

    testWidgets('ek satırına dokunma: doğru yoldan indirir ve paylaşım sayfasına bellekten verir', (tester) async {
      final be = backend([_notice(11, 'MATERIAL', title: 'Notlar', files: [file])])
        ..onBytes('/my-courses/3/notices/11/files/5', [37, 80, 68, 70]);
      ShareParams? shared;
      debugNoticeFileShare = (p) async => shared = p;
      addTearDown(() => debugNoticeFileShare = null);
      await openDetail(tester, be);
      await tester.tap(find.byKey(const ValueKey('notice-file-5')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.count('GET /my-courses/3/notices/11/files/5'), 1);
      expect(shared, isNotNull);
      expect(shared!.files!.single.name, 'odev3.pdf');
      expect(shared!.files!.single.mimeType, 'application/pdf');
      expect(shared!.fileNameOverrides, ['odev3.pdf']);
      expect(await shared!.files!.single.readAsBytes(), Uint8List.fromList([37, 80, 68, 70]));
    });

    testWidgets('indirme hatası: bildirim gösterilir, paylaşım açılmaz', (tester) async {
      final be = backend([_notice(11, 'MATERIAL', title: 'Notlar', files: [file])])
        ..fail('/my-courses/3/notices/11/files/5', status: 404, code: 'NOT_FOUND');
      var opened = false;
      debugNoticeFileShare = (p) async => opened = true;
      addTearDown(() => debugNoticeFileShare = null);
      await openDetail(tester, be);
      await tester.tap(find.byKey(const ValueKey('notice-file-5')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(opened, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
    });

    testWidgets('duyuru listesi hatası: yeniden dene', (tester) async {
      final be = FakeBackend()
        ..on('/my-courses', [_course(3, 'Matematik 101')])
        ..fail('/my-courses/3/notices*', status: 500);
      await openDetail(tester, be);
      expect(find.text('Ders materyali'), findsNothing);
      be.on('/my-courses/3/notices*', [_notice(12, 'MATERIAL', title: 'Notlar')]);
      final retry = find.text('Yeniden dene');
      await tester.tap(retry.first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Notlar'), findsOneWidget);
    });

    test('dosya adı güvenli hale getirilir; boyut okunur', () {
      expect(safeFileName('../a/b\\c.pdf'), '.._a_b_c.pdf');
      expect(safeFileName('  '), 'ek');
      expect(humanSize(512), '512 B');
      expect(humanSize(2048), '2 KB');
      expect(humanSize(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('bildirim yönlendirme', () {
    test('ACADEMIC_COURSE ders ayrıntısına gider', () {
      expect(resolvePushTarget({'targetType': 'ACADEMIC_COURSE', 'targetId': '5'}), const PushTarget(PushDest.course, id: 5));
      expect(resolvePushTarget({'targetType': 'ACADEMIC_COURSE', 'courseId': '6'}), const PushTarget(PushDest.course, id: 6));
      expect(resolvePushTarget({'targetType': 'ACADEMIC_COURSE'}).dest, PushDest.notifications);
    });

    test('mevcut hedefler değişmez', () {
      expect(resolvePushTarget({'targetType': 'COURSE', 'targetId': '5'}).dest, PushDest.timetable);
      expect(resolvePushTarget({'targetType': 'EXAM', 'examId': '9'}), const PushTarget(PushDest.exams, id: 9));
    });
  });

  group('kontrast (WCAG AA, açık ve koyu tema)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + .05) / (lo + .05);
    }

    for (final tokens in [BuTokens.light, BuTokens.dark]) {
      test('Derslerim metinleri zemin üstünde >= 4.5: bg=${tokens.bg}', () {
        for (final c in [tokens.ink, tokens.mut, tokens.warn, tokens.danger]) {
          expect(contrast(c, tokens.bg), greaterThanOrEqualTo(4.5), reason: '$c');
        }
      });
    }
  });
}
