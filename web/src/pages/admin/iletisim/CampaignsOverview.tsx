// Bildirim kampanyaları özeti: son kampanyaların durum dağılımı, hedef kitleye ulaşma oranı ve kitle büyüklüğü grafiği.
// API: GET /api/admin/push/campaigns?size=50 (liste süzgecinden bağımsız; gönderim sürerken 5 sn'de bir yenilenir).
import { useQuery } from '@tanstack/react-query';
import { listCampaigns } from '../../../api/campaigns';
import { qk } from '../../../api/queryKeys';
import type { CampaignStatus } from '../../../api/types';
import { BarChart } from '../../../components/charts/BarChart';
import { ChartPanel } from '../../../components/charts/ChartPanel';
import { StackedShare, type ShareSegment } from '../../../components/kit/StackedShareIletisim';
import { Card, Insight, ProgressRing, StatTile } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { CAMPAIGN_STATUSES, isLive } from '../campaigns/lib';
import { useIl } from './il';
import { campaignTone, reachRate, statusCounts } from './logic';
import styles from './iletisim.module.css';

const OVERVIEW_SIZE = 50;
const CHART_ROWS = 6;

export interface CampaignsOverviewProps {
  status: CampaignStatus | undefined;
  onStatus: (s: CampaignStatus | undefined) => void;
}

const short = (s: string, n = 22) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

export function CampaignsOverview({ status, onStatus }: CampaignsOverviewProps) {
  const { td, formatNumber } = useI18n();
  const il = useIl();
  const q = useQuery({
    queryKey: [...qk.campaigns.list(), 'overview'],
    queryFn: () => listCampaigns({ size: OVERVIEW_SIZE }),
    staleTime: 30_000,
    refetchInterval: (query) => (query.state.data?.items.some((c) => isLive(c.status)) ? 5000 : false),
  });
  const items = q.data?.items ?? [];
  const counts = statusCounts(items, CAMPAIGN_STATUSES);
  const reach = reachRate(items);
  const queued = counts
    .filter((c) => c.key === 'SCHEDULED' || c.key === 'SENDING')
    .reduce((s, c) => s + c.count, 0);
  const sent = items.filter((c) => c.status === 'SENT');
  const reachedTotal = sent.reduce((s, c) => s + (c.recipientCount ?? 0), 0);
  const failed = counts.find((c) => c.key === 'FAILED')?.count ?? 0;

  const segments: ShareSegment[] = counts.map((c) => ({
    key: c.key,
    label: td(`admin.campaigns.status.${c.key}`, c.key),
    value: c.count,
    tone: campaignTone(c.key),
  }));

  // Hedef kitle büyüklüğü ve gerçekten ulaşılan kişi: kitle bilinen son gönderimler (yeniden eskiye)
  const chartRows = sent
    .filter((c) => !!c.audienceSize)
    .slice(0, CHART_ROWS)
    .reverse()
    .map((c) => ({
      name: short(c.tr.title),
      audience: c.audienceSize ?? 0,
      reached: Math.min(c.recipientCount ?? 0, c.audienceSize ?? 0),
    }));

  const sentence = (() => {
    if (!q.data || items.length === 0) return null;
    if (failed > 0)
      return {
        tone: 'warn' as const,
        parts: [
          { text: il('admin.il.cp.sentence.failed', { n: formatNumber(failed) }), tone: 'warn' as const },
        ],
      };
    if (queued > 0)
      return {
        tone: 'info' as const,
        parts: [il('admin.il.cp.sentence.queued', { n: formatNumber(queued) })],
      };
    return {
      tone: 'good' as const,
      parts: [il('admin.il.cp.sentence.calm', { n: formatNumber(sent.length) })],
    };
  })();

  return (
    <section data-search-anchor="campaigns-summary" aria-label={il('admin.il.cp.summary')}>
      <div className={styles.tiles}>
        <StatTile
          className={styles.tileBox}
          label={il('admin.il.cp.tile.reached')}
          value={q.data ? reachedTotal : undefined}
          unit={il('admin.il.cp.tile.reachedUnit')}
          icon="megaphone"
          compact
          caption={il('admin.il.cp.tile.reachedHint', { n: formatNumber(sent.length) })}
          loading={q.isLoading}
          error={q.isError}
          onRetry={() => void q.refetch()}
        />
        <StatTile
          className={styles.tileBox}
          label={il('admin.il.cp.tile.queued')}
          value={q.data ? queued : undefined}
          unit={il('admin.il.cp.tile.queuedUnit')}
          icon="clock"
          caption={il('admin.il.cp.tile.queuedHint')}
          loading={q.isLoading}
          error={q.isError}
          onRetry={() => void q.refetch()}
        />
        <div className={styles.ringBox}>
          <ProgressRing
            value={reach ? reach.percent : null}
            label={il('admin.il.cp.ring')}
            tone={
              !reach
                ? 'neutral'
                : reach.percent >= 80
                  ? 'success'
                  : reach.percent >= 50
                    ? 'warning'
                    : 'danger'
            }
            size={104}
            loading={q.isLoading}
          />
        </div>
      </div>
      {sentence && <Insight className={styles.sentence} tone={sentence.tone} parts={sentence.parts} />}

      <div className={styles.grid2}>
        <Card title={il('admin.il.cp.dist.title')} data-search-anchor="campaigns-status-dist">
          {q.isError ? (
            <p role="alert">{il('admin.il.err.load')}</p>
          ) : (
            <>
              <StackedShare
                segments={segments}
                ariaLabel={il('admin.il.cp.dist.aria', { n: formatNumber(items.length) })}
                selectedKey={status ?? null}
                onSelect={(k) => onStatus(k === status ? undefined : (k as CampaignStatus))}
              />
              <p className={styles.panelNote}>
                {il('admin.il.cp.dist.note', { n: formatNumber(OVERVIEW_SIZE) })}
              </p>
            </>
          )}
        </Card>
        <div data-search-anchor="campaigns-audience-chart">
          <ChartPanel
            title={il('admin.il.cp.chart.title')}
            insight={
              reach
                ? il('admin.il.cp.chart.insight', {
                    reached: formatNumber(reach.reached),
                    audience: formatNumber(reach.audience),
                    pct: formatNumber(reach.percent),
                  })
                : undefined
            }
            loading={q.isLoading}
            error={q.isError}
            onRetry={() => void q.refetch()}
            empty={!q.isLoading && !q.isError && chartRows.length === 0}
            emptyLabel={il('admin.il.cp.chart.empty')}
            height={240}
            footnote={il('admin.il.cp.chart.note')}
            table={{
              columns: [
                { key: 'name', header: il('admin.il.cp.chart.col.name') },
                { key: 'audience', header: il('admin.il.cp.chart.audience'), align: 'end' },
                { key: 'reached', header: il('admin.il.cp.chart.reached'), align: 'end' },
              ],
              rows: chartRows.map((r) => ({
                name: r.name,
                audience: formatNumber(r.audience),
                reached: formatNumber(r.reached),
              })),
            }}
          >
            <BarChart
              data={chartRows}
              xKey="name"
              layout="horizontal"
              height={Math.max(180, chartRows.length * 56)}
              series={[
                { key: 'audience', label: il('admin.il.cp.chart.audience') },
                { key: 'reached', label: il('admin.il.cp.chart.reached') },
              ]}
              ariaLabel={il('admin.il.cp.chart.title')}
            />
          </ChartPanel>
        </div>
      </div>
    </section>
  );
}
