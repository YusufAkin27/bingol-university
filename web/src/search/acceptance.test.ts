/**
 * PANEL-ENT arama kabul testi: kullanıcının istediği sorgular gerçek (birleşik) dizinde çalıştırılır.
 * Her sorgu için sonuç sayısı ve ilk 3 sonuç (başlık + yol) `VITE_ACCEPT_LOG=1` ile konsola yazılır.
 */
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

const entries = buildSearchEntries((k) => translate('tr', k));
const searcher = createSearcher(entries);

function run(q: string, limit = 80) {
  const hits = searcher.search(q, { limit });
  const rows = hits.map((h) => ({
    id: h.item.id,
    page: h.item.pageId,
    title: h.item.title,
    path: [...h.item.crumbs, h.item.title].join(' > '),
  }));
  if (import.meta.env.VITE_ACCEPT_LOG) {
    const top = rows
      .slice(0, 3)
      .map((r, i) => `${i + 1}) ${r.path}`)
      .join(' | ');
    console.log(`ARAMA "${q}": ${rows.length} sonuc; ilk 3: ${top}`);
  }
  return rows;
}
const pagesOf = (rows: { page: string }[]) => [...new Set(rows.map((r) => r.page))];

describe('kabul: "mesaj"', () => {
  it('sohbet akışı + mesaj erişim denetimi + kullanıcı mesajları + mesaj içeren diğer bölümler', () => {
    const rows = run('mesaj');
    const pages = pagesOf(rows);
    expect(pages.slice(0, 8)).toEqual(expect.arrayContaining(['chatFeed', 'messageAccess']));
    expect(rows.some((r) => /Kullanıcı mesajlarını görüntüle/.test(r.title))).toBe(true);
    // mesaj içeren başka bölümler de listelenir (kampanya / duyuru / destek yazışması / şifreleme)
    expect(pages).toEqual(expect.arrayContaining(['crypto', 'campaigns', 'tickets']));
    // alt başlık eşleşmesi: bölüm sonucu üst sayfa + bölüm yolunu gösterir
    const section = rows.find((r) => r.path.split(' > ').length >= 3);
    expect(section).toBeTruthy();
  });

  it.each(['meaj', 'mesjalar', 'Mesajlar', 'MESAJ', 'mesaj'])('"%s" aynı ilgili sayfaları getirir', (q) => {
    const pages = pagesOf(run(q)).slice(0, 8);
    expect(pages).toEqual(expect.arrayContaining(['chatFeed', 'messageAccess']));
    const set = new Set(pagesOf(run(q)).slice(0, 8));
    const ref = new Set(pagesOf(run('mesaj')).slice(0, 8));
    // yazım hatalı sorgunun ilk 8 sayfasının çoğu doğru yazılışla örtüşmeli
    const overlap = [...set].filter((p) => ref.has(p)).length;
    expect(overlap).toBeGreaterThanOrEqual(3);
  });
});

describe('kabul: diğer sorgular', () => {
  it('"kulanıcı" -> Kullanıcılar ilk sonuç', () => {
    const rows = run('kulanıcı');
    expect(rows[0].page).toBe('users');
    expect(pagesOf(rows).slice(0, 3)).toContain('users');
  });
  it('"yedek" -> Yedekleme (Google Drive)', () => {
    const rows = run('yedek');
    expect(rows[0].page).toBe('backup');
    expect(rows[0].title).toMatch(/Yedekleme/);
  });
  it.each(['iki faktör', '2fa', 'iki faktorlu', '2 faktör', 'ikili doğrulama'])('"%s" -> İki faktörlü doğrulama', (q) => {
    const rows = run(q);
    expect(pagesOf(rows).slice(0, 2)).toContain('twoFactor');
  });
  it('"duyuru" -> akademik/bölüm duyuruları sayfaları', () => {
    const rows = run('duyuru');
    const pages = pagesOf(rows);
    expect(pages.slice(0, 6)).toEqual(expect.arrayContaining(['acdAnnouncements']));
    expect(pages).toEqual(expect.arrayContaining(['news', 'unitNews']));
  });
  it('"kalori" -> Yemek menüsü', () => {
    const rows = run('kalori');
    expect(pagesOf(rows).slice(0, 2)).toContain('menu');
  });
  it('sonuç satırı eşleşen bölümü ve yolu gösterir', () => {
    for (const q of ['kalori', 'yedek', '2fa', 'mesaj']) {
      for (const r of run(q, 10)) expect(r.path.includes(' > ') || r.id.startsWith('page.'), `${q}: ${r.id}`).toBe(true);
    }
  });
});
