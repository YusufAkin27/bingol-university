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
  // izin sorgusu (GET /admin/rbac/me, P16) test konusu değildir
  return fn.mock.calls
    .map(([url, init]) => ({ url: String(url), init: init as RequestInit }))
    .filter((c) => !c.url.includes('/admin/rbac/'));
}
const hdr = (c: { init: RequestInit }, name: string) => (c.init.headers as Record<string, string>)[name];

type U = ReturnType<typeof userEvent.setup>;

describe('UserActions', () => {
  it('askıya alma: sebep zorunlu (onay kapalı), sonra POST gider; Idempotency-Key eklenir', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();

    await user.click(screen.getByRole('button', { name: 'Askıya al' }));
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Askıya al' });
    expect(confirm).toBeDisabled();
    await user.click(confirm);
    expect(calls(f)).toHaveLength(0);

    await user.type(within(dialog).getByRole('textbox'), 'Spam');
    expect(confirm).toBeDisabled(); // W1-B: en az 5 karakter
    await user.type(within(dialog).getByRole('textbox'), ' hesap');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    const c = calls(f)[0];
    expect(c.url).toBe('/api/admin/users/7/suspend');
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ reason: 'Spam hesap' });
    expect(decodeURIComponent(hdr(c, 'X-Admin-Reason'))).toBe('Spam hesap');
    expect(hdr(c, 'Idempotency-Key')).toBeTruthy();
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

  it('rol değişimi: sebep + e-posta yazılmadan onay kapalı; sonra PATCH sebep ile gider', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    const change = screen.getByRole('button', { name: 'Rolü değiştir' });
    expect(change).toBeDisabled(); // rol aynı
    await user.selectOptions(screen.getByLabelText('Rol'), 'ADMIN');
    await user.click(change);
    const dialog = screen.getByRole('alertdialog');
    expect(dialog).toHaveTextContent('Yönetici');
    const confirm = within(dialog).getByRole('button', { name: 'Rolü değiştir' });
    expect(confirm).toBeDisabled();
    expect(calls(f)).toHaveLength(0);

    const [reasonBox, emailBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Yeni dönem moderatörü olarak atandı');
    expect(confirm).toBeDisabled(); // e-posta hâlâ yok
    await user.type(emailBox, 'yanlis@bingol.edu.tr');
    expect(confirm).toBeDisabled();
    await user.clear(emailBox);
    await user.type(emailBox, 'demo.007@bingol.edu.tr');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(calls(f)[0].url).toBe('/api/admin/users/7/role');
    expect(calls(f)[0].init.method).toBe('PATCH');
    expect(JSON.parse(String(calls(f)[0].init.body))).toEqual({ role: 'ADMIN' });
    expect(decodeURIComponent(hdr(calls(f)[0], 'X-Admin-Reason'))).toBe('Yeni dönem moderatörü olarak atandı');
    expect(hdr(calls(f)[0], 'Idempotency-Key')).toBeTruthy();
  });

  it('yöneticiyi düşürürken ADMIN_EMAILS uyarısı gösterilir', async () => {
    mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={{ ...base, role: 'ADMIN' }} selfId={1} />);
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Rol'), 'USER');
    await user.click(screen.getByRole('button', { name: 'Rolü değiştir' }));
    expect(screen.getByRole('alertdialog')).toHaveTextContent('ADMIN_EMAILS listesindeki bir hesap');
  });

  async function fillRole(user: U) {
    const dialog = screen.getByRole('alertdialog');
    const [reasonBox, emailBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Görev değişikliği nedeniyle');
    await user.type(emailBox, 'demo.007@bingol.edu.tr');
    await user.click(within(dialog).getByRole('button', { name: 'Rolü değiştir' }));
  }

  it('LAST_ADMIN hatası çevrilmiş mesajla gösterilir', async () => {
    mockFetch(() => jsonResponse(409, { code: 'LAST_ADMIN', message: 'x' }));
    renderWithProviders(<UserActions user={{ ...base, role: 'ADMIN' }} selfId={1} />);
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Rol'), 'USER');
    await user.click(screen.getByRole('button', { name: 'Rolü değiştir' }));
    await fillRole(user);
    expect(await screen.findByText('Son yönetici düşürülemez.')).toBeInTheDocument();
  });

  it('CANNOT_MODIFY_SELF hatası çevrilmiş mesajla gösterilir', async () => {
    mockFetch(() => jsonResponse(400, { code: 'CANNOT_MODIFY_SELF', message: 'x' }));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Rol'), 'ADMIN');
    await user.click(screen.getByRole('button', { name: 'Rolü değiştir' }));
    await fillRole(user);
    expect(await screen.findByText('Kendi hesabınız üzerinde bu işlemi yapamazsınız.')).toBeInTheDocument();
  });

  it('kendi hesabında rol ve silme devre dışıdır', () => {
    renderWithProviders(<UserActions user={base} selfId={7} />);
    expect(screen.getByLabelText('Rol')).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Rolü değiştir' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Hesabı sil' })).toBeDisabled();
  });

  it('silme: e-posta VE sebep olmadan onay kapalı; sebep ve anahtar başlıkta gider', async () => {
    const f = mockFetch(() => jsonResponse(204));
    const onDeleted = vi.fn();
    renderWithProviders(<UserActions user={base} selfId={1} onDeleted={onDeleted} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Hesabı sil' }));
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Hesabı sil' });
    expect(confirm).toBeDisabled();
    const [reasonBox, emailBox] = within(dialog).getAllByRole('textbox');
    await user.type(emailBox, 'DEMO.007@bingol.edu.tr');
    expect(confirm).toBeDisabled(); // e-posta tamam ama sebep yok
    await user.type(reasonBox, 'kısa');
    expect(confirm).toBeDisabled(); // sebep çok kısa
    await user.clear(emailBox);
    await user.type(emailBox, 'yanlis@bingol.edu.tr');
    await user.type(reasonBox, ' sebep yazıldı artık');
    expect(confirm).toBeDisabled(); // sebep tamam ama e-posta yanlış
    await user.clear(emailBox);
    await user.type(emailBox, 'DEMO.007@bingol.edu.tr');
    expect(confirm).toBeEnabled();
    expect(calls(f)).toHaveLength(0);
    await user.click(confirm);
    await waitFor(() => expect(onDeleted).toHaveBeenCalled());
    expect(calls(f)).toHaveLength(1);
    expect(calls(f)[0].url).toBe('/api/admin/users/7');
    expect(decodeURIComponent(hdr(calls(f)[0], 'X-Admin-Reason'))).toBe('kısa sebep yazıldı artık');
    expect(calls(f)[0].init.method).toBe('DELETE');
    expect(hdr(calls(f)[0], 'Idempotency-Key')).toBeTruthy();
  });

  it('silme onayında Enter + tık çift tetiklense de tek istek gider', async () => {
    let release: (r: Response) => void = () => undefined;
    const f = mockFetch(() => new Promise<Response>((res) => (release = res)));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Hesabı sil' }));
    const dialog = screen.getByRole('alertdialog');
    const [reasonBox, emailBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Hesap sahibi talep etti, doğrulandı');
    await user.type(emailBox, 'demo.007@bingol.edu.tr');
    await user.keyboard('{Enter}');
    await user.keyboard('{Enter}');
    await user.click(within(dialog).getByRole('button', { name: 'Hesabı sil' }));
    expect(calls(f)).toHaveLength(1);
    release(jsonResponse(204));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument());
    expect(calls(f)).toHaveLength(1);
  });

  it('oturum kapatma: gerekçe (>= 5 karakter) olmadan onay kapalıdır, istek gitmez', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Oturumlarını kapat' }));
    expect(calls(f)).toHaveLength(0);
    const dialog = screen.getByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Oturumlarını kapat' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'abcd');
    expect(confirm).toBeDisabled();
    await user.click(confirm);
    expect(calls(f)).toHaveLength(0);
  });

  it('şifre sıfırlama gönder: gerekçe zorunlu; başlıkta gider', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Şifre sıfırlama e-postası gönder' }));
    const dialog = screen.getByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Şifre sıfırlama e-postası gönder' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Kullanıcı şifresini unuttu');
    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(calls(f)[0].url).toBe('/api/admin/users/7/send-reset');
    expect(decodeURIComponent(hdr(calls(f)[0], 'X-Admin-Reason'))).toBe('Kullanıcı şifresini unuttu');
  });

  it('e-postayı elle doğrula: gerekçe zorunlu; başlıkta gider; çok satırlı gerekçe tek satıra iner', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={{ ...base, emailVerified: false }} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'E-postayı elle doğrula' }));
    const dialog = screen.getByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'E-postayı elle doğrula' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Posta kutusu{Enter}erişilemiyor');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(calls(f)[0].url).toBe('/api/admin/users/7/verify-email');
    const sent = decodeURIComponent(hdr(calls(f)[0], 'X-Admin-Reason'));
    expect(sent).toBe('Posta kutusu erişilemiyor');
    expect(sent).not.toMatch(/[\r\n\t]/);
  });

  it('VERIFY_ADMIN_EMAIL_FORBIDDEN (409) anlaşılır Türkçe iletiyle gösterilir', async () => {
    mockFetch(() => jsonResponse(409, { code: 'VERIFY_ADMIN_EMAIL_FORBIDDEN', message: 'x' }));
    renderWithProviders(<UserActions user={{ ...base, emailVerified: false }} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'E-postayı elle doğrula' }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByRole('textbox'), 'Gerekçe yazıldı');
    await user.click(within(dialog).getByRole('button', { name: 'E-postayı elle doğrula' }));
    expect(await screen.findByText(/koda gerek kalmadan doğrulanamaz/)).toBeInTheDocument();
  });

  it('oturum kapatma: yazılan sebep başlıkta gider', async () => {
    const f = mockFetch(() => jsonResponse(204));
    renderWithProviders(<UserActions user={base} selfId={1} />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Oturumlarını kapat' }));
    const dialog = screen.getByRole('alertdialog');
    await user.type(within(dialog).getByRole('textbox'), 'Şüpheli giriş');
    await user.click(within(dialog).getByRole('button', { name: 'Oturumlarını kapat' }));
    await waitFor(() => expect(calls(f)).toHaveLength(1));
    expect(decodeURIComponent(hdr(calls(f)[0], 'X-Admin-Reason'))).toBe('Şüpheli giriş');
  });

  it('silinmiş hesapta işlem düğmesi yoktur', () => {
    renderWithProviders(<UserActions user={{ ...base, status: 'DELETED' }} selfId={1} />);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });
});
