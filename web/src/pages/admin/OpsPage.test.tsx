import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { levelOf, safeHttpsUrl } from '../../api/ops';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import OpsPage from './OpsPage';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  init: RequestInit;
}

function setup() {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.endsWith('/admin/ops/health'))
      return jsonResponse(200, {
        status: 'WARN',
        components: {
          mailQueue: { status: 'UP', details: { pending: 0, dead: 0 } },
          pushQueue: { status: 'WARN', details: { dead: 2 } },
        },
      });
    if (url.endsWith('/status'))
      return jsonResponse(200, {
        NEWS: { maintenance: true, lastSuccessAt: '2026-10-26T10:00:00Z' },
        MENU: { maintenance: false, lastSuccessAt: null },
      });
    if (url.endsWith('/admin/push/outbox/stats'))
      return jsonResponse(200, {
        enabled: true,
        pending: 3,
        sending: 0,
        failed: 1,
        dead: 4,
        sentLast24h: 120,
        oldestPendingAgeSeconds: 12,
      });
    if (url.endsWith('/admin/push/outbox/retry-dead') && method === 'POST')
      return jsonResponse(200, { requeued: 4 });
    if (url.endsWith('/admin/ops/backup-status'))
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    if (url.includes('/admin/ops/')) return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    if (url.endsWith('/admin/settings') && method === 'GET')
      return jsonResponse(200, {
        maintenance_mode: 'true',
        min_version_android: '1.2.0',
        ops_sentry_url: 'https://sentry.example.com/x',
      });
    if (url.includes('/admin/settings/') && method === 'PUT') return new Response(null, { status: 204 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Operasyon paneli', () => {
  it('sağlık bileşenlerini ve bakımdaki kaynakları gösterir', async () => {
    setup();
    renderWithProviders(<OpsPage />);
    expect(await screen.findByText('pushQueue')).toBeInTheDocument();
    expect(screen.getByText('mailQueue')).toBeInTheDocument();
    expect(await screen.findByText('Bakımda')).toBeInTheDocument();
  });

  it('kuyruk istatistiklerini gösterir, ölüleri yeniden dener; eksik uç için "Veri yok" der', async () => {
    const calls = setup();
    renderWithProviders(<OpsPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'Kuyruklar' }));
    expect(await screen.findByText('120')).toBeInTheDocument();
    expect((await screen.findAllByText('Veri yok')).length).toBeGreaterThan(0);
    await userEvent.click(screen.getByRole('button', { name: 'Ölüleri yeniden dene' }));
    await waitFor(() =>
      expect(
        calls.some((c) => c.url.endsWith('/admin/push/outbox/retry-dead') && c.init.method === 'POST'),
      ).toBe(true),
    );
  });

  it('yedekleme ucu yoksa zarifçe "Veri yok" gösterir', async () => {
    setup();
    renderWithProviders(<OpsPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'Yedekleme' }));
    expect(await screen.findByText('Veri yok')).toBeInTheDocument();
  });

  it('dış bağlantı yalnızca https kabul eder ve kaydeder', async () => {
    const calls = setup();
    renderWithProviders(<OpsPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'Dış bağlantılar' }));
    const input = await screen.findByLabelText('Grafana (metrikler)');
    await userEvent.type(input, 'http://x.example.com');
    expect(await screen.findByText('Geçerli bir https:// adresi girin.')).toBeInTheDocument();
    await userEvent.clear(input);
    await userEvent.type(input, 'https://grafana.example.com');
    await userEvent.click(screen.getAllByRole('button', { name: 'Kaydet' })[1]);
    await waitFor(() =>
      expect(
        calls.some((c) => c.url.endsWith('/admin/settings/ops_grafana_url') && c.init.method === 'PUT'),
      ).toBe(true),
    );
  });
});

describe('ops yardımcıları', () => {
  it('durumları seviyeye çevirir', () => {
    expect(levelOf('up')).toBe('UP');
    expect(levelOf('OUT_OF_SERVICE')).toBe('DOWN');
    expect(levelOf('WARN')).toBe('WARN');
    expect(levelOf(undefined)).toBe('UNKNOWN');
  });
  it('yalnız https adreslerini kabul eder', () => {
    expect(safeHttpsUrl('https://a.example.com')).toContain('https://a.example.com');
    expect(safeHttpsUrl('http://a.example.com')).toBeNull();
    expect(safeHttpsUrl('javascript:alert(1)')).toBeNull();
  });
});
