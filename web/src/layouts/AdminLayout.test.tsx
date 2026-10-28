import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import axe from 'axe-core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../auth/AuthProvider';
import { setTokens } from '../auth/tokens';
import { AppRoutes } from '../routes';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { renderWithProviders } from '../test/utils';

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
  if (url.endsWith('/admin/me'))
    return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

/** Görünüm genişliğini taklit eder: `(min-width: Npx)` sorguları buna göre eşleşir. */
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

function open(route = '/admin/users', lang: 'tr' | 'en' = 'tr') {
  setTokens('a', 'r');
  mockFetch(api);
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route, lang },
  );
}

const usersHeading = () => screen.findByRole('heading', { level: 1, name: 'Kullanıcılar' });

beforeEach(() => setViewport(1280));
afterEach(() => vi.unstubAllGlobals());

describe('yönetim kabuğu', () => {
  it('landmark, atlama bağlantısı, kırıntı ve etkin menü öğesi var; dil seçici yok', async () => {
    open();
    await usersHeading();
    expect(screen.getByRole('link', { name: 'İçeriğe geç' })).toHaveAttribute('href', '#admin-main');
    expect(screen.getByRole('main')).toHaveAttribute('id', 'admin-main');
    expect(screen.getByRole('complementary', { name: 'Yönetim Paneli' })).toBeInTheDocument();
    const crumbs = screen.getByRole('navigation', { name: 'Sayfa konumu' });
    expect(crumbs.querySelector('[aria-current="page"]')).toHaveTextContent('Kullanıcılar');
    const menu = screen.getByRole('navigation', { name: 'Yönetim menüsü' });
    expect(within(menu).getByRole('link', { name: 'Kullanıcılar' })).toHaveAttribute('aria-current', 'page');
    // üst çubukta dil seçici yok (sayfa içeriğindeki süzgeç seçicileri ayrı)
    const topbar = screen.getAllByRole('banner')[0];
    expect(within(topbar).queryByLabelText('Dil')).toBeNull();
    expect(topbar.querySelector('select')).toBeNull();
  });

  it('site dili İngilizce olsa bile panel Türkçedir ve dil tercihi bozulmaz', async () => {
    window.localStorage.setItem('bu.lang', 'en');
    open('/admin/users', 'en');
    await usersHeading();
    expect(document.documentElement.lang).toBe('tr');
    expect(window.localStorage.getItem('bu.lang')).toBe('en');
  });

  it('menü araması aksansız yazımla süzer, boş sonuçta mesaj verir ve Esc ile temizler', async () => {
    const user = userEvent.setup();
    open();
    await usersHeading();
    const menu = screen.getByRole('navigation', { name: 'Yönetim menüsü' });
    const box = screen.getByRole('searchbox', { name: 'Menüde ara' });

    await user.type(box, 'gonderi');
    expect(within(menu).getAllByRole('link')).toHaveLength(1);
    expect(within(menu).getByRole('link', { name: 'Gönderiler' })).toBeInTheDocument();

    await user.clear(box);
    await user.type(box, 'zzzz');
    expect(within(menu).queryAllByRole('link')).toHaveLength(0);
    expect(screen.getByText('Eşleşen menü öğesi yok')).toBeInTheDocument();

    await user.keyboard('{Escape}');
    expect(box).toHaveValue('');
    expect(within(menu).getAllByRole('link').length).toBeGreaterThan(5);
  });

  it('grup başlığı menü bölümünü açıp kapatır (aria-expanded)', async () => {
    const user = userEvent.setup();
    open();
    await usersHeading();
    const menu = screen.getByRole('navigation', { name: 'Yönetim menüsü' });
    const btn = within(menu).getByRole('button', { name: /Moderasyon/ });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    await user.click(btn);
    expect(btn).toHaveAttribute('aria-expanded', 'true');
    expect(within(menu).getByRole('link', { name: 'Raporlar' })).toBeVisible();
    await user.click(btn);
    expect(btn).toHaveAttribute('aria-expanded', 'false');
  });

  it('ok tuşları menü öğeleri arasında odağı taşır', async () => {
    const user = userEvent.setup();
    open();
    await usersHeading();
    const menu = screen.getByRole('navigation', { name: 'Yönetim menüsü' });
    const box = screen.getByRole('searchbox', { name: 'Menüde ara' });
    box.focus();
    await user.keyboard('{ArrowDown}');
    expect(document.activeElement).toBe(within(menu).getAllByRole('button')[0]);
    await user.keyboard('{ArrowUp}');
    expect(document.activeElement).toBe(box);
  });

  it('dar ekranda menü çekmecede: hamburger açar, Kapat düğmesi kapatır', async () => {
    setViewport(360);
    const user = userEvent.setup();
    open();
    await usersHeading();
    expect(screen.queryByRole('button', { name: 'Menüyü kapat' })).toBeNull();
    await user.click(screen.getByRole('button', { name: 'Menüyü aç' }));
    expect(await screen.findByRole('button', { name: 'Menüyü kapat' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Menüyü kapat' }));
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Menüyü kapat' })).toBeNull());
  });

  it('orta genişlikte menü simge çubuğudur (etiketler erişilebilir ad olarak kalır)', async () => {
    setViewport(768);
    open();
    await usersHeading();
    expect(screen.queryByRole('searchbox', { name: 'Menüde ara' })).toBeNull();
    const menu = screen.getByRole('navigation', { name: 'Yönetim menüsü' });
    expect(within(menu).getByRole('link', { name: 'Raporlar' })).toHaveAttribute('title', 'Raporlar');
    expect(screen.getByRole('button', { name: 'Menüyü aç' })).toBeInTheDocument();
  });

  it('axe ihlali yok', async () => {
    const { container } = open();
    await usersHeading();
    const res = await axe.run(container, {
      rules: { 'color-contrast': { enabled: false }, region: { enabled: false } },
    });
    expect(res.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`)).toEqual([]);
  });
});
