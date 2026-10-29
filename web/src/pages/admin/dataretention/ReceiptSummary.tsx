// Makbuz özeti (dışa aktarma sonrası ve silme önizlemesinde): aralık, satır, boyut, SHA-256, yönetici, zaman.
import type { Receipt } from '../../../api/dataRetention';
import { CopyButton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes } from './format';
import styles from './DataRetention.module.css';

export function ReceiptSummary({ receipt }: { receipt: Receipt }) {
  const { t, td, formatNumber, formatDateTime } = useI18n();
  return (
    <section className={styles.receipt} aria-label={t('admin.ds1.receipt.title', { id: receipt.id })} data-testid="receipt">
      <h3 className={styles.cardTitle}>{t('admin.ds1.receipt.title', { id: receipt.id })}</h3>
      <dl className={styles.dl}>
        <dt>{t('admin.ds1.receipt.range')}</dt>
        <dd>
          {receipt.from} → {receipt.to}
        </dd>
        <dt>{t('admin.ds1.receipt.rows')}</dt>
        <dd>{formatNumber(receipt.rowCount)}</dd>
        <dt>{t('admin.ds1.receipt.bytes')}</dt>
        <dd>{formatBytes(receipt.byteCount)}</dd>
        <dt>{t('admin.ds1.receipt.sha')}</dt>
        <dd className={styles.mono} data-testid="receipt-sha">
          {receipt.sha256 ?? '—'}
          {receipt.sha256 && <CopyButton value={receipt.sha256} />}
        </dd>
        <dt>{t('admin.ds1.receipt.admin')}</dt>
        <dd>{receipt.adminEmail ?? '—'}</dd>
        <dt>{t('admin.ds1.receipt.at')}</dt>
        <dd>{formatDateTime(receipt.finishedAt ?? receipt.createdAt)}</dd>
        <dt>{t('admin.ds1.history.col.status')}</dt>
        <dd>{td(`admin.ds1.receipt.status.${receipt.status}`, receipt.status)}</dd>
      </dl>
    </section>
  );
}
