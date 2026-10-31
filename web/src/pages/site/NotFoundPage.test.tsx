import { screen } from '@testing-library/react';
import { renderWithProviders } from '../../test/utils';
import NotFoundPage from './NotFoundPage';

describe('NotFoundPage (A3-12)', () => {
  it('sayfanın tek h1 başlığını verir ve noindex + açıklama yazar', () => {
    renderWithProviders(<NotFoundPage />, { route: '/tr/zzz-yok' });
    expect(screen.getByRole('heading', { level: 1, name: 'Sayfa bulunamadı' })).toBeInTheDocument();
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    expect(document.head.querySelector('meta[name="robots"]')?.getAttribute('content')).toMatch(/noindex/);
    expect(document.head.querySelector('meta[name="description"]')?.getAttribute('content')).toContain('taşınmış');
  });
});
