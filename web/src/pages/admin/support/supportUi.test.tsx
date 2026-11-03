// Destek yönetimi arayüzü: talep kuyruğu (süzgeçler, durumlar) ve ayrıntıda ekler (küçük resim, büyük görüntüleyici,
// video, yükleme ilerlemesi, ön kontrol, yanıtla birlikte attachmentIds). Ağ: sahte fetch + sahte XMLHttpRequest.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import TicketDetailPage from '../TicketDetailPage';
import TicketsPage from '../TicketsPage';

interface Call {
  method: string;
  url: string;
  path: string;
  body: unknown;
}

function record(handler: (c: Call) => Response | undefined) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const c: Call = {
      method: init.method ?? 'GET',
      url,
      path: url.split('?')[0],
      body: typeof init.body === 'string' ? JSON.parse(init.body) : undefined,
    };
    calls.push(c);
    return handler(c) ?? jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const png = () => new Response(new Blob(['x'], { type: 'image/png' }), { status: 200 });

// ---- sahte XMLHttpRequest (yükleme ilerlemesi) ----
class FakeXHR {
  static all: FakeXHR[] = [];
  upload: { onprogress: ((e: { lengthComputable: boolean; loaded: number; total: number }) => void) | null } = { onprogress: null };
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  status = 0;
  responseText = '';
  aborted = false;
  file: File | null = null;
  headers: Record<string, string> = {};
  constructor() {
    FakeXHR.all.push(this);
  }
  open() {}
  setRequestHeader(k: string, v: string) {
    this.headers[k] = v;
  }
  getResponseHeader() {
    return null;
  }
  send(form: FormData) {
    this.file = form.get('file') as File;
  }
  abort() {
    this.aborted = true;
    this.onabort?.();
  }
  progress(loaded: number, total: number) {
    this.upload.onprogress?.({ lengthComputable: true, loaded, total });
  }
  respond(status: number, body: unknown) {
    this.status = status;
    this.responseText = JSON.stringify(body);
    this.onload?.();
  }
}

const att = (id: number, kind: 'IMAGE' | 'VIDEO', name: string) => ({
  id,
  kind,
  url: `/api/admin/support/attachments/${id}/file`,
  thumbUrl: `/api/admin/support/attachments/${id}/thumb`,
  mime: kind === 'IMAGE' ? 'image/jpeg' : 'video/mp4',
  bytes: 120_000,
  name,
  width: 800,
  height: 600,
  durationMs: kind === 'VIDEO' ? 12_000 : null,
});

beforeEach(() => {
  FakeXHR.all = [];
  vi.stubGlobal('XMLHttpRequest', FakeXHR);
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: vi.fn(() => 'blob:x'), revokeObjectURL: vi.fn() }));
  Element.prototype.scrollIntoView = vi.fn();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  window.localStorage.clear();
});

// ---------------------------------------------------------------- liste

describe('Talep kuyruğu', () => {
  const item = (over: Record<string, unknown>) => ({
    id: 1,
    userId: 7,
    userEmail: 'ayse@bingol.edu.tr',
    publicTicket: false,
    category: 'TECHNICAL',
    subject: 'Giriş sorunu',
    status: 'OPEN',
    createdAt: '2026-11-01T10:00:00Z',
    updatedAt: new Date(Date.now() - 3 * 3600_000).toISOString(),
    ...over,
  });
  const rows = [
    item({ id: 1, attachmentCount: 2 }),
    item({ id: 2, subject: 'Şifre sıfırlama', category: 'ACCOUNT', status: 'ANSWERED', userEmail: 'mehmet@bingol.edu.tr', priority: 'URGENT' }),
    item({ id: 3, subject: 'Kapalı konu', category: 'OTHER', status: 'CLOSED', userEmail: null, publicTicket: true, userId: null }),
  ];

  function renderList() {
    return renderWithProviders(
      <Routes>
        <Route path="/admin/support/tickets" element={<TicketsPage />} />
      </Routes>,
      { route: '/admin/support/tickets' },
    );
  }

  it('satırlar ayrıntıya bağlantıdır; durum, kategori, kullanıcı, ek sayısı ve göreli zaman görünür', async () => {
    record((c) => (c.path === '/api/admin/support/tickets' ? jsonResponse(200, { items: rows, nextCursor: null }) : undefined));
    renderList();
    const link = await screen.findByRole('link', { name: /Giriş sorunu/ });
    expect(link).toHaveAttribute('href', '/admin/support/tickets/1');
    expect(link).toHaveTextContent('#1');
    expect(link).toHaveTextContent('Teknik');
    expect(link).toHaveTextContent('ayse@bingol.edu.tr');
    expect(link).toHaveTextContent('Yanıt bekliyor');
    expect(link).toHaveTextContent('3 sa önce');
    expect(within(link).getByText('2 ek')).toBeInTheDocument();
    const urgent = screen.getByRole('link', { name: /Şifre sıfırlama/ });
    expect(urgent).toHaveTextContent('Acil');
    expect(screen.getByRole('link', { name: /Kapalı konu/ })).toHaveTextContent('Misafir');
  });

  it('durum düğmesi sunucuya status gönderir; kategori ve arama yüklenen satırlarda süzer', async () => {
    const calls = record((c) => (c.path === '/api/admin/support/tickets' ? jsonResponse(200, { items: rows, nextCursor: null }) : undefined));
    renderList();
    await screen.findByRole('link', { name: /Giriş sorunu/ });

    await userEvent.selectOptions(screen.getByLabelText('Kategori'), 'ACCOUNT');
    expect(screen.queryByRole('link', { name: /Giriş sorunu/ })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Şifre sıfırlama/ })).toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent('1 sonuç');
    await userEvent.selectOptions(screen.getByLabelText('Kategori'), '');

    await userEvent.type(screen.getByRole('searchbox'), 'mehmet');
    await waitFor(() => expect(screen.queryByRole('link', { name: /Giriş sorunu/ })).not.toBeInTheDocument());
    expect(screen.getByRole('link', { name: /Şifre sıfırlama/ })).toBeInTheDocument();

    await userEvent.clear(screen.getByRole('searchbox'));
    await userEvent.click(screen.getByRole('button', { name: 'Kapalı' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=CLOSED'))).toBe(true));
  });

  it('boş durum, hata ve yeniden deneme', async () => {
    let fail = true;
    record((c) => {
      if (c.path !== '/api/admin/support/tickets') return undefined;
      return fail ? jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }) : jsonResponse(200, { items: [], nextCursor: null });
    });
    renderList();
    const retry = await screen.findByRole('button', { name: /tekrar dene/i });
    fail = false;
    await userEvent.click(retry);
    expect(await screen.findByText('Bu filtrede talep yok')).toBeInTheDocument();
  });

  it('daha fazla yükle imecini kullanır', async () => {
    const calls = record((c) => {
      if (c.path !== '/api/admin/support/tickets') return undefined;
      return c.url.includes('cursor=1')
        ? jsonResponse(200, { items: [item({ id: 0, subject: 'Eski talep' })], nextCursor: null })
        : jsonResponse(200, { items: [rows[0]], nextCursor: 1 });
    });
    renderList();
    await screen.findByRole('link', { name: /Giriş sorunu/ });
    await userEvent.click(screen.getByRole('button', { name: /daha fazla/i }));
    expect(await screen.findByRole('link', { name: /Eski talep/ })).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('cursor=1'))).toBe(true);
  });
});

// ---------------------------------------------------------------- ayrıntı + ekler

describe('Talep ayrıntısı: ekler', () => {
  const base = {
    ticket: {
      id: 5,
      category: 'TECHNICAL',
      subject: 'Giriş sorunu',
      status: 'OPEN',
      createdAt: '2026-11-01T10:00:00Z',
      updatedAt: '2026-11-01T10:00:00Z',
      publicTicket: false,
    },
    messages: [
      {
        id: 1,
        fromStaff: false,
        internal: false,
        text: 'Ekran görüntüsü ekledim',
        createdAt: '2026-11-01T10:00:00Z',
        authorId: null,
        attachments: [att(11, 'IMAGE', 'hata.jpg'), att(12, 'IMAGE', 'ikinci.jpg'), att(13, 'VIDEO', 'kayit.mp4')],
      },
    ],
    userId: 7,
    userEmail: 'ayse@bingol.edu.tr',
    priority: 'NORMAL',
    assigneeId: null,
    assigneeName: null,
  };

  function setup(extra?: (c: Call) => Response | undefined) {
    return record((c) => {
      if (c.method === 'GET' && c.path === '/api/admin/support/tickets/5') return jsonResponse(200, base);
      if (c.path.includes('/attachments/')) return png();
      return extra?.(c);
    });
  }
  function renderDetail() {
    return renderWithProviders(
      <Routes>
        <Route path="/admin/support/tickets/:id" element={<TicketDetailPage />} />
      </Routes>,
      { route: '/admin/support/tickets/5' },
    );
  }

  it('talep bilgisi panelinde kullanıcı, kategori ve durum görünür', async () => {
    setup();
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    const panel = screen.getByRole('complementary', { name: 'Talep bilgisi' });
    expect(within(panel).getByText('ayse@bingol.edu.tr')).toBeInTheDocument();
    expect(within(panel).getByText('Yanıt bekliyor')).toBeInTheDocument();
    expect(within(panel).getByText('Teknik')).toBeInTheDocument();
    expect(within(panel).getByRole('link', { name: 'Kullanıcı #7' })).toHaveAttribute('href', '/admin/users/7');
  });

  it('görseller küçük resim olarak gelir; tıklayınca büyük görüntüleyici açılır, oklarla gezilir, Esc kapatır', async () => {
    setup();
    renderDetail();
    const first = await screen.findByRole('button', { name: 'Görseli büyüt: hata.jpg' });
    expect(await screen.findAllByRole('img', { name: 'hata.jpg' })).not.toHaveLength(0);
    await userEvent.click(first);
    const dialog = await screen.findByRole('dialog', { name: 'Görsel görüntüleyici' });
    expect(within(dialog).getByText('hata.jpg')).toBeInTheDocument();
    expect(within(dialog).getByText(/1 \/ 2/)).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Önceki görsel' })).toBeDisabled();
    await userEvent.keyboard('{ArrowRight}');
    expect(within(dialog).getByText('ikinci.jpg')).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Sonraki görsel' })).toBeDisabled();
    await userEvent.keyboard('{Escape}');
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Görsel görüntüleyici' })).not.toBeInTheDocument());
    expect(screen.getByRole('button', { name: 'Görseli büyüt: hata.jpg' })).toHaveFocus();
  });

  it('video tıklanana kadar indirilmez; tıklayınca kontrollü oynatıcı gelir', async () => {
    const calls = setup();
    renderDetail();
    const play = await screen.findByRole('button', { name: 'Videoyu oynat: kayit.mp4' });
    expect(calls.some((c) => c.path.endsWith('/attachments/13/file'))).toBe(false);
    await userEvent.click(play);
    await waitFor(() => expect(document.querySelector('video[controls]')).not.toBeNull());
    expect(calls.some((c) => c.path.endsWith('/attachments/13/file'))).toBe(true);
  });

  it('dosya ekleme: ilerleme gösterilir, tamamlanınca yanıt attachmentIds ile gider ve liste boşalır', async () => {
    const calls = setup((c) => {
      if (c.method === 'POST' && c.path === '/api/admin/support/tickets/5/reply')
        return jsonResponse(200, { ticket: base.ticket, messages: base.messages, emailStatus: 'NOT_APPLICABLE' });
      return undefined;
    });
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    await userEvent.type(screen.getByLabelText('Yanıtınız'), 'Güncelleyin');
    await userEvent.upload(screen.getByTestId('attach-input'), new File([new Uint8Array(2000)], 'cozum.png', { type: 'image/png' }));

    const xhr = FakeXHR.all[0];
    expect(xhr.file?.name).toBe('cozum.png');
    expect(screen.getByText('cozum.png')).toBeInTheDocument();
    // yükleme sürerken gönder kapalı
    expect(screen.getByRole('button', { name: 'Yanıtla' })).toBeDisabled();
    xhr.progress(50, 100);
    expect(await screen.findByRole('progressbar', { name: 'cozum.png' })).toHaveAttribute('aria-valuenow', '50');
    expect(screen.getByText('Yükleniyor… 50%')).toBeInTheDocument();

    xhr.respond(201, att(31, 'IMAGE', 'cozum.png'));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Yanıtla' })).toBeEnabled());
    expect(screen.getByText(/^Hazır · /)).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Yanıtla' }));
    await waitFor(() => expect(calls.some((c) => c.path.endsWith('/reply'))).toBe(true));
    expect(calls.find((c) => c.path.endsWith('/reply'))!.body).toEqual({ text: 'Güncelleyin', attachmentIds: [31] });
    await waitFor(() => expect(screen.queryByText('cozum.png')).not.toBeInTheDocument());
  });

  it('ön kontrol: desteklenmeyen tür ve büyük dosya yüklenmez, açıklayıcı hata gösterilir', async () => {
    setup();
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    const input = screen.getByTestId('attach-input');
    fireEvent.change(input, { target: { files: [new File(['x'], 'not.pdf', { type: 'application/pdf' })] } });
    expect(await screen.findByRole('alert')).toHaveTextContent('not.pdf: desteklenmeyen dosya türü');
    const big = new File(['x'], 'dev.jpg', { type: 'image/jpeg' });
    Object.defineProperty(big, 'size', { value: 9 * 1024 * 1024 });
    fireEvent.change(input, { target: { files: [big] } });
    expect(await screen.findByRole('alert')).toHaveTextContent('dev.jpg: görsel 8 MB sınırını aşıyor');
    expect(FakeXHR.all).toHaveLength(0);
  });

  it('sunucu hatası satırda gösterilir; yeniden dene yeniden yükler; kaldır siler', async () => {
    setup();
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    await userEvent.upload(screen.getByTestId('attach-input'), new File([new Uint8Array(10)], 'a.png', { type: 'image/png' }));
    FakeXHR.all[0].respond(413, { code: 'ATTACHMENT_TOO_LARGE', message: 'x' });
    expect(await screen.findByText(/Dosya çok büyük/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Yeniden dene' }));
    expect(FakeXHR.all).toHaveLength(2);
    await userEvent.click(screen.getByRole('button', { name: 'Eki kaldır: a.png' }));
    expect(FakeXHR.all[1].aborted).toBe(true);
    expect(screen.queryByText('a.png')).not.toBeInTheDocument();
  });

  it('sürükle-bırak dosya ekler', async () => {
    setup();
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    const drop = screen.getByTestId('attach-drop');
    const f = new File([new Uint8Array(10)], 'surukle.webp', { type: 'image/webp' });
    fireEvent.dragEnter(drop, { dataTransfer: { types: ['Files'], files: [f] } });
    expect(screen.getByText('Dosyaları buraya bırakın')).toBeInTheDocument();
    fireEvent.drop(drop, { dataTransfer: { types: ['Files'], files: [f] } });
    await waitFor(() => expect(FakeXHR.all).toHaveLength(1));
    expect(FakeXHR.all[0].file?.name).toBe('surukle.webp');
  });

  it('herkese açık talepte e-posta gönderilemezse kalıcı uyarı gösterilir', async () => {
    setup((c) =>
      c.method === 'POST' && c.path.endsWith('/reply')
        ? jsonResponse(200, { ticket: { ...base.ticket, publicTicket: true }, messages: base.messages, emailStatus: 'FAILED' })
        : undefined,
    );
    renderDetail();
    await screen.findByText('Ekran görüntüsü ekledim');
    await userEvent.type(screen.getByLabelText('Yanıtınız'), 'Merhaba');
    await userEvent.click(screen.getByRole('button', { name: 'Yanıtla' }));
    const alerts = await screen.findAllByRole('alert');
    expect(alerts.some((a) => a.textContent?.includes('e-posta gönderilemedi'))).toBe(true);
  });
});
