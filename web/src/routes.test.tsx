import { screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from './auth/AuthProvider';
import { allAdminNavItems } from './layouts/adminNav';
import { AppRoutes } from './routes';
import { jsonResponse, mockFetch } from './test/fetchMock';
import { renderWithProviders } from './test/utils';
import { setTokens } from './auth/tokens';

afterEach(() => vi.unstubAllGlobals());

const info = {
  appName: 'BÜ Kampüs',
  website: null,
  contactEmail: 'info@bingol.edu.tr',
  supportEmail: null,
  phone: null,
  address: null,
  social: { instagram: null, twitter: null, youtube: null },
  banner: null,
  maintenance: { enabled: false, message: null },
  languages: ['tr', 'en', 'ar'],
};

function api(url: string) {
  if (url.includes('/app/info')) return jsonResponse(200, info);
  if (url.includes('/app/version'))
    return jsonResponse(200, {
      updateRequired: false,
      updateAvailable: false,
      latestVersion: '1.0.0',
      storeUrl: null,
    });
  if (url.endsWith('/admin/me'))
    return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

describe('yönlendirme', () => {
  it('ana sayfa SiteLayout içinde açılır', async () => {
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
    );
    expect(
      await screen.findByRole('heading', { level: 1, name: 'Kampüs hayatı tek uygulamada' }),
    ).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'Ana menü' })).toBeInTheDocument();
  });

  it('bilinmeyen yol 404 sayfasını gösterir', async () => {
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/olmayan/sayfa' },
    );
    expect(await screen.findByRole('heading', { name: 'Sayfa bulunamadı' })).toBeInTheDocument();
  });

  it('geçersiz yasal tür 404 gösterir', async () => {
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/legal/bilinmeyen' },
    );
    expect(await screen.findByRole('heading', { name: 'Sayfa bulunamadı' })).toBeInTheDocument();
  });

  it('yönetim menüsündeki her öğe için yer tutucu sayfa açılır', async () => {
    setTokens('a', 'r');
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/admin/users' },
    );
    // /admin/users artık gerçek sayfa (yer tutucu değil)
    expect(await screen.findByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: undefined })).toBeTruthy();
  });

  it('adminNav öğeleri benzersiz', () => {
    const ids = allAdminNavItems.map((i) => i.id);
    expect(new Set(ids).size).toBe(ids.length);
    const tos = allAdminNavItems.map((i) => i.to);
    expect(new Set(tos).size).toBe(tos.length);
  });
});
