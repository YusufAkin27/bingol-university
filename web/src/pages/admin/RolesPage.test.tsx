import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminProfile, ProfileChange, RbacAdminRow, RbacMe } from '../../api/rbac';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import RolesPage from './RolesPage';

afterEach(() => vi.unstubAllGlobals());

const ALL_PERMS = [
  'dashboard.read',
  'users.read',
  'users.role',
  'rbac.manage',
  'chat.read',
  'content.read',
];

const matrix = {
  profiles: ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
  entries: [
    { permission: 'dashboard.read', profiles: ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'] },
    { permission: 'users.role', profiles: ['FULL'] },
    { permission: 'chat.read', profiles: ['FULL', 'MODERATOR'] },
  ],
};

function meOf(profile: AdminProfile, permissions: string[], userId = 1): RbacMe {
  return { userId, email: 'ben@bingol.edu.tr', displayName: 'Ben Yönetici', profile, pinned: false, permissions };
}

const admins: RbacAdminRow[] = [
  { id: 1, email: 'ben@bingol.edu.tr', displayName: 'Ben Yönetici', profile: 'FULL', pinned: false, status: 'ACTIVE', lastSeenAt: null },
  { id: 2, email: 'diger@bingol.edu.tr', displayName: 'Diğer FULL', profile: 'FULL', pinned: false, status: 'ACTIVE', lastSeenAt: null },
  { id: 3, email: 'izleyici@bingol.edu.tr', displayName: 'İzleyici Ali', profile: 'VIEWER', pinned: false, status: 'ACTIVE', lastSeenAt: null },
  { id: 4, email: 'pinli@bingol.edu.tr', displayName: 'Sabit Hesap', profile: 'FULL', pinned: true, status: 'ACTIVE', lastSeenAt: null },
];

function change(over: Partial<ProfileChange>): ProfileChange {
  return {
    id: 10,
    targetUserId: 3,
    targetEmail: 'izleyici@bingol.edu.tr',
    targetName: 'İzleyici Ali',
    fromProfile: 'VIEWER',
    toProfile: 'FULL',
    reason: 'ikinci FULL gerekli',
    proposedBy: 2,
    proposedByEmail: 'diger@bingol.edu.tr',
    proposedAt: '2026-10-28T10:00:00Z',
    expiresAt: '2026-10-29T10:00:00Z',
    status: 'PENDING',
    decidedBy: null,
    decidedAt: null,
    decisionNote: null,
    ...over,
  };
}

interface Call {
  url: string;
  method: string;
  body: unknown;
}

function setup(me: RbacMe, changes: ProfileChange[] = []) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    const body = typeof init.body === 'string' ? (JSON.parse(init.body) as unknown) : undefined;
    calls.push({ url, method, body });
    if (url.endsWith('/admin/rbac/me')) return jsonResponse(200, me);
    if (url.endsWith('/admin/rbac/matrix')) return jsonResponse(200, matrix);
    if (url.endsWith('/admin/rbac/admins')) return jsonResponse(200, admins);
    if (url.includes('/admin/rbac/changes') && method === 'GET') return jsonResponse(200, changes);
    if (url.endsWith('/admin/rbac/changes') && method === 'POST')
      return jsonResponse(201, change({ id: 11, proposedBy: 1 }));
    if (/\/admin\/rbac\/changes\/\d+\/(approve|reject)$/.test(url) && method === 'POST')
      return jsonResponse(200, change({ status: 'APPROVED' }));
    if (/\/admin\/rbac\/users\/\d+\/profile$/.test(url) && method === 'PUT') return new Response(null, { status: 204 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const rowOf = (name: string) =>
  within(screen.getByTestId('roles-admins')).getByText(name).closest('tr') as HTMLElement;

describe('Roller ve izinler sayfası (P16)', () => {
  it('matrisi salt okunur gösterir ve "Ben" kartında profili yazar', async () => {
    setup(meOf('FULL', ALL_PERMS));
    renderWithProviders(<RolesPage />);
    const table = await screen.findByTestId('roles-matrix');
    expect(within(table).getByText('users.role')).toBeInTheDocument();
    // users.role satırında yalnız FULL işaretli
    const row = table.querySelector('tr[data-perm="users.role"]') as HTMLElement;
    const marks = Array.from(row.querySelectorAll('td')).map((td) => td.getAttribute('data-yes'));
    expect(marks).toEqual(['true', 'false', 'false', 'false', 'false']);
    const meCard = await screen.findByTestId('roles-me');
    await waitFor(() => expect(meCard).toHaveTextContent('Ben Yönetici'));
    expect(meCard).toHaveTextContent('Tam yetkili (FULL)');
  });

  it('rbac.manage yoksa yönetici listesi istenmez ve açıklama gösterilir', async () => {
    const calls = setup(meOf('VIEWER', ['dashboard.read']));
    renderWithProviders(<RolesPage />);
    expect(await screen.findByText(/Yönetici listesini ve profil atamayı yalnız FULL/)).toBeInTheDocument();
    expect(screen.getByTestId('roles-matrix')).toBeInTheDocument();
    expect(calls.some((c) => c.url.endsWith('/admin/rbac/admins'))).toBe(false);
    expect(calls.some((c) => c.url.includes('/admin/rbac/changes'))).toBe(false);
  });

  it('FULL olmayan geçişi doğrudan atar (PUT), sebep ister', async () => {
    const calls = setup(meOf('FULL', ALL_PERMS));
    renderWithProviders(<RolesPage />);
    await screen.findByText('İzleyici Ali');
    const row = rowOf('İzleyici Ali');
    await userEvent.selectOptions(within(row).getByRole('combobox'), 'EDITOR');
    await userEvent.click(within(row).getByRole('button', { name: 'Profili değiştir' }));
    const dialog = await screen.findByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Profili değiştir' });
    expect(confirm).toBeDisabled(); // sebep yok
    await userEvent.type(within(dialog).getByRole('textbox'), 'görev değişikliği nedeniyle');
    await waitFor(() => expect(confirm).toBeEnabled());
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT')).toBe(true));
    const put = calls.find((c) => c.method === 'PUT');
    expect(put?.url).toMatch(/\/admin\/rbac\/users\/3\/profile$/);
    expect(put?.body).toMatchObject({ profile: 'EDITOR' });
  });

  it('FULL yapmak iki kişi onayı önerisi oluşturur: sebep + e-postayı yazarak onay ister, POST /changes', async () => {
    const calls = setup(meOf('FULL', ALL_PERMS));
    renderWithProviders(<RolesPage />);
    await screen.findByText('İzleyici Ali');
    const row = rowOf('İzleyici Ali');
    await userEvent.selectOptions(within(row).getByRole('combobox'), 'FULL');
    await userEvent.click(within(row).getByRole('button', { name: 'Onaya öner' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('ikinci bir FULL yönetici 24 saat içinde onaylamalıdır');
    const confirm = within(dialog).getByRole('button', { name: 'Onaya öner' });
    const boxes = within(dialog).getAllByRole('textbox');
    await userEvent.type(boxes[0], 'ikinci FULL yönetici gerekli');
    expect(confirm).toBeDisabled(); // e-posta henüz yazılmadı
    await userEvent.type(boxes[1], 'izleyici@bingol.edu.tr');
    await waitFor(() => expect(confirm).toBeEnabled());
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/rbac/changes'))).toBe(true));
    const post = calls.find((c) => c.method === 'POST' && c.url.endsWith('/admin/rbac/changes'));
    expect(post?.body).toMatchObject({ userId: 3, profile: 'FULL' });
    expect(calls.some((c) => c.method === 'PUT')).toBe(false);
  });

  it('kendi satırı ve sabit hesap için profil seçimi kilitlidir', async () => {
    setup(meOf('FULL', ALL_PERMS));
    renderWithProviders(<RolesPage />);
    await screen.findByText('Sabit Hesap');
    expect(within(rowOf('Sabit Hesap')).getByRole('combobox')).toBeDisabled();
    expect(within(rowOf('Ben Yönetici')).getByRole('combobox')).toBeDisabled();
    expect(within(rowOf('Diğer FULL')).getByRole('combobox')).toBeEnabled();
  });

  it('bekleyen önerinin ONAYLA düğmesi, öneren kendisiyse devre dışıdır; başkasıysa açık', async () => {
    setup(meOf('FULL', ALL_PERMS), [
      change({ id: 10, proposedBy: 1, targetName: 'Kendi Önerim' }),
      change({ id: 12, proposedBy: 2, targetName: 'Başkasının Önerisi', targetEmail: 'bas@bingol.edu.tr' }),
    ]);
    renderWithProviders(<RolesPage />);
    const card = await screen.findByTestId('roles-changes');
    await within(card).findByText('Kendi Önerim');
    const mine = within(card).getByText('Kendi Önerim').closest('tr') as HTMLElement;
    const theirs = within(card).getByText('Başkasının Önerisi').closest('tr') as HTMLElement;
    expect(within(mine).getByRole('button', { name: 'Onayla' })).toBeDisabled();
    expect(within(theirs).getByRole('button', { name: 'Onayla' })).toBeEnabled();
    // reddet: geri çekme herkese açık
    expect(within(mine).getByRole('button', { name: 'Reddet' })).toBeEnabled();
  });

  it('başkasının önerisini e-postayı yazarak onaylar (POST /approve)', async () => {
    const calls = setup(meOf('FULL', ALL_PERMS), [
      change({ id: 12, proposedBy: 2, targetName: 'Başkasının Önerisi', targetEmail: 'bas@bingol.edu.tr' }),
    ]);
    renderWithProviders(<RolesPage />);
    const card = await screen.findByTestId('roles-changes');
    const row = (await within(card).findByText('Başkasının Önerisi')).closest('tr') as HTMLElement;
    await userEvent.click(within(row).getByRole('button', { name: 'Onayla' }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Onayla' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), 'bas@bingol.edu.tr');
    await waitFor(() => expect(confirm).toBeEnabled());
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/rbac/changes/12/approve'))).toBe(true));
  });

  it('sunucu ADMIN_PERMISSION_DENIED dönerse Türkçe açıklama gösterir', async () => {
    mockFetch((url) => {
      if (url.endsWith('/admin/rbac/me')) return jsonResponse(200, meOf('FULL', ALL_PERMS));
      if (url.endsWith('/admin/rbac/matrix')) return jsonResponse(403, { code: 'ADMIN_PERMISSION_DENIED', message: 'x' });
      if (url.endsWith('/admin/rbac/admins')) return jsonResponse(200, admins);
      if (url.includes('/admin/rbac/changes')) return jsonResponse(200, []);
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<RolesPage />);
    expect(await screen.findByText(/Bu işlem için yetkiniz yok\. Yönetici profilinizi/)).toBeInTheDocument();
  });
});
