import { useQuery } from '@tanstack/react-query';
import { getBehaviorOverview, type BehaviorOverview } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import { BarChart, LineAreaChart } from '../../../../components/charts';
import { Card, EmptyState, StatTile, type Column } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import { BarList, ChartCard } from '../parts';
import styles from './behavior.module.css';
import { formatDec, formatDuration, formatInt, formatPct, type Range } from './format';
import { Boundary } from './shared';

type DayRow = BehaviorOverview['byDay'][number];

/** Grafik/tablo için günlük satırlar (ms -> sn, oran -> yüzde). */
export function dayRows(byDay: DayRow[], label: (day: string) => string = (d) => d) {
  return byDay.map((d) => ({
    day: d.day,
    dayLabel: label(d.day),
    sessions: d.sessions,
    avgSec: Math.round(d.avgSessionMs / 1000),
    bouncePct: Math.round(d.bounceRate * 1000) / 10,
    avgSessionMs: d.avgSessionMs,
    bounceRate: d.bounceRate,
  }));
}

export default function OverviewSection({ range }: { range: Range }) {
  const { t, formatDate } = useI18n();
  const q = useQuery({
    queryKey: qk.analytics.behavior('overview', range),
    queryFn: () => getBehaviorOverview(range),
  });
  const fmtDay = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });

  return (
    <Boundary query={q} subject={t('admin.bh.sub.overview')} height={420}>
      {(d) => {
        if (d.sessions === 0) {
          return (
            <EmptyState
              icon="chart"
              title={t('admin.bh.overview.emptyTitle')}
              description={t('admin.bh.overview.emptyBody')}
            />
          );
        }
        const rows = dayRows(d.byDay, (day) => fmtDay(day));
        const totalBuckets = d.durationBuckets.reduce((s, b) => s + b.sessions, 0);
        const dayCol = (r: { day: string }) => formatDate(r.day);
        const num = (v: string) => <span className={analytics.num}>{v}</span>;
        const sessionCols: Column<(typeof rows)[number]>[] = [
          { key: 'day', header: t('admin.analytics.table.date'), render: dayCol },
          { key: 'sessions', header: t('admin.bh.col.sessions'), align: 'end', render: (r) => num(formatInt(r.sessions)) },
        ];
        const avgCols: Column<(typeof rows)[number]>[] = [
          { key: 'day', header: t('admin.analytics.table.date'), render: dayCol },
          { key: 'avg', header: t('admin.bh.col.avgSession'), align: 'end', render: (r) => num(formatDuration(r.avgSessionMs)) },
        ];
        const bounceCols: Column<(typeof rows)[number]>[] = [
          { key: 'day', header: t('admin.analytics.table.date'), render: dayCol },
          { key: 'bounce', header: t('admin.bh.col.bounce'), align: 'end', render: (r) => num(formatPct(r.bounceRate)) },
        ];
        return (
          <div className={styles.stack}>
            <div className={styles.kpiGrid} data-search-anchor="anl-behavior-kpi">
              <StatTile
                label={t('admin.bh.kpi.sessions')}
                value={formatInt(d.sessions)}
                caption={t('admin.bh.kpi.sessionsHint', {
                  users: formatInt(d.users),
                  per: formatDec(d.sessionsPerUser),
                })}
                icon="clock"
              />
              <StatTile
                label={t('admin.bh.kpi.avgSession')}
                value={formatDuration(d.avgSessionMs)}
                caption={t('admin.bh.kpi.avgSessionHint')}
                icon="clock"
              />
              <StatTile
                label={t('admin.bh.kpi.medianSession')}
                value={formatDuration(d.medianSessionMs)}
                caption={t('admin.bh.kpi.medianSessionHint')}
                icon="clock"
              />
              <StatTile
                label={t('admin.bh.kpi.quickClose')}
                value={formatPct(d.quickCloseRate)}
                caption={t('admin.bh.kpi.quickCloseHint')}
                icon="alert"
              />
              <StatTile
                label={t('admin.bh.kpi.bounce')}
                value={formatPct(d.bounceRate)}
                caption={t('admin.bh.kpi.bounceHint')}
                icon="alert"
              />
              <StatTile
                label={t('admin.bh.kpi.screensPerSession')}
                value={formatDec(d.avgScreensPerSession)}
                caption={t('admin.bh.kpi.screensPerSessionHint')}
                icon="chart"
              />
            </div>

            <div className={analytics.grid2}>
              <ChartCard title={t('admin.bh.chart.sessionsByDay')} rows={rows} rowKey={(r) => r.day} columns={sessionCols}>
                <BarChart
                  data={rows}
                  xKey="dayLabel"
                  series={[{ key: 'sessions', label: t('admin.bh.col.sessions'), color: 'var(--chart-1)' }]}
                  ariaLabel={t('admin.bh.chart.sessionsByDay')}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
              <ChartCard title={t('admin.bh.chart.avgByDay')} rows={rows} rowKey={(r) => r.day} columns={avgCols}>
                <LineAreaChart
                  data={rows}
                  xKey="day"
                  series={[{ key: 'avgSec', label: t('admin.bh.chart.avgSeries'), color: 'var(--chart-3)' }]}
                  ariaLabel={t('admin.bh.chart.avgByDay')}
                  formatX={fmtDay}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
              <ChartCard title={t('admin.bh.chart.bounceByDay')} rows={rows} rowKey={(r) => r.day} columns={bounceCols}>
                <LineAreaChart
                  data={rows}
                  xKey="day"
                  series={[{ key: 'bouncePct', label: t('admin.bh.chart.bounceSeries'), color: 'var(--chart-2)' }]}
                  ariaLabel={t('admin.bh.chart.bounceByDay')}
                  formatX={fmtDay}
                  area={false}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
              <Card title={t('admin.bh.chart.buckets')} data-search-anchor="anl-behavior-buckets">
                <p className={analytics.muted}>{t('admin.bh.chart.bucketsHint')}</p>
                <BarList
                  ariaLabel={t('admin.bh.chart.buckets')}
                  items={d.durationBuckets.map((b) => ({
                    key: b.label,
                    label: b.label,
                    value: b.sessions,
                    percent: totalBuckets > 0 ? Math.round((b.sessions / totalBuckets) * 1000) / 10 : 0,
                  }))}
                />
              </Card>
            </div>
          </div>
        );
      }}
    </Boundary>
  );
}
