import { describe, expect, it } from 'vitest';
import { isAdminPath, normalizeAdminBase } from './adminBase';

describe('yonetim yolu on eki', () => {
  it('ayar yoksa /admin, verilince kok ve sonda egik cizgi duzeltilir', () => {
    expect(normalizeAdminBase(undefined)).toBe('/admin');
    expect(normalizeAdminBase('  ')).toBe('/admin');
    expect(normalizeAdminBase('yonetim-k7x2m9')).toBe('/yonetim-k7x2m9');
    expect(normalizeAdminBase('/yonetim-k7x2m9///')).toBe('/yonetim-k7x2m9');
  });

  it('isAdminPath yalniz on ekin kendisi veya altindaki yollari kabul eder', () => {
    expect(isAdminPath('/admin/users', '/admin')).toBe(true);
    expect(isAdminPath('/admin', '/admin')).toBe(true);
    expect(isAdminPath('/adminfoo', '/admin')).toBe(false);
    expect(isAdminPath('/yonetim-k7x2m9/users', '/yonetim-k7x2m9')).toBe(true);
    expect(isAdminPath('/admin/users', '/yonetim-k7x2m9')).toBe(false);
  });
});
