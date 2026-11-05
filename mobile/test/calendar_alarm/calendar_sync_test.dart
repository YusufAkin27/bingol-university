import 'package:bu_kampus/core/platform/device_calendar.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/calendar_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Takvim yazma servisi sahte backend ile: cift kayit yok, guncelleme, kaldirma, izin durumlari, kanal cagrilari.
AcademicEvent _ev(int id, String title, String start, {String? end, bool allDay = true, String kind = 'DERS_KAYIT'}) => AcademicEvent(
      id: id,
      kind: kind,
      title: title,
      // 'yyyy-MM-dd' Istanbul gece yarisi
      startsAt: wallToInstant(int.parse(start.substring(0, 4)), int.parse(start.substring(5, 7)), int.parse(start.substring(8, 10)), start.length > 10 ? int.parse(start.substring(11, 13)) : 0, start.length > 10 ? int.parse(start.substring(14, 16)) : 0),
      endsAt: end == null
          ? null
          : wallToInstant(int.parse(end.substring(0, 4)), int.parse(end.substring(5, 7)), int.parse(end.substring(8, 10)), end.length > 10 ? int.parse(end.substring(11, 13)) : 0, end.length > 10 ? int.parse(end.substring(14, 16)) : 0),
      allDay: allDay,
    );

const _cal = DeviceCalendarInfo(id: 'c1', name: 'Takvim', primary: true);

void main() {
  late FakeDeviceCalendarBackend be;
  late MemoryCalendarSyncStore store;
  late CalendarSyncService svc;

  setUp(() {
    be = FakeDeviceCalendarBackend();
    store = MemoryCalendarSyncStore();
    svc = CalendarSyncService(backend: be, store: store, clock: () => wallToInstant(2026, 11, 9, 9, 0));
  });

  final events = [
    _ev(1, 'Ders kayit', '2026-11-20', end: '2026-11-22'),
    _ev(2, 'Vize haftasi', '2026-12-01'),
    _ev(3, 'Saatli toplanti', '2026-11-25 14:00', end: '2026-11-25 15:30', allDay: false),
  ];

  test('tum gun kayit: tum gun etkinlik + o gun 08:00 hatirlatici (dahil bitis), saatli kayit kendi saatinde', () {
    final all = academicEventSpec(events[0], calendarId: 'c1', notes: 'n');
    expect(all.allDay, isTrue);
    expect((all.startDay, all.endDay), ('2026-11-20', '2026-11-22'));
    expect(all.alarmDayMin, 480);
    expect(all.toMap()['tz'], 'Europe/Istanbul');
    final timed = academicEventSpec(events[2], calendarId: 'c1');
    expect(timed.allDay, isFalse);
    expect(timed.endMs! - timed.startMs!, 90 * 60 * 1000);
    // 14:00 baslangic 08:00 sonrasi: hatirlatici o gun 08:00
    expect(timed.alarmAtMs, wallToInstant(2026, 11, 25, 8, 0).millisecondsSinceEpoch);
    // sabah 07:00 baslangic: hatirlatici baslangicta
    final early = academicEventSpec(_ev(9, 'Erken', '2026-11-25 07:00', allDay: false), calendarId: 'c1');
    expect(early.alarmAtMs, early.startMs);
    // allDay=false ama 00:00 baslangic ("yarim gun" kaydi): tum gun sayilir
    expect(academicEventSpec(_ev(8, 'Gece yarisi', '2026-11-25', allDay: false), calendarId: 'c1').allDay, isTrue);
  });

  test('ilk yazma hepsini ekler; ikinci yazma CIFT KAYIT OLUSTURMAZ (degismedi)', () async {
    final r1 = await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    expect((r1.added, r1.updated, r1.unchanged), (3, 0, 0));
    expect(be.events, hasLength(3));
    final r2 = await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    expect((r2.added, r2.updated, r2.unchanged), (0, 0, 3));
    expect(be.events, hasLength(3));
    expect(be.creates, 3); // ikinci turda yeni etkinlik acilmadi (yerinde guncellendi)
  });

  test('baslik/tarih degisince GUNCELLER (yeni etkinlik acmaz)', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    final changed = [events[0], _ev(2, 'Vize haftasi (yeni)', '2026-12-02'), events[2]];
    final r = await svc.sync(target: _cal, events: changed, windowEnd: '2027-11-09');
    expect((r.added, r.updated, r.unchanged), (0, 1, 2));
    expect(be.events, hasLength(3));
    expect(be.events.values.any((s) => s.title == 'Vize haftasi (yeni)' && s.startDay == '2026-12-02'), isTrue);
  });

  test('kullanici etkinligi takvimden elle sildiyse yeniden eklenir', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    be.events.clear();
    final r = await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    expect((r.added, r.updated, r.unchanged), (3, 0, 0)); // yerinde yoklar: yeniden olusturuldu
    expect(be.events, hasLength(3));
  });

  test('gecmis kayitlar yazilmaz', () async {
    final r = await svc.sync(target: _cal, events: [_ev(5, 'Eski', '2026-10-01', end: '2026-10-03'), events[1]], windowEnd: '2027-11-09');
    expect(r.added, 1);
    expect(be.events.values.single.title, 'Vize haftasi');
  });

  test('yoneticinin sildigi (artik gelmeyen) gelecek kayit cihazdan da silinir; pencere disi dokunulmaz', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    final r = await svc.sync(target: _cal, events: [events[0], events[2]], windowEnd: '2027-11-09');
    expect(r.removed, 1);
    expect(be.events, hasLength(2));
  });

  test('pencere disindaki eski kayda dokunulmaz (cekilen aralikta olmayan silinmis sayilmaz)', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    // pencere 21 Kasim'da biter: kayitlarin hepsi (22 Kasim, 25 Kasim, 1 Aralik) pencerenin DISINDA
    final r = await svc.sync(target: _cal, events: const [], windowEnd: '2026-11-21');
    expect(r.removed, 0);
    expect(be.events, hasLength(3));
    // pencere 22 Kasim'a uzayinca yalniz o gune kadar olan (Ders kayit) silinir
    final r2 = await svc.sync(target: _cal, events: const [], windowEnd: '2026-11-22');
    expect(r2.removed, 1);
    expect(be.events, hasLength(2));
  });

  test('hedef takvim degisirse eskisindeki bizim etkinlikler tasinir', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    final first = be.events.keys.toList();
    const other = DeviceCalendarInfo(id: 'c2', name: 'Is');
    final r = await svc.sync(target: other, events: events, windowEnd: '2027-11-09');
    expect(r.added, 3);
    expect(be.deleted.toSet(), first.toSet());
    expect(be.events.values.every((s) => s.calendarId == 'c2'), isTrue);
  });

  test('yazilamayan etkinlik failed sayilir, digerleri yazilir', () async {
    be = FakeDeviceCalendarBackend(failTitles: {'Vize haftasi'});
    svc = CalendarSyncService(backend: be, store: store, clock: () => wallToInstant(2026, 11, 9, 9, 0));
    final r = await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    expect((r.added, r.failed), (2, 1));
  });

  test('removeAll yalniz bizim yazdiklarimizi siler (baska etkinlige dokunmaz)', () async {
    // baska uygulamanin etkinligi
    be.events['foreign'] = const DeviceEventSpec(calendarId: 'c1', title: 'Dis etkinlik');
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    expect(await svc.removeAll(), 3);
    expect(be.events.keys, ['foreign']);
    expect((await svc.state()).links, isEmpty);
    expect((await svc.state()).activeCount('2026-11-09'), 0);
  });

  test('aktif sayi: yalniz bitmemis kayitlar', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    final st = await svc.state();
    expect(st.activeCount('2026-11-09'), 3);
    expect(st.activeCount('2026-11-23'), 2); // Ders kayit (11-22) bitti
    expect(st.activeCount('2027-01-01'), 0);
  });

  test('durum JSON gidis-donus', () async {
    await svc.sync(target: _cal, events: events, windowEnd: '2027-11-09');
    final st = await svc.state();
    final back = CalendarSyncState.fromJson(st.toJson().map((k, v) => MapEntry(k, v)).cast<String, dynamic>());
    expect(back.calendarId, 'c1');
    expect(back.links.keys, st.links.keys);
  });

  test('sahte backend izin akisi', () async {
    final denied = FakeDeviceCalendarBackend(state: CalAccess.denied);
    expect(await denied.requestAccess(), CalAccess.denied); // kalici red: istem cikmaz
    final fresh = FakeDeviceCalendarBackend(state: CalAccess.notDetermined);
    expect(await fresh.requestAccess(), CalAccess.granted);
    expect(fresh.requests, 1);
  });
}
