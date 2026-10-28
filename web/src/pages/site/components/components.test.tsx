import { screen } from '@testing-library/react';
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
    expect(q('link[rel="canonical"]')).toHaveAttribute('href', `${window.location.origin}/features`);
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
