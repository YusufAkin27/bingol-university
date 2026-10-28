import { screen } from '@testing-library/react';
import { beforeEach } from 'vitest';
import { renderWithProviders } from '../../../test/utils';
import { StoreButton } from './StoreButton';
import { usePageMeta } from './usePageMeta';

describe('StoreButton', () => {
  it('bağlantı yoksa "Yakında" ve devre dışı', () => {
    renderWithProviders(<StoreButton store="android" href={null} />);
    const btn = screen.getByRole('button', { name: /Yakında.*Google Play/ });
    expect(btn).toHaveAttribute('aria-disabled', 'true');
    expect(btn).toHaveTextContent('Yakında');
    expect(screen.queryByRole('link')).toBeNull();
    expect(btn).toHaveAccessibleDescription(/henüz yayınlanmadı/);
  });

  it('bağlantı varsa yeni sekmede açılan gerçek bağlantı', () => {
    renderWithProviders(<StoreButton store="ios" href="https://apps.apple.com/app/id1" />);
    const link = screen.getByRole('link', { name: /Şuradan indirin.*App Store/ });
    expect(link).toHaveAttribute('href', 'https://apps.apple.com/app/id1');
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'));
    expect(screen.queryByText('Yakında')).toBeNull();
  });
});

function Meta({ title, ld }: { title: string; ld?: Record<string, unknown> }) {
  usePageMeta({ title, description: 'Açıklama metni', jsonLd: ld });
  return null;
}

describe('usePageMeta', () => {
  it('title, description, Open Graph, canonical ve JSON-LD yazar; çıkışta temizler', () => {
    document.title = 'önceki';
    const { unmount } = renderWithProviders(<Meta title="Özellikler" ld={{ '@type': 'MobileApplication' }} />, {
      route: '/features',
    });
    expect(document.title).toBe('Özellikler · BÜ Kampüs');
    const q = (s: string) => document.head.querySelector(s);
    expect(q('meta[name="description"]')).toHaveAttribute('content', 'Açıklama metni');
    expect(q('meta[property="og:title"]')).toHaveAttribute('content', 'Özellikler · BÜ Kampüs');
    expect(q('meta[property="og:locale"]')).toHaveAttribute('content', 'tr_TR');
    expect(q('link[rel="canonical"]')).toHaveAttribute('href', `${window.location.origin}/tr/features`);
    expect(q('script[type="application/ld+json"]')?.textContent).toContain('MobileApplication');
    unmount();
    expect(document.title).toBe('önceki');
    expect(q('meta[name="description"]')).toBeNull();
    expect(q('link[rel="canonical"]')).toBeNull();
    expect(q('script[type="application/ld+json"]')).toBeNull();
  });

  it('dil değişince og:locale güncellenir', () => {
    renderWithProviders(<Meta title="" />, { lang: 'ar' });
    expect(document.title).toBe('BÜ Kampüs');
    expect(document.head.querySelector('meta[property="og:locale"]')).toHaveAttribute('content', 'ar_AR');
  });
});

function RouteMeta({ route }: { route: string }) {
  usePageMeta({ route });
  return null;
}

describe('usePageMeta (rota tablosundan)', () => {
  beforeEach(() => {
    document.head.innerHTML = '';
  });

  const q = (s: string) => document.head.querySelector(s);
  const all = (s: string) => Array.from(document.head.querySelectorAll(s));

  it('başlık/açıklama routeMeta kaynağından; canonical dil önekli; hreflang + x-default; OG/Twitter mutlak', () => {
    renderWithProviders(<RouteMeta route="privacy" />, { route: '/en/privacy', lang: 'en' });
    const origin = window.location.origin;
    expect(document.title).toBe('Privacy policy · BÜ Kampüs');
    expect(q('meta[name="description"]')?.getAttribute('content')).toMatch(/privacy policy/i);
    expect(q('link[rel="canonical"]')).toHaveAttribute('href', `${origin}/en/privacy`);
    expect(all('link[rel="alternate"][hreflang]').map((l) => `${l.getAttribute('hreflang')}=${l.getAttribute('href')}`)).toEqual([
      `tr=${origin}/tr/privacy`,
      `en=${origin}/en/privacy`,
      `ar=${origin}/ar/privacy`,
      `x-default=${origin}/tr/privacy`,
    ]);
    expect(q('meta[property="og:image"]')).toHaveAttribute('content', `${origin}/og.png`);
    expect(q('meta[property="og:image:alt"]')).toBeTruthy();
    expect(q('meta[name="twitter:title"]')).toHaveAttribute('content', 'Privacy policy · BÜ Kampüs');
    expect(q('meta[name="twitter:image"]')).toHaveAttribute('content', `${origin}/og.png`);
    expect(all('meta[property="og:locale:alternate"]').length).toBe(2);
    const ld = all('script[type="application/ld+json"]').map((s) => JSON.parse(s.textContent ?? '{}') as { '@type': string });
    expect(ld.map((x) => x['@type'])).toEqual(['BreadcrumbList']);
  });

  it('önrender etiketlerini (data-pre) devralır ve çıkışta geri koymaz (bayat olmasın)', () => {
    document.head.innerHTML =
      '<meta name="description" content="ESKİ" data-pre="1"><link rel="canonical" href="https://x/eski" data-pre="1">' +
      '<script type="application/ld+json" data-pre="1">{"@type":"Organization"}</script>';
    const { unmount } = renderWithProviders(<RouteMeta route="about" />, { route: '/tr/about' });
    expect(all('meta[name="description"]').length).toBe(1);
    expect(q('meta[name="description"]')?.getAttribute('content')).not.toBe('ESKİ');
    expect(all('link[rel="canonical"]').length).toBe(1);
    expect(all('script[type="application/ld+json"]').every((s) => !s.hasAttribute('data-pre'))).toBe(true);
    unmount();
    expect(q('meta[name="description"]')).toBeNull();
    expect(q('link[rel="canonical"]')).toBeNull();
  });

  it('noindex sayfada hreflang yazılmaz', () => {
    function NoIdx() {
      usePageMeta({ title: 'Yok', noindex: true });
      return null;
    }
    renderWithProviders(<NoIdx />, { route: '/tr/zzz' });
    expect(q('meta[name="robots"]')).toHaveAttribute('content', 'noindex');
    expect(all('link[rel="alternate"][hreflang]')).toEqual([]);
  });
});
