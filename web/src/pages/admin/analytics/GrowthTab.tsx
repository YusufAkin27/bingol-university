import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { getOverview, getRegistrations } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import type { DateRange } from '../../../api/types';
import { Card, ProgressRing, StatTile } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from '../dashboard/dict';
import { lastDays } from '../../../lib/date';
import styles from './analytics.module.css';
import { Async, ChartCard } from './parts';
import { PeriodChart } from './PeriodChart';
import { periodCompare, previousRange } from './transform';

export default function GrowthTab({ range, compare }: { range: DateRange; compare: boolean }) {
  const { t, formatNumber } = useI18n();
  const g = useGt();

  const regs = useQuery({ queryKey: qk.analytics.registrations(range), queryFn: () => getRegistrations(range) });
  // Karşılaştırma seçili aralıktan bağımsızdır: 30 + 30 gün için son 60 gün alınır
  const wide = useMemo(() => lastDays(60), []);
  const prevRange = useMemo(() => (compare ? previousRange(range) : null), [compare, range]);
  const regsPrev = useQuery({
    queryKey: qk.analytics.registrations(prevRange ?? {}),
    queryFn: () => getRegistrations(prevRange as DateRange),
    enabled: !!prevRange,
  });
  const regs60 = useQuery({ queryKey: qk.analytics.registrations(wide), queryFn: () => getRegistrations(wide) });
  const overview = useQuery({ queryKey: qk.analytics.overview(), queryFn: getOverview });

  return (
    <div className={styles.panel}>
      <div className={styles.grid2}>
        <Async query={regs} title={t('admin.analytics.growth.reg')}>
          {(d) => (
            <PeriodChart
              title={t('admin.v2p.dash.trend.signups')}
              anchor="anl-growth-reg"
              points={d.points.map((p) => ({ date: p.date, value: p.count }))}
              prevPoints={regsPrev.data?.points.map((p) => ({ date: p.date, value: p.count }))}
              seriesLabel={t('admin.analytics.overview.regSeries')}
              mode="sum"
              verb={g('admin.genel.anl.verbJoined')}
            />
          )}
        </Async>
        <Async query={regs} title={t('admin.analytics.growth.cum')}>
          {(d) => (
            <PeriodChart
              title={t('admin.analytics.growth.cum')}
              anchor="anl-growth-cum"
              points={d.points.map((p) => ({ date: p.date, value: p.cumulative }))}
              seriesLabel={t('admin.analytics.overview.cumSeries')}
              color="var(--chart-5)"
              mode="sum"
              verb=""
              noInsight
            />
          )}
        </Async>
      </div>

      <div className={styles.grid2}>
        <Card title={t('admin.analytics.growth.compare')} data-search-anchor="anl-compare">
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
