import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademiciansPage from './AcademiciansPage';

afterEach(() => vi.unstubAllGlobals());

const person = (id: number, over: Record<string, unknown> = {}) => ({
  userId: id,
  email: `hoca${id}@bingol.edu.tr`,
  displayName: `Deneme Hoca ${id}`,
  title: 'Dr. Öğr. Üyesi',
  firstName: 'Deneme',
  lastName: `Hoca ${id}`,
  unit: 'Örnek Fakültesi',
  status: 'PENDING',
  approvalMode: null,
  rejectReason: null,
  reviewedBy: null,
  reviewedAt: null,
  createdAt: '2026-11-01T09:30:00Z',
  ...over,
});

const ME = (perms: string[]) => ({
  userId: 1,
  email: 'a@b.c',
  displayName: 'Yönetici',
  profile: 'FULL',
  pinned: false,
  permissions: perms,
});
const WRITE = ['users.read', 'users.write', 'audit.read'];
const READ_ONLY = ['users.read', 'audit.read'];

interface Call {
  url: string;
  method: string;
  body?: unknown;
  headers: Record<string, string>;
}

type Rows = (url: URL) => { items: unknown[]; nextCursor?: number | null } | Response;

function setup(rows: Rows, perms = WRITE, post?: (url: string) => Response | undefined) {
  const calls: Call[] = [];
  mockFetch((raw, init) => {
    const method = init.method ?? 'GET';
    const url = new URL(raw, 'http://x');
    calls.push({
      url: raw,
      method,
      body: typeof init.body === 'string' ? JSON.parse(init.body) : undefined,
      headers: (init.headers ?? {}) as Record<string, string>,
    });
    if (url.pathname.endsWith('/admin/rbac/me')) return jsonResponse(200, ME(perms));
    if (method === 'GET' && url.pathname.endsWith('/admin/academicians')) {
      const r = rows(url);
      return r instanceof Response ? r : jsonResponse(200, { nextCursor: null, ...r });
    }
    if (method === 'POST') return post?.(raw) ?? jsonResponse(200, person(1, { status: 'APPROVED', approvalMode: 'ADMIN' }));
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const listCalls = (calls: Call[]) => calls.filter((c) => c.method === 'GET' && /\/admin\/academicians\?/.test(c.url));
const statusParam = (c: Call) => new URL(c.url, 'http://x').searchParams.get('status');

describe('Akademisyen başvuru listesi', () => {
  it('varsayılan sekme Bekleyen: PENDING ister; ad, unvan, birim ve MASKELİ e-postayı sunucunun verdiği gibi gösterir', async () => {
    const calls = setup(() => ({ items: [person(1, { email: 'h***@bingol.edu.tr' })] }));
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    expect(await screen.findByText('h***@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText(/Dr\. Öğr\. Üyesi Deneme Hoca 1/)).toBeInTheDocument();
    expect(screen.getByText('Örnek Fakültesi')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Bekleyen' })).toHaveAttribute('aria-selected', 'true');
    expect(statusParam(listCalls(calls)[0])).toBe('PENDING');
  });

  it('sekmeler doğru süzgeci ister: Onaylı, Otomatik onaylanan, Reddedilen', async () => {
    const calls = setup(() => ({ items: [] }));
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('Bekleyen başvuru yok');

    await userEvent.click(screen.getByRole('tab', { name: 'Onaylı' }));
    await waitFor(() => expect(listCalls(calls).some((c) => statusParam(c) === 'APPROVED' && !c.url.includes('approvalMode'))).toBe(true));

    await userEvent.click(screen.getByRole('tab', { name: 'Otomatik onaylanan' }));
    await waitFor(() =>
      expect(listCalls(calls).some((c) => statusParam(c) === 'APPROVED' && c.url.includes('approvalMode=AUTO'))).toBe(true),
    );

    await userEvent.click(screen.getByRole('tab', { name: 'Reddedilen' }));
    await waitFor(() => expect(listCalls(calls).some((c) => statusParam(c) === 'REJECTED,REVOKED')).toBe(true));
  });

  it('otomatik sekme denetim alanlarını gösterir: e-posta, başvuru tarihi, onay biçimi, karar veren = sistem, geri alma', async () => {
    setup((u) =>
      u.searchParams.get('approvalMode') === 'AUTO'
        ? {
            items: [
              person(7, {
                status: 'APPROVED',
                approvalMode: 'AUTO',
                email: 'kurum.ornek@bingol.edu.tr',
                reviewedAt: '2026-11-02T10:00:00Z',
                createdAt: '2026-11-02T09:59:00Z',
              }),
            ],
          }
        : { items: [] },
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians?tab=auto' });
    expect(await screen.findByText('kurum.ornek@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText(/bir insan bakmadan, kurala göre/)).toBeInTheDocument();
    expect(screen.getByText('Otomatik (kural)')).toBeInTheDocument();
    expect(screen.getByText('Sistem (kural)')).toBeInTheDocument();
    expect(screen.getAllByText(/2 Kas 2026/).length).toBe(2); // başvuru ve karar tarihi
    expect(screen.getByRole('button', { name: 'Onayı geri al' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reddet' })).not.toBeInTheDocument();
  });

  it('imeç sayfalama: "Daha fazla yükle" cursor ile sonraki sayfayı ekler', async () => {
    const calls = setup((u) =>
      u.searchParams.get('cursor') === '9'
        ? { items: [person(3)], nextCursor: null }
        : { items: [person(9)], nextCursor: 9 },
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca9@bingol.edu.tr');
    await userEvent.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    expect(await screen.findByText('hoca3@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('hoca9@bingol.edu.tr')).toBeInTheDocument();
    expect(listCalls(calls).some((c) => c.url.includes('cursor=9'))).toBe(true);
    expect(screen.queryByRole('button', { name: 'Daha fazla yükle' })).not.toBeInTheDocument();
  });

  it('arama q parametresiyle SUNUCUYA gider ve imeci sıfırlar', async () => {
    const calls = setup((u) =>
      u.searchParams.get('q') === 'baska'
        ? { items: [person(2, { email: 'baska@bingol.edu.tr' })] }
        : { items: [person(9)], nextCursor: 9 },
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca9@bingol.edu.tr');
    await userEvent.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    await userEvent.type(screen.getByRole('searchbox'), 'baska');
    expect(await screen.findByText('baska@bingol.edu.tr')).toBeInTheDocument();
    const withQ = listCalls(calls).filter((c) => c.url.includes('q=baska'));
    expect(withQ.length).toBeGreaterThan(0);
    expect(withQ.every((c) => !c.url.includes('cursor='))).toBe(true);
  });

  it('users.pii yoksa 3 karakterden kısa arama gönderilmez ve ipucu görünür', async () => {
    const calls = setup(() => ({ items: [person(1)] }), WRITE);
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    expect(screen.getByText(/en az 3 karakter/)).toBeInTheDocument();
    await userEvent.type(screen.getByRole('searchbox'), 'ba');
    await new Promise((r) => setTimeout(r, 500));
    expect(listCalls(calls).some((c) => c.url.includes('q='))).toBe(false);
  });

  it('users.pii varsa ipucu yoktur ve kısa arama da gider', async () => {
    const calls = setup(() => ({ items: [person(1)] }), [...WRITE, 'users.pii']);
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    expect(screen.queryByText(/en az 3 karakter/)).not.toBeInTheDocument();
    await userEvent.type(screen.getByRole('searchbox'), 'ba');
    await waitFor(() => expect(listCalls(calls).some((c) => c.url.includes('q=ba'))).toBe(true));
  });

  it('boş durum ve hata durumu (tekrar dene)', async () => {
    let fail = true;
    setup(() => (fail ? jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }) : { items: [] }));
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
    fail = false;
    await userEvent.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(await screen.findByText('Bekleyen başvuru yok')).toBeInTheDocument();
  });

  it('users.write yoksa onay/ret/geri alma denetimi çizilmez', async () => {
    setup(
      (u) => ({ items: [person(1, u.searchParams.get('status') === 'APPROVED' ? { status: 'APPROVED', approvalMode: 'ADMIN' } : {})] }),
      READ_ONLY,
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Onayla' })).not.toBeInTheDocument());
    expect(screen.queryByRole('button', { name: 'Reddet' })).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('tab', { name: 'Onaylı' }));
    await screen.findByText('Onaylı', { selector: 'span' });
    expect(screen.queryByRole('button', { name: 'Onayı geri al' })).not.toBeInTheDocument();
  });

  it('users.write varsa onay: sonucu açıklayan cümle, POST /approve ve liste yenilenir', async () => {
    let approved = false;
    const calls = setup(
      () => ({ items: approved ? [] : [person(1)] }),
      WRITE,
      (url) => {
        if (url.endsWith('/academicians/1/approve')) {
          approved = true;
          return jsonResponse(200, person(1, { status: 'APPROVED', approvalMode: 'ADMIN' }));
        }
        return undefined;
      },
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    await userEvent.click(await screen.findByRole('button', { name: 'Onayla' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText(/hemen akademisyen paneline erişir/)).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/academicians/1/approve'))).toBe(true));
    const post = calls.find((c) => c.method === 'POST');
    expect(post?.headers['Idempotency-Key']).toBeTruthy();
    expect(await screen.findByText('Bekleyen başvuru yok')).toBeInTheDocument();
  });

  it('ret gerekçe ister ve gerekçeyi gönderir', async () => {
    const calls = setup(() => ({ items: [person(1)] }));
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    await userEvent.click(await screen.findByRole('button', { name: 'Reddet' }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Reddet' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), 'kısa');
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), ' ama yeterince uzun gerekçe');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/academicians/1/reject'))).toBe(true));
    expect(calls.find((c) => c.url.endsWith('/reject'))?.body).toEqual({ reason: 'kısa ama yeterince uzun gerekçe' });
  });

  it('onayı geri alma gerekçe ister, sonucu söyler ve gerekçeyi gönderir', async () => {
    const calls = setup(() => ({ items: [person(1, { status: 'APPROVED', approvalMode: 'ADMIN' })] }));
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians?tab=approved' });
    await screen.findByText('hoca1@bingol.edu.tr');
    await userEvent.click(await screen.findByRole('button', { name: 'Onayı geri al' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).getByText(/dersleri ve yoklama verileri silinmez/)).toBeInTheDocument();
    const confirm = within(dialog).getByRole('button', { name: 'Onayı geri al' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), 'Kurum dışı e-posta saptandı');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/academicians/1/revoke'))).toBe(true));
    expect(calls.find((c) => c.url.endsWith('/revoke'))?.body).toEqual({ reason: 'Kurum dışı e-posta saptandı' });
  });

  it('sunucu hatası mesajı gösterir ve diyalog açık kalır', async () => {
    setup(
      () => ({ items: [person(1)] }),
      WRITE,
      () => jsonResponse(409, { code: 'ACADEMICIAN_BAD_STATE', message: 'x' }),
    );
    renderWithProviders(<AcademiciansPage />, { route: '/admin/academicians' });
    await screen.findByText('hoca1@bingol.edu.tr');
    await userEvent.click(await screen.findByRole('button', { name: 'Onayla' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Onayla' }));
    expect(await screen.findByText(/Başvuru bu arada değişti/)).toBeInTheDocument();
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });
});
