import { describe, expect, it } from 'vitest';
import { isAdminPath, localizePath } from './langPath';

describe('akademisyen paneli yolları dil öneki almaz', () => {
  it('localizePath /akademisyen yollarını olduğu gibi bırakır', () => {
    for (const p of ['/akademisyen', '/akademisyen/dersler/7?sekme=duyurular', '/akademisyen/yoklama/5']) {
      expect(localizePath(p, 'en')).toBe(p);
    }
  });
  it('benzer önekler sayılmaz; site yolları hâlâ önek alır', () => {
    expect(isAdminPath('/akademisyen')).toBe(true);
    expect(isAdminPath('/akademisyenler')).toBe(false);
    expect(localizePath('/privacy', 'en')).toBe('/en/privacy');
    expect(localizePath('/admin/users', 'en')).toBe('/admin/users');
  });
});
