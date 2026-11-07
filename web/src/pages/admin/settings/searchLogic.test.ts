import { describe, expect, it } from 'vitest';
import { registeredEntries } from '../../../search/registry';
import { createSettingsSearcher, searchSettings, settingsItems, valueExcerpt } from './searchLogic';

const searcher = createSettingsSearcher(settingsItems(registeredEntries));
const top = (q: string) => searchSettings(searcher, q).map((r) => r.anchor);

describe('ayarlar içi arama', () => {
  it('kutunun kendisi ve eylemler sonuç listesine girmez', () => {
    const items = settingsItems(registeredEntries);
    expect(items.some((i) => i.anchor.startsWith('settings-'))).toBe(false);
    expect(items.some((i) => i.kind === 'action')).toBe(false);
    expect(items.length).toBeGreaterThan(20);
  });

  it('ayar adıyla ve günlük sözcükle bulur', () => {
    expect(top('bakım modu')[0]).toBe('maintenance_mode');
    expect(top('siteyi kapat')).toContain('maintenance_mode');
    expect(top('banner')).toContain('banner_url');
    expect(top('instagram')[0]).toBe('instagram');
  });

  it('yazım hatasına ve aksansız yazıma dayanıklıdır', () => {
    expect(top('bakim modu')[0]).toBe('maintenance_mode');
    expect(top('bakm modu')).toContain('maintenance_mode');
    expect(top('isntagram')).toContain('instagram');
  });

  it('boş sorgu ve eşleşmeyen sorgu boş liste verir', () => {
    expect(top('   ')).toEqual([]);
    expect(top('zzzzqqqq')).toEqual([]);
  });

  it('aynı anchor tek sonuç olur, en çok 8 sonuç', () => {
    const r = searchSettings(searcher, 'ayar');
    expect(new Set(r.map((x) => x.anchor)).size).toBe(r.length);
    expect(r.length).toBeLessThanOrEqual(8);
  });
});

describe('değer özeti', () => {
  it('boşlukları sadeleştirir, uzun metni kırpar', () => {
    expect(valueExcerpt('  a   b ')).toBe('a b');
    expect(valueExcerpt(undefined)).toBe('');
    expect(valueExcerpt('x'.repeat(80), 10)).toBe(`${'x'.repeat(9)}…`);
  });
});
