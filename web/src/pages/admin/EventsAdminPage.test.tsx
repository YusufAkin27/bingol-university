import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import EventsAdminPage from './EventsAdminPage';

const ev = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  title: `etkinlik-${id}`,
  description: null,
  startsAt: '2099-01-01T10:00:00Z',
  endsAt: '2099-01-01T12:00:00Z',
  location: 'Salon',
  coverUrl: null,
  capacity: null,
  goingCount: 0,
  interestedCount: null,
  communityId: null,
  communityName: null,
  createdBy: 5,
  organizerName: 'Ayse',
  status: 'PENDING_REVIEW',
  createdAt: '2026-10-01T10:00:00Z',
  joinPolicy: 'OPEN',
  pendingCount: null,
  ...over,
});

const detail = (status: string, allowedActions: string[], over: Record<string, unknown> = {}) => ({
  event: ev(1, { status, communityId: 3, communityName: 'Yazilim Kulubu', capacity: 40 }),
  organizerEmail: 'ayse@bingol.edu.tr',
  requests: { pending: 4, waitlisted: 1, accepted: 20, rejected: 2, cancelled: 3 },
  attendedCount: 17,
  reviewNote: null,
  moderationReason: null,
  moderatedBy: null,
  moderatedAt: null,
  history: [
    {
      id: 1,
      adminId: 9,
      adminName: 'Yonetici Bir',
      action: 'HIDE',
      fromStatus: 'ACTIVE',
      toStatus: 'HIDDEN',
      reason: 'Supheli icerik',
      createdAt: '2026-10-10T10:00:00Z',
    },
  ],
  allowedActions,
  ...over,
});

interface Call {
  method: string;
  url: string;
  body: unknown;
}

function setup(d = detail('ACTIVE', ['edit', 'hide', 'cancel', 'delete']), failPatch?: { status: number; code: string }) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({ method, url, body: init.body ? JSON.parse(String(init.body)) : undefined });
    if (/\/admin\/events\/1$/.test(url) && method === 'GET') return jsonResponse(200, d);
    if (/\/admin\/events\/1$/.test(url) && method === 'PATCH')
      return failPatch ? jsonResponse(failPatch.status, { code: failPatch.code, message: 'x' }) : jsonResponse(200, d);
    if (/\/admin\/events\/1\/(hide|unhide|cancel)$/.test(url)) return jsonResponse(200, d);
    if (/\/admin\/events\/1\?reason=/.test(url) && method === 'DELETE') return jsonResponse(204);
    if (url.includes('/admin/events')) {
      return jsonResponse(200, {
        items: [
          ev(1, { communityId: 3, communityName: 'Yazilim Kulubu' }),
          ev(2, { joinPolicy: 'APPROVAL', pendingCount: 4 }),
        ],
        nextCursor: null,
      });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('EventsAdminPage: liste', () => {
  it('kulüpsüz/kulüp rozeti, istekle katılım ve bekleyen istek sayısını gösterir', async () => {
    setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events' });
    expect(await screen.findByText('etkinlik-1')).toBeInTheDocument();
    expect(screen.getByText('Yazilim Kulubu')).toBeInTheDocument();
    expect(screen.getAllByText('Kulüpsüz').length).toBeGreaterThan(0);
    expect(screen.getAllByText(/İstekle katılım/).length).toBeGreaterThan(0);
    expect(screen.getByText('4 bekleyen istek')).toBeInTheDocument();
  });

  it('kapsam, katılım türü, tarih ve arama süzgeçleri sunucuya gider', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ACTIVE&scope=standalone&join=APPROVAL' });
    await screen.findByText('etkinlik-1');
    const first = calls.find((c) => c.url.includes('/admin/events?'))?.url ?? '';
    expect(first).toContain('status=ACTIVE');
    expect(first).toContain('standalone=true');
    expect(first).toContain('joinPolicy=APPROVAL');
    await user.type(screen.getByRole('searchbox'), 'piknik');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=piknik'))).toBe(true));
  });

  it('Tümü sekmesi status=ALL ister', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events' });
    await screen.findByText('etkinlik-1');
    await user.click(screen.getAllByRole('tab', { name: 'Tümü' })[0]);
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=ALL'))).toBe(true));
  });
});

describe('EventsAdminPage: ayrıntı çekmecesi', () => {
  it('?open= ayrıntıyı açar: istek sayıları, geçmiş, e-posta ve yalnız izinli düğmeler', async () => {
    setup(detail('ACTIVE', ['edit', 'hide', 'cancel', 'delete']));
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByText('ayse@bingol.edu.tr')).toBeInTheDocument();
    expect(within(dialog).getByTestId('request-counts')).toHaveTextContent('20');
    expect(within(dialog).getByTestId('history')).toHaveTextContent('Supheli icerik');
    expect(within(dialog).getByTestId('history')).toHaveTextContent('Yonetici Bir');
    for (const name of ['Düzenle', 'Gizle', 'İptal et', 'Sil (iptal eder)']) {
      expect(within(dialog).getByRole('button', { name })).toBeInTheDocument();
    }
    expect(within(dialog).queryByRole('button', { name: 'Yeniden yayına al' })).not.toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: 'Onayla' })).not.toBeInTheDocument();
  });

  it('gizli etkinlikte geri açma görünür ve organizatöre de 404 notu gösterilir', async () => {
    setup(detail('HIDDEN', ['unhide', 'cancel', 'delete']));
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByRole('button', { name: 'Yeniden yayına al' })).toBeInTheDocument();
    expect(within(dialog).getByText(/organizatöre de görünmez/)).toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: 'Gizle' })).not.toBeInTheDocument();
  });

  it('gizleme sebep olmadan gönderilmez; sebep ile POST /hide yapılır', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'Gizle' }));
    const dialogs = await screen.findAllByRole('dialog');
    const modal = dialogs[dialogs.length - 1];
    await user.click(within(modal).getByTestId('reason-confirm'));
    expect(calls.some((c) => c.url.endsWith('/hide'))).toBe(false);
    expect(await within(modal).findByText('Bir sebep yazın.')).toBeInTheDocument();
    await user.type(within(modal).getByRole('textbox'), 'Uygunsuz görsel');
    await user.click(within(modal).getByTestId('reason-confirm'));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/events/1/hide'))).toBe(true));
    expect(calls.find((c) => c.url.endsWith('/hide'))?.body).toEqual({ reason: 'Uygunsuz görsel' });
  });

  it('silme sebebi sorgu parametresi olarak gider ve yumuşak silme olarak açıklanır', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'Sil (iptal eder)' }));
    const dialogs = await screen.findAllByRole('dialog');
    const modal = dialogs[dialogs.length - 1];
    expect(modal).toHaveTextContent('Yumuşak silme');
    await user.type(within(modal).getByRole('textbox'), 'Tekrarlanan kayıt');
    await user.click(within(modal).getByTestId('reason-confirm'));
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    const del = calls.find((c) => c.method === 'DELETE');
    expect(decodeURIComponent(del?.url ?? '')).toContain('reason=Tekrarlanan kayıt');
  });

  it('düzenleme yalnızca değişen alanları PATCH eder', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'Düzenle' }));
    const title = await within(drawer).findByLabelText(/Başlık/);
    await user.clear(title);
    await user.type(title, 'Yeni baslik');
    const cap = within(drawer).getByLabelText('Kontenjan');
    await user.clear(cap);
    await user.type(cap, '0');
    await user.click(within(drawer).getByTestId('edit-save'));
    await waitFor(() => expect(calls.some((c) => c.method === 'PATCH')).toBe(true));
    expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ title: 'Yeni baslik', capacity: 0 });
  });

  it('422 CONTENT_PROFANITY düzenleme formunda çevrilmiş mesajla gösterilir', async () => {
    setup(detail('ACTIVE', ['edit', 'hide', 'cancel', 'delete']), { status: 422, code: 'CONTENT_PROFANITY' });
    const user = userEvent.setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'Düzenle' }));
    const title = await within(drawer).findByLabelText(/Başlık/);
    await user.type(title, ' x');
    await user.click(within(drawer).getByTestId('edit-save'));
    expect((await within(drawer).findAllByText(/uygunsuz ifade bulundu/)).length).toBeGreaterThan(0);
  });
});
