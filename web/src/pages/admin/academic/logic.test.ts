import { describe, expect, it } from 'vitest';
import type { AcademicEvent } from '../../../api/academic';
import {
  allDayRange,
  endAfterStart,
  eventsByDay,
  monthGrid,
  shiftMonth,
  summarizeImport,
  toDateTimeInput,
  totalPages,
} from './logic';

describe('akademik mantık', () => {
  it('tarih dönüşümleri', () => {
    expect(toDateTimeInput('2026-11-02T10:00:00+03:00')).toBe('2026-11-02T10:00');
    expect(toDateTimeInput(null)).toBe('');
    expect(allDayRange('2026-11-09', '2026-11-13')).toEqual({
      startsAt: '2026-11-09T00:00',
      endsAt: '2026-11-13T23:59',
    });
    expect(allDayRange('2026-11-09', '').endsAt).toBeNull();
  });

  it('bitiş doğrulaması', () => {
    expect(endAfterStart('2026-11-02T10:00', '2026-11-02T09:00')).toBe(false);
    expect(endAfterStart('2026-11-02T10:00', '')).toBe(true);
  });

  it('içe aktarma satırlarını sayar, yorum ve boş satırı atlar', () => {
    const r = summarizeImport('# yorum\n\nVIZE;A;2026-11-09\r\nFINAL;B;2026-12-01');
    expect(r).toEqual({ lines: 2, tooMany: false });
    expect(summarizeImport('x\n'.repeat(201)).tooMany).toBe(true);
  });

  it('ay ızgarası Pazartesi başlar', () => {
    const weeks = monthGrid(2026, 10); // Kasım 2026, 1 Kasım Pazar
    expect(weeks[0][0].date).toBe('2026-10-26');
    expect(weeks[0][6]).toEqual({ date: '2026-11-01', day: 1, inMonth: true });
    expect(weeks.every((w) => w.length === 7)).toBe(true);
    expect(weeks[weeks.length - 1].some((c) => c.date === '2026-11-30')).toBe(true);
  });

  it('aralık olayı kapsadığı her güne düşer', () => {
    const ev = {
      id: 1,
      startsAt: '2026-11-09T00:00:00+03:00',
      endsAt: '2026-11-11T23:59:00+03:00',
    } as AcademicEvent;
    const map = eventsByDay([ev]);
    expect([...map.keys()]).toEqual(['2026-11-09', '2026-11-10', '2026-11-11']);
  });

  it('ay kaydırma yıl sınırını aşar', () => {
    expect(shiftMonth(2026, 11, 1)).toEqual({ year: 2027, month0: 0 });
    expect(shiftMonth(2026, 0, -1)).toEqual({ year: 2025, month0: 11 });
  });

  it('sayfa sayısı', () => {
    expect(totalPages(41, 20)).toBe(3);
  });
});
