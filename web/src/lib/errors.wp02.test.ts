// Yönetici yazma güvenliği hata kodları (W-P02): 429 + Retry-After, REASON_REQUIRED, REQUEST_IN_PROGRESS,
// IDEMPOTENCY_KEY_REUSED, ADMIN_EMAIL_PINNED.
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, api, isApiError } from '../api/client';
import { translate } from '../i18n';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { adminError, errorMessage } from './errors';

const i18n = {
  t: (key: string, params?: Record<string, string | number>) => translate('tr', key, params),
  td: (key: string, fallback = '', params?: Record<string, string | number>) => {
    const v = translate('tr', key, params);
    return v === key ? fallback : v;
  },
} as unknown as Parameters<typeof adminError>[0];

afterEach(() => vi.unstubAllGlobals());

describe('yönetici yazma güvenliği hata mesajları', () => {
  it('429: Retry-After saniyesini gösterir', () => {
    const e = new ApiError(429, 'RATE_LIMITED', 'x', 12);
    expect(adminError(i18n, e)).toBe('Kısa sürede çok fazla işlem yaptınız. 12 saniye sonra yeniden deneyin.');
    expect(errorMessage(i18n, e)).toBe('Kısa sürede çok fazla işlem yaptınız. 12 saniye sonra yeniden deneyin.');
  });

  it('429 ama Retry-After yoksa mevcut genel hız sınırı mesajına düşer', () => {
    expect(adminError(i18n, new ApiError(429, 'RATE_LIMITED', 'x'))).toBe(translate('tr', 'admin.err.RATE_LIMITED'));
  });

  it.each([
    ['REASON_REQUIRED', 400, 'Bu işlem için yeterince uzun bir sebep yazmanız gerekir.'],
    ['REQUEST_IN_PROGRESS', 409, 'Aynı işlem zaten sürüyor. Bitmesini bekleyin; sonuç hazır olunca liste yenilenir.'],
    ['IDEMPOTENCY_KEY_REUSED', 422, 'Bu işlem anahtarı başka bir işlem için kullanılmış. Pencereyi kapatıp işlemi yeniden başlatın.'],
    ['ADMIN_EMAIL_PINNED', 409, 'Bu hesap ADMIN_EMAILS listesinde sabitlenmiş: rolü düşürülemez ve hesap silinemez. Önce adresi sunucu ayarındaki listeden çıkarın.'],
  ])('%s Türkçe mesaja çevrilir (tüm kapsamlarda)', (code, status, text) => {
    const e = new ApiError(status, code, 'sunucu metni');
    expect(adminError(i18n, e)).toBe(text);
    expect(adminError(i18n, e, 'admin.mail.err')).toBe(text);
    expect(errorMessage(i18n, e)).toBe(text);
  });

  it('istemci yanıttaki Retry-After başlığını ApiError.retryAfter olarak taşır', async () => {
    mockFetch(
      () =>
        new Response(JSON.stringify({ code: 'RATE_LIMITED', message: 'x' }), {
          status: 429,
          headers: { 'Content-Type': 'application/json', 'Retry-After': '7' },
        }),
    );
    const err = await api.post('/admin/users/1/suspend', {}).catch((e: unknown) => e);
    expect(isApiError(err)).toBe(true);
    expect((err as ApiError).retryAfter).toBe(7);
    expect(adminError(i18n, err)).toContain('7 saniye');
  });

  it('Retry-After yoksa ya da geçersizse retryAfter tanımsızdır', async () => {
    mockFetch(() => jsonResponse(409, { code: 'REQUEST_IN_PROGRESS', message: 'x' }));
    const err = (await api.post('/admin/x', {}).catch((e: unknown) => e)) as ApiError;
    expect(err.retryAfter).toBeUndefined();
    expect(err.code).toBe('REQUEST_IN_PROGRESS');
  });
});
