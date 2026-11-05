import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihaz takvimine yazma arayüzü (Android `CalendarContract`, iOS EventKit; kanal `bu_kampus/calendar`).
///
/// Neden eklenti değil kendi köprü: yalnız beş işlem gerekir (izin, takvim listesi, yaz/güncelle, sil, yerel takvim
/// oluştur); hepsinde kimlikle güncelleme, tüm gün + hatırlatıcı (iOS mutlak alarm) ve yalnız bizim yazdıklarımızı
/// silme denetimi isteriz. Genç eklentiler (device_calendar_plus 0.x) bu ayrıntıları tam vermez, Gradle/AGP uyumu da
/// ek risktir; köprü mevcut `BuNativeBridge`/Kotlin kalıbına uyar ve yeni bağımlılık eklemez.

/// Takvim izni durumu.
enum CalAccess {
  /// Okuma + yazma verildi.
  granted,

  /// Henüz sorulmadı (ya da Android'de yeniden sorulabilir).
  notDetermined,

  /// Reddedildi ya da kısıtlı: yalnız Ayarlar'dan açılır.
  denied,

  /// Bu platformda köprü yok (masaüstü, test).
  unavailable,
}

class DeviceCalendarInfo {
  const DeviceCalendarInfo({required this.id, required this.name, this.account = '', this.primary = false, this.local = false});

  final String id, name, account;
  final bool primary, local;

  factory DeviceCalendarInfo.fromMap(Map<Object?, Object?> m) => DeviceCalendarInfo(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        account: '${m['account'] ?? ''}',
        primary: m['primary'] == true,
        local: m['local'] == true,
      );
}

/// Yazılacak tek etkinlik. Tüm gün etkinlikte [startDay]/[endDay] (dahil, `yyyy-MM-dd`) ve [alarmDayMin] (gün
/// başından kaç dk sonra, örn. 480 = 08:00) kullanılır; saatli etkinlikte [startMs]/[endMs]/[alarmAtMs] (epoch ms).
class DeviceEventSpec {
  const DeviceEventSpec({
    required this.calendarId,
    this.eventId,
    required this.title,
    this.notes = '',
    this.allDay = true,
    this.startDay,
    this.endDay,
    this.startMs,
    this.endMs,
    this.alarmDayMin,
    this.alarmAtMs,
  });

  final String calendarId;
  final String? eventId;
  final String title, notes;
  final bool allDay;
  final String? startDay, endDay;
  final int? startMs, endMs;
  final int? alarmDayMin;
  final int? alarmAtMs;

  Map<String, Object?> toMap() => {
        'calendarId': calendarId,
        if (eventId != null) 'eventId': eventId,
        'title': title,
        'notes': notes,
        'allDay': allDay,
        if (startDay != null) 'startDay': startDay,
        if (endDay != null) 'endDay': endDay,
        if (startMs != null) 'startMs': startMs,
        if (endMs != null) 'endMs': endMs,
        if (alarmDayMin != null) 'alarmDayMin': alarmDayMin,
        if (alarmAtMs != null) 'alarmAtMs': alarmAtMs,
        'tz': 'Europe/Istanbul',
      };
}

abstract class DeviceCalendarBackend {
  static DeviceCalendarBackend instance = ChannelDeviceCalendarBackend();

  Future<CalAccess> access();

  /// Sistem iznini ister (verilmiş/kalıcı reddedilmişse istem çıkmaz, güncel durum döner).
  Future<CalAccess> requestAccess();

  /// Yazılabilir takvimler.
  Future<List<DeviceCalendarInfo>> calendars();

  /// Yerel "BÜ Kampüs" takvimi oluşturur; kimliği ya da null.
  Future<String?> createCalendar(String name);

  /// Etkinliği yazar. [DeviceEventSpec.eventId] varsa ve takvimde duruyorsa günceller (`created=false`), yoksa ekler.
  /// Başarısızsa null.
  Future<({String id, bool created})?> upsertEvent(DeviceEventSpec spec);

  /// Yalnız [calendarId] içindeki bu etkinliği siler; silindi ya da zaten yoktu ise true.
  Future<bool> deleteEvent(String calendarId, String eventId);
}

class ChannelDeviceCalendarBackend implements DeviceCalendarBackend {
  ChannelDeviceCalendarBackend();

  static const channel = MethodChannel('bu_kampus/calendar');

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(m, args);
    } on MissingPluginException {
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('device calendar $m: ${e.code}');
      return null;
    }
  }

  CalAccess _parse(String? s) => switch (s) {
        'granted' => CalAccess.granted,
        'notDetermined' => CalAccess.notDetermined,
        _ => CalAccess.denied,
      };

  @override
  Future<CalAccess> access() async {
    try {
      return _parse(await _call<String>('access'));
    } on MissingPluginException {
      return CalAccess.unavailable;
    }
  }

  @override
  Future<CalAccess> requestAccess() async {
    try {
      return _parse(await _call<String>('requestAccess'));
    } on MissingPluginException {
      return CalAccess.unavailable;
    }
  }

  @override
  Future<List<DeviceCalendarInfo>> calendars() async {
    try {
      final r = await _call<List<Object?>>('calendars');
      return [for (final m in r ?? const []) if (m is Map) DeviceCalendarInfo.fromMap(m)];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<String?> createCalendar(String name) async {
    try {
      final id = await _call<Object>('createCalendar', {'name': name});
      return id == null ? null : '$id';
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<({String id, bool created})?> upsertEvent(DeviceEventSpec spec) async {
    try {
      final r = await _call<Map<Object?, Object?>>('upsertEvent', spec.toMap());
      if (r == null || r['id'] == null) return null;
      return (id: '${r['id']}', created: r['created'] != false);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> deleteEvent(String calendarId, String eventId) async {
    try {
      return (await _call<bool>('deleteEvent', {'calendarId': calendarId, 'eventId': eventId})) ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Testler için bellekte çalışan sahte takvim.
class FakeDeviceCalendarBackend implements DeviceCalendarBackend {
  FakeDeviceCalendarBackend({
    this.state = CalAccess.granted,
    this.onRequest = CalAccess.granted,
    List<DeviceCalendarInfo>? calendars,
    this.failTitles = const {},
  }) : _calendars = calendars ?? const [DeviceCalendarInfo(id: 'c1', name: 'Takvim', account: 'a@x.com', primary: true)];

  CalAccess state;
  final CalAccess onRequest;
  final List<DeviceCalendarInfo> _calendars;
  final Set<String> failTitles;

  /// eventId -> son yazılan özellikler.
  final Map<String, DeviceEventSpec> events = {};
  final List<String> deleted = [];
  int upserts = 0, creates = 0, requests = 0;
  int _next = 1;

  @override
  Future<CalAccess> access() async => state;

  @override
  Future<CalAccess> requestAccess() async {
    requests++;
    if (state == CalAccess.notDetermined) state = onRequest;
    return state;
  }

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => _calendars;

  @override
  Future<String?> createCalendar(String name) async => 'new-$name';

  @override
  Future<({String id, bool created})?> upsertEvent(DeviceEventSpec spec) async {
    upserts++;
    if (failTitles.contains(spec.title)) return null;
    final id = spec.eventId;
    if (id != null && events.containsKey(id)) {
      events[id] = spec;
      return (id: id, created: false);
    }
    final nid = 'e${_next++}';
    events[nid] = spec;
    creates++;
    return (id: nid, created: true);
  }

  @override
  Future<bool> deleteEvent(String calendarId, String eventId) async {
    deleted.add(eventId);
    events.remove(eventId);
    return true;
  }
}
