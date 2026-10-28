import { describe, expect, it } from 'vitest';
import type { EventView } from '../../../api/types';
import { allowed, buildPatch, dayBoundIso, formFromEvent, reasonError, validateEdit } from './lib';

const base = {
  id: 1,
  title: 'Kodlama Gecesi',
  description: 'Aciklama',
  startsAt: '2099-01-01T10:00:00Z',
  endsAt: '2099-01-01T12:00:00Z',
  location: 'Salon',
  coverUrl: null,
  capacity: null,
  goingCount: 0,
  interestedCount: null,
  communityId: 3,
  communityName: 'Yazilim',
  createdBy: 5,
  organizerName: 'Ayse',
  status: 'ACTIVE',
  createdAt: '2026-10-01T10:00:00Z',
  joinPolicy: 'OPEN',
} as EventView;

describe('sebep doğrulaması', () => {
  it('zorunlu ve en çok 300 karakter', () => {
    expect(reasonError('')).toBe('REQUIRED');
    expect(reasonError('   ')).toBe('REQUIRED');
    expect(reasonError('ok')).toBeNull();
    expect(reasonError('x'.repeat(300))).toBeNull();
    expect(reasonError('x'.repeat(301))).toBe('TOO_LONG');
  });
});

describe('allowedActions', () => {
  it('yalnız sunucunun izin verdiği işlemler açıktır', () => {
    expect(allowed(['hide', 'edit'], 'hide')).toBe(true);
    expect(allowed(['hide', 'edit'], 'unhide')).toBe(false);
    expect(allowed(undefined, 'hide')).toBe(false);
  });
});

describe('düzenleme formu', () => {
  it('değişiklik yoksa null döner', () => {
    expect(buildPatch(base, formFromEvent(base))).toBeNull();
  });

  it('yalnızca değişen alanları gönderir; sınırsız kontenjan 0 olur', () => {
    const f = { ...formFromEvent({ ...base, capacity: 30 }), capacity: '', title: ' Yeni ad ', reason: ' neden ' };
    expect(buildPatch({ ...base, capacity: 30 }, f)).toEqual({ title: 'Yeni ad', capacity: 0, reason: 'neden' });
  });

  it('sınırsızı sınırsız bırakınca kontenjan göndermez; katılım türü değişir', () => {
    const f = { ...formFromEvent(base), capacity: '0', joinPolicy: 'APPROVAL' as const };
    expect(buildPatch(base, f)).toEqual({ joinPolicy: 'APPROVAL' });
  });

  it('tarih değişince ISO UTC gönderir', () => {
    const f = { ...formFromEvent(base), endsLocal: '2099-01-01T18:30' };
    const p = buildPatch(base, f);
    expect(p?.endsAt).toBe(new Date('2099-01-01T18:30').toISOString());
    expect(p?.startsAt).toBeUndefined();
  });

  it('doğrulama: başlık, tarih sırası, kontenjan, sebep', () => {
    const ok = formFromEvent(base);
    expect(validateEdit(ok)).toEqual([]);
    expect(validateEdit({ ...ok, title: 'ab' })).toContain('TITLE');
    expect(validateEdit({ ...ok, title: 'x'.repeat(151) })).toContain('TITLE');
    expect(validateEdit({ ...ok, endsLocal: ok.startsLocal })).toContain('DATES');
    expect(validateEdit({ ...ok, startsLocal: '' })).toContain('DATES');
    expect(validateEdit({ ...ok, capacity: '-1' })).toContain('CAPACITY');
    expect(validateEdit({ ...ok, capacity: '100001' })).toContain('CAPACITY');
    expect(validateEdit({ ...ok, capacity: '100000' })).not.toContain('CAPACITY');
    expect(validateEdit({ ...ok, reason: 'x'.repeat(301) })).toContain('REASON');
  });
});

describe('gün sınırları', () => {
  it('geçerli gün için gün başı/sonu, geçersizse undefined', () => {
    expect(dayBoundIso('2026-11-01', false)).toBe(new Date('2026-11-01T00:00:00').toISOString());
    expect(dayBoundIso('2026-11-01', true)).toBe(new Date('2026-11-01T23:59:59').toISOString());
    expect(dayBoundIso('', false)).toBeUndefined();
    expect(dayBoundIso('bozuk', true)).toBeUndefined();
  });
});
