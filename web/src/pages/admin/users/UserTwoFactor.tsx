// Kullanıcı ayrıntısı: iki faktörlü doğrulama kartı + "2FA'yı kapat" (hesap kurtarma).
// API: POST /api/admin/users/{id}/two-factor/disable {reason} (api/twoFactor.ts; izin users.write, sunucu zorlar).
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { qk } from '../../../api/queryKeys';
import type { AdminUserDetail } from '../../../api/types';
import { disableUserTwoFactor } from '../../../api/twoFactor';
import { Badge, Button, Card, FormField, Modal, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import styles from './users.module.css';

export function UserTwoFactor({ user }: { user: AdminUserDetail }) {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [reasonError, setReasonError] = useState<string | null>(null);
  const enabled = !!user.twoFactorEnabled;
  const deleted = user.status === 'DELETED';

  function close() {
    setOpen(false);
    setReason('');
    setReasonError(null);
  }

  const disable = useMutation({
    mutationFn: () => disableUserTwoFactor(user.id, reason.trim()),
    onSuccess: () => {
      toast.success(t('admin.users.tf.disable.done'));
      close();
      void qc.invalidateQueries({ queryKey: qk.users.all });
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  function submit() {
    if (!reason.trim()) {
      setReasonError(t('admin.users.tf.disable.reasonRequired'));
      return;
    }
    disable.mutate();
  }

  return (
    <Card title={t('admin.users.tf.title')}>
      <dl className={styles.facts}>
        <div>
          <dt>{t('admin.users.tf.status')}</dt>
          <dd>
            <Badge tone={enabled ? 'success' : 'neutral'}>
              {enabled ? t('admin.users.twoFactor.on') : t('admin.users.twoFactor.off')}
            </Badge>
          </dd>
        </div>
        {enabled && (
          <>
            <div>
              <dt>{t('admin.users.tf.enabledAt')}</dt>
              <dd>{user.twoFactorEnabledAt ? formatDateTime(user.twoFactorEnabledAt) : '—'}</dd>
            </div>
            <div>
              <dt>{t('admin.users.tf.devices')}</dt>
              <dd>{formatNumber(user.twoFactorTrustedDeviceCount ?? 0)}</dd>
            </div>
          </>
        )}
      </dl>
      {!enabled && <p className={styles.hint}>{t('admin.users.tf.offNote')}</p>}
      {enabled && !deleted && (
        <div className={styles.actionRow} style={{ marginBlockStart: 'var(--space-3)' }}>
          <Button variant="danger" onClick={() => setOpen(true)}>
            {t('admin.users.tf.disable')}
          </Button>
        </div>
      )}

      <Modal
        open={open}
        onClose={close}
        title={t('admin.users.tf.disable.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={close}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={disable.isPending} onClick={submit}>
              {t('admin.users.tf.disable')}
            </Button>
          </>
        }
      >
        <div className={styles.modalForm}>
          <p>{t('admin.users.tf.disable.confirm', { name: user.displayName })}</p>
          <p className={styles.hint}>{t('admin.users.tf.disable.explain')}</p>
          <FormField
            label={t('admin.users.tf.disable.reason')}
            hint={t('admin.users.tf.disable.reasonHint')}
            error={reasonError}
            required
          >
            <Textarea
              data-autofocus
              rows={3}
              maxLength={300}
              value={reason}
              onChange={(e) => {
                setReason(e.target.value);
                setReasonError(null);
              }}
            />
          </FormField>
        </div>
      </Modal>
    </Card>
  );
}
