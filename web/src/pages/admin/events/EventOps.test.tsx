import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import EventsAdminPage from '../EventsAdminPage';

const ev = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  title: `etkinlik-${id}`,
  description: null,
  startsAt: '2099-01-01T10:00:00Z',
  endsAt: '2099-01-01T12:00:00Z',
  location: 'Salon',
  coverUrl: null,
  capacity: 3,
  goingCount: 2,
  interestedCount: null,
  communityId: null,
  communityName: null,
  createdBy: 5,
  organizerName: 'Sahip Kisi',
  status: 'ACTIVE',
  createdAt: '2026-10-01T10:00:00Z',
  joinPolicy: 'APPROVAL',
  pendingCount: null,
  ...over,
});

const detail = {
  event: ev(1),
  organizerEmail: 'sahip@bingol.edu.tr',
  requests: { pending: 1, waitlisted: 0, accepted: 1, rejected: 0, cancelled: 0 },
  attendedCount: 1,
  reviewNote: null,
  moderationReason: null,
  moderatedBy: null,
  moderatedAt: null,
  history: [],
  allowedActions: ['edit', 'hide', 'cancel', 'delete'],
};

const summary = (over: Record<string, unknown> = {}) => ({
  mode: 'APPROVAL',
  capacity: 3,
  goingCount: 2,
  seatsLeft: 1,
  pending: 1,
  accepted: 1,
  waitlisted: 0,
  rejected: 0,
  cancelled: 0,
  ...over,
});

const appRow = (id: number, userId: number, name: string, status: string) => ({
  id,
  userId,
  displayName: name,
  emailMasked: `${name[0].toLowerCase()}***@bingol.edu.tr`,
  department: 'Bilgisayar',
  status,
  note: 'Katilmak istiyorum',
  answers: ['Yanit bir'],
  queuedAt: null,
  decidedBy: null,
  decidedAt: null,
  decisionNote: null,
  createdAt: '2026-10-10T10:00:00Z',
  updatedAt: '2026-10-10T10:00:00Z',
});

interface Call {
  method: string;
  url: string;
  body: unknown;
  headers: Record<string, string>;
}

function setup(over: { seatsLeft?: number } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      method,
      url,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
      headers: (init.headers ?? {}) as Record<string, string>,
    });
    const path = url.split('?')[0];
    if (method === 'GET' && path === '/api/admin/events/1') return jsonResponse(200, detail);
    if (method === 'GET' && path === '/api/admin/events/1/applications')
      return jsonResponse(200, {
        items: [appRow(11, 7, 'Ayse Yilmaz', 'PENDING'), appRow(12, 8, 'Berk Kaya', 'ACCEPTED')],
        nextCursor: null,
        summary: summary({ seatsLeft: over.seatsLeft ?? 1 }),
      });
    if (method === 'POST' && /\/admin\/events\/1\/applications\/\d+\/(accept|reject)$/.test(path))
      return jsonResponse(200, { id: 11, userId: 7, status: 'ACCEPTED', summary: summary() });
    if (method === 'GET' && path === '/api/admin/events/1/attendance')
      return jsonResponse(200, {
        rows: [
          {
            userId: 21,
            displayName: 'Ali Veli',
            emailMasked: 'a***@bingol.edu.tr',
            department: null,
            rsvp: 'GOING',
            present: true,
            method: 'QR',
            markedBy: 21,
            markedByName: null,
            markedAt: '2099-01-01T10:05:00Z',
            hasCertificate: true,
            certificateRevoked: false,
          },
          {
            userId: 22,
            displayName: 'Cem Can',
            emailMasked: 'c***@bingol.edu.tr',
            department: null,
            rsvp: 'GOING',
            present: null,
            method: null,
            markedBy: null,
            markedByName: null,
            markedAt: null,
            hasCertificate: false,
            certificateRevoked: false,
          },
        ],
        summary: { going: 2, present: 1, absent: 0, unmarked: 1, walkIns: 0 },
        truncated: false,
      });
    if (method === 'PUT' && /\/admin\/events\/1\/attendance\/\d+$/.test(path))
      return jsonResponse(200, {
        userId: 21,
        present: false,
        certificateExists: true,
        certificateValid: false,
      });
    if (method === 'GET' && path === '/api/admin/events/1/attendance.csv')
      return new Response('userId,name\r\n', { status: 200, headers: { 'Content-Type': 'text/csv' } });
    if (method === 'GET' && path === '/api/admin/events/1/certificates')
      return jsonResponse(200, {
        items: [
          {
            id: 31,
            userId: 21,
            holderName: 'Ali Veli',
            emailMasked: 'a***@bingol.edu.tr',
            codeHint: 'ABCD...QRST',
            issuedAt: '2099-01-01T13:00:00Z',
            attended: true,
            revoked: false,
            revokedAt: null,
            revokedBy: null,
            revokeReason: null,
            valid: true,
          },
          {
            id: 32,
            userId: 22,
            holderName: 'Cem Can',
            emailMasked: 'c***@bingol.edu.tr',
            codeHint: 'WXYZ...2345',
            issuedAt: '2099-01-01T13:00:00Z',
            attended: true,
            revoked: true,
            revokedAt: '2099-01-02T10:00:00Z',
            revokedBy: 9,
            revokeReason: 'sahte katilim',
            valid: false,
          },
        ],
        nextCursor: null,
      });
    if (method === 'POST' && /\/certificates\/\d+\/(revoke|restore)$/.test(path))
      return jsonResponse(200, {});
    if (method === 'GET' && path === '/api/admin/events/1/feedback')
      return jsonResponse(200, {
        items: [{ id: 41, rating: 4, comment: 'Cok guzeldi', createdAt: '2099-01-01T14:00:00Z' }],
        nextCursor: null,
        summary: { total: 1, average: 4, distribution: [0, 0, 0, 1, 0] },
      });
    if (method === 'DELETE' && /\/admin\/events\/1\/(feedback|announcements|organizers)\/\d+$/.test(path))
      return jsonResponse(204);
    if (method === 'GET' && path === '/api/admin/events/1/announcements')
      return jsonResponse(200, {
        items: [
          {
            id: 51,
            senderId: 5,
            senderName: 'Sahip Kisi',
            recipients: 12,
            createdAt: '2099-01-01T09:00:00Z',
          },
        ],
        nextCursor: null,
      });
    if (method === 'GET' && path === '/api/admin/events/1/organizers')
      return jsonResponse(200, [
        {
          userId: 5,
          displayName: 'Sahip Kisi',
          emailMasked: 's***@bingol.edu.tr',
          role: 'OWNER',
          addedBy: null,
          createdAt: '2026-10-01T10:00:00Z',
          removable: false,
        },
        {
          userId: 6,
          displayName: 'Ortak Kisi',
          emailMasked: 'o***@bingol.edu.tr',
          role: 'CO_ORGANIZER',
          addedBy: 5,
          createdAt: '2026-10-02T10:00:00Z',
          removable: true,
        },
      ]);
    if (method === 'GET' && path === '/api/admin/audit')
      return jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 });
    if (method === 'POST' && path === '/api/admin/events/bulk')
      return jsonResponse(200, {
        action: 'HIDE',
        requested: 2,
        done: 1,
        failed: 1,
        items: [
          { id: 1, ok: true, status: 200, error: null },
          { id: 2, ok: false, status: 409, error: 'EVENT_INVALID_TRANSITION' },
        ],
      });
    if (method === 'GET' && path === '/api/admin/events/export.csv')
      return new Response('id,title\r\n', { status: 200, headers: { 'Content-Type': 'text/csv' } });
    if (method === 'GET' && path === '/api/admin/events')
      return jsonResponse(200, { items: [ev(1), ev(2, { status: 'CANCELLED' })], nextCursor: null });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

beforeEach(() => {
  vi.stubGlobal(
    'URL',
    Object.assign(URL, { createObjectURL: vi.fn(() => 'blob:x'), revokeObjectURL: vi.fn() }),
  );
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

async function openDrawerTab(name: string) {
  renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
  const drawer = await screen.findByRole('dialog');
  await within(drawer).findByTestId('request-counts');
  await userEvent.click(within(drawer).getByRole('tab', { name }));
  return drawer;
}

describe('P07: ayrıntı çekmecesi sekmeleri', () => {
  it('Genel varsayılan; sekme çubuğu tüm derin yönetim bölümlerini sunar', async () => {
    setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?open=1' });
    const drawer = await screen.findByRole('dialog');
    await within(drawer).findByTestId('request-counts');
    const tabs = within(drawer)
      .getAllByRole('tab')
      .map((t) => t.textContent);
    expect(tabs).toEqual([
      'Genel',
      'Başvurular',
      'Yoklama',
      'Sertifikalar',
      'Geri bildirim',
      'Duyurular',
      'Düzenleyenler',
      'Denetim',
    ]);
    expect(within(drawer).getByRole('tab', { name: 'Genel' })).toHaveAttribute('aria-selected', 'true');
    // moderasyon düğmeleri yalnız Genel sekmesinde
    expect(within(drawer).getByRole('button', { name: 'Gizle' })).toBeInTheDocument();
    await userEvent.click(within(drawer).getByRole('tab', { name: 'Yoklama' }));
    expect(within(drawer).queryByRole('button', { name: 'Gizle' })).not.toBeInTheDocument();
  });

  it('Denetim sekmesi EVENT hedefiyle denetim kaydını ister', async () => {
    const calls = setup();
    await openDrawerTab('Denetim');
    await waitFor(() =>
      expect(calls.some((c) => c.url.includes('/admin/audit') && c.url.includes('targetType=EVENT'))).toBe(
        true,
      ),
    );
    expect(calls.find((c) => c.url.includes('/admin/audit'))?.url).toContain('targetId=1');
  });
});

describe('P07: başvurular', () => {
  it('maskeli e-posta ve kapasite özetini gösterir', async () => {
    setup();
    const drawer = await openDrawerTab('Başvurular');
    const row = await within(drawer).findByTestId('app-7');
    expect(row).toHaveTextContent('a***@bingol.edu.tr');
    expect(row).toHaveTextContent('Katilmak istiyorum');
    expect(within(drawer).getByTestId('app-summary')).toHaveTextContent('Boş yer');
    expect(within(drawer).getByTestId('app-summary')).toHaveTextContent('3');
  });

  it('kabul: sebep yazmadan onaylanmaz; sebep başlığı + Idempotency-Key ile POST /accept gider', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Başvurular');
    const row = await within(drawer).findByTestId('app-7');
    await userEvent.click(within(row).getByRole('button', { name: 'Kabul et' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ayse Yilmaz başvurusu kabul edilsin mi?' });
    const confirm = within(dialog).getByRole('button', { name: 'Kabul et' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'kontenjan uygun, onaylandi');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() =>
      expect(
        calls.some((c) => c.method === 'POST' && c.url === '/api/admin/events/1/applications/7/accept'),
      ).toBe(true),
    );
    const post = calls.find((c) => c.method === 'POST')!;
    expect(decodeURIComponent(post.headers['X-Admin-Reason'])).toBe('kontenjan uygun, onaylandi');
    expect(post.headers['Idempotency-Key']).toBeTruthy();
  });

  it('kapasite doluyken Kabul et devre dışıdır ve nedeni yazılır; Reddet açıktır', async () => {
    setup({ seatsLeft: 0 });
    const drawer = await openDrawerTab('Başvurular');
    const row = await within(drawer).findByTestId('app-7');
    expect(within(row).getByRole('button', { name: 'Kabul et' })).toBeDisabled();
    expect(within(row).getByRole('button', { name: 'Reddet' })).toBeEnabled();
    expect(within(drawer).getByText(/Kapasite dolu/)).toBeInTheDocument();
  });

  it('kabul edilmiş katılımcıyı reddetme sonucu açıklar ve POST /reject yapar', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Başvurular');
    const row = await within(drawer).findByTestId('app-8');
    await userEvent.click(within(row).getByRole('button', { name: 'Reddet' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('etkinlikten çıkarılır');
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'kurallara aykiri davranis');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Reddet' }));
    await waitFor(() =>
      expect(calls.some((c) => c.url === '/api/admin/events/1/applications/8/reject')).toBe(true),
    );
  });

  it('durum süzgeci sunucuya gider', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Başvurular');
    await within(drawer).findByTestId('app-7');
    await userEvent.selectOptions(within(drawer).getByLabelText('Durum'), 'WAITLISTED');
    await waitFor(() =>
      expect(calls.some((c) => c.url.includes('/applications?') && c.url.includes('status=WAITLISTED'))).toBe(
        true,
      ),
    );
  });
});

describe('P07: yoklama', () => {
  it('özet ve satırlar gelir; sertifikalı kişiyi gelmedi yapmanın sertifika etkisi yazılır; PUT gövdesi doğru', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Yoklama');
    const row = await within(drawer).findByTestId('att-21');
    expect(within(drawer).getByTestId('att-summary')).toHaveTextContent('Gelen');
    expect(row).toHaveTextContent('Geldi');
    await userEvent.click(within(row).getByRole('button', { name: 'Gelmedi yap' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ali Veli gelmedi olarak işaretlensin mi?' });
    expect(dialog).toHaveTextContent('sertifikası geçersiz sayılır');
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'kapida yanlis okutma');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Düzelt' }));
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'PUT' && c.url === '/api/admin/events/1/attendance/21')).toBe(
        true,
      ),
    );
    const put = calls.find((c) => c.method === 'PUT')!;
    expect(put.body).toEqual({ present: false, reason: 'kapida yanlis okutma' });
    expect(decodeURIComponent(put.headers['X-Admin-Reason'])).toBe('kapida yanlis okutma');
  });

  it('işaretsiz kişide iki düzeltme düğmesi, gelen kişide yalnız Gelmedi yap vardır', async () => {
    setup();
    const drawer = await openDrawerTab('Yoklama');
    const unmarked = await within(drawer).findByTestId('att-22');
    expect(within(unmarked).getByRole('button', { name: 'Geldi yap' })).toBeInTheDocument();
    expect(within(unmarked).getByRole('button', { name: 'Gelmedi yap' })).toBeInTheDocument();
    const present = within(drawer).getByTestId('att-21');
    expect(within(present).queryByRole('button', { name: 'Geldi yap' })).not.toBeInTheDocument();
  });

  it('CSV düğmesi maskeli yoklama CSV uç noktasını çağırır', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Yoklama');
    await within(drawer).findByTestId('att-21');
    await userEvent.click(within(drawer).getByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url === '/api/admin/events/1/attendance.csv')).toBe(true));
  });
});

describe('P07: sertifikalar', () => {
  it('iptal İPTAL yazdırır + sebep ister; sonra POST /revoke gider', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Sertifikalar');
    const row = await within(drawer).findByTestId('cert-21');
    expect(row).toHaveTextContent('ABCD...QRST');
    await userEvent.click(within(row).getByRole('button', { name: 'İptal et' }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Sertifikayı iptal et' });
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'sahte katilim tespit edildi');
    expect(confirm).toBeDisabled(); // yazarak onay eksik
    await userEvent.type(within(dialog).getByLabelText('Onay metni'), 'iptal');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() =>
      expect(calls.some((c) => c.url === '/api/admin/events/1/certificates/21/revoke')).toBe(true),
    );
  });

  it('iptal edilmiş sertifikada Geri al sunulur ve iptal sebebi görünür', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Sertifikalar');
    const row = await within(drawer).findByTestId('cert-22');
    expect(row).toHaveTextContent('sahte katilim');
    expect(within(row).queryByRole('button', { name: 'İptal et' })).not.toBeInTheDocument();
    await userEvent.click(within(row).getByRole('button', { name: 'Geri al' }));
    const dialog = await screen.findByRole('dialog', { name: 'Cem Can sertifika iptali geri alınsın mı?' });
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'yanlis iptal edilmisti');
    await userEvent.click(within(dialog).getByRole('button', { name: 'İptali geri al' }));
    await waitFor(() =>
      expect(calls.some((c) => c.url === '/api/admin/events/1/certificates/22/restore')).toBe(true),
    );
  });
});

describe('P07: geri bildirim, duyuru, düzenleyen', () => {
  it('geri bildirim anonimdir: kimlik gösterilmez; silme sebep ister ve DELETE gönderir', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Geri bildirim');
    const card = await within(drawer).findByTestId('fb-41');
    expect(card).toHaveTextContent('Cok guzeldi');
    expect(within(drawer).getByText(/anonimdir/)).toBeInTheDocument();
    expect(drawer.textContent).not.toMatch(/userId|@bingol/);
    await userEvent.click(within(card).getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Geri alınamaz');
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'hakaret iceren yorum');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'DELETE' && c.url === '/api/admin/events/1/feedback/41')).toBe(
        true,
      ),
    );
    const del = calls.find((c) => c.method === 'DELETE')!;
    expect(decodeURIComponent(del.headers['X-Admin-Reason'])).toBe('hakaret iceren yorum');
  });

  it('duyuru kaydı silme sonucu (bildirimler geri alınmaz) açıkça yazar', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Duyurular');
    const card = await within(drawer).findByTestId('ann-51');
    expect(card).toHaveTextContent('12 alıcı');
    await userEvent.click(within(card).getByRole('button', { name: 'Kaydı sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('geri alınmaz');
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'yanlis etkinlige gonderilmis');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydı sil' }));
    await waitFor(() =>
      expect(
        calls.some((c) => c.method === 'DELETE' && c.url === '/api/admin/events/1/announcements/51'),
      ).toBe(true),
    );
  });

  it('sahip korunur (çıkarma düğmesi yok); ortak düzenleyen sebeple çıkarılır', async () => {
    const calls = setup();
    const drawer = await openDrawerTab('Düzenleyenler');
    const owner = await within(drawer).findByTestId('org-5');
    expect(within(owner).queryByRole('button', { name: 'Çıkar' })).not.toBeInTheDocument();
    expect(owner).toHaveTextContent('Sahip çıkarılamaz');
    const co = within(drawer).getByTestId('org-6');
    await userEvent.click(within(co).getByRole('button', { name: 'Çıkar' }));
    const dialog = await screen.findByRole('alertdialog');
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'yetki kotuye kullanildi');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Çıkar' }));
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'DELETE' && c.url === '/api/admin/events/1/organizers/6')).toBe(
        true,
      ),
    );
  });
});

describe('P07: listede toplu işlem ve CSV', () => {
  it('seçim çubuğu çıkar; gizleme sebep ister, POST /bulk gövdesi doğru; kısmi başarı raporlanır', async () => {
    const calls = setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ALL' });
    await screen.findByText('etkinlik-1');
    await userEvent.click(screen.getByRole('checkbox', { name: 'etkinlik-1 etkinliğini seç' }));
    await userEvent.click(screen.getByRole('checkbox', { name: 'etkinlik-2 etkinliğini seç' }));
    expect(await screen.findByText('2 satır seçili')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri gizle' }));
    const dialog = await screen.findByRole('dialog', { name: '2 etkinlik gizlensin mi?' });
    const confirm = within(dialog).getByRole('button', { name: 'Gizle' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'toplu inceleme sonucu');
    await userEvent.click(confirm);
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'POST' && c.url === '/api/admin/events/bulk')).toBe(true),
    );
    const post = calls.find((c) => c.url === '/api/admin/events/bulk')!;
    expect(post.body).toEqual({ action: 'HIDE', ids: [1, 2], reason: 'toplu inceleme sonucu' });
    expect(decodeURIComponent(post.headers['X-Admin-Reason'])).toBe('toplu inceleme sonucu');
    const report = await screen.findByTestId('bulk-result');
    expect(report).toHaveTextContent('1 / 2 etkinlik işlendi, 1 atlandı');
    expect(report).toHaveTextContent('#2');
    expect(report).toHaveTextContent('Etkinliğin durumu bu işleme uygun değil');
    // seçim temizlendi
    expect(screen.queryByText('2 satır seçili')).not.toBeInTheDocument();
  });

  it('toplu iptal yıkıcıdır (alertdialog, geri alınamaz) ve sebepsiz gönderilmez', async () => {
    const calls = setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ALL' });
    await screen.findByText('etkinlik-1');
    await userEvent.click(screen.getByRole('checkbox', { name: 'etkinlik-1 etkinliğini seç' }));
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri iptal et' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Geri alınamaz');
    expect(within(dialog).getByRole('button', { name: 'İptal et' })).toBeDisabled();
    expect(calls.some((c) => c.url.endsWith('/bulk'))).toBe(false);
  });

  it('liste CSV düğmesi mevcut süzgeçle export.csv ister', async () => {
    const calls = setup();
    renderWithProviders(<EventsAdminPage />, { route: '/admin/events?status=ACTIVE' });
    await screen.findByText('etkinlik-1');
    await userEvent.click(screen.getByRole('button', { name: 'Listeyi CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/events/export.csv'))).toBe(true));
    expect(calls.find((c) => c.url.includes('export.csv'))?.url).toContain('status=ACTIVE');
  });
});
