// Şişebilen log tabloları: boyut, tahmini satır, en eski kayıt, asgari saklama ve satır başına "Dışa aktar" / "Temizle".
// İşlem düğmeleri izne göre gizlenir (data.retention.export / .purge); asıl denetim sunucudadır.
import { useQuery } from '@tanstack/react-query';
import { getRetentionTables, retentionKeys, type RetentionTable } from '../../../api/dataRetention';
import { Badge, Button, Card, Table, type Column } from '../../../components/ui';
import { useCan } from '../../../auth/permissions';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes } from './format';
import styles from './DataRetention.module.css';

export function TablesPanel({
  onExport,
  onPurge,
}: {
  onExport: (t: RetentionTable) => void;
  onPurge: (t: RetentionTable) => void;
}) {
  const { t, formatNumber, formatDate } = useI18n();
  const canExport = useCan('data.retention.export');
  const canPurge = useCan('data.retention.purge');
  const q = useQuery({ queryKey: retentionKeys.tables, queryFn: getRetentionTables, staleTime: 30_000 });

  const columns: Column<RetentionTable>[] = [
    {
      key: 'name',
      header: t('admin.ds1.tables.col.table'),
      render: (r) => (
        <div className={styles.tableCell}>
          <strong>{r.label}</strong>
          <span className={styles.mono}>{r.name}</span>
          <span className={styles.muted}>{r.description}</span>
          <span className={styles.badges}>
            {r.personalData && <Badge tone="warning">{t('admin.ds1.tables.personal')}</Badge>}
            {!r.deletable && <Badge tone="info">{t('admin.ds1.tables.exportOnly')}</Badge>}
          </span>
        </div>
      ),
    },
    {
      key: 'rows',
      header: t('admin.ds1.tables.col.rows'),
      align: 'end',
      render: (r) => (r.estimatedRows === null ? t('admin.ds1.tables.unknown') : formatNumber(r.estimatedRows)),
    },
    { key: 'size', header: t('admin.ds1.tables.col.size'), align: 'end', render: (r) => formatBytes(r.sizeBytes) },
    {
      key: 'oldest',
      header: t('admin.ds1.tables.col.oldest'),
      render: (r) => (r.oldestAt ? formatDate(r.oldestAt) : t('admin.ds1.tables.unknown')),
    },
    {
      key: 'min',
      header: t('admin.ds1.tables.col.min'),
      render: (r) => t('admin.ds1.tables.minDays', { n: r.minRetentionDays }),
    },
  ];
  if (canExport || canPurge) {
    columns.push({
      key: 'actions',
      header: t('admin.ds1.tables.col.actions'),
      render: (r) => (
        <div className={styles.rowActions}>
          {canExport && (
            <Button size="sm" variant="secondary" onClick={() => onExport(r)} aria-label={`${t('admin.ds1.tables.export')}: ${r.name}`}>
              {t('admin.ds1.tables.export')}
            </Button>
          )}
          {canPurge && r.deletable && (
            <Button size="sm" variant="danger" onClick={() => onPurge(r)} aria-label={`${t('admin.ds1.tables.purge')}: ${r.name}`}>
              {t('admin.ds1.tables.purge')}
            </Button>
          )}
        </div>
      ),
    });
  }

  return (
    <Card title={t('admin.ds1.tables.title')}>
      <p className={styles.muted}>{t('admin.ds1.tables.intro')}</p>
      {!canExport && !canPurge && (
        <p className={styles.readOnly} data-testid="readonly-note">
          {t('admin.ds1.tables.readOnlyNote')}
        </p>
      )}
      <div className={styles.tableScroll}>
        <Table<RetentionTable>
          columns={columns}
          rows={q.data}
          rowKey={(r) => r.name}
          loading={q.isLoading}
          error={q.isError}
          onRetry={() => void q.refetch()}
          empty={t('admin.ds1.tables.empty')}
          caption={t('admin.ds1.tables.title')}
        />
      </div>
    </Card>
  );
}
