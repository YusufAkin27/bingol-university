import { describe, expect, it } from 'vitest';
import { menuGaps } from './menuLogic';

describe('menuGaps', () => {
  it('fotoğrafsız günleri ve kalorisiz yemekleri (aynı ad bir kez) bulur', () => {
    const gaps = menuGaps([
      {
        date: '2026-12-01',
        items: ['Mercimek Çorbası', 'Browni'],
        imageUrl: null,
        dishes: [
          { name: 'Mercimek Çorbası', kcal: 150 },
          { name: 'Browni', kcal: null },
        ],
      },
      {
        date: '2026-12-02',
        items: ['BROWNİ', 'Salata'],
        imageUrl: '/files/covers/a.jpg',
        dishes: [
          { name: 'BROWNİ', kcal: null },
          { name: 'Salata', kcal: null },
        ],
      },
    ]);
    expect(gaps.noImage).toEqual(['2026-12-01']);
    expect(gaps.noKcal.map((g) => g.name)).toEqual(['Browni', 'Salata']);
    expect(gaps.noKcal[0].days).toBe(2);
  });

  it('eksik yoksa boş döner; dishes yoksa tüm yemekler kalorisiz sayılır', () => {
    expect(menuGaps([{ date: '2026-12-01', items: ['A'], imageUrl: '/x.jpg', dishes: [{ name: 'A', kcal: 0 }] }])).toEqual({
      noImage: [],
      noKcal: [],
    });
    expect(menuGaps([{ date: '2026-12-01', items: ['A'], imageUrl: '/x.jpg' }]).noKcal).toHaveLength(1);
  });
});
