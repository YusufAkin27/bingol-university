import { describe, expect, it } from 'vitest';
import { translate } from '../../../i18n';
import { locateNav } from '../../../layouts/adminNav';
import { accessFiltersFromParams, accessFiltersToParams, accessFiltersToQuery } from './accessLogic';
import {
  actionKeyCandidates,
  activeFilterCount,
  auditForTargetHref,
  clip,
  describeAction,
  filtersFromParams,
  filtersToParams,
  filtersToQuery,
  pathSegments,
  targetHref,
} from './auditLogic';

const td = (key: string, fallback = '') => {
  const v = translate('tr', key);
  return v === key ? fallback : v;
};

describe('süzgeç <-> URL', () => {
  it('geçerli değerleri okur, geçersizleri atar', () => {
    const f = filtersFromParams(
      new URLSearchParams('adminId=5&method=patch&status=4XX&q=rol&from=2026-10-01&to=2026-13&targetType=user&targetId=12&page=2'),
    );
    expect(f).toEqual({
      adminId: 5,
      method: 'PATCH',
      status: '4xx',
      q: 'rol',
      from: '2026-10-01',
      to: '', // geçersiz tarih
      targetType: 'USER',
      targetId: '12',
      page: 2,
    });
    const bad = filtersFromParams(new URLSearchParams('method=TRACE&status=abc&targetType=a-b&page=-3&adminId=x'));
    expect(bad).toMatchObject({ method: '', status: '', targetType: '', page: 0, adminId: undefined });
  });

  it('URL ve API sorgusuna yalnız dolu alanları yazar', () => {
    const f = filtersFromParams(new URLSearchParams('status=403&targetType=EVENT&targetId=9'));
    expect(filtersToParams(f).toString()).toBe('status=403&targetType=EVENT&targetId=9');
    expect(filtersToQuery(f)).toEqual({
      adminId: undefined,
      method: undefined,
      status: '403',
      q: undefined,
      from: undefined,
      to: undefined,
      targetType: 'EVENT',
      targetId: '9',
    });
    expect(activeFilterCount(f)).toBe(3);
    expect(activeFilterCount(filtersFromParams(new URLSearchParams('page=4')))).toBe(0);
  });
});

describe('işlem adı', () => {
  it('kimlik, e-posta, özet ve tarih parçalarını atar', () => {
    expect(pathSegments('/api/admin/users/3/role')).toEqual(['users', 'role']);
    expect(pathSegments('/api/admin/pending-registrations/ali%40bingol.edu.tr/verify')).toEqual(['pending-registrations', 'verify']);
    expect(pathSegments('/api/admin/moderation/blocklist/' + 'a'.repeat(64))).toEqual(['moderation', 'blocklist']);
    expect(pathSegments('/api/admin/menu/2026-10-28/image?x=1')).toEqual(['menu', 'image']);
    expect(actionKeyCandidates('put', '/api/admin/settings/maintenance_mode')).toEqual([
      'admin.wp02.audit.act.PUT.settings.maintenance_mode',
      'admin.wp02.audit.act.PUT.settings',
    ]);
  });

  it('bilinen işlemleri insanca yazar', () => {
    expect(describeAction(td, 'PATCH', '/api/admin/users/3/role')).toEqual({ label: 'Kullanıcı rolü değiştirildi', known: true });
    expect(describeAction(td, 'POST', '/api/admin/users/3/suspend').label).toBe('Kullanıcı askıya alındı');
    expect(describeAction(td, 'PUT', '/api/admin/settings/maintenance_mode').label).toBe('Ayar değiştirildi');
    expect(describeAction(td, 'GET', '/api/admin/users/3/conversations/9/messages').label).toBe('Sohbet mesajları okundu');
    expect(describeAction(td, 'GET', '/api/admin/audit/export.csv').label).toBe('Denetim kaydı CSV indirildi');
    expect(describeAction(td, 'POST', '/api/admin/push/campaigns/4/cancel').label).toBe('Push kampanyası iptal edildi');
  });

  it('bilinmeyen işlemde fiil + kaynak gösterir', () => {
    expect(describeAction(td, 'DELETE', '/api/admin/zzz/5/yyy')).toEqual({ label: 'Silme · zzz/yyy', known: false });
    expect(describeAction(td, 'GET', '/api/admin/').label).toBe('Görüntüleme');
  });
});

describe('hedef bağlantıları', () => {
  it('USER, EVENT, POST, REPORT, CAMPAIGN, COMMUNITY, TICKET, POLL için yönetim sayfasına gider', () => {
    expect(targetHref('USER', '12')).toBe('/admin/users/12');
    expect(targetHref('EVENT', '5')).toBe('/admin/events?open=5');
    expect(targetHref('POST', '7')).toBe('/admin/posts?open=7');
    expect(targetHref('REPORT', '9')).toBe('/admin/reports');
    expect(targetHref('CAMPAIGN', '3')).toBe('/admin/campaigns');
    expect(targetHref('COMMUNITY', '2')).toBe('/admin/communities');
    expect(targetHref('TICKET', '8')).toBe('/admin/support/tickets/8');
    expect(targetHref('POLL', '1')).toBe('/admin/polls');
  });

  it('kimliği sayı olmayan kullanıcı ve bilinmeyen türler bağlantısızdır', () => {
    expect(targetHref('USER', 'ali@bingol.edu.tr')).toBeNull();
    expect(targetHref('USER', null)).toBeNull();
    expect(targetHref('SETTING', 'maintenance_mode')).toBeNull();
    expect(targetHref(null, '1')).toBeNull();
  });

  it('bir hedefin tüm kayıtları süzgeçli denetim bağlantısıdır', () => {
    expect(auditForTargetHref('user', '12')).toBe('/admin/audit?targetType=USER&targetId=12');
  });
});

describe('menü', () => {
  it('mesaj erişim kayıtları kendi menü öğesine, denetim kaydı alt yolları da kendisine bağlanır', () => {
    expect(locateNav('/admin/audit')?.item.id).toBe('audit');
    expect(locateNav('/admin/audit/message-access')?.item.id).toBe('messageAccess');
  });
});

describe('clip', () => {
  it('uzun metni kısaltır', () => {
    expect(clip('a'.repeat(70), 10)).toBe('aaaaaaaaa…');
    expect(clip('  kısa ')).toBe('kısa');
    expect(clip(null)).toBe('');
  });
});

describe('mesaj erişim süzgeçleri', () => {
  it('URL <-> API sorgusu', () => {
    const f = accessFiltersFromParams(
      new URLSearchParams('adminId=2&targetUserId=7&conversationId=x&kind=MEDIA&q=rapor&from=2026-10-01&page=1'),
    );
    expect(f).toMatchObject({ adminId: 2, targetUserId: '7', conversationId: '', kind: 'MEDIA', q: 'rapor', from: '2026-10-01', page: 1 });
    expect(accessFiltersToParams(f).toString()).toBe('adminId=2&targetUserId=7&kind=MEDIA&q=rapor&from=2026-10-01&page=1');
    expect(accessFiltersToQuery(f)).toEqual({ page: 1, size: 20, adminId: 2, targetUserId: 7, kind: 'MEDIA', q: 'rapor', from: '2026-10-01' });
    expect(accessFiltersFromParams(new URLSearchParams('kind=NOPE')).kind).toBe('');
  });
});
