import { describe, expect, it } from 'vitest';
import type { AuditRowV2 } from '../../../api/audit';
import { activeChips, presetActive, presetClearPatch, presetPatch, QUICK_PRESETS } from './auditQuick';
import { EMPTY_AUDIT_FILTERS } from './auditLogic';
import {
  addDays,
  bucketRows,
  groupByDay,
  istanbulParts,
  istanbulToday,
  resourceOf,
  summarize,
  verbClass,
} from './auditStats';

let id = 0;
const row = (at: string, over: Partial<AuditRowV2> = {}): AuditRowV2 => ({
  id: ++id,
  adminId: 1,
  adminEmail: 'a@bingol.edu.tr',
  method: 'PATCH',
  path: '/api/admin/users/3/role',
  status: 204,
  at,
  ip: null,
  ...over,
});

describe('eylem türü ve alan', () => {
  it('yöntemi okuma/ekleme/değiştirme/silme olarak sınıflar', () => {
    expect(verbClass('GET')).toBe('READ');
    expect(verbClass('post')).toBe('CREATE');
    expect(verbClass('PUT')).toBe('CHANGE');
    expect(verbClass('PATCH')).toBe('CHANGE');
    expect(verbClass('DELETE')).toBe('DELETE');
  });
  it('yoldan kimliksiz ilk parçayı alan sayar', () => {
    expect(resourceOf('/api/admin/users/3/role')).toBe('users');
    expect(resourceOf('/api/admin/settings/maintenance_mode')).toBe('settings');
    expect(resourceOf('/api/admin/')).toBe('other');
  });
});

describe('İstanbul gün/saat', () => {
  it('UTC 21:30, İstanbul ertesi gün 00:30 olur', () => {
    expect(istanbulParts('2026-10-28T21:30:00Z')).toEqual({ day: '2026-10-29', hour: '00' });
    expect(istanbulParts('bozuk')).toBeNull();
  });
  it('gün ekleme ay sınırını aşar', () => {
    expect(addDays('2026-10-30', 2)).toBe('2026-11-01');
    expect(addDays('2026-11-01', -6)).toBe('2026-10-26');
  });
  it('bugünü İstanbul gününe göre verir', () => {
    expect(istanbulToday(new Date('2026-10-28T22:00:00Z'))).toBe('2026-10-29');
  });
});

describe('zaman kovaları', () => {
  it('48 saate sığan örnek saatlik, boş saatler 0 ile doldurulur; reddedilenler ayrı sayılır', () => {
    const rows = [
      row('2026-10-28T06:10:00Z'), // 09:00 İstanbul
      row('2026-10-28T06:40:00Z', { status: 403 }),
      row('2026-10-28T08:05:00Z'), // 11:00
    ];
    const b = bucketRows(rows);
    expect(b.unit).toBe('hour');
    expect(b.buckets.map((x) => x.label)).toEqual(['09:00', '10:00', '11:00']);
    expect(b.buckets.map((x) => x.total)).toEqual([2, 0, 1]);
    expect(b.buckets[0].denied).toBe(1);
  });
  it('uzun aralık günlük olur ve aradaki boş günler doldurulur', () => {
    const b = bucketRows([row('2026-10-20T09:00:00Z'), row('2026-10-23T09:00:00Z'), row('2026-10-23T10:00:00Z')]);
    expect(b.unit).toBe('day');
    expect(b.buckets.map((x) => x.label)).toEqual(['20.10', '21.10', '22.10', '23.10']);
    expect(b.buckets.map((x) => x.total)).toEqual([1, 0, 0, 2]);
  });
  it('boş örnek: boş kova listesi', () => {
    expect(bucketRows([]).buckets).toEqual([]);
  });
});

describe('özet', () => {
  it('eylem türlerini, alanları, reddedilenleri ve en yoğun kovayı sayar', () => {
    const rows = [
      row('2026-10-28T06:10:00Z'),
      row('2026-10-28T06:20:00Z', { method: 'DELETE', path: '/api/admin/posts/9' }),
      row('2026-10-28T06:30:00Z', { method: 'GET', path: '/api/admin/users', status: 403 }),
      row('2026-10-28T08:00:00Z', { method: 'POST', path: '/api/admin/events/1/approve', status: 500 }),
    ];
    const s = summarize(rows, bucketRows(rows));
    expect(s.total).toBe(4);
    expect(s.byVerb).toEqual({ READ: 1, CREATE: 1, CHANGE: 1, DELETE: 1 });
    expect(s.denied).toBe(1);
    expect(s.failed).toBe(1);
    expect(s.byResource[0]).toEqual({ resource: 'users', count: 2 });
    expect(s.busiest?.label).toBe('09:00');
    expect(s.topAdmin?.count).toBe(4);
  });
});

describe('gün gruplama', () => {
  it('en yeni gün üstte, gün içi sıra korunur', () => {
    const a = row('2026-10-27T10:00:00Z');
    const b = row('2026-10-28T10:00:00Z');
    const c = row('2026-10-28T09:00:00Z');
    const g = groupByDay([b, c, a]);
    expect(g.map((x) => x.day)).toEqual(['2026-10-28', '2026-10-27']);
    expect(g[0].rows).toEqual([b, c]);
  });
});

describe('hızlı süzgeç çipleri', () => {
  const today = '2026-10-28';
  it('çip basılınca ilgili alanları yazar, kapanınca temizler', () => {
    expect(presetPatch('today', today)).toEqual({ from: today, to: today });
    expect(presetPatch('week', today)).toEqual({ from: '2026-10-22', to: today });
    expect(presetPatch('denied', today)).toEqual({ status: '403' });
    expect(presetClearPatch('deletes')).toEqual({ method: '' });
    for (const id of QUICK_PRESETS) {
      const f = { ...EMPTY_AUDIT_FILTERS, ...presetPatch(id, today) };
      expect(presetActive(id, f, today), id).toBe(true);
      expect(presetActive(id, EMPTY_AUDIT_FILTERS, today), id).toBe(false);
    }
  });
  it('etkin süzgeçleri kaldırılabilir çiplere çevirir; tarih aralığı tek çip', () => {
    const f = { ...EMPTY_AUDIT_FILTERS, method: 'DELETE', from: '2026-10-22', to: '2026-10-28', adminId: 5 };
    const chips = activeChips(f, (i) => `kisi${i}`);
    expect(chips.map((c) => c.id)).toEqual(['adminId', 'method', 'range']);
    expect(chips[0].value).toBe('kisi5');
    expect(chips[2].value).toBe('2026-10-22 – 2026-10-28');
    expect(chips[2].clear).toEqual({ from: '', to: '' });
    expect(activeChips(EMPTY_AUDIT_FILTERS)).toEqual([]);
  });
});
