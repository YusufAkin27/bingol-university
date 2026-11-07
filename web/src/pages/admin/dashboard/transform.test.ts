import { describe, expect, it } from 'vitest';
import type { SystemOverview } from '../../../api/system';
import { summarizeHealth } from './health';
import { audienceLevels, sharePercent, shiftDate, sumWindow, weekCompare } from './transform';

describe('shiftDate', () => {
  it('ay ve yıl sınırlarını aşar', () => {
    expect(shiftDate('2026-03-01', -1)).toBe('2026-02-28');
    expect(shiftDate('2026-12-31', 1)).toBe('2027-01-01');
    expect(shiftDate('2026-11-01', -7)).toBe('2026-10-25');
  });
});

describe('weekCompare', () => {
  // 2026-11-08 12:00 İstanbul: dün = 11-07 -> bu hafta 11-01..11-07, geçen hafta 10-25..10-31
  const now = new Date('2026-11-08T09:00:00Z');
  const points = Array.from({ length: 20 }, (_, i) => ({ date: shiftDate('2026-10-20', i), value: i + 1 }));

  it('bugünü dışarıda bırakıp 7 günü önceki 7 günle gün gün eşler', () => {
    const w = weekCompare([...points, { date: '2026-11-08', value: 999 }], now);
    expect(w.rows).toHaveLength(7);
    expect(w.rows[0].date).toBe('2026-11-01');
    expect(w.rows[6].date).toBe('2026-11-07');
    // 11-01 = 13. gün (değer 13), 10-25 = 6. gün (değer 6)
    expect(w.rows[0]).toEqual({ date: '2026-11-01', thisWeek: 13, lastWeek: 6 });
    expect(w.thisTotal).toBe(13 + 14 + 15 + 16 + 17 + 18 + 19);
    expect(w.lastTotal).toBe(6 + 7 + 8 + 9 + 10 + 11 + 12);
    expect(w.hasData).toBe(true);
  });

  it('seri boşsa ya da yalnız bir hafta varsa karşılaştırma yok sayılır (uydurma yüzde yok)', () => {
    expect(weekCompare([], now).hasData).toBe(false);
    const onlyThis = [{ date: '2026-11-03', value: 5 }];
    expect(weekCompare(onlyThis, now).hasData).toBe(false);
  });
});

describe('audienceLevels / sharePercent', () => {
  it('kayıtlı > ay > hafta > gün sırasını korur', () => {
    const l = audienceLevels({ totalUsers: 1000, activeUsers: { dau: 50, wau: 200, mau: 500 } });
    expect(l.map((x) => [x.key, x.value])).toEqual([
      ['total', 1000],
      ['month', 500],
      ['week', 200],
      ['day', 50],
    ]);
  });
  it('toplam 0 ise yüzde yok', () => {
    expect(sharePercent(5, 0)).toBeNull();
    expect(sharePercent(1, 3)).toBe(33);
  });
});

describe('sumWindow', () => {
  const pts = [
    { date: '2026-11-01', value: 2 },
    { date: '2026-11-02', value: 3 },
    { date: '2026-11-05', value: 10 },
  ];
  it('pencere içindekileri toplar, pencerede nokta yoksa found=false', () => {
    expect(sumWindow(pts, '2026-11-03', 3)).toEqual({ total: 5, found: true });
    expect(sumWindow(pts, '2026-10-20', 3)).toEqual({ total: 0, found: false });
  });
});

describe('summarizeHealth', () => {
  const ind = (status: string) => ({ status, value: null, threshold: null, message: null });
  const sys = (indicators: Record<string, ReturnType<typeof ind>>): SystemOverview => ({
    generatedAt: '2026-11-01T10:00:00Z',
    overall: 'OK',
    indicators: indicators as SystemOverview['indicators'],
  });

  it('hepsi OK ise iyi', () => {
    const h = summarizeHealth(sys({ db: ind('OK'), redis: ind('OK') }), { NEWS: { maintenance: false }, MENU: { maintenance: false } });
    expect(h.tone).toBe('good');
    expect(h.issues).toEqual([]);
    expect(h.systemKnown).toBe(true);
  });

  it('kritik varsa kötü ve kritik uyarının önünde sıralanır; UNKNOWN sorun sayılmaz', () => {
    const h = summarizeHealth(sys({ a: ind('WARN'), db: ind('CRIT'), x: ind('UNKNOWN') }), {
      NEWS: { maintenance: true },
    });
    expect(h.tone).toBe('bad');
    expect(h.issues.map((i) => i.id)).toEqual(['db', 'a', 'source:NEWS']);
  });

  it('yalnız kaynak bakımı varsa uyarı; sistem verisi yoksa systemKnown=false', () => {
    const h = summarizeHealth(undefined, { MENU: { maintenance: true } });
    expect(h.tone).toBe('warn');
    expect(h.systemKnown).toBe(false);
  });
});
