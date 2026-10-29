// Dışa aktarma: tarih aralığı + gerekçe → akışlı gzip CSV indirme → makbuz (satır sayısı, SHA-256). Makbuz silmeyi açar.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { exportTable, getReceipt, retentionKeys, type Receipt, type RetentionTable } from '../../../api/dataRetention';
import { Button, FormField, Input, Modal, ReasonField, Spinner, isReasonValid, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { ReceiptSummary } from './ReceiptSummary';
import { formatBytes, rangeValid, saveBlob, sha256Hex } from './format';
import styles from './DataRetention.module.css';

const REASON_MIN = 10;

export function ExportDialog({
  table,
  onClose,
  onPurge,
}: {
  table: RetentionTable | null;
  onClose: () => void;
  /** Dışa aktarma sonrası "bu aralığı temizlemeye geç". */
  onPurge: (table: RetentionTable, from: string, to: string) => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [receipt, setReceipt] = useState<Receipt | null>(null);
  const [verified, setVerified] = useState<boolean | null>(null);
  const inFlight = useRef(false);

  useEffect(() => {
    if (table) {
      setFrom('');
      setTo(table.maxTo);
      setReason('');
      setReceipt(null);
      setVerified(null);
      setBusy(false);
    }
  }, [table]);

  if (!table) return null;
  const valid = rangeValid(from, to, table.maxTo) && isReasonValid(reason, REASON_MIN);

  const run = async () => {
    if (inFlight.current || !valid) return;
    inFlight.current = true;
    setBusy(true);
    try {
      const res = await exportTable(table.name, from, to, reason.trim());
      saveBlob(res.blob, res.filename);
      let rec: Receipt | null = null;
      if (res.receiptId !== null) {
        rec = await getReceipt(res.receiptId);
        setReceipt(rec);
        const local = await sha256Hex(res.blob);
        setVerified(local === null || !rec.sha256 ? null : local === rec.sha256);
      }
      await qc.invalidateQueries({ queryKey: retentionKeys.exports });
      await qc.invalidateQueries({ queryKey: retentionKeys.all });
    } catch (e) {
      toast.error(adminError(i18n, e, 'admin.ds1.err', 'admin.err'));
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  };

  const done = receipt !== null;
  return (
    <Modal
      open
      onClose={() => !busy && onClose()}
      title={t('admin.ds1.export.title', { table: table.name })}
      size="md"
      footer={
        done ? (
          <>
            {receipt.status === 'COMPLETED' && table.deletable && (
              <Button variant="danger" onClick={() => onPurge(table, from, to)}>
                {t('admin.ds1.export.goPurge')}
              </Button>
            )}
            <Button variant="secondary" onClick={onClose}>
              {t('admin.ds1.export.close')}
            </Button>
          </>
        ) : (
          <>
            <Button variant="secondary" onClick={onClose} disabled={busy}>
              {t('common.cancel')}
            </Button>
            <Button onClick={run} disabled={!valid || busy} loading={busy}>
              {t('admin.ds1.export.start')}
            </Button>
          </>
        )
      }
    >
      <div className={styles.dialogStack}>
        {!done && (
          <>
            <p className={styles.muted}>{t('admin.ds1.export.intro')}</p>
            {table.personalData && (
              <Callout tone="warning" role="status">
                {t('admin.ds1.export.personal')}
              </Callout>
            )}
            <div className={styles.dateRow}>
              <FormField label={t('admin.ds1.export.from')}>
                <Input type="date" value={from} max={to || table.maxTo} onChange={(e) => setFrom(e.target.value)} disabled={busy} />
              </FormField>
              <FormField
                label={t('admin.ds1.export.to')}
                hint={t('admin.ds1.export.toHint', { max: table.maxTo, n: table.minRetentionDays })}
              >
                <Input type="date" value={to} max={table.maxTo} onChange={(e) => setTo(e.target.value)} disabled={busy} />
              </FormField>
            </div>
            {!rangeValid(from, to, table.maxTo) && <p className={styles.errorText}>{t('admin.ds1.export.invalidRange')}</p>}
            <ReasonField
              value={reason}
              onChange={setReason}
              minLength={REASON_MIN}
              label={t('admin.ds1.export.reason')}
              disabled={busy}
            />
            {busy && (
              <p className={styles.progressText} role="status">
                <Spinner size="sm" /> {t('admin.ds1.export.running')}
              </p>
            )}
          </>
        )}
        {done && (
          <>
            <Callout tone={receipt.status === 'COMPLETED' ? 'success' : 'warning'} title={t('admin.ds1.export.done')} role="status">
              {receipt.status === 'PARTIAL' ? t('admin.ds1.export.partial') : formatBytes(receipt.byteCount)}
            </Callout>
            {verified === true && <p className={styles.okText}>{t('admin.ds1.export.verified')}</p>}
            {verified === false && (
              <Callout tone="danger" role="alert">
                {t('admin.ds1.export.mismatch')}
              </Callout>
            )}
            <ReceiptSummary receipt={receipt} />
          </>
        )}
      </div>
    </Modal>
  );
}
