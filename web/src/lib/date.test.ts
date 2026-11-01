import { afterEach, describe, expect, it } from 'vitest';
import { istanbulDate, istanbulDaysAgo, istanbulYesterday, lastDaysIstanbul } from './date';

describe('Europe/Istanbul gün hesabı', () => {
  const origTz = process.env.TZ;
  afterEach(() => {
    if (origTz === undefined) delete process.env.TZ;
    else process.env.TZ = origTz;
  });

  it('gece yarısı sınırında İstanbul gününü kullanır (UTC 22:30 = İstanbul ertesi gün 01:30)', () => {
    const now = new Date('2026-11-01T22:30:00Z');
    expect(istanbulDate(now)).toBe('2026-11-02');
    expect(istanbulYesterday(now)).toBe('2026-11-01');
    expect(lastDaysIstanbul(3, now)).toEqual({ from: '2026-10-31', to: '2026-11-02' });
  });

  it('tarayıcı TR dışı bir saat dilimindeyken de aynı sonucu verir', () => {
    process.env.TZ = 'America/Los_Angeles';
    const now = new Date('2026-11-02T05:00:00Z'); // LA: 1 Kasım 22:00 (yerel gün 1), İstanbul: 2 Kasım 08:00
    expect(now.getDate()).toBe(1); // simülasyonun gerçekten farklı gün verdiğini doğrular
    expect(istanbulDate(now)).toBe('2026-11-02');
    expect(istanbulYesterday(now)).toBe('2026-11-01');
    process.env.TZ = 'Pacific/Kiritimati'; // UTC+14: yerel gün İstanbul'dan ileri
    const later = new Date('2026-11-02T12:00:00Z'); // Kiritimati 3 Kasım 02:00, İstanbul 2 Kasım 15:00
    expect(later.getDate()).toBe(3);
    expect(istanbulYesterday(later)).toBe('2026-11-01');
  });

  it('ay/yıl sınırını doğru geçer', () => {
    const now = new Date('2026-01-01T09:00:00Z');
    expect(istanbulYesterday(now)).toBe('2025-12-31');
    expect(istanbulDaysAgo(29, now)).toBe('2025-12-03');
  });
});
