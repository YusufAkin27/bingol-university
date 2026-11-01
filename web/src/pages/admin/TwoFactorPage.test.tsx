import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import TwoFactorPage from './TwoFactorPage';

afterEach(() => vi.unstubAllGlobals());

const summary = {
  enabledCount: 42,
  totalActiveUsers: 400,
  enabledPercent: 10.5,
  enabledLast7Days: 7,
  trustedDeviceTotal: 63,
};

const row = {
  userId: 11,
  displayName: 'Ayşe Demir',
  email: 'ay***@bingol.edu.tr',
  role: 'ADMIN',
  enabledAt: '2026-10-20T09:00:00Z',
  trustedDeviceCount: 3,
  lastLoginAt: null,
};

function page(content: unknown[], extra: Record<string, unknown> = {}) {
  return { content, totalElements: content.length, totalPages: 1, number: 0, size: 20, ...extra };
}

describe('TwoFactorPage', () => {
  it('özet kartlarını ve 2FA açan kullanıcı tablosunu gösterir', async () => {
    const f = mockFetch((url) => {
      if (url.includes('/admin/two-factor/summary')) return jsonResponse(200, summary);
      if (url.includes('/admin/two-factor/users')) return jsonResponse(200, page([row]));
      return jsonResponse(404);
    });
    renderWithProviders(<TwoFactorPage />);

    expect(await screen.findByText('Ayşe Demir')).toBeInTheDocument();
    expect(screen.getByText('Açan kullanıcı')).toBeInTheDocument();
    expect(await screen.findByText('42')).toBeInTheDocument();
    expect(screen.getByText('63')).toBeInTheDocument();
    expect(screen.getByText('7')).toBeInTheDocument();
    expect(screen.getByText(/400/)).toBeInTheDocument();
    // e-posta sunucuda maskelenmiş gelir, olduğu gibi gösterilir
    expect(screen.getByText('ay***@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('Hiç')).toBeInTheDocument();
    const link = screen.getByRole('link', { name: 'Ayşe Demir ayrıntısını aç' });
    expect(link).toHaveAttribute('href', '/admin/users/11');
    expect(f.mock.calls.some(([u]) => String(u).includes('/admin/two-factor/users?page=0&size=20'))).toBe(
      true,
    );
  });

  it('arama sözcüğünü q parametresiyle gönderir ve boş durumu gösterir', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.includes('/admin/two-factor/summary')) return jsonResponse(200, summary);
      if (url.includes('q=zzz')) return jsonResponse(200, page([]));
      return jsonResponse(200, page([row]));
    });
    renderWithProviders(<TwoFactorPage />);
    await screen.findByText('Ayşe Demir');

    await user.type(screen.getByRole('searchbox'), 'zzz{Enter}');
    expect(await screen.findByText('Kullanıcı bulunamadı')).toBeInTheDocument();
    expect(f.mock.calls.some(([u]) => String(u).includes('q=zzz'))).toBe(true);
  });

  it('sayfalama: ikinci sayfayı page=1 ile ister', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.includes('/admin/two-factor/summary')) return jsonResponse(200, summary);
      if (url.includes('page=1'))
        return jsonResponse(
          200,
          page([{ ...row, userId: 12, displayName: 'Can Kaya' }], {
            number: 1,
            totalPages: 2,
            totalElements: 21,
          }),
        );
      return jsonResponse(200, page([row], { totalPages: 2, totalElements: 21 }));
    });
    renderWithProviders(<TwoFactorPage />);
    await screen.findByText('Ayşe Demir');
    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    expect(await screen.findByText('Can Kaya')).toBeInTheDocument();
    expect(f.mock.calls.some(([u]) => String(u).includes('page=1'))).toBe(true);
  });

  it('liste hatasında yeniden deneme sunar', async () => {
    mockFetch((url) =>
      url.includes('/summary')
        ? jsonResponse(200, summary)
        : jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }),
    );
    renderWithProviders(<TwoFactorPage />);
    const alert = await screen.findByRole('alert');
    await waitFor(() =>
      expect(within(alert).getByRole('button', { name: /Tekrar dene|Yeniden dene/ })).toBeInTheDocument(),
    );
  });
});
