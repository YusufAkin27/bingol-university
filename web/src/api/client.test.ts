import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getAccessToken, getRefreshToken, setTokens } from '../auth/tokens';
import { setCurrentLang } from '../i18n/lang';
import { headerOf, jsonResponse, mockFetch } from '../test/fetchMock';
import { ApiError, apiFetch, apiFetchMeta, buildUrl, setRefreshRetryDelays, setUnauthorizedHandler } from './client';

describe('api client', () => {
  beforeEach(() => {
    setCurrentLang('tr');
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    setUnauthorizedHandler(null);
    setRefreshRetryDelays([400, 1500]);
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

  describe('refresh dayanıklılığı (geçici hatada oturum düşmez)', () => {
    const tokens = { accessToken: 'new', refreshToken: 'r2', expiresInSeconds: 900, tokenType: 'Bearer' };

    it('refresh 429 verirse oturum kapanmaz, kısa gecikmeyle yeniden denenir ve başarılı olur', async () => {
      setRefreshRetryDelays([1, 1]);
      setTokens('old', 'r1');
      const onExpired = vi.fn();
      setUnauthorizedHandler(onExpired);
      let refreshCalls = 0;
      mockFetch((url, init) => {
        if (url.endsWith('/auth/refresh')) {
          refreshCalls++;
          return refreshCalls === 1
            ? jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' })
            : jsonResponse(200, tokens);
        }
        return headerOf(init, 'Authorization') === 'Bearer new'
          ? jsonResponse(200, { ok: true })
          : jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
      });
      expect(await apiFetch('/admin/me')).toEqual({ ok: true });
      expect(refreshCalls).toBe(2);
      expect(onExpired).not.toHaveBeenCalled();
      expect(getRefreshToken()).toBe('r2');
    });

    it('refresh sürekli 429 verirse hata döner ama oturum ve token korunur', async () => {
      setRefreshRetryDelays([1, 1]);
      setTokens('old', 'r1');
      const onExpired = vi.fn();
      setUnauthorizedHandler(onExpired);
      let refreshCalls = 0;
      mockFetch((url) => {
        if (url.endsWith('/auth/refresh')) {
          refreshCalls++;
          return jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' });
        }
        return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
      });
      const err = await apiFetch('/admin/me').catch((e) => e);
      expect(err).toMatchObject({ status: 429 });
      expect(refreshCalls).toBe(3); // ilk deneme + 2 yeniden deneme
      expect(onExpired).not.toHaveBeenCalled();
      expect(getRefreshToken()).toBe('r1');
      expect(getAccessToken()).toBe('old');
    });

    it('refresh 500 verirse yeniden denenmez (token tek kullanımlık) ama oturum da düşmez', async () => {
      setRefreshRetryDelays([1, 1]);
      setTokens('old', 'r1');
      const onExpired = vi.fn();
      setUnauthorizedHandler(onExpired);
      let refreshCalls = 0;
      mockFetch((url) => {
        if (url.endsWith('/auth/refresh')) {
          refreshCalls++;
          return jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' });
        }
        return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
      });
      expect(await apiFetch('/admin/me').catch((e) => e)).toMatchObject({ status: 500 });
      expect(refreshCalls).toBe(1);
      expect(onExpired).not.toHaveBeenCalled();
      expect(getRefreshToken()).toBe('r1');
    });

    it('refresh 403 ise oturum sonlanır', async () => {
      setTokens('old', 'r1');
      const onExpired = vi.fn();
      setUnauthorizedHandler(onExpired);
      mockFetch((url) =>
        url.endsWith('/auth/refresh')
          ? jsonResponse(403, { code: 'INVALID_REFRESH_TOKEN', message: 'x' })
          : jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }),
      );
      await apiFetch('/admin/me').catch(() => undefined);
      expect(onExpired).toHaveBeenCalledTimes(1);
      expect(getRefreshToken()).toBeNull();
    });
  });

  it('apiFetchMeta gövdeyle birlikte yanıt başlıklarını döner', async () => {
    mockFetch(
      () =>
        new Response(JSON.stringify([1, 2]), {
          status: 200,
          headers: { 'Content-Type': 'application/json', 'X-Next-Cursor': '3' },
        }),
    );
    const r = await apiFetchMeta<number[]>('/admin/faq');
    expect(r.data).toEqual([1, 2]);
    expect(r.headers.get('X-Next-Cursor')).toBe('3');
  });

  it('Idempotency-Key gibi ek başlıklar gönderilir', async () => {
    const f = mockFetch(() => jsonResponse(204));
    await apiFetch('/admin/x', { method: 'POST', headers: { 'Idempotency-Key': 'k1' } });
    expect(headerOf(f.mock.calls[0][1] as RequestInit, 'Idempotency-Key')).toBe('k1');
  });
});
