/**
 * Gerçek dizinde (menü + tüm sayfa girdileri) uçtan uca arama beklentileri: yönetici "mesaj" yazınca mesaj içeren
 * tüm ilgili sayfalar gelir; yazım hatası, Türkçe karakter eksikliği, ek ve eş anlamlı farkı sonucu bozmaz; yanıt < 100 ms.
 */
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

const entries = buildSearchEntries((k) => translate('tr', k));

/** Soğuk (ilk) çağrı süresi dahil: her test kendi arayıcısını kurar. */
function run(q: string, limit = 60) {
  const s = createSearcher(entries);
  const t0 = performance.now();
  const hits = s.search(q, { limit });
  return { hits, ms: performance.now() - t0, ids: hits.map((h) => h.item.id) };
}

const pageOf = (ids: string[]) => ids.filter((i) => i.startsWith('page.')).map((i) => i.slice(5));

describe('"mesaj" araması: mesaj içeren tüm ilgili sayfalar', () => {
  const MESSAGE_PAGES = ['messageAccess', 'chatFeed', 'crypto'];
  const RELATED_PAGES = ['campaigns', 'tickets'];

  it('sohbet akışı, mesaj erişim denetimi ve sohbet şifreleme/kullanıcı mesajları ilk sayfalardadır', () => {
    const { ids } = run('mesaj');
    const pages = pageOf(ids);
    for (const p of MESSAGE_PAGES) expect(pages.slice(0, 8), `${p} ilk 8 sayfada olmalı`).toContain(p);
    // "Kullanıcı mesajlarını görüntüle" bölümü (kullanıcı mesajları) sonuçlarda
    expect(ids.some((i) => /message|crypto/i.test(i) || i.includes('user'))).toBe(true);
    expect(run('mesaj').hits.some((h) => /Kullanıcı mesajlarını görüntüle/.test(h.item.title))).toBe(true);
  });

  it('kampanya, duyuru ve destek yazışması gibi mesaj içeren sayfalar da listelenir (doğrudan eşleşmelerin ardından)', () => {
    const { ids } = run('mesaj', 120);
    const pages = pageOf(ids);
    for (const p of RELATED_PAGES) expect(pages, `${p} listelenmeli`).toContain(p);
    const firstRelated = Math.min(...RELATED_PAGES.map((p) => pages.indexOf(p)));
    const lastDirect = Math.max(...MESSAGE_PAGES.map((p) => pages.indexOf(p)));
    expect(lastDirect).toBeLessThan(firstRelated);
  });

  it('her sonuçta bölüm/yol (kırıntı) vardır; bölüm sonuçları sayfanın altında adlandırılır', () => {
    const { hits } = run('mesaj');
    for (const h of hits) expect(h.item.crumbs.length, h.item.id).toBeGreaterThanOrEqual(1);
    const section = hits.find((h) => h.item.kind === 'section' && /mesaj/i.test(h.item.title));
    expect(section?.item.crumbs.length).toBeGreaterThanOrEqual(2);
  });

  it.each(['meaj', 'mesjalar', 'mesajlr', 'msajlar', 'mesaaj', 'mesagelar', 'MESAJLAR', 'Mesajlar'])(
    'yazım hatası/büyük harf: "%s" yine mesaj sayfalarını getirir',
    (q) => {
      const pages = pageOf(run(q).ids);
      expect(pages.slice(0, 6)).toContain('messageAccess');
      expect(pages.slice(0, 6)).toContain('chatFeed');
    },
  );

  it.each(['sohbet', 'sohbte', 'dm', 'yazisma', 'yazışma', 'mesajlasma', 'ileti'])('eş anlamlı "%s" mesaj sayfalarına götürür', (q) => {
    const pages = pageOf(run(q).ids);
    expect(pages.slice(0, 5)).toContain('chatFeed');
    expect(pages).toContain('messageAccess');
  });

  it('çok sözcüklü: "kullanıcı mesajları" ve yazım hatalısı "kulanıcı mesjları" aynı bölümü ilk sıraya koyar', () => {
    for (const q of ['kullanıcı mesajları', 'kullanici mesajlari', 'kulanıcı mesjları']) {
      const first = run(q).hits[0];
      expect(first.item.title, q).toMatch(/Kullanıcı mesajlarını görüntüle/);
    }
  });
});

describe('Türkçe karakter eksikliği ve yazım hatası', () => {
  const same: [string, string][] = [
    ['sikayet', 'şikâyet'],
    ['sifre', 'şifre'],
    ['kulup', 'kulüp'],
    ['gonderi', 'gönderi'],
    ['cokme', 'çökme'],
    ['ogrenci', 'öğrenci'],
    ['kullanici', 'kullanıcı'],
    ['guncelleme', 'güncelleme'],
  ];
  it.each(same)('"%s" ile "%s" aynı ilk sonucu verir', (a, b) => {
    expect(run(a).ids[0]).toBe(run(b).ids[0]);
    expect(run(a).ids.slice(0, 5)).toEqual(run(b).ids.slice(0, 5));
  });

  const typos: [string, string][] = [
    ['kulanıcı', 'users'],
    ['kullnaıcı', 'users'],
    ['bildrim', 'campaigns'],
    ['kampnya', 'campaigns'],
    ['yedekelme', 'backup'],
    ['sikayetler', 'reports'],
    ['etkinlk', 'events'],
    ['anktler', 'polls'],
    ['ayralar', 'settings'],
  ];
  it.each(typos)('yazım hatası "%s" → %s sayfası ilk 6 sayfada', (q, page) => {
    expect(pageOf(run(q).ids).slice(0, 6)).toContain(page);
  });
});

describe('sıralama ve doğruluk', () => {
  it('tam başlık eşleşmesi en üsttedir ("Ayarlar" → Ayarlar sayfası)', () => {
    expect(run('ayarlar').ids[0]).toBe('page.settings');
    expect(run('kampanyalar').ids[0]).toBe('page.campaigns');
  });
  it('"bakım modu" ayarı en üstte, günlük dil ifadeleri de bulur', () => {
    expect(run('bakım modu').hits[0].item.title).toBe('Bakım modu');
    expect(run('siteyi kapat').ids.some((i) => i.includes('maintenance'))).toBe(true);
  });
  it('"yedek" yedekleme sayfasını, "ban" erişim engellerini getirir (bant gürültüsü yok)', () => {
    expect(run('yedek').ids[0]).toBe('page.backup');
    expect(pageOf(run('ban').ids).slice(0, 3)).toContain('accessBans');
  });
  it('anlamsız sorgu sonuç vermez', () => {
    expect(run('qqqqqqqq').hits).toEqual([]);
    expect(run('xyzxyz mesaj').hits).toEqual([]);
  });
});

describe('başarım (100 ms altı)', () => {
  const queries = [
    'mesaj',
    'meaj',
    'mesjalar',
    'kullanıcı mesajları',
    'kulanıcı mesjları',
    'duyuru',
    'e-posta',
    'şikayet',
    'yedek',
    'bakım modu',
    'a',
    'ayarlar nasıl yapılır',
    'sdfghjkl',
    'kullanıcı hesabı sil',
  ];
  it('soğuk ilk sorgu bile her durumda 100 ms altındadır', () => {
    const slow = queries.map((q) => ({ q, ms: run(q).ms })).filter((r) => r.ms >= 100);
    expect(slow).toEqual([]);
  });
  it('ısınmış arayıcıda sorgu başına birkaç ms (en iyi 3 deneme)', () => {
    const s = createSearcher(entries);
    for (const q of queries) s.search(q);
    for (const q of queries) {
      let best = Infinity;
      for (let i = 0; i < 3; i++) {
        const t0 = performance.now();
        s.search(q);
        best = Math.min(best, performance.now() - t0);
      }
      expect(best, q).toBeLessThan(40);
    }
  });
});
