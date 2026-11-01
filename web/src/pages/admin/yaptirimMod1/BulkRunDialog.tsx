// Toplu işlem onayı: seçili kayıt sayısını, sonucu ve (gerekirse) işlem gerekçesini sorar; işlemi sunucuya TEK TEK uygular.
// Toplu uç olmayan yerlerde (itiraz, askı önerisi, ihlal affı, geri açma, kelime silme) karar akışını hızlandırır.
import { useState, type ReactNode } from 'react';
import { Button, Modal, useToast } from '../../../components/ui';
import { ReasonField } from '../../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import { runBatch, type BatchOutcome } from './queueLogic';

export interface BulkRunDialogProps<T> {
  open: boolean;
  onClose: () => void;
  title: string;
  /** Ne olacağını anlatan düz Türkçe açıklama (kaç kayıt, sonucu ne). */
  message: ReactNode;
  confirmLabel: string;
  danger?: boolean;
  /** İşlem gerekçesi (X-Admin-Reason) istensin mi. */
  requireReason?: boolean;
  /** Seçili kayıtlar; boşsa diyalog açılmaz. */
  items: readonly T[];
  /** Her kayıt için sunucu isteği; gerekçe `reason` ile gelir. */
  runOne: (item: T, reason: string) => Promise<unknown>;
  /** İşlem bitince (başarı, kısmi başarı ya da hız sınırı) çağrılır; üst bileşen listeyi yeniler ve seçimi temizler. */
  onDone: (outcome: BatchOutcome<T>) => void;
  concurrency?: number;
}

/** Toplu işlem sonucunu tek cümlelik bildirime çevirir. */
export function useBatchToast() {
  const i18n = useI18n();
  const gt = useGt();
  const toast = useToast();
  const { formatNumber } = i18n;
  return <T,>(o: BatchOutcome<T>) => {
    const ok = formatNumber(o.ok.length);
    if (o.rateLimited) {
      toast.error(gt('admin.mod1.batch.rate', { ok, skipped: formatNumber(o.skipped.length) }));
    } else if (o.failed.length > 0) {
      toast.error(gt('admin.mod1.batch.partial', { ok, failed: formatNumber(o.failed.length) }));
    } else {
      toast.success(gt('admin.mod1.batch.done', { ok }));
    }
  };
}

export function BulkRunDialog<T>({
  open,
  onClose,
  title,
  message,
  confirmLabel,
  danger,
  requireReason,
  items,
  runOne,
  onDone,
  concurrency = 3,
}: BulkRunDialogProps<T>) {
  const i18n = useI18n();
  const gt = useGt();
  const { t } = i18n;
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const blocked = busy || items.length === 0 || (!!requireReason && !isReasonValid(reason, ADMIN_REASON_MIN));

  async function go() {
    setBusy(true);
    try {
      const outcome = await runBatch(items, (it) => runOne(it, reason.trim()), concurrency);
      setReason('');
      onDone(outcome);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={open && items.length > 0}
      onClose={() => !busy && onClose()}
      title={title}
      size="sm"
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            {t('common.cancel')}
          </Button>
          <Button variant={danger ? 'danger' : 'primary'} loading={busy} disabled={blocked} onClick={() => void go()}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <p>{message}</p>
      <p className="sr-only" role="status">
        {busy ? gt('admin.mod1.batch.running', { n: i18n.formatNumber(items.length) }) : ''}
      </p>
      {requireReason && (
        <ReasonField
          value={reason}
          onChange={setReason}
          minLength={ADMIN_REASON_MIN}
          label={t('admin.wp02.actionReason.label')}
          disabled={busy}
          focusOnMount
        />
      )}
    </Modal>
  );
}
