// Cihazlar sekmesi: GET /api/admin/push/devices/summary (yalnız toplu sayılar; token/kullanıcı yok).
import { useQuery } from '@tanstack/react-query';
import { getDeviceSummary, pushOpsKeys } from '../../../api/adminPushOps';
import { BarChart } from '../../../components/charts/BarChart';
import { DonutChart } from '../../../components/charts/DonutChart';
import { Card, EmptyState, ErrorState, Skeleton, StatCard, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { PLATFORM_ORDER } from './lib';
import styles from './pushops.module.css';

interface PlatformRow {
  key: string;
  label: string;
  count: number;
  share: number;
}

export function DevicesTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const q = useQuery({ queryKey: pushOpsKeys.devices(), queryFn: getDeviceSummary });
  const d = q.data;

  if (q.isError) {
    return <ErrorState onRetry={() => void q.refetch()} description={adminError(i18n, q.error, 'admin.p14.err')} />;
  }
  if (!d) {
    return <Skeleton width="100%" height="12em" />;
  }

  const total = PLATFORM_ORDER.reduce((s, k) => s + (d.byPlatform[k] ?? 0), 0);
  const rows: PlatformRow[] = PLATFORM_ORDER.map((k) => ({
    key: k,
    label: t(`admin.p14.devices.platform.${k}`),
    count: d.byPlatform[k] ?? 0,
    share: total > 0 ? Math.round(((d.byPlatform[k] ?? 0) / total) * 1000) / 10 : 0,
  }));
  const pie = rows.filter((r) => r.count > 0).map((r) => ({ name: r.label, value: r.count }));
  const versions = d.byAppVersion.map((v) => ({
    version: v.version === 'unknown' ? t('admin.p14.devices.version.unknown') : v.version,
    count: v.count,
  }));

  const platformCols: Column<PlatformRow>[] = [
    { key: 'label', header: t('admin.p14.devices.col.platform'), render: (r) => r.label },
    { key: 'count', header: t('admin.p14.devices.col.count'), align: 'end', render: (r) => formatNumber(r.count) },
    { key: 'share', header: t('admin.p14.devices.col.share'), align: 'end', render: (r) => `%${formatNumber(r.share)}` },
  ];
  const versionCols: Column<(typeof versions)[number]>[] = [
    { key: 'version', header: t('admin.p14.devices.col.version'), render: (r) => <span className="ltr">{r.version}</span> },
    { key: 'count', header: t('admin.p14.devices.col.count'), align: 'end', render: (r) => formatNumber(r.count) },
  ];

  return (
    <div className={styles.stack}>
      <Callout tone="info">{t('admin.p14.devices.aggregateNote')}</Callout>
      <div className={styles.statGrid}>
        <StatCard title={t('admin.p14.devices.stat.total')} value={formatNumber(d.totalTokens)} />
        <StatCard title={t('admin.p14.devices.stat.users')} value={formatNumber(d.usersWithDevice)} />
        <StatCard title={t('admin.p14.devices.stat.active7')} value={formatNumber(d.activeLast7d)} />
        <StatCard title={t('admin.p14.devices.stat.stale30')} value={formatNumber(d.staleOver30d)} hint={t('admin.p14.devices.stat.staleHint')} invertTone />
      </div>

      <div className={styles.twoCol}>
        <Card title={t('admin.p14.devices.platform.title')}>
          <DonutChart
            data={pie}
            ariaLabel={t('admin.p14.devices.platform.chart')}
            emptyLabel={t('admin.p14.devices.empty')}
          />
          <Table
            caption={t('admin.p14.devices.platform.table')}
            columns={platformCols}
            rows={rows}
            rowKey={(r) => r.key}
          />
        </Card>
        <Card title={t('admin.p14.devices.version.title')}>
          {versions.length > 0 ? (
            <>
              <BarChart
                data={versions}
                xKey="version"
                layout="horizontal"
                height={Math.max(160, versions.length * 34)}
                series={[{ key: 'count', label: t('admin.p14.devices.col.count') }]}
                ariaLabel={t('admin.p14.devices.version.chart')}
              />
              <Table
                caption={t('admin.p14.devices.version.table')}
                columns={versionCols}
                rows={versions}
                rowKey={(r) => r.version}
              />
            </>
          ) : (
            <EmptyState icon="info" title={t('admin.p14.devices.empty')} compact />
          )}
        </Card>
      </div>
    </div>
  );
}
