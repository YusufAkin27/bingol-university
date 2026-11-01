import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { getOverview, getRegistrations } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import type { DateRange } from '../../../api/types';
import { LineAreaChart } from '../../../components/charts';
import { Card, ProgressRing, StatTile, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { lastDays } from '../../../lib/date';
import styles from './analytics.module.css';
import { Async, ChartCard } from './parts';
import { periodCompare } from './transform';

export default function GrowthTab({ range }: { range: DateRange }) {
  const { t, formatDate, formatNumber } = useI18n();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });

  const regs = useQuery({ queryKey: qk.analytics.registrations(range), queryFn: () => getRegistrations(range) });
  // Karşılaştırma seçili aralıktan bağımsızdır: 30 + 30 gün için son 60 gün alınır
  const wide = useMemo(() => lastDays(60), []);
  const regs60 = useQuery({ queryKey: qk.analytics.registrations(wide), queryFn: () => getRegistrations(wide) });
  const overview = useQuery({ queryKey: qk.analytics.overview(), queryFn: getOverview });

  const col = (key: 'count' | 'cumulative', header: string): Column<{ date: string; count: number; cumulative: number }> => ({
    key,
    header,
    align: 'end',
    render: (r) => <span className={styles.num}>{formatNumber(r[key])}</span>,
  });
  const dateCol: Column<{ date: string; count: number; cumulative: number }> = {
    key: 'date',
    header: t('admin.analytics.table.date'),
    render: (r) => formatDate(r.date),
  };

  return (
    <div className={styles.panel}>
      <div className={styles.grid2}>
        <Async query={regs} title={t('admin.analytics.growth.reg')}>
          {(d) => {
            const total = d.points.reduce((s, p) => s + p.count, 0);
            return (
              <ChartCard
                title={t('admin.analytics.growth.reg')}
                rows={d.points}
                rowKey={(r) => r.date}
                columns={[dateCol, col('count', t('admin.analytics.overview.regSeries'))]}
              >
                <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-2)' }}>
                  {t('admin.analytics.growth.total', { n: formatNumber(total) })}
                </p>
                <LineAreaChart
                  data={d.points}
                  xKey="date"
                  series={[{ key: 'count', label: t('admin.analytics.overview.regSeries') }]}
                  ariaLabel={t('admin.analytics.growth.reg')}
                  formatX={fmt}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
            );
          }}
        </Async>
        <Async query={regs}>
          {(d) => (
            <ChartCard
              title={t('admin.analytics.growth.cum')}
              rows={d.points}
              rowKey={(r) => r.date}
              columns={[dateCol, col('cumulative', t('admin.analytics.overview.cumSeries'))]}
            >
              <LineAreaChart
                data={d.points}
                xKey="date"
                series={[{ key: 'cumulative', label: t('admin.analytics.overview.cumSeries'), color: 'var(--chart-5)' }]}
                ariaLabel={t('admin.analytics.growth.cum')}
                formatX={fmt}
                emptyLabel={t('admin.analytics.chart.noData')}
              />
            </ChartCard>
          )}
        </Async>
      </div>

      <div className={styles.grid2}>
        <Card title={t('admin.analytics.growth.compare')}>
          <Async query={regs60} height={140} title={t('admin.analytics.growth.compare')}>
            {(d) => {
              const counts = d.points.map((p) => p.count);
              const week = periodCompare(counts, 7);
              const month = periodCompare(counts, 30);
              return (
                <div className={styles.summaryTiles}>
                  <StatTile
                    label={t('admin.analytics.growth.week')}
                    value={week.current}
                    unit={t('admin.v2p.unit.person')}
                    change={week.change}
                    compareLabel={t('admin.analytics.growth.vsPrev', { n: formatNumber(7) })}
                    caption={t('admin.analytics.growth.prevCount', { n: formatNumber(week.previous) })}
                  />
                  <StatTile
                    label={t('admin.analytics.growth.month')}
                    value={month.current}
                    unit={t('admin.v2p.unit.person')}
                    change={month.change}
                    compareLabel={t('admin.analytics.growth.vsPrev', { n: formatNumber(30) })}
                    caption={t('admin.analytics.growth.prevCount', { n: formatNumber(month.previous) })}
                  />
                </div>
              );
            }}
          </Async>
        </Card>

        <Async query={overview} title={t('admin.analytics.growth.verification')}>
          {(o) => {
            const unverified = Math.max(o.totalUsers - o.verifiedUsers, 0);
            const rows = [
              { key: 'v', name: t('admin.analytics.growth.verified'), value: o.verifiedUsers },
              { key: 'u', name: t('admin.analytics.growth.unverified'), value: unverified },
            ];
            return (
              <ChartCard
                title={t('admin.analytics.growth.verification')}
                rows={rows}
                rowKey={(r) => r.key}
                columns={[
                  { key: 'name', header: t('admin.analytics.demo.category') },
                  {
                    key: 'value',
                    header: t('admin.analytics.demo.count'),
                    align: 'end',
                    render: (r) => <span className={styles.num}>{formatNumber(r.value)}</span>,
                  },
                ]}
              >
                <ProgressRing
                  value={o.verifiedUsers}
                  max={Math.max(o.totalUsers, 1)}
                  label={t('admin.v2p.dash.verified.label')}
                  tone="success"
                />
                <p className={styles.muted} style={{ textAlign: 'center', marginBlock: 'var(--space-3)' }}>
                  {t('admin.analytics.growth.verifiedOf', {
                    verified: formatNumber(o.verifiedUsers),
                    total: formatNumber(o.totalUsers),
                  })}
                </p>
              </ChartCard>
            );
          }}
        </Async>
      </div>
    </div>
  );
}
