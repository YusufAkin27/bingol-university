import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import {
  getActiveUsers,
  getContentAnalytics,
  getPushAnalytics,
  getRegistrations,
  getSupportAnalytics,
} from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { BarChart, DonutChart } from '../../../components/charts';
import { Card, EmptyState, Insight, StatCard, StatusPill, Table, toneFor, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from '../dashboard/dict';
import { DailySummary } from './DailySummary';
import styles from './analytics.module.css';
import { Async, BarList, ChartCard } from './parts';
import { PeriodChart } from './PeriodChart';
import { humanizeMinutes, previousRange } from './transform';
import type { DateRange } from '../../../api/types';

export default function OverviewTab({ range, compare }: { range: DateRange; compare: boolean }) {
  const { t, td, formatDate, formatNumber, formatDateTime } = useI18n();
  const g = useGt();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });
  const dateCol = { key: 'date', header: t('admin.analytics.table.date'), render: (r: { date: string }) => formatDate(r.date) };
  const numCol = <T extends object>(key: keyof T & string, header: string): Column<T> => ({
    key,
    header,
    align: 'end',
    render: (r) => <span className={styles.num}>{formatNumber(r[key] as number)}</span>,
  });

  const prevRange = useMemo(() => (compare ? previousRange(range) : null), [compare, range]);
  const dau = useQuery({ queryKey: qk.analytics.activeUsers(range), queryFn: () => getActiveUsers(range) });
  const regs = useQuery({ queryKey: qk.analytics.registrations(range), queryFn: () => getRegistrations(range) });
  const dauPrev = useQuery({
    queryKey: qk.analytics.activeUsers(prevRange ?? {}),
    queryFn: () => getActiveUsers(prevRange as DateRange),
    enabled: !!prevRange,
  });
  const regsPrev = useQuery({
    queryKey: qk.analytics.registrations(prevRange ?? {}),
    queryFn: () => getRegistrations(prevRange as DateRange),
    enabled: !!prevRange,
  });
  const content = useQuery({ queryKey: qk.analytics.content(range), queryFn: () => getContentAnalytics(range) });
  const support = useQuery({ queryKey: qk.analytics.support(), queryFn: getSupportAnalytics });
  const push = useQuery({ queryKey: qk.analytics.push(), queryFn: getPushAnalytics });

  return (
    <div className={styles.panel}>
      <DailySummary />
      <div className={styles.grid2}>
        <Async query={dau} title={t('admin.v2p.dash.trend.dau')}>
          {(d) => (
            <PeriodChart
              title={t('admin.v2p.dash.trend.dau')}
              anchor="anl-dau"
              points={d.points.map((p) => ({ date: p.date, value: p.dau }))}
              prevPoints={dauPrev.data?.points.map((p) => ({ date: p.date, value: p.dau }))}
              seriesLabel={t('admin.analytics.overview.dauSeries')}
              color="var(--chart-3)"
              mode="avg"
              verb={t('admin.v2p.dash.verbEntered')}
              extra={
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
              }
            />
          )}
        </Async>

        <Async query={regs} title={t('admin.v2p.dash.trend.signups')}>
          {(d) => (
            <PeriodChart
              title={t('admin.v2p.dash.trend.signups')}
              anchor="anl-reg"
              points={d.points.map((p) => ({ date: p.date, value: p.count }))}
              prevPoints={regsPrev.data?.points.map((p) => ({ date: p.date, value: p.count }))}
              seriesLabel={t('admin.analytics.overview.regSeries')}
              mode="sum"
              verb={g('admin.genel.anl.verbJoined')}
            />
          )}
        </Async>

        <Async query={content} title={t('admin.analytics.overview.content')}>
          {(d) => {
            const data = d.daily.map((x) => ({ ...x, label: fmt(x.date) }));
            const sum = (k: 'news' | 'announcements' | 'events') => d.daily.reduce((s, x) => s + x[k], 0);
            const total = sum('news') + sum('announcements') + sum('events');
            return (
              <div data-search-anchor="anl-content">
              <ChartCard
                title={t('admin.analytics.overview.content')}
                rows={d.daily}
                rowKey={(r) => r.date}
                insight={
                  total > 0
                    ? {
                        tone: 'info',
                        parts: g('admin.genel.anl.contentSentence', {
                          total: formatNumber(total),
                          news: formatNumber(sum('news')),
                          ann: formatNumber(sum('announcements')),
                          ev: formatNumber(sum('events')),
                        }),
                      }
                    : null
                }
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
              </div>
            );
          }}
        </Async>
      </div>

      <div className={styles.grid2}>
        <Card title={t('admin.analytics.support.title')} data-search-anchor="anl-support">
          <Async query={support} height={160} title={t('admin.analytics.support.title')}>
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
                  <div className={styles.ticketsBody}>
                    <Insight
                      tone={d.tickets.open > 0 ? 'warn' : 'good'}
                      parts={
                        d.tickets.open + d.tickets.answered + d.tickets.closed === 0
                          ? g('admin.genel.anl.ticketsNone')
                          : g('admin.genel.anl.ticketsSentence', {
                              open: formatNumber(d.tickets.open),
                              answered: formatNumber(d.tickets.answered),
                              closed: formatNumber(d.tickets.closed),
                            })
                      }
                    />
                    <DonutChart
                      data={[
                        { name: t('admin.analytics.support.open'), value: d.tickets.open },
                        { name: t('admin.analytics.support.answered'), value: d.tickets.answered },
                        { name: t('admin.analytics.support.closed'), value: d.tickets.closed },
                      ]}
                      ariaLabel={t('admin.analytics.support.title')}
                      height={220}
                      emptyLabel={g('admin.genel.anl.ticketsNone')}
                    />
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

        <Card title={t('admin.analytics.push.title')} data-search-anchor="anl-push">
          <Async query={push} height={160} title={t('admin.analytics.push.title')}>
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

    </div>
  );
}
