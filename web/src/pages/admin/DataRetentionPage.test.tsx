import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { StorageBanner } from './dataretention/StorageBanner';
import { formatBytes, rangeValid } from './dataretention/format';
import DataRetentionPage from './DataRetentionPage';

const FULL_PERMS = ['data.retention.read', 'data.retention.export', 'data.retention.purge', 'admin.full', 'dashboard.read'];
const VIEWER_PERMS = ['data.retention.read', 'dashboard.read'];

const STORAGE = {
  generatedAt: '2026-10-29T10:00:00Z',
  status: 'WARN',
  worstPercent: 83.4,
  worstKey: 'db-server',
  database: { sizeBytes: 5 * 1024 ** 3, topTables: [{ name: 'analytics_event', totalBytes: 2 * 1024 ** 3, estimatedRows: 9000000 }] },
  dbServerDisk: {
    key: 'db-server', roles: ['db'], source: 'COMPUTED', path: null, totalBytes: 80 * 1024 ** 3,
    usedBytes: 66 * 1024 ** 3, freeBytes: 14 * 1024 ** 3, percent: 83.4, status: 'WARN',
  },
  appDisks: [
    {
      key: 'app:uploads+backups', roles: ['uploads', 'backups'], source: 'MEASURED', path: '/data', totalBytes: 100 * 1024 ** 3,
      usedBytes: 20 * 1024 ** 3, freeBytes: 80 * 1024 ** 3, percent: 20, status: 'OK',
    },
  ],
  warnPercent: 80,
  critPercent: 90,
};

const TABLES = [
  {
    name: 'analytics_event', label: 'Analitik ham olaylar', description: 'Mobil kullanım olayları.', estimatedRows: 9000000,
    sizeBytes: 2 * 1024 ** 3, oldestAt: '2026-01-01T00:00:00Z', minRetentionDays: 7, maxTo: '2026-10-22', deletable: true,
    notDeletableReason: null, personalData: true,
  },
  {
    name: 'message_access_audit', label: 'Sohbet içeriği erişim kaydı', description: 'KVKK kanıtı.', estimatedRows: 10, sizeBytes: 1024,
    oldestAt: null, minRetentionDays: 365, maxTo: '2025-10-29', deletable: false, notDeletableReason: 'Ekleme-yalnız kayıt.', personalData: true,
  },
];

const RECEIPT = {
  id: 7, table: 'analytics_event', from: '1970-01-01', to: '2026-10-22', format: 'CSV_GZIP', status: 'COMPLETED', rowCount: 8000000,
  byteCount: 1234, sha256: 'a'.repeat(64), adminId: 1, adminEmail: 'yonetici@bingol.edu.tr', reason: 'yedek', createdAt: '2026-10-29T09:00:00Z',
  finishedAt: '2026-10-29T09:05:00Z',
};

interface Call {
  url: string;
  init: RequestInit;
}

function setup(opts: { perms?: string[]; storage?: unknown; preview?: unknown; purgeStatuses?: string[] } = {}) {
  const calls: Call[] = [];
  const perms = opts.perms ?? FULL_PERMS;
  const statuses = [...(opts.purgeStatuses ?? ['RUNNING', 'COMPLETED'])];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.endsWith('/admin/rbac/me'))
      return jsonResponse(200, { userId: 1, email: 'a@bingol.edu.tr', displayName: 'A', profile: perms.includes('admin.full') ? 'FULL' : 'VIEWER', pinned: false, permissions: perms });
    if (url.includes('/admin/system/storage')) return jsonResponse(200, opts.storage ?? STORAGE);
    if (url.includes('/purge-preview'))
      return jsonResponse(
        200,
        opts.preview ?? {
          table: 'analytics_event', from: '1970-01-01', to: '2026-10-22', rowsInRange: 8000000, capped: false, estimatedBytes: 1.5 * 1024 ** 3,
          deletable: true, notDeletableReason: null, maxTo: '2026-10-22', minRetentionDays: 7, receipt: RECEIPT, receiptStale: false, canPurge: true, blockers: [],
        },
      );
    if (url.endsWith('/admin/data-retention/tables')) return jsonResponse(200, TABLES);
    if (url.includes('/admin/data-retention/exports/7')) return jsonResponse(200, RECEIPT);
    if (url.endsWith('/admin/data-retention/exports') && method === 'POST') {
      return new Response('GZIPDATA', { status: 200, headers: { 'Content-Type': 'application/gzip', 'X-Export-Receipt-Id': '7', 'Content-Disposition': 'attachment; filename="analytics_event_1970-01-01_2026-10-22.csv.gz"' } });
    }
    if (url.endsWith('/admin/data-retention/exports')) return jsonResponse(200, [RECEIPT]);
    if (url.endsWith('/admin/data-retention/purges') && method === 'POST')
      return jsonResponse(202, { id: 31, table: 'analytics_event', from: '1970-01-01', to: '2026-10-22', receiptId: 7, forced: false, status: 'RUNNING', estRows: 8000000, deletedRows: 0, oldestAt: null, newestAt: null, reason: 'x', adminId: 1, adminEmail: 'a@b', error: null, startedAt: '2026-10-29T10:00:00Z', updatedAt: '2026-10-29T10:00:00Z', finishedAt: null, vacuumRecommended: false });
    if (url.endsWith('/admin/data-retention/purges/31')) {
      const st = statuses.length > 1 ? statuses.shift()! : statuses[0];
      return jsonResponse(200, { id: 31, table: 'analytics_event', from: '1970-01-01', to: '2026-10-22', receiptId: 7, forced: false, status: st, estRows: 8000000, deletedRows: st === 'COMPLETED' ? 8000000 : 1000, oldestAt: null, newestAt: null, reason: 'x', adminId: 1, adminEmail: 'a@b', error: null, startedAt: '2026-10-29T10:00:00Z', updatedAt: '2026-10-29T10:00:00Z', finishedAt: null, vacuumRecommended: st === 'COMPLETED' });
    }
    if (url.endsWith('/admin/data-retention/purges')) return jsonResponse(200, []);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

beforeEach(() => {
  URL.createObjectURL = vi.fn(() => 'blob:x');
  URL.revokeObjectURL = vi.fn();
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {}); // jsdom indirme gezinmesi yok
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('format yardımcıları', () => {
  it('bayt ve aralık doğrulaması', () => {
    expect(formatBytes(1024 ** 3 * 5)).toBe('5 GB');
    expect(formatBytes(null)).toBe('—');
    expect(rangeValid('', '2026-10-22', '2026-10-22')).toBe(true);
    expect(rangeValid('', '2026-10-23', '2026-10-22')).toBe(false);
    expect(rangeValid('2026-10-22', '2026-10-22', '2026-10-22')).toBe(false);
    expect(rangeValid('', '', '2026-10-22')).toBe(false);
  });
});

describe('Veri saklama sayfası', () => {
  it('doluluğu kaynak etiketiyle ve %80+ uyarısıyla gösterir', async () => {
    setup();
    renderWithProviders(<DataRetentionPage />);
    const dbDisk = await screen.findByTestId('card-db-disk');
    expect(within(dbDisk).getByText('%83,4')).toBeInTheDocument();
    expect(within(dbDisk).getByTestId('source-COMPUTED')).toHaveTextContent('Kapasite ayarından hesaplanan');
    expect(within(dbDisk).getByText('Uyarı')).toBeInTheDocument();
    const app = screen.getByTestId('card-app:uploads+backups');
    expect(within(app).getByTestId('source-MEASURED')).toHaveTextContent('Ölçülen');
    expect(within(app).getByText('Normal')).toBeInTheDocument();
    expect(screen.getByTestId('page-alert')).toHaveTextContent('%83,4');
    expect(within(dbDisk).getByRole('progressbar')).toHaveAttribute('aria-valuenow', '83');
    expect(screen.getByTestId('card-db-size')).toHaveTextContent('5 GB');
  });

  it('veritabanı diski bilinmiyorsa bunu açıkça söyler', async () => {
    setup({ storage: { ...STORAGE, status: 'OK', worstPercent: 20, dbServerDisk: { ...STORAGE.dbServerDisk, source: 'UNKNOWN', percent: null, totalBytes: null, usedBytes: null, freeBytes: null, status: 'UNKNOWN' } } });
    renderWithProviders(<DataRetentionPage />);
    const dbDisk = await screen.findByTestId('card-db-disk');
    expect(within(dbDisk).getByTestId('source-UNKNOWN')).toHaveTextContent('Bilinmiyor');
    expect(within(dbDisk).getByText(/STORAGE_DB_DISK_CAPACITY_BYTES/)).toBeInTheDocument();
    expect(screen.queryByTestId('page-alert')).not.toBeInTheDocument();
  });

  it('yetkisiz profilde (VIEWER) işlem düğmeleri yok', async () => {
    setup({ perms: VIEWER_PERMS });
    renderWithProviders(<DataRetentionPage />);
    expect(await screen.findByText('Analitik ham olaylar')).toBeInTheDocument();
    await waitFor(() => expect(screen.getByTestId('readonly-note')).toBeInTheDocument());
    expect(screen.queryByRole('button', { name: /Dışa aktar: / })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Temizle: / })).not.toBeInTheDocument();
  });

  it('silinemeyen tabloda yalnız dışa aktarma düğmesi vardır', async () => {
    setup();
    renderWithProviders(<DataRetentionPage />);
    await screen.findByText('Sohbet içeriği erişim kaydı');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Dışa aktar: message_access_audit' })).toBeInTheDocument());
    expect(screen.queryByRole('button', { name: 'Temizle: message_access_audit' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Temizle: analytics_event' })).toBeInTheDocument();
  });

  it('dışa aktarır, dosyayı indirtir ve makbuzu gösterir', async () => {
    const calls = setup();
    renderWithProviders(<DataRetentionPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Dışa aktar: analytics_event' }));
    const dlg = await screen.findByRole('dialog');
    const start = within(dlg).getByRole('button', { name: 'Dışa aktar ve indir' });
    expect(start).toBeDisabled(); // gerekçe yok
    await userEvent.type(within(dlg).getByRole('textbox'), 'aylık yedekleme için dışa aktarma');
    await waitFor(() => expect(start).toBeEnabled());
    await userEvent.click(start);
    expect(await within(dlg).findByTestId('receipt')).toHaveTextContent('8.000.000');
    expect(within(dlg).getByTestId('receipt-sha')).toHaveTextContent('a'.repeat(64));
    expect(URL.createObjectURL).toHaveBeenCalled();
    const post = calls.find((c) => c.init.method === 'POST' && c.url.endsWith('/exports'))!;
    expect(JSON.parse(String(post.init.body))).toMatchObject({ table: 'analytics_event', to: '2026-10-22' });
    expect((post.init.headers as Record<string, string>)['X-Admin-Reason']).toBeTruthy();
    expect(within(dlg).getByRole('button', { name: 'Bu aralığı temizlemeye geç' })).toBeInTheDocument();
  });

  it('makbuz yoksa silme KAPALIDIR; tablo adı yazılmadan ve gerekçesiz açılmaz', async () => {
    setup({
      preview: {
        table: 'analytics_event', from: '1970-01-01', to: '2026-10-22', rowsInRange: 500, capped: false, estimatedBytes: 1000, deletable: true,
        notDeletableReason: null, maxTo: '2026-10-22', minRetentionDays: 7, receipt: null, receiptStale: false, canPurge: false, blockers: ['NO_RECEIPT'],
      },
    });
    renderWithProviders(<DataRetentionPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Temizle: analytics_event' }));
    const dlg = await screen.findByRole('alertdialog');
    expect(await within(dlg).findByText(/dışa aktarma makbuzu yok — silme kapalı/)).toBeInTheDocument();
    expect(within(dlg).getByRole('button', { name: 'Kalıcı olarak sil' })).toBeDisabled();
    // tablo adı / gerekçe alanları makbuz yokken hiç görünmez
    expect(within(dlg).queryByLabelText('Onay için tablo adını yazın')).not.toBeInTheDocument();
    // FULL yöneticiye "makbuzsuz sil" seçeneği ayrıca sunulur
    expect(within(dlg).getByLabelText('Makbuzsuz sil (tehlikeli)')).toBeInTheDocument();
    expect(within(dlg).getByRole('button', { name: 'Önce dışa aktar' })).toBeInTheDocument();
  });

  it('makbuzlu silme: gerekçe + tablo adı + Idempotency-Key, sonra ilerleme ve tamamlanma', async () => {
    const calls = setup();
    renderWithProviders(<DataRetentionPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Temizle: analytics_event' }));
    const dlg = await screen.findByRole('alertdialog');
    expect(await within(dlg).findByTestId('receipt-ok')).toHaveTextContent('makbuz #7');
    expect(within(dlg).getByTestId('preview-rows')).toHaveTextContent('8.000.000');
    const confirm = within(dlg).getByRole('button', { name: 'Kalıcı olarak sil' });
    expect(confirm).toBeDisabled();
    const boxes = within(dlg).getAllByRole('textbox');
    // sırasıyla: gerekçe (textarea), tablo adı
    await userEvent.type(boxes[boxes.length - 2], 'aylık temizlik, yedek alındı');
    expect(confirm).toBeDisabled();
    await userEvent.type(boxes[boxes.length - 1], 'analytics_event');
    await waitFor(() => expect(confirm).toBeEnabled());
    await userEvent.click(confirm);
    expect(await within(dlg).findByTestId('purge-progress')).toBeInTheDocument();
    const post = calls.find((c) => c.init.method === 'POST' && c.url.endsWith('/purges'))!;
    const h = post.init.headers as Record<string, string>;
    expect(h['Idempotency-Key']).toMatch(/[A-Za-z0-9-]{8,}/);
    expect(JSON.parse(String(post.init.body))).toMatchObject({
      table: 'analytics_event', confirmTable: 'analytics_event', receiptId: 7, to: '2026-10-22',
    });
    await waitFor(() => expect(within(dlg).getByText(/Temizlik tamamlandı/)).toBeInTheDocument(), { timeout: 6000 });
    expect(within(dlg).getByText(/VACUUM FULL/)).toBeInTheDocument();
  }, 15000);
});

describe('StorageBanner', () => {
  it('WARN iken kalıcı bandı gösterir ve sayfaya bağlar', async () => {
    setup();
    renderWithProviders(<StorageBanner />);
    const b = await screen.findByTestId('storage-banner');
    expect(b).toHaveTextContent('%83,4');
    expect(within(b).getByRole('link')).toHaveAttribute('href', '/admin/data-retention');
    expect(b).toHaveAttribute('role', 'status');
  });

  it('CRIT iken alert rolündedir', async () => {
    setup({ storage: { ...STORAGE, status: 'CRIT', worstPercent: 93 } });
    renderWithProviders(<StorageBanner />);
    expect(await screen.findByRole('alert')).toHaveTextContent('kritik');
  });

  it('OK iken ya da izin yokken görünmez', async () => {
    setup({ storage: { ...STORAGE, status: 'OK', worstPercent: 30 } });
    const { unmount } = renderWithProviders(<StorageBanner />);
    await new Promise((r) => setTimeout(r, 150));
    expect(screen.queryByTestId('storage-banner')).not.toBeInTheDocument();
    unmount();
    const calls = setup({ perms: ['dashboard.read'] });
    renderWithProviders(<StorageBanner />);
    await new Promise((r) => setTimeout(r, 150));
    expect(screen.queryByTestId('storage-banner')).not.toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('/system/storage'))).toBe(false);
  });
});
