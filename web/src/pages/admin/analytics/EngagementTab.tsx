import { useQuery } from '@tanstack/react-query';
import { getEngagement } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import type { DateRange } from '../../../api/types';
import { FunnelChart, LineAreaChart } from '../../../components/charts';
import { Card, EmptyState, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './analytics.module.css';
import { Async, BarList, ChartCard } from './parts';
import { funnelRows } from './transform';

export default function EngagementTab({ range }: { range: DateRange }) {
  const { t, td, formatDate, formatNumber } = useI18n();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });
  const q = useQuery({ queryKey: qk.analytics.engagement(range), queryFn: () => getEngagement(range) });

  return (
    <div className={styles.panel}>
      <Async query={q} height={320}>
        {(d) => {
          const rows = funnelRows(d.funnel);
          const funnelCols: Column<(typeof rows)[number]>[] = [
            { key: 'step', header: t('admin.analytics.funnel.step'), render: (r) => td(`admin.analytics.funnel.${r.step}`, r.step) },
            {
              key: 'count',
              header: t('admin.analytics.funnel.users'),
              align: 'end',
              render: (r) => <span className={styles.num}>{formatNumber(r.count)}</span>,
            },
            {
              key: 'conv',
              header: t('admin.analytics.funnel.conversion'),
              align: 'end',
              render: (r) => (
                <span className={`${styles.num} ltr`}>{r.fromPrev === null ? '—' : `%${formatNumber(r.fromPrev)}`}</span>
              ),
            },
          ];
          const eventCols: Column<(typeof d.topEvents)[number]>[] = [
            { key: 'name', header: t('admin.analytics.engagement.event'), render: (e) => <code className="ltr">{e.name}</code> },
            {
              key: 'count',
              header: t('admin.analytics.engagement.count'),
              align: 'end',
              render: (e) => <span className={styles.num}>{formatNumber(e.count)}</span>,
            },
            {
              key: 'uniqueUsers',
              header: t('admin.analytics.engagement.uniqueUsers'),
              align: 'end',
              render: (e) => <span className={styles.num}>{formatNumber(e.uniqueUsers)}</span>,
            },
          ];
          const dailyCols: Column<(typeof d.daily)[number]>[] = [
            { key: 'date', header: t('admin.analytics.table.date'), render: (r) => formatDate(r.date) },
            ...(['messages', 'posts', 'rsvps', 'searches'] as const).map(
              (k): Column<(typeof d.daily)[number]> => ({
                key: k,
                header: t(`admin.analytics.engagement.${k}`),
                align: 'end',
                render: (r) => <span className={styles.num}>{formatNumber(r[k])}</span>,
              }),
            ),
          ];
          return (
            <>
              <div className={styles.grid2}>
                <Card title={t('admin.analytics.funnel.title')}>
                  <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-3)' }}>
                    {t('admin.analytics.funnel.note')}
                  </p>
                  <FunnelChart
                    steps={rows.map((r) => ({ label: td(`admin.analytics.funnel.${r.step}`, r.step), value: r.count }))}
                    ariaLabel={t('admin.analytics.funnel.title')}
                    emptyLabel={t('admin.analytics.chart.noData')}
                  />
                  {rows.length > 0 && (
                    <div style={{ marginBlockStart: 'var(--space-4)' }} data-testid="funnel-table">
                      <Table caption={t('admin.analytics.funnel.title')} columns={funnelCols} rows={rows} rowKey={(r) => r.step} />
                    </div>
                  )}
                </Card>

                <Card title={t('admin.analytics.engagement.topEvents')}>
                  <Table
                    caption={t('admin.analytics.engagement.topEvents')}
                    columns={eventCols}
                    rows={d.topEvents}
                    rowKey={(e) => e.name}
                    empty={<EmptyState compact icon="chart" title={t('admin.analytics.engagement.noEvents')} description=" " />}
                  />
                </Card>
              </div>

              <ChartCard
                title={t('admin.analytics.engagement.daily')}
                rows={d.daily}
                rowKey={(r) => r.date}
                columns={dailyCols}
              >
                <LineAreaChart
                  data={d.daily}
                  xKey="date"
                  area={false}
                  series={[
                    { key: 'messages', label: t('admin.analytics.engagement.messages') },
                    { key: 'posts', label: t('admin.analytics.engagement.posts') },
                    { key: 'rsvps', label: t('admin.analytics.engagement.rsvps') },
                    { key: 'searches', label: t('admin.analytics.engagement.searches') },
                  ]}
                  ariaLabel={t('admin.analytics.engagement.daily')}
                  formatX={fmt}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>

              <Card title={t('admin.analytics.engagement.screens')}>
                {d.screens.length === 0 ? (
                  <EmptyState compact icon="chart" title={t('admin.analytics.engagement.noEvents')} description=" " />
                ) : (
                  <BarList
                    ariaLabel={t('admin.analytics.engagement.screens')}
                    items={d.screens.map((s) => ({ key: s.screen, label: s.screen, value: s.views }))}
                  />
                )}
              </Card>
            </>
          );
        }}
      </Async>
    </div>
  );
}
