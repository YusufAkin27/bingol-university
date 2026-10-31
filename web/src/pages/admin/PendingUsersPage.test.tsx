import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PendingUsersPage from './PendingUsersPage';

afterEach(() => vi.unstubAllGlobals());

const entry = (email: string, over: Record<string, unknown> = {}) => ({
  email,
  displayName: `Ad ${email.split('@')[0]}`,
  faculty: 'Mühendislik',
  department: 'Bilgisayar',
  grade: '2',
  createdAtEpochSec: 1_790_000_000,
  remainingSeconds: 2 * 86400 + 3 * 3600,
  resendCount: 1,
  ...over,
});

interface Call {
  url: string;
  init: RequestInit;
}

type Extra = (url: string, init: RequestInit) => Response | undefined;

function setup(items = [entry('a@bingol.edu.tr'), entry('226051015@bingol.edu.tr')], extra: Extra = () => undefined) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const o = extra(url, init);
    if (o) return o;
    if (url.includes('/admin/pending-registrations') && (init.method ?? 'GET') === 'GET') {
      if (url.includes('cursor=c1')) return jsonResponse(200, { items: [entry('z@bingol.edu.tr')], nextCursor: null });
      return jsonResponse(200, { items, nextCursor: null });
    }
    if (url.endsWith('/verify')) return jsonResponse(201, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Ad a', createdAt: 'x' });
    if (url.endsWith('/resend-code')) return jsonResponse(204);
    if ((init.method ?? '') === 'DELETE') return jsonResponse(204);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Doğrulanmamış kullanıcılar sayfası', () => {
  it('listeyi, kalan süreyi ve okul numarası rozetini gösterir', async () => {
    setup();
    renderWithProviders(<PendingUsersPage />);
    expect(await screen.findByText('a@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getAllByText('2 gün 3 sa').length).toBe(2);
    expect(screen.getByText('226051015@bingol.edu.tr')).toBeInTheDocument();
  });

  it('arama q parametresini gönderir', async () => {
    const calls = setup();
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.type(screen.getByPlaceholderText(/okul numarası ara/), '2260');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=2260'))).toBe(true));
  });

  it('doğrula onay ister, POST atar ve satırı kaldırır', async () => {
    const calls = setup();
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Doğrula' })[0]);
    expect(await screen.findByText(/e-posta kodu olmadan oluşturulacak/)).toBeInTheDocument();
    const dialog = screen.getByRole('dialog');
    // W1-B (T-011): kodsuz doğrulama gerekçe ister (>= 5 karakter)
    const confirm = within(dialog).getByRole('button', { name: 'Doğrula' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), 'abcd');
    expect(confirm).toBeDisabled();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    await userEvent.type(within(dialog).getByRole('textbox'), 'e');
    await userEvent.click(confirm);
    await waitFor(() =>
      expect(calls.some((c) => c.init.method === 'POST' && c.url.endsWith('/a%40bingol.edu.tr/verify'))).toBe(true),
    );
    const post = calls.find((c) => c.init.method === 'POST' && c.url.endsWith('/verify'));
    expect(decodeURIComponent((post?.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('abcde');
    await waitFor(() => expect(screen.queryByText('a@bingol.edu.tr')).not.toBeInTheDocument());
  });

  it('409 VERIFY_ADMIN_EMAIL_FORBIDDEN anlaşılır Türkçe iletiyle gösterilir', async () => {
    setup(undefined, (url) =>
      url.endsWith('/verify') ? jsonResponse(409, { code: 'VERIFY_ADMIN_EMAIL_FORBIDDEN', message: 'x' }) : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Doğrula' })[0]);
    const dialog = screen.getByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox'), 'Yönetici adayı');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Doğrula' }));
    expect(await screen.findByText(/koda gerek kalmadan doğrulanamaz/)).toBeInTheDocument();
  });

  it('users.verify izni yoksa (FULL dışı profil) doğrula düğmeleri kapalıdır', async () => {
    setup(undefined, (url) =>
      url.endsWith('/admin/rbac/me')
        ? jsonResponse(200, {
            userId: 2,
            email: 'm@bingol.edu.tr',
            displayName: 'Moderatör',
            profile: 'MODERATOR',
            pinned: false,
            permissions: ['users.read', 'users.pii', 'users.write'],
          })
        : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await waitFor(() => expect(screen.getAllByRole('button', { name: 'Doğrula' })[0]).toBeDisabled());
  });

  it('409 durumunda bilgi verir ve satırı kaldırır', async () => {
    setup(undefined, (url) =>
      url.endsWith('/verify') ? jsonResponse(409, { code: 'EMAIL_ALREADY_REGISTERED', message: 'var' }) : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Doğrula' })[0]);
    await userEvent.type(within(screen.getByRole('dialog')).getByRole('textbox'), 'Elle doğrulama');
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Doğrula' }));
    expect(await screen.findByText(/zaten kayıtlı/)).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByText('a@bingol.edu.tr')).not.toBeInTheDocument());
  });

  it('yeniden gönder 429 alırsa bekleme gösterir', async () => {
    setup(undefined, (url) =>
      url.endsWith('/resend-code') ? jsonResponse(429, { code: 'RESEND_COOLDOWN', message: 'bekle' }) : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Kodu yeniden gönder' })[0]);
    expect(await screen.findByText(/Çok sık denendi/)).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: /Bekleyin/ }).length).toBe(1);
  });

  it('yeniden gönder başarılıysa POST atar', async () => {
    const calls = setup();
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Kodu yeniden gönder' })[0]);
    expect(await screen.findByText('Doğrulama kodu yeniden gönderildi.')).toBeInTheDocument();
    expect(calls.some((c) => c.url.endsWith('/resend-code') && c.init.method === 'POST')).toBe(true);
  });

  it('sil onaylıdır ve DELETE gönderir', async () => {
    const calls = setup();
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getAllByRole('button', { name: 'Sil / iptal et' })[0]);
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Sil / iptal et' }));
    await waitFor(() => expect(calls.some((c) => c.init.method === 'DELETE')).toBe(true));
    await waitFor(() => expect(screen.queryByText('a@bingol.edu.tr')).not.toBeInTheDocument());
  });

  it('toplu doğrulama sıralı çalışır ve hata raporu verir', async () => {
    const calls = setup(undefined, (url) =>
      url.includes('226051015') && url.endsWith('/verify')
        ? jsonResponse(404, { code: 'PENDING_REGISTRATION_NOT_FOUND', message: 'yok' })
        : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getByLabelText('Görünenlerin tümünü seç'));
    expect(screen.getByText('2 seçili')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri doğrula' }));
    const dialog = screen.getByRole('dialog');
    const bulkGo = within(dialog).getByRole('button', { name: 'Seçilenleri doğrula' });
    expect(bulkGo).toBeDisabled(); // gerekçe yok
    await userEvent.type(within(dialog).getByRole('textbox'), 'Toplu elle doğrulama');
    await userEvent.click(bulkGo);
    expect(await screen.findByText('1 doğrulandı, 1 hata.')).toBeInTheDocument();
    expect(calls.filter((c) => c.url.endsWith('/verify')).length).toBe(2);
  });

  it('boş durumu gösterir', async () => {
    setup([]);
    renderWithProviders(<PendingUsersPage />);
    expect(await screen.findByText('Doğrulanmamış kullanıcı yok')).toBeInTheDocument();
  });

  it('hata durumunda yeniden dene sunar', async () => {
    setup(undefined, (_url, init) =>
      (init.method ?? 'GET') === 'GET' ? jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }) : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
  });

  it('sonraki sayfayı "Daha fazla yükle" ile imleçle getirir', async () => {
    const calls = setup(undefined, (url, init) =>
      (init.method ?? 'GET') === 'GET' && !url.includes('cursor=')
        ? jsonResponse(200, { items: [entry('a@bingol.edu.tr')], nextCursor: 'c1' })
        : undefined,
    );
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    expect(await screen.findByText('z@bingol.edu.tr')).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('cursor=c1'))).toBe(true);
  });
});
