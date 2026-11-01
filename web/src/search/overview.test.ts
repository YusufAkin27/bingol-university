// Genel bakış + Analitik arama girdileri: günlük dil, aksansız yazım ve yazım hatası.
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { buildSearchEntries } from './build';
import { createSearcher } from './engine';

type Key = Parameters<typeof buildSearchEntries>[0] extends (k: infer K) => string ? K : never;
const entries = buildSearchEntries((k: Key) => translate('tr', k));
const searcher = createSearcher(entries);
const ids = (q: string) => searcher.search(q).map((h) => h.item.id);

describe('Genel bakış / Analitik arama dizini', () => {
  it('"her şey yolunda mı" ve aksansız yazımı sağlık şeridini getirir', () => {
    expect(ids('her şey yolunda mı').slice(0, 3)).toContain('dashboard.health');
    expect(ids('her sey yolunda mi')).toContain('dashboard.health');
    expect(ids('sistem sagligi')).toContain('dashboard.health');
  });

  it('"mesaj" yazınca günlük etkileşim (mesaj) bölümü gelir; "meaj" yazım hatası da getirir', () => {
    expect(ids('mesaj')).toContain('analytics.daily');
    expect(ids('meaj')).toContain('analytics.daily');
    expect(ids('yazışma')).toContain('analytics.daily');
  });

  it('karşılaştırma anahtarı ve yazım hatası', () => {
    expect(ids('karşılaştır')).toContain('analytics.compareToggle');
    expect(ids('karsilastir')).toContain('analytics.compareToggle');
    expect(ids('karşılştır')).toContain('analytics.compareToggle'); // harf eksik
    expect(ids('geçen haftaya göre')).toContain('analytics.compareToggle');
  });

  it('kitle, hafta karşılaştırması ve destek özeti bulunur', () => {
    expect(ids('aylık aktif')).toContain('dashboard.audience');
    expect(ids('geçen hafta')).toContain('dashboard.week');
    expect(ids('ilk yanıt süresi')).toContain('analytics.support');
    expect(ids('kümülatif')).toContain('analytics.growthCum');
  });

  it('girdiler derin bağlantı (anchor) taşır', () => {
    const h = entries.find((e) => e.id === 'dashboard.health');
    expect(h?.to).toMatch(/#dash-health$/);
    const c = entries.find((e) => e.id === 'analytics.compareToggle');
    expect(c?.to).toMatch(/#anl-compare-toggle$/);
  });
});
