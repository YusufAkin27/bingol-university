import { screen } from '@testing-library/react';
import { renderWithProviders } from '../../test/utils';
import { Logo } from './Logo';

describe('Logo', () => {
  it('işaret: yalnız glif, oran korunur, çevirili alt metin', () => {
    const { container } = renderWithProviders(<Logo variant="mark" height={40} />);
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(2); // auto: açık + koyu glif
    expect(screen.getAllByAltText('BÜ Kampüs logosu')).toHaveLength(2); // iki tonun da alt metni var (koyu temada bağlantı adı boş kalmaz)
    expect(imgs[0]).toHaveAttribute('height', '40');
    expect(Number(imgs[0].getAttribute('width')) / 40).toBeGreaterThan(1.2); // geniş BÜ glifi
    expect(container.textContent).toBe('');
  });

  it('yatay: auto iki tonu basar (açık/koyu), yanında Kampüs yazısı vardır', () => {
    const { container } = renderWithProviders(<Logo variant="horizontal" height={36} />);
    const imgs = container.querySelectorAll('img');
    expect(imgs).toHaveLength(2);
    expect(imgs[0].className).toContain('forLight');
    expect(imgs[1].className).toContain('forDark');
    expect(container.textContent).toBe('Kampüs');
    expect(container.querySelector('[aria-hidden="true"]:not(img)')).not.toBeNull();
  });

  it('tone=dark tek görsel (beyaz glif) basar; dikey düzen işaretlenir', () => {
    const { container } = renderWithProviders(<Logo variant="vertical" tone="dark" height={96} />);
    expect(container.querySelectorAll('img')).toHaveLength(1);
    expect(container.firstElementChild).toHaveAttribute('data-variant', 'vertical');
  });

  it('dil değişince alt metin çevrilir (ar)', () => {
    renderWithProviders(<Logo variant="mark" />, { lang: 'ar' });
    expect(screen.getAllByAltText('شعار BÜ Kampüs').length).toBeGreaterThan(0);
  });

  it('decorative: boş alt', () => {
    const { container } = renderWithProviders(<Logo variant="mark" decorative />);
    container.querySelectorAll('img').forEach((i) => expect(i).toHaveAttribute('alt', ''));
  });

  it('to verilince bağlantı olur', () => {
    renderWithProviders(<Logo to="/" tone="light" />);
    expect(screen.getByRole('link', { name: 'BÜ Kampüs logosu' })).toHaveAttribute('href', '/tr');
  });
});
