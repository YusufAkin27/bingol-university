import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/platform/device_calendar.dart';

/// Etkinliği cihaz takvimine yazan ve hatırlatıcıyı tek kaynaktan (takvimin kendi alarmı) veren servis.
/// Akademik takvimdeki [DeviceCalendarBackend] köprüsünü yeniden kullanır; akademik kayıtlarla karışmasın diye
/// ayrı depo tutar. Katılımdan ayrılınca [remove] cihaz etkinliğini (dolayısıyla hatırlatıcıyı) siler.

/// Hatırlatma süreleri (dakika): 15 dk, 1 sa, 1 gün.
const List<int> kEventLeadChoices = [15, 60, 1440];

/// Katılım sonrası önerilen süre.
const int kEventDefaultLead = 60;

class EventCalLink {
  const EventCalLink({required this.eventId, required this.calendarId, required this.leadMin});

  /// Cihaz etkinliği kimliği.
  final String eventId, calendarId;
  final int leadMin;

  Map<String, Object?> toJson() => {'e': eventId, 'c': calendarId, 'l': leadMin};

  factory EventCalLink.fromJson(Map<String, dynamic> j) =>
      EventCalLink(eventId: '${j['e']}', calendarId: '${j['c']}', leadMin: j['l'] is int ? j['l'] as int : kEventDefaultLead);
}

class EventCalState {
  const EventCalState({this.links = const {}, this.dontAsk = false, this.calendarId});

  /// Uygulama etkinlik kimliği -> cihaz etkinliği.
  final Map<int, EventCalLink> links;

  /// Katılım sonrası öneri bir daha sorulmasın.
  final bool dontAsk;

  /// Son kullanılan takvim.
  final String? calendarId;

  EventCalState copyWith({Map<int, EventCalLink>? links, bool? dontAsk, String? calendarId}) =>
      EventCalState(links: links ?? this.links, dontAsk: dontAsk ?? this.dontAsk, calendarId: calendarId ?? this.calendarId);

  Map<String, Object?> toJson() => {
        'dontAsk': dontAsk,
        if (calendarId != null) 'cal': calendarId,
        'links': {for (final e in links.entries) '${e.key}': e.value.toJson()},
      };

  factory EventCalState.fromJson(Map<String, dynamic> j) {
    final raw = j['links'];
    return EventCalState(
      dontAsk: j['dontAsk'] == true,
      calendarId: j['cal'] is String ? j['cal'] as String : null,
      links: {
        if (raw is Map)
          for (final e in raw.entries)
            if (int.tryParse('${e.key}') != null && e.value is Map)
              int.parse('${e.key}'): EventCalLink.fromJson((e.value as Map).cast<String, dynamic>())
      },
    );
  }
}

abstract class EventCalStore {
  Future<EventCalState> load();
  Future<void> save(EventCalState s);
}

class SecureEventCalStore implements EventCalStore {
  const SecureEventCalStore();
  static const _key = 'event_calendar_links';

  @override
  Future<EventCalState> load() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return const EventCalState();
      return EventCalState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const EventCalState();
    }
  }

  @override
  Future<void> save(EventCalState s) async {
    try {
      await const FlutterSecureStorage().write(key: _key, value: jsonEncode(s.toJson()));
    } catch (_) {}
  }
}

class MemoryEventCalStore implements EventCalStore {
  MemoryEventCalStore([this.value = const EventCalState()]);
  EventCalState value;

  @override
  Future<EventCalState> load() async => value;

  @override
  Future<void> save(EventCalState s) async => value = s;
}

/// [EventCalendarService.add] sonucu.
enum EventCalResult { added, updated, denied, unavailable, failed, pastEvent }

class EventCalendarService {
  EventCalendarService({DeviceCalendarBackend? backend, EventCalStore? store, DateTime Function()? clock})
      : _backend = backend,
        _store = store ?? const SecureEventCalStore(),
        _clock = clock ?? DateTime.now;

  static EventCalendarService instance = EventCalendarService();

  final DeviceCalendarBackend? _backend;
  final EventCalStore _store;
  final DateTime Function() _clock;

  DeviceCalendarBackend get backend => _backend ?? DeviceCalendarBackend.instance;

  Future<EventCalState> state() => _store.load();

  Future<EventCalLink?> linkOf(int eventId) async => (await _store.load()).links[eventId];

  Future<void> setDontAsk(bool v) async => _store.save((await _store.load()).copyWith(dontAsk: v));

  /// Etkinliği takvime yazar (varsa günceller) ve başlangıçtan [leadMin] dk önce alarm kurar.
  Future<EventCalResult> add({
    required int eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String location = '',
    int leadMin = kEventDefaultLead,
  }) async {
    if (!startsAt.isAfter(_clock())) return EventCalResult.pastEvent;
    var acc = await backend.access();
    if (acc == CalAccess.notDetermined) acc = await backend.requestAccess();
    if (acc == CalAccess.unavailable) return EventCalResult.unavailable;
    if (acc != CalAccess.granted) return EventCalResult.denied;

    final st = await _store.load();
    final cals = await backend.calendars();
    var calId = cals.any((c) => c.id == st.calendarId) ? st.calendarId : (cals.where((c) => c.primary).firstOrNull ?? cals.firstOrNull)?.id;
    calId ??= await backend.createCalendar('BÜ Kampüs');
    if (calId == null) return EventCalResult.failed;

    final cur = st.links[eventId];
    var end = endsAt ?? startsAt.add(const Duration(hours: 1));
    if (!end.isAfter(startsAt)) end = startsAt.add(const Duration(hours: 1));
    var alarm = startsAt.subtract(Duration(minutes: leadMin));
    if (!alarm.isAfter(_clock())) alarm = startsAt.subtract(const Duration(minutes: 1));
    final r = await backend.upsertEvent(DeviceEventSpec(
      calendarId: calId,
      eventId: cur?.calendarId == calId ? cur?.eventId : null,
      title: title,
      notes: location,
      allDay: false,
      startMs: startsAt.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
      alarmAtMs: alarm.millisecondsSinceEpoch,
    ));
    if (r == null) return EventCalResult.failed;
    final links = {...st.links, eventId: EventCalLink(eventId: r.id, calendarId: calId, leadMin: leadMin)};
    await _store.save(st.copyWith(links: links, calendarId: calId));
    return r.created ? EventCalResult.added : EventCalResult.updated;
  }

  /// Etkinliğin takvim kaydını (ve hatırlatıcısını) siler; kayıt yoksa false.
  Future<bool> remove(int eventId) async {
    final st = await _store.load();
    final l = st.links[eventId];
    if (l == null) return false;
    await backend.deleteEvent(l.calendarId, l.eventId);
    await _store.save(st.copyWith(links: {...st.links}..remove(eventId)));
    return true;
  }
}
