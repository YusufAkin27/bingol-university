import 'package:bu_kampus/core/notify/local_reminders.dart';
import 'package:bu_kampus/core/platform/device_alarm.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/alarm_planner.dart';
import 'package:bu_kampus/features/academic/alarm_service.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Exam _exam(int id, int d, int h, int m, {int mo = 11}) => Exam(id: id, title: 'Sinav $id', startsAt: wallToInstant(2026, mo, d, h, m), room: 'B-1');

CourseSession _s(int day, String start) => CourseSession(dayOfWeek: day, start: start, end: '23:00');

void main() {
  final l = lookupAppLocalizations(const Locale('tr'));
  var now = wallToInstant(2026, 11, 15, 12, 0); // Pazar 12:00
  late FakeDeviceAlarmService alarms;
  late MemoryAlarmStateStore store;
  late RemBackend rem;
  late AlarmService svc;

  AlarmService make({bool clock = true}) {
    alarms = FakeDeviceAlarmService(clockApp: clock);
    store = MemoryAlarmStateStore();
    rem = RemBackend();
    return svc = AlarmService(
      alarms: alarms,
      store: store,
      reminders: LocalReminders(rem, clock: () => now),
      gap: Duration.zero,
      clock: () => now,
    );
  }

  setUp(() {
    now = wallToInstant(2026, 11, 15, 12, 0);
    make();
  });

  group('sinav (Android Saat uygulamasi)', () {
    test('24 saat icindeki alarm dogrudan kurulur; tek seferlik, 60 dk once, yalniz ilk sinav', () async {
      // Pazartesi 16 Kasim 10:00 ve 12:30 -> alarm 09:00 (21 saat sonra)
      final plans = planExamAlarms([_exam(2, 16, 12, 30), _exam(1, 16, 10, 0)], now);
      final out = await svc.applyExams(plans, l);
      expect(out.set, hasLength(1));
      expect(out.deferred, isEmpty);
      expect(alarms.requests, hasLength(1));
      final spec = alarms.requests.single;
      expect((spec.hour, spec.minute), (9, 0));
      expect(spec.weekdays, isEmpty); // tek seferlik
      expect(spec.repeats, isFalse);
      expect(spec.label, contains('10:00'));
      expect(spec.label, contains('Sinav 1'));
      expect((await svc.state()).pending, isEmpty);
    });

    test('ileri tarihli alarm ERTELENIR: kayit + onceki aksam 20:00 hatirlatma; Saat cagrilmaz', () async {
      final plans = planExamAlarms([_exam(1, 20, 10, 0)], now); // 20 Kasim Cuma, alarm 09:00
      final out = await svc.applyExams(plans, l);
      expect(out.set, isEmpty);
      expect(out.deferred, hasLength(1));
      expect(alarms.requests, isEmpty);
      final st = await svc.state();
      expect(st.pending.single.key, 'exam-1');
      final nudges = rem.groups['examalarm']!;
      expect(nudges, hasLength(1));
      expect(istanbulWall(nudges.single.at), DateTime.utc(2026, 11, 19, 20, 0));
      expect(nudges.single.payload['targetType'], 'EXAM');
      // henuz 24 saat icinde degil
      expect(await svc.dueNow(), isEmpty);
    });

    test('hatirlatma gunu gelince due; setDue alarmi kurar ve kaydi/hatirlatmayi siler', () async {
      await svc.applyExams(planExamAlarms([_exam(1, 20, 10, 0)], now), l);
      now = wallToInstant(2026, 11, 19, 20, 5); // hatirlatma sonrasi, alarma 12 saat var
      final due = await svc.dueNow();
      expect(due, hasLength(1));
      final r = await svc.setDue(l);
      expect((r.set, r.failed), (1, 0));
      expect((alarms.requests.single.hour, alarms.requests.single.minute), (9, 0));
      expect((await svc.state()).pending, isEmpty);
      expect(rem.groups['examalarm'], isEmpty);
    });

    test('alarm ani gecen ertelenmis kayit temizlenir', () async {
      await svc.applyExams(planExamAlarms([_exam(1, 20, 10, 0)], now), l);
      now = wallToInstant(2026, 11, 20, 9, 30); // alarm gecmis
      expect(await svc.dueNow(), isEmpty);
      await svc.setDue(l);
      expect((await svc.state()).pending, isEmpty);
    });

    test('karisik plan: yakin olan kurulur, uzak olan ertelenir', () async {
      final plans = planExamAlarms([_exam(1, 16, 10, 0), _exam(2, 25, 10, 0)], now);
      final out = await svc.applyExams(plans, l);
      expect(out.set.map((p) => p.exam.id), [1]);
      expect(out.deferred.map((p) => p.exam.id), [2]);
      expect((await svc.state()).pending.map((p) => p.key), ['exam-2']);
    });

    test('Saat uygulamasi alarmi reddederse failed olur ve ertelenmez', () async {
      alarms = FakeDeviceAlarmService(failKeys: {'exam-1'});
      svc = AlarmService(alarms: alarms, store: store, reminders: LocalReminders(rem, clock: () => now), gap: Duration.zero, clock: () => now);
      final out = await svc.applyExams(planExamAlarms([_exam(1, 16, 10, 0)], now), l);
      expect(out.failed.map((p) => p.exam.id), [1]);
      expect(out.set, isEmpty);
      expect((await svc.state()).pending, isEmpty);
    });

    test('hesap degisimi: ertelenmis kayit ve hatirlatmalar silinir', () async {
      AlarmService.instance = svc;
      await svc.applyExams(planExamAlarms([_exam(1, 20, 10, 0)], now), l);
      await AlarmService.clearUserData();
      expect((await svc.state()).pending, isEmpty);
      expect(rem.groups.containsKey('examalarm'), isFalse);
      expect(alarms.cancelled, 1);
      AlarmService.instance = AlarmService();
    });
  });

  group('sinav (iOS bildirim yedegi)', () {
    test('hepsi tarihli bildirim olarak kurulur (ertelenmez), tarih ve baslik bildirim metni', () async {
      make(clock: false);
      final plans = planExamAlarms([_exam(1, 20, 10, 0), _exam(2, 16, 10, 0)], now);
      final out = await svc.applyExams(plans, l);
      expect(out.set, hasLength(2));
      expect(out.deferred, isEmpty);
      expect(alarms.requests.map((s) => s.key), ['exam-2', 'exam-1']);
      final s = alarms.requests.first;
      expect(isoDate(s.date!), '2026-11-16');
      expect(s.title, 'Alarm: Sınav 1 saat sonra');
      expect(s.body, contains('B-1'));
      expect(s.payload['targetType'], 'EXAM');
      expect(await svc.dueNow(), isEmpty);
    });
  });

  group('ders', () {
    test('haftalik tekrarli alarm; ayni saatteki gunler birlesir; Calendar gun degerleri kanalda', () async {
      final courses = [
        Course(id: 1, name: 'A', sessions: [_s(1, '08:15'), _s(3, '08:15'), _s(5, '09:15'), _s(2, '14:00')]),
      ];
      final plans = groupClassAlarms(planClassAlarmDays(courses));
      final out = await svc.applyClasses(plans, l);
      expect(out.set, hasLength(2));
      expect(alarms.requests.map((s) => '${s.hour}:${s.minute}:${s.weekdays}'), ['7:15:[1, 3]', '8:15:[5]']);
      expect(alarms.requests.first.repeats, isTrue);
      expect(alarms.requests.first.label, contains('08:15'));
    });

    test('ayni plan ikinci kez: onceki kurulum bulunur (Android cift alarm uyarisi); farkli plan bulunmaz; iOS bulunmaz', () async {
      final plans = groupClassAlarms(planClassAlarmDays([Course(id: 1, name: 'A', sessions: [_s(1, '08:15')])]));
      expect(await svc.previousClassSetup(plans), isNull);
      await svc.applyClasses(plans, l);
      expect(await svc.previousClassSetup(plans), isNotNull);
      final other = groupClassAlarms(planClassAlarmDays([Course(id: 1, name: 'A', sessions: [_s(2, '08:15')])]));
      expect(await svc.previousClassSetup(other), isNull);
      make(clock: false);
      await svc.applyClasses(plans, l);
      expect(await svc.previousClassSetup(plans), isNull);
    });

    test('basarisiz alarm failed listesine girer, imza kaydedilmez', () async {
      alarms = FakeDeviceAlarmService(failKeys: {'class-0715'});
      svc = AlarmService(alarms: alarms, store: store, reminders: LocalReminders(rem), gap: Duration.zero, clock: () => now);
      final plans = groupClassAlarms(planClassAlarmDays([Course(id: 1, name: 'A', sessions: [_s(1, '08:15')])]));
      final out = await svc.applyClasses(plans, l);
      expect(out.failed, hasLength(1));
      expect(await svc.previousClassSetup(plans), isNull);
    });
  });
}
