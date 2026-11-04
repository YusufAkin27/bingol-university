import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n/all';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { FEATURES, MORE_FEATURE_IDS, SHOWCASE } from './components/features';
import { PhoneMockup } from './components/PhoneMockup';
import { SHOTS, type ShotId } from './components/screenshots';
import { StoreButton } from './components/StoreButton';

const info = {
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

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr', stores?: { android: string | null; ios: string | null }) {
  mockFetch((url) => {
    if (url.includes('/app/info')) return jsonResponse(200, stores ? { ...info, stores } : info);
    if (url.includes('/app/version')) {
      return jsonResponse(200, { updateRequired: false, updateAvailable: false, latestVersion: '1', storeUrl: null });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route: `/${lang}${route === '/' ? '' : route}`, lang },
  );
}

describe('telefon görselleri (SITE1)', () => {
  const dir = join(process.cwd(), 'src/assets/site');
  const files = readdirSync(dir).filter((f) => f.endsWith('.webp'));

  it('her ekran görüntüsü ASCII adlı WebP, <= 90 KB ve en <= 900 px genişliktedir', () => {
    expect(files.length).toBeGreaterThanOrEqual(8);
    for (const f of files) {
      expect(f, f).toMatch(/^[a-z0-9-]+\.webp$/);
      expect((statSync(join(dir, f)) as unknown as { size: number }).size, f).toBeLessThanOrEqual(90 * 1024);
    }
    for (const [id, s] of Object.entries(SHOTS)) {
      expect(s.width, id).toBeLessThanOrEqual(900);
      expect(s.height, id).toBeGreaterThan(s.width);
    }
  });

  it('her ekranın alt metni üç dilde vardır', () => {
    for (const s of Object.values(SHOTS)) {
      for (const lang of ['tr', 'en', 'ar'] as const) expect(dictionaries[lang][s.alt].trim()).not.toBe('');
    }
    for (const f of SHOWCASE) {
      for (const lang of ['tr', 'en', 'ar'] as const) {
        expect(dictionaries[lang][f.title].trim()).not.toBe('');
        expect(dictionaries[lang][f.text].trim()).not.toBe('');
      }
    }
  });

  it('PhoneMockup: boyut öznitelikleri, çevrilmiş alt metin; öncelikli olan eager + fetchpriority, diğeri lazy', () => {
    const { container } = renderWithProviders(
      <>
        <PhoneMockup shot="home" priority />
        <PhoneMockup shot={'menu' as ShotId} />
      </>,
    );
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(2);
    expect(imgs[0]).toHaveAttribute('width', '900');
    expect(imgs[0]).toHaveAttribute('height', '1948');
    expect(imgs[0]).toHaveAttribute('loading', 'eager');
    expect(imgs[0]).toHaveAttribute('fetchpriority', 'high');
    expect(imgs[0].getAttribute('alt')).toMatch(/Ana Sayfa/);
    expect(imgs[1]).toHaveAttribute('loading', 'lazy');
    expect(imgs[1]).not.toHaveAttribute('fetchpriority');
    expect(container.querySelector('[class*="island"]')).toBeInTheDocument();
  });

  it('PhoneMockup: crop ve altı boş ekranlar peek olur', () => {
    const { container } = renderWithProviders(
      <>
        <PhoneMockup shot="home" crop={0.6} />
        <PhoneMockup shot="qr" />
        <PhoneMockup shot="chat" />
      </>,
    );
    const phones = container.querySelectorAll('[class*="phone"]');
    expect(phones[0].className).toMatch(/peek/);
    expect((phones[0] as HTMLElement).style.getPropertyValue('--crop-h')).not.toBe('');
    expect(phones[1].className).toMatch(/peek/);
    expect(phones[2].className).not.toMatch(/peek/);
  });
});

describe('mağaza rozeti (SITE1)', () => {
  it('marka simgesi vardır; bağlantı yokken tıklanamaz, yer tutucu adres yok', () => {
    const { container } = renderWithProviders(
      <>
        <StoreButton store="android" href={null} />
        <StoreButton store="ios" href="" />
      </>,
    );
    expect(container.querySelectorAll('svg')).toHaveLength(2);
    expect(screen.queryByRole('link')).toBeNull();
    for (const b of screen.getAllByRole('button')) expect(b).toHaveAttribute('aria-disabled', 'true');
    expect(container.querySelector('a[href]')).toBeNull();
  });

  it('bağlantı varsa gerçek <a> (yeni sekme, noopener)', () => {
    renderWithProviders(<StoreButton store="android" href="https://play.google.com/store/apps/details?id=x" size="lg" />);
    const a = screen.getByRole('link', { name: /Şuradan edinin.*Google Play/ });
    expect(a).toHaveAttribute('target', '_blank');
    expect(a).toHaveAttribute('rel', expect.stringContaining('noopener'));
  });
});

describe('vitrin sayfaları (SITE1)', () => {
  it('ana sayfa: tek h1, iki rozet ("Yakında"), bağımsızlık etiketi, 4 vitrin kartı, 3 adım', async () => {
    renderAt('/');
    const h1 = await screen.findByRole('heading', { level: 1, name: 'Kampüs hayatı tek uygulamada' });
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const main = within(screen.getByRole('main'));
    expect(main.getByText('Bağımsız öğrenci uygulaması')).toBeInTheDocument();
    expect(main.getAllByRole('button', { name: /Yakında/ }).length).toBeGreaterThanOrEqual(2);
    expect(main.getAllByRole('img').length).toBeGreaterThanOrEqual(2);
    expect(main.getByRole('heading', { level: 3, name: 'Yemek listesi' })).toBeInTheDocument();
    expect(main.getAllByRole('listitem').length).toBeGreaterThanOrEqual(7);
    expect(h1).toBeInTheDocument();
  });

  it('ana sayfa: mağaza bağlantısı varsa rozet <a> olur', async () => {
    renderAt('/', 'tr', { android: 'https://play.google.com/store/apps/details?id=tr.com.bukampus.app', ios: null });
    await screen.findByRole('heading', { level: 1 });
    const link = await screen.findAllByRole('link', { name: /Google Play/ });
    expect(link[0]).toHaveAttribute('href', expect.stringContaining('play.google.com'));
  });

  it('özellikler: sekiz ekran satırı + yinelenmeyen ayrıntı kartları, her başlık bir kez', async () => {
    renderAt('/features');
    await screen.findByRole('heading', { level: 1, name: 'Özellikler' });
    const main = within(screen.getByRole('main'));
    expect(main.getAllByRole('article')).toHaveLength(SHOWCASE.length);
    expect(SHOWCASE).toHaveLength(8);
    expect(main.getAllByRole('heading', { level: 3 })).toHaveLength(MORE_FEATURE_IDS.length);
    expect(MORE_FEATURE_IDS.length + SHOWCASE.length).toBeGreaterThanOrEqual(14);
    expect(FEATURES.length).toBe(14);
    // telefonlar: her satırda en az bir görsel (events satırında iki)
    expect(main.getAllByRole('img').length).toBeGreaterThanOrEqual(9);
  });

  it('indir: iki platform, rozetler, bağımsızlık notu', async () => {
    renderAt('/download');
    await screen.findByRole('heading', { level: 1, name: 'Uygulamayı indir' });
    const main = within(screen.getByRole('main'));
    const status = await main.findByRole('list', { name: 'Mağaza durumu' });
    expect(within(status).getAllByRole('listitem')).toHaveLength(2);
    expect(within(status).getByText('Android')).toBeInTheDocument();
    expect(within(status).getByText('iPhone ve iPad')).toBeInTheDocument();
    // bağlantılar yüklenirken rozetler pasif/gizlidir (pending, CLS); yüklenince "Yakında" düğmeleri oluşur
    expect(await main.findAllByRole('button', { name: /Yakında/ })).toHaveLength(2);
    expect(main.getByText(/resmî uygulaması değildir/)).toBeInTheDocument();
  });

  it('hakkımızda: bağımsız uygulama notu ve değerler (üç dilde)', async () => {
    renderAt('/about');
    await screen.findByRole('heading', { level: 1, name: 'Hakkımızda' });
    expect(screen.getByText(/bağımsız bir öğrenci uygulamasıdır/)).toBeInTheDocument();
    for (const lang of ['tr', 'en', 'ar'] as const) {
      expect(dictionaries[lang]['site.about.whoText']).not.toMatch(/üniversite projesi|university project/);
    }
  });

  it('alt bilgide bağımsızlık notu ve mağaza rozetleri vardır; en/ar sayfaları da açılır', async () => {
    renderAt('/features', 'en');
    await screen.findByRole('heading', { level: 1, name: 'Features' });
    const footer = screen.getByRole('contentinfo');
    expect(within(footer).getByText(/not the official app/)).toBeInTheDocument();
    expect(within(footer).getAllByRole('button', { name: /Coming soon/ })).toHaveLength(2);
  });
});
