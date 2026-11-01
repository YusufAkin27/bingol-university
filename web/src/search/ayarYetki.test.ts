// Sistem2 arama girdileri: yeni bölümler günlük dille ve yazım hatasıyla bulunur.
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const searcher = createSearcher(buildSearchEntries((k: Key) => translate('tr', k)));
const ids = (q: string) => searcher.search(q).map((h) => h.item.id);

describe('Ayarlar ve yetki arama girdileri', () => {
  it('"ısı haritası" ve aksansız/yanlış yazımı yetki özetini getirir', () => {
    expect(ids('ısı haritası')).toContain('roles.heatmap');
    expect(ids('isi haritasi')).toContain('roles.heatmap');
    expect(ids('isi haritsi')).toContain('roles.heatmap');
    expect(ids('moderatör neye yetkili')).toContain('roles.heatmap');
  });

  it('"zaman çizelgesi" denetim görünümünü getirir (yazım hatası dahil)', () => {
    expect(ids('zaman çizelgesi')).toContain('audit.view-toggle');
    expect(ids('zman cizelgesi')).toContain('audit.view-toggle');
    expect(ids('olay akışı')).toContain('audit.view-toggle');
  });

  it('denetim özeti ve hızlı süzgeçler', () => {
    expect(ids('en yoğun saat')).toContain('audit.summary');
    expect(ids('reddedilen işlemler')).toContain('audit.quick-filters');
    expect(ids('rededilen')).toContain('audit.quick-filters');
    expect(ids('silme işlemleri')).toContain('audit.quick-filters');
  });

  it('ayar arama kutusu, son değişiklikler ve sürüm grafiği', () => {
    expect(ids('ayar ara')).toContain('settings.search-box');
    expect(ids('ayarı kim değiştirdi')).toContain('settings.recent-changes');
    expect(ids('eski sürüm kullanan')).toContain('appVersions.versions-chart');
    expect(ids('sürüm grafiği')).toContain('appVersions.versions-chart');
  });
});
