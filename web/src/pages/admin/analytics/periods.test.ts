import { describe, expect, it } from 'vitest';
import { clampRange, mergePrevious, previousRange, rangeDays, seriesStats } from './transform';

describe('rangeDays / previousRange', () => {
  it('uçlar dahil gün sayısını verir; geçersiz tarihte 0', () => {
    expect(rangeDays({ from: '2026-10-03', to: '2026-11-01' })).toBe(30);
    expect(rangeDays({ from: '2026-11-01', to: '2026-11-01' })).toBe(1);
    expect(rangeDays({ from: 'x', to: '2026-11-01' })).toBe(0);
    expect(rangeDays({})).toBe(0);
  });
  it('aynı uzunlukta hemen önceki dönemi verir', () => {
    expect(previousRange({ from: '2026-10-03', to: '2026-11-01' })).toEqual({ from: '2026-09-03', to: '2026-10-02' });
    expect(previousRange({ from: '2026-11-01', to: '2026-11-01' })).toEqual({ from: '2026-10-31', to: '2026-10-31' });
    expect(previousRange({})).toBeNull();
  });
});

describe('clampRange', () => {
  it('ters aralığı çevirir', () => {
    expect(clampRange('2026-11-01', '2026-10-01')).toEqual({ from: '2026-10-01', to: '2026-11-01', swapped: true, clipped: false });
  });
  it('366 günden uzun aralığın başlangıcını ileri alır', () => {
    const r = clampRange('2020-01-01', '2026-11-01');
    expect(r.clipped).toBe(true);
    expect(rangeDays(r)).toBe(366);
    expect(r.to).toBe('2026-11-01');
  });
  it('normal aralığa dokunmaz', () => {
    expect(clampRange('2026-10-03', '2026-11-01')).toEqual({ from: '2026-10-03', to: '2026-11-01', swapped: false, clipped: false });
  });
});

describe('mergePrevious', () => {
  const cur = [
    { date: '2026-11-01', value: 5 },
    { date: '2026-11-02', value: 7 },
  ];
  it('önceki dönemi gün sırasıyla eşler; eksik gün undefined kalır', () => {
    const rows = mergePrevious(cur, [{ date: '2026-10-30', value: 4 }], (p) => p.value);
    expect(rows.map((r) => r.prev)).toEqual([4, undefined]);
    expect(rows[1].value).toBe(7);
  });
  it('önceki dönem yoksa prev undefined', () => {
    expect(mergePrevious(cur, undefined, (p) => p.value).every((r) => r.prev === undefined)).toBe(true);
  });
});

describe('seriesStats', () => {
  it('toplam, yuvarlanmış ortalama ve en yoğun günü verir', () => {
    expect(seriesStats([2, 9, 4])).toEqual({ total: 15, avg: 5, peakIndex: 1, peak: 9 });
  });
  it('boş seride peakIndex -1', () => {
    expect(seriesStats([])).toEqual({ total: 0, avg: 0, peakIndex: -1, peak: 0 });
  });
});
