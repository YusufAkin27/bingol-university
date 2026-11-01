import { describe, expect, it } from 'vitest';
import { translate } from '../../../i18n';
import { eventTiming, fillLabel, filterEvents, relativeStart } from './lib';

const NOW = new Date('2026-10-23T12:00:00Z');

describe('etkinlik doluluk yazısı', () => {
  const t = (k: Parameters<typeof translate>[1], p?: Parameters<typeof translate>[2]) => translate('tr', k, p);
  const nf = (n: number) => String(n);
  it('normal doluluk yüzdesi yazılır', () => {
    expect(fillLabel(t, nf, 94, 100)).toBe('94 / 100 kişi (%94 dolu)');
    expect(fillLabel(t, nf, 100, 100)).toBe('100 / 100 kişi (%100 dolu)');
  });
  it('kontenjan aşılınca %100 üstü yazılmaz, açık metin gösterilir', () => {
    const text = fillLabel(t, nf, 125, 100);
    expect(text).toBe('125 / 100 kişi (kontenjan aşıldı: 25 kişi fazla)');
    expect(text).not.toMatch(/%12/);
  });
});

describe('etkinlik zamanlama vurgusu', () => {
  it('geçmiş / yakında / sonra', () => {
    expect(eventTiming('2026-10-23T11:00:00Z', NOW)).toBe('past');
    expect(eventTiming('2026-10-23T13:00:00Z', NOW)).toBe('soon');
    expect(eventTiming('2026-10-25T11:59:00Z', NOW)).toBe('soon');
    expect(eventTiming('2026-10-25T12:01:00Z', NOW)).toBe('later');
    expect(eventTiming('bozuk', NOW)).toBe('later');
  });
  it('göreli süre yazısı', () => {
    expect(relativeStart('2026-10-23T15:00:00Z', 'en', NOW)).toBe('in 3 hours');
    expect(relativeStart('2026-10-23T12:30:00Z', 'en', NOW)).toBe('in 30 minutes');
  });
});

describe('etkinlik süzgeci', () => {
  const base = { location: null, communityName: null, organizerName: null };
  const items = [
    { ...base, title: 'Kodlama Gecesi', communityId: 3, communityName: 'Yazılım Kulübü' },
    { ...base, title: 'Piknik', communityId: null, organizerName: 'Ayşe' },
    { ...base, title: 'IŞIK atölyesi', communityId: null },
  ];
  it('kulüp kapsamı', () => {
    expect(filterEvents(items, 'club', '').map((e) => e.title)).toEqual(['Kodlama Gecesi']);
    expect(filterEvents(items, 'standalone', '')).toHaveLength(2);
    expect(filterEvents(items, 'all', '')).toHaveLength(3);
  });
  it('arama başlık/kulüp/organizatör üzerinde, Türkçe büyük-küçük harf', () => {
    expect(filterEvents(items, 'all', 'yazılım')).toHaveLength(1);
    expect(filterEvents(items, 'all', 'ayşe')).toHaveLength(1);
    expect(filterEvents(items, 'all', 'ışık')).toHaveLength(1);
    expect(filterEvents(items, 'standalone', 'kodlama')).toHaveLength(0);
  });
});
