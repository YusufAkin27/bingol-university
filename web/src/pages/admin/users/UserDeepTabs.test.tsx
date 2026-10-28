import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminUserDetail } from '../../../api/types';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { UserDeepTabs } from './UserDeepTabs';

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
  avatarUrl: '/files/avatars/a.jpg',
  bio: 'uygunsuz biyografi',
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

const FULL_TOKEN = 'fcm-tam-token-HICBIR-ZAMAN-GOSTERILMEZ-ABC123';

type Call = { url: string; init: RequestInit };
function calls(fn: ReturnType<typeof mockFetch>): Call[] {
  return fn.mock.calls.map(([url, init]) => ({ url: String(url), init: (init ?? {}) as RequestInit }));
}
const hdr = (c: Call, name: string) => (c.init.headers as Record<string, string> | undefined)?.[name];
const reasonOf = (c: Call) => decodeURIComponent(hdr(c, 'X-Admin-Reason') ?? '');

async function openTab(user: ReturnType<typeof userEvent.setup>, name: string) {
  await user.click(screen.getByRole('tab', { name }));
}

afterEach(() => vi.unstubAllGlobals());

describe('UserDeepTabs', () => {
  it('beş sekme gösterir; silinmiş hesapta yalnız bilgi notu', () => {
    mockFetch(() => jsonResponse(200, {}));
    const { unmount } = renderWithProviders(<UserDeepTabs user={base} />);
    expect(screen.getAllByRole('tab').map((t) => t.textContent)).toEqual([
      'Profil müdahalesi',
      'Oturumlar',
      'Cihazlar',
      'Bildirimler',
      'Veri dışa aktarma',
    ]);
    unmount();
    renderWithProviders(<UserDeepTabs user={{ ...base, status: 'DELETED' }} />);
    expect(screen.queryByRole('tab')).not.toBeInTheDocument();
    expect(screen.getByText(/Silinmiş \(anonimleştirilmiş\) hesapta/)).toBeInTheDocument();
  });

  it('profil: biyografi temizleme sebepsiz onaylanamaz; sonra PATCH sebep başlığıyla gider', async () => {
    const f = mockFetch(() => jsonResponse(200, { avatarCleared: false, bioCleared: true, displayNameChanged: false }));
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();

    await user.click(screen.getByRole('button', { name: 'Biyografiyi temizle' }));
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Biyografiyi temizle' });
    expect(confirm).toBeDisabled();
    await user.click(confirm);
    expect(calls(f)).toHaveLength(0);

    await user.type(within(dialog).getByRole('textbox'), 'Kurallara aykırı içerik');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    const c = calls(f)[0];
    expect(c.url).toBe('/api/admin/users/7/profile');
    expect(c.init.method).toBe('PATCH');
    expect(JSON.parse(String(c.init.body))).toEqual({ clearBio: true });
    expect(reasonOf(c)).toBe('Kurallara aykırı içerik');
    expect(hdr(c, 'Idempotency-Key')).toBeTruthy();
    expect(await screen.findByText('Biyografi temizlendi.')).toBeInTheDocument();
  });

  it('profil: avatar yoksa temizleme düğmesi kapalı; ad değişikliği için yeni ad gerekir', async () => {
    const f = mockFetch(() => jsonResponse(200, { avatarCleared: false, bioCleared: false, displayNameChanged: true }));
    renderWithProviders(<UserDeepTabs user={{ ...base, avatarUrl: null, bio: null }} />);
    const user = userEvent.setup();
    expect(screen.getByRole('button', { name: 'Fotoğrafı temizle' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Biyografiyi temizle' })).toBeDisabled();

    const change = screen.getByRole('button', { name: 'Adı değiştir' });
    expect(change).toBeDisabled();
    await user.type(screen.getByLabelText('Yeni görünen ad'), 'Düzeltilmiş Ad');
    await user.click(change);
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByRole('textbox'), 'Taklit eden ad');
    await user.click(within(dialog).getByRole('button', { name: 'Adı değiştir' }));
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(JSON.parse(String(calls(f)[0].init.body))).toEqual({ displayName: 'Düzeltilmiş Ad' });
  });

  it('oturumlar: liste gelir, tek oturum sebep + onayla sonlandırılır', async () => {
    const f = mockFetch((_url, init) => {
      if (init.method === 'DELETE') return jsonResponse(204);
      return jsonResponse(200, {
        total: 2,
        items: [
          { id: 'aaaaaaaaaaaaaaaa', client: 'mobile', createdAt: '2026-10-27T10:00:00Z', expiresAt: '2026-11-26T10:00:00Z' },
          { id: 'bbbbbbbbbbbbbbbb', client: 'web', createdAt: '2026-10-26T10:00:00Z', expiresAt: null },
        ],
      });
    });
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();
    await openTab(user, 'Oturumlar');

    const rows = await screen.findAllByTestId('session-row');
    expect(rows).toHaveLength(2);
    expect(within(rows[0]).getByText('Mobil')).toBeInTheDocument();
    expect(calls(f)[0].url).toBe('/api/admin/users/7/sessions');

    await user.click(within(rows[0]).getByRole('button', { name: 'Sonlandır' }));
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Oturumu sonlandır' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Şüpheli oturum');
    await user.click(confirm);
    await waitFor(() => expect(calls(f).some((c) => c.init.method === 'DELETE')).toBe(true));
    const del = calls(f).find((c) => c.init.method === 'DELETE')!;
    expect(del.url).toBe('/api/admin/users/7/sessions/aaaaaaaaaaaaaaaa');
    expect(reasonOf(del)).toBe('Şüpheli oturum');
  });

  it('cihazlar: yalnız belirteç sonu görünür, tam belirteç asla; silme sebep ister', async () => {
    const f = mockFetch((_url, init) => {
      if (init.method === 'DELETE') return jsonResponse(204);
      return jsonResponse(200, [
        {
          id: 3,
          platform: 'ANDROID',
          appVersion: '2.0.1',
          locale: 'tr',
          tokenTail: FULL_TOKEN.slice(-6),
          createdAt: '2026-10-01T10:00:00Z',
          lastSeenAt: '2026-10-27T10:00:00Z',
        },
      ]);
    });
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();
    await openTab(user, 'Cihazlar');

    const row = await screen.findByTestId('push-device-row');
    expect(within(row).getByTestId('token-tail')).toHaveTextContent('…ABC123');
    expect(document.body.textContent).not.toContain('HICBIR-ZAMAN');
    expect(within(row).getByText('Android')).toBeInTheDocument();

    await user.click(within(row).getByRole('button', { name: 'Kaydı sil' }));
    const dialog = screen.getByRole('alertdialog');
    expect(dialog).toHaveTextContent('…ABC123');
    const confirm = within(dialog).getByRole('button', { name: 'Kaydı sil' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Eski cihaz temizliği');
    await user.click(confirm);
    await waitFor(() => expect(calls(f).some((c) => c.init.method === 'DELETE')).toBe(true));
    const del = calls(f).find((c) => c.init.method === 'DELETE')!;
    expect(del.url).toBe('/api/admin/users/7/push-devices/3');
    expect(reasonOf(del)).toBe('Eski cihaz temizliği');
  });

  it('bildirimler: salt okunur liste; "yalnız okunmamışlar" süzgeci sunucuya gider', async () => {
    const f = mockFetch(() =>
      jsonResponse(200, {
        items: [
          { id: 9, type: 'SYSTEM', subtype: null, title: 'Hesabınız yeniden etkinleştirildi', body: 'Hoş geldiniz', read: false, groupCount: 1, createdAt: '2026-10-27T10:00:00Z', readAt: null },
          { id: 8, type: 'NEWS', subtype: null, title: 'Yeni haber', body: null, read: true, groupCount: 1, createdAt: '2026-10-26T10:00:00Z', readAt: '2026-10-26T11:00:00Z' },
        ],
        page: 0,
        totalPages: 1,
        totalItems: 2,
      }),
    );
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();
    await openTab(user, 'Bildirimler');

    const rows = await screen.findAllByTestId('notif-row');
    expect(rows).toHaveLength(2);
    expect(within(rows[0]).getByText('Okunmadı')).toBeInTheDocument();
    expect(within(rows[1]).getByText('Okundu')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /sil|temizle/i })).not.toBeInTheDocument();
    expect(calls(f)[0].url).toBe('/api/admin/users/7/notifications?page=0&size=20');

    await user.click(screen.getByRole('checkbox', { name: 'Yalnız okunmamışlar' }));
    await waitFor(() => expect(calls(f).some((c) => c.url.includes('unread=true'))).toBe(true));
  });

  it('dışa aktarma: iki aşamalı onay (kutu → sebep ≥20 + kimlik yazma), başlıklar ve indirme', async () => {
    const createObjectURL = vi.fn(() => 'blob:x');
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL, revokeObjectURL: vi.fn() }));
    const f = mockFetch(
      () => new Response(JSON.stringify({ subjectUserId: 7 }), { status: 200, headers: { 'Content-Type': 'application/json' } }),
    );
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();
    await openTab(user, 'Veri dışa aktarma');

    // 1. aşama: yetki onay kutusu işaretlenmeden başlatılamaz
    const start = screen.getByRole('button', { name: 'Dışa aktarmayı başlat' });
    expect(start).toBeDisabled();
    await user.click(screen.getByRole('checkbox'));
    expect(start).toBeEnabled();
    await user.click(start);

    // 2. aşama: kısa sebep + yanlış kimlik ile onay kapalı
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Dışa aktar' });
    const [reasonBox, idBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Çok kısa sebep');
    await user.type(idBox, '7');
    expect(confirm).toBeDisabled(); // sebep < 20 karakter
    await user.clear(reasonBox);
    await user.type(reasonBox, 'KVKK m.11 başvurusu 2026/118 sayılı');
    await user.clear(idBox);
    await user.type(idBox, '8');
    expect(confirm).toBeDisabled(); // kimlik yanlış
    await user.clear(idBox);
    await user.type(idBox, '7');
    expect(confirm).toBeEnabled();
    expect(calls(f)).toHaveLength(0);

    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    const c = calls(f)[0];
    expect(c.url).toBe('/api/admin/users/7/export');
    expect(c.init.method).toBe('POST');
    expect(hdr(c, 'X-Admin-Confirm')).toBe('7');
    expect(reasonOf(c)).toBe('KVKK m.11 başvurusu 2026/118 sayılı');
    await waitFor(() => expect(createObjectURL).toHaveBeenCalled());
    expect(await screen.findByText('Dışa aktarma indirildi.')).toBeInTheDocument();
  });

  it('dışa aktarma: günlük sınır (429) çevrilmiş mesajla gösterilir', async () => {
    mockFetch(() => jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' }));
    renderWithProviders(<UserDeepTabs user={base} />);
    const user = userEvent.setup();
    await openTab(user, 'Veri dışa aktarma');
    await user.click(screen.getByRole('checkbox'));
    await user.click(screen.getByRole('button', { name: 'Dışa aktarmayı başlat' }));
    const dialog = screen.getByRole('alertdialog');
    const [reasonBox, idBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'KVKK m.11 başvurusu 2026/118 sayılı');
    await user.type(idBox, '7');
    await user.click(within(dialog).getByRole('button', { name: 'Dışa aktar' }));
    expect(await screen.findByText(/bugün zaten dışa aktarma yapıldı/)).toBeInTheDocument();
  });
});
