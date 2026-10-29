// Temizlik: aralık seç → önizleme (silinecek satır, tahmini boyut, makbuz var mı) → gerekçe + tablo adını yazarak onay →
// arka planda parçalı silme (ilerleme çubuğu). Makbuz yoksa silme KAPALIDIR; "makbuzsuz sil" yalnız FULL yöneticiye ve
// ayrıca en az 20 karakterlik gerekçeyle açılır. Yıkıcı tüm eylemler kırmızı ve açıklamalıdır.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import {
  getPurge,
  getPurgePreview,
  retentionKeys,
  startPurge,
  type Purge,
  type RetentionTable,
} from '../../../api/dataRetention';
import {
  Button,
  Checkbox,
  FormField,
  Input,
  Modal,
  ReasonField,
  Spinner,
  TypeToConfirm,
  isReasonValid,
  matchesTarget,
  useGuardedMutation,
} from '../../../components/ui';
import { useCan } from '../../../auth/permissions';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { ReceiptSummary } from './ReceiptSummary';
import { formatBytes, rangeValid } from './format';
import styles from './DataRetention.module.css';

const REASON_MIN = 10;
const FORCE_REASON_MIN = 20;

export function PurgeDialog({
  table,
  initialFrom,
  initialTo,
  onClose,
  onExport,
}: {
  table: RetentionTable | null;
  initialFrom?: string;
  initialTo?: string;
  onClose: () => void;
  /** Makbuz yokken "Önce dışa aktar". */
  onExport: (table: RetentionTable) => void;
}) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const qc = useQueryClient();
  const isFull = useCan('admin.full');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [reason, setReason] = useState('');
  const [typed, setTyped] = useState('');
  const [force, setForce] = useState(false);
  const [purgeId, setPurgeId] = useState<number | null>(null);

  useEffect(() => {
    if (table) {
      setFrom(initialFrom ?? '');
      setTo(initialTo || table.maxTo);
      setReason('');
      setTyped('');
      setForce(false);
      setPurgeId(null);
    }
  }, [table, initialFrom, initialTo]);

  const rangeOk = table ? rangeValid(from, to, table.maxTo) : false;
  const preview = useQuery({
    queryKey: retentionKeys.preview(table?.name ?? '', from, to),
    queryFn: () => getPurgePreview(table!.name, from, to),
    enabled: Boolean(table) && rangeOk && purgeId === null,
    retry: false,
  });

  const guarded = useGuardedMutation<Purge, void>({
    mutationFn: (_v, ctx) =>
      startPurge(
        {
          table: table!.name,
          from: from || undefined,
          to,
          confirmTable: typed.trim(),
          receiptId: force ? undefined : preview.data?.receipt?.id,
          forceWithoutExport: force || undefined,
          reason: reason.trim(),
        },
        { reason: reason.trim(), idempotencyKey: ctx.idempotencyKey },
      ),
    successMessage: false,
    errorMessage: (e) => adminError(i18n, e, 'admin.ds1.err', 'admin.err'),
    onSuccess: (p) => setPurgeId(p.id),
  });

  // ilerleme: çalışırken 1,5 sn'de bir
  const progress = useQuery({
    queryKey: retentionKeys.purge(purgeId ?? 0),
    queryFn: () => getPurge(purgeId!),
    enabled: purgeId !== null,
    refetchInterval: (q) => (q.state.data && q.state.data.status !== 'RUNNING' ? false : 1500),
  });
  const running = purgeId !== null && (!progress.data || progress.data.status === 'RUNNING');
  useEffect(() => {
    if (progress.data && progress.data.status !== 'RUNNING') {
      void qc.invalidateQueries({ queryKey: retentionKeys.all });
    }
  }, [progress.data, qc]);

  if (!table) return null;
  const pv = preview.data;
  const noReceipt = Boolean(pv) && !pv!.receipt;
  const stale = Boolean(pv?.receiptStale);
  const receiptOk = Boolean(pv?.receipt) && !stale;
  // Makbuz yoksa/eskiyse: yalnız FULL "makbuzsuz sil" kutusunu işaretleyerek ilerleyebilir
  const forceAvailable = isFull && (noReceipt || stale) && table.deletable && (pv?.rowsInRange ?? 0) > 0;
  const reasonMin = force ? FORCE_REASON_MIN : REASON_MIN;
  const canSubmit =
    table.deletable &&
    rangeOk &&
    Boolean(pv) &&
    (pv?.rowsInRange ?? 0) > 0 &&
    (receiptOk || force) &&
    isReasonValid(reason, reasonMin) &&
    matchesTarget(typed, table.name);

  const submit = async () => {
    if (!canSubmit) return;
    await guarded.run();
  };

  const finished = progress.data && progress.data.status !== 'RUNNING';
  const closeSafe = () => {
    if (!guarded.isPending) onClose();
  };

  return (
    <Modal
      open
      onClose={closeSafe}
      role="alertdialog"
      size="md"
      title={t('admin.ds1.purge.title', { table: table.name })}
      footer={
        purgeId !== null ? (
          <Button variant="secondary" onClick={onClose}>
            {t('admin.ds1.purge.close')}
          </Button>
        ) : (
          <>
            <Button variant="secondary" onClick={onClose} disabled={guarded.isPending}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" onClick={submit} disabled={!canSubmit || guarded.isPending} loading={guarded.isPending}>
              {t('admin.ds1.purge.confirmLabel')}
            </Button>
          </>
        )
      }
    >
      <div className={styles.dialogStack}>
        {purgeId === null && (
          <>
            <Callout tone="danger" title={t('admin.ds1.purge.danger.title')}>
              {t('admin.ds1.purge.danger.body')}
            </Callout>
            <p className={styles.muted}>{t('admin.ds1.purge.intro', { n: table.minRetentionDays })}</p>
            {!table.deletable && (
              <Callout tone="warning" role="status">
                {table.notDeletableReason ?? t('admin.ds1.purge.notDeletable')}
              </Callout>
            )}
            <div className={styles.dateRow}>
              <FormField label={t('admin.ds1.purge.from')}>
                <Input type="date" value={from} max={to || table.maxTo} onChange={(e) => setFrom(e.target.value)} />
              </FormField>
              <FormField
                label={t('admin.ds1.purge.to')}
                hint={t('admin.ds1.export.toHint', { max: table.maxTo, n: table.minRetentionDays })}
              >
                <Input type="date" value={to} max={table.maxTo} onChange={(e) => setTo(e.target.value)} />
              </FormField>
            </div>
            {!rangeOk && <p className={styles.errorText}>{t('admin.ds1.export.invalidRange')}</p>}

            {rangeOk && preview.isLoading && (
              <p className={styles.progressText} role="status">
                <Spinner size="sm" /> {t('admin.ds1.purge.preview.loading')}
              </p>
            )}
            {rangeOk && preview.isError && <p className={styles.errorText}>{t('admin.ds1.purge.preview.error')}</p>}

            {pv && (
              <section className={styles.previewBox} data-testid="purge-preview">
                <dl className={styles.dl}>
                  <dt>{t('admin.ds1.purge.preview.rows')}</dt>
                  <dd data-testid="preview-rows">
                    {pv.capped
                      ? t('admin.ds1.purge.preview.capped', { n: formatNumber(pv.rowsInRange) })
                      : formatNumber(pv.rowsInRange)}
                  </dd>
                  <dt>{t('admin.ds1.purge.preview.bytes')}</dt>
                  <dd>{formatBytes(pv.estimatedBytes)}</dd>
                </dl>
                {pv.rowsInRange === 0 && <p className={styles.muted}>{t('admin.ds1.purge.nothing')}</p>}
              </section>
            )}

            {pv && receiptOk && pv.receipt && (
              <>
                <p className={styles.okText} data-testid="receipt-ok">
                  {t('admin.ds1.purge.receipt.ok', { id: pv.receipt.id, rows: formatNumber(pv.receipt.rowCount) })}
                </p>
                <ReceiptSummary receipt={pv.receipt} />
              </>
            )}

            {pv && (noReceipt || stale) && (
              <Callout
                tone="danger"
                role="alert"
                title={noReceipt ? t('admin.ds1.purge.receipt.none.title') : t('admin.ds1.purge.receipt.stale.title')}
              >
                {noReceipt ? t('admin.ds1.purge.receipt.none.body') : t('admin.ds1.purge.receipt.stale.body')}
                <div className={styles.inlineActions}>
                  <Button size="sm" onClick={() => onExport(table)}>
                    {t('admin.ds1.purge.exportFirst')}
                  </Button>
                </div>
              </Callout>
            )}

            {forceAvailable && (
              <div className={styles.forceBox}>
                <Checkbox
                  checked={force}
                  onChange={(e) => setForce(e.target.checked)}
                  label={t('admin.ds1.purge.force.label')}
                />
                <p className={styles.errorText}>{t('admin.ds1.purge.force.hint')}</p>
              </div>
            )}

            {pv && (receiptOk || force) && pv.rowsInRange > 0 && (
              <>
                <ReasonField
                  value={reason}
                  onChange={setReason}
                  minLength={reasonMin}
                  label={t('admin.ds1.purge.reason')}
                />
                <TypeToConfirm
                  target={table.name}
                  value={typed}
                  onChange={(v) => setTyped(v)}
                  label={t('admin.ds1.purge.confirmTable')}
                  onEnter={submit}
                />
              </>
            )}
          </>
        )}

        {purgeId !== null && (
          <PurgeProgress purge={progress.data} running={running} finished={Boolean(finished)} fallbackEst={preview.data?.rowsInRange ?? 0} />
        )}
      </div>
    </Modal>
  );
}

function PurgeProgress({
  purge,
  running,
  finished,
  fallbackEst,
}: {
  purge: Purge | undefined;
  running: boolean;
  finished: boolean;
  fallbackEst: number;
}) {
  const { t, formatNumber } = useI18n();
  const est = Math.max(purge?.estRows ?? fallbackEst, 1);
  const deleted = purge?.deletedRows ?? 0;
  const pct = finished && purge?.status === 'COMPLETED' ? 100 : Math.min(99, Math.round((deleted / est) * 100));
  return (
    <div data-testid="purge-progress" className={styles.dialogStack}>
      <div
        className={styles.bar}
        role="progressbar"
        aria-label={t('admin.ds1.purge.progress.label')}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
        data-status={purge?.status === 'FAILED' || purge?.status === 'INTERRUPTED' ? 'CRIT' : 'OK'}
      >
        <div
          className={styles.barFill}
          style={{ inlineSize: `${pct}%` }}
          data-status={purge?.status === 'FAILED' || purge?.status === 'INTERRUPTED' ? 'CRIT' : 'OK'}
        />
      </div>
      {running && (
        <p className={styles.progressText} role="status">
          <Spinner size="sm" />{' '}
          {purge
            ? t('admin.ds1.purge.progress', { deleted: formatNumber(deleted), est: formatNumber(est) })
            : t('admin.ds1.purge.starting')}
        </p>
      )}
      {purge?.status === 'COMPLETED' && (
        <>
          <Callout tone="success" role="status">
            {t('admin.ds1.purge.done', { deleted: formatNumber(deleted) })}
          </Callout>
          {purge.vacuumRecommended && <p className={styles.muted}>{t('admin.ds1.purge.vacuum')}</p>}
        </>
      )}
      {purge?.status === 'FAILED' && (
        <Callout tone="danger" role="alert">
          {t('admin.ds1.purge.failed', { error: purge.error ?? '—' })}
        </Callout>
      )}
      {purge?.status === 'INTERRUPTED' && (
        <Callout tone="warning" role="alert">
          {t('admin.ds1.purge.interrupted', { deleted: formatNumber(deleted) })}
        </Callout>
      )}
    </div>
  );
}
