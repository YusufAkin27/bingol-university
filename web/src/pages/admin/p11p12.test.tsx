// P11/P12 sayfa testleri: ihlaller + af, gizlenen içerik + geri alma, karar şablonları, CSV, talep iç notu/öncelik/atama/silme,
// geri bildirim silme/birleştirme, SSS sıralama.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AppealsPage from './AppealsPage';
import FaqAdminPage from './FaqAdminPage';
import FeedbackPage from './FeedbackPage';
import HiddenContentPage from './HiddenContentPage';
import ReasonTemplatesPage from './ReasonTemplatesPage';
import ReportsPage from './ReportsPage';
import StrikesPage from './StrikesPage';
import TicketDetailPage from './TicketDetailPage';
import TicketsPage from './TicketsPage';

interface Call {
  method: string;
  url: string;
  path: string;
  body: unknown;
  headers: Record<string, string>;
}

function record(handler: (c: Call) => Response | undefined) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const call: Call = {
      method: init.method ?? 'GET',
      url,
      path: url.split('?')[0],
      body: init.body ? JSON.parse(String(init.body)) : undefined,
      headers: (init.headers ?? {}) as Record<string, string>,
    };
    calls.push(call);
    return handler(call) ?? jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: vi.fn(() => 'blob:x'), revokeObjectURL: vi.fn() }));
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  window.localStorage.clear();
});

const page = <T,>(items: T[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1 });
const csvResponse = () => new Response('id\r\n', { status: 200, headers: { 'Content-Type': 'text/csv' } });

async function fillReason(dialog: HTMLElement, text = 'Gerekçe yeterince uzun') {
  await userEvent.type(within(dialog).getByLabelText(/^Sebep/), text);
}

// ---------------------------------------------------------------- ihlaller

const strike = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  userId: 40 + id,
  userName: `Ayse ${id}`,
  userEmail: `a${id}@bingol.edu.tr`,
  reportId: 1,
  targetType: 'POST',
  targetId: 100 + id,
  resolution: 'HIDE',
  createdAt: '2026-10-01T10:00:00Z',
  revokedAt: null,
  active: true,
  forgiven: false,
  forgivenBy: null,
  forgivenReason: null,
  ...over,
});

describe('P11: ihlaller', () => {
  function setup() {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/moderation/strikes')
        return jsonResponse(
          200,
          page([
            strike(1),
            strike(2, { active: false, forgiven: true, revokedAt: '2026-10-02T10:00:00Z', forgivenReason: 'Hatali karar' }),
            strike(3, { active: false, forgiven: false, revokedAt: '2026-10-02T10:00:00Z' }),
          ]),
        );
      if (c.method === 'POST' && c.path === '/api/admin/moderation/strikes/1/forgive')
        return jsonResponse(200, { id: 1, userId: 41, remaining: 0 });
      return undefined;
    });
  }

  it('varsayılan olarak sayılanları ister; yalnız sayılan ihlalde Affet düğmesi vardır', async () => {
    const calls = setup();
    renderWithProviders(<StrikesPage />);
    await screen.findByText('Ayse 1');
    expect(calls[0].url).toContain('status=ACTIVE');
    expect(screen.getAllByRole('button', { name: 'Affet' })).toHaveLength(1);
    expect(screen.getByText('Affedildi')).toBeInTheDocument();
    expect(screen.getByText('İptal (itiraz kabulü)')).toBeInTheDocument();
    expect(screen.getByText('Af sebebi: Hatali karar')).toBeInTheDocument();
  });

  it('süzgeç değişince istek parametreleri güncellenir', async () => {
    const calls = setup();
    renderWithProviders(<StrikesPage />);
    await screen.findByText('Ayse 1');
    await userEvent.type(screen.getByLabelText('Kullanıcı kimliği'), '41');
    await waitFor(() => expect(calls.some((c) => c.url.includes('userId=41'))).toBe(true));
    await userEvent.selectOptions(screen.getByLabelText('Durum'), 'ALL');
    await waitFor(() => expect(calls[calls.length - 1].url).not.toContain('status='));
  });

  it('af: sebep yazmadan onaylanmaz; sebep başlığı + gövde + Idempotency-Key ile POST gider', async () => {
    const calls = setup();
    renderWithProviders(<StrikesPage />);
    await screen.findByText('Ayse 1');
    await userEvent.click(screen.getByRole('button', { name: 'Affet' }));
    const dialog = await screen.findByRole('dialog', { name: 'İhlali affet' });
    const confirm = within(dialog).getByRole('button', { name: 'Affet' });
    expect(confirm).toBeDisabled();
    expect(within(dialog).getByText('Bu işlem geri alınamaz.')).toBeInTheDocument();
    await fillReason(dialog, 'Hatali karar verilmisti');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.method === 'POST')!;
    expect(post.path).toBe('/api/admin/moderation/strikes/1/forgive');
    expect(post.body).toEqual({ reason: 'Hatali karar verilmisti' });
    expect(post.headers['X-Admin-Reason']).toBe(encodeURIComponent('Hatali karar verilmisti'));
    expect(post.headers['Idempotency-Key']).toBeTruthy();
  });
});

// ---------------------------------------------------------------- gizlenen içerik

describe('P11: gizlenen içerik', () => {
  const row = (type: string, id: number, over: Record<string, unknown> = {}) => ({
    targetType: type,
    targetId: id,
    hiddenBy: 'AUTO',
    hiddenAt: '2026-10-01T10:00:00Z',
    reversible: true,
    exists: true,
    ownerId: 5,
    ownerName: 'Sahip Kisi',
    preview: { kind: 'TEXT', url: null, thumbnailUrl: null, mime: null, text: `metin-${id}` },
    ...over,
  });

  function setup() {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/moderation/hidden')
        return jsonResponse(
          200,
          page([
            row('POST', 7),
            row('USER', 9, { reversible: false, hiddenBy: 'ADMIN', preview: null }),
            row('POST', 11, { exists: false, preview: null }),
          ]),
        );
      if (c.method === 'POST' && c.path === '/api/admin/moderation/hidden/POST/7/restore')
        return jsonResponse(200, { targetType: 'POST', targetId: 7, unhidden: true });
      return undefined;
    });
  }

  it('yalnız geri alınabilir ve var olan içerikte Geri al görünür; diğerlerinde neden yazar', async () => {
    setup();
    renderWithProviders(<HiddenContentPage />);
    await screen.findByText('metin-7');
    expect(screen.getAllByRole('button', { name: 'Geri al' })).toHaveLength(1);
    expect(screen.getByText('Bu tür geri alınamaz; yalnız yönetici kararıyla gizlenir.')).toBeInTheDocument();
    expect(screen.getByText('İçerik silinmiş; geri alınacak bir şey yok.')).toBeInTheDocument();
    expect(screen.getAllByText('Yönetici kararı').length).toBeGreaterThan(1); // süzgeç seçeneği + satır rozeti
  });

  it('geri alma: sebep zorunlu, doğru yola POST gider', async () => {
    const calls = setup();
    renderWithProviders(<HiddenContentPage />);
    await screen.findByText('metin-7');
    await userEvent.click(screen.getByRole('button', { name: 'Geri al' }));
    const dialog = await screen.findByRole('dialog', { name: 'İçeriği yeniden yayına al' });
    const confirm = within(dialog).getByRole('button', { name: 'Geri al' });
    expect(confirm).toBeDisabled();
    await fillReason(dialog, 'Itiraz haklı bulundu');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.method === 'POST')!;
    expect(post.path).toBe('/api/admin/moderation/hidden/POST/7/restore');
    expect(post.body).toEqual({ reason: 'Itiraz haklı bulundu' });
    expect(post.headers['X-Admin-Reason']).toBeTruthy();
  });
});

// ---------------------------------------------------------------- karar şablonları

describe('P11: karar şablonları', () => {
  const tpl = (id: number, over: Record<string, unknown> = {}) => ({
    id,
    kind: 'DECISION',
    code: `KOD_${id}`,
    textTr: `Metin ${id}`,
    textEn: null,
    textAr: null,
    active: true,
    sortOrder: id * 10,
    updatedAt: '2026-10-01T10:00:00Z',
    ...over,
  });

  function setup(count = 2) {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/moderation/reason-templates')
        return jsonResponse(200, { items: Array.from({ length: count }, (_, i) => tpl(i + 1)), max: 50 });
      if (c.method === 'POST' && c.path === '/api/admin/moderation/reason-templates') return jsonResponse(201, tpl(9));
      if (c.method === 'PUT' && c.path === '/api/admin/moderation/reason-templates/1') return jsonResponse(200, tpl(1));
      if (c.method === 'DELETE' && c.path === '/api/admin/moderation/reason-templates/1') return jsonResponse(204);
      return undefined;
    });
  }

  it('listeler; en/ar boşsa Türkçeye düşeceğini belirtir', async () => {
    setup();
    renderWithProviders(<ReasonTemplatesPage />);
    await screen.findByText('Metin 1');
    expect(screen.getByText('2 / 50 şablon')).toBeInTheDocument();
    expect(screen.getAllByText('EN: Türkçe · AR: Türkçe')).toHaveLength(2);
  });

  it('boş form hata gösterir ve istek atmaz; geçerli formda büyük harfli kodla POST gider', async () => {
    const calls = setup();
    renderWithProviders(<ReasonTemplatesPage />);
    await screen.findByText('Metin 1');
    await userEvent.click(screen.getByRole('button', { name: 'Şablon ekle' }));
    const dialog = await screen.findByRole('dialog', { name: 'Yeni şablon' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dialog).findByText('Türkçe metin zorunludur.')).toBeInTheDocument();
    expect(within(dialog).getByText(/Kod harfle başlamalı/)).toBeInTheDocument();
    expect(calls.some((c) => c.method === 'POST')).toBe(false);

    await userEvent.type(within(dialog).getByLabelText(/^Kod/), 'kural_ihlali');
    await userEvent.type(within(dialog).getByLabelText(/^Türkçe metin/), 'Kural ihlali');
    await userEvent.type(within(dialog).getByLabelText(/^İngilizce metin/), 'Rule violation');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    expect(calls.find((c) => c.method === 'POST')!.body).toEqual({
      code: 'KURAL_IHLALI',
      textTr: 'Kural ihlali',
      textEn: 'Rule violation',
      textAr: '',
      active: true,
    });
  });

  it('düzenlemede kod değişmez ve gönderilmez', async () => {
    const calls = setup();
    renderWithProviders(<ReasonTemplatesPage />);
    await screen.findByText('Metin 1');
    await userEvent.click(screen.getAllByRole('button', { name: 'Düzenle' })[0]);
    const dialog = await screen.findByRole('dialog', { name: 'Şablonu düzenle' });
    expect(within(dialog).getByLabelText(/^Kod/)).toBeDisabled();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT')).toBe(true));
    const put = calls.find((c) => c.method === 'PUT')!;
    expect('code' in (put.body as object)).toBe(false);
    expect((put.body as { textTr: string }).textTr).toBe('Metin 1');
  });

  it('silme: sebep zorunlu, DELETE sebep başlığıyla gider', async () => {
    const calls = setup();
    renderWithProviders(<ReasonTemplatesPage />);
    await screen.findByText('Metin 1');
    await userEvent.click(screen.getAllByRole('button', { name: 'Sil' })[0]);
    const dialog = await screen.findByRole('alertdialog', { name: 'Şablonu sil' });
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    expect(confirm).toBeDisabled();
    await fillReason(dialog, 'Artik kullanilmiyor');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    const del = calls.find((c) => c.method === 'DELETE')!;
    expect(del.path).toBe('/api/admin/moderation/reason-templates/1');
    expect(del.headers['X-Admin-Reason']).toBe(encodeURIComponent('Artik kullanilmiyor'));
  });

  it('50 şablonda ekleme kapanır', async () => {
    setup(50);
    renderWithProviders(<ReasonTemplatesPage />);
    await screen.findByText('Metin 1');
    expect(screen.getByRole('button', { name: 'Şablon ekle' })).toBeDisabled();
    expect(screen.getByText('Üst sınıra ulaşıldı')).toBeInTheDocument();
  });
});

// ---------------------------------------------------------------- CSV düğmeleri

describe('P11/P12: CSV düğmeleri', () => {
  it('raporlar: durum + tür süzgeciyle istenir ve indirilir', async () => {
    const calls = record((c) => {
      if (c.path === '/api/admin/reports/export.csv') return csvResponse();
      if (c.path === '/api/admin/reports/reason-templates') return jsonResponse(200, []);
      if (c.path === '/api/admin/reports') return jsonResponse(200, { items: [], nextCursor: null });
      return undefined;
    });
    renderWithProviders(<ReportsPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.path === '/api/admin/reports/export.csv')).toBe(true));
    expect(calls.find((c) => c.path === '/api/admin/reports/export.csv')!.url).toContain('status=OPEN');
    await waitFor(() => expect(HTMLAnchorElement.prototype.click).toHaveBeenCalled());
  });

  it('itirazlar', async () => {
    const calls = record((c) => {
      if (c.path === '/api/admin/appeals/export.csv') return csvResponse();
      if (c.path === '/api/admin/moderation/appeals') return jsonResponse(200, { items: [], nextCursor: null });
      return undefined;
    });
    renderWithProviders(<AppealsPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.path === '/api/admin/appeals/export.csv')).toBe(true));
    expect(calls.find((c) => c.path === '/api/admin/appeals/export.csv')!.url).toContain('status=OPEN');
  });

  it('talepler ve geri bildirimler', async () => {
    const calls = record((c) => {
      if (c.path.endsWith('/export.csv')) return csvResponse();
      if (c.path === '/api/admin/support/tickets') return jsonResponse(200, { items: [], nextCursor: null });
      if (c.path === '/api/admin/feedback') return jsonResponse(200, { items: [], nextCursor: null });
      return undefined;
    });
    const t = renderWithProviders(<TicketsPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.path === '/api/admin/support/tickets/export.csv')).toBe(true));
    t.unmount();
    renderWithProviders(<FeedbackPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.path === '/api/admin/support/feedback/export.csv')).toBe(true));
  });
});

// ---------------------------------------------------------------- talep ayrıntısı (P12)

describe('P12: talep ayrıntısı', () => {
  const NOTE = 'DAHILI-NOT-METNI';
  const detail = (over: Record<string, unknown> = {}, status = 'OPEN') => ({
    ticket: {
      id: 5,
      category: 'TECHNICAL',
      subject: 'Giriş sorunu',
      status,
      createdAt: '2026-01-01T10:00:00Z',
      updatedAt: '2026-01-01T10:00:00Z',
      publicTicket: false,
    },
    messages: [
      { id: 1, fromStaff: false, internal: false, text: 'Giremiyorum', createdAt: '2026-01-01T10:00:00Z', authorId: null },
      { id: 1, fromStaff: true, internal: true, text: NOTE, createdAt: '2026-01-01T10:30:00Z', authorId: 9 },
    ],
    userId: 7,
    userEmail: 'u@bingol.edu.tr',
    priority: 'NORMAL',
    assigneeId: null,
    assigneeName: null,
    ...over,
  });

  function setup(initial = detail(), after?: Record<string, Response>) {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/support/tickets/5') return jsonResponse(200, initial);
      if (c.method === 'POST' && c.path === '/api/admin/support/tickets/5/notes')
        return jsonResponse(201, { id: 2, fromStaff: true, internal: true, text: 'yeni', createdAt: '2026-01-02T10:00:00Z', authorId: 9 });
      if (c.method === 'PATCH' && c.path === '/api/admin/support/tickets/5')
        return jsonResponse(200, detail({ priority: 'URGENT', assigneeId: 12, assigneeName: 'Yonetici Oniki' }));
      if (c.method === 'POST' && c.path === '/api/admin/support/tickets/5/reopen')
        return jsonResponse(200, detail({}, 'OPEN'));
      if (c.method === 'DELETE' && c.path === '/api/admin/support/tickets/5') return jsonResponse(204);
      return after?.[c.path];
    });
  }

  function renderDetail() {
    return renderWithProviders(
      <Routes>
        <Route path="/admin/support/tickets/:id" element={<TicketDetailPage />} />
        <Route path="/admin/support/tickets" element={<p>TALEP-LISTESI</p>} />
      </Routes>,
      { route: '/admin/support/tickets/5' },
    );
  }

  it('iç not yazışma sekmesinde GÖRÜNMEZ; İç notlar sekmesinde uyarıyla görünür', async () => {
    setup();
    renderDetail();
    await screen.findByText('Giremiyorum');
    expect(screen.queryByText(NOTE)).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('tab', { name: 'İç notlar (1)' }));
    expect(await screen.findByText(NOTE)).toBeInTheDocument();
    expect(screen.getByRole('note')).toHaveTextContent('müşteriye GÖRÜNMEZ');
    expect(screen.queryByText('Giremiyorum')).not.toBeInTheDocument();
  });

  it('iç not ekleme: boşken kapalı, doğru uca POST eder', async () => {
    const calls = setup();
    renderDetail();
    await screen.findByText('Giremiyorum');
    await userEvent.click(screen.getByRole('tab', { name: 'İç notlar (1)' }));
    const add = screen.getByRole('button', { name: 'Notu ekle' });
    expect(add).toBeDisabled();
    await userEvent.type(screen.getByLabelText('Yeni iç not'), '  ekip icin not  ');
    await userEvent.click(add);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.method === 'POST')!;
    expect(post.path).toBe('/api/admin/support/tickets/5/notes');
    expect(post.body).toEqual({ text: 'ekip icin not' });
  });

  it('öncelik değişince PATCH {priority} gider', async () => {
    const calls = setup();
    renderDetail();
    await screen.findByText('Giremiyorum');
    await userEvent.selectOptions(screen.getByLabelText('Öncelik'), 'URGENT');
    await waitFor(() => expect(calls.some((c) => c.method === 'PATCH')).toBe(true));
    expect(calls.find((c) => c.method === 'PATCH')!.body).toEqual({ priority: 'URGENT' });
  });

  it('atama: geçersiz kimlikte kapalı; geçerlide PATCH {assigneeId}; atanmışsa kaldırılabilir', async () => {
    const calls = setup(detail({ assigneeId: 3, assigneeName: 'Yonetici Uc' }));
    renderDetail();
    await screen.findByText('Giremiyorum');
    expect(screen.getByTestId('assignee-now')).toHaveTextContent('Atanan: Yonetici Uc');
    const assign = screen.getByRole('button', { name: 'Ata' });
    expect(assign).toBeDisabled();
    await userEvent.type(screen.getByLabelText('Yönetici kimliği'), '12');
    await userEvent.click(assign);
    await waitFor(() => expect(calls.some((c) => c.method === 'PATCH')).toBe(true));
    expect(calls.find((c) => c.method === 'PATCH')!.body).toEqual({ assigneeId: 12 });
    await userEvent.click(await screen.findByRole('button', { name: 'Atamayı kaldır' }));
    await waitFor(() => expect(calls.filter((c) => c.method === 'PATCH')).toHaveLength(2));
    expect(calls.filter((c) => c.method === 'PATCH')[1].body).toEqual({ unassign: true });
  });

  it('kapalı talepte Yeniden aç görünür ve POST /reopen gider', async () => {
    const calls = setup(detail({}, 'CLOSED'));
    renderDetail();
    await screen.findByText('Giremiyorum');
    expect(screen.queryByRole('button', { name: 'Talebi kapat' })).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Yeniden aç' }));
    await waitFor(() => expect(calls.some((c) => c.path === '/api/admin/support/tickets/5/reopen')).toBe(true));
  });

  it('silme: sebep + SİL yazmadan açılmaz; DELETE sebep başlığıyla gider ve liste açılır', async () => {
    const calls = setup();
    renderDetail();
    await screen.findByText('Giremiyorum');
    await userEvent.click(screen.getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Talebi kalıcı olarak sil' });
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    expect(confirm).toBeDisabled();
    await fillReason(dialog, 'Mukerrer talep silindi');
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Onay metni' }), 'sil');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    const del = calls.find((c) => c.method === 'DELETE')!;
    expect(del.path).toBe('/api/admin/support/tickets/5');
    expect(del.headers['X-Admin-Reason']).toBe(encodeURIComponent('Mukerrer talep silindi'));
    expect(await screen.findByText('TALEP-LISTESI')).toBeInTheDocument();
  });

  it('eski sunucu yanıtı (internal/priority alanı yok) hata vermez; tüm mesajlar sohbettedir', async () => {
    setup({
      ticket: detail().ticket,
      messages: [{ id: 1, fromStaff: false, text: 'Eski mesaj', createdAt: '2026-01-01T10:00:00Z' }],
      userEmail: 'u@bingol.edu.tr',
    } as unknown as ReturnType<typeof detail>);
    renderDetail();
    expect(await screen.findByText('Eski mesaj')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'İç notlar (0)' })).toBeInTheDocument();
    expect(screen.getByLabelText('Öncelik')).toHaveValue('NORMAL');
  });
});

// ---------------------------------------------------------------- geri bildirim (P12)

describe('P12: geri bildirim silme/birleştirme', () => {
  const item = {
    id: 3,
    userId: 7,
    userEmail: 'u@bingol.edu.tr',
    category: 'SUGGESTION',
    subject: 'Karanlık tema',
    message: 'Olsa güzel olur',
    status: 'NEW',
    adminResponse: null,
    publicVisible: true,
    voteCount: 4,
    appVersion: null,
    platform: null,
    createdAt: '2026-01-01T10:00:00Z',
  };

  function setup() {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/feedback') return jsonResponse(200, { items: [item], nextCursor: null });
      if (c.method === 'POST' && c.path === '/api/admin/support/feedback/merge')
        return jsonResponse(200, { sourceId: 3, targetId: 12, voteCount: 5 });
      if (c.method === 'DELETE' && c.path === '/api/admin/support/feedback/3') return jsonResponse(204);
      return undefined;
    });
  }

  async function openDrawer() {
    renderWithProviders(<FeedbackPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Değerlendir' }));
    return screen.findByRole('dialog');
  }

  it('birleştirme: hedef kimliği olmadan ve kendisiyle birleştirme kapalı; sebep + gövde ile POST gider', async () => {
    const calls = setup();
    const drawer = await openDrawer();
    const merge = within(drawer).getByRole('button', { name: 'Birleştir' });
    expect(merge).toBeDisabled();
    await userEvent.type(within(drawer).getByLabelText(/^Birleştirilecek hedef kimliği/), '3');
    expect(merge).toBeDisabled();
    await userEvent.clear(within(drawer).getByLabelText(/^Birleştirilecek hedef kimliği/));
    await userEvent.type(within(drawer).getByLabelText(/^Birleştirilecek hedef kimliği/), '12');
    expect(merge).toBeEnabled();
    await userEvent.click(merge);
    const dialog = await screen.findByRole('alertdialog', { name: 'Geri bildirimi birleştir' });
    await fillReason(dialog, 'Ayni oneri tekrar edilmis');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Birleştir' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.method === 'POST')!;
    expect(post.path).toBe('/api/admin/support/feedback/merge');
    expect(post.body).toEqual({ sourceId: 3, targetId: 12, reason: 'Ayni oneri tekrar edilmis' });
    expect(post.headers['X-Admin-Reason']).toBeTruthy();
  });

  it('silme: sebep + SİL yazmak gerekir; DELETE sebep başlığıyla gider', async () => {
    const calls = setup();
    const drawer = await openDrawer();
    await userEvent.click(within(drawer).getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Geri bildirimi kalıcı olarak sil' });
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    await fillReason(dialog, 'Uygunsuz icerik');
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Onay metni' }), 'SİL');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    expect(calls.find((c) => c.method === 'DELETE')!.headers['X-Admin-Reason']).toBe(encodeURIComponent('Uygunsuz icerik'));
  });
});

// ---------------------------------------------------------------- SSS sıralama (P12)

describe('P12: SSS sıralama', () => {
  const faq = (id: number, order: number) => ({
    id,
    lang: 'tr',
    category: 'Genel',
    question: `Soru ${id}`,
    answer: `Cevap ${id}`,
    sortOrder: order,
    published: true,
  });

  function setup(nextCursor?: string) {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/faq')
        return new Response(JSON.stringify([faq(1, 10), faq(2, 20), faq(3, 30)]), {
          status: 200,
          headers: { 'Content-Type': 'application/json', ...(nextCursor ? { 'X-Next-Cursor': nextCursor } : {}) },
        });
      if (c.method === 'PUT' && c.path === '/api/admin/faq/order') return jsonResponse(200, [faq(2, 10), faq(1, 20), faq(3, 30)]);
      return undefined;
    });
  }

  it('aşağı taşı: yeni sıra kimlik dizisi olarak PUT edilir; sınır düğmeleri kapalıdır', async () => {
    const calls = setup();
    renderWithProviders(<FaqAdminPage />);
    await screen.findByText('Soru 1');
    const ups = screen.getAllByRole('button', { name: 'Yukarı taşı' });
    const downs = screen.getAllByRole('button', { name: 'Aşağı taşı' });
    expect(ups[0]).toBeDisabled();
    expect(downs[2]).toBeDisabled();
    await userEvent.click(downs[0]);
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT')).toBe(true));
    const put = calls.find((c) => c.method === 'PUT')!;
    expect(put.path).toBe('/api/admin/faq/order');
    expect(put.body).toEqual({ ids: [2, 1, 3] });
  });

  it('tüm kayıtlar yüklenmemişse sıralama kapalıdır (başka sayfadakilerle çakışmasın)', async () => {
    setup('50');
    renderWithProviders(<FaqAdminPage />);
    await screen.findByText('Soru 1');
    for (const b of screen.getAllByRole('button', { name: 'Aşağı taşı' })) expect(b).toBeDisabled();
    expect(screen.getByText(/Sıralamak için önce tüm kayıtları yükleyin/)).toBeInTheDocument();
  });
});
