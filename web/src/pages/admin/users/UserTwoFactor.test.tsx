import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminUserDetail } from '../../../api/types';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { UserTwoFactor } from './UserTwoFactor';

afterEach(() => vi.unstubAllGlobals());

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
  twoFactorEnabled: true,
  twoFactorTrustedDeviceCount: 4,
  twoFactorEnabledAt: '2026-10-20T09:00:00Z',
};

function calls(fn: ReturnType<typeof mockFetch>) {
  // PermissionButton izinleri /admin/rbac/me'den okur; yazma çağrıları bundan ayrı sayılır
  return fn.mock.calls
    .map(([url, init]) => ({ url: String(url), init: init as RequestInit }))
    .filter((c) => !c.url.endsWith('/admin/rbac/me'));
}

describe('UserTwoFactor', () => {
  it('açıkken durum, açılış tarihi ve güvenilen cihaz sayısını gösterir', () => {
    renderWithProviders(<UserTwoFactor user={base} />);
    expect(screen.getByText('Açık')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '2FA’yı kapat' })).toBeInTheDocument();
  });

  it('kendi hesabında kapatma düğmesi yerine açıklama gösterilir (sunucu 403 ADMIN_SELF_FORBIDDEN verir)', () => {
    renderWithProviders(<UserTwoFactor user={base} isSelf />);
    expect(screen.queryByRole('button', { name: '2FA’yı kapat' })).not.toBeInTheDocument();
    expect(screen.getByText(/Kendi iki faktörlü doğrulamanızı panelden kapatamazsınız/)).toBeInTheDocument();
  });

  it('düğme users.2fa iznine bağlıdır: izin yoksa devre dışı kalır', async () => {
    mockFetch((url) =>
      String(url).endsWith('/admin/rbac/me')
        ? jsonResponse(200, { profile: 'MODERATOR', permissions: ['users.read', 'users.write'], pinned: false })
        : jsonResponse(204),
    );
    renderWithProviders(<UserTwoFactor user={base} />);
    await waitFor(() => expect(screen.getByRole('button', { name: '2FA’yı kapat' })).toBeDisabled());
  });

  it('sunucu FULL yönetici hedefini reddederse mesaj gösterilir', async () => {
    mockFetch(() => jsonResponse(403, { code: 'TWO_FACTOR_ADMIN_FORBIDDEN', message: 'FULL yönetici hesabı' }));
    renderWithProviders(<UserTwoFactor user={{ ...base, role: 'ADMIN' }} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: '2FA’yı kapat' }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByRole('textbox'), 'Gerekçe yeterli');
    await user.click(within(dialog).getByRole('button', { name: '2FA’yı kapat' }));
    expect(await screen.findByText(/FULL yönetici hesabı/)).toBeInTheDocument();
  });

  it('kapalıyken kapatma eylemi yoktur', () => {
    renderWithProviders(<UserTwoFactor user={{ ...base, twoFactorEnabled: false }} />);
    expect(screen.getByText('Kapalı')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '2FA’yı kapat' })).not.toBeInTheDocument();
  });

  it('alan hiç gelmezse (eski sunucu) kapalı sayılır', () => {
    const { twoFactorEnabled: _t, ...rest } = base;
    renderWithProviders(<UserTwoFactor user={rest as AdminUserDetail} />);
    expect(screen.getByText('Kapalı')).toBeInTheDocument();
  });

  it('gerekçe zorunlu; onaydan sonra POST gerekçeyle gider', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserTwoFactor user={base} />);
    const user = userEvent.setup();

    await user.click(screen.getByRole('button', { name: '2FA’yı kapat' }));
    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveTextContent('e-postasına erişemediğinde');
    await user.click(within(dialog).getByRole('button', { name: '2FA’yı kapat' }));
    expect(within(dialog).getByText('Gerekçeyi yazın (en az 5 karakter).')).toBeInTheDocument();
    expect(calls(f)).toHaveLength(0);

    await user.type(within(dialog).getByRole('textbox'), 'E-postasına erişemiyor');
    await user.click(within(dialog).getByRole('button', { name: '2FA’yı kapat' }));
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    const c = calls(f)[0];
    expect(c.url).toBe('/api/admin/users/7/two-factor/disable');
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ reason: 'E-postasına erişemiyor' });
    expect(await screen.findByText('İki faktörlü doğrulama kapatıldı.')).toBeInTheDocument();
  });

  it('sunucu hatasını (yetki) toast olarak gösterir ve pencere açık kalır', async () => {
    mockFetch(() =>
      jsonResponse(403, { code: 'ADMIN_PERMISSION_DENIED', message: 'Yetkiniz yok (users.write)' }),
    );
    renderWithProviders(<UserTwoFactor user={base} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: '2FA’yı kapat' }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByRole('textbox'), 'Gerekçe');
    await user.click(within(dialog).getByRole('button', { name: '2FA’yı kapat' }));
    expect(await screen.findByText(/Bu işlem için yetkiniz yok/)).toBeInTheDocument();
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });
});
