import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { AdminUserDetail } from '../../../api/types';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { UserActions } from './UserActions';

const base: AdminUserDetail = {
  id: 7,
  email: 'demo.007@bingol.edu.tr',
  displayName: 'Demo Yedi',
  faculty: null,
  department: null,
  classYear: null,
  language: 'tr',
  role: 'USER',
  status: 'ACTIVE',
  emailVerified: true,
  createdAt: '2026-10-01T10:00:00Z',
  lastSeenAt: null,
  avatarUrl: null,
  bio: null,
  suspendedReason: null,
  deletedAt: null,
  deviceCount: 0,
  platforms: [],
  counts: {
    feedback: 0,
    tickets: 0,
    reportsAgainst: 0,
    reportsFiled: 0,
    conversations: 0,
    communities: 0,
    eventsCreated: 0,
    bookmarks: 0,
  },
  consents: [],
  recentActivity: [],
};

function calls(fn: ReturnType<typeof mockFetch>) {
  return fn.mock.calls.map(([url, init]) => ({ url: String(url), init: init as RequestInit }));
}

describe('UserActions', () => {
  it('askıya alma: neden zorunlu, onaydan sonra POST gider ve toast gösterilir', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();

    await user.click(screen.getByRole('button', { name: 'Askıya al' }));
    const dialog = screen.getByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: 'Askıya al' }));
    expect(within(dialog).getByText('Askı nedenini yazın.')).toBeInTheDocument();
    expect(calls(f)).toHaveLength(0);

    await user.type(within(dialog).getByRole('textbox'), 'Spam');
    await user.click(within(dialog).getByRole('button', { name: 'Askıya al' }));
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    const c = calls(f)[0];
    expect(c.url).toBe('/api/admin/users/7/suspend');
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ reason: 'Spam' });
    expect(await screen.findByText('Hesap askıya alındı.')).toBeInTheDocument();
  });

  it('askıdaki hesap onayla geri açılır', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={{ ...base, status: 'SUSPENDED' }} selfId={1} />);
    const user = userEvent.setup();
    expect(screen.queryByRole('button', { name: 'Askıya al' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Askıyı kaldır' }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Askıyı kaldır' }));
    await waitFor(() => expect(calls(f)[0]?.url).toBe('/api/admin/users/7/unsuspend'));
    expect(await screen.findByText('Hesap yeniden etkinleştirildi.')).toBeInTheDocument();
  });

  it('rol değişimi onay penceresi ister ve PATCH gönderir', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    const change = screen.getByRole('button', { name: 'Rolü değiştir' });
    expect(change).toBeDisabled(); // rol aynı
    await user.selectOptions(screen.getByLabelText('Rol'), 'ADMIN');
    await user.click(change);
    expect(screen.getByRole('dialog')).toHaveTextContent('Yönetici');
    expect(calls(f)).toHaveLength(0);
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(calls(f)[0].url).toBe('/api/admin/users/7/role');
    expect(calls(f)[0].init.method).toBe('PATCH');
    expect(JSON.parse(String(calls(f)[0].init.body))).toEqual({ role: 'ADMIN' });
  });

  it('LAST_ADMIN hatası çevrilmiş mesajla gösterilir', async () => {
    mockFetch(() => jsonResponse(409, { code: 'LAST_ADMIN', message: 'x' }));
    renderWithProviders(<UserActions user={{ ...base, role: 'ADMIN' }} selfId={1} />);
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Rol'), 'USER');
    await user.click(screen.getByRole('button', { name: 'Rolü değiştir' }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Onayla' }));
    expect(await screen.findByText('Son yönetici düşürülemez.')).toBeInTheDocument();
  });

  it('CANNOT_MODIFY_SELF hatası çevrilmiş mesajla gösterilir', async () => {
    mockFetch(() => jsonResponse(400, { code: 'CANNOT_MODIFY_SELF', message: 'x' }));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Rol'), 'ADMIN');
    await user.click(screen.getByRole('button', { name: 'Rolü değiştir' }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Onayla' }));
    expect(await screen.findByText('Kendi hesabınız üzerinde bu işlemi yapamazsınız.')).toBeInTheDocument();
  });

  it('kendi hesabında rol ve silme devre dışıdır', () => {
    renderWithProviders(<UserActions user={base} selfId={7} />);
    expect(screen.getByLabelText('Rol')).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Rolü değiştir' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Hesabı sil' })).toBeDisabled();
  });

  it('silme iki adımlıdır: e-posta yazılmadan onay düğmesi kapalı', async () => {
    const f = mockFetch(() => jsonResponse(204));
    const onDeleted = vi.fn();
    renderWithProviders(<UserActions user={base} selfId={1} onDeleted={onDeleted} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Hesabı sil' }));
    const dialog = screen.getByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Hesabı sil' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'yanlis@bingol.edu.tr');
    expect(confirm).toBeDisabled();
    await user.clear(within(dialog).getByRole('textbox'));
    await user.type(within(dialog).getByRole('textbox'), 'DEMO.007@bingol.edu.tr');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(onDeleted).toHaveBeenCalled());
    expect(calls(f)[0].url).toBe('/api/admin/users/7');
    expect(calls(f)[0].init.method).toBe('DELETE');
  });

  it('silinmiş hesapta işlem düğmesi yoktur', () => {
    renderWithProviders(<UserActions user={{ ...base, status: 'DELETED' }} selfId={1} />);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });
});
