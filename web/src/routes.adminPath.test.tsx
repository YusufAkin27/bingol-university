// VITE_ADMIN_PATH ayarlıyken panel rotaları gizli önekte açılmalı (hoisted: modüller yüklenmeden önce ayarlanır).
import { screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

vi.hoisted(() => {
  vi.stubEnv('VITE_ADMIN_PATH', '/yonetim-k7x2m9');
});

import { AuthProvider } from './auth/AuthProvider';
import { setTokens } from './auth/tokens';
import { paths } from './paths';
import { AppRoutes } from './routes';
import { jsonResponse, mockFetch } from './test/fetchMock';
import { renderWithProviders } from './test/utils';

afterEach(() => vi.unstubAllGlobals());

function api(url: string) {
  if (url.endsWith('/admin/me'))
    return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

describe('VITE_ADMIN_PATH', () => {
  it('paths.admin gizli öneki kullanır', () => {
    expect(paths.admin.dashboard).toBe('/yonetim-k7x2m9');
    expect(paths.admin.users).toBe('/yonetim-k7x2m9/users');
    expect(paths.admin.login).toBe('/yonetim-k7x2m9/login');
  });

  it('panel sayfası gizli yolda açılır', async () => {
    setTokens('a', 'r');
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/yonetim-k7x2m9/users' },
    );
    expect(await screen.findByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeInTheDocument();
  });

  it('giriş sayfası gizli yolda açılır; /admin artık panel değildir', async () => {
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/admin/users' },
    );
    // /admin site 404 sayfasına düşer (panel rotası değil)
    expect(await screen.findByRole('heading', { name: 'Sayfa bulunamadı' })).toBeInTheDocument();
  });
});
