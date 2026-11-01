import { describe, expect, it } from 'vitest';
import type { UnitSource } from '../../../api/adminUnitNews';
import { coreTilesOf, sortTiles, sourceState, summarizeTiles, unitTiles } from './sourceGrid';

const NOW = Date.parse('2026-11-10T12:00:00+03:00');
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000).toISOString();

function unit(over: Partial<UnitSource>): UnitSource {
  return {
    code: 'x',
    name: 'Birim',
    kind: 'FACULTY',
    baseUrl: 'https://x.bingol.edu.tr',
    enabled: true,
    graduate: false,
    facultyKeys: [],
    departmentCount: 0,
    announcementCount: 0,
    lastSuccessAt: hoursAgo(5),
    lastAttemptAt: hoursAgo(5),
    lastMessage: null,
    maintenance: false,
    ...over,
  };
}

describe('sourceState', () => {
  it('öncelik sırası: kapalı > bakımda > hiç çekilmemiş > eski > çalışıyor', () => {
    expect(sourceState({ enabled: false, maintenance: true, lastSuccessAt: null }, 48, NOW)).toBe('disabled');
    expect(sourceState({ maintenance: true, lastSuccessAt: hoursAgo(1) }, 48, NOW)).toBe('maintenance');
    expect(sourceState({ maintenance: false, lastSuccessAt: null }, 48, NOW)).toBe('never');
    expect(sourceState({ maintenance: false, lastSuccessAt: hoursAgo(49) }, 48, NOW)).toBe('stale');
    expect(sourceState({ maintenance: false, lastSuccessAt: hoursAgo(47) }, 48, NOW)).toBe('ok');
  });
  it('bozuk tarihi "hiç çekilmemiş" sayar', () => {
    expect(sourceState({ maintenance: false, lastSuccessAt: 'bozuk' }, 48, NOW)).toBe('never');
  });
});

describe('coreTilesOf', () => {
  it('yemek listesini aylık eşikle değerlendirir (10 günlük çekim eski sayılmaz)', () => {
    const [news, menu] = coreTilesOf(
      { maintenance: false, lastSuccess: hoursAgo(10 * 24) },
      { maintenance: false, lastSuccess: hoursAgo(10 * 24) },
      { news: 'Haber', menu: 'Yemek' },
      NOW,
    );
    expect(news.state).toBe('stale');
    expect(menu.state).toBe('ok');
    expect(news.core && menu.core).toBe(true);
  });
});

describe('sortTiles ve summarizeTiles', () => {
  it('sorunluları üste dizer, kapalıları sona atar', () => {
    const tiles = unitTiles(
      [
        unit({ code: 'a', name: 'Zeta' }),
        unit({ code: 'b', name: 'Beta', maintenance: true }),
        unit({ code: 'c', name: 'Alfa', enabled: false }),
        unit({ code: 'd', name: 'Gama', lastSuccessAt: null }),
        unit({ code: 'e', name: 'Ceta', lastSuccessAt: hoursAgo(100) }),
      ],
      NOW,
    );
    expect(sortTiles(tiles).map((t) => [t.label, t.state])).toEqual([
      ['Beta', 'maintenance'],
      ['Gama', 'never'],
      ['Ceta', 'stale'],
      ['Zeta', 'ok'],
      ['Alfa', 'disabled'],
    ]);
  });
  it('özet: kapalılar izlenenlere girmez; ilgi isteyenler sayılır', () => {
    const tiles = unitTiles(
      [
        unit({ code: 'a' }),
        unit({ code: 'b', maintenance: true }),
        unit({ code: 'c', enabled: false }),
        unit({ code: 'd', lastSuccessAt: null }),
      ],
      NOW,
    );
    const s = summarizeTiles(tiles);
    expect(s).toMatchObject({ watched: 3, ok: 1, bad: 2, disabled: 1 });
    expect(s.counts.maintenance).toBe(1);
    expect(s.counts.never).toBe(1);
  });
  it('duyuru sayısını karoya taşır', () => {
    expect(unitTiles([unit({ announcementCount: 42 })], NOW)[0].announcements).toBe(42);
  });
});
