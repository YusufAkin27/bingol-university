import { useQuery } from '@tanstack/react-query';
import { getEngagement } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import type { DateRange } from '../../../api/types';
import { FunnelChart, LineAreaChart } from '../../../components/charts';
import { Card, EmptyState, RankedBars, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './analytics.module.css';
import { Async, BarList, ChartCard } from './parts';
import { funnelRows } from './transform';

/** Teknik olay adını (screen_view, message_sent) Türkçe yazar; bilinmeyeni gri "teknik ad" etiketiyle gösterir. */
function EventName({ name }: { name: string }) {
  const { t, td } = useI18n();
  const label = td(`admin.v2p.anl.event.${name}`, '');
  if (label) return <span title={name}>{label}</span>;
  return (
    <span>
      <code className="ltr">{name}</code> <span className={styles.muted}>{t('admin.v2p.anl.technicalName')}</span>
    </span>
  );
}

export default function EngagementTab({ range }: { range: DateRange }) {
  const { t, td, formatDate, formatNumber } = useI18n();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });
  const q = useQuery({ queryKey: qk.analytics.engagement(range), queryFn: () => getEngagement(range) });

  return (
    <div className={styles.panel}>
      <Async query={q} height={320} title={t('admin.v2p.anl.engagement.title')}>
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
            { key: 'name', header: t('admin.analytics.engagement.event'), render: (e) => <EventName name={e.name} /> },
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
          const sumOf = (k: 'messages' | 'posts' | 'rsvps' | 'searches') => d.daily.reduce((s, r) => s + r[k], 0);
          const dailyTotal = sumOf('messages') + sumOf('posts') + sumOf('rsvps') + sumOf('searches');
          const dailyInsight =
            dailyTotal > 0
              ? {
                  tone: 'info' as const,
                  parts: t('admin.genel.anl.dailySentence', {
                    messages: formatNumber(sumOf('messages')),
                    posts: formatNumber(sumOf('posts')),
                    rsvps: formatNumber(sumOf('rsvps')),
                    searches: formatNumber(sumOf('searches')),
                  }),
                }
              : null;
          return (
            <>
              <div className={styles.grid2}>
                <Card title={t('admin.analytics.funnel.title')} data-search-anchor="anl-funnel">
                  <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-3)' }}>
                    {t('admin.analytics.funnel.note')}
                  </p>
                  <FunnelChart
                    steps={rows.map((r) => ({ label: td(`admin.analytics.funnel.${r.step}`, r.step), value: r.count }))}
                    ariaLabel={t('admin.analytics.funnel.title')}
                    emptyLabel={t('admin.analytics.chart.noData')}
                  />
                  {rows.length > 1 && (
                    <ul className={styles.funnelNotes}>
                      {rows.slice(1).map((r) => (
                        <li key={r.step}>
                          {t('admin.v2p.anl.funnel.keep', {
                            step: td(`admin.analytics.funnel.${r.step}`, r.step),
                            pct: formatNumber(r.fromPrev ?? 0),
                          })}
                        </li>
                      ))}
                    </ul>
                  )}
                  {rows.length > 0 && (
                    <details style={{ marginBlockStart: 'var(--space-3)' }} data-testid="funnel-table">
                      <summary className={styles.detailsSummary}>{t('admin.analytics.table.show')}</summary>
                      <Table caption={t('admin.analytics.funnel.title')} columns={funnelCols} rows={rows} rowKey={(r) => r.step} />
                    </details>
                  )}
                </Card>

                <Card title={t('admin.analytics.engagement.topEvents')} data-search-anchor="anl-events">
                  {d.topEvents.length === 0 ? (
                    <EmptyState compact icon="chart" title={t('admin.analytics.engagement.noEvents')} description=" " />
                  ) : (
                    <>
                      <RankedBars
                        ariaLabel={t('admin.analytics.engagement.topEvents')}
                        limit={6}
                        truncateAt={40}
                        items={d.topEvents.map((e) => ({
                          key: e.name,
                          label: td(`admin.v2p.anl.event.${e.name}`, e.name),
                          value: e.count,
                          hint: t('admin.genel.anl.eventUsers', { n: formatNumber(e.uniqueUsers) }),
                        }))}
                      />
                      <details style={{ marginBlockStart: 'var(--space-3)' }} data-testid="events-table">
                        <summary className={styles.detailsSummary}>{t('admin.analytics.table.show')}</summary>
                        <Table
                          caption={t('admin.analytics.engagement.topEvents')}
                          columns={eventCols}
                          rows={d.topEvents}
                          rowKey={(e) => e.name}
                        />
                      </details>
                    </>
                  )}
                </Card>
              </div>

              <div data-search-anchor="anl-daily">
              <ChartCard
                title={t('admin.v2p.anl.engagement.dailyTitle')}
                rows={d.daily}
                rowKey={(r) => r.date}
                columns={dailyCols}
                insight={dailyInsight}
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
                  ariaLabel={t('admin.v2p.anl.engagement.dailyTitle')}
                  formatX={fmt}
                  emptyLabel={t('admin.analytics.chart.noData')}
                />
              </ChartCard>
              </div>

              <Card title={t('admin.analytics.engagement.screens')} data-search-anchor="anl-screens">
                {d.screens.length === 0 ? (
                  <EmptyState compact icon="chart" title={t('admin.analytics.engagement.noEvents')} description=" " />
                ) : (
                  <BarList
                    ariaLabel={t('admin.analytics.engagement.screens')}
                    items={d.screens.slice(0, 8).map((s) => ({
                      key: s.screen,
                      label: td(`admin.v2p.anl.screen.${s.screen}`, s.screen),
                      value: s.views,
                    }))}
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
