// Mesaj işlem menüsü (P08): Gizle / Geri göster / Kalıcı sil. Her işlem GuardedAction'dır: sebep ZORUNLU (sohbet içeriğini
// görüntüleme sebebinden AYRI alan), kalıcı silme ayrıca "SİL" yazdırır ve geri alınamaz olarak işaretlenir.
// Menü içeriği her zaman bağlıdır (yalnız gizlenir): onay diyaloğu açıkken menü kapansa da diyalog kaybolmaz.
import { useState } from 'react';
import { adminChatApi } from '../../../api';
import type { AdminChatMessage } from '../../../api/types';
import { Button, GuardedAction } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { availableActions, messageState } from './chatAction';
import styles from './chatAction.module.css';

/** Mesaj değişince bu önek altındaki tüm sohbet sorguları yenilenir (görüntüleyici + akış). */
const INVALIDATE = [['adminChat']];

export function MessageActions({ m }: { m: AdminChatMessage }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [open, setOpen] = useState(false);
  const state = messageState(m);
  const can = availableActions(state);
  const err = (e: unknown) => adminError(i18n, e);
  if (!can.hide && !can.unhide && !can.purge) return null;

  return (
    <div className={styles.menu} data-testid="msg-actions">
      <Button
        variant="ghost"
        size="sm"
        aria-haspopup="true"
        aria-expanded={open}
        aria-label={t('admin.p08.menuFor', { id: m.id })}
        onClick={() => setOpen((o) => !o)}
      >
        {t('admin.p08.menu')}
      </Button>
      <div className={styles.menuList} hidden={!open}>
        {can.hide && (
          <GuardedAction
            variant="secondary"
            size="sm"
            title={t('admin.p08.hide.title')}
            message={t('admin.p08.hide.message')}
            consequence={t('admin.p08.hide.consequence')}
            irreversible={false}
            requireReason
            reasonLabel={t('admin.p08.reason.hide')}
            successMessage={t('admin.p08.hide.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onConfirm={({ reason, idempotencyKey }) => adminChatApi.hideMessage(m.id, reason, idempotencyKey)}
          >
            {t('admin.p08.hide.btn')}
          </GuardedAction>
        )}
        {can.unhide && (
          <GuardedAction
            variant="secondary"
            size="sm"
            title={t('admin.p08.unhide.title')}
            message={t('admin.p08.unhide.message')}
            consequence={t('admin.p08.unhide.consequence')}
            irreversible={false}
            requireReason
            reasonLabel={t('admin.p08.reason.hide')}
            successMessage={t('admin.p08.unhide.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onConfirm={({ reason, idempotencyKey }) => adminChatApi.unhideMessage(m.id, reason, idempotencyKey)}
          >
            {t('admin.p08.unhide.btn')}
          </GuardedAction>
        )}
        {can.purge && (
          <GuardedAction
            danger
            size="sm"
            title={t('admin.p08.purge.title')}
            message={t('admin.p08.purge.message')}
            consequence={t('admin.p08.purge.consequence')}
            irreversible
            requireReason
            reasonLabel={t('admin.p08.reason.hide')}
            typeToConfirm={t('admin.p08.purge.confirmWord')}
            successMessage={t('admin.p08.purge.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onConfirm={({ reason, idempotencyKey }) => adminChatApi.purgeMessage(m.id, reason, idempotencyKey)}
          >
            {t('admin.p08.purge.btn')}
          </GuardedAction>
        )}
      </div>
    </div>
  );
}
