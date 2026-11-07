import { describe, expect, it } from 'vitest';
import { kcalSeries } from './kcalChartLogic';

const day = (date: string, kcals: (number | null)[]) => ({
  date,
  items: kcals.map((_, i) => `Yemek ${i}`),
  dishes: kcals.map((kcal, i) => ({ name: `Yemek ${i}`, kcal })),
});

describe('kcalSeries', () => {
  it('günleri tam / eksik / yok olarak ayırır ve yüksekliği orantılar', () => {
    const s = kcalSeries([
      day('2026-11-03', [300, 200]), // 500 tam
      day('2026-11-02', [250, null]), // 250 eksik
      day('2026-11-04', [null, null]), // hiç yok
      day('2026-11-05', [1000]), // 1000 tam
    ]);
    expect(s.bars.map((b) => [b.date, b.state, b.kcal, b.missing])).toEqual([
      ['2026-11-02', 'partial', 250, 1],
      ['2026-11-03', 'full', 500, 0],
      ['2026-11-04', 'none', 0, 2],
      ['2026-11-05', 'full', 1000, 0],
    ]);
    expect(s.bars.map((b) => b.pct)).toEqual([25, 50, 0, 100]);
    expect(s.maxKcal).toBe(1000);
    expect(s.maxBar?.date).toBe('2026-11-05');
    expect(s.avgFull).toBe(750); // yalnız tam günler: (500 + 1000) / 2
  });
  it('kapsamı ve ilk eksik günü verir', () => {
    const s = kcalSeries([day('2026-11-01', [100, 100]), day('2026-11-02', [100, null, null]), day('2026-11-03', [null])]);
    expect(s.dishTotal).toBe(6);
    expect(s.dishKnown).toBe(3);
    expect(s.daysMissing).toBe(2);
    expect(s.firstMissingDate).toBe('2026-11-02');
  });
  it('hiç kalori yoksa maksimum yok, ortalama null; menüsüz gün eksik sayılmaz', () => {
    const s = kcalSeries([day('2026-11-01', [null]), { date: '2026-11-02', items: [] }]);
    expect(s.maxBar).toBeNull();
    expect(s.avgFull).toBeNull();
    expect(s.daysMissing).toBe(1);
    expect(s.bars[1]).toMatchObject({ state: 'none', dishes: 0, missing: 0 });
  });
  it('eski yanıtta (dishes yok) tüm yemekleri kalorisiz sayar', () => {
    const s = kcalSeries([{ date: '2026-11-01', items: ['A', 'B'] }]);
    expect(s.bars[0]).toMatchObject({ state: 'none', missing: 2 });
  });
});
