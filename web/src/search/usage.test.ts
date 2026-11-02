// Analitik > Kullanım sekmesi arama girdileri: günlük dil, eş anlamlı ve yazım hatalı sorgular doğru bölüme gider.
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const searcher = createSearcher(buildSearchEntries((k: Key) => translate('tr', k)));
const ids = (q: string, n = 8) =>
  searcher
    .search(q)
    .slice(0, n)
    .map((h) => h.item.id);

describe('kullanım istatistikleri araması', () => {
  it('"kullanım" ve yazım hatalı "kulanım" kullanım bölümünü getirir', () => {
    expect(ids('kullanım istatistikleri')).toContain('analytics.usage');
    expect(ids('kulanım')).toEqual(expect.arrayContaining([expect.stringMatching(/^analytics\.usage/)]));
  });
  it('"ekran" ve "sayfa gezinme" en çok gezilen sayfalara gider', () => {
    expect(ids('ekran')).toContain('analytics.usage-screens');
    expect(ids('sayfa gezinme')).toContain('analytics.usage-screens');
  });
  it('"eylem" en çok yapılan eylemlere gider', () => {
    expect(ids('eylem')).toContain('analytics.usage-actions');
  });
  it('"ısı haritası" ve aksansız "isi haritasi" saat yoğunluğuna gider', () => {
    expect(ids('ısı haritası')).toContain('analytics.usage-hourly');
    expect(ids('isi haritasi')).toContain('analytics.usage-hourly');
  });
  it('"akış" ve "nereden nereye" sayfa akışına gider', () => {
    expect(ids('akış')).toContain('analytics.usage-flow');
    expect(ids('nereden nereye')).toContain('analytics.usage-flow');
  });
  it('"özellik benimseme" ve "uygulama sürümü" ilgili bölümleri getirir', () => {
    expect(ids('özellik benimseme')).toContain('analytics.usage-features');
    expect(ids('uygulama sürümü')).toContain('analytics.usage-segments');
  });
});
