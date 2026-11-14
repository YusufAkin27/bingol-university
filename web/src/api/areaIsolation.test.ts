// İki oturum alanı (yönetim `bu.admin.*`, akademisyen `bu.acad.*`) birbirine token ya da yönlendirme sızdırmaz.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { tokensFor } from '../auth/tokens';
import { headerOf, jsonResponse, mockFetch } from '../test/fetchMock';
import { apiFetch, setRefreshRetryDelays, setUnauthorizedHandler } from './client';
import { getMe, listCourses } from './academician';

const admin = tokensFor('admin');
const acad = tokensFor('acad');

beforeEach(() => {
  admin.clearTokens();
  acad.clearTokens();
  setRefreshRetryDelays([0, 0]);
});
afterEach(() => {
  vi.unstubAllGlobals();
  setUnauthorizedHandler(null, 'admin');
  setUnauthorizedHandler(null, 'acad');
});

describe('oturum alanları: token depoları', () => {
  it('alanlar ayrı sessionStorage anahtarları kullanır', () => {
    admin.setTokens('adm-a', 'adm-r');
    acad.setTokens('ac-a', 'ac-r');
    expect(sessionStorage.getItem('bu.admin.access')).toBe('adm-a');
    expect(sessionStorage.getItem('bu.acad.access')).toBe('ac-a');
    acad.clearTokens();
    expect(acad.getAccessToken()).toBeNull();
    expect(admin.getAccessToken()).toBe('adm-a'); // akademisyen çıkışı yöneticiyi düşürmez
    admin.clearTokens();
    expect(sessionStorage.getItem('bu.admin.refresh')).toBeNull();
  });

  it('yalnız yönetici oturumu açıkken akademisyen oturumu açık sayılmaz (ve tersi)', () => {
    admin.setTokens('adm-a', 'adm-r');
    expect(acad.getAccessToken()).toBeNull();
    expect(acad.getRefreshToken()).toBeNull();
    admin.clearTokens();
    acad.setTokens('ac-a', 'ac-r');
    expect(admin.getAccessToken()).toBeNull();
    expect(admin.getRefreshToken()).toBeNull();
  });
});

describe('oturum alanları: istemci', () => {
  it('akademisyen çağrısı yalnız bu.acad token\'ını gönderir; yönetici çağrısı yalnız bu.admin', async () => {
    admin.setTokens('adm-a', 'adm-r');
    acad.setTokens('ac-a', 'ac-r');
    const f = mockFetch(() => jsonResponse(200, { status: 'NONE' }));
    await getMe();
    await apiFetch('/admin/me');
    expect(headerOf(f.mock.calls[0][1] as RequestInit, 'Authorization')).toBe('Bearer ac-a');
    expect(headerOf(f.mock.calls[1][1] as RequestInit, 'Authorization')).toBe('Bearer adm-a');
  });

  it('yönetici oturumu varken akademisyen çağrısına Bearer eklenmez', async () => {
    admin.setTokens('adm-a', 'adm-r');
    const f = mockFetch(() => jsonResponse(200, []));
    await listCourses();
    expect(headerOf(f.mock.calls[0][1] as RequestInit, 'Authorization')).toBeUndefined();
  });

  it('akademisyen oturumu düşünce yalnız akademisyen işleyicisi çalışır; yönetici token\'ı korunur', async () => {
    admin.setTokens('adm-a', 'adm-r');
    acad.setTokens('ac-a', 'ac-r');
    const onAdmin = vi.fn();
    const onAcad = vi.fn();
    setUnauthorizedHandler(onAdmin, 'admin');
    setUnauthorizedHandler(onAcad, 'acad');
    const f = mockFetch((url) =>
      url.endsWith('/auth/refresh') ? jsonResponse(401, { code: 'REFRESH_INVALID', message: 'x' }) : jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }),
    );
    await expect(listCourses()).rejects.toMatchObject({ status: 401 });
    expect(onAcad).toHaveBeenCalledTimes(1);
    expect(onAdmin).not.toHaveBeenCalled();
    expect(acad.getAccessToken()).toBeNull();
    expect(admin.getAccessToken()).toBe('adm-a');
    expect(admin.getRefreshToken()).toBe('adm-r');
    // yenileme çağrısı akademisyen refresh token'ıyla yapıldı
    const refreshCall = f.mock.calls.find((c) => String(c[0]).endsWith('/auth/refresh'))!;
    expect(JSON.parse(String((refreshCall[1] as RequestInit).body))).toEqual({ refreshToken: 'ac-r' });
  });

  it('yönetici oturumu düşünce akademisyen token\'ı ve işleyicisi etkilenmez', async () => {
    admin.setTokens('adm-a', 'adm-r');
    acad.setTokens('ac-a', 'ac-r');
    const onAdmin = vi.fn();
    const onAcad = vi.fn();
    setUnauthorizedHandler(onAdmin);
    setUnauthorizedHandler(onAcad, 'acad');
    mockFetch(() => jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }));
    await expect(apiFetch('/admin/me')).rejects.toMatchObject({ status: 401 });
    expect(onAdmin).toHaveBeenCalledTimes(1);
    expect(onAcad).not.toHaveBeenCalled();
    expect(acad.getAccessToken()).toBe('ac-a');
    expect(admin.getAccessToken()).toBeNull();
  });

  it('refresh başarılıysa yeni token yalnız kendi alanına yazılır', async () => {
    admin.setTokens('adm-a', 'adm-r');
    acad.setTokens('ac-old', 'ac-r');
    let first = true;
    mockFetch((url) => {
      if (url.endsWith('/auth/refresh')) return jsonResponse(200, { accessToken: 'ac-new', refreshToken: 'ac-r2', expiresInSeconds: 900, tokenType: 'Bearer' });
      if (first) {
        first = false;
        return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
      }
      return jsonResponse(200, []);
    });
    await listCourses();
    expect(acad.getAccessToken()).toBe('ac-new');
    expect(acad.getRefreshToken()).toBe('ac-r2');
    expect(admin.getAccessToken()).toBe('adm-a');
    expect(admin.getRefreshToken()).toBe('adm-r');
  });
});
