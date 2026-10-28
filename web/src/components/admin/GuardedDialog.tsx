import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { FormField, Textarea } from '../ui/Fields';
import { ConfirmDialog } from '../ui/Overlay';
import { BulkImpactNotice, isBulkConfirmed } from './guard/BulkImpactNotice';
import { ReasonField, type ReasonTemplateOption } from './guard/ReasonField';
import { TypeToConfirm } from './guard/TypeToConfirm';
import {
  DEFAULT_BULK_THRESHOLD,
  DEFAULT_REASON_MIN,
  REASON_MAX,
  bulkNeedsConfirm,
  isReasonValid,
  matchesTarget,
} from './guard/match';
import { useGuardedMutation } from './guard/useGuardedMutation';
import type { GuardedActionProps } from './guard/GuardedAction';
import styles from './guard/guard.module.css';

export interface GuardedDialogProps
  extends Omit<
    GuardedActionProps,
    'children' | 'variant' | 'size' | 'leftIcon' | 'fullWidth' | 'disabled' | 'className'
  > {
  open: boolean;
  onClose: () => void;
  /** Sebep alanı gösterilsin ama doldurmak zorunlu olmasın (boş geçilebilir; yazılırsa gönderilir). */
  optionalReason?: boolean;
  /** Mesaj ile alanlar arasına konan ek içerik (fark önizlemesi, kapsam özeti...). */
  extra?: ReactNode;
}

/**
 * `GuardedAction`ın denetlenen (controlled) kardeşi: tetikleyici düğme sayfada zaten vardır (örn. ayar satırının
 * "Kaydet" düğmesi); onay diyaloğunu `open` ile açarsınız. Aynı kurallar: koşullar sağlanmadan onay düğmesi kapalı,
 * iş sürerken kapanmaz, ikinci tetikleme yok sayılır, her açılışta yeni `Idempotency-Key`.
 */
export function GuardedDialog({
  open,
  onClose,
  onConfirm,
  title,
  message,
  consequence,
  irreversible,
  danger,
  confirmLabel,
  cancelLabel,
  requireReason,
  optionalReason,
  reasonMinLength = DEFAULT_REASON_MIN,
  reasonLabel,
  reasonTemplates,
  typeToConfirm,
  impact,
  successMessage,
  errorMessage,
  invalidateKeys,
  onSuccess,
  extra,
}: GuardedDialogProps & { reasonTemplates?: ReasonTemplateOption[] }) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [typed, setTyped] = useState('');
  const [bulkTyped, setBulkTyped] = useState('');

  const guarded = useGuardedMutation<unknown, string>({
    mutationFn: (r, ctx) => onConfirm({ reason: r, idempotencyKey: ctx.idempotencyKey }),
    successMessage,
    errorMessage,
    invalidateKeys,
  });
  const { run, renewKey, isPending } = guarded;

  // Her açılış yeni bir niyettir: alanları sıfırla, yeni anahtar üret.
  useEffect(() => {
    if (!open) return;
    renewKey();
    setReason('');
    setTyped('');
    setBulkTyped('');
  }, [open, renewKey]);

  const reasonOk = !requireReason || isReasonValid(reason, reasonMinLength);
  const typedOk = !typeToConfirm || matchesTarget(typed, typeToConfirm);
  const bulkOk = !impact || isBulkConfirmed(impact.count, impact.threshold ?? DEFAULT_BULK_THRESHOLD, bulkTyped);
  const canConfirm = reasonOk && typedOk && bulkOk;
  const bulkTyping = Boolean(impact && bulkNeedsConfirm(impact.count, impact.threshold ?? DEFAULT_BULK_THRESHOLD));
  const focusInContent = Boolean(requireReason || optionalReason || typeToConfirm || bulkTyping);

  const close = useCallback(() => {
    if (!isPending) onClose(); // iş sürerken kapanmaz
  }, [isPending, onClose]);

  const submit = useCallback(async () => {
    if (!canConfirm) return;
    const res = await run(reason.trim());
    if (res.ok) {
      onClose();
      onSuccess?.();
    }
  }, [canConfirm, run, reason, onClose, onSuccess]);

  const reasonFirst = Boolean(requireReason);
  const typeFirst = !reasonFirst && Boolean(typeToConfirm);

  return (
    <ConfirmDialog
      open={open}
      onClose={close}
      onConfirm={() => void submit()}
      title={title}
      message={message}
      consequence={consequence}
      irreversible={irreversible}
      danger={danger}
      confirmLabel={confirmLabel}
      cancelLabel={cancelLabel}
      loading={isPending}
      confirmDisabled={!canConfirm}
      role={danger ? 'alertdialog' : 'dialog'}
      initialFocus={focusInContent ? 'content' : danger ? 'cancel' : 'confirm'}
    >
      {extra}
      {(requireReason || optionalReason || typeToConfirm || impact) && (
        <div className={styles.fields}>
          {impact && (
            <BulkImpactNotice
              count={impact.count}
              threshold={impact.threshold}
              noun={impact.noun}
              value={bulkTyped}
              onChange={(v) => setBulkTyped(v)}
              focusOnMount={!reasonFirst && !typeFirst}
            />
          )}
          {requireReason && (
            <ReasonField
              value={reason}
              onChange={setReason}
              minLength={reasonMinLength}
              label={reasonLabel}
              templates={reasonTemplates}
              focusOnMount={reasonFirst}
              disabled={isPending}
            />
          )}
          {!requireReason && optionalReason && (
            <FormField label={reasonLabel ?? t('admin.p05.reason.optional')} hint={t('admin.p05.reason.optionalHint')}>
              <Textarea
                rows={3}
                value={reason}
                maxLength={REASON_MAX}
                disabled={isPending}
                data-autofocus
                onChange={(e) => setReason(e.target.value)}
              />
            </FormField>
          )}
          {typeToConfirm && (
            <TypeToConfirm
              target={typeToConfirm}
              value={typed}
              onChange={(v) => setTyped(v)}
              focusOnMount={typeFirst}
              disabled={isPending}
              onEnter={() => void submit()}
            />
          )}
        </div>
      )}
    </ConfirmDialog>
  );
}
