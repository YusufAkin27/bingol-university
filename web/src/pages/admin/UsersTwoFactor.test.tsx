import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { filtersToApi, filtersToSearch, parseUserFilters } from './users/filters';
import UsersPage from './UsersPage';

afterEach(() => vi.unstubAllGlobals());

const base = {
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
};
const users = [
  {
    ...base,
    id: 1,
    email: 'a@bingol.edu.tr',
    displayName: 'Açık Kullanıcı',
    twoFactorEnabled: true,
    twoFactorTrustedDeviceCount: 2,
  },
  { ...base, id: 2, email: 'b@bingol.edu.tr', displayName: 'Kapalı Kullanıcı', twoFactorEnabled: false },
];

function api(url: string) {
  if (url.includes('/faculties')) return jsonResponse(200, []);
  if (url.includes('/admin/users'))
    return jsonResponse(200, { items: users, page: 0, totalPages: 1, totalItems: 2 });
  return jsonResponse(404);
}

describe('Kullanıcılar: iki faktörlü süzgeç ve rozet', () => {
  it('2FA sütununda açık/kapalı rozetleri (açıksa cihaz sayısı) görünür', async () => {
    mockFetch(api);
    renderWithProviders(<UsersPage />, { route: '/admin/users' });
    const row1 = (await screen.findByText('Açık Kullanıcı')).closest('tr') as HTMLElement;
    const row2 = screen.getByText('Kapalı Kullanıcı').closest('tr') as HTMLElement;
    expect(within(row1).getByText('Açık · 2 cihaz')).toBeInTheDocument();
    expect(within(row2).getByText('Kapalı')).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: '2FA' })).toBeInTheDocument();
  });

  it('"İki faktörlü" seçimi twoFactor=true parametresiyle sorgular', async () => {
    const f = mockFetch(api);
    renderWithProviders(<UsersPage />, { route: '/admin/users' });
    await screen.findByText('Açık Kullanıcı');
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('İki faktörlü'), 'true');
    await waitFor(() =>
      expect(
        f.mock.calls.some(
          ([u]) => String(u).includes('/admin/users?') && String(u).includes('twoFactor=true'),
        ),
      ).toBe(true),
    );
    await user.selectOptions(screen.getByLabelText('İki faktörlü'), 'false');
    await waitFor(() => expect(f.mock.calls.some(([u]) => String(u).includes('twoFactor=false'))).toBe(true));
  });

  it('URL’deki twoFactor değeri süzgece yansır', async () => {
    const f = mockFetch(api);
    renderWithProviders(<UsersPage />, { route: '/admin/users?twoFactor=false' });
    await screen.findByText('Açık Kullanıcı');
    expect(screen.getByLabelText('İki faktörlü')).toHaveValue('false');
    expect(f.mock.calls.some(([u]) => String(u).includes('twoFactor=false'))).toBe(true);
  });
});

describe('süzgeç yardımcıları: twoFactor', () => {
  it('URL ↔ API dönüşümü', () => {
    const f = parseUserFilters(new URLSearchParams('twoFactor=true'));
    expect(f.twoFactor).toBe('true');
    expect(filtersToApi(f).twoFactor).toBe(true);
    expect(filtersToSearch(f).get('twoFactor')).toBe('true');
    expect(filtersToApi(parseUserFilters(new URLSearchParams('twoFactor=false'))).twoFactor).toBe(false);
    expect(filtersToApi(parseUserFilters(new URLSearchParams('twoFactor=bos'))).twoFactor).toBeUndefined();
  });
});
