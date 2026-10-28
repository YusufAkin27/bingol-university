import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n';
import { COOKIE_KEY, hasAcknowledgedCookies, resetCookieChoice } from '../../lib/cookieConsent';
import { isoDate } from '../../lib/date';
import { shiftMonth } from './MenuPage';
import { SITE_GROUPS, MAIN_NAV } from '../../layouts/siteLinks';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { infoKeys } from './components/InfoPage';
import { ACCESSIBILITY_SECTIONS } from './AccessibilityPage';
import { COOKIES_SECTIONS } from './CookiesPage';
import { DELETE_SECTIONS } from './DeleteAccountPage';
import { GUIDELINES_SECTIONS } from './CommunityGuidelinesPage';
import { SECURITY_SECTIONS } from './SecurityPage';
import { BRAND_COLORS, BRAND_LOGOS, hexToRgb } from './BrandPage';
import { CHANGELOG } from './ChangelogPage';
import { HELP_CATEGORIES } from './HelpPage';
import { parseKind } from './NewsListPage';
import { neighbours, safeSourceUrl } from './NewsDetailPage';
import { classifyError } from '../../components/ErrorBoundary';

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

const news = {
  items: [
    {
      id: 7,
      type: 'DUYURU',
      title: 'Kayıt yenileme duyurusu',
      summary: 'Özet metni',
      imageUrl: null,
      publishedDate: '2026-10-01',
      url: 'http://www.bingol.edu.tr/x',
    },
  ],
  page: 0,
  totalPages: 1,
  totalItems: 1,
};

const statusBody = {
  NEWS: {
    maintenance: false,
    lastSuccessAt: '2026-10-25T21:00:00Z',
    lastAttemptAt: '2026-10-25T21:00:00Z',
    message: null,
  },
  MENU: {
    maintenance: true,
    lastSuccessAt: null,
    lastAttemptAt: '2026-10-25T21:00:00Z',
    message: 'Kaynak değişti',
  },
};

function api(url: string) {
  if (url.includes('/app/info')) return jsonResponse(200, info);
  if (url.includes('/app/version'))
    return jsonResponse(200, {
      updateRequired: false,
      updateAvailable: false,
      latestVersion: '1',
      storeUrl: null,
    });
  if (url.includes('/status')) return jsonResponse(200, statusBody);
  if (/\/news\/7/.test(url))
    return jsonResponse(200, {
      id: 7,
      type: 'DUYURU',
      title: 'Kayıt yenileme duyurusu',
      content: 'Birinci paragraf\nİkinci paragraf',
      imageUrl: null,
      publishedDate: '2026-10-01',
      url: 'http://www.bingol.edu.tr/x',
    });
  if (/\/news\/\d+/.test(url)) return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  if (url.includes('/news')) return jsonResponse(200, news);
  if (url.includes('/menu'))
    return jsonResponse(200, [{ date: isoDate(new Date()), items: ['Mercimek çorbası', 'Pilav'] }]);
  if (url.includes('/versions')) return jsonResponse(200, []);
  if (url.includes('/legal/'))
    return jsonResponse(200, {
      type: 'PRIVACY',
      version: 2,
      lang: 'tr',
      title: 'Gizlilik Politikası',
      content: '# Gizlilik\nMetin',
      publishedAt: '2026-10-01T00:00:00Z',
    });
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
}

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch(api);
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    // Site rotaları dil önekli (/tr, /en, /ar); verilmediyse testin diliyle öneklenir
    { route: /^\/(tr|en|ar)(\/|$)/.test(route) ? route : `/${lang}${route === '/' ? '' : route}`, lang },
  );
}

beforeEach(() => resetCookieChoice());
afterEach(() => vi.unstubAllGlobals());

describe('çeviri tamlığı', () => {
  it('bölüm tabanlı sayfaların tüm anahtarları üç dilde dolu', () => {
    const all = [
      ...infoKeys('cookies', COOKIES_SECTIONS),
      ...infoKeys('delete', DELETE_SECTIONS),
      ...infoKeys('accessibility', ACCESSIBILITY_SECTIONS),
      ...infoKeys('security', SECURITY_SECTIONS),
      ...infoKeys('guidelines', GUIDELINES_SECTIONS),
      ...BRAND_LOGOS.map((l) => l.name as string),
      ...CHANGELOG.flatMap((e) => [
        `pg.changelog.${e.id}.title`,
        `pg.changelog.${e.id}.date`,
        ...Array.from({ length: e.items }, (_, i) => `pg.changelog.${e.id}.l${i + 1}`),
      ]),
      ...HELP_CATEGORIES.flatMap((c) => [`pg.help.cat.${c.id}.title`, `pg.help.cat.${c.id}.text`]),
      ...SITE_GROUPS.flatMap((g) => [g.title as string, ...g.links.map((l) => l.label as string)]),
      ...MAIN_NAV.map((n) => n.label as string),
    ];
    for (const lang of ['tr', 'en', 'ar'] as const) {
      const dict = dictionaries[lang] as Record<string, string>;
      for (const key of all) expect(dict[key]?.trim(), `${lang}:${key}`).toBeTruthy();
    }
  });

  it('güvenlik metni uçtan uca şifreleme iddia etmez, sunucunun anahtarları yönettiğini söyler', () => {
    for (const lang of ['tr', 'en', 'ar'] as const)
      for (const [k, v] of Object.entries(dictionaries[lang]))
        if (k.startsWith('pg.security.'))
          expect(v, k).not.toMatch(/uçtan uca|end[- ]to[- ]end|من طرف إلى طرف/i);
    expect(dictionaries.tr['pg.security.s1.l2']).toMatch(/sunucu yönetir/);
  });

  it('herkese açık metinlerde yönetim yolu geçmez', () => {
    for (const lang of ['tr', 'en', 'ar'] as const)
      for (const [k, v] of Object.entries(dictionaries[lang]))
        if (k.startsWith('pg.')) expect(v, `${lang}:${k}`).not.toMatch(/\/admin/);
    for (const g of SITE_GROUPS) for (const l of g.links) expect(l.to.startsWith('/admin')).toBe(false);
  });
});

describe('rota eşleşmesi ve sayfalar', () => {
  const cases: [string, RegExp | string][] = [
    ['/cookies', 'Çerez Politikası'],
    ['/delete-account', 'Hesap silme'],
    ['/accessibility', 'Erişilebilirlik beyanı'],
    ['/security', 'Güvenlik'],
    ['/community-guidelines', 'Topluluk kuralları'],
    ['/help', 'Yardım merkezi'],
    ['/sitemap', 'Site haritası'],
    ['/changelog', 'Sürüm notları'],
    ['/brand', 'Basın ve marka kiti'],
  ];
  it.each(cases)('%s tek bir h1 ile açılır', async (route, name) => {
    renderAt(route);
    const h1 = await screen.findByRole('heading', { level: 1, name });
    expect(h1).toBeInTheDocument();
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    // Başlık useEffect ile sonradan yazılır; h1 görünür görünmez okumak yarışa açıktır.
    await waitFor(() => expect(document.title).toContain('BÜ Kampüs'));
  });

  it('/privacy ve /terms sürümlü sözleşme bileşenini aynı adreste gösterir', async () => {
    renderAt('/privacy');
    expect(await screen.findByRole('heading', { level: 1, name: 'Gizlilik Politikası' })).toBeInTheDocument();
    expect(document.querySelector('link[rel="canonical"]')?.getAttribute('href')).toMatch(/\/privacy$/);
  });

  it('Arapça: sayfa başlığı çevrilir ve yön rtl olur', async () => {
    renderAt('/cookies', 'ar');
    expect(
      await screen.findByRole('heading', { level: 1, name: 'سياسة ملفات تعريف الارتباط' }),
    ).toBeInTheDocument();
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('çerez sayfası zorunlu kayıtları ve "analitik yok" bilgisini söyler', async () => {
    renderAt('/cookies');
    expect(await screen.findByText(/bu\.lang/)).toBeInTheDocument();
    expect(screen.getByText(/analiz, reklam veya üçüncü taraf izleme aracı bulunmuyor/i)).toBeInTheDocument();
  });

  it('hesap silme sayfası adımları ve veri talebi bağlantısını içerir', async () => {
    renderAt('/delete-account');
    await screen.findByRole('heading', { level: 1, name: 'Hesap silme' });
    expect(screen.getAllByRole('listitem').some((li) => /Hesabımı sil/.test(li.textContent ?? ''))).toBe(
      true,
    );
    const link = screen.getAllByRole('link').find((a) => a.getAttribute('href') === '/tr/data-request');
    expect(link).toBeTruthy();
  });

  it('güvenlik sayfası iletişim adresini uygulama bilgisinden alır', async () => {
    renderAt('/security');
    await screen.findByRole('heading', { level: 1, name: 'Güvenlik' });
    const main = within(screen.getByRole('main'));
    expect(await main.findByRole('link', { name: 'info@bingol.edu.tr' })).toHaveAttribute(
      'href',
      'mailto:info@bingol.edu.tr',
    );
  });

  it('haber listesi kaynak atfı ve detay bağlantısı gösterir; detay orijinal bağlantıyı https yapar', async () => {
    renderAt('/news');
    const link = await screen.findByRole('link', { name: 'Kayıt yenileme duyurusu' });
    expect(link).toHaveAttribute('href', '/tr/news/7');
    expect(screen.queryByText(/aittir/)).toBeNull();
    expect(screen.getByText('Öne çıkan')).toBeInTheDocument();
    expect(screen.getByRole('searchbox', { name: 'Haberlerde ara' })).toBeInTheDocument();
    expect(screen.getByRole('group', { name: 'Tür filtresi' })).toBeInTheDocument();
  });

  it('haber detayı paragrafları ve orijinal bağlantıyı gösterir; bilinmeyen id bulunamadı der', async () => {
    renderAt('/news/7');
    expect(await screen.findByText('İkinci paragraf')).toBeInTheDocument();
    const orig = screen.getByRole('link', { name: /Orijinal sayfayı aç/ });
    expect(orig).toHaveAttribute('href', 'https://www.bingol.edu.tr/x');
    expect(orig).toHaveAttribute('rel', expect.stringContaining('noopener'));
  });

  it('haber detayı 404 için bulunamadı gösterir', async () => {
    renderAt('/news/99');
    expect(await screen.findByText('İçerik bulunamadı', { selector: 'h2' })).toBeInTheDocument();
  });

  it('yemek listesi günlük menüyü ve aylık görünümü gösterir', async () => {
    renderAt('/menu');
    expect(await screen.findByText('Mercimek çorbası')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Aylık' }));
    expect(await within(screen.getByRole('main')).findByRole('heading', { level: 2 })).toBeInTheDocument();
  });
});

describe('çerez tercihi', () => {
  it('bant gösterilir; "Anladım" localStorage anahtarını yazar ve bandı kapatır', async () => {
    renderAt('/about');
    const banner = await screen.findByRole('region', { name: 'Çerez bilgilendirmesi' });
    expect(within(banner).getByText(/izleme, analiz veya reklam çerezi kullanmaz/)).toBeInTheDocument();
    fireEvent.click(within(banner).getByRole('button', { name: 'Anladım' }));
    await waitFor(() => expect(screen.queryByRole('region', { name: 'Çerez bilgilendirmesi' })).toBeNull());
    expect(hasAcknowledgedCookies()).toBe(true);
    expect(window.localStorage.getItem(COOKIE_KEY)).toBe('ack:v1');
  });

  it('depolama erişimi hata verse bile bant çalışır', async () => {
    const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('kota');
    });
    renderAt('/about');
    const banner = await screen.findByRole('region', { name: 'Çerez bilgilendirmesi' });
    fireEvent.click(within(banner).getByRole('button', { name: 'Anladım' }));
    await waitFor(() => expect(screen.queryByRole('region', { name: 'Çerez bilgilendirmesi' })).toBeNull());
    spy.mockRestore();
  });

  it('çerez sayfasından bilgilendirme yeniden gösterilebilir', async () => {
    renderAt('/cookies');
    const banner = await screen.findByRole('region', { name: 'Çerez bilgilendirmesi' });
    fireEvent.click(within(banner).getByRole('button', { name: 'Anladım' }));
    const again = await screen.findByRole('button', { name: 'Bilgilendirme bandını yeniden göster' });
    fireEvent.click(again);
    expect(await screen.findByRole('region', { name: 'Çerez bilgilendirmesi' })).toBeInTheDocument();
    expect(hasAcknowledgedCookies()).toBe(false);
  });
});

describe('erişilebilirlik temel kontrolleri', () => {
  it('atlama bağlantısı, ana menü, ana alan ve alt bilgi sütunları vardır; yönetim bağlantısı yoktur', async () => {
    renderAt('/help');
    await screen.findByRole('heading', { level: 1, name: 'Yardım merkezi' });
    expect(screen.getByRole('link', { name: 'İçeriğe geç' })).toHaveAttribute('href', '#main');
    expect(screen.getByRole('navigation', { name: 'Ana menü' })).toBeInTheDocument();
    expect(screen.getByRole('main')).toHaveAttribute('id', 'main');
    for (const name of ['Kurum', 'Ürün', 'Destek', 'Yasal']) {
      expect(screen.getByRole('navigation', { name })).toBeInTheDocument();
    }
    expect(screen.getByRole('navigation', { name: 'Sayfa yolu' })).toBeInTheDocument();
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href') ?? '');
    expect(hrefs.some((h) => h.startsWith('/admin'))).toBe(false);
  });

  it('hamburger düğmesi menüyü açar ve aria-expanded günceller', async () => {
    renderAt('/help');
    const btn = await screen.findByRole('button', { name: 'Menüyü aç' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    fireEvent.click(btn);
    expect(screen.getByRole('button', { name: 'Menüyü kapat' })).toHaveAttribute('aria-expanded', 'true');
  });

  it('marka kitindeki her görselin alternatif metni vardır', async () => {
    renderAt('/brand');
    await screen.findByRole('heading', { level: 1, name: 'Basın ve marka kiti' });
    const imgs = screen.getAllByRole('img');
    expect(imgs.length).toBeGreaterThanOrEqual(BRAND_LOGOS.length);
    for (const img of imgs) expect(img.getAttribute('alt')?.trim()).toBeTruthy();
  });
});

describe('marka kiti', () => {
  it('her logo için çalışan indirme bağlantıları (download özniteliği, PNG ve varsa SVG) sunar', async () => {
    renderAt('/brand');
    await screen.findByRole('heading', { level: 1, name: 'Basın ve marka kiti' });
    const dl = screen.getAllByRole('link').filter((a) => a.hasAttribute('download'));
    expect(dl.length).toBe(BRAND_LOGOS.length + BRAND_LOGOS.filter((l) => l.svgBytes).length);
    for (const a of dl) {
      expect(a.getAttribute('href')).toMatch(/^\/brand\/[a-z-]+\.(png|svg)$/);
      expect(a.getAttribute('download')).toMatch(/^bu-kampus-/);
    }
  });
  it(
    'renk kartları hex, RGB ve kopyalama düğmesi içerir; koruma alanı ve yapılmayacaklar bölümleri vardır',
    { timeout: 20000 },
    async () => {
      renderAt('/brand');
      await screen.findByRole('heading', { level: 1, name: 'Basın ve marka kiti' });
      for (const c of BRAND_COLORS) {
        expect(screen.getByText(c.hex)).toBeInTheDocument();
        expect(screen.getByLabelText(c.hex + ' kodunu kopyala')).toBeInTheDocument();
      }
      expect(screen.getByText('Koruma alanı', { selector: 'h2' })).toBeInTheDocument();
      expect(screen.getByText('Yapmayın', { selector: 'h2' })).toBeInTheDocument();
      expect(
        await within(screen.getByRole('main')).findByRole('link', { name: 'info@bingol.edu.tr' }),
      ).toHaveAttribute('href', 'mailto:info@bingol.edu.tr');
    },
  );
  it('hexToRgb dönüştürür', () => {
    expect(hexToRgb('#F73A2E')).toBe('247, 58, 46');
  });
});

describe('haber yardımcıları ve arama', () => {
  it('neighbours önceki/sonraki ve ilgili kayıtları verir', () => {
    const list = [{ id: 5 }, { id: 4 }, { id: 3 }, { id: 2 }];
    expect(neighbours(list, 4)).toEqual({
      newer: { id: 5 },
      older: { id: 3 },
      related: [{ id: 5 }, { id: 3 }, { id: 2 }],
    });
    expect(neighbours(list, 5).newer).toBeNull();
    expect(neighbours(list, 99).older).toBeNull();
  });
  it('arama kutusu q parametresiyle API çağırır', async () => {
    const seen: string[] = [];
    mockFetch((url) => {
      seen.push(url);
      return api(url);
    });
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/news?q=kayit', lang: 'tr' },
    );
    await screen.findByRole('link', { name: 'Kayıt yenileme duyurusu' });
    expect(seen.some((u) => /news\?.*q=kayit/.test(u))).toBe(true);
    expect(screen.queryByText('Öne çıkan')).toBeNull();
  });
});

describe('taslak ibaresi', () => {
  it('herkese açık site sözlüklerinde taslak ibaresi yoktur', () => {
    for (const lang of ['tr', 'en', 'ar'] as const)
      for (const [k, v] of Object.entries(dictionaries[lang])) {
        if (k.startsWith('admin.')) continue;
        expect(v, lang + ':' + k).not.toMatch(/taslak|draft|مسودة|hukuki inceleme/i);
      }
  });
});

describe('yardımcılar', () => {
  it('parseKind yalnızca bilinen türleri kabul eder', () => {
    expect(parseKind('DUYURU')).toBe('DUYURU');
    expect(parseKind('x')).toBeUndefined();
    expect(parseKind(null)).toBeUndefined();
  });
  it('safeSourceUrl http bağlantıyı https yapar, tehlikeli şemaları reddeder', () => {
    expect(safeSourceUrl('http://a.b/c')).toBe('https://a.b/c');
    expect(safeSourceUrl('javascript:alert(1)')).toBeNull();
    expect(safeSourceUrl(null)).toBeNull();
  });
  it('shiftMonth yıl sınırını aşar', () => {
    expect(shiftMonth('2026-12', 1)).toBe('2027-01');
    expect(shiftMonth('2026-01', -1)).toBe('2025-12');
  });
  it('classifyError ağ ve bakım hatalarını ayırır', () => {
    expect(classifyError(new Error('Failed to fetch dynamically imported module'))).toBe('network');
    expect(classifyError(new Error('MAINTENANCE'))).toBe('maintenance');
    expect(classifyError(new Error('boom'))).toBe('error');
  });
});
