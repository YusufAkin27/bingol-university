import { describe, expect, it } from 'vitest';
import { CALENDAR_KINDS, type AcademicEvent } from '../../../api/academic';
import {
  buildLanes,
  dayNum,
  keyOfDay,
  layoutBox,
  packLanes,
  placeEvent,
  shiftWindowStart,
  summarizeUpcoming,
  timelineWindow,
  todayPct,
} from './timelineLogic';

let seq = 0;
function ev(over: Partial<AcademicEvent> & Pick<AcademicEvent, 'startsAt'>): AcademicEvent {
  seq += 1;
  return {
    id: seq,
    kind: 'VIZE',
    title: `Olay ${seq}`,
    endsAt: null,
    allDay: true,
    scopeDepartment: null,
    note: null,
    published: true,
    ...over,
  };
}

describe('timelineWindow', () => {
  it('6 aylık pencerenin gün sayısını ve uçlarını hesaplar', () => {
    const w = timelineWindow(2026, 10, 6); // Kasım 2026 - Nisan 2027
    expect(w.totalDays).toBe(30 + 31 + 31 + 28 + 31 + 30);
    expect(w.startKey).toBe('2026-11-01');
    expect(w.endKey).toBe('2027-04-30');
    expect(w.months.map((m) => m.days)).toEqual([30, 31, 31, 28, 31, 30]);
  });
  it('3 ay ileri/geri kaydırırken yıl sınırını geçer', () => {
    expect(shiftWindowStart(2026, 10, 3)).toEqual({ year: 2027, month0: 1 });
    expect(shiftWindowStart(2026, 1, -3)).toEqual({ year: 2025, month0: 10 });
  });
  it('dayNum/keyOfDay gidiş dönüşte aynı günü verir', () => {
    expect(keyOfDay(dayNum('2026-02-28T10:00:00+03:00'))).toBe('2026-02-28');
    expect(dayNum('bozuk')).toBeNaN();
  });
});

describe('placeEvent', () => {
  const w = timelineWindow(2026, 10, 6);
  it('bitiş gününü dahil sayar (tüm gün olayı)', () => {
    const p = placeEvent(ev({ startsAt: '2026-11-09T00:00:00+03:00', endsAt: '2026-11-13T23:59:00+03:00' }), w)!;
    expect(p.leftPct).toBeCloseTo((8 / w.totalDays) * 100, 5);
    expect(p.widthPct).toBeCloseTo((5 / w.totalDays) * 100, 5);
    expect(p.clippedStart || p.clippedEnd).toBe(false);
  });
  it('bitişi olmayan olay tek gün olur', () => {
    const p = placeEvent(ev({ startsAt: '2026-11-01T09:00:00+03:00' }), w)!;
    expect(p.widthPct).toBeCloseTo((1 / w.totalDays) * 100, 5);
    expect(p.leftPct).toBe(0);
  });
  it('pencereden taşanı kırpar ve işaretler; dışındakini atar', () => {
    const a = placeEvent(ev({ startsAt: '2026-10-20T00:00:00+03:00', endsAt: '2026-11-05T23:59:00+03:00' }), w)!;
    expect(a.clippedStart).toBe(true);
    expect(a.leftPct).toBe(0);
    expect(a.widthPct).toBeCloseTo((5 / w.totalDays) * 100, 5);
    const b = placeEvent(ev({ startsAt: '2027-04-20T00:00:00+03:00', endsAt: '2027-05-10T23:59:00+03:00' }), w)!;
    expect(b.clippedEnd).toBe(true);
    expect(b.leftPct + b.widthPct).toBeCloseTo(100, 5);
    expect(placeEvent(ev({ startsAt: '2026-09-01T00:00:00+03:00' }), w)).toBeNull();
    expect(placeEvent(ev({ startsAt: '2027-05-01T00:00:00+03:00' }), w)).toBeNull();
  });
  it('bitişi başlangıçtan önce olan bozuk kaydı tek gün sayar', () => {
    const p = placeEvent(ev({ startsAt: '2026-11-10T00:00:00+03:00', endsAt: '2026-11-02T00:00:00+03:00' }), w)!;
    expect(p.widthPct).toBeCloseTo((1 / w.totalDays) * 100, 5);
  });
});

describe('layoutBox ve packLanes', () => {
  it('dar çubuğa yazı için yer ayırır, sağ kenara taşırmaz', () => {
    const a = layoutBox(10, 1);
    expect(a.occ).toBe(22);
    expect(a.boxLeft).toBe(10);
    expect(a.alignEnd).toBe(false);
    const b = layoutBox(98, 1);
    expect(b.boxLeft).toBe(78);
    expect(b.alignEnd).toBe(true);
    expect(b.bandOffset).toBeCloseTo(((98 - 78) / 22) * 100, 5);
    const wide = layoutBox(20, 40);
    expect(wide.occ).toBe(40);
    expect(wide.bandWidth).toBe(100);
  });
  it('çakışan olayları ayrı alt satırlara koyar, uzak olanı aynı satırda tutar', () => {
    const w = timelineWindow(2026, 10, 6);
    const items = [
      placeEvent(ev({ startsAt: '2026-11-02T00:00:00+03:00', endsAt: '2026-11-20T23:59:00+03:00' }), w)!,
      placeEvent(ev({ startsAt: '2026-11-10T00:00:00+03:00' }), w)!,
      placeEvent(ev({ startsAt: '2027-02-01T00:00:00+03:00' }), w)!,
    ];
    const rows = packLanes(items);
    expect(rows).toHaveLength(2);
    expect(rows[0]).toHaveLength(2);
    expect(rows[1]).toHaveLength(1);
  });
});

describe('buildLanes', () => {
  it('yalnız olayı olan türleri, tür sırasıyla üretir', () => {
    const w = timelineWindow(2026, 10, 6);
    const lanes = buildLanes(
      [
        ev({ kind: 'FINAL', startsAt: '2027-01-11T00:00:00+03:00' }),
        ev({ kind: 'DERS_KAYIT', startsAt: '2026-11-03T00:00:00+03:00' }),
        ev({ kind: 'DERS_KAYIT', startsAt: '2026-11-05T00:00:00+03:00' }),
        ev({ kind: 'VIZE', startsAt: '2025-01-01T00:00:00+03:00' }), // pencere dışı
      ],
      w,
      CALENDAR_KINDS,
    );
    expect(lanes.map((l) => l.kind)).toEqual(['DERS_KAYIT', 'FINAL']);
    expect(lanes[0].count).toBe(2);
  });
});

describe('todayPct', () => {
  const w = timelineWindow(2026, 10, 6);
  it('bugünün sütun ortasını verir', () => {
    expect(todayPct(w, '2026-11-01')).toBeCloseTo((0.5 / w.totalDays) * 100, 5);
    expect(todayPct(w, '2026-11-15')).toBeCloseTo((14.5 / w.totalDays) * 100, 5);
  });
  it('pencere dışındaysa null', () => {
    expect(todayPct(w, '2026-10-31')).toBeNull();
    expect(todayPct(w, '2027-05-01')).toBeNull();
  });
});

describe('summarizeUpcoming', () => {
  const today = '2026-11-10';
  it('süren, sıradaki ve taslak olayları ayırır; geçmişi yok sayar', () => {
    const s = summarizeUpcoming(
      [
        ev({ title: 'Geçmiş', startsAt: '2026-10-01T00:00:00+03:00', endsAt: '2026-10-05T23:59:00+03:00' }),
        ev({ title: 'Sürüyor', startsAt: '2026-11-09T00:00:00+03:00', endsAt: '2026-11-13T23:59:00+03:00' }),
        ev({ title: 'Bugün biter', startsAt: '2026-11-08T00:00:00+03:00', endsAt: '2026-11-10T23:59:00+03:00' }),
        ev({ title: 'Yarın', startsAt: '2026-11-11T00:00:00+03:00', published: false }),
        ev({ title: 'Uzak', startsAt: '2027-03-01T00:00:00+03:00' }),
      ],
      today,
    );
    expect(s.ongoing.map((u) => u.ev.title)).toEqual(['Bugün biter', 'Sürüyor']);
    expect(s.ongoing[0].endsInDays).toBe(0);
    expect(s.ongoing[1].endsInDays).toBe(3);
    expect(s.next.map((u) => [u.ev.title, u.inDays])).toEqual([
      ['Yarın', 1],
      ['Uzak', 111],
    ]);
    expect(s.withinHorizon).toBe(3); // 2 süren + yarın; uzak ufuk dışı
    expect(s.draftSoon).toBe(1);
  });
  it('olay yoksa boş özet verir', () => {
    const s = summarizeUpcoming([], today);
    expect(s).toMatchObject({ ongoing: [], next: [], withinHorizon: 0, draftSoon: 0 });
  });
  it('sıradaki sayısını sınırlar', () => {
    const many = Array.from({ length: 9 }, (_, i) => ev({ startsAt: `2026-11-${String(11 + i).padStart(2, '0')}T00:00:00+03:00` }));
    expect(summarizeUpcoming(many, today, 5).next).toHaveLength(5);
  });
});
