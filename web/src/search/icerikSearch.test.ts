// Akademik ve içerik sayfalarının yeni bölümleri aramada bulunur (aksansız yazım ve küçük yazım hataları dahil).
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const entries = buildSearchEntries((k: Key) => translate('tr', k));
const searcher = createSearcher(entries);
const topIds = (q: string, n = 5) =>
  searcher
    .search(q)
    .slice(0, n)
    .map((h) => h.item.id);

describe('akademik ve içerik arama girdileri', () => {
  it('çizelge: gantt, zaman çizelgesi, aksansız ve yazım hatalı sorgular', () => {
    expect(topIds('gantt')).toContain('acdCalendar.timeline');
    expect(topIds('zaman cizelgesi')).toContain('acdCalendar.timeline');
    expect(topIds('donem cizelgesi')).toContain('acdCalendar.timeline');
    expect(topIds('cizelgse')).toContain('acdCalendar.timeline'); // yazım hatası
    expect(topIds('bugün çizgisi')[0]).toBe('acdCalendar.timeline');
  });
  it('yaklaşan olaylar: günlük dil', () => {
    expect(topIds('yaklasan olay')).toContain('acdCalendar.upcoming');
    expect(topIds('kaç gün kaldı')).toContain('acdCalendar.upcoming');
    expect(topIds('yaklasn olaylar')).toContain('acdCalendar.upcoming'); // yazım hatası
  });
  it('sınav yoğunluğu', () => {
    expect(topIds('bu hafta sınav')).toContain('acdExams.timeline');
    expect(topIds('sinav yogunlugu')).toContain('acdExams.timeline');
  });
  it('menü kalori grafiği ve eksik uyarısı', () => {
    expect(topIds('kalori grafigi')).toContain('menu.kcalChart');
    expect(topIds('kalori grafgi')).toContain('menu.kcalChart'); // yazım hatası
    expect(topIds('ortalama kalori')).toContain('menu.kcalChart');
    expect(topIds('kalorisiz yemek')).toContain('menu.gaps');
    expect(topIds('fotografsiz gun')).toContain('menu.gaps');
  });
  it('kaynak ızgarası ve haber/birim dağılımı', () => {
    expect(topIds('hangi kaynak bozuk')).toContain('sources.grid');
    expect(topIds('kaynak sagligi', 8)).toContain('sources.grid');
    expect(topIds('fakulte siteleri calisiyor mu', 8)).toContain('sources.grid');
    expect(topIds('kac haber var')).toContain('news.dist');
    expect(topIds('birim dagilimi')).toContain('unitNews.distribution');
  });
  it('girdiler ilgili menü sayfasına ve derin bağlantıya çözülür', () => {
    const e = entries.find((x) => x.id === 'acdCalendar.timeline')!;
    expect(e.pageId).toBe('acdCalendar');
    expect(e.to).toMatch(/#cal-timeline$/);
    const k = entries.find((x) => x.id === 'menu.kcalChart')!;
    expect(k.to).toMatch(/#menu-kcal-chart$/);
  });
});
