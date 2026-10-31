import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n/all';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { SHOTS } from './components/screenshots';
import { Steps } from './components/Steps';

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

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch((url) => {
    if (url.includes('/app/info')) return jsonResponse(200, info);
    if (url.includes('/app/version')) {
      return jsonResponse(200, { updateRequired: false, updateAvailable: false, latestVersion: '1', storeUrl: null });
    }
    if (url.endsWith('/legal')) {
      return jsonResponse(200, [
        { type: 'TERMS', version: 2, lang: 'tr', title: 'Kullanım Koşulları', publishedAt: '2026-10-01T00:00:00Z' },
      ]);
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

const PAGES = ['security', 'child', 'guidelines', 'access', 'cookies'] as const;

describe('güven sayfaları (SITE3)', () => {
  it('"Kısaca" maddeleri üç dilde dolu; uçtan uca şifreleme ve uydurma iddia yok', () => {
    for (const lang of ['tr', 'en', 'ar'] as const) {
      const dict = dictionaries[lang] as Record<string, string>;
      for (const p of PAGES) {
        const keys = Object.keys(dict).filter((k) => k.startsWith(`site.trust.${p}.pt`));
        expect(keys.length, `${lang}:${p}`).toBeGreaterThanOrEqual(3);
        for (const k of keys) {
          expect(dict[k].trim(), `${lang}:${k}`).not.toBe('');
          expect(dict[k], `${lang}:${k}`).not.toMatch(/uçtan uca|end[- ]to[- ]end|من طرف إلى طرف|ISO|sertifika|certified|ödül|award/i);
        }
      }
      expect(dict['site.shot.delete.alt'].trim()).not.toBe('');
    }
  });

  it.each([
    ['/security', 'Güvenlik', 4],
    ['/child-safety', 'Çocuk güvenliği standartları', 4],
    ['/community-guidelines', 'Topluluk kuralları', 4],
    ['/accessibility', 'Erişilebilirlik beyanı', 4],
    ['/cookies', 'Çerez Politikası', 3],
  ] as const)('%s: tek h1, "Kısaca" bölümünde simgeli maddeler', async (route, h1, count) => {
    renderAt(route);
    await screen.findByRole('heading', { level: 1, name: h1 });
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    const glance = screen.getByRole('region', { name: 'Kısaca' });
    expect(within(glance).getAllByRole('listitem')).toHaveLength(count);
  });

  it('Arapça güvenlik sayfasında "باختصار" bölümü ve rtl yön', async () => {
    renderAt('/security', 'ar');
    expect(await screen.findByRole('region', { name: 'باختصار' })).toBeInTheDocument();
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('hesap silme: adımlar numaralı liste, iPhone görünümlü ekran görüntüsü boyutlu ve alt metinli, ek başlık üretmez', async () => {
    renderAt('/delete-account');
    await screen.findByRole('heading', { level: 1, name: 'Hesap silme' });
    const shot = SHOTS.delete;
    const img = await screen.findByRole('img', { name: /Hesabı sil ekranı/ });
    expect(img).toHaveAttribute('width', String(shot.width));
    expect(img).toHaveAttribute('height', String(shot.height));
    expect(img).toHaveAttribute('loading', 'lazy');
    const steps = screen.getAllByRole('listitem').filter((li) => /Hesabımı sil/.test(li.textContent ?? ''));
    expect(steps.length).toBeGreaterThan(0);
    // adım cümleleri başlık değildir (Steps stack): yalnız bölüm başlıkları h2
    expect(screen.queryByRole('heading', { level: 3, name: /Hesabımı sil/ })).toBeNull();
    // Play için gerekli içerik korunur: veri talebi bağlantısı ve silme tablosu
    expect(screen.getByRole('table')).toBeInTheDocument();
    expect(screen.getAllByRole('link').some((a) => a.getAttribute('href') === '/tr/data-request')).toBe(true);
  });

  it('Steps: stack kipi başlık yerine paragraf kullanır, varsayılan h3 kalır', () => {
    const { unmount } = renderWithProviders(<Steps stack items={[{ title: 'Bir' }, { title: 'İki' }]} />);
    expect(screen.queryAllByRole('heading')).toHaveLength(0);
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    unmount();
    renderWithProviders(<Steps items={[{ title: 'Bir', text: 'a' }]} />);
    expect(screen.getByRole('heading', { level: 3, name: 'Bir' })).toBeInTheDocument();
  });

  it('veri talebi: dört bölüm başlığı, e-posta bağlantısı ve KVKK bağlantısı', async () => {
    renderAt('/data-request');
    await screen.findByRole('heading', { level: 1, name: 'Veri talebi' });
    const main = within(screen.getByRole('main'));
    expect(main.getAllByRole('heading', { level: 2 })).toHaveLength(4);
    expect(await main.findByRole('link', { name: 'info@bingol.edu.tr' })).toHaveAttribute(
      'href',
      'mailto:info@bingol.edu.tr',
    );
    expect(screen.getAllByRole('link').some((a) => a.getAttribute('href') === '/tr/legal/kvkk')).toBe(true);
  });

  it('yasal belgeler listesi: güven sayfalarına dil önekli bağlantılar', async () => {
    renderAt('/legal');
    await screen.findByRole('heading', { level: 1, name: 'Yasal belgeler' });
    const trust = await screen.findByRole('region', { name: 'Güven ve güvenlik' });
    const hrefs = within(trust).getAllByRole('link').map((a) => a.getAttribute('href'));
    expect(hrefs).toEqual([
      '/tr/security',
      '/tr/child-safety',
      '/tr/community-guidelines',
      '/tr/accessibility',
      '/tr/cookies',
      '/tr/delete-account',
    ]);
  });
});
