// Yaptırım sayfalarının arama dizini: günlük söyleyişler ve yazım hataları doğru sayfayı getirmeli.
import { describe, expect, it } from 'vitest';
import { translate } from '../../../i18n';
import { buildSearchEntries } from '../../../search/build';
import { createSearcher } from '../../../search/engine';

const entries = buildSearchEntries((k) => translate('tr', k));
const searcher = createSearcher(entries);
const pagesFor = (q: string): string[] => [...new Set(searcher.search(q, { limit: 40 }).map((h) => h.item.pageId))];

describe('yaptırım sayfaları araması', () => {
  it.each([
    ['itiraz', 'appeals'],
    ['itirz', 'appeals'], // yazım hatası
    ['toplu reddet', 'appeals'],
    ['aski onerisi', 'suspensions'], // aksansız
    ['askıya al', 'suspensions'],
    ['erisim engeli', 'accessBans'],
    ['erişim engli', 'accessBans'], // yazım hatası
    ['süresi dolan engel', 'accessBans'],
    ['ihlal', 'strikes'],
    ['gizlenen icerik', 'hiddenContent'],
    ['yasakli kelime', 'profanity'],
    ['yasaklı kelim', 'profanity'], // yazım hatası
    ['kufur', 'profanity'],
    ['yasakli gorsel', 'blocklist'],
    ['hazir gerekce', 'reasonTemplates'],
  ])('"%s" yazınca %s sayfası gelir', (q, page) => {
    expect(pagesFor(q)).toContain(page);
  });

  it('alt başlıklar derin bağlantıyla bulunur', () => {
    const anchors = (q: string) => searcher.search(q, { limit: 40 }).map((h) => h.item.anchor);
    expect(anchors('kuyruk yaşı')).toEqual(expect.arrayContaining(['apl-age']));
    expect(anchors('klavye kısayolu')).toEqual(expect.arrayContaining(['apl-keys']));
    expect(anchors('engel temizliği')).toEqual(expect.arrayContaining(['ab-health']));
    expect(anchors('silinmeye yakın')).toEqual(expect.arrayContaining(['hidden-summary']));
    expect(anchors('çeviri eksik')).toEqual(expect.arrayContaining(['tpl-summary']));
  });

  it('yeni girdilerin hepsi geçerli sayfaya bağlıdır', () => {
    const mine = entries.filter((e) =>
      ['appeals', 'suspensions', 'accessBans', 'strikes', 'hiddenContent', 'reasonTemplates', 'profanity', 'blocklist'].includes(e.pageId),
    );
    expect(mine.length).toBeGreaterThan(40);
    for (const e of mine) expect(e.path).toMatch(/^\/admin\//);
  });
});
