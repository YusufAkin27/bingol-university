import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PushOpsPage from './PushOpsPage';

type Call = { url: string; init: RequestInit };
const calls = (fn: ReturnType<typeof mockFetch>): Call[] =>
  fn.mock.calls.map(([url, init]) => ({ url: String(url), init: (init ?? {}) as RequestInit }));

const FCM_ON = { enabled: true, validated: false, projectId: 'bu-kampus-prod', error: null };

const row = (id: number, status: string, extra: Record<string, unknown> = {}) => ({
  id,
  status,
  type: 'ANNOUNCEMENT',
  campaignId: 7,
  targetRef: 'a1b2c3d4...',
  userRef: '1***5',
  attempts: status === 'DEAD' ? 6 : 0,
  errorCode: status === 'DEAD' ? 'UNREGISTERED' : null,
  nextAttemptAt: '2026-10-28T10:00:00Z',
  createdAt: '2026-10-28T09:00:00Z',
  sentAt: null,
  ...extra,
});

const detail = (id: number, status: string) => ({
  ...row(id, status),
  maxAttempts: 6,
  lastError: status === 'DEAD' ? 'UNREGISTERED: cihaz kaydi silindi' : null,
  priority: 0,
  leaseUntil: null,
  canRetry: status === 'DEAD' || status === 'FAILED' || status === 'CANCELLED',
  canCancel: status === 'PENDING' || status === 'FAILED',
});

const STATS = { enabled: true, pending: 3, sending: 1, failed: 2, dead: 9, sentLast24h: 120, oldestPendingAgeSeconds: 60 };

function queueServer(opts: { bulk?: unknown } = {}) {
  return mockFetch((url, init) => {
    if (url.startsWith('/api/admin/push/outbox/stats')) return jsonResponse(200, STATS);
    if (url.startsWith('/api/admin/push/outbox/bulk')) {
      return jsonResponse(
        200,
        opts.bulk ?? { action: 'RETRY', requested: 2, succeeded: 1, failed: [{ id: 2, code: 'INVALID_STATE' }] },
      );
    }
    const one = /^\/api\/admin\/push\/outbox\/(\d+)(\/retry|\/cancel)?/.exec(url);
    if (one) {
      const id = Number(one[1]);
      if (one[2]) return jsonResponse(200, { id, status: one[2] === '/retry' ? 'PENDING' : 'CANCELLED' });
      return jsonResponse(200, detail(id, id === 1 ? 'DEAD' : 'PENDING'));
    }
    if (url.startsWith('/api/admin/push/outbox')) {
      return jsonResponse(200, {
        items: [row(1, 'DEAD'), row(2, 'PENDING')],
        page: 0,
        totalPages: 1,
        totalItems: 2,
      });
    }
    void init;
    return jsonResponse(404, { code: 'X', message: 'x' });
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('PushOpsPage: FCM durumu', () => {
  it('durum ve proje kimliği görünür; iOS hazırlık kartı vardır', async () => {
    mockFetch((url) => (url === '/api/admin/push/fcm/status' ? jsonResponse(200, FCM_ON) : jsonResponse(404, { code: 'X', message: 'x' })));
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops' });
    expect(await screen.findByText('bu-kampus-prod')).toBeInTheDocument();
    expect(screen.getByText('Etkin (kimlik bilgisi yüklü)')).toBeInTheDocument();
    expect(screen.getByText(/GoogleService-Info\.plist dosyası yok/)).toBeInTheDocument();
    expect(screen.getByText(/APNs anahtarı yüklenmeli/)).toBeInTheDocument();
  });

  it('Doğrula: açıklamalı onay sonrası POST gider ve sonuç gösterilir (sebep istenmez)', async () => {
    const f = mockFetch((url, init) => {
      if (url === '/api/admin/push/fcm/status') return jsonResponse(200, FCM_ON);
      if (url === '/api/admin/push/fcm/validate' && init.method === 'POST') {
        return jsonResponse(200, { ...FCM_ON, validated: true });
      }
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops' });
    const user = userEvent.setup();
    const trigger = await screen.findByRole('button', { name: 'Doğrula' });
    await waitFor(() => expect(trigger).toBeEnabled());
    expect(screen.getByText('Dakikada en çok 5 doğrulama yapılabilir.')).toBeInTheDocument();
    await user.click(trigger);

    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent('hiçbir cihaza gitmeyen bir deneme mesajı');
    expect(within(dialog).queryByRole('textbox')).not.toBeInTheDocument(); // sebep alanı yok
    await user.click(within(dialog).getByRole('button', { name: 'Doğrula' }));

    expect(await screen.findByText('Doğrulama başarılı: Firebase bağlantısı çalışıyor.')).toBeInTheDocument();
    expect(calls(f).filter((c) => c.url === '/api/admin/push/fcm/validate' && c.init.method === 'POST')).toHaveLength(1);
  });

  it('hız sınırı (429) anlaşılır mesajla gösterilir ve diyalog açık kalır', async () => {
    mockFetch((url, init) => {
      if (url === '/api/admin/push/fcm/status') return jsonResponse(200, FCM_ON);
      if (url === '/api/admin/push/fcm/validate' && init.method === 'POST') {
        return jsonResponse(429, { code: 'RATE_LIMITED', message: 'Çok fazla istek' });
      }
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops' });
    const user = userEvent.setup();
    const trigger = await screen.findByRole('button', { name: 'Doğrula' });
    await waitFor(() => expect(trigger).toBeEnabled());
    await user.click(trigger);
    const dialog = await screen.findByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: 'Doğrula' }));
    expect(await screen.findByText('Çok sık doğrulama yapıldı (dakikada en çok 5). Birkaç saniye bekleyip yeniden deneyin.')).toBeInTheDocument();
    expect(screen.getByRole('dialog')).toBeInTheDocument(); // hata sonrası diyalog açık kalır
  });

  it('kimlik yokken uyarı gösterilir ve Doğrula devre dışıdır; başarısız doğrulama hata kodunu yazar', async () => {
    mockFetch((url) =>
      url === '/api/admin/push/fcm/status'
        ? jsonResponse(200, { enabled: false, validated: false, projectId: null, error: 'DISABLED' })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops' });
    expect(await screen.findByText('Push gönderimi kapalı')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Doğrula' })).toBeDisabled();
  });

  it('doğrulama başarısızsa hata kodu ve açıklaması görünür', async () => {
    mockFetch((url, init) => {
      if (url === '/api/admin/push/fcm/status') return jsonResponse(200, FCM_ON);
      if (url === '/api/admin/push/fcm/validate' && init.method === 'POST') {
        return jsonResponse(200, { ...FCM_ON, validated: false, error: 'THIRD_PARTY_AUTH_ERROR' });
      }
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops' });
    const user = userEvent.setup();
    const trigger = await screen.findByRole('button', { name: 'Doğrula' });
    await waitFor(() => expect(trigger).toBeEnabled());
    await user.click(trigger);
    await user.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Doğrula' }));
    expect(await screen.findByText('Doğrulama başarısız')).toBeInTheDocument();
    expect(screen.getByText(/THIRD_PARTY_AUTH_ERROR/)).toBeInTheDocument();
  });
});

describe('PushOpsPage: kuyruk', () => {
  it('liste maskeli hedefi ve hata kodunu gösterir; durum süzgeci API parametresine yazılır', async () => {
    const f = queueServer();
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    expect(await screen.findAllByText('a1b2c3d4...')).toHaveLength(2);
    expect(screen.getAllByText('1***5')).toHaveLength(2);
    expect(screen.getByText('UNREGISTERED')).toBeInTheDocument();
    expect(await screen.findByText('9')).toBeInTheDocument(); // ölü sayacı
    expect(document.body.textContent).not.toMatch(/payload|fcmToken/i);

    fireEvent.change(screen.getByLabelText('Durum'), { target: { value: 'DEAD' } });
    await waitFor(() => expect(calls(f).some((c) => c.url.startsWith('/api/admin/push/outbox?') && c.url.includes('status=DEAD'))).toBe(true));
    fireEvent.change(screen.getByLabelText('Kampanya no'), { target: { value: '7' } });
    await waitFor(() => expect(calls(f).some((c) => c.url.includes('campaignId=7') && c.url.includes('status=DEAD'))).toBe(true));
  });

  it('geçersiz kampanya numarası uyarı verir ve istek atılmaz', async () => {
    const f = queueServer();
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    await screen.findAllByText('a1b2c3d4...');
    const before = calls(f).filter((c) => c.url.startsWith('/api/admin/push/outbox?')).length;
    fireEvent.change(screen.getByLabelText('Kampanya no'), { target: { value: 'abc' } });
    expect(await screen.findByText('Geçerli bir kampanya numarası yazın.')).toBeInTheDocument();
    expect(calls(f).filter((c) => c.url.startsWith('/api/admin/push/outbox?')).length).toBe(before);
  });

  it('toplu yeniden dene: etki sayısı + sebep zorunlu; gövde ve kısmi başarı raporu', async () => {
    const f = queueServer();
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    const user = userEvent.setup();
    await screen.findAllByText('a1b2c3d4...');
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).not.toBeInTheDocument();
    for (const b of screen.getAllByRole('checkbox', { name: 'Satırı seç' })) await user.click(b);

    const bar = screen.getByRole('region', { name: 'Toplu işlemler' });
    await user.click(within(bar).getByRole('button', { name: 'Yeniden dene' }));
    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveTextContent('2 kuyruk kaydı etkilenecek');
    const confirm = within(dialog).getByRole('button', { name: 'Seçilenleri yeniden dene' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Firebase kesintisi sonrası');
    expect(confirm).toBeEnabled();
    await user.click(confirm);

    await waitFor(() => expect(calls(f).some((c) => c.url === '/api/admin/push/outbox/bulk')).toBe(true));
    const c = calls(f).find((x) => x.url === '/api/admin/push/outbox/bulk')!;
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ action: 'RETRY', ids: [1, 2], reason: 'Firebase kesintisi sonrası' });
    expect(decodeURIComponent((c.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('Firebase kesintisi sonrası');

    const result = await screen.findByTestId('push-bulk-result');
    expect(result).toHaveTextContent('1 / 2 kayıt işlendi, 1 kayıt atlandı.');
    expect(result).toHaveTextContent('1 kayıt: durumu bu işleme uygun değil');
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).not.toBeInTheDocument();
  });

  it('toplu iptal tehlikeli işlem olarak alertdialog açar ve CANCEL gönderir', async () => {
    const f = queueServer({ bulk: { action: 'CANCEL', requested: 2, succeeded: 2, failed: [] } });
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    const user = userEvent.setup();
    await screen.findAllByText('a1b2c3d4...');
    for (const b of screen.getAllByRole('checkbox', { name: 'Satırı seç' })) await user.click(b);
    await user.click(within(screen.getByRole('region', { name: 'Toplu işlemler' })).getByRole('button', { name: 'İptal et' }));
    const dialog = screen.getByRole('alertdialog');
    await user.type(within(dialog).getByRole('textbox'), 'Yanlış duyuru gönderildi');
    await user.click(within(dialog).getByRole('button', { name: 'Seçilenleri iptal et' }));
    await waitFor(() => expect(calls(f).some((c) => c.url === '/api/admin/push/outbox/bulk')).toBe(true));
    const body = JSON.parse(String(calls(f).find((x) => x.url === '/api/admin/push/outbox/bulk')!.init.body));
    expect(body.action).toBe('CANCEL');
    expect(await screen.findByTestId('push-bulk-result')).toHaveTextContent('2 / 2 kayıt işlendi, 0 kayıt atlandı.');
  });

  it('ayrıntı çekmecesi: yük/token yok notu; ölü kayıtta yeniden dene, iptal yok', async () => {
    const f = queueServer();
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    const user = userEvent.setup();
    const cell = (await screen.findAllByText('#1'))[0];
    await user.click(cell);
    const drawer = await screen.findByRole('dialog', { name: /Kuyruk kaydı #1/ });
    expect(await within(drawer).findByText(/mesaj içeriği ve cihaz belirteci gösterilmez/)).toBeInTheDocument();
    expect(within(drawer).getByText('6 / 6')).toBeInTheDocument();
    expect(within(drawer).getByText('UNREGISTERED: cihaz kaydi silindi')).toBeInTheDocument();
    expect(within(drawer).getByRole('button', { name: 'Yeniden dene' })).toBeInTheDocument();
    expect(within(drawer).queryByRole('button', { name: 'İptal et' })).not.toBeInTheDocument();
    expect(calls(f).some((c) => c.url === '/api/admin/push/outbox/1')).toBe(true);
  });

  it('bekleyen kaydı iptal: sebep zorunlu, POST gövdesinde reason', async () => {
    const f = queueServer();
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=queue' });
    const user = userEvent.setup();
    await user.click((await screen.findAllByText('#2'))[0]);
    const drawer = await screen.findByRole('dialog', { name: /Kuyruk kaydı #2/ });
    await user.click(await within(drawer).findByRole('button', { name: 'İptal et' }));
    const dialog = (await screen.findAllByRole('alertdialog'))[0];
    const confirm = within(dialog).getByRole('button', { name: 'Kaydı iptal et' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Hatalı mesaj içeriği');
    await user.click(confirm);
    await waitFor(() => expect(calls(f).some((c) => c.url === '/api/admin/push/outbox/2/cancel')).toBe(true));
    const c = calls(f).find((x) => x.url === '/api/admin/push/outbox/2/cancel')!;
    expect(c.init.method).toBe('POST');
    expect(JSON.parse(String(c.init.body))).toEqual({ reason: 'Hatalı mesaj içeriği' });
  });
});

describe('PushOpsPage: cihazlar ve istatistikler', () => {
  it('cihaz özeti: sayılar, platform dağılımı grafiği ve erişilebilir tablo alternatifi', async () => {
    mockFetch((url) =>
      url === '/api/admin/push/devices/summary'
        ? jsonResponse(200, {
            totalTokens: 150,
            usersWithDevice: 140,
            byPlatform: { android: 100, ios: 40, web: 5, other: 5 },
            byAppVersion: [
              { version: '1.2.0', count: 90 },
              { version: 'unknown', count: 10 },
            ],
            activeLast7d: 120,
            staleOver30d: 8,
          })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=devices' });
    expect(await screen.findByText('Kayıtlı cihaz')).toBeInTheDocument();
    expect(screen.getByText('150')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /platforma göre dağılımı/ })).toBeInTheDocument();
    const table = screen.getByRole('table', { name: 'Platforma göre cihaz sayıları' });
    expect(within(table).getByText('Android')).toBeInTheDocument();
    expect(within(table).getByText('100')).toBeInTheDocument();
    expect(within(table).getByText('%66,7')).toBeInTheDocument();
    const versions = screen.getByRole('table', { name: 'Uygulama sürümüne göre cihaz sayıları' });
    expect(within(versions).getByText('1.2.0')).toBeInTheDocument();
    expect(within(versions).getByText('Bilinmiyor')).toBeInTheDocument();
    expect(screen.getByText(/kişisel veri .* bu sayfada yok/)).toBeInTheDocument();
  });

  it('bildirim istatistikleri: 14 günlük grafik + günlük tablo + tür dağılımı', async () => {
    const series = Array.from({ length: 14 }, (_, i) => ({
      date: `2026-10-${String(15 + i).padStart(2, '0')}`,
      created: 10 + i,
      read: 5,
    }));
    mockFetch((url) =>
      url.startsWith('/api/admin/notifications/stats')
        ? jsonResponse(200, {
            days: 14,
            series,
            readRate: 0.25,
            created: 217,
            read: 70,
            byType: [
              { type: 'NEWS', count: 150 },
              { type: 'EVENT', count: 67 },
            ],
            totalRows: 5000,
            unreadRows: 1200,
          })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );
    renderWithProviders(<PushOpsPage />, { route: '/admin/push/ops?tab=stats' });
    expect(await screen.findByText('Oluşturulan bildirim')).toBeInTheDocument();
    expect(screen.getAllByText('%25').length).toBeGreaterThan(0);
    expect(screen.getByRole('img', { name: /Son 14 günde oluşturulan ve okunan/ })).toBeInTheDocument();
    const days = screen.getByRole('table', { name: 'Günlük bildirim sayıları' });
    expect(within(days).getAllByRole('row')).toHaveLength(15); // başlık + 14 gün
    const types = screen.getByRole('table', { name: 'Türe göre bildirim sayıları' });
    expect(within(types).getByText('Haber')).toBeInTheDocument();
    expect(within(types).getByText('150')).toBeInTheDocument();
  });
});
