import { useEffect, useState } from 'react';
import { qk } from '../../../api/queryKeys';
import type { AdminUserDetail, Role } from '../../../api/types';
import {
  deleteUser,
  revokeUserSessions,
  sendUserReset,
  setUserRole,
  suspendUser,
  unsuspendUser,
  verifyUserEmail,
} from '../../../api/users';
import { Button, Card, Select } from '../../../components/ui';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import styles from './users.module.css';

interface Props {
  user: AdminUserDetail;
  /** Oturum açmış yöneticinin kimliği: kendi hesabında rol/silme devre dışıdır. */
  selfId: number | null | undefined;
  onDeleted?: () => void;
}

type Dialog = null | 'suspend' | 'unsuspend' | 'role' | 'delete' | 'verify' | 'reset' | 'revoke';

/** Askı sebebi en az bu kadar karakter olmalı (önceki davranış: boş olamaz; kısa ama anlamlı sebepler kabul). */
const SUSPEND_REASON_MIN = 3;

/**
 * Askıya al / geri aç, rol değiştir, oturum kapat ve hesap sil işlemleri. Hepsi `GuardedDialog`dan geçer:
 * çift tıklamaya karşı kilit + Idempotency-Key; silme/rol için yazılı onay (e-posta) + zorunlu sebep.
 */
export function UserActions({ user, selfId, onDeleted }: Props) {
  const { t, td } = useI18n();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [role, setRole] = useState<Role>(user.role);
  const isSelf = selfId === user.id;
  const deleted = user.status === 'DELETED';

  useEffect(() => setRole(user.role), [user.role]);

  const close = () => setDialog(null);
  const refreshKeys = [qk.users.all, qk.analytics.all];
  const name = user.displayName;

  if (deleted) {
    return (
      <Card title={t('admin.users.actions.title')}>
        <p className={styles.hint}>{t('admin.users.actions.deletedNote')}</p>
      </Card>
    );
  }

  return (
    <Card title={t('admin.users.actions.title')}>
      <div className={styles.actions}>
        <div className={styles.actionRow}>
          {user.status === 'SUSPENDED' ? (
            <Button variant="secondary" onClick={() => setDialog('unsuspend')}>
              {t('admin.users.actions.unsuspend')}
            </Button>
          ) : (
            <Button variant="secondary" onClick={() => setDialog('suspend')} disabled={isSelf}>
              {t('admin.users.actions.suspend')}
            </Button>
          )}
        </div>

        {!user.emailVerified && (
          <div className={styles.actionRow}>
            <Button variant="primary" onClick={() => setDialog('verify')}>
              {t('admin.users.actions.verifyEmail')}
            </Button>
          </div>
        )}

        <div className={styles.actionRow}>
          <Button variant="secondary" onClick={() => setDialog('reset')}>
            {t('admin.users.actions.sendReset')}
          </Button>
        </div>

        <div className={styles.actionRow}>
          <Button variant="secondary" onClick={() => setDialog('revoke')}>
            {t('admin.users.actions.revoke')}
          </Button>
        </div>

        <div className={styles.actionRow}>
          <label htmlFor="user-role-select" className={styles.filterLabel}>
            {t('admin.users.actions.role')}
          </label>
          <div className={styles.roleRow}>
            <Select
              id="user-role-select"
              value={role}
              disabled={isSelf}
              onChange={(e) => setRole(e.target.value as Role)}
            >
              {(['USER', 'ADMIN'] as const).map((r) => (
                <option key={r} value={r}>
                  {td(`admin.users.role.${r}`)}
                </option>
              ))}
            </Select>
            <Button
              variant="secondary"
              disabled={isSelf || role === user.role}
              onClick={() => setDialog('role')}
            >
              {t('admin.users.actions.role.change')}
            </Button>
          </div>
          {isSelf && <p className={styles.hint}>{t('admin.users.actions.role.self')}</p>}
        </div>

        <div className={styles.actionRow}>
          <Button variant="danger" disabled={isSelf} onClick={() => setDialog('delete')}>
            {t('admin.users.actions.delete')}
          </Button>
          {isSelf && <p className={styles.hint}>{t('admin.users.actions.delete.self')}</p>}
        </div>
      </div>

      <GuardedDialog
        open={dialog === 'suspend'}
        onClose={close}
        title={t('admin.users.actions.suspend.title')}
        message={t('admin.p05.user.suspend.message', { name })}
        confirmLabel={t('admin.users.actions.suspend')}
        danger
        requireReason
        reasonMinLength={SUSPEND_REASON_MIN}
        reasonLabel={t('admin.users.actions.suspend.reason')}
        successMessage={t('admin.users.actions.suspend.done')}
        invalidateKeys={refreshKeys}
        onConfirm={({ reason, idempotencyKey }) => suspendUser(user.id, reason, { idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'unsuspend'}
        onClose={close}
        title={t('admin.users.actions.unsuspend')}
        message={t('admin.users.actions.unsuspend.message', { name })}
        confirmLabel={t('admin.users.actions.unsuspend')}
        successMessage={t('admin.users.actions.unsuspend.done')}
        invalidateKeys={refreshKeys}
        onConfirm={({ idempotencyKey }) => unsuspendUser(user.id, { idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'verify'}
        onClose={close}
        title={t('admin.users.actions.verifyEmail')}
        message={t('admin.users.actions.verifyEmail.message', { name })}
        confirmLabel={t('admin.users.actions.verifyEmail')}
        successMessage={t('admin.users.actions.verifyEmail.done')}
        invalidateKeys={refreshKeys}
        onConfirm={({ idempotencyKey }) => verifyUserEmail(user.id, { idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'reset'}
        onClose={close}
        title={t('admin.users.actions.sendReset')}
        message={t('admin.users.actions.sendReset.message', { name })}
        confirmLabel={t('admin.users.actions.sendReset')}
        successMessage={t('admin.users.actions.sendReset.done')}
        onConfirm={({ idempotencyKey }) => sendUserReset(user.id, { idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'revoke'}
        onClose={close}
        title={t('admin.users.actions.revoke')}
        message={t('admin.users.actions.revoke.message', { name })}
        consequence={t('admin.p05.user.revoke.consequence')}
        irreversible={false}
        confirmLabel={t('admin.users.actions.revoke')}
        danger
        optionalReason
        successMessage={t('admin.users.actions.revoke.done')}
        onConfirm={({ reason, idempotencyKey }) => revokeUserSessions(user.id, { reason, idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'role'}
        onClose={close}
        title={t('admin.users.actions.role.change')}
        message={t('admin.users.actions.role.message', { name, role: td(`admin.users.role.${role}`) })}
        consequence={t(role === 'ADMIN' ? 'admin.p05.user.role.promote' : 'admin.p05.user.role.demote')}
        irreversible={false}
        confirmLabel={t('admin.users.actions.role.change')}
        danger
        requireReason
        typeToConfirm={user.email}
        successMessage={t('admin.users.actions.role.done')}
        invalidateKeys={refreshKeys}
        extra={
          role === 'USER' ? (
            <Callout tone="warning" role="status">
              {t('admin.p05.user.role.adminEmailsWarning')}
            </Callout>
          ) : null
        }
        onConfirm={({ reason, idempotencyKey }) => setUserRole(user.id, role, { reason, idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'delete'}
        onClose={close}
        title={t('admin.users.actions.delete.title')}
        message={t('admin.users.actions.delete.warning')}
        consequence={
          <>
            <span className="ltr">
              <strong>{user.email}</strong>
            </span>
            <br />
            {t('admin.p05.user.delete.consequence')}
          </>
        }
        irreversible
        confirmLabel={t('admin.users.actions.delete')}
        danger
        requireReason
        typeToConfirm={user.email}
        successMessage={t('admin.users.actions.delete.done')}
        invalidateKeys={refreshKeys}
        onSuccess={onDeleted}
        onConfirm={({ reason, idempotencyKey }) => deleteUser(user.id, { reason, idempotencyKey })}
      />
    </Card>
  );
}
