import { describe, expect, it } from 'vitest';
import { adminNav, allAdminNavItems, foldTr, locateNav, navMatches } from './adminNav';

describe('adminNav yardımcıları', () => {
  it('foldTr Türkçe harfleri sadeleştirir', () => {
    expect(foldTr('Gönderiler')).toBe('gonderiler');
    expect(foldTr('İtirazlar')).toBe('itirazlar');
    expect(foldTr('ISIK ığ')).toBe('isik ig');
  });

  it('navMatches sözcükleri sıradan bağımsız ve aksansız eşler', () => {
    expect(navMatches('Doğrulanmamış kullanıcılar', 'dogrulanmamis kul')).toBe(true);
    expect(navMatches('Mail kampanyaları', 'kampanya mail')).toBe(true);
    expect(navMatches('Raporlar', 'zzz')).toBe(false);
    expect(navMatches('Raporlar', '  ')).toBe(true);
  });

  it('locateNav alt yolları üst menü öğesine bağlar, kökü yalnız tam eşleştirir', () => {
    expect(locateNav('/admin')?.item.id).toBe('dashboard');
    expect(locateNav('/admin/users/5/messages')?.item.id).toBe('users');
    expect(locateNav('/admin/events/applications')?.item.id).toBe('eventApplications');
    expect(locateNav('/admin/events')?.item.id).toBe('events');
    expect(locateNav('/admin/yok-boyle-sayfa')).toBeNull();
  });

  it('her grubun en az bir öğesi var ve hiçbir öğe iki grupta değil', () => {
    for (const g of adminNav) expect(g.items.length).toBeGreaterThan(0);
    expect(new Set(allAdminNavItems.map((i) => i.id)).size).toBe(allAdminNavItems.length);
  });
});
