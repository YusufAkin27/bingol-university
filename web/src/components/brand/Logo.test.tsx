import { screen } from '@testing-library/react';
import { renderWithProviders } from '../../test/utils';
import { Logo } from './Logo';

describe('Logo', () => {
  it('işaret: kare ve çevirili alt metin', () => {
    renderWithProviders(<Logo variant="mark" height={40} />);
    const img = screen.getByAltText('BÜ Kampüs logosu');
    expect(img).toHaveAttribute('width', '40');
    expect(img).toHaveAttribute('height', '40');
  });

  it('yatay: oran korunur, auto iki ton basar (yalnız biri alt metinli)', () => {
    const { container } = renderWithProviders(<Logo variant="horizontal" height={36} />);
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(2);
    expect(screen.getAllByAltText('BÜ Kampüs logosu')).toHaveLength(1);
    const w = Number(imgs[0].getAttribute('width'));
    expect(imgs[0]).toHaveAttribute('height', '36');
    expect(w / 36).toBeGreaterThan(3); // geniş yatay kilit
    expect(imgs[0].className).toContain('forLight');
    expect(imgs[1].className).toContain('forDark');
  });

  it('tone=dark tek görsel basar; dikey daha yüksek orana sahiptir', () => {
    const { container } = renderWithProviders(<Logo variant="vertical" tone="dark" height={96} />);
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(1);
    expect(Number(imgs[0].getAttribute('width'))).toBeLessThan(150);
  });

  it('dil değişince alt metin çevrilir (ar)', () => {
    renderWithProviders(<Logo variant="mark" />, { lang: 'ar' });
    expect(screen.getByAltText('شعار BÜ Kampüs')).toBeInTheDocument();
  });

  it('decorative: boş alt, bağlantıda erişilebilir ad yok sayılmaz', () => {
    const { container } = renderWithProviders(<Logo variant="mark" decorative />);
    expect(container.querySelector('img')).toHaveAttribute('alt', '');
  });

  it('to verilince bağlantı olur', () => {
    renderWithProviders(<Logo to="/" tone="light" />);
    expect(screen.getByRole('link', { name: 'BÜ Kampüs logosu' })).toHaveAttribute('href', '/tr');
  });
});
