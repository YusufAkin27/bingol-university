// Varsayılan oturum-sonu yönlendirmeleri (işleyici kaydedilmemişken): her alan kendi giriş sayfasına gider.
// Ayrı dosya: işleyiciler modül düzeyinde durur; diğer test dosyası bunları sıfırlar.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { tokensFor } from '../auth/tokens';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { acadPaths } from '../pages/academician/paths';
import { paths } from '../paths';
import { apiFetch } from './client';
import { listCourses } from './academician';

beforeEach(() => {
  tokensFor('admin').clearTokens();
  tokensFor('acad').clearTokens();
});
afterEach(() => vi.unstubAllGlobals());

describe('varsayılan oturum-sonu yönlendirmesi', () => {
  it('varsayılan akademisyen yönlendirmesi /akademisyen/giris\'tir, yönetim girişi değil', async () => {
    const assign = vi.fn();
    vi.stubGlobal('location', { pathname: '/akademisyen/dersler', search: '', assign });
    tokensFor('acad').setTokens('ac-a', 'ac-r');
    mockFetch(() => jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }));
    await expect(listCourses()).rejects.toBeTruthy();
    expect(assign).toHaveBeenCalledWith(acadPaths.login);
    expect(assign).not.toHaveBeenCalledWith(paths.admin.login);
  });

  it('varsayılan yönetici yönlendirmesi değişmedi: yönetim girişi', async () => {
    const assign = vi.fn();
    vi.stubGlobal('location', { pathname: '/admin/users', search: '', assign });
    tokensFor('admin').setTokens('adm-a', 'adm-r');
    mockFetch(() => jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }));
    await expect(apiFetch('/admin/me')).rejects.toBeTruthy();
    expect(assign).toHaveBeenCalledWith(paths.admin.login);
  });
});
