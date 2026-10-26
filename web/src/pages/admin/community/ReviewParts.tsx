/** Topluluk ve etkinlik onay kuyruklarının ortak parçaları. */
import { useState, type ReactNode } from 'react';
import { Button, Modal, Textarea, FormField } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { CharCounter } from '../campaigns/shared';
import { counterTone } from '../campaigns/lib';
import styles from './review.module.css';

export const REASON_MAX = 300;

export function RejectDialog({
  open,
  name,
  loading,
  onClose,
  onConfirm,
}: {
  open: boolean;
  name: string;
  loading: boolean;
  onClose: () => void;
  onConfirm: (reason: string) => void;
}) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={t('admin.review.reject.title', { name })}
      size="sm"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button
            variant="danger"
            loading={loading}
            disabled={reason.length > REASON_MAX}
            onClick={() => onConfirm(reason.trim())}
          >
            {t('admin.review.reject')}
          </Button>
        </>
      }
    >
      <p className={styles.rejectIntro}>{t('admin.review.reject.intro')}</p>
      <FormField label={t('admin.review.reject.reason')}>
        <Textarea
          rows={3}
          value={reason}
          maxLength={REASON_MAX + 50}
          onChange={(e) => setReason(e.target.value)}
          data-autofocus
        />
      </FormField>
      <div className={styles.counterRow}>
        <CharCounter length={reason.length} max={REASON_MAX} tone={counterTone(reason.length, REASON_MAX)} />
      </div>
    </Modal>
  );
}

export function DetailList({ items }: { items: { label: string; value: ReactNode }[] }) {
  return (
    <dl className={styles.dl}>
      {items.map((it) => (
        <div key={it.label} className={styles.dlRow}>
          <dt>{it.label}</dt>
          <dd>{it.value}</dd>
        </div>
      ))}
    </dl>
  );
}
