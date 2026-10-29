// CR1: çökme raporları — gruplu liste, süzgeç, ayrıntı çekmecesi (anonim uyarı, sürüm dağılımı, yığın izi),
// sebepli durum değişikliği/silme ve izin kontrolü.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import CrashesPage, { statusTone } from './CrashesPage';

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

const group = (over: Record<string, unknown> = {}) => ({
  id: 7,
  errorType: 'StateError',
  message: null,
  topFrame: 'Foo.bar (package:bu_kampus/features/x/x_page.dart:10:5)',
  status: 'NEW',
  eventCount: 14,
  firstSeenAt: '2026-10-20T09:00:00Z',
  lastSeenAt: '2026-10-28T09:00:00Z',
  firstVersion: '1.0.0',
  lastVersion: '1.2.0',
  reopenCount: 0,
  statusReason: null,
  statusBy: null,
  statusAt: null,
  fixedInVersion: null,
  versions: [
    { version: '1.2.0', platform: 'ANDROID', count: 9 },
    { version: '1.1.0', platform: 'IOS', count: 4 },
    { version: '1.0.0', platform: 'ANDROID', count: 1 },
    { version: '0.9.0', platform: 'OTHER', count: 1 },
  ],
  ...over,
});

const detail = (g = group()) => ({
  group: g,
  events: [
    {
      id: 1,
      appVersion: '1.2.0',
      platform: 'ANDROID',
      osVersion: 'Android 14',
      deviceModel: null,
      screen: '/news',
      fatal: true,
      message: null,
      stack: '#0      Foo.bar (package:bu_kampus/features/x/x_page.dart:10:5)\n#1      _baz (package:bu_kampus/core/api.dart:77:3)',
      occurredAt: '2026-10-28T09:00:00Z',
      receivedAt: '2026-10-28T09:00:01Z',
    },
  ],
});

const summary = { newGroups: 3, ackGroups: 2, resolvedGroups: 5, events24h: 41, reopened: 1 };

function setup(items: ReturnType<typeof group>[], det = detail()) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url === '/api/admin/rbac/me') {
      return jsonResponse(200, { profile: 'FULL', permissions: ['system.read', 'system.write', 'admin.full'], twoPerson: false });
    }
    if (url === '/api/admin/crashes/summary') return jsonResponse(200, summary);
    if (method === 'GET' && /\/admin\/crashes\/\d+$/.test(url)) return jsonResponse(200, det);
    if (method === 'GET' && url.startsWith('/api/admin/crashes')) {
      return jsonResponse(200, { items, page: 0, totalPages: 1, totalItems: items.length });
    }
    if (method === 'PATCH') return jsonResponse(200, det);
    if (method === 'DELETE') return new Response(null, { status: 204 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET');
async function topDialog() {
  const all = await screen.findAllByRole('dialog');
  return all[all.length - 1];
}

describe('liste', () => {
  it('özet kartlarını, grubu, sürüm özetini ve kalan sürüm sayısını gösterir', async () => {
    setup([group()]);
    renderWithProviders(<CrashesPage />);
    expect(await screen.findByText('StateError')).toBeInTheDocument();
    const stats = await screen.findByTestId('crash-summary');
    expect(within(stats).getByText('41')).toBeInTheDocument();
    expect(within(stats).getByText('Son 24 saatte rapor')).toBeInTheDocument();
    const table = within(screen.getByRole('table'));
    expect(table.getByText('Yeni')).toBeInTheDocument();
    expect(table.getByText(/1\.2\.0 · A · 9/)).toBeInTheDocument();
    expect(table.getByText('+1 daha')).toBeInTheDocument();
  });

  it('süzgeç değişince durum, platform ve sürüm sorguya gider', async () => {
    const calls = setup([group()]);
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await screen.findByText('StateError');
    await user.selectOptions(screen.getByLabelText('Durum'), 'ACK');
    await user.selectOptions(screen.getByLabelText('Platform'), 'IOS');
    await user.type(screen.getByLabelText('Sürüm'), '1.2.0');
    await waitFor(() =>
      expect(
        calls.some(
          (c) => c.url.includes('/admin/crashes?') && c.url.includes('status=ACK') && c.url.includes('platform=IOS') && c.url.includes('version=1.2.0'),
        ),
      ).toBe(true),
    );
  });

  it('yeniden açılan grup rozetini gösterir', async () => {
    setup([group({ reopenCount: 2 })]);
    renderWithProviders(<CrashesPage />);
    expect(await screen.findByText('Yeniden açıldı (2)')).toBeInTheDocument();
  });

  it('durum tonları', () => {
    expect(statusTone('NEW')).toBe('danger');
    expect(statusTone('ACK')).toBe('warning');
    expect(statusTone('RESOLVED')).toBe('success');
  });
});

describe('ayrıntı çekmecesi', () => {
  it('anonim notu, sürüm dağılımı ve maskeli yığın izini gösterir', async () => {
    setup([group()]);
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(/Bu raporlar anonimdir/)).toBeInTheDocument();
    expect(within(drawer).getByRole('heading', { name: 'Sürüm dağılımı' })).toBeInTheDocument();
    expect(within(drawer).getByLabelText('Yığın izi')).toHaveTextContent('package:bu_kampus/core/api.dart:77:3');
    expect(within(drawer).getByText('Yakalanmamış')).toBeInTheDocument();
  });

  it('incelemeye alma sebep ister ve sebebi başlık ile gövdede gönderir', async () => {
    const calls = setup([group()]);
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'İncelemeye al' }));
    const dialog = await topDialog();
    const confirm = within(dialog).getByRole('button', { name: 'İncelemeye al' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'inceleniyor');
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0];
    expect(w.method).toBe('PATCH');
    expect(w.url).toBe('/api/admin/crashes/7/status');
    expect(w.body).toMatchObject({ status: 'ACK', reason: 'inceleniyor' });
    expect(decodeURIComponent(w.headers['X-Admin-Reason'])).toBe('inceleniyor');
  });

  it('çözüldü işaretlenirken düzeltme sürümü gönderilir', async () => {
    const calls = setup([group({ status: 'ACK' })], detail(group({ status: 'ACK' })));
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    await user.type(await within(drawer).findByLabelText(/Düzeltme sürümü/), '1.3.0');
    await user.click(within(drawer).getByRole('button', { name: 'Çözüldü olarak işaretle' }));
    const dialog = await topDialog();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'düzeltme yayında');
    await user.click(within(dialog).getByRole('button', { name: 'Çözüldü olarak işaretle' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].body).toMatchObject({ status: 'RESOLVED', fixedInVersion: '1.3.0' });
  });

  it('silme geri alınamaz uyarısı ve sebep ister', async () => {
    const calls = setup([group()]);
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    await user.click(await within(drawer).findByRole('button', { name: 'Grubu sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('geri alınamaz');
    await user.type(within(dialog).getByLabelText(/Sebep/), 'gürültülü grup');
    await user.click(within(dialog).getByRole('button', { name: 'Grubu sil' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].method).toBe('DELETE');
    expect(writes(calls)[0].url).toBe('/api/admin/crashes/7');
    expect(decodeURIComponent(writes(calls)[0].headers['X-Admin-Reason'])).toBe('gürültülü grup');
  });

  it('yazma izni yoksa eylem düğmeleri devre dışıdır', async () => {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, method: init.method ?? 'GET', headers: {}, body: undefined });
      if (url === '/api/admin/rbac/me') {
        return jsonResponse(200, { profile: 'VIEWER', permissions: ['system.read'], twoPerson: false });
      }
      if (url === '/api/admin/crashes/summary') return jsonResponse(200, summary);
      if (/\/admin\/crashes\/\d+$/.test(url)) return jsonResponse(200, detail());
      return jsonResponse(200, { items: [group()], page: 0, totalPages: 1, totalItems: 1 });
    });
    renderWithProviders(<CrashesPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    const del = await within(drawer).findByRole('button', { name: 'Grubu sil' });
    await waitFor(() => expect(del).toBeDisabled());
  });
});
