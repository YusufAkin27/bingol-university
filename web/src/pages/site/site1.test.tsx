import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fireEvent, screen, within } from '@testing-library/react';
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
  const dir = join(process.cwd(), 'public/site/screens');
  const names = [...new Set(Object.values(SHOTS).map((s) => s.name))];

  it('her ekranın açık + koyu WebP (ve PNG yedek) dosyası vardır: ASCII ad, WebP <= 140 KB, PNG yedek <= 300 KB', () => {
    const files = readdirSync(dir);
    for (const n of names) {
      for (const theme of ['light', 'dark']) {
        for (const ext of ['webp', 'png']) {
          const f = `${n}-${theme}.${ext}`;
          expect(files, f).toContain(f);
          expect(f, f).toMatch(/^[a-z0-9-]+\.(webp|png)$/);
          expect((statSync(join(dir, f)) as unknown as { size: number }).size, f).toBeLessThanOrEqual((ext === 'webp' ? 140 : 300) * 1024);
        }
      }
    }
    for (const [id, s] of Object.entries(SHOTS)) {
      expect(s.width, id).toBe(1179);
      expect(s.height, id).toBe(2556);
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

  it('PhoneMockup: boyut öznitelikleri, çevrilmiş alt metin; öncelikli olan eager + fetchpriority, diğeri lazy; iOS çerçevesi', () => {
    const { container } = renderWithProviders(
      <>
        <PhoneMockup shot="home" priority />
        <PhoneMockup shot={'menu' as ShotId} />
      </>,
    );
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(2);
    expect(imgs[0]).toHaveAttribute('width', '1179');
    expect(imgs[0]).toHaveAttribute('height', '2556');
    expect(imgs[0].getAttribute('src')).toBe('/site/screens/home-light.webp');
    expect(imgs[0]).toHaveAttribute('loading', 'eager');
    expect(imgs[0]).toHaveAttribute('fetchpriority', 'high');
    expect(imgs[0].getAttribute('alt')).toMatch(/Ana Sayfa/);
    expect(imgs[1]).toHaveAttribute('loading', 'lazy');
    expect(imgs[1]).not.toHaveAttribute('fetchpriority');
    expect(container.querySelector('[class*="island"]')).toBeInTheDocument();
    expect(container.querySelector('[class*="bar"]')?.textContent).toContain('9:41');
    expect(container.querySelector('[class*="home"]')).toBeInTheDocument();
  });

  it('PhoneMockup: dosya yoksa önce .png yedeği, sonra boş zemin; çökmez', () => {
    const { container } = renderWithProviders(<PhoneMockup shot="home" />);
    fireEvent.error(container.querySelector('img')!);
    expect(container.querySelector('img')?.getAttribute('src')).toBe('/site/screens/home-light.png');
    fireEvent.error(container.querySelector('img')!);
    expect(container.querySelector('img')).toBeNull();
    expect(screen.getByRole('img').getAttribute('aria-label')).toMatch(/Ana Sayfa/);
  });

  it('PhoneMockup: crop peek olur ve ana gösterge çizilmez; peek verilmeyen tam boydur', () => {
    const { container } = renderWithProviders(
      <>
        <PhoneMockup shot="home" crop={0.6} />
        <PhoneMockup shot="menu" />
      </>,
    );
    const phones = container.querySelectorAll('[class*="phone"]');
    expect(phones[0].className).toMatch(/peek/);
    expect((phones[0] as HTMLElement).style.getPropertyValue('--crop-h')).not.toBe('');
    expect(phones[0].querySelector('[class*="home"]')).toBeNull();
    expect(phones[1].className).not.toMatch(/peek/);
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
    const h1 = await screen.findByRole('heading', { level: 1, name: 'Öğrencilere özel kampüs sosyal ağı' });
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const main = within(screen.getByRole('main'));
    expect(main.getByText('Bağımsız öğrenci uygulaması')).toBeInTheDocument();
    expect(main.getAllByRole('button', { name: /Yakında/ }).length).toBeGreaterThanOrEqual(2);
    expect(main.getAllByRole('img').length).toBeGreaterThanOrEqual(2);
    expect(main.getByRole('heading', { level: 3, name: 'Yemek listesi' })).toBeInTheDocument();
    // sosyal medya vurgusu + öğrencilere özel güvenli alan; Keşfet ekranı uydurma içerikli gerçek uygulama görüntüsüdür (tel kafes çizim yok)
    expect(main.getByRole('heading', { level: 2, name: 'Kampüsün sosyal tarafı' })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 3, name: 'Kampüs Forum' })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 2, name: 'Öğrencilere özel, güvenli bir alan' })).toBeInTheDocument();
    expect(main.getByRole('img', { name: /Keşfet/ })).toBeInTheDocument();
    expect(main.getAllByRole('listitem').length).toBeGreaterThanOrEqual(7);
    expect(h1).toBeInTheDocument();
  });

  it('ana sayfa: mağaza bağlantısı varsa rozet <a> olur', async () => {
    renderAt('/', 'tr', { android: 'https://play.google.com/store/apps/details?id=tr.com.bukampus.app', ios: null });
    await screen.findByRole('heading', { level: 1 });
    const link = await screen.findAllByRole('link', { name: /Google Play/ });
    expect(link[0]).toHaveAttribute('href', expect.stringContaining('play.google.com'));
  });

  it('özellikler: yedi ekran satırı + yinelenmeyen ayrıntı kartları, her başlık bir kez', async () => {
    renderAt('/features');
    await screen.findByRole('heading', { level: 1, name: 'Özellikler' });
    const main = within(screen.getByRole('main'));
    expect(main.getAllByRole('article')).toHaveLength(SHOWCASE.length + 1);
    expect(SHOWCASE).toHaveLength(7);
    expect(main.getAllByRole('heading', { level: 3 })).toHaveLength(MORE_FEATURE_IDS.length);
    expect(MORE_FEATURE_IDS.length + SHOWCASE.length).toBeGreaterThanOrEqual(14);
    expect(FEATURES.length).toBe(16);
    // telefonlar: yedi ekran satırında birer görsel (sosyal akış satırı soyut çizimdir, img değil)
    expect(main.getAllByRole('img').length).toBeGreaterThanOrEqual(7);
  });

  it('indir: iki platform, rozetler, bağımsızlık notu', async () => {
    renderAt('/download');
    await screen.findByRole('heading', { level: 1, name: 'Uygulamayı indir' });
    const main = within(screen.getByRole('main'));
    expect(main.getByRole('heading', { level: 2, name: 'Android' })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 2, name: 'iPhone ve iPad' })).toBeInTheDocument();
    expect(main.getAllByRole('button', { name: /Yakında/ })).toHaveLength(2);
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
