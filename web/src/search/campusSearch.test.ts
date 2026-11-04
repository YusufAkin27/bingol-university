// Kampüs haritası sayfasının arama dizini girdileri: kritik sorgular (yazım hatası ve aksansız yazım dahil) ve yetki.
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const entries = buildSearchEntries((k: Key) => translate('tr', k));
const searcher = createSearcher(entries);
const ids = (q: string, n = 6) =>
  searcher
    .search(q)
    .slice(0, n)
    .map((h) => h.item.id);

describe('kampüs haritası arama girdileri', () => {
  it('sayfa menüden otomatik üretilir ve harita sorgularında üstte gelir', () => {
    expect(ids('harita')).toContain('page.campus');
    expect(ids('kampüs haritası')[0]).toBe('page.campus');
    expect(ids('kampus haritasi')[0]).toBe('page.campus');
  });

  it('yazım hatası: "harta" haritayı bulur', () => {
    expect(ids('harta')).toContain('page.campus');
  });

  it('bina, yer, konum, sınır, karo sözcükleri ilgili girdileri bulur', () => {
    expect(ids('bina')).toEqual(expect.arrayContaining(['page.campus']));
    expect(ids('yer ekle')).toContain('campus.add');
    expect(ids('konum')).toEqual(expect.arrayContaining(['campus.coords']));
    expect(ids('koordinat')).toContain('campus.coords');
    expect(ids('karo')).toEqual(expect.arrayContaining(['campus.tiles']));
    expect(ids('karo adresi')[0]).toBe('campus.tileUrl');
    expect(ids('sınır')).toContain('campus.boundary');
    expect(ids('sinir')).toContain('campus.boundary'); // aksansız
    expect(ids('zoom')).toContain('campus.zoom');
    expect(ids('openstreetmap')).toEqual(expect.arrayContaining(['campus.tileWarning']));
    expect(ids('geojson')).toContain('campus.footprint');
  });

  it('girdiler kampüs sayfasına ve derin bağlantıya çözülür', () => {
    const e = entries.find((x) => x.id === 'campus.tileUrl')!;
    expect(e.pageId).toBe('campus');
    expect(e.to).toMatch(/\/admin\/campus#cfg-tile-url$/);
    expect(entries.find((x) => x.id === 'campus.add')!.to).toMatch(/#campus-add$/);
  });

  it('yazma girdileri campus.write, diğerleri sayfa izni campus.read ister', () => {
    const resolved = new Map(entries.map((e) => [e.id, e]));
    for (const id of ['campus.add', 'campus.check', 'campus.coords', 'campus.saveConfig', 'campus.footprint']) {
      expect(resolved.get(id)?.perm, id).toBe('campus.write');
    }
    for (const id of ['campus.stats', 'campus.list', 'campus.tiles', 'campus.boundary', 'page.campus']) {
      expect(resolved.get(id)?.perm, id).toBe('campus.read');
    }
  });
});
