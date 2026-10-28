import { useState } from 'react';
import { EXPORT_REASON_MIN, exportUserData } from '../../../api/adminUsers';
import { isApiError } from '../../../api/client';
import type { AdminUserDetail } from '../../../api/types';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { Button, Checkbox, Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { downloadBlob } from './filters';
import styles from './deep.module.css';

/**
 * Kullanıcı adına KVKK dışa aktarma, İKİ AŞAMALI onay: (1) uyarıyı okuyup yetki onayı kutusunu işaretleme,
 * (2) diyalogda sebep (>= 20 karakter) + kullanıcı kimliğini yazma. Kullanıcıya bildirim gitmez; işlem denetlenir;
 * kullanıcı başına günde bir kez.
 */
export function ExportTab({ user }: { user: AdminUserDetail }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [ack, setAck] = useState(false);
  const [open, setOpen] = useState(false);

  const errorMessage = (e: unknown) =>
    isApiError(e) && e.status === 429 ? t('admin.p09.export.daily') : adminError(i18n, e, 'admin.p09.err');

  return (
    <div className={styles.tabBody}>
      <div className={styles.warn}>
        <Callout tone="warning" title={t('admin.p09.export.warnTitle')}>
          {t('admin.p09.export.warn')}
        </Callout>
        <ul className={styles.bulkList}>
          <li>{t('admin.p09.export.rule.audit')}</li>
          <li>{t('admin.p09.export.rule.noNotify')}</li>
          <li>{t('admin.p09.export.rule.daily')}</li>
          <li>{t('admin.p09.export.rule.reason', { n: EXPORT_REASON_MIN })}</li>
        </ul>
        <Checkbox
          label={t('admin.p09.export.ack', { name: user.displayName })}
          checked={ack}
          onChange={(e) => setAck(e.target.checked)}
        />
        <div>
          <Button
            variant="secondary"
            leftIcon={<Icon name="download" size={18} />}
            disabled={!ack}
            onClick={() => setOpen(true)}
          >
            {t('admin.p09.export.start')}
          </Button>
        </div>
      </div>

      <GuardedDialog
        open={open}
        onClose={() => setOpen(false)}
        title={t('admin.p09.export.title')}
        message={t('admin.p09.export.message', { name: user.displayName })}
        consequence={t('admin.p09.export.consequence')}
        irreversible={false}
        danger
        requireReason
        reasonMinLength={EXPORT_REASON_MIN}
        reasonLabel={t('admin.p09.export.reasonLabel')}
        typeToConfirm={String(user.id)}
        confirmLabel={t('admin.p09.export.confirm')}
        successMessage={t('admin.p09.export.done')}
        errorMessage={errorMessage}
        onConfirm={async ({ reason, idempotencyKey }) => {
          const blob = await exportUserData(user.id, { reason, idempotencyKey });
          downloadBlob(blob, `user-${user.id}-data.json`);
        }}
        onSuccess={() => setAck(false)}
      />
    </div>
  );
}
