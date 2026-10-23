import { describe, expect, it } from 'vitest';
import { filtersToApi, filtersToSearch, parseSort, parseUserFilters, activeFilterCount, EMPTY_FILTERS } from './filters';
import { statusTone, isDenied } from '../audit/status';

describe('kullanıcı filtreleri ↔ URL', () => {
  it('varsayılan durum boş URL üretir', () => {
    expect(filtersToSearch(EMPTY_FILTERS).toString()).toBe('');
    expect(parseUserFilters(new URLSearchParams(''))).toEqual(EMPTY_FILTERS);
  });

  it('gidiş-dönüş: URL → filtre → URL aynıdır (paylaşılabilir bağlantı)', () => {
    const qs = 'q=ay%C5%9Fe&status=SUSPENDED&role=ADMIN&faculty=Ornek+A&classYear=3&language=ar&verified=false&sort=displayName%2Casc&page=2';
    const f = parseUserFilters(new URLSearchParams(qs));
    expect(f).toMatchObject({
      q: 'ayşe',
      status: 'SUSPENDED',
      role: 'ADMIN',
      faculty: 'Ornek A',
      classYear: '3',
      language: 'ar',
      verified: 'false',
      sort: 'displayName,asc',
      page: 2,
    });
    const back = filtersToSearch(f);
    expect(parseUserFilters(back)).toEqual(f);
  });

  it('geçersiz değerleri yoksayar', () => {
    const f = parseUserFilters(new URLSearchParams('status=X&role=Y&classYear=9&language=de&verified=maybe&sort=hack&page=-4'));
    expect(f).toEqual(EMPTY_FILTERS);
    expect(parseSort('createdAt,sideways')).toBe('createdAt,desc');
  });

  it('API parametrelerine boşlar girmez, türler dönüştürülür', () => {
    const f = parseUserFilters(new URLSearchParams('status=ACTIVE&classYear=2&verified=true&q=x'));
    expect(filtersToApi(f)).toEqual({ sort: 'createdAt,desc', q: 'x', status: 'ACTIVE', classYear: 2, verified: true });
    expect(activeFilterCount(f)).toBe(3);
  });
});

describe('denetim durum rozeti', () => {
  it('HTTP kodlarını tonlara eşler, 403 ayrıca vurgulanır', () => {
    expect(statusTone(204)).toBe('success');
    expect(statusTone(302)).toBe('info');
    expect(statusTone(403)).toBe('warning');
    expect(statusTone(500)).toBe('danger');
    expect(isDenied(403)).toBe(true);
    expect(isDenied(401)).toBe(false);
  });
});
