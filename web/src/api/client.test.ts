import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getAccessToken, getRefreshToken, setTokens } from '../auth/tokens';
import { setCurrentLang } from '../i18n/lang';
import { headerOf, jsonResponse, mockFetch } from '../test/fetchMock';
import { ApiError, apiFetch, buildUrl, setUnauthorizedHandler } from './client';

describe('api client', () => {
  beforeEach(() => {
    setCurrentLang('tr');
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    setUnauthorizedHandler(null);
  });

  it('Accept-Language ve Bearer başlıklarını ekler', async () => {
    setTokens('tok', 'ref');
    setCurrentLang('ar');
    const f = mockFetch(() => jsonResponse(200, { ok: true }));
    const out = await apiFetch<{ ok: boolean }>('/admin/me');
    expect(out).toEqual({ ok: true });
    const init = f.mock.calls[0][1] as RequestInit;
    expect(headerOf(init, 'Accept-Language')).toBe('ar');
    expect(headerOf(init, 'Authorization')).toBe('Bearer tok');
  });

  it('auth:false istekte Bearer eklenmez', async () => {
    setTokens('tok', 'ref');
    const f = mockFetch(() => jsonResponse(200, {}));
    await apiFetch('/app/info', { auth: false });
    expect(headerOf(f.mock.calls[0][1] as RequestInit, 'Authorization')).toBeUndefined();
  });

  it('hata gövdesini {code,message} olarak ApiError yapar', async () => {
    mockFetch(() => jsonResponse(409, { code: 'LAST_ADMIN', message: 'Son yönetici düşürülemez.' }));
    const err = await apiFetch('/admin/users/1/role', { method: 'PATCH', body: { role: 'USER' } }).catch(
      (e) => e,
    );
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(409);
    expect(err.code).toBe('LAST_ADMIN');
    expect(err.message).toBe('Son yönetici düşürülemez.');
  });

  it('JSON olmayan hata gövdesinde HTTP_<status> / SERVER_ERROR kodu verir', async () => {
    mockFetch(() => new Response('<html>nope</html>', { status: 404 }));
    expect(await apiFetch('/x').catch((e) => e)).toMatchObject({ status: 404, code: 'HTTP_404' });
    mockFetch(() => new Response('boom', { status: 502 }));
    expect(await apiFetch('/x').catch((e) => e)).toMatchObject({ status: 502, code: 'SERVER_ERROR' });
  });

  it('ağ hatasını NETWORK_ERROR (status 0) yapar', async () => {
    mockFetch(() => {
      throw new TypeError('failed');
    });
    expect(await apiFetch('/x').catch((e) => e)).toMatchObject({ status: 0, code: 'NETWORK_ERROR' });
  });

  it('204 yanıtta undefined döner', async () => {
    mockFetch(() => jsonResponse(204));
    expect(await apiFetch('/x', { method: 'POST' })).toBeUndefined();
  });

  it('sorgu parametrelerini kodlar, boşları atlar', () => {
    expect(
      buildUrl('/admin/users', { q: 'a b&c', page: 0, status: undefined, role: '', verified: false }),
    ).toBe('/api/admin/users?q=a+b%26c&page=0&verified=false');
  });

  it('401 üzerine EŞZAMANLI isteklerde tek refresh çağrısı yapar ve istekleri yeniden dener', async () => {
    setTokens('old', 'r1');
    let refreshCalls = 0;
    const f = mockFetch(async (url, init) => {
      if (url.endsWith('/auth/refresh')) {
        refreshCalls++;
        await new Promise((r) => setTimeout(r, 20));
        return jsonResponse(200, {
          accessToken: 'new',
          refreshToken: 'r2',
          expiresInSeconds: 900,
          tokenType: 'Bearer',
        });
      }
      return headerOf(init, 'Authorization') === 'Bearer new'
        ? jsonResponse(200, { url })
        : jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
    });
    const results = await Promise.all([apiFetch('/a'), apiFetch('/b'), apiFetch('/c')]);
    expect(refreshCalls).toBe(1);
    expect(results).toHaveLength(3);
    expect(getAccessToken()).toBe('new');
    expect(getRefreshToken()).toBe('r2');
    // 3 ilk deneme + 1 refresh + 3 yeniden deneme
    expect(f).toHaveBeenCalledTimes(7);
  });

  it("refresh başarısızsa token'ları siler ve oturum sonu işleyicisini çağırır", async () => {
    setTokens('old', 'r1');
    const onExpired = vi.fn();
    setUnauthorizedHandler(onExpired);
    mockFetch((url) =>
      url.endsWith('/auth/refresh')
        ? jsonResponse(401, { code: 'INVALID_REFRESH_TOKEN', message: 'x' })
        : jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }),
    );
    const err = await apiFetch('/admin/me').catch((e) => e);
    expect(err).toMatchObject({ status: 401 });
    expect(onExpired).toHaveBeenCalledTimes(1);
    expect(getAccessToken()).toBeNull();
    expect(getRefreshToken()).toBeNull();
  });

  it('refresh sırasında ağ hatası oturumu düşürmez', async () => {
    setTokens('old', 'r1');
    const onExpired = vi.fn();
    setUnauthorizedHandler(onExpired);
    mockFetch((url) => {
      if (url.endsWith('/auth/refresh')) throw new TypeError('offline');
      return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
    });
    const err = await apiFetch('/admin/me').catch((e) => e);
    expect(err).toMatchObject({ code: 'NETWORK_ERROR' });
    expect(onExpired).not.toHaveBeenCalled();
    expect(getRefreshToken()).toBe('r1');
  });

  it('giriş isteğindeki 401 refresh denemez', async () => {
    const f = mockFetch(() => jsonResponse(401, { code: 'INVALID_CREDENTIALS', message: 'x' }));
    const err = await apiFetch('/auth/login', { method: 'POST', body: {}, auth: false }).catch((e) => e);
    expect(err.code).toBe('INVALID_CREDENTIALS');
    expect(f).toHaveBeenCalledTimes(1);
  });
});
