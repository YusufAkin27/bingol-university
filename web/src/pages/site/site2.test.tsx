// SITE2: bilgi sayfaları (SSS, Yardım, İletişim, Menü, Haberler, Basın kiti, 404) yeni tasarım dili sözleşmesi.
import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n/all';
import { isoDate } from '../../lib/date';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { AppCallout } from './components/AppCallout';
import { PageHero } from './components/PageHero';
import { SHOTS } from './components/screenshots';

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
  if (url.includes('/app/version')) {
    return jsonResponse(200, { updateRequired: false, updateAvailable: false, latestVersion: '1', storeUrl: null });
  }
  if (url.includes('/status')) return jsonResponse(200, {});
  if (url.includes('/faq')) {
    return jsonResponse(200, [{ category: 'Hesap', items: [{ id: 1, question: 'Kimler kayıt olabilir?', answer: 'Yalnızca bingol.edu.tr.' }] }]);
  }
  if (url.includes('/news')) return jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 });
  if (url.includes('/menu')) return jsonResponse(200, [{ date: isoDate(new Date()), items: ['Mercimek çorbası'] }]);
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch(api);
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route: `/${lang}${route}`, lang },
  );
}

const KEYS = [
  'site.shot.support.alt',
  'site2.help.appTitle',
  'site2.help.appText',
  'site2.menu.appTitle',
  'site2.menu.appText',
  'site2.news.appTitle',
  'site2.news.appText',
  'site2.brand.shotsTitle',
  'site2.brand.shotsText',
  'site2.notFound.try',
] as const;

describe('SITE2 metinleri ve görseli', () => {
  it('yeni anahtarlar üç dilde dolu; Arapça/İngilizce metin Türkçe ile aynı değil', () => {
    for (const k of KEYS) {
      for (const lang of ['tr', 'en', 'ar'] as const) {
        expect(dictionaries[lang][k as keyof (typeof dictionaries)['tr']], `${lang}:${k}`).toBeTruthy();
      }
      expect(dictionaries.en[k as keyof (typeof dictionaries)['en']]).not.toBe(dictionaries.tr[k as keyof (typeof dictionaries)['tr']]);
    }
  });

  it('destek ekranı kayıt defterinde, tam boy oranında', () => {
    expect(SHOTS.support).toMatchObject({ width: 600, height: 1298, peek: false });
  });

  it('metinlerde resmî uygulama iddiası yok; bağımsızlık belirtilir', () => {
    for (const lang of ['tr', 'en', 'ar'] as const) {
      const d = dictionaries[lang];
      expect(d['site2.brand.shotsText' as keyof typeof d]).toBeTruthy();
    }
    expect(dictionaries.tr['site2.brand.shotsText' as keyof (typeof dictionaries)['tr']]).toMatch(/bağımsız/);
    expect(dictionaries.en['site2.brand.shotsText' as keyof (typeof dictionaries)['en']]).toMatch(/independent/);
  });
});

describe('AppCallout ve PageHero', () => {
  it('başlık (h2), metin, gerçek ekran görüntüsü ve iki mağaza rozeti çizer; stores=false rozet çizmez', () => {
    mockFetch(api);
    const { unmount } = renderWithProviders(<AppCallout shot="support" title="Başlık" text="Metin" />);
    expect(screen.getByRole('heading', { level: 2, name: 'Başlık' })).toBeInTheDocument();
    const img = screen.getByRole('img');
    expect(img).toHaveAttribute('width', '600');
    expect(img).toHaveAttribute('height', '1298');
    expect(img.getAttribute('alt')).toMatch(/Destek ekranı/);
    expect(screen.getAllByRole('button', { name: /Yakında/ })).toHaveLength(2);
    unmount();
    renderWithProviders(<AppCallout shot="menu" title="B" text="M" stores={false} />);
    expect(screen.queryAllByRole('button', { name: /Yakında/ })).toHaveLength(0);
  });

  it('PageHero compact boyutu başlığa ayrı sınıf verir, tek h1 kalır', () => {
    renderWithProviders(<PageHero title="Uzun bir haber başlığı" size="compact" />);
    const h1 = screen.getByRole('heading', { level: 1 });
    expect(h1.className).toMatch(/compact/);
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
  });
});

describe('bilgi sayfaları (SITE2)', () => {
  it('SSS: tek h1, statik bölüm + API listesi, uygulama içi destek telefonu ve alt CTA rozetleri', async () => {
    renderAt('/faq');
    await screen.findByRole('heading', { level: 1, name: 'Sık sorulan sorular' });
    expect(await screen.findByRole('button', { name: 'Kimler kayıt olabilir?' })).toBeInTheDocument();
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const main = within(screen.getByRole('main'));
    expect(main.getByRole('img', { name: /Destek ekranı/ })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 2, name: 'Aradığınızı bulamadınız mı?' })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 2, name: 'Kampüsü cebinize alın' })).toBeInTheDocument();
    expect(main.getAllByRole('button', { name: /Yakında/ })).toHaveLength(2);
  });

  it('Yardım: kategori kartları + "Destek uygulamanın içinde" kartı (telefon + rozet)', async () => {
    renderAt('/help');
    await screen.findByRole('heading', { level: 1, name: 'Yardım merkezi' });
    const main = within(screen.getByRole('main'));
    expect(main.getByRole('heading', { level: 2, name: 'Destek uygulamanın içinde' })).toBeInTheDocument();
    expect(main.getByRole('img', { name: /Destek ekranı/ })).toBeInTheDocument();
    expect(main.getAllByRole('button', { name: /Yakında/ })).toHaveLength(2);
  });

  it('İletişim: form + uygulama içi adımlar (3 madde) + veri talebi bağlantısı, tek h1', async () => {
    renderAt('/contact');
    await screen.findByRole('heading', { level: 1, name: 'İletişim' });
    const main = within(screen.getByRole('main'));
    expect(await main.findByRole('heading', { level: 2, name: 'Bize ulaşın' })).toBeInTheDocument();
    expect(main.getByRole('heading', { level: 2, name: 'Uygulama içinden destek talebi' })).toBeInTheDocument();
    expect(main.getAllByRole('listitem').filter((li) => /Destek bölümünden yeni talep/.test(li.textContent ?? ''))).toHaveLength(1);
    expect(main.getByRole('link', { name: 'Veri talebi sayfasına git' })).toHaveAttribute('href', '/tr/data-request');
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
  });

  it('Menü: uygulama kartı (yemek ekranı) ve haber listesi: ana sayfa ekranı', async () => {
    renderAt('/menu');
    await screen.findByText('Mercimek çorbası');
    expect(within(screen.getByRole('main')).getByRole('img', { name: /Yemek listesi ekranı/ })).toBeInTheDocument();
    expect(within(screen.getByRole('main')).getByRole('heading', { level: 2, name: 'Günün menüsü cebinizde' })).toBeInTheDocument();
  });

  it('Haberler: boş listede bile uygulama kartı (Ana Sayfa ekranı) vardır', async () => {
    renderAt('/news');
    await screen.findByRole('heading', { level: 1, name: 'Haberler ve duyurular' });
    const main = within(screen.getByRole('main'));
    expect(await main.findByRole('heading', { level: 2, name: 'Haberler ve duyurular uygulamada' })).toBeInTheDocument();
    expect(main.getByRole('img', { name: /Ana Sayfa ekranı/ })).toBeInTheDocument();
  });

  it('Basın kiti: üç uygulama ekranı, hepsinin alt metni var; indirme bağlantısı sayısı değişmez', async () => {
    renderAt('/brand');
    await screen.findByRole('heading', { level: 1, name: 'Basın ve marka kiti' });
    const section = screen.getByRole('heading', { level: 2, name: 'Uygulama ekranları' }).closest('section') as HTMLElement;
    const imgs = within(section).getAllByRole('img');
    expect(imgs).toHaveLength(3);
    for (const img of imgs) expect(img.getAttribute('alt')?.trim()).toBeTruthy();
  });

  it.each([
    ['tr', 'Sayfa bulunamadı', 'Bunlara göz atabilirsiniz'],
    ['en', 'Page not found', 'You might want to try these'],
    ['ar', null, 'يمكنك تصفّح هذه الصفحات'],
  ] as const)('404 (%s): tek h1, açıklama, ana sayfa düğmesi ve dil önekli öneri bağlantıları', async (lang, h1, tryText) => {
    renderAt('/zzz-yok', lang);
    const heading = await screen.findByRole('heading', { level: 1 });
    if (h1) expect(heading).toHaveTextContent(h1);
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const nav = screen.getByRole('navigation', { name: tryText });
    const links = within(nav).getAllByRole('link');
    expect(links).toHaveLength(6);
    for (const a of links) expect(a.getAttribute('href')).toMatch(new RegExp(`^/${lang}/`));
    expect(document.head.querySelector('meta[name="robots"]')?.getAttribute('content')).toMatch(/noindex/);
    expect(screen.getByText('404')).toHaveAttribute('aria-hidden', 'true');
  });
});
