import { useCallback, useState, type ReactNode } from 'react';
import type { QueryKey } from '@tanstack/react-query';
import { useCan } from '../../../auth/permissions';
import { useI18n } from '../../../i18n/I18nProvider';
import { Button, type ButtonProps } from '../../ui/Button';
import { Tooltip } from '../../ui/Tooltip';
import { ConfirmDialog } from '../../ui/Overlay';
import { BulkImpactNotice, isBulkConfirmed } from './BulkImpactNotice';
import { ReasonField, type ReasonTemplateOption } from './ReasonField';
import { TypeToConfirm } from './TypeToConfirm';
import {
  DEFAULT_BULK_THRESHOLD,
  DEFAULT_REASON_MIN,
  bulkNeedsConfirm,
  isReasonValid,
  matchesTarget,
} from './match';
import { useGuardedMutation } from './useGuardedMutation';
import styles from './guard.module.css';

export interface GuardedActionContext {
  /** Girilen sebep (requireReason yoksa boş metin). */
  reason: string;
  /** Bu onay diyaloğuna ait `Idempotency-Key`; isteğe `idempotencyHeaders(key)` ile ekleyin. */
  idempotencyKey: string;
}

export interface GuardedActionProps {
  /** Düğme etiketi. */
  children: ReactNode;
  /** Onaylanınca çalışır; hata fırlatırsa toast gösterilir ve diyalog açık kalır. */
  onConfirm: (ctx: GuardedActionContext) => Promise<unknown>;
  /** Diyalog başlığı. */
  title: string;
  message?: ReactNode;
  /** "Ne olacak" metni. */
  consequence?: ReactNode;
  /** true: kırmızı "geri alınamaz" satırı; false: "geri alınabilir" satırı; verilmezse satır yok. */
  irreversible?: boolean;
  /** Yıkıcı eylem: kırmızı düğme, role="alertdialog", ilk odak Vazgeç (alan yoksa). */
  danger?: boolean;
  confirmLabel?: string;
  cancelLabel?: string;
  /** Sebep zorunlu olsun. */
  requireReason?: boolean;
  reasonMinLength?: number;
  reasonLabel?: string;
  reasonTemplates?: ReasonTemplateOption[];
  /** Bu metni (ad, e-posta, "SİL"...) yazdırır. */
  typeToConfirm?: string;
  /** Toplu işlem etkisi: eşik aşılırsa etkilenen sayıyı yazdırır. */
  impact?: { count: number; threshold?: number; noun?: string };
  successMessage?: string | false;
  errorMessage?: (error: unknown) => string;
  invalidateKeys?: QueryKey[];
  onSuccess?: () => void;
  /** Tetikleyici düğme görünümü. */
  variant?: ButtonProps['variant'];
  size?: ButtonProps['size'];
  leftIcon?: ReactNode;
  fullWidth?: boolean;
  disabled?: boolean;
  className?: string;
  /**
   * P16: gereken yönetici izni (örn. 'users.delete'). Yetkisizse düğme devre dışı kalır ve açıklama ipucu gösterir.
   * UI gizlemesi güvenlik değildir; asıl denetim sunucudadır (403 ADMIN_PERMISSION_DENIED).
   */
  permission?: string;
}

/**
 * Tek bileşende: düğme + onay diyaloğu + (isteğe bağlı) sebep + (isteğe bağlı) yazarak onay + toplu etki
 * şeridi + `useGuardedMutation` (çift tetiklemeye karşı kilit, Idempotency-Key, tek tip toast).
 */
export function GuardedAction({
  children,
  onConfirm,
  title,
  message,
  consequence,
  irreversible,
  danger,
  confirmLabel,
  cancelLabel,
  requireReason,
  reasonMinLength = DEFAULT_REASON_MIN,
  reasonLabel,
  reasonTemplates,
  typeToConfirm,
  impact,
  successMessage,
  errorMessage,
  invalidateKeys,
  onSuccess,
  variant,
  size,
  leftIcon,
  fullWidth,
  disabled,
  className,
  permission,
}: GuardedActionProps) {
  const { t } = useI18n();
  const allowed = useCan(permission);
  const [open, setOpen] = useState(false);
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

  const reasonOk = !requireReason || isReasonValid(reason, reasonMinLength);
  const typedOk = !typeToConfirm || matchesTarget(typed, typeToConfirm);
  const bulkOk = !impact || isBulkConfirmed(impact.count, impact.threshold ?? DEFAULT_BULK_THRESHOLD, bulkTyped);
  const canConfirm = reasonOk && typedOk && bulkOk;
  const bulkTyping = Boolean(impact && bulkNeedsConfirm(impact.count, impact.threshold ?? DEFAULT_BULK_THRESHOLD));
  const hasFields = Boolean(requireReason || typeToConfirm || impact);
  const focusInContent = Boolean(requireReason || typeToConfirm || bulkTyping);

  const openDialog = () => {
    renewKey(); // her onay diyaloğu açılışı yeni bir niyettir
    setReason('');
    setTyped('');
    setBulkTyped('');
    setOpen(true);
  };
  const close = useCallback(() => {
    if (!isPending) setOpen(false); // iş sürerken kapanmaz
  }, [isPending]);

  const submit = useCallback(async () => {
    if (!canConfirm) return;
    const res = await run(reason.trim());
    if (res.ok) {
      setOpen(false);
      onSuccess?.();
    }
  }, [canConfirm, run, reason, onSuccess]);

  // Alan sırası: sebep -> yazarak onay -> toplu etki; ilk alan odak alır.
  const reasonFirst = Boolean(requireReason);
  const typeFirst = !reasonFirst && Boolean(typeToConfirm);

  return (
    <>
      {allowed ? (
        <Button
          variant={variant ?? (danger ? 'danger' : 'primary')}
          size={size}
          leftIcon={leftIcon}
          fullWidth={fullWidth}
          disabled={disabled}
          className={className}
          onClick={openDialog}
        >
          {children}
        </Button>
      ) : (
        <Tooltip text={t('admin.p16.noPermission', { perm: permission ?? '' })}>
          <Button
            variant={variant ?? (danger ? 'danger' : 'primary')}
            size={size}
            leftIcon={leftIcon}
            fullWidth={fullWidth}
            disabled
            className={className}
          >
            {children}
          </Button>
        </Tooltip>
      )}
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
        {hasFields && (
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
    </>
  );
}
