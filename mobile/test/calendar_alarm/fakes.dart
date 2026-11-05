import 'package:bu_kampus/core/notify/local_reminders.dart';
import 'package:bu_kampus/core/platform/device_alarm.dart';
import 'package:bu_kampus/features/academic/alarm_service.dart';

/// Bellekte calisan yerel hatirlatma arka ucu.
class RemBackend implements LocalReminderBackend {
  final Map<String, List<LocalReminder>> groups = {};

  @override
  Future<void> replaceGroup(String group, List<LocalReminder> items) async => groups[group] = items;
  @override
  Future<void> upsert(String group, LocalReminder item) async {}
  @override
  Future<void> cancel(String group, int id) async {}
  @override
  Future<void> cancelGroup(String group) async => groups.remove(group);
  @override
  Future<void> cancelAll() async => groups.clear();
  @override
  Future<bool> notificationsAllowed() async => true;
  @override
  Future<Map<String, String>?> takeLaunchPayload() async => null;
}

/// Alarm servislerini sahtelerle degistirir; sahte alarm servisini dondurur.
FakeDeviceAlarmService useFakeAlarms({bool clock = true, RemBackend? reminders, DateTime Function()? now}) {
  final fake = FakeDeviceAlarmService(clockApp: clock);
  final rem = reminders ?? RemBackend();
  DeviceAlarmService.instance = fake;
  // Gercek kanal testte yanit vermez; hatirlatma ve bildirim izni sorgusu sahteye gider.
  LocalReminders.instance = LocalReminders(rem);
  AlarmService.instance = AlarmService(
    alarms: fake,
    store: MemoryAlarmStateStore(),
    reminders: LocalReminders.instance,
    gap: Duration.zero,
    clock: now,
  );
  return fake;
}

void resetAlarms() {
  DeviceAlarmService.instance = ChannelDeviceAlarmService();
  AlarmService.instance = AlarmService();
  LocalReminders.instance = LocalReminders(const ChannelReminderBackend());
}
