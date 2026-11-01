// Performans düzenlemeleri için regresyon testleri: CLS'siz mağaza düğmesi, hafif zemin, öncelikli logo.
import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { Logo } from './components/brand/Logo';
import { ContourBackdrop } from './components/ui';
import { StoreButton } from './pages/site/components/StoreButton';
import { renderWithProviders } from './test/utils';

describe('StoreButton pending', () => {
  it('yüklenirken "Yakında" açıklaması çizmez (yükseklik değişmez), pasif ve ekran okuyucudan gizlidir', () => {
    const { container } = renderWithProviders(<StoreButton store="android" href={null} pending />);
    expect(screen.queryByText('Yakında')).toBeNull();
    expect(screen.queryByText(/henüz yayınlanmadı/)).toBeNull();
    expect(container.querySelector('[aria-hidden="true"]')).not.toBeNull();
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
  });

  it('pending değilken bağlantı yoksa "Yakında" gösterilir', () => {
    renderWithProviders(<StoreButton store="android" href={null} />);
    expect(screen.getByText('Yakında')).toBeInTheDocument();
  });
});

describe('ContourBackdrop', () => {
  it('DOM düğümü eklemeden tek süs öğesi çizer (çizgiler statik SVG dosyasında)', () => {
    const { container } = renderWithProviders(<ContourBackdrop className="x" />);
    const el = container.firstElementChild as HTMLElement;
    expect(el).toHaveAttribute('aria-hidden', 'true');
    expect(el.className).toContain('x');
    expect(el.childElementCount).toBe(0);
  });
});

describe('Logo yükleme önceliği', () => {
  it('priority: açık ton hemen, gizli ton tembel yüklenir; priority yoksa ikisi de tembel', () => {
    const { container, unmount } = renderWithProviders(
      <Logo variant="horizontal" height={36} priority />,
    );
    let imgs = container.querySelectorAll('img');
    expect(imgs[0]).not.toHaveAttribute('loading');
    expect(imgs[1]).toHaveAttribute('loading', 'lazy');
    unmount();
    const second = renderWithProviders(
      <Logo variant="horizontal" height={36} />,
    );
    imgs = second.container.querySelectorAll('img');
    expect(imgs[0]).toHaveAttribute('loading', 'lazy');
    expect(imgs[1]).toHaveAttribute('loading', 'lazy');
  });
});
