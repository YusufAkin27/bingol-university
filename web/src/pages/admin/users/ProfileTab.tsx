import { useState } from 'react';
import { patchUserProfile } from '../../../api/adminUsers';
import { qk } from '../../../api/queryKeys';
import type { AdminUserDetail } from '../../../api/types';
import { Callout } from '../campaigns/shared';
import { GuardedAction, Input, FormField } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import styles from './deep.module.css';

/** Profil müdahalesi: avatar/biyografi temizleme + görünen ad düzeltme. Sebep zorunlu; kullanıcıya bildirim gider. */
export function ProfileTab({ user }: { user: AdminUserDetail }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [name, setName] = useState('');
  const trimmed = name.trim();
  const keys = [[...qk.users.all]];
  const err = (e: unknown) => adminError(i18n, e, 'admin.p09.err');

  return (
    <div className={styles.tabBody}>
      <Callout tone="info">{t('admin.p09.profile.note')}</Callout>
      <div className={styles.actionList}>
        <div>
          <p className={styles.current}>
            <strong>{t('admin.p09.profile.avatar')}:</strong>{' '}
            {user.avatarUrl ? t('admin.p09.profile.avatar.set') : t('admin.p09.profile.avatar.none')}
          </p>
          <GuardedAction
            variant="secondary"
            size="sm"
            disabled={!user.avatarUrl}
            title={t('admin.p09.profile.avatar.title')}
            message={t('admin.p09.profile.avatar.message', { name: user.displayName })}
            consequence={t('admin.p09.profile.consequence')}
            irreversible
            danger
            requireReason
            confirmLabel={t('admin.p09.profile.avatar.confirm')}
            successMessage={t('admin.p09.profile.avatar.done')}
            errorMessage={err}
            invalidateKeys={keys}
            onConfirm={({ reason, idempotencyKey }) =>
              patchUserProfile(user.id, { clearAvatar: true }, { reason, idempotencyKey })
            }
          >
            {t('admin.p09.profile.avatar.clear')}
          </GuardedAction>
        </div>

        <div>
          <p className={styles.current}>
            <strong>{t('admin.p09.profile.bio')}:</strong> {user.bio || t('admin.p09.profile.bio.none')}
          </p>
          <GuardedAction
            variant="secondary"
            size="sm"
            disabled={!user.bio}
            title={t('admin.p09.profile.bio.title')}
            message={t('admin.p09.profile.bio.message', { name: user.displayName })}
            consequence={t('admin.p09.profile.consequence')}
            irreversible
            danger
            requireReason
            confirmLabel={t('admin.p09.profile.bio.confirm')}
            successMessage={t('admin.p09.profile.bio.done')}
            errorMessage={err}
            invalidateKeys={keys}
            onConfirm={({ reason, idempotencyKey }) =>
              patchUserProfile(user.id, { clearBio: true }, { reason, idempotencyKey })
            }
          >
            {t('admin.p09.profile.bio.clear')}
          </GuardedAction>
        </div>

        <div>
          <p className={styles.current}>
            <strong>{t('admin.p09.profile.name')}:</strong> {user.displayName}
          </p>
          <div className={styles.nameRow}>
            <FormField label={t('admin.p09.profile.name.new')} hint={t('admin.p09.profile.name.hint')}>
              <Input value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />
            </FormField>
            <GuardedAction
              variant="secondary"
              size="sm"
              disabled={trimmed.length < 2 || trimmed === user.displayName}
              title={t('admin.p09.profile.name.title')}
              message={t('admin.p09.profile.name.message', { from: user.displayName, to: trimmed })}
              consequence={t('admin.p09.profile.consequence')}
              irreversible={false}
              requireReason
              confirmLabel={t('admin.p09.profile.name.confirm')}
              successMessage={t('admin.p09.profile.name.done')}
              errorMessage={err}
              invalidateKeys={keys}
              onSuccess={() => setName('')}
              onConfirm={({ reason, idempotencyKey }) =>
                patchUserProfile(user.id, { displayName: trimmed }, { reason, idempotencyKey })
              }
            >
              {t('admin.p09.profile.name.change')}
            </GuardedAction>
          </div>
        </div>
      </div>
    </div>
  );
}
