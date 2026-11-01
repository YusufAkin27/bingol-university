import { describe, expect, it } from 'vitest';
import { distributionText, newsDistribution } from './newsDist';

const label = (k: string) => ({ HABER: 'Haber', DUYURU: 'Duyuru', ETKINLIK: 'Etkinlik' })[k] ?? k;

describe('newsDistribution', () => {
  it('bilinen türleri sabit sırada verir, sıfırları atar', () => {
    const parts = newsDistribution({ DUYURU: 340, HABER: 120, ETKINLIK: 0 }, label);
    expect(parts.map((p) => [p.key, p.value, p.tone])).toEqual([
      ['HABER', 120, 'info'],
      ['DUYURU', 340, 'warning'],
    ]);
  });
  it('bilinmeyen türü sona nötr ekler; negatifi sıfırlar', () => {
    const parts = newsDistribution({ HABER: 5, DIGER: 2, ZZZ: -4 }, label);
    expect(parts.map((p) => p.key)).toEqual(['HABER', 'DIGER']);
    expect(parts[1].tone).toBe('neutral');
  });
  it('boş yanıtta boş dizi döner', () => {
    expect(newsDistribution({}, label)).toEqual([]);
  });
  it('dökümü büyükten küçüğe yazar', () => {
    const parts = newsDistribution({ HABER: 120, DUYURU: 340, ETKINLIK: 40 }, label);
    expect(distributionText(parts, (n) => String(n))).toBe('Duyuru 340, Haber 120, Etkinlik 40');
  });
});
