// Bildirim istatistikleri sekmesi: GET /api/admin/notifications/stats (son 14 gün, toplu; kullanıcı yok).
import { useQuery } from '@tanstack/react-query';
import { getNotificationStats, pushOpsKeys } from '../../../api/adminPushOps';
import { LineAreaChart } from '../../../components/charts/LineAreaChart';
import { Card, ErrorState, Skeleton, StatCard, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { dayRate, percent } from './lib';
import styles from './pushops.module.css';

interface DayRow {
  date: string;
  created: number;
  read: number;
  rate: number | null;
}

export function StatsTab() {
  const i18n = useI18n();
  const { t, td, formatNumber, formatDate } = i18n;
  const q = useQuery({ queryKey: pushOpsKeys.inbox(), queryFn: () => getNotificationStats(14) });
  const s = q.data;

  if (q.isError) {
    return <ErrorState onRetry={() => void q.refetch()} description={adminError(i18n, q.error, 'admin.p14.err')} />;
  }
  if (!s) {
    return <Skeleton width="100%" height="12em" />;
  }

  const rows: DayRow[] = s.series.map((d) => ({ ...d, rate: dayRate(d.created, d.read) }));
  const rate = percent(s.readRate);
  const fmtDay = (v: string | number) => formatDate(`${v}T12:00:00`, { day: 'numeric', month: 'short' });

  const dayCols: Column<DayRow>[] = [
    { key: 'date', header: t('admin.p14.stats.col.date'), render: (r) => formatDate(`${r.date}T12:00:00`) },
    { key: 'created', header: t('admin.p14.stats.col.created'), align: 'end', render: (r) => formatNumber(r.created) },
    { key: 'read', header: t('admin.p14.stats.col.read'), align: 'end', render: (r) => formatNumber(r.read) },
    {
      key: 'rate',
      header: t('admin.p14.stats.col.rate'),
      align: 'end',
      render: (r) => (r.rate === null ? '—' : `%${formatNumber(r.rate)}`),
    },
  ];
  const typeCols: Column<{ type: string; count: number }>[] = [
    { key: 'type', header: t('admin.p14.stats.col.type'), render: (r) => td(`admin.p14.stats.type.${r.type}`, r.type) },
    { key: 'count', header: t('admin.p14.stats.col.count'), align: 'end', render: (r) => formatNumber(r.count) },
  ];

  return (
    <div className={styles.stack}>
      <div className={styles.statGrid}>
        <StatCard title={t('admin.p14.stats.stat.created')} value={formatNumber(s.created)} hint={t('admin.p14.stats.stat.window', { n: s.days })} />
        <StatCard title={t('admin.p14.stats.stat.read')} value={formatNumber(s.read)} />
        <StatCard title={t('admin.p14.stats.stat.rate')} value={rate === null ? '—' : `%${formatNumber(rate)}`} />
        <StatCard title={t('admin.p14.stats.stat.total')} value={formatNumber(s.totalRows)} />
        <StatCard title={t('admin.p14.stats.stat.unread')} value={formatNumber(s.unreadRows)} />
      </div>
      <Callout tone="info">{t('admin.p14.stats.note')}</Callout>

      <Card title={t('admin.p14.stats.chart.title', { n: s.days })}>
        <LineAreaChart
          data={rows}
          xKey="date"
          formatX={fmtDay}
          series={[
            { key: 'created', label: t('admin.p14.stats.col.created') },
            { key: 'read', label: t('admin.p14.stats.col.read') },
          ]}
          ariaLabel={t('admin.p14.stats.chart.aria', { n: s.days })}
          emptyLabel={t('admin.p14.stats.empty')}
        />
        <Table caption={t('admin.p14.stats.table.days')} columns={dayCols} rows={rows} rowKey={(r) => r.date} />
      </Card>

      <Card title={t('admin.p14.stats.type.title')}>
        <Table
          caption={t('admin.p14.stats.table.types')}
          columns={typeCols}
          rows={s.byType}
          rowKey={(r) => r.type}
          empty={<p className={styles.hint}>{t('admin.p14.stats.empty')}</p>}
        />
      </Card>
    </div>
  );
}
