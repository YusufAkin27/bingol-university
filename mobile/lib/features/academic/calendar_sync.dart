import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/platform/device_calendar.dart';
import 'academic_models.dart';

/// Akademik takvimi cihaz takvimine yazan servis. Yazılan etkinliklerin cihaz kimlikleri saklanır: ikinci "Takvime
/// ekle" mevcutları GÜNCELLER (çift oluşturmaz), "Kaldır" yalnız bizim yazdıklarımızı siler.
///
/// Hatırlatma TEK KAYNAK: bildirim cihaz takviminin kendi hatırlatıcısıdır (tüm gün etkinlikte o gün 08:00); uygulama
/// ayrıca yerel bildirim kurmaz, böylece çift bildirim olmaz.

/// Hatırlatıcı saati: günün 08:00'i (dakika).
const kCalendarAlarmDayMin = 8 * 60;

int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Bir akademik kaydın cihaz takvimindeki karşılığı.
class CalendarLink {
  const CalendarLink({required this.eventId, required this.calendarId, required this.hash, required this.endDay});

  final String eventId, calendarId;
  final int hash;

  /// Etkinliğin son günü (`yyyy-MM-dd`; geçmiş ayrımı için).
  final String endDay;

  Map<String, Object?> toJson() => {'e': eventId, 'c': calendarId, 'h': hash, 'd': endDay};

  factory CalendarLink.fromJson(Map<String, dynamic> j) =>
      CalendarLink(eventId: '${j['e']}', calendarId: '${j['c']}', hash: j['h'] is int ? j['h'] as int : 0, endDay: '${j['d']}');
}

class CalendarSyncState {
  const CalendarSyncState({this.calendarId, this.calendarName, this.links = const {}});

  final String? calendarId, calendarName;

  /// Akademik takvim kaydı kimliği -> cihaz etkinliği.
  final Map<int, CalendarLink> links;

  /// Bugün ve sonrası için cihaz takviminde duran etkinlik sayısı.
  int activeCount(String todayIso) => links.values.where((l) => l.endDay.compareTo(todayIso) >= 0).length;

  Map<String, Object?> toJson() => {
        if (calendarId != null) 'cal': calendarId,
        if (calendarName != null) 'name': calendarName,
        'links': {for (final e in links.entries) '${e.key}': e.value.toJson()},
      };

  factory CalendarSyncState.fromJson(Map<String, dynamic> j) {
    final raw = j['links'];
    return CalendarSyncState(
      calendarId: j['cal'] is String ? j['cal'] as String : null,
      calendarName: j['name'] is String ? j['name'] as String : null,
      links: {
        if (raw is Map)
          for (final e in raw.entries)
            if (int.tryParse('${e.key}') != null && e.value is Map) int.parse('${e.key}'): CalendarLink.fromJson((e.value as Map).cast<String, dynamic>())
      },
    );
  }
}

abstract class CalendarSyncStore {
  Future<CalendarSyncState> load();
  Future<void> save(CalendarSyncState s);
}

class SecureCalendarSyncStore implements CalendarSyncStore {
  const SecureCalendarSyncStore();
  static const _key = 'academic_calendar_sync';

  @override
  Future<CalendarSyncState> load() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return const CalendarSyncState();
      return CalendarSyncState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const CalendarSyncState();
    }
  }

  @override
  Future<void> save(CalendarSyncState s) async {
    try {
      await const FlutterSecureStorage().write(key: _key, value: jsonEncode(s.toJson()));
    } catch (_) {}
  }
}

class MemoryCalendarSyncStore implements CalendarSyncStore {
  MemoryCalendarSyncStore([this.value = const CalendarSyncState()]);
  CalendarSyncState value;

  @override
  Future<CalendarSyncState> load() async => value;

  @override
  Future<void> save(CalendarSyncState s) async => value = s;
}

class CalendarSyncResult {
  const CalendarSyncResult({this.added = 0, this.updated = 0, this.unchanged = 0, this.removed = 0, this.failed = 0});

  final int added, updated, unchanged, removed, failed;

  /// Cihaz takvimine gerçekten dokunuldu mu.
  bool get changed => added + updated + removed > 0;

  @override
  String toString() => 'CalendarSyncResult(+$added ~$updated =$unchanged -$removed !$failed)';
}

/// Akademik kaydı cihaz etkinliğine çevirir. Tüm gün kayıtlar tüm gün etkinlik olur ve o gün 08:00 hatırlatıcı alır;
/// saatli kayıtlar kendi saatinde yazılır ve o günün 08:00'inde (başlangıç daha erkense başlangıçta) hatırlatır.
DeviceEventSpec academicEventSpec(AcademicEvent e, {required String calendarId, String? eventId, String notes = ''}) {
  final w = istanbulWall(e.startsAt);
  final timed = !e.allDay && !(w.hour == 0 && w.minute == 0);
  if (!timed) {
    return DeviceEventSpec(
      calendarId: calendarId,
      eventId: eventId,
      title: e.title,
      notes: notes,
      allDay: true,
      startDay: isoDate(e.startDay),
      endDay: isoDate(e.endDay),
      alarmDayMin: kCalendarAlarmDayMin,
    );
  }
  final start = e.startsAt;
  var end = e.endsAt ?? start.add(const Duration(hours: 1));
  if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
  var alarm = wallToInstant(w.year, w.month, w.day, 8);
  if (!alarm.isBefore(start)) alarm = start;
  return DeviceEventSpec(
    calendarId: calendarId,
    eventId: eventId,
    title: e.title,
    notes: notes,
    allDay: false,
    startMs: start.millisecondsSinceEpoch,
    endMs: end.millisecondsSinceEpoch,
    alarmAtMs: alarm.millisecondsSinceEpoch,
  );
}

String _signature(DeviceEventSpec s) =>
    [s.title, s.notes, s.allDay, s.startDay, s.endDay, s.startMs, s.endMs, s.alarmDayMin, s.alarmAtMs].join('\u0001');

class CalendarSyncService {
  CalendarSyncService({DeviceCalendarBackend? backend, CalendarSyncStore? store, DateTime Function()? clock})
      : _backend = backend,
        _store = store ?? const SecureCalendarSyncStore(),
        _clock = clock ?? academicClock;

  static CalendarSyncService instance = CalendarSyncService();

  final DeviceCalendarBackend? _backend;
  final CalendarSyncStore _store;
  final DateTime Function() _clock;

  DeviceCalendarBackend get backend => _backend ?? DeviceCalendarBackend.instance;

  String get todayIso {
    final w = istanbulWall(_clock());
    return isoDate(DateTime.utc(w.year, w.month, w.day));
  }

  Future<CalendarSyncState> state() => _store.load();

  /// [events] sunucudan gelen akademik takvimdir ([windowEnd] penceresinin son günü, `yyyy-MM-dd`). Geçmiş kayıtlar
  /// yazılmaz; pencere içinde artık gelmeyen (yöneticinin sildiği) eski kayıtlar cihazdan da silinir.
  Future<CalendarSyncResult> sync({
    required DeviceCalendarInfo target,
    required List<AcademicEvent> events,
    required String windowEnd,
    String Function(AcademicEvent e)? notesOf,
  }) async {
    final today = todayIso;
    var st = await _store.load();
    final links = {...st.links};
    var added = 0, updated = 0, unchanged = 0, removed = 0, failed = 0;

    // Hedef takvim değiştiyse eskisindeki bizim etkinliklerimiz taşınır (silinip yenisine yazılır).
    if (st.calendarId != null && st.calendarId != target.id) {
      for (final e in links.entries.toList()) {
        if (await backend.deleteEvent(e.value.calendarId, e.value.eventId)) {
          links.remove(e.key);
        }
      }
    }

    final fetched = {for (final e in events) e.id};
    for (final e in events) {
      if (isoDate(e.endDay).compareTo(today) < 0) continue;
      final cur = links[e.id];
      final spec = academicEventSpec(e, calendarId: target.id, eventId: cur?.calendarId == target.id ? cur?.eventId : null, notes: notesOf?.call(e) ?? '');
      final h = _fnv(_signature(spec));
      // Her seferinde yazılır: etkinlik yerindeyse güncellenir (çift kayıt yok), kullanıcı takvimden elle sildiyse
      // yeniden oluşur. İçerik değişmediyse "aynı kaldı" sayılır.
      final r = await backend.upsertEvent(spec);
      if (r == null) {
        failed++;
        continue;
      }
      if (r.created) {
        added++;
      } else if (cur != null && cur.calendarId == target.id && cur.hash == h) {
        unchanged++;
      } else {
        updated++;
      }
      links[e.id] = CalendarLink(eventId: r.id, calendarId: target.id, hash: h, endDay: isoDate(e.endDay));
    }

    for (final entry in links.entries.toList()) {
      final l = entry.value;
      if (fetched.contains(entry.key)) continue;
      if (l.endDay.compareTo(today) < 0 || l.endDay.compareTo(windowEnd) > 0) continue;
      if (await backend.deleteEvent(l.calendarId, l.eventId)) {
        links.remove(entry.key);
        removed++;
      }
    }

    st = CalendarSyncState(calendarId: target.id, calendarName: target.name, links: links);
    await _store.save(st);
    return CalendarSyncResult(added: added, updated: updated, unchanged: unchanged, removed: removed, failed: failed);
  }

  /// Bizim yazdığımız tüm etkinlikleri cihaz takviminden siler; kaç tane silindi.
  Future<int> removeAll() async {
    final st = await _store.load();
    final left = {...st.links};
    var n = 0;
    for (final e in st.links.entries) {
      if (await backend.deleteEvent(e.value.calendarId, e.value.eventId)) {
        left.remove(e.key);
        n++;
      }
    }
    await _store.save(left.isEmpty ? const CalendarSyncState() : CalendarSyncState(calendarId: st.calendarId, calendarName: st.calendarName, links: left));
    return n;
  }
}
