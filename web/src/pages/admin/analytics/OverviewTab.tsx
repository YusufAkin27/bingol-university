import { useQuery } from '@tanstack/react-query';
import {
  getActiveUsers,
  getContentAnalytics,
  getPushAnalytics,
  getRegistrations,
  getSupportAnalytics,
} from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { BarChart, LineAreaChart } from '../../../components/charts';
import { Card, EmptyState, StatCard, StatusPill, Table, toneFor, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { SourcesPanel } from '../dashboard/panels';
import styles from './analytics.module.css';
import { Async, BarList, ChartCard } from './parts';
import { humanizeMinutes } from './transform';
import type { DateRange } from '../../../api/types';

export default function OverviewTab({ range }: { range: DateRange }) {
  const { t, td, formatDate, formatNumber, formatDateTime } = useI18n();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });
  const dateCol = { key: 'date', header: t('admin.analytics.table.date'), render: (r: { date: string }) => formatDate(r.date) };
  const numCol = <T extends object>(key: keyof T & string, header: string): Column<T> => ({
    key,
    header,
    align: 'end',
    render: (r) => <span className={styles.num}>{formatNumber(r[key] as number)}</span>,
  });

  const dau = useQuery({ queryKey: qk.analytics.activeUsers(range), queryFn: () => getActiveUsers(range) });
  const regs = useQuery({ queryKey: qk.analytics.registrations(range), queryFn: () => getRegistrations(range) });
  const content = useQuery({ queryKey: qk.analytics.content(range), queryFn: () => getContentAnalytics(range) });
  const support = useQuery({ queryKey: qk.analytics.support(), queryFn: getSupportAnalytics });
  const push = useQuery({ queryKey: qk.analytics.push(), queryFn: getPushAnalytics });

  return (
    <div className={styles.panel}>
      <div className={styles.grid2}>
        <Async query={dau}>
          {(d) => (
            <ChartCard
              title={t('admin.analytics.overview.dau')}
              rows={d.points}
              rowKey={(r) => r.date}
              columns={[dateCol, numCol('dau', t('admin.analytics.overview.dauSeries'))]}
            >
              <div className={styles.chips}>
                <div className={styles.chip}>
                  <span className={styles.chipLabel}>{t('admin.analytics.overview.wau')}</span>
                  <span className={styles.chipValue}>{formatNumber(d.wau)}</span>
                </div>
                <div className={styles.chip}>
                  <span className={styles.chipLabel}>{t('admin.analytics.overview.mau')}</span>
                  <span className={styles.chipValue}>{formatNumber(d.mau)}</span>
                </div>
              </div>
              <LineAreaChart
                data={d.points}
                xKey="date"
                series={[{ key: 'dau', label: t('admin.analytics.overview.dauSeries'), color: 'var(--chart-3)' }]}
                ariaLabel={t('admin.analytics.overview.dau')}
                formatX={fmt}
                emptyLabel={t('admin.analytics.chart.noData')}
              />
            </ChartCard>
          )}
        </Async>

        <Async query={regs}>
          {(d) => (
            <ChartCard
              title={t('admin.analytics.overview.reg')}
              rows={d.points}
              rowKey={(r) => r.date}
              columns={[dateCol, numCol('count', t('admin.analytics.overview.regSeries')), numCol('cumulative', t('admin.analytics.overview.cumSeries'))]}
            >
              <LineAreaChart
                data={d.points}
                xKey="date"
                series={[{ key: 'count', label: t('admin.analytics.overview.regSeries') }]}
                ariaLabel={t('admin.analytics.overview.reg')}
                formatX={fmt}
                emptyLabel={t('admin.analytics.chart.noData')}
              />
            </ChartCard>
          )}
        </Async>

        <Async query={regs}>
          {(d) => (
            <ChartCard
              title={t('admin.analytics.overview.cum')}
              rows={d.points}
              rowKey={(r) => r.date}
              columns={[dateCol, numCol('cumulative', t('admin.analytics.overview.cumSeries'))]}
            >
              <LineAreaChart
                data={d.points}
                xKey="date"
                series={[{ key: 'cumulative', label: t('admin.analytics.overview.cumSeries'), color: 'var(--chart-5)' }]}
                ariaLabel={t('admin.analytics.overview.cum')}
                formatX={fmt}
                emptyLabel={t('admin.analytics.chart.noData')}
              />
            </ChartCard>
          )}
        </Async>

        <Async query={content}>
          {(d) => {
            const data = d.daily.map((x) => ({ ...x, label: fmt(x.date) }));
            return (
              <ChartCard
                title={t('admin.analytics.overview.content')}
                rows={d.daily}
                rowKey={(r) => r.date}
                columns={[
                  dateCol,
                  numCol('news', t('admin.analytics.overview.news')),
                  numCol('announcements', t('admin.analytics.overview.announcements')),
                  numCol('events', t('admin.analytics.overview.events')),
                ]}
              >
                <BarChart
                  data={data}
                  xKey="label"
                  stacked
                  series={[
                    { key: 'news', label: t('admin.analytics.overview.news') },
                    { key: 'announcements', label: t('admin.analytics.overview.announcements') },
                    { key: 'events', label: t('admin.analytics.overview.events') },
                  ]}
                  ariaLabel={t('admin.analytics.overview.content')}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
            );
          }}
        </Async>
      </div>

      <div className={styles.grid2}>
        <Card title={t('admin.analytics.support.title')}>
          <Async query={support} height={160}>
            {(d) => {
              const avg = d.avgFirstResponseMinutes;
              const h = avg ? humanizeMinutes(avg) : null;
              const cat = d.feedbackByCategory.map((c) => ({
                key: c.key,
                label: td(`admin.analytics.category.${c.key}`, c.key),
                value: c.count,
              }));
              const st = d.feedbackByStatus.map((c) => ({
                key: c.key,
                label: td(`admin.analytics.fstatus.${c.key}`, c.key),
                value: c.count,
              }));
              return (
                <>
                  <div className={styles.grid3}>
                    <StatCard title={t('admin.analytics.support.open')} value={formatNumber(d.tickets.open)} />
                    <StatCard title={t('admin.analytics.support.answered')} value={formatNumber(d.tickets.answered)} />
                    <StatCard title={t('admin.analytics.support.closed')} value={formatNumber(d.tickets.closed)} />
                  </div>
                  <p className={styles.muted} style={{ marginBlockStart: 'var(--space-3)' }}>
                    {t('admin.analytics.support.avg')}:{' '}
                    <strong>
                      {h
                        ? t(h.unit === 'hours' ? 'admin.analytics.support.hours' : 'admin.analytics.support.minutes', {
                            n: formatNumber(h.value),
                          })
                        : t('admin.analytics.support.noAvg')}
                    </strong>
                  </p>
                  <h3 className={styles.sub}>{t('admin.analytics.support.byCategory')}</h3>
                  {cat.length ? (
                    <BarList items={cat} ariaLabel={t('admin.analytics.support.byCategory')} />
                  ) : (
                    <p className={styles.muted}>{t('admin.analytics.support.noFeedback')}</p>
                  )}
                  {st.length > 0 && (
                    <>
                      <h3 className={styles.sub}>{t('admin.analytics.support.byStatus')}</h3>
                      <BarList items={st} ariaLabel={t('admin.analytics.support.byStatus')} />
                    </>
                  )}
                </>
              );
            }}
          </Async>
        </Card>

        <Card title={t('admin.analytics.push.title')}>
          <Async query={push} height={160}>
            {(d) => {
              const columns: Column<(typeof d.recent)[number]>[] = [
                { key: 'title', header: t('admin.analytics.push.col.title'), render: (c) => c.tr.title },
                {
                  key: 'status',
                  header: t('admin.analytics.push.col.status'),
                  render: (c) => (
                    <StatusPill tone={toneFor(c.status)}>
                      {td(`admin.analytics.push.status.${c.status}`, c.status)}
                    </StatusPill>
                  ),
                },
                {
                  key: 'recipients',
                  header: t('admin.analytics.push.col.recipients'),
                  align: 'end',
                  render: (c) => <span className={styles.num}>{c.recipientCount === null ? '—' : formatNumber(c.recipientCount)}</span>,
                },
                {
                  key: 'date',
                  header: t('admin.analytics.push.col.date'),
                  render: (c) => <span className={styles.num}>{formatDateTime(c.finishedAt ?? c.scheduledAt ?? c.createdAt)}</span>,
                },
              ];
              return (
                <>
                  <div className={styles.grid3} style={{ gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' }}>
                    <StatCard title={t('admin.analytics.push.campaigns')} value={formatNumber(d.totals.campaigns)} />
                    <StatCard title={t('admin.analytics.push.recipients')} value={formatNumber(d.totals.recipients)} />
                  </div>
                  <h3 className={styles.sub}>{t('admin.analytics.push.recent')}</h3>
                  <Table
                    caption={t('admin.analytics.push.recent')}
                    columns={columns}
                    rows={d.recent}
                    rowKey={(c) => c.id}
                    empty={<EmptyState compact icon="bell" title={t('admin.analytics.push.empty')} description=" " />}
                  />
                </>
              );
            }}
          </Async>
        </Card>
      </div>

      <SourcesPanel />
    </div>
  );
}
