import 'package:bu_kampus/core/platform/device_alarm.dart';
import 'package:bu_kampus/core/platform/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kanal sozlesmesi: Dart -> yerel kanal cagrilari (bu_kampus/alarm, bu_kampus/calendar) sahte isleyiciyle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mock(String channel, Future<Object?> Function(MethodCall) h) =>
      messenger.setMockMethodCallHandler(MethodChannel(channel), (c) async {
        calls.add(c);
        return h(c);
      });

  setUp(calls.clear);
  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/alarm'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/calendar'), null);
  });

  group('bu_kampus/alarm', () {
    test('haftalik alarm: ISO gunler Calendar.DAY_OF_WEEK degerlerine cevrilir (Pzt=2 ... Paz=1)', () async {
      mock('bu_kampus/alarm', (c) async => true);
      final ok = await ChannelDeviceAlarmService(clockApp: true).set(const AlarmSpec(key: 'class-0715', hour: 7, minute: 15, label: 'Ders alarmi', weekdays: [1, 3, 7]));
      expect(ok, isTrue);
      final c = calls.single;
      expect(c.method, 'setAlarm');
      final a = (c.arguments as Map).cast<String, Object?>();
      expect((a['hour'], a['minute'], a['label']), (7, 15, 'Ders alarmi'));
      expect(a['days'], [2, 4, 1]);
      expect(a.containsKey('date'), isFalse);
    });

    test('tek seferlik alarm: gun listesi bos; tarih (iOS bildirimi icin) gonderilir', () async {
      mock('bu_kampus/alarm', (c) async => true);
      await ChannelDeviceAlarmService(clockApp: true).set(AlarmSpec(key: 'exam-1', hour: 9, minute: 0, label: 'Sinav', date: DateTime.utc(2026, 11, 16), title: 'T', body: 'B', payload: const {'targetType': 'EXAM'}));
      final a = (calls.single.arguments as Map).cast<String, Object?>();
      expect(a['days'], isEmpty);
      expect(a['date'], {'year': 2026, 'month': 11, 'day': 16});
      expect(a['payload'], {'targetType': 'EXAM'});
      expect(a['key'], 'exam-1');
    });

    test('yerel kod yoksa (MissingPlugin) ya da hata: false, exception sizmaz', () async {
      final s = ChannelDeviceAlarmService(clockApp: true);
      expect(await s.set(const AlarmSpec(key: 'k', hour: 1, minute: 2, label: 'x')), isFalse);
      expect(await s.isAvailable(), isFalse);
      mock('bu_kampus/alarm', (c) async => throw PlatformException(code: 'X'));
      expect(await s.set(const AlarmSpec(key: 'k', hour: 1, minute: 2, label: 'x')), isFalse);
    });

    test('usesClockApp: kurucuda verilen deger', () {
      expect(ChannelDeviceAlarmService(clockApp: true).usesClockApp, isTrue);
      expect(ChannelDeviceAlarmService(clockApp: false).usesClockApp, isFalse);
    });
  });

  group('bu_kampus/calendar', () {
    test('izin durumlari eslenir; yerel kod yoksa unavailable', () async {
      final b = ChannelDeviceCalendarBackend();
      expect(await b.access(), CalAccess.unavailable);
      mock('bu_kampus/calendar', (c) async => switch (c.method) {
            'access' => 'notDetermined',
            'requestAccess' => 'denied',
            _ => null,
          });
      expect(await b.access(), CalAccess.notDetermined);
      expect(await b.requestAccess(), CalAccess.denied);
    });

    test('takvim listesi', () async {
      mock('bu_kampus/calendar', (c) async => [
            {'id': '1', 'name': 'Ana', 'account': 'a@b.c', 'primary': true, 'local': false},
            {'id': '2', 'name': 'BU', 'account': 'BU Kampus', 'primary': false, 'local': true},
          ]);
      final l = await ChannelDeviceCalendarBackend().calendars();
      expect(l.map((c) => (c.id, c.primary, c.local)), [('1', true, false), ('2', false, true)]);
    });

    test('etkinlik yaz: tum gun alanlari kanalda, yanit olusturuldu/guncellendi', () async {
      mock('bu_kampus/calendar', (c) async => {'id': '77', 'created': false});
      final r = await ChannelDeviceCalendarBackend().upsertEvent(const DeviceEventSpec(
        calendarId: '1',
        eventId: '77',
        title: 'Vize',
        notes: 'n',
        startDay: '2026-11-17',
        endDay: '2026-11-19',
        alarmDayMin: 480,
      ));
      expect(r, isNotNull);
      expect((r!.id, r.created), ('77', false));
      final a = (calls.single.arguments as Map).cast<String, Object?>();
      expect(a['allDay'], true);
      expect((a['startDay'], a['endDay'], a['alarmDayMin'], a['eventId'], a['tz']), ('2026-11-17', '2026-11-19', 480, '77', 'Europe/Istanbul'));
      expect(a.containsKey('startMs'), isFalse);
    });

    test('yazma/silme hatasi: null/false', () async {
      mock('bu_kampus/calendar', (c) async => null);
      final b = ChannelDeviceCalendarBackend();
      expect(await b.upsertEvent(const DeviceEventSpec(calendarId: '1', title: 'x')), isNull);
      expect(await b.deleteEvent('1', '9'), isFalse);
      expect(await b.createCalendar('BU'), isNull);
    });

    test('silme: takvim + etkinlik kimligi', () async {
      mock('bu_kampus/calendar', (c) async => true);
      expect(await ChannelDeviceCalendarBackend().deleteEvent('1', '9'), isTrue);
      expect(calls.single.arguments, {'calendarId': '1', 'eventId': '9'});
    });
  });
}
