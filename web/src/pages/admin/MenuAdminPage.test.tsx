import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MenuAdminPage from './MenuAdminPage';
import { monthRange, validateMenuImage } from './menu/menuLogic';

describe('menuLogic', () => {
  it('ay araligini hesaplar', () => {
    expect(monthRange('2026-02')).toEqual({ from: '2026-02-01', to: '2026-02-28' });
    expect(monthRange('2028-02').to).toBe('2028-02-29');
    expect(() => monthRange('2026-13')).toThrow();
  });
  it('dosyayi dogrular', () => {
    expect(validateMenuImage({ type: 'image/gif', size: 10 })).toBe('type');
    expect(validateMenuImage({ type: 'image/png', size: 6 * 1024 * 1024 })).toBe('size');
    expect(validateMenuImage({ type: 'image/webp', size: 0 })).toBe('empty');
    expect(validateMenuImage({ type: 'image/jpeg', size: 1000 })).toBeNull();
  });
});

const days = [
  { date: '2026-02-03', items: ['Corba', 'Pilav'], imageUrl: null },
  { date: '2026-02-04', items: ['Makarna'], imageUrl: '/files/menu/a.jpg' },
];

describe('MenuAdminPage', () => {
  it('listeler, gecersiz dosyayi istemcide reddeder, gecerliyi multipart yukler, kaldirmada onay ister', async () => {
    const fetchFn = mockFetch((url, init) => {
      if (url.includes('/image') && init.method === 'PUT')
        return jsonResponse(200, { date: '2026-02-03', imageUrl: '/files/menu/b.jpg' });
      if (url.includes('/image') && init.method === 'DELETE') return jsonResponse(204);
      if (url.includes('/admin/menu')) return jsonResponse(200, days);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<MenuAdminPage />);
    const rows = await screen.findAllByTestId('menu-row');
    expect(rows).toHaveLength(2);
    expect(fetchFn.mock.calls.some(([u]) => String(u).includes('/admin/menu?from='))).toBe(true);
    expect(within(rows[1]).getByRole('img')).toHaveAttribute('src', '/files/menu/a.jpg');

    const input = within(rows[0]).getByTestId('menu-file') as HTMLInputElement;
    await userEvent.upload(input, new File(['x'], 'a.gif', { type: 'image/gif' }), { applyAccept: false });
    expect(await within(rows[0]).findByRole('alert')).toHaveTextContent('JPEG');
    expect(fetchFn.mock.calls.some(([, i]) => (i as RequestInit).method === 'PUT')).toBe(false);

    await userEvent.upload(input, new File(['x'], 'a.png', { type: 'image/png' }));
    await waitFor(() => {
      const put = fetchFn.mock.calls.find(([, i]) => (i as RequestInit).method === 'PUT');
      expect(put).toBeTruthy();
      expect((put![1] as RequestInit).body).toBeInstanceOf(FormData);
      expect(((put![1] as RequestInit).headers as Record<string, string>)['Content-Type']).toBeUndefined();
    });

    await userEvent.click(within(rows[1]).getByRole('button', { name: /Kaldır/ }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaldır' }));
    await waitFor(() =>
      expect(fetchFn.mock.calls.some(([u, i]) => String(u).includes('/2026-02-04/image') && (i as RequestInit).method === 'DELETE')).toBe(true),
    );
  });

  it('bos ayda bos durum gosterir', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<MenuAdminPage />);
    expect(await screen.findByText('Bu ay için menü yok')).toBeInTheDocument();
  });

  it('sunucu hatasini gosterir', async () => {
    mockFetch(() => jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }));
    renderWithProviders(<MenuAdminPage />);
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});
