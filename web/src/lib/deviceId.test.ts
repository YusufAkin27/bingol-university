import { afterEach, describe, expect, it, vi } from 'vitest';
import { apiFetch } from '../api/client';
import { headerOf, jsonResponse, mockFetch } from '../test/fetchMock';
import { getDeviceId } from './deviceId';

afterEach(() => {
  vi.unstubAllGlobals();
  window.localStorage.clear();
});

describe('cihaz kimliği', () => {
  it('32+ karakter rastgele kimlik üretir, localStorage’a yazar ve tekrar kullanır', () => {
    window.localStorage.clear();
    const a = getDeviceId();
    expect(a.length).toBeGreaterThanOrEqual(32);
    expect(a).toMatch(/^[0-9a-f]+$/);
    expect(window.localStorage.getItem('bu.device.id')).toBe(a);
    expect(getDeviceId()).toBe(a);
  });

  it('çok kısa kayıtlı değeri geçersiz sayıp yenisini üretir', () => {
    window.localStorage.setItem('bu.device.id', 'kisa');
    const id = getDeviceId();
    expect(id).not.toBe('kisa');
    expect(id.length).toBeGreaterThanOrEqual(32);
  });

  it('localStorage erişilemezse bellekte kalıcı kalır', () => {
    const spy = vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    const setSpy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    try {
      const a = getDeviceId();
      expect(a.length).toBeGreaterThanOrEqual(32);
      expect(getDeviceId()).toBe(a);
    } finally {
      spy.mockRestore();
      setSpy.mockRestore();
    }
  });

  it('tüm /api isteklerine X-Device-Id başlığı eklenir (herkese açık uçlar dahil)', async () => {
    const f = mockFetch(() => jsonResponse(200, {}));
    await apiFetch('/auth/login', { method: 'POST', body: {}, auth: false });
    await apiFetch('/admin/me');
    const id = getDeviceId();
    for (const call of f.mock.calls) {
      expect(headerOf(call[1] as RequestInit, 'X-Device-Id')).toBe(id);
    }
    expect(f).toHaveBeenCalledTimes(2);
  });
});
