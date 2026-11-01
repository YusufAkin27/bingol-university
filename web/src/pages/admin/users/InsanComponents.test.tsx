import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminUserDetail } from '../../../api/types';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import UsersPage from '../UsersPage';
import { UserRiskCard } from './UserRiskCard';
import { UserTimeline } from './UserTimeline';
import { UsersAttention } from './UsersAttention';

afterEach(() => vi.unstubAllGlobals());

const ago = (d: number) => new Date(Date.now() - d * 86_400_000).toISOString();

const detail = (over: Partial<AdminUserDetail> = {}): AdminUserDetail =>
  ({
    id: 3,
    email: 'a@bingol.edu.tr',
    displayName: 'Ayşe',
    faculty: null,
    department: null,
    classYear: null,
    language: 'tr',
    role: 'USER',
    status: 'ACTIVE',
    emailVerified: true,
    createdAt: ago(40),
    lastSeenAt: ago(1),
    avatarUrl: null,
    bio: null,
    suspendedReason: null,
    deletedAt: null,
    deviceCount: 0,
    platforms: [],
    counts: { feedback: 0, tickets: 0, reportsAgainst: 0, reportsFiled: 0, conversations: 0, communities: 0, eventsCreated: 0, bookmarks: 0 },
    consents: [],
    recentActivity: [],
    ...over,
  }) as AdminUserDetail;

describe('UsersAttention', () => {
  const api = (adminsNo2fa: number) =>
    mockFetch((url) =>
      url.includes('/admin/users')
        ? jsonResponse(200, { items: [], page: 0, size: 1, totalItems: adminsNo2fa, totalPages: adminsNo2fa })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );

  it('sayısı olan kutuları önem sırasıyla gösterir; tıklayınca seçilen türü bildirir', async () => {
    api(2);
    const onPick = vi.fn();
    renderWithProviders(
      <UsersAttention suspended={3} unverified={40} loading={false} active={null} onPick={onPick} />,
    );
    const btns = await screen.findAllByRole('button');
    expect(btns).toHaveLength(3);
    expect(btns[0]).toHaveTextContent('Askıdaki hesap');
    expect(btns[1]).toHaveTextContent('Korumasız yönetici');
    expect(btns[2]).toHaveTextContent('E-postasını doğrulamayan');
    await userEvent.click(btns[1]);
    expect(onPick).toHaveBeenCalledWith('adminNo2fa');
  });

  it('etkin kutu aria-pressed=true taşır', async () => {
    api(0);
    renderWithProviders(<UsersAttention suspended={3} unverified={0} loading={false} active="suspended" onPick={() => {}} />);
    const btn = await screen.findByRole('button', { name: /Askıdaki hesap/ });
    expect(btn).toHaveAttribute('aria-pressed', 'true');
  });

  it('hiçbir sorun yoksa sakin bir cümle gösterir (düğme yok)', async () => {
    api(0);
    renderWithProviders(<UsersAttention suspended={0} unverified={0} loading={false} active={null} onPick={() => {}} />);
    expect(await screen.findByText(/Her şey yolunda/)).toBeInTheDocument();
    expect(screen.queryAllByRole('button')).toHaveLength(0);
  });
});

describe('UserRiskCard', () => {
  it('askıdaki + doğrulanmamış hesap: yüksek risk, nedenler ve sekme bağlantısı', async () => {
    const onGoto = vi.fn();
    renderWithProviders(
      <UserRiskCard user={detail({ status: 'SUSPENDED', emailVerified: false, role: 'ADMIN', twoFactorEnabled: false })} onGoto={onGoto} />,
    );
    expect(screen.getByText('Risk: Yüksek')).toBeInTheDocument();
    expect(screen.getByText(/Hesap askıda/)).toBeInTheDocument();
    expect(screen.getByText(/E-postası doğrulanmamış/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Güvenlik sekmesine bak' }));
    expect(onGoto).toHaveBeenCalledWith('security');
  });

  it('sorunsuz hesap: Risk Yok ve sakin cümle', () => {
    renderWithProviders(<UserRiskCard user={detail()} />);
    expect(screen.getByText('Risk: Yok')).toBeInTheDocument();
    expect(screen.getByText(/dikkat çeken bir durum yok/)).toBeInTheDocument();
  });

  it('silinmiş hesapta risk değerlendirilmez', () => {
    renderWithProviders(<UserRiskCard user={detail({ status: 'DELETED' })} />);
    expect(screen.getByText(/risk değerlendirmesi yapılmaz/)).toBeInTheDocument();
  });
});

describe('UserTimeline', () => {
  it('olayları en yeni üstte listeler; 8 üstü için "Tümünü göster"', async () => {
    const feedback = Array.from({ length: 10 }, (_, i) => ({ id: i + 1, category: 'BUG', subject: `Konu ${i + 1}`, status: 'NEW', createdAt: ago(2 + i * 0.1) }));
    const u = detail({
      extras: { devices: [], communities: [], tickets: [], feedback, reportsAgainst: [], reportsFiled: [], eventsCreated: [], eventsAttending: [] } as unknown as AdminUserDetail['extras'],
    });
    renderWithProviders(<UserTimeline user={u} />);
    const list = screen.getByRole('list', { name: 'Hesap olayları' });
    const items = within(list).getAllByRole('listitem');
    expect(items).toHaveLength(8);
    expect(items[0]).toHaveTextContent('Son görülme');
    const more = screen.getByRole('button', { name: /Tümünü göster \(12\)/ });
    await userEvent.click(more);
    expect(within(list).getAllByRole('listitem')).toHaveLength(12);
    expect(within(list).getAllByRole('listitem').at(-1)).toHaveTextContent('Hesap oluşturuldu');
  });

  it('kayıtlı olay yoksa boş durum cümlesi', () => {
    renderWithProviders(<UserTimeline user={detail({ createdAt: 'bozuk', lastSeenAt: null })} />);
    expect(screen.getByText(/henüz kayıtlı bir olay yok/)).toBeInTheDocument();
  });
});

describe('UsersPage: dikkat gerektirenler', () => {
  const perms = ['users.read', 'analytics.read'];
  const overview = {
    totalUsers: 100, verifiedUsers: 90, suspendedUsers: 4,
    newUsers: { today: 2, last7d: 10, last30d: 30 }, activeUsers: { dau: 1, wau: 2, mau: 3 }, stickiness: 0.1,
    messages: { total: 0, last24h: 0 }, communities: { active: 0, pending: 0 }, events: { upcoming: 0, pending: 0 },
    openReports: 0, openTickets: 0, newFeedback: 0, pushCampaignsSent30d: 0,
  };
  it('"Askıdaki hesap" kutusu listeyi status=SUSPENDED ile yeniden sorgular', async () => {
    const f = mockFetch((url) => {
      if (url.startsWith('/api/admin/rbac/me'))
        return jsonResponse(200, { userId: 1, email: 'a@b.c', displayName: 'Y', profile: 'FULL', pinned: true, permissions: perms });
      if (url.startsWith('/api/admin/analytics/overview')) return jsonResponse(200, overview);
      if (url.startsWith('/api/admin/analytics/registrations')) return jsonResponse(200, { points: [] });
      if (url.startsWith('/api/admin/analytics/breakdown')) return jsonResponse(200, { dimension: 'status', total: 0, items: [] });
      if (url.startsWith('/api/faculties')) return jsonResponse(200, []);
      if (url.startsWith('/api/admin/users'))
        return jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 });
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<UsersPage />, { route: '/admin/users' });
    const btn = await screen.findByRole('button', { name: /Askıdaki hesap/ });
    await userEvent.click(btn);
    await waitFor(() => expect(f.mock.calls.some(([u]) => String(u).includes('/admin/users?') && String(u).includes('status=SUSPENDED'))).toBe(true));
    expect(await screen.findByRole('button', { name: /Askıdaki hesap/ })).toHaveAttribute('aria-pressed', 'true');
  });
});
