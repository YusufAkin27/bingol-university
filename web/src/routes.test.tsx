import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { useLocation } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from './auth/AuthProvider';
import { allAdminNavItems } from './layouts/adminNav';
import { AppRoutes } from './routes';
import { jsonResponse, mockFetch } from './test/fetchMock';
import { renderWithProviders } from './test/utils';
import { setTokens } from './auth/tokens';
import { removeStorage } from './lib/storage';

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
      { route: '/tr/olmayan/sayfa' },
    );
    expect(await screen.findByRole('heading', { name: 'Sayfa bulunamadı' })).toBeInTheDocument();
  });

  it('geçersiz yasal tür 404 gösterir', async () => {
    mockFetch(api);
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/tr/legal/bilinmeyen' },
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
    expect(screen.getByRole('navigation', { name: 'Yönetim menüsü' })).toBeTruthy();
    expect(screen.getByRole('navigation', { name: 'Sayfa konumu' })).toBeTruthy();
  });

  it('adminNav öğeleri benzersiz', () => {
    const ids = allAdminNavItems.map((i) => i.id);
    expect(new Set(ids).size).toBe(ids.length);
    const tos = allAdminNavItems.map((i) => i.to);
    expect(new Set(tos).size).toBe(tos.length);
  });
});

// --- dil URL'leri (/tr /en /ar) ---
function Where() {
  const l = useLocation();
  return <output data-testid="where">{`${l.pathname}${l.search}`}</output>;
}

function renderRoutes(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch(api);
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
      <Where />
    </AuthProvider>,
    { route, lang },
  );
}

function setNavLang(language: string, languages: string[]) {
  Object.defineProperty(window.navigator, 'language', { value: language, configurable: true });
  Object.defineProperty(window.navigator, 'languages', { value: languages, configurable: true });
}

afterEach(() => setNavLang('tr-TR', ['tr-TR', 'tr']));

const where = () => screen.getByTestId('where').textContent;

describe('dil önekli rotalar', () => {
  it('/ → tarayıcı dili Türkçe iken /tr', async () => {
    renderRoutes('/');
    await screen.findByRole('heading', { level: 1, name: 'Kampüs hayatı tek uygulamada' });
    expect(where()).toBe('/tr');
  });

  it('/ → kayıtlı bu.lang önceliklidir (ar)', async () => {
    window.localStorage.setItem('bu.lang', 'ar');
    renderRoutes('/');
    await screen.findByRole('heading', { level: 1 });
    expect(where()).toBe('/ar');
  });

  it('/ → kayıt yoksa tarayıcı dili (en-GB → /en), tanınmayan dil → /tr', async () => {
    removeStorage('local', 'bu.lang'); // bellek yedeği de silinir (storage.ts)
    setNavLang('en-GB', ['en-GB', 'en']);
    renderRoutes('/');
    await screen.findByRole('heading', { level: 1 });
    expect(where()).toBe('/en');
    cleanup();
    removeStorage('local', 'bu.lang');
    setNavLang('fr-FR', ['fr-FR']);
    renderRoutes('/');
    await screen.findByRole('heading', { level: 1 });
    expect(where()).toBe('/tr');
  });

  it('eski adresler dil önekli adrese yönlenir ve sorgu korunur (/privacy → /tr/privacy)', async () => {
    renderRoutes('/privacy');
    await screen.findByRole('heading', { level: 1, name: 'Gizlilik politikası' });
    expect(where()).toBe('/tr/privacy');
    cleanup();
    renderRoutes('/delete-account');
    await screen.findByRole('heading', { level: 1, name: 'Hesap silme' });
    expect(where()).toBe('/tr/delete-account');
    cleanup();
    renderRoutes('/support/track?token=abc');
    await waitFor(() => expect(where()).toBe('/tr/support/track?token=abc'));
  });

  it('eski adres kayıtlı dile yönlenir (bu.lang=en → /en/contact)', async () => {
    window.localStorage.setItem('bu.lang', 'en');
    renderRoutes('/contact');
    await waitFor(() => expect(where()).toBe('/en/contact'));
    expect(await screen.findByRole('heading', { level: 1, name: 'Contact' })).toBeInTheDocument();
  });

  it('URL dili etkin dil olur: /en/features İngilizce, html lang/dir ve bu.lang güncellenir', async () => {
    renderRoutes('/en/features');
    await screen.findByRole('heading', { level: 1, name: 'Features' });
    expect(document.documentElement.lang).toBe('en');
    await waitFor(() => expect(window.localStorage.getItem('bu.lang')).toBe('en'));
  });

  it('/ar/... Arapça ve rtl', async () => {
    renderRoutes('/ar/features');
    await waitFor(() => expect(document.documentElement.dir).toBe('rtl'));
    expect(document.documentElement.lang).toBe('ar');
  });

  it('iç bağlantılar geçerli dilin önekini taşır', async () => {
    renderRoutes('/en/about');
    await screen.findByRole('heading', { level: 1 });
    const nav = screen.getByRole('navigation', { name: /main menu/i });
    const hrefs = within(nav).getAllByRole('link').map((a) => a.getAttribute('href'));
    expect(hrefs).toContain('/en');
    expect(hrefs).toContain('/en/features');
    expect(hrefs.every((h) => h?.startsWith('/en'))).toBe(true);
  });

  it('dil değiştirici aynı sayfanın başka dilindeki adrese götürür', async () => {
    renderRoutes('/tr/about');
    await screen.findByRole('heading', { level: 1, name: 'Hakkımızda' });
    fireEvent.change(screen.getByRole('combobox', { name: 'Dil' }), { target: { value: 'en' } });
    await waitFor(() => expect(where()).toBe('/en/about'));
    expect(document.documentElement.lang).toBe('en');
    await waitFor(() => expect(window.localStorage.getItem('bu.lang')).toBe('en'));
  });

  it('bilinmeyen dil öneki yerine yol 404 olur (/xx/foo → /tr/xx/foo)', async () => {
    renderRoutes('/xx/foo');
    expect(await screen.findByRole('heading', { name: 'Sayfa bulunamadı' })).toBeInTheDocument();
    expect(where()).toBe('/tr/xx/foo');
  });

  it('büyük harfli önek küçültülür (/EN/about → /en/about)', async () => {
    renderRoutes('/EN/about');
    await waitFor(() => expect(where()).toBe('/en/about'));
  });

  it('yönetim rotaları dil önekinden muaf ve Türkçe kalır; site dili tercihi bozulmaz', async () => {
    window.localStorage.setItem('bu.lang', 'en');
    renderRoutes('/admin/login', 'en');
    await screen.findByRole('button', { name: /giri/i });
    expect(where()).toBe('/admin/login');
    expect(document.documentElement.lang).toBe('tr');
    expect(window.localStorage.getItem('bu.lang')).toBe('en');
  });
});
