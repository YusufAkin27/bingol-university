import { screen, waitFor } from '@testing-library/react';
import axe from 'axe-core';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from './auth/AuthProvider';
import { AppRoutes } from './routes';
import { jsonResponse, mockFetch } from './test/fetchMock';
import { renderWithProviders } from './test/utils';

// jsdom'da yerleşim/renk hesaplanmadığından kontrast ve bölge kuralları kapalı (kontrast tarayıcıda denetlenir)
async function violations(container: HTMLElement) {
  const res = await axe.run(container, {
    rules: { 'color-contrast': { enabled: false }, region: { enabled: false } },
  });
  return res.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`);
}

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
  if (url.includes('/auth/me')) return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'yok' });
}

afterEach(() => vi.unstubAllGlobals());

const SITE_ROUTES = ['/', '/about', '/features', '/download', '/accessibility', '/cookies', '/security', '/delete-account'];

describe('erisilebilirlik (axe)', () => {
  for (const lang of ['tr', 'ar'] as const) {
    for (const route of SITE_ROUTES) {
      it(`${lang} ${route}: ihlal yok`, async () => {
        mockFetch(api);
        const { container } = renderWithProviders(
          <AuthProvider>
            <AppRoutes />
          </AuthProvider>,
          { route, lang },
        );
        await waitFor(() => expect(container.querySelector('h1')).not.toBeNull(), { timeout: 5000 });
        expect(await violations(container)).toEqual([]);
      });
    }
  }

  it('yonetim girisi: ihlal yok', async () => {
    mockFetch(api);
    const { container } = renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/admin/login', lang: 'tr' },
    );
    await screen.findByRole('button', { name: /giri/i });
    expect(await violations(container)).toEqual([]);
  });
});
