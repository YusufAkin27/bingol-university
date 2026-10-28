import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import UsersPage from './UsersPage';

const row = (id: number, name: string, role = 'USER', status = 'ACTIVE') => ({
  id,
  email: `u${id}@bingol.edu.tr`,
  displayName: name,
  faculty: null,
  department: null,
  classYear: null,
  language: 'tr',
  role,
  status,
  emailVerified: true,
  createdAt: '2026-10-01T10:00:00Z',
  lastSeenAt: null,
  avatarUrl: null,
});

type Call = { url: string; init: RequestInit };
const calls = (fn: ReturnType<typeof mockFetch>): Call[] =>
  fn.mock.calls.map(([url, init]) => ({ url: String(url), init: (init ?? {}) as RequestInit }));

function server(bulkResult?: unknown) {
  return mockFetch((url, init) => {
    if (url.startsWith('/api/faculties')) return jsonResponse(200, []);
    if (url.startsWith('/api/admin/users/bulk')) return jsonResponse(200, bulkResult ?? {});
    if (url.startsWith('/api/admin/users')) {
      return jsonResponse(200, {
        items: [row(1, 'Ayşe Bir'), row(2, 'Mehmet İki'), row(3, 'Yönetici Üç', 'ADMIN')],
        page: 0,
        totalPages: 1,
        totalItems: 3,
      });
    }
    void init;
    return jsonResponse(404, { code: 'X', message: 'x' });
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('UsersPage (P09): toplu işlem ve gelişmiş süzgeç', () => {
  it('seçim yapılmadıkça toplu işlem çubuğu yoktur; seçilince 3 işlem görünür', async () => {
    server();
    renderWithProviders(<UsersPage />);
    const user = userEvent.setup();
    await screen.findByText('Ayşe Bir');
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).not.toBeInTheDocument();

    const boxes = screen.getAllByRole('checkbox', { name: 'Satırı seç' });
    await user.click(boxes[0]);
    await user.click(boxes[1]);
    const bar = screen.getByRole('region', { name: 'Toplu işlemler' });
    expect(within(bar).getByText('2 satır seçili')).toBeInTheDocument();
    expect(within(bar).getByRole('button', { name: 'Askıya al' })).toBeInTheDocument();
    expect(within(bar).getByRole('button', { name: 'Askıyı kaldır' })).toBeInTheDocument();
    expect(within(bar).getByRole('button', { name: 'Oturumları kapat' })).toBeInTheDocument();
  });

  it('toplu askı: sebep + ADMIN atlanır bilgisi; POST gövdesi ve kısmi başarı raporu', async () => {
    const f = server({
      action: 'SUSPEND',
      requested: 3,
      done: 2,
      skipped: 1,
      failed: 0,
      results: [
        { id: 1, status: 'DONE', code: null },
        { id: 2, status: 'DONE', code: null },
        { id: 3, status: 'SKIPPED', code: 'ADMIN_TARGET' },
      ],
    });
    renderWithProviders(<UsersPage />);
    const user = userEvent.setup();
    await screen.findByText('Ayşe Bir');
    for (const b of screen.getAllByRole('checkbox', { name: 'Satırı seç' })) await user.click(b);

    await user.click(within(screen.getByRole('region', { name: 'Toplu işlemler' })).getByRole('button', { name: 'Askıya al' }));
    const dialog = screen.getByRole('alertdialog');
    expect(dialog).toHaveTextContent('Yönetici hesapları');
    expect(dialog).toHaveTextContent('3 kullanıcı etkilenecek');
    const confirm = within(dialog).getByRole('button', { name: 'Seçilenleri askıya al' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Toplu spam hesapları');
    expect(confirm).toBeEnabled();
    await user.click(confirm);

    await waitFor(() => expect(calls(f).some((c) => c.url === '/api/admin/users/bulk')).toBe(true));
    const c = calls(f).find((x) => x.url === '/api/admin/users/bulk')!;
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ action: 'SUSPEND', ids: [1, 2, 3], reason: 'Toplu spam hesapları' });
    expect(decodeURIComponent((c.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('Toplu spam hesapları');

    const result = await screen.findByTestId('user-bulk-result');
    expect(result).toHaveTextContent('3 kullanıcıdan 2 işlendi, 1 atlandı, 0 başarısız.');
    expect(result).toHaveTextContent('#3: Yönetici hesabı (atlandı)');
    // seçim temizlendi
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).not.toBeInTheDocument();
  });

  it('süzgeç: kayıt/son görülme tarih aralığı API parametresine ve URL durumuna yazılır', async () => {
    const f = server();
    renderWithProviders(<UsersPage />);
    await screen.findByText('Ayşe Bir');

    fireEvent.change(screen.getByLabelText('Kayıt tarihi (başlangıç)'), { target: { value: '2026-09-01' } });
    await waitFor(() =>
      expect(calls(f).some((c) => c.url.includes('createdFrom=2026-09-01'))).toBe(true),
    );
    fireEvent.change(screen.getByLabelText('Son görülme (bitiş)'), { target: { value: '2026-10-15' } });
    await waitFor(() =>
      expect(calls(f).some((c) => c.url.includes('createdFrom=2026-09-01') && c.url.includes('seenTo=2026-10-15'))).toBe(true),
    );
    // aktif süzgeç varken "Süzgeçleri temizle" görünür
    expect(screen.getByRole('button', { name: /temizle/i })).toBeInTheDocument();
  });

  it('CSV dışa aktarma etkin süzgeçleri taşır', async () => {
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:csv', revokeObjectURL: () => {} }));
    const f = mockFetch((url) => {
      if (url.startsWith('/api/faculties')) return jsonResponse(200, []);
      if (url.startsWith('/api/admin/users/export.csv')) {
        return new Response('id,email\r\n', { status: 200, headers: { 'Content-Type': 'text/csv' } });
      }
      return jsonResponse(200, { items: [row(1, 'Ayşe Bir')], page: 0, totalPages: 1, totalItems: 1 });
    });
    renderWithProviders(<UsersPage />, { route: '/admin/users?status=SUSPENDED&seenFrom=2026-08-01' });
    const user = userEvent.setup();
    await screen.findByText('Ayşe Bir');
    await user.click(screen.getByRole('button', { name: /CSV/ }));
    await waitFor(() => expect(calls(f).some((c) => c.url.startsWith('/api/admin/users/export.csv'))).toBe(true));
    const url = calls(f).find((c) => c.url.startsWith('/api/admin/users/export.csv'))!.url;
    expect(url).toContain('status=SUSPENDED');
    expect(url).toContain('seenFrom=2026-08-01');
  });
});
