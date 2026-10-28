import { screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../auth/AuthProvider';
import { setTokens } from '../auth/tokens';
import { AppRoutes } from '../routes';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { renderWithProviders } from '../test/utils';
import { allAdminNavItems } from './adminNav';

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

/** Destek profili: kullanıcı okuma (maskeli), destek okuma/yazma, tek kullanıcı bildirimi. */
const SUPPORT_PERMS = [
  'dashboard.read',
  'analytics.read',
  'users.read',
  'content.read',
  'support.read',
  'support.write',
  'comms.read',
  'comms.single',
  'legal.read',
];

function api(url: string) {
  if (url.includes('/app/info')) return jsonResponse(200, info);
  if (url.endsWith('/admin/me'))
    return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
  if (url.endsWith('/admin/rbac/me'))
    return jsonResponse(200, {
      userId: 1,
      email: 'a@bingol.edu.tr',
      displayName: 'Yönetici',
      profile: 'SUPPORT',
      pinned: false,
      permissions: SUPPORT_PERMS,
    });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

function setViewport(width: number) {
  window.matchMedia = ((query: string) => {
    const m = /min-width:\s*(\d+)px/.exec(query);
    return {
      matches: m ? width >= Number(m[1]) : false,
      media: query,
      onchange: null,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
      dispatchEvent: () => false,
    };
  }) as unknown as typeof window.matchMedia;
}

function open(route: string) {
  setTokens('a', 'r');
  mockFetch(api);
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route, lang: 'tr' },
  );
}

beforeEach(() => setViewport(1280));
afterEach(() => vi.unstubAllGlobals());

describe('yönetim menüsü izinleri (P16)', () => {
  it('her menü öğesinin izni tanımlıdır', () => {
    const missing = allAdminNavItems.filter((i) => !i.perm).map((i) => i.id);
    expect(missing).toEqual([]);
  });

  it('yetkisiz menü öğeleri GİZLENİR, yetkililer görünür', async () => {
    open('/admin/users');
    const menu = await screen.findByRole('navigation', { name: 'Yönetim menüsü' });
    // izin bilgisi gelince yetkisiz öğe kaybolur
    await waitFor(() => expect(within(menu).queryByRole('link', { name: 'Denetim kaydı', hidden: true })).toBeNull());
    expect(within(menu).getByRole('link', { name: 'Kullanıcılar', hidden: true })).toBeInTheDocument();
    expect(within(menu).queryByRole('link', { name: 'Ayarlar', hidden: true })).toBeNull(); // settings.read yok
    expect(within(menu).queryByRole('link', { name: 'Sohbet medyası ve mesajlar', hidden: true })).toBeNull(); // chat.read yok
    expect(within(menu).queryByRole('link', { name: 'Raporlar', hidden: true })).toBeNull(); // moderation.read yok
    expect(within(menu).queryByRole('link', { name: 'Kampanyalar', hidden: true })).not.toBeNull(); // comms.read var
  });

  it('yetkisiz sayfa adresi "yetkiniz yok" gösterir (rota koruması)', async () => {
    open('/admin/audit');
    expect(await screen.findByText('Bu sayfa için yetkiniz yok')).toBeInTheDocument();
    expect(screen.getByText('Gereken izin: audit.read')).toBeInTheDocument();
  });

  it('kullanıcı mesajları sayfası chat.read ister', async () => {
    open('/admin/users/5/messages');
    expect(await screen.findByText('Gereken izin: chat.read')).toBeInTheDocument();
  });
});
