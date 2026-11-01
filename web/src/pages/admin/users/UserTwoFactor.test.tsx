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
  return fn.mock.calls.map(([url, init]) => ({ url: String(url), init: init as RequestInit }));
}

describe('UserTwoFactor', () => {
  it('açıkken durum, açılış tarihi ve güvenilen cihaz sayısını gösterir', () => {
    renderWithProviders(<UserTwoFactor user={base} />);
    expect(screen.getByText('Açık')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '2FA’yı kapat' })).toBeInTheDocument();
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
    expect(within(dialog).getByText('Gerekçeyi yazın.')).toBeInTheDocument();
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
    expect(await screen.findByText('Yetkiniz yok (users.write)')).toBeInTheDocument();
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });
});
