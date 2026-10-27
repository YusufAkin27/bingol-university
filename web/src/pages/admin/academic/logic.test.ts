import { describe, expect, it } from 'vitest';
import type { AcademicEvent } from '../../../api/academic';
import {
  allDayRange,
  announcementState,
  endAfterStart,
  eventsByDay,
  isHttps,
  monthGrid,
  readPercent,
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

  it('https ve bitiş doğrulaması', () => {
    expect(isHttps('https://a.edu.tr/x')).toBe(true);
    expect(isHttps('http://a.edu.tr')).toBe(false);
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

  it('duyuru durumu ve okunma yüzdesi', () => {
    const now = Date.parse('2026-11-01T12:00:00+03:00');
    expect(announcementState({ published: false, publishAt: null, expiresAt: null }, now)).toBe('draft');
    expect(
      announcementState({ published: true, publishAt: '2026-11-02T09:00:00+03:00', expiresAt: null }, now),
    ).toBe('scheduled');
    expect(
      announcementState({ published: true, publishAt: null, expiresAt: '2026-10-01T09:00:00+03:00' }, now),
    ).toBe('expired');
    expect(
      announcementState({ published: true, publishAt: '2026-10-01T09:00:00+03:00', expiresAt: null }, now),
    ).toBe('active');
    expect(readPercent(50, 200)).toBe(25);
    expect(readPercent(5, 0)).toBeNull();
    expect(totalPages(41, 20)).toBe(3);
  });
});
