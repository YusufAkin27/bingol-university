import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { adminNav } from '../layouts/adminNav';
import { paths } from '../paths';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';
import { pageInfo } from './pageInfo';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const t = (k: Key) => translate('tr', k);
const entries = buildSearchEntries(t);
const searcher = createSearcher(entries);

describe('buildSearchEntries', () => {
  it('her menü öğesi için bir sayfa girdisi üretir (yol, izin, simge, grup kırıntısı)', () => {
    for (const g of adminNav) {
      for (const i of g.items) {
        const e = entries.find((x) => x.id === `page.${i.id}`);
        expect(e, i.id).toBeTruthy();
        expect(e!.path).toBe(i.to);
        expect(e!.perm).toBe(i.perm);
        expect(e!.crumbs).toEqual([t(g.labelKey)]);
        expect(e!.title).toBe(t(i.labelKey));
      }
    }
  });

  it('her menü sayfasının açıklaması ve anahtar kelimeleri var', () => {
    const missing = adminNav.flatMap((g) => g.items.map((i) => i.id)).filter((id) => !pageInfo[id]);
    expect(missing).toEqual([]);
    for (const [id, p] of Object.entries(pageInfo)) {
      expect(p.d.length, id).toBeGreaterThan(10);
      expect(p.k.length, id).toBeGreaterThanOrEqual(3);
    }
  });

  it('girdiler yolu, izni, kırıntıyı ve derin bağlantıyı menü öğesinden alır', () => {
    const m = entries.find((e) => e.id === 'settings.maintenance_mode')!;
    expect(m.to).toBe(`${paths.admin.settings}#maintenance_mode`);
    expect(m.perm).toBe('settings.read');
    expect(m.crumbs).toEqual(['Sistem', 'Ayarlar', 'Bakım modu']);
    const a = entries.find((e) => e.id === 'settings.maintenance_save')!;
    expect(a.perm).toBe('settings.write'); // izin geçersiz kılma
    const n = entries.find((e) => e.id === 'campaigns.new')!;
    expect(n.path).toBe(paths.admin.campaignNew); // yol geçersiz kılma
  });
});

describe('gerçek dizinde arama', () => {
  const top = (q: string) => searcher.search(q)[0]?.item;
  it('"bakım modu" → Ayarlar sayfasındaki bakım modu alanı', () => {
    expect(top('bakım modu')?.id).toBe('settings.maintenance_mode');
    expect(top('bakim modu')?.id).toBe('settings.maintenance_mode');
    expect(top('bakım modu')?.to).toBe(`${paths.admin.settings}#maintenance_mode`);
  });
  it('günlük dil ve eş anlamlılar', () => {
    expect(top('siteyi kapat')?.id).toBe('settings.maintenance_mode');
    expect(searcher.search('zorunlu güncelleme').slice(0, 8).map((h) => h.item.pageId)).toContain('appVersions');
    expect(searcher.search('google play').slice(0, 3).map((h) => h.item.id)).toContain('settings.store_url_android');
    expect(top('küfür')?.pageId).toBe('profanity');
  });
  it('sayfa adları', () => {
    expect(top('ayarlar')?.id).toBe('page.settings');
    expect(top('itirazlar')?.id).toBe('page.appeals');
    expect(top('gonderiler')?.id).toBe('page.posts');
  });
  it('RBAC: izni olmayan girdi sonuçta ve önerilerde görünmez', () => {
    const allowed = (perm?: string) => perm !== 'settings.read' && perm !== 'settings.write';
    const r = searcher.search('bakım modu', { filter: (e) => allowed(e.perm) });
    expect(r.find((h) => h.item.id === 'settings.maintenance_mode')).toBeUndefined();
    expect(searcher.suggest('bakim mdu', { filter: (e) => allowed(e.perm) })).not.toBe('bakım modu');
  });
  it('1000+ girdi büyüklüğünde bile hızlı (gerçek girdiler x10)', () => {
    const many = createSearcher(
      Array.from({ length: 10 }, (_, k) => entries.map((e) => ({ ...e, id: `${e.id}.${k}` }))).flat(),
    );
    for (const q of ['bakim modu', 'zorunlu guncelleme', 'kampnya']) many.search(q);
    let best = Infinity;
    for (let i = 0; i < 5; i++) {
      const a = performance.now();
      many.search('bakm modu');
      best = Math.min(best, performance.now() - a);
    }
    expect(best, `${many.size} girdi, en iyi süre ${best.toFixed(1)} ms`).toBeLessThan(30);
  });
});
