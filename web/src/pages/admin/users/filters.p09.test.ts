import { describe, expect, it } from 'vitest';
import { activeFilterCount, EMPTY_FILTERS, filtersToApi, filtersToSearch, parseUserFilters } from './filters';

describe('kullanıcı filtreleri (P09): tarih aralıkları', () => {
  it('kayıt / son görülme aralığı URL ↔ süzgeç ↔ API parametresine gidiş-dönüş yapar', () => {
    const f = parseUserFilters(
      new URLSearchParams('createdFrom=2026-09-01&createdTo=2026-09-30&seenFrom=2026-10-01&seenTo=2026-10-28'),
    );
    expect(f).toMatchObject({
      createdFrom: '2026-09-01',
      createdTo: '2026-09-30',
      seenFrom: '2026-10-01',
      seenTo: '2026-10-28',
    });
    expect(parseUserFilters(filtersToSearch(f))).toEqual(f);
    expect(filtersToApi(f)).toEqual({
      sort: 'createdAt,desc',
      createdFrom: '2026-09-01',
      createdTo: '2026-09-30',
      seenFrom: '2026-10-01',
      seenTo: '2026-10-28',
    });
    expect(activeFilterCount(f)).toBe(4);
  });

  it('geçersiz tarih biçimleri yok sayılır; boş süzgeç URL üretmez', () => {
    const f = parseUserFilters(new URLSearchParams('createdFrom=dun&seenTo=2026-13&createdTo=01.09.2026'));
    expect(f).toEqual(EMPTY_FILTERS);
    expect(filtersToSearch(EMPTY_FILTERS).toString()).toBe('');
  });

  it('yeni sıralama alanları kabul edilir; e-posta ile sıralama kapalıdır (sunucu da reddeder)', () => {
    expect(parseUserFilters(new URLSearchParams('sort=faculty,asc')).sort).toBe('faculty,asc');
    expect(parseUserFilters(new URLSearchParams('sort=status,desc')).sort).toBe('status,desc');
    expect(parseUserFilters(new URLSearchParams('sort=email,asc')).sort).toBe('createdAt,desc');
  });
});
