import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n/all';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { LegalDocument } from './components/LegalDocument';
import { deleteTableKeys } from './DeleteAccountPage';

const emptyInfo = {
  appName: 'BÜ Kampüs',
  website: null,
  contactEmail: null,
  supportEmail: null,
  phone: null,
  address: null,
  social: { instagram: null, twitter: null, youtube: null },
  banner: null,
  maintenance: { enabled: false, message: null },
  languages: ['tr', 'en', 'ar'],
};

const realMatchMedia = window.matchMedia;
function mockViewport(matches: boolean) {
  window.matchMedia = ((query: string) => ({
    matches,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  })) as unknown as typeof window.matchMedia;
}
afterEach(() => {
  window.matchMedia = realMatchMedia;
});

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch((url) => (url.includes('/app/info') ? jsonResponse(200, emptyInfo) : jsonResponse(404, {})));
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route, lang },
  );
}

describe('hesap silme sayfası (Google Play veri silme gereği)', () => {
  it('silme tablosu anahtarları tr/en/ar üçünde dolu', () => {
    for (const lang of ['tr', 'en', 'ar'] as const)
      for (const k of [...deleteTableKeys(), 'pg.delete.app', 'pg.delete.app.nodev', 'pg.delete.s6.h', 'pg.delete.s6.p1']) {
        const v = (dictionaries[lang] as Record<string, string>)[k];
        expect(v?.trim(), `${lang}:${k}`).toBeTruthy();
      }
  });

  it('geliştirici adı ayardan gelir (operatorName); ayar boşsa yalnız "Bağımsız uygulama"; üniversite adı yok', async () => {
    mockFetch((url) =>
      url.includes('/app/info') ? jsonResponse(200, { ...emptyInfo, operatorName: 'Yusuf Akın' }) : jsonResponse(404, {}),
    );
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/delete-account', lang: 'tr' },
    );
    await screen.findByRole('heading', { level: 1, name: 'Hesap silme' });
    await waitFor(() =>
      expect(screen.getByTestId('delete-app-line')).toHaveTextContent(
        'Uygulama: BÜ Kampüs · Geliştirici: Yusuf Akın · Bağımsız uygulama',
      ),
    );
    expect(screen.getByTestId('delete-app-line')).not.toHaveTextContent('Bingöl Üniversitesi');
  });

  it('uygulama satırı, saklama süreleri ve /data-request yolu', async () => {
    renderAt('/delete-account');
    await screen.findByRole('heading', { level: 1, name: 'Hesap silme' });
    expect(screen.getByTestId('delete-app-line')).toHaveTextContent('Uygulama: BÜ Kampüs · Bağımsız uygulama');
    expect(screen.getByTestId('delete-app-line')).not.toHaveTextContent('Bingöl Üniversitesi');
    const table = screen.getByRole('table', { name: /silinen ve saklanan veriler/i });
    const text = table.textContent ?? '';
    for (const n of ['45 gün', '90 gün', '365 gün', '7 gün', '30 gün']) expect(text).toContain(n);
    expect(within(table).getAllByRole('columnheader')).toHaveLength(3);
    expect(screen.getAllByRole('link').some((a) => /^(\/(tr|en|ar))?\/data-request$/.test(a.getAttribute('href') ?? ''))).toBe(true);
  });
});

describe('alt bilgi', () => {
  it('iletişim bilgisi yokken başlığı boş bırakmaz: /contact yedek bağlantısı', async () => {
    renderAt('/about');
    const footer = await screen.findByRole('contentinfo');
    const heading = within(footer).getByRole('heading', { name: 'İletişim' });
    expect(heading).toBeInTheDocument();
    expect(within(footer).getByRole('link', { name: 'Bize yazın' })).toHaveAttribute('href', expect.stringMatching(/^(\/(tr|en|ar))?\/contact$/));
  });

  it('mobilde bağlantı grupları akordeondur (aria-expanded), masaüstünde düz listedir', async () => {
    mockViewport(true);
    renderAt('/about');
    const footer = await screen.findByRole('contentinfo');
    const btn = within(footer).getByRole('button', { name: 'Yasal' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    expect(within(footer).queryByRole('link', { name: 'Güvenlik' })).toBeNull();
    fireEvent.click(btn);
    expect(btn).toHaveAttribute('aria-expanded', 'true');
    expect(within(footer).getByRole('link', { name: 'Güvenlik' })).toBeInTheDocument();
  });
});

describe('yasal belge içindekiler', () => {
  const md = '## 1. Bir\n\nmetin\n\n## 2. İki\n\n| a | b |\n|---|---|\n| 1 | 2 |';

  it('mobilde "Bu sayfada" düğmesiyle açılır, bağlantıya tıklayınca kapanır', () => {
    mockViewport(true);
    renderWithProviders(<LegalDocument title="T" content={md} docLang="tr" />);
    const btn = screen.getByRole('button', { name: 'Bu sayfada' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    fireEvent.click(btn);
    expect(btn).toHaveAttribute('aria-expanded', 'true');
    fireEvent.click(screen.getByRole('link', { name: '2. İki' }));
    expect(btn).toHaveAttribute('aria-expanded', 'false');
  });

  it('masaüstünde içindekiler her zaman görünür bağlantı listesidir', () => {
    renderWithProviders(<LegalDocument title="T" content={md} docLang="tr" />);
    expect(screen.queryByRole('button', { name: 'Bu sayfada' })).toBeNull();
    expect(within(screen.getByRole('navigation', { name: 'İçindekiler' })).getAllByRole('link')).toHaveLength(2);
  });

  it('tablolar yatay kaydırma kapsayıcısındadır', () => {
    const { container } = renderWithProviders(<LegalDocument title="T" content={md} docLang="tr" />);
    const table = container.querySelector('table');
    expect(table?.parentElement?.className).toMatch(/tableWrap/);
  });
});

describe('özellikler sayfası', () => {
  it('ızgara kartları liste öğesidir ve tek h1 vardır', async () => {
    renderAt('/features');
    await screen.findByRole('heading', { level: 1, name: 'Özellikler' });
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const main = within(screen.getByRole('main'));
    expect(main.getAllByRole('listitem').length).toBeGreaterThanOrEqual(14);
  });
});
