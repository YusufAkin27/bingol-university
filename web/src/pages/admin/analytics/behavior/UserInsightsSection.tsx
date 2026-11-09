import type { UserInsights } from '../../../../api/analyticsBehavior';
import { Badge, Card, EmptyState, ResponsiveTable, StatTile, type Column } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import { actionLabel, formatDayShort, formatDuration, formatInt, formatPct, screenLabel } from './format';

export default function UserInsightsSection({ data }: { data: UserInsights }) {
  const { t } = useI18n();
  const columns: Column<UserInsights['screens'][number]>[] = [
    {
      key: 'screen',
      header: t('admin.bh.col.screen'),
      card: { priority: 1 },
      render: (r) => <strong>{screenLabel(r.screen)}</strong>,
    },
    {
      key: 'totalMs',
      header: t('admin.bh.col.totalTime'),
      align: 'end',
      card: { priority: 2 },
      render: (r) => formatDuration(r.totalMs),
    },
    {
      key: 'views',
      header: t('admin.bh.col.views'),
      align: 'end',
      card: { priority: 3 },
      render: (r) => formatInt(r.views),
    },
    {
      key: 'avgMs',
      header: t('admin.bh.col.avgDwell'),
      align: 'end',
      render: (r) => (r.measuredVisits ? formatDuration(r.avgMs) : '—'),
    },
    {
      key: 'maxMs',
      header: t('admin.bh.insights.longest'),
      align: 'end',
      render: (r) => (r.measuredVisits ? formatDuration(r.maxMs) : '—'),
    },
    { key: 'share', header: t('admin.bh.col.share'), align: 'end', render: (r) => formatPct(r.share) },
  ];
  const activeDays = data.byDay.filter((d) => d.sessions > 0).length;
  const totalActions = data.actions.reduce((n, a) => n + a.count, 0);
  const maxHour = Math.max(1, ...data.byHour.map((h) => h.views));
  const maxDay = Math.max(1, ...data.byDay.map((d) => d.totalMs));
  return (
    <div className={styles.stack}>
      {data.partial && (
        <p className={styles.partial} role="note">
          {t('admin.bh.insights.partial', { n: formatInt(data.eventCount) })}
        </p>
      )}
      <div className={styles.drawerKpis}>
        <StatTile label={t('admin.bh.insights.activeDays')} value={formatInt(activeDays)} />
        <StatTile
          label={t('admin.bh.insights.screenCount')}
          value={formatInt(data.screens.filter((s) => s.views > 0).length)}
        />
        <StatTile label={t('admin.bh.insights.actions')} value={formatInt(totalActions)} />
      </div>
      <Card title={t('admin.bh.insights.screens')}>
        <p className={analytics.muted}>{t('admin.bh.insights.measurement')}</p>
        <ResponsiveTable
          caption={t('admin.bh.insights.screens')}
          columns={columns}
          rows={data.screens}
          rowKey={(r) => r.screen}
        />
      </Card>
      <Card title={t('admin.bh.insights.daily')}>
        <p className={analytics.muted}>{t('admin.bh.insights.dailyNote')}</p>
        <ul className={styles.dayActivity} aria-label={t('admin.bh.insights.daily')}>
          {data.byDay.map((d) => (
            <li key={d.day}>
              <div className={styles.dayHead}>
                <strong>{formatDayShort(`${d.day}T12:00:00+03:00`)}</strong>
                <span>{formatDuration(d.totalMs)}</span>
              </div>
              <div className={styles.activityTrack} aria-hidden="true">
                <span style={{ inlineSize: `${(d.totalMs / maxDay) * 100}%` }} />
              </div>
              <span className={analytics.muted}>
                {t('admin.bh.insights.dayCounts', {
                  sessions: formatInt(d.sessions),
                  views: formatInt(d.views),
                  actions: formatInt(d.actions),
                })}
              </span>
            </li>
          ))}
        </ul>
      </Card>
      <Card title={t('admin.bh.insights.hours')}>
        <p className={analytics.muted}>{t('admin.bh.insights.hoursNote')}</p>
        <ul className={styles.hourActivity} aria-label={t('admin.bh.insights.hours')}>
          {data.byHour.map((h) => (
            <li
              key={h.hour}
              title={t('admin.bh.insights.hourCounts', {
                hour: `${h.hour}`.padStart(2, '0'),
                views: formatInt(h.views),
                actions: formatInt(h.actions),
              })}
            >
              <strong className="ltr">{`${h.hour}`.padStart(2, '0')}:00</strong>
              <div className={styles.activityTrack} aria-hidden="true">
                <span style={{ inlineSize: `${(h.views / maxHour) * 100}%` }} />
              </div>
              <span>{t('admin.bh.insights.views', { n: formatInt(h.views) })}</span>
              <span className={analytics.muted}>
                {t('admin.bh.insights.actionCount', { n: formatInt(h.actions) })}
              </span>
            </li>
          ))}
        </ul>
      </Card>
      <Card title={t('admin.bh.insights.actions')}>
        {data.actions.length === 0 ? (
          <EmptyState compact icon="chart" title={t('admin.bh.insights.noActions')} />
        ) : (
          <ul className={styles.actionBreakdown}>
            {data.actions.map((a) => (
              <li key={a.kind}>
                <span>{actionLabel(a.kind)}</span>
                <Badge tone="neutral">{formatInt(a.count)}</Badge>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
