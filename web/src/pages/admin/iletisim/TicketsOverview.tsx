// Destek talepleri özeti: tüm taleplerin durum dağılımı, ilk yanıt süresi ve bekleyenlerin yaşı (grafikli).
// API: GET /api/admin/analytics/support (toplu sayılar + ilk yanıt ortalaması),
//      GET /api/admin/support/tickets?status=OPEN&size=50 (bekleyenlerin yaşı; en çok 50 kayıt).
import { useQuery } from '@tanstack/react-query';
import { analyticsApi, qk, supportApi } from '../../../api';
import type { TicketStatus } from '../../../api/types';
import { BarChart } from '../../../components/charts/BarChart';
import { ChartPanel } from '../../../components/charts/ChartPanel';
import { StackedShare, type ShareSegment } from '../../../components/kit/StackedShareIletisim';
import { Card, Insight, ProgressRing, StatTile, useKitFormat } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import {
  AGE_KEYS,
  ageBuckets,
  answeredShare,
  firstReplyVerdict,
  humanizeDuration,
  staleCount,
  ticketTotal,
  type AgeKey,
} from './logic';
import styles from './iletisim.module.css';

const SEARCH_LIMIT = 50;

export interface TicketsOverviewProps {
  status: TicketStatus | '';
  onStatus: (s: TicketStatus | '') => void;
}

export function TicketsOverview({ status, onStatus }: TicketsOverviewProps) {
  const { formatNumber } = useI18n();
  const il = useIl();
  const kit = useKitFormat();

  const stats = useQuery({
    queryKey: qk.analytics.support(),
    queryFn: analyticsApi.getSupportAnalytics,
    staleTime: 60_000,
  });
  const waiting = useQuery({
    queryKey: [...qk.tickets.all, 'waiting-age'],
    queryFn: () => supportApi.listTickets({ status: 'OPEN', size: SEARCH_LIMIT }),
    staleTime: 30_000,
  });

  const counts = stats.data?.tickets;
  const avg = stats.data?.avgFirstResponseMinutes ?? null;
  const verdict = firstReplyVerdict(avg);
  const human = avg !== null && avg > 0 ? humanizeDuration(avg) : null;
  const share = counts ? answeredShare(counts) : null;

  const items = waiting.data?.items ?? [];
  const buckets = ageBuckets(items);
  const stale = staleCount(buckets);
  const oldest = items.reduce<string | null>((o, r) => (!o || r.updatedAt < o ? r.updatedAt : o), null);
  const moreThanShown = !!waiting.data?.nextCursor;

  const segments: ShareSegment[] = [
    {
      key: 'OPEN',
      label: il('admin.il.tk.seg.OPEN'),
      value: counts?.open ?? 0,
      tone: 'warning',
      hint: il('admin.il.tk.seg.OPENHint'),
    },
    {
      key: 'ANSWERED',
      label: il('admin.il.tk.seg.ANSWERED'),
      value: counts?.answered ?? 0,
      tone: 'info',
      hint: il('admin.il.tk.seg.ANSWEREDHint'),
    },
    {
      key: 'CLOSED',
      label: il('admin.il.tk.seg.CLOSED'),
      value: counts?.closed ?? 0,
      tone: 'success',
      hint: il('admin.il.tk.seg.CLOSEDHint'),
    },
  ];

  // Bekleme cümlesi: acil -> dikkat -> bilgi
  const openCount = counts?.open ?? items.length;
  const sentence = (() => {
    if (!counts && !waiting.data) return null;
    if (openCount === 0)
      return {
        tone: 'good' as const,
        parts: [{ text: il('admin.il.tk.sentence.none'), tone: 'good' as const }],
      };
    const parts: (string | { text: string; tone?: 'warn' | 'bad' | 'good' })[] = [
      { text: il('admin.il.tk.sentence.waiting', { n: formatNumber(openCount) }), tone: 'warn' },
    ];
    if (oldest) parts.push(' ', il('admin.il.tk.sentence.oldest', { when: kit.relative(oldest) }));
    if (stale > 0)
      parts.push(' ', { text: il('admin.il.tk.sentence.stale', { n: formatNumber(stale) }), tone: 'bad' });
    return { tone: stale > 0 ? ('bad' as const) : ('warn' as const), parts };
  })();

  const ageData = AGE_KEYS.map((key: AgeKey) => ({
    label: il(`admin.il.tk.age.${key}`),
    count: buckets.find((b) => b.key === key)?.count ?? 0,
  }));
  const ageInsight =
    items.length === 0
      ? il('admin.il.tk.ageInsight.none')
      : stale > 0
        ? il('admin.il.tk.ageInsight.stale', { n: formatNumber(stale), total: formatNumber(items.length) })
        : il('admin.il.tk.ageInsight.fresh', { total: formatNumber(items.length) });

  return (
    <section data-search-anchor="tickets-summary" aria-label={il('admin.il.tk.summary')}>
      <div className={styles.tiles}>
        <StatTile
          className={styles.tileBox}
          label={il('admin.il.tk.tile.waiting')}
          value={counts?.open}
          unit={il('admin.il.tk.tile.waitingUnit')}
          icon="lifebuoy"
          caption={il('admin.il.tk.tile.waitingHint')}
          loading={stats.isLoading}
          error={stats.isError}
          onRetry={() => void stats.refetch()}
        />
        <span data-search-anchor="tickets-first-response" style={{ display: 'contents' }}>
          <StatTile
            className={styles.tileBox}
            label={il('admin.il.tk.tile.first')}
            value={human ? formatNumber(human.value) : null}
            unit={human ? il(`admin.il.unit.${human.unit}`) : undefined}
            icon="clock"
            caption={il(`admin.il.tk.first.${verdict}`)}
            loading={stats.isLoading}
            error={stats.isError}
            onRetry={() => void stats.refetch()}
          />
        </span>
        <div className={styles.ringBox}>
          <ProgressRing
            value={share}
            label={il('admin.il.tk.ring')}
            tone={share === null ? 'neutral' : share >= 80 ? 'success' : share >= 50 ? 'warning' : 'danger'}
            size={104}
            loading={stats.isLoading}
          />
        </div>
      </div>
      {sentence && <Insight className={styles.sentence} tone={sentence.tone} parts={sentence.parts} />}

      <div className={styles.grid2}>
        <Card title={il('admin.il.tk.dist.title')} data-search-anchor="tickets-status-dist">
          {stats.isError ? (
            <p role="alert">{il('admin.il.err.load')}</p>
          ) : (
            <>
              <StackedShare
                segments={segments}
                ariaLabel={il('admin.il.tk.dist.aria', { n: formatNumber(counts ? ticketTotal(counts) : 0) })}
                selectedKey={status || null}
                onSelect={(k) => onStatus(k === status ? '' : (k as TicketStatus))}
              />
              <p className={styles.panelNote}>{il('admin.il.tk.dist.note')}</p>
            </>
          )}
        </Card>
        <div data-search-anchor="tickets-age">
          <ChartPanel
            title={il('admin.il.tk.age.title')}
            insight={ageInsight}
            insightTone={stale > 0 ? 'bad' : items.length === 0 ? 'good' : 'info'}
            loading={waiting.isLoading}
            error={waiting.isError}
            onRetry={() => void waiting.refetch()}
            empty={!waiting.isLoading && !waiting.isError && items.length === 0}
            emptyLabel={il('admin.il.tk.age.empty')}
            height={220}
            footnote={
              moreThanShown ? il('admin.il.tk.age.more', { n: formatNumber(SEARCH_LIMIT) }) : undefined
            }
            table={{
              columns: [
                { key: 'range', header: il('admin.il.tk.age.col.range') },
                { key: 'count', header: il('admin.il.tk.age.col.count'), align: 'end' },
              ],
              rows: ageData.map((d) => ({ range: d.label, count: formatNumber(d.count) })),
            }}
          >
            <BarChart
              data={ageData}
              xKey="label"
              series={[{ key: 'count', label: il('admin.il.tk.age.series') }]}
              ariaLabel={il('admin.il.tk.age.title')}
              height={220}
            />
          </ChartPanel>
        </div>
      </div>
    </section>
  );
}
