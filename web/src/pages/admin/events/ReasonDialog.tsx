import { useState } from 'react';
import { Button, FormField, Modal, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { counterTone } from '../campaigns/lib';
import { CharCounter } from '../campaigns/shared';
import { REASON_MAX, reasonError, type ReasonAction } from './lib';

/** Gizle / geri aç / iptal / sil: zorunlu sebep (≤300) isteyen onay penceresi. */
export function ReasonDialog({
  action,
  name,
  loading,
  error,
  onClose,
  onConfirm,
}: {
  action: ReasonAction;
  name: string;
  loading: boolean;
  error?: string | null;
  onClose: () => void;
  onConfirm: (reason: string) => void;
}) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [touched, setTouched] = useState(false);
  const err = reasonError(reason);
  const danger = action === 'cancel' || action === 'delete';
  return (
    <Modal
      open
      onClose={loading ? () => undefined : onClose}
      size="sm"
      title={t(`admin.events.dialog.title.${action}`, { name })}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={loading}>
            {t('common.cancel')}
          </Button>
          <Button
            variant={danger ? 'danger' : 'primary'}
            loading={loading}
            data-testid="reason-confirm"
            onClick={() => {
              setTouched(true);
              if (!err) onConfirm(reason.trim());
            }}
          >
            {t(`admin.events.action.${action}`)}
          </Button>
        </>
      }
    >
      <p>{t(`admin.events.dialog.message.${action}`)}</p>
      <FormField
        label={t('admin.events.dialog.reason')}
        hint={t('admin.events.dialog.reasonHint')}
        error={touched && err ? t(err === 'REQUIRED' ? 'admin.events.dialog.reasonRequired' : 'admin.events.dialog.reasonTooLong') : null}
        required
      >
        <Textarea rows={3} value={reason} maxLength={REASON_MAX + 50} onChange={(e) => setReason(e.target.value)} data-autofocus />
      </FormField>
      <CharCounter length={reason.length} max={REASON_MAX} tone={counterTone(reason.length, REASON_MAX)} />
      {error && (
        <p role="alert" style={{ color: 'var(--danger)', marginBlockStart: 'var(--space-3)' }}>
          {error}
        </p>
      )}
    </Modal>
  );
}
