// SAYFA: Veri saklama (/admin/data-retention) — depolama doluluğu, şişebilen log tabloları, makbuzlu dışa aktarma,
// onaylı temizlik ve geçmiş. Sistem altında. Yalnız Türkçe (yönetim paneli).
// API: GET /api/admin/system/storage; GET /api/admin/data-retention/{tables,exports,purges}, .../purge-preview;
//      POST /api/admin/data-retention/{exports,purges} (api/dataRetention.ts). Silme makbuzsuz yapılamaz.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { getStorage, isStorageAlert, retentionKeys, type RetentionTable } from '../../api/dataRetention';
import { Button, Card, ErrorState, PageHeader, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { Callout } from './campaigns/shared';
import { ExportDialog } from './dataretention/ExportDialog';
import { HistoryPanel } from './dataretention/HistoryPanel';
import { PurgeDialog } from './dataretention/PurgeDialog';
import { StorageCards } from './dataretention/StorageCards';
import { TablesPanel } from './dataretention/TablesPanel';
import styles from './dataretention/DataRetention.module.css';

const POLL_MS = 60_000;

interface PurgeTarget {
  table: RetentionTable;
  from?: string;
  to?: string;
}

export default function DataRetentionPage() {
  const { t, formatNumber, formatDateTime } = useI18n();
  usePageTitle(t('admin.ds1.title'));
  const [exporting, setExporting] = useState<RetentionTable | null>(null);
  const [purging, setPurging] = useState<PurgeTarget | null>(null);
  const storage = useQuery({
    queryKey: retentionKeys.storage,
    queryFn: getStorage,
    refetchInterval: POLL_MS,
    staleTime: 30_000,
  });
  const r = storage.data;

  return (
    <>
      <PageHeader title={t('admin.ds1.title')} description={t('admin.ds1.desc')} />
      <div className={styles.page}>
        <Card title={t('admin.ds1.storage.title')}>
          {storage.isLoading && <Skeleton height={120} />}
          {storage.isError && (
            <ErrorState title={t('admin.ds1.storage.error')} onRetry={() => void storage.refetch()} />
          )}
          {r && (
            <div className={styles.stack}>
              {isStorageAlert(r) && (
                <Callout tone={r.status === 'CRIT' ? 'danger' : 'warning'} role={r.status === 'CRIT' ? 'alert' : 'status'}>
                  <span data-testid="page-alert">
                    {t(r.status === 'CRIT' ? 'admin.ds1.storage.alert.crit' : 'admin.ds1.storage.alert.warn', {
                      pct: formatNumber(r.worstPercent ?? 0),
                      warn: r.warnPercent,
                      crit: r.critPercent,
                    })}{' '}
                    {t('admin.ds1.storage.alert.hint')}
                  </span>
                </Callout>
              )}
              <StorageCards report={r} />
              <p className={styles.muted}>{t('admin.ds1.storage.updated', { time: formatDateTime(r.generatedAt) })}</p>
              <div>
                <Button size="sm" variant="ghost" onClick={() => void storage.refetch()}>
                  ↻
                </Button>
              </div>
            </div>
          )}
        </Card>

        <TablesPanel onExport={setExporting} onPurge={(table) => setPurging({ table })} />
        <HistoryPanel />
      </div>

      <ExportDialog
        table={exporting}
        onClose={() => setExporting(null)}
        onPurge={(table, from, to) => {
          setExporting(null);
          setPurging({ table, from, to });
        }}
      />
      <PurgeDialog
        table={purging?.table ?? null}
        initialFrom={purging?.from}
        initialTo={purging?.to}
        onClose={() => setPurging(null)}
        onExport={(table) => {
          setPurging(null);
          setExporting(table);
        }}
      />
    </>
  );
}
