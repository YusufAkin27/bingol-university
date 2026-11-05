import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/alarm_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saf alarm hesabı: günün ilk sınavı, 60 dk önce, geçmiş atlanır, ders sabah kuralı, haftalık eşleme.
Exam _exam(int id, int y, int m, int d, int h, int min) => Exam(id: id, title: 'S$id', startsAt: wallToInstant(y, m, d, h, min));

CourseSession _s(int day, String start, String end) => CourseSession(dayOfWeek: day, start: start, end: end);

Course _c(int id, String name, List<CourseSession> s) => Course(id: id, name: name, sessions: s);

void main() {
  // Pazartesi 9 Kasım 2026 08:00 (Istanbul) = simdi
  final now = wallToInstant(2026, 11, 9, 8, 0);

  group('sinav alarmi', () {
    test('gunun ilk sinavi icin 60 dk once; ikinci sinav alarmsiz', () {
      // 16 Kasim 2026 Pazartesi: 10:00 ve 12:30
      final plans = planExamAlarms([_exam(2, 2026, 11, 16, 12, 30), _exam(1, 2026, 11, 16, 10, 0)], now);
      expect(plans, hasLength(1));
      final p = plans.single;
      expect(p.exam.id, 1);
      expect((p.hour, p.minute), (9, 0));
      expect(isoDate(p.alarmDay), '2026-11-16');
      expect(p.skipped.map((e) => e.id), [2]);
      expect(p.key, 'exam-1');
    });

    test('farkli gunler ayri alarm, alarm anina gore sirali', () {
      final plans = planExamAlarms([_exam(2, 2026, 11, 18, 14, 0), _exam(1, 2026, 11, 16, 10, 30)], now);
      expect(plans.map((p) => p.exam.id), [1, 2]);
      expect(plans.map((p) => (p.hour, p.minute)), [(9, 30), (13, 0)]);
    });

    test('gecmis sinav icin alarm yok; alarm ani gecmisse o gun atlanir (ikinci sinava dusmez)', () {
      // Sinav 08:30 bugun -> alarm 07:30 (gecmis); ayni gun 14:00 sinavi var: alarm yine YOK.
      final plans = planExamAlarms([_exam(1, 2026, 11, 9, 8, 30), _exam(2, 2026, 11, 9, 14, 0), _exam(3, 2026, 11, 7, 10, 0)], now);
      expect(plans, isEmpty);
    });

    test('sinir: alarm ani tam simdi ise kurulmaz, 1 dk sonra ise kurulur', () {
      expect(planExamAlarms([_exam(1, 2026, 11, 9, 9, 0)], now), isEmpty); // alarm 08:00 == simdi
      expect(planExamAlarms([_exam(1, 2026, 11, 9, 9, 1)], now), hasLength(1)); // alarm 08:01
    });

    test('gun siniri: 00:30 sinavi icin alarm bir onceki gun 23:30', () {
      final p = planExamAlarms([_exam(1, 2026, 11, 17, 0, 30)], now).single;
      expect((p.hour, p.minute), (23, 30));
      expect(isoDate(p.alarmDay), '2026-11-16');
      expect(isoDate(p.examDay), '2026-11-17');
    });

    test('ayni anda iki sinav: kimligi kucuk olan secilir', () {
      final p = planExamAlarms([_exam(7, 2026, 11, 16, 10, 0), _exam(3, 2026, 11, 16, 10, 0)], now).single;
      expect(p.exam.id, 3);
      expect(p.skipped.single.id, 7);
    });

    test('bos liste', () => expect(planExamAlarms(const [], now), isEmpty));

    test('canSetInClockNow: yalniz 24 saat icindeki tek seferlik alarm tarihi dogru tutar', () {
      final soon = planExamAlarms([_exam(1, 2026, 11, 10, 9, 0)], now).single; // alarm 10 Kasim 08:00 = 24 saat
      expect(soon.canSetInClockNow(now), isFalse); // tam 24 saat: sinir disi (bir sonraki 08:00 bugundur)
      final ok = planExamAlarms([_exam(1, 2026, 11, 10, 8, 59)], now).single; // alarm 07:59, 23h59
      expect(ok.canSetInClockNow(now), isTrue);
      final far = planExamAlarms([_exam(1, 2026, 11, 16, 10, 0)], now).single;
      expect(far.canSetInClockNow(now), isFalse);
    });

    test('hatirlatma ani: alarm gununden onceki aksam 20:00; aksam alarminda ayni gun 08:00; alarm 24 saat icinde', () {
      final a = planExamAlarms([_exam(1, 2026, 11, 16, 10, 0)], now).single; // alarm Pzt 09:00
      expect(istanbulWall(a.nudgeAt), DateTime.utc(2026, 11, 15, 20, 0));
      expect(a.alarmAt.difference(a.nudgeAt) < kClockOneShotHorizon, isTrue);
      final e = planExamAlarms([_exam(2, 2026, 11, 16, 21, 0)], now).single; // alarm 20:00
      expect(istanbulWall(e.nudgeAt), DateTime.utc(2026, 11, 16, 8, 0));
      expect(e.alarmAt.difference(e.nudgeAt) < kClockOneShotHorizon, isTrue);
      final n = planExamAlarms([_exam(3, 2026, 11, 17, 0, 30)], now).single; // alarm Pzt 23:30 -> o gun 08:00
      expect(istanbulWall(n.nudgeAt), DateTime.utc(2026, 11, 16, 8, 0));
    });
  });

  group('ders alarmi', () {
    test('her gunun en erken dersi, yalniz sabahsa, 60 dk once', () {
      final days = planClassAlarmDays([
        _c(1, 'Algoritma', [_s(1, '10:00', '11:00'), _s(3, '08:15', '09:00')]),
        _c(2, 'Fizik', [_s(1, '08:15', '09:00'), _s(2, '13:00', '14:00')]),
      ]);
      expect(days.map((d) => d.classWeekday), [1, 3]); // Sali ogleden sonra -> yok
      final mon = days.first;
      expect(mon.course.name, 'Fizik'); // Pazartesi'nin en erkeni 08:15
      expect((mon.hour, mon.minute), (7, 15));
      expect(mon.alarmWeekday, 1);
    });

    test('sabah siniri: 11:59 dahil, 12:00 haric', () {
      final d = planClassAlarmDays([
        _c(1, 'A', [_s(1, '11:59', '12:30'), _s(2, '12:00', '13:00')]),
      ]);
      expect(d.map((x) => x.classWeekday), [1]);
      expect((d.single.hour, d.single.minute), (10, 59));
    });

    test('ayni saatteki gunler tek tekrarli alarmda birlesir', () {
      final plans = groupClassAlarms(planClassAlarmDays([
        _c(1, 'A', [_s(1, '08:15', '09:00'), _s(3, '08:15', '09:00'), _s(5, '09:15', '10:00')]),
      ]));
      expect(plans, hasLength(2));
      expect((plans[0].hour, plans[0].minute), (7, 15));
      expect(plans[0].weekdays, [1, 3]);
      expect((plans[1].hour, plans[1].minute), (8, 15));
      expect(plans[1].weekdays, [5]);
      expect(plans[0].key, 'class-0715');
    });

    test('gece yarisina yakin ders: alarm bir onceki gune kayar (Pzt 00:30 -> Paz 23:30)', () {
      final d = planClassAlarmDays([
        _c(1, 'Gece', [_s(1, '00:30', '02:00')]),
      ]).single;
      expect((d.hour, d.minute), (23, 30));
      expect(d.alarmWeekday, 7);
      expect(d.classWeekday, 1);
    });

    test('hafta gunu eslemesi: Pzt=Calendar.MONDAY(2) ... Paz=Calendar.SUNDAY(1)', () {
      expect([for (var i = 1; i <= 7; i++) calendarWeekday(i)], [2, 3, 4, 5, 6, 7, 1]);
    });

    test('bos liste ve yalniz ogleden sonra dersleri: alarm yok', () {
      expect(planClassAlarmDays(const []), isEmpty);
      expect(planClassAlarmDays([_c(1, 'A', [_s(4, '13:00', '14:00')])]), isEmpty);
      expect(groupClassAlarms(const []), isEmpty);
    });

    test('donem bitmisse alarm yok; surerken var', () {
      final sem = Semester(id: 1, name: 'Guz', startDate: DateTime.utc(2026, 9, 14), endDate: DateTime.utc(2027, 1, 15));
      final courses = [_c(1, 'A', [_s(1, '08:15', '09:00')])];
      expect(planClassAlarmDays(courses, semester: sem, now: now), hasLength(1));
      expect(planClassAlarmDays(courses, semester: sem, now: wallToInstant(2027, 2, 1, 10, 0)), isEmpty);
    });
  });
}
