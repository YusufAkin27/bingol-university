// Sistem sağlığı görselleri: trafik ışığı, ana göstergeler, çizelge, görev şeridi, yedek tazeliği, çökme dağılımı,
// büyüme tahmini ve arama dizini (yazım hatalı sorgular dahil).
import { screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { BackupStatus } from '../../../api/backup';
import type { CrashGroup } from '../../../api/crashes';
import { translate } from '../../../i18n';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { buildSearchEntries } from '../../../search/build';
import { createSearcher } from '../../../search/engine';
import { useI18n } from '../../../i18n/I18nProvider';
import SystemStatusPage from '../SystemStatusPage';
import { BackupHealth } from './BackupHealth';
import { CrashOverview } from './CrashOverview';
import { OpsSummary } from './OpsSummary';
import { summarizeOps } from './logic';
import { GrowthPanel } from './StorageInsights';
import { TrafficLight } from './Visuals';

afterEach(() => {
  vi.unstubAllGlobals();
  try {
    window.sessionStorage.clear();
  } catch {
    /* yok say */
  }
});

function Harness({ render }: { render: (i18n: ReturnType<typeof useI18n>) => React.ReactNode }) {
  return <>{render(useI18n())}</>;
}

describe('trafik ışığı', () => {
  it('yanan lambayı kelimeyle söyler (renk tek başına değil)', async () => {
    renderWithProviders(<Harness render={(i18n) => <TrafficLight i18n={i18n} level="CRIT" />} />);
    const light = await screen.findByTestId('traffic-light');
    expect(light).toHaveAttribute('data-active', 'urgent');
    expect(light).toHaveAttribute('aria-label', 'Genel durum: Acil');
    expect(light).toHaveTextContent('İyi');
    expect(light).toHaveTextContent('Dikkat');
    expect(light).toHaveTextContent('Acil');
  });
});

describe('Sistem durumu: ana göstergeler, çizelge, görev şeridi', () => {
  function setup() {
    mockFetch((url) => {
      if (url.includes('/admin/system/overview'))
        return jsonResponse(200, {
          generatedAt: '2026-11-01T10:00:00Z',
          overall: 'WARN',
          indicators: {
            'mail.dead': { status: 'WARN', value: 3, threshold: { warn: 1, crit: 20 }, message: null },
            'push.dead': { status: 'OK', value: 0, threshold: { warn: 1, crit: 20 }, message: null },
            'disk.storage': { status: 'OK', value: 41.5, threshold: { warn: 80, crit: 90 }, message: null },
            'backup.age': { status: 'OK', value: 5, threshold: { warn: 25, crit: 49 }, message: null },
            'jobs.mail-queue': { status: 'OK', value: 120, threshold: { warn: 3600, crit: 7200 }, message: null },
            'jobs.news-sync': { status: 'CRIT', value: 20000, threshold: { warn: 3600, crit: 7200 }, message: null },
          },
        });
      return jsonResponse(200, []);
    });
  }

  it('trafik ışığı, dört ana gösterge ve görev şeridi görünür; teknik ayrıntı katlanır bölümdedir', async () => {
    setup();
    renderWithProviders(<SystemStatusPage />);
    const gauges = await screen.findByTestId('key-gauges');
    expect(within(gauges).getByText('Depolama')).toBeInTheDocument();
    expect(within(gauges).getByText('Yedek tazeliği')).toBeInTheDocument();
    expect(within(gauges).getByText('Gönderim sıraları')).toBeInTheDocument();
    expect(within(gauges).getByText('Otomatik görevler')).toBeInTheDocument();
    expect(within(gauges).getByText('2 görevin 1 tanesi geç kaldı ya da hiç çalışmadı.', { exact: false })).toBeInTheDocument();
    expect(screen.getByTestId('sys-hero').querySelector('[data-testid="traffic-light"]')).toHaveAttribute('data-active', 'attention');
    const lanes = screen.getByTestId('job-lanes');
    const items = within(lanes).getAllByRole('listitem');
    // sorunlu görev (kritik) listenin başında
    expect(items[0]).toHaveTextContent('Haber güncellemesi');
    expect(items[0]).toHaveAttribute('data-status', 'CRIT');
    const tech = document.querySelector('[data-search-anchor="technical-details"]') as HTMLDetailsElement;
    expect(tech.tagName).toBe('DETAILS');
    expect(tech).toHaveTextContent('Teknik ayrıntılar (6 gösterge)');
    expect(tech.open).toBe(true); // sorun var: açık gelir
  });

  it('ilk ölçümde çizelge "tek kontrol" der ve oturum belleğine yazar', async () => {
    setup();
    renderWithProviders(<SystemStatusPage />);
    const timeline = await screen.findByTestId('health-timeline');
    expect(within(timeline).getAllByRole('listitem')).toHaveLength(1);
    expect(screen.getByText(/Şimdilik tek kontrol var/)).toBeInTheDocument();
    // Yazım render sonrası bir efektte yapılır: yük altında gecikebilir, bu yüzden beklenir.
    await waitFor(() => expect(window.sessionStorage.getItem('bu-admin-sys-health-history')).toContain('WARN'));
  });
});

describe('OpsSummary', () => {
  it('sorunları tek cümlede sayar ve ışığı Dikkat yapar', async () => {
    const summary = summarizeOps({ healthStatus: 'UP', mailDead: 2, pushDead: 1, backup: null, now: Date.now() });
    renderWithProviders(<Harness render={(i18n) => <OpsSummary i18n={i18n} summary={summary} />} />);
    const el = await screen.findByTestId('ops-summary');
    expect(within(el).getByTestId('traffic-light')).toHaveAttribute('data-active', 'attention');
    expect(el).toHaveTextContent('3 e-posta/bildirim gönderilemedi');
  });
  it('veri yoksa iyi demez', async () => {
    const summary = summarizeOps({ now: Date.now() });
    renderWithProviders(<Harness render={(i18n) => <OpsSummary i18n={i18n} summary={summary} />} />);
    const el = await screen.findByTestId('ops-summary');
    expect(within(el).getByTestId('traffic-light')).toHaveAttribute('data-active', 'unknown');
    expect(el).not.toHaveTextContent('Her şey yolunda');
  });
});

describe('BackupHealth', () => {
  const now = Date.parse('2026-11-01T12:00:00Z');
  const status = (hoursAgo: number, over: Partial<BackupStatus> = {}): BackupStatus => ({
    local: { count: 10, bytes: 100, oldestAt: null },
    remote: { configured: true, kind: 'drive', name: 'bu', lastSuccessAt: null, lastVerifiedAt: new Date(now).toISOString(), lastError: null, bytes: 1, count: 4 },
    lastSuccessAt: new Date(now - hoursAgo * 3_600_000).toISOString(),
    lastStatus: 'ok',
    schedule: null,
    retention: null,
    ...over,
  });
  it('taze yedek: İyi ışığı, ölçek ve sunucu/Drive sayıları', async () => {
    renderWithProviders(<Harness render={(i18n) => <BackupHealth i18n={i18n} status={status(1)} now={now} />} />);
    const el = await screen.findByTestId('backup-health');
    expect(within(el).getByTestId('traffic-light')).toHaveAttribute('data-active', 'good');
    expect(el).toHaveTextContent('yedekler güncel');
    expect(within(el).getByRole('img', { name: /Yeşil bölge güncel/ })).toBeInTheDocument();
    expect(el).toHaveTextContent('Sunucuda');
    expect(el).toHaveTextContent('Google Drive’da');
  });
  it('çok eski yedek: Acil', async () => {
    renderWithProviders(<Harness render={(i18n) => <BackupHealth i18n={i18n} status={status(30)} now={now} />} />);
    const el = await screen.findByTestId('backup-health');
    expect(within(el).getByTestId('traffic-light')).toHaveAttribute('data-active', 'urgent');
    expect(el).toHaveTextContent('çok eski');
  });
  it('durum yoksa hiçbir şey çizmez', async () => {
    const { container } = renderWithProviders(<Harness render={(i18n) => <BackupHealth i18n={i18n} status={null} now={now} />} />);
    expect(container.querySelector('[data-testid="backup-health"]')).toBeNull();
  });
});

describe('CrashOverview', () => {
  const g = (versions: CrashGroup['versions']): CrashGroup => ({ versions }) as CrashGroup;
  it('durum çubuğu ve sürüm dağılımı: en çok çöken sürümü cümleyle söyler', async () => {
    renderWithProviders(
      <CrashOverview
        summary={{ newGroups: 3, ackGroups: 2, resolvedGroups: 5, events24h: 41, reopened: 1 }}
        groups={[g([{ version: '2.0.5', platform: 'ANDROID', count: 11 }, { version: '2.0.4', platform: 'IOS', count: 3 }])]}
        groupsLoading={false}
      />,
    );
    const el = await screen.findByTestId('crash-overview');
    expect(el).toHaveTextContent('Yeni: 3');
    expect(el).toHaveTextContent('İncelemede: 2');
    expect(el).toHaveTextContent('Çözüldü: 5');
    expect(el).toHaveTextContent('En çok çöken: Android 2.0.5 sürümü (11 kez).');
  });
  it('sürüm verisi yoksa uydurmaz', async () => {
    renderWithProviders(<CrashOverview summary={undefined} groups={[]} groupsLoading={false} />);
    expect(await screen.findByText('Sürüm dağılımı için yeterli çökme raporu yok.')).toBeInTheDocument();
  });
});

describe('GrowthPanel', () => {
  it('tablo büyüme tahminini ve "kaç gün yeter" cümlesini gösterir', async () => {
    const old = new Date(Date.now() - 10 * 86_400_000).toISOString();
    mockFetch((url) => {
      if (url.includes('/admin/data-retention/tables'))
        return jsonResponse(200, [
          { name: 'audit_log', label: 'Denetim kaydı', description: '', estimatedRows: 10, sizeBytes: 10 * 1024 * 1024, oldestAt: old, minRetentionDays: 30, maxTo: '2026-10-01', deletable: true, notDeletableReason: null, personalData: false },
          { name: 'tiny', label: 'Küçük', description: '', estimatedRows: 1, sizeBytes: null, oldestAt: null, minRetentionDays: 30, maxTo: '2026-10-01', deletable: true, notDeletableReason: null, personalData: false },
        ]);
      if (url.includes('/admin/system/storage'))
        return jsonResponse(200, {
          generatedAt: '2026-11-01T10:00:00Z',
          status: 'OK',
          worstPercent: 40,
          worstKey: 'db',
          database: { sizeBytes: 1, topTables: [] },
          dbServerDisk: { key: 'db', roles: [], source: 'MEASURED', path: null, totalBytes: 1, usedBytes: 1, freeBytes: 10 * 1024 * 1024 * 1024, percent: 40, status: 'OK' },
          appDisks: [],
          warnPercent: 80,
          critPercent: 90,
        });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<GrowthPanel />);
    expect(await screen.findByText(/En hızlı büyüyen: Denetim kaydı, günde ortalama 1 MB/)).toBeInTheDocument();
    expect(await screen.findByText(/yaklaşık 10240 gün yeter|yaklaşık 10\.240 gün yeter/)).toBeInTheDocument();
    expect(screen.getByText(/Bu bir tahmindir/)).toBeInTheDocument();
  });
  it('tahmin için veri yoksa nedenini söyler', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<GrowthPanel />);
    expect(await screen.findByText(/Tahmin için yeterli veri yok/)).toBeInTheDocument();
  });
});

describe('arama dizini: sistem sağlığı', () => {
  const t = (k: Parameters<typeof translate>[1]) => translate('tr', k);
  const searcher = createSearcher(buildSearchEntries(t));
  const ids = (q: string) => searcher.search(q).map((h) => h.item.id);

  it('"trafik ışığı" ve "iyi dikkat acil" sistem özetlerini getirir', () => {
    expect(ids('trafik ışığı')).toEqual(expect.arrayContaining(['ops.summary']));
    expect(ids('iyi dikkat acil').some((id) => id === 'system.health-timeline' || id === 'ops.summary')).toBe(true);
  });
  it('"yedek taze mi" yedek tazeliğini getirir; yazım hatalı "yedk taze" de', () => {
    expect(ids('yedek taze mi').slice(0, 6)).toEqual(expect.arrayContaining(['backup.freshness']));
    expect(ids('yedk taze').slice(0, 8)).toEqual(expect.arrayContaining(['backup.freshness']));
  });
  it('"kuyruk" ve yazım hatalı "kuyurk" kuyruk kartlarını getirir', () => {
    expect(ids('mail kuyruğu')).toEqual(expect.arrayContaining(['ops.mail-queue']));
    expect(ids('kuyurk')).toEqual(expect.arrayContaining(['ops.mail-queue']));
  });
  it('"hangi sürüm çöküyor" ve "büyüme tahmini" ilgili bölümü getirir', () => {
    expect(ids('hangi sürüm çöküyor')).toEqual(expect.arrayContaining(['crashes.versions']));
    expect(ids('büyüme tahmini')).toEqual(expect.arrayContaining(['dataRetention.growth']));
    expect(ids('buyume tahmni')).toEqual(expect.arrayContaining(['dataRetention.growth']));
  });
  it('girdilerin yolu ilgili sayfaya, anchor ile gider', () => {
    const e = buildSearchEntries(t).find((x) => x.id === 'system.gauge-backup')!;
    expect(e.to).toMatch(/\/system#gauge-backup$/);
  });
});
