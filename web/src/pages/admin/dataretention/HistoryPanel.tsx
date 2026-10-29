// Geçmiş: son dışa aktarma makbuzları ve silme (temizlik) kayıtları. Silme kayıtları silinemez; makbuzsuz silmeler
// "Makbuzsuz" rozetiyle öne çıkar.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { getPurges, getReceipts, retentionKeys, type Purge, type Receipt } from '../../../api/dataRetention';
import { Badge, Card, Table, Tabs, type Column, type Tone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes } from './format';
import styles from './DataRetention.module.css';

type TabId = 'receipts' | 'purges';

const RECEIPT_TONE: Record<Receipt['status'], Tone> = { COMPLETED: 'success', RUNNING: 'info', PARTIAL: 'warning', FAILED: 'danger' };
const PURGE_TONE: Record<Purge['status'], Tone> = { COMPLETED: 'success', RUNNING: 'info', FAILED: 'danger', INTERRUPTED: 'warning' };

export function HistoryPanel() {
  const { t, td, formatNumber, formatDateTime } = useI18n();
  const [tab, setTab] = useState<TabId>('receipts');
  const receipts = useQuery({ queryKey: retentionKeys.exports, queryFn: getReceipts, staleTime: 15_000 });
  const purges = useQuery({ queryKey: retentionKeys.purges, queryFn: getPurges, staleTime: 15_000 });

  const receiptCols: Column<Receipt>[] = [
    { key: 'id', header: t('admin.ds1.history.col.id'), render: (r) => `#${r.id}` },
    { key: 'table', header: t('admin.ds1.history.col.table'), render: (r) => <span className={styles.mono}>{r.table}</span> },
    { key: 'range', header: t('admin.ds1.history.col.range'), render: (r) => `${r.from} → ${r.to}` },
    { key: 'rows', header: t('admin.ds1.history.col.rows'), align: 'end', render: (r) => formatNumber(r.rowCount) },
    { key: 'size', header: t('admin.ds1.history.col.size'), align: 'end', render: (r) => formatBytes(r.byteCount) },
    {
      key: 'sha',
      header: t('admin.ds1.history.col.sha'),
      render: (r) => <span className={styles.mono}>{r.sha256 ? `${r.sha256.slice(0, 12)}…` : '—'}</span>,
    },
    {
      key: 'status',
      header: t('admin.ds1.history.col.status'),
      render: (r) => <Badge tone={RECEIPT_TONE[r.status]}>{td(`admin.ds1.receipt.status.${r.status}`, r.status)}</Badge>,
    },
    { key: 'admin', header: t('admin.ds1.history.col.admin'), render: (r) => r.adminEmail ?? '—' },
    { key: 'at', header: t('admin.ds1.history.col.at'), render: (r) => formatDateTime(r.createdAt) },
  ];

  const purgeCols: Column<Purge>[] = [
    { key: 'id', header: t('admin.ds1.history.col.id'), render: (r) => `#${r.id}` },
    { key: 'table', header: t('admin.ds1.history.col.table'), render: (r) => <span className={styles.mono}>{r.table}</span> },
    { key: 'range', header: t('admin.ds1.history.col.range'), render: (r) => `${r.from} → ${r.to}` },
    {
      key: 'rows',
      header: t('admin.ds1.history.col.rows'),
      align: 'end',
      render: (r) => formatNumber(r.deletedRows),
    },
    {
      key: 'status',
      header: t('admin.ds1.history.col.status'),
      render: (r) => (
        <span className={styles.badges}>
          <Badge tone={PURGE_TONE[r.status]}>{td(`admin.ds1.purgeStatus.${r.status}`, r.status)}</Badge>
          {r.forced ? (
            <Badge tone="danger">{t('admin.ds1.history.forced')}</Badge>
          ) : (
            r.receiptId !== null && <Badge tone="neutral">{t('admin.ds1.history.receiptRef', { id: r.receiptId })}</Badge>
          )}
        </span>
      ),
    },
    { key: 'reason', header: t('admin.ds1.history.col.reason'), render: (r) => r.reason },
    { key: 'admin', header: t('admin.ds1.history.col.admin'), render: (r) => r.adminEmail ?? '—' },
    { key: 'at', header: t('admin.ds1.history.col.at'), render: (r) => formatDateTime(r.startedAt) },
  ];

  return (
    <Card title={t('admin.ds1.history.title')}>
      <Tabs
        label={t('admin.ds1.history.tabs')}
        value={tab}
        onChange={(id) => setTab(id as TabId)}
        tabs={[
          { id: 'receipts', label: t('admin.ds1.history.tab.receipts') },
          { id: 'purges', label: t('admin.ds1.history.tab.purges') },
        ]}
      >
        <div className={styles.tableScroll}>
          {tab === 'receipts' ? (
            <Table<Receipt>
              columns={receiptCols}
              rows={receipts.data}
              rowKey={(r) => r.id}
              loading={receipts.isLoading}
              error={receipts.isError}
              onRetry={() => void receipts.refetch()}
              empty={t('admin.ds1.history.emptyReceipts')}
              caption={t('admin.ds1.history.tab.receipts')}
            />
          ) : (
            <Table<Purge>
              columns={purgeCols}
              rows={purges.data}
              rowKey={(r) => r.id}
              loading={purges.isLoading}
              error={purges.isError}
              onRetry={() => void purges.refetch()}
              empty={t('admin.ds1.history.emptyPurges')}
              caption={t('admin.ds1.history.tab.purges')}
            />
          )}
        </div>
      </Tabs>
    </Card>
  );
}
