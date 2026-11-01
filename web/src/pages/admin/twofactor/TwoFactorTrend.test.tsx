import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import TwoFactorTrend from './TwoFactorTrend';

afterEach(() => vi.unstubAllGlobals());

const ago = (d: number) => new Date(Date.now() - d * 86_400_000).toISOString();
const row = (id: number, daysAgo: number | null) => ({
  userId: id, displayName: `K${id}`, email: 'k***@bingol.edu.tr', role: 'USER',
  enabledAt: daysAgo === null ? null : ago(daysAgo), trustedDeviceCount: 1, lastLoginAt: null,
});

describe('TwoFactorTrend', () => {
  it('haftalık sayıları tablo alternatifinde ve karşılaştırma cümlesinde gösterir', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        content: [row(1, 0.2), row(2, 1), row(3, 2), row(4, 9)],
        totalElements: 4, totalPages: 1, number: 0, size: 100,
      }),
    );
    renderWithProviders(<TwoFactorTrend />);
    expect(await screen.findByText(/Son 7 günde 3 kişi korumayı açtı, önceki hafta 1 kişi: %200 fazla/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /tablo olarak göster/i }));
    const table = await screen.findByRole('table');
    expect(within(table).getAllByRole('row')).toHaveLength(9); // başlık + 8 hafta
  });

  it('hiç açan yoksa yönlendirici boş durum gösterir', async () => {
    mockFetch(() => jsonResponse(200, { content: [], totalElements: 0, totalPages: 0, number: 0, size: 100 }));
    renderWithProviders(<TwoFactorTrend />);
    expect((await screen.findAllByText(/Henüz korumayı açan kişi yok/)).length).toBeGreaterThan(0);
  });

  it('sunucu hatasında anlaşılır hata ve "Tekrar dene" çıkar', async () => {
    mockFetch(() => jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }));
    renderWithProviders(<TwoFactorTrend />);
    const alert = await screen.findByRole('alert');
    expect(within(alert).getByRole('button', { name: /Tekrar dene|Yeniden dene/ })).toBeInTheDocument();
  });
});
