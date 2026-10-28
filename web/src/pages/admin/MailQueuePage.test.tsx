// P13: mail kuyruğu — maskeli liste, içeriksiz ayrıntı, tek ve toplu yeniden dene/iptal, günlük kota kartı.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MailQueuePage from './MailQueuePage';
import { QuotaBody } from './mail/MailQuotaCard';
import type { QuotaView } from '../../api/adminMailOps';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}

const quota = (over: Partial<QuotaView> = {}): QuotaView => ({
  mailEnabled: true,
  enabled: true,
  limit: 300,
  reserve: 60,
  announcementCap: 240,
  used: 255,
  remaining: 45,
  announcementRemaining: 0,
  percent: 85,
  level: 'WARN',
  resetHourUtc: 21,
  dayStart: '2026-10-27T21:00:00Z',
  nextReset: '2026-10-28T21:05:00Z',
  publicCodeUsed: 12,
  publicCodeCapRegistration: 180,
  publicCodeCapReset: 255,
  maxCodesPerEmailPerDay: 10,
  maxCodeRequestsPerIpPerDay: 100,
  history: [
    { date: '2026-10-26T21:00:00Z', used: 120 },
    { date: '2026-10-27T21:00:00Z', used: 255 },
  ],
  historyNote: 'x',
  queue: { pending: 4, failed: 1, dead: 3, skipped: 2, oldestPendingAt: null },
  ...over,
});

const row = (over: Record<string, unknown> = {}) => ({
  id: 1,
  status: 'DEAD',
  template: 'ACCOUNT_DELETED',
  category: 'TRANSACTIONAL',
  toMasked: 'a***@bingol.edu.tr',
  lang: 'tr',
  attempts: 5,
  nextAttemptAt: '2026-10-28T10:00:00Z',
  createdAt: '2026-10-28T09:00:00Z',
  sentAt: null,
  lastError: 'SMTPSendFailedException: 550 a***@bingol.edu.tr unavailable',
  retryable: true,
  cancellable: false,
  ...over,
});
const detail = (over: Record<string, unknown> = {}) => ({
  ...row(),
  retryBlockedCode: null,
  contentCleared: false,
  contentIncluded: false,
  timeline: [
    { at: '2026-10-28T09:00:00Z', event: 'CREATED', detail: null },
    { at: null, event: 'DEAD', detail: 'SMTPSendFailedException' },
  ],
  warnings: [],
  ...over,
});

function setup(items: ReturnType<typeof row>[], det: ReturnType<typeof detail>, bulk?: unknown, q: QuotaView = quota()) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url === '/api/admin/mail/quota') return jsonResponse(200, q);
    if (method === 'GET' && /\/admin\/mail\/outbox\/\d+$/.test(url)) return jsonResponse(200, det);
    if (method === 'GET' && url.startsWith('/api/admin/mail/outbox')) {
      return jsonResponse(200, { items, page: 0, size: 20, total: items.length, totalPages: 1 });
    }
    if (url.endsWith('/bulk')) return jsonResponse(200, bulk);
    if (method === 'POST') return jsonResponse(200, det);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET');
/** En üstteki (son açılan) diyalog: çekmece açıkken onay diyaloğu ondan sonra eklenir. */
async function topDialog() {
  const all = await screen.findAllByRole('dialog');
  return all[all.length - 1];
}

describe('kuyruk listesi', () => {
  it('alıcıyı maskeli, durumu metinle gösterir; içerik alanı yoktur', async () => {
    setup([row(), row({ id: 2, status: 'SENT', retryable: false, lastError: null })], detail());
    renderWithProviders(<MailQueuePage />);
    expect((await screen.findAllByText('a***@bingol.edu.tr')).length).toBe(2);
    const table = within(screen.getByRole('table'));
    expect(table.getByText('Başarısız (ölü)')).toBeInTheDocument();
    expect(table.getByText('Gönderildi')).toBeInTheDocument();
    expect(table.getAllByText('Hesap silindi').length).toBe(2);
    expect(screen.queryByText(/varsJson/)).toBeNull();
  });

  it('süzgeç değişince durum sorguya gider', async () => {
    const calls = setup([row()], detail());
    renderWithProviders(<MailQueuePage />);
    const user = userEvent.setup();
    await screen.findAllByText('a***@bingol.edu.tr');
    await user.selectOptions(screen.getByLabelText('Durum'), 'DEAD');
    await waitFor(() => expect(calls.some((c) => c.url.includes('/outbox?') && c.url.includes('status=DEAD'))).toBe(true));
  });
});

describe('ayrıntı çekmecesi', () => {
  it('içerik gösterilmez notu, geçmiş ve yeniden dene (sebepli) gösterir', async () => {
    const calls = setup([row()], detail());
    renderWithProviders(<MailQueuePage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(/gizlilik gereği gösterilmez/)).toBeInTheDocument();
    expect(within(drawer).getByText('Kuyruğa alındı')).toBeInTheDocument();
    expect(within(drawer).getByText('Denemeler tükendi (ölü)')).toBeInTheDocument();
    await user.click(within(drawer).getByRole('button', { name: 'Yeniden dene' }));
    const dialog = await topDialog();
    const confirm = within(dialog).getByRole('button', { name: 'Yeniden dene' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'sunucu düzeldi');
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].url).toBe('/api/admin/mail/outbox/1/retry');
    expect(decodeURIComponent(writes(calls)[0].headers['X-Admin-Reason'])).toBe('sunucu düzeldi');
  });

  it('içeriği silinmiş kayıtta yeniden deneme kapalıdır ve nedeni yazar', async () => {
    setup(
      [row({ id: 3, retryable: false, template: 'ANNOUNCEMENT', category: 'ANNOUNCEMENT' })],
      detail({ id: 3, template: 'ANNOUNCEMENT', category: 'ANNOUNCEMENT', retryable: false, contentCleared: true, retryBlockedCode: 'MAILOPS_RETRY_NO_CONTENT' }),
    );
    renderWithProviders(<MailQueuePage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(/içeriği gizlilik gereği silindiği için yeniden üretilemez|Posta içeriği gizlilik gereği silindiği/)).toBeInTheDocument();
    expect(within(drawer).getByRole('button', { name: 'Yeniden dene' })).toBeDisabled();
  });

  it('bekleyen kayıt iptal edilir (geri alınamaz uyarısı + sebep)', async () => {
    const calls = setup(
      [row({ id: 4, status: 'PENDING', retryable: false, cancellable: true })],
      detail({ id: 4, status: 'PENDING', retryable: false, cancellable: true, warnings: ['CODE_MAIL'] }),
    );
    renderWithProviders(<MailQueuePage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(/Kod postası: kod yalnızca 10 dakika/)).toBeInTheDocument();
    await user.click(within(drawer).getByRole('button', { name: 'İptal et' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('geri alınamaz');
    await user.type(within(dialog).getByLabelText(/Sebep/), 'yanlış gönderim');
    await user.click(within(dialog).getByRole('button', { name: 'İptal et' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].url).toBe('/api/admin/mail/outbox/4/cancel');
  });
});

describe('toplu işlem', () => {
  it('yalnız uygun kayıtların kimliğini gönderir; kısmi sonucu nedenleriyle gösterir', async () => {
    const items = [
      row({ id: 1, retryable: true }),
      row({ id: 2, status: 'PENDING', retryable: false, cancellable: true }),
      row({ id: 3, retryable: false }),
    ];
    const calls = setup(items, detail(), {
      action: 'RETRY',
      requested: 1,
      succeeded: 0,
      failed: [{ id: 1, code: 'MAILOPS_RETRY_STATE' }],
    });
    renderWithProviders(<MailQueuePage />);
    const user = userEvent.setup();
    await screen.findAllByText('a***@bingol.edu.tr');
    const boxes = screen.getAllByRole('checkbox');
    // ilk onay kutusu "tümünü seç"
    await user.click(boxes[0]);
    const bar = await screen.findByRole('region', { name: 'Toplu işlemler' });
    expect(within(bar).getByText(/1 kayıt yeniden denenebilir, 1 kayıt iptal edilebilir/)).toBeInTheDocument();
    await user.click(within(bar).getByRole('button', { name: 'Toplu yeniden dene' }));
    const dialog = await topDialog();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'toplu düzeltme');
    await user.click(within(dialog).getByRole('button', { name: 'Toplu yeniden dene' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].url).toBe('/api/admin/mail/outbox/bulk');
    expect(writes(calls)[0].body).toEqual({ action: 'RETRY', ids: [1], reason: 'toplu düzeltme' });
    expect(await screen.findByText(/0 \/ 1 kayıt işlendi, 1 kayıt işlenemedi/)).toBeInTheDocument();
    expect(screen.getByText(/Yalnızca ölü ya da atlanmış kayıt yeniden denenebilir/)).toBeInTheDocument();
  });
});

describe('günlük kota kartı', () => {
  it('%80 ve üstünde ilerleme çubuğu, uyarı metni ve kalan değerleri gösterir', async () => {
    setup([], detail());
    renderWithProviders(<MailQueuePage />);
    const bar = await screen.findByRole('progressbar', { name: 'Günlük kota kullanımı' });
    expect(bar).toHaveAttribute('aria-valuenow', '85');
    expect(await screen.findByText(/Uyarı: günlük kotanın %85 kadarı kullanıldı/)).toBeInTheDocument();
    expect(screen.getByText('45')).toBeInTheDocument();
    expect(screen.getByText('Uyarı')).toBeInTheDocument();
  });

  it('kritik düzeyde metin farklıdır', () => {
    renderWithProviders(<QuotaBody q={quota({ used: 290, percent: 96.7, level: 'CRITICAL', remaining: 10 })} />);
    expect(screen.getByText('Kritik')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Kritik: günlük kotanın %97');
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '97');
  });

  it('normal düzeyde uyarı yok', () => {
    renderWithProviders(<QuotaBody q={quota({ used: 30, percent: 10, level: 'OK', remaining: 270, announcementRemaining: 210 })} />);
    expect(screen.getByText('Normal')).toBeInTheDocument();
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('sınırsız kipte çubuk yok, açıklama var', () => {
    renderWithProviders(<QuotaBody q={quota({ enabled: false, percent: -1, limit: 0, remaining: -1, level: 'OFF', used: 5 })} />);
    expect(screen.queryByRole('progressbar')).toBeNull();
    expect(screen.getByText(/Günlük kota sınırı tanımlı değil/)).toBeInTheDocument();
  });
});
