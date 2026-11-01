import { useEffect, useState, type ReactNode } from 'react';
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
import { ActionBar, Card, Icon, PermissionButton, Select } from '../../../components/ui';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { useI18n } from '../../../i18n/I18nProvider';
import { ADMIN_REASON_MIN } from '../../../components/admin/guard/match';
import { Callout } from '../campaigns/shared';
import styles from './users.module.css';

interface Props {
  user: AdminUserDetail;
  /** Oturum açmış yöneticinin kimliği: kendi hesabında rol/silme devre dışıdır. */
  selfId: number | null | undefined;
  onDeleted?: () => void;
  /**
   * full: bütün işlemler (Yönetim sekmesi, tehlikeli bölge ayrı). quick: sayfanın üstündeki hızlı çubuk;
   * yalnız askıya al / askıyı kaldır ve (doğrulanmamışsa) e-postayı doğrula düğmeleri. İki hâl de aynı onay diyaloglarını kullanır.
   */
  variant?: 'full' | 'quick';
  /** quick çubuğuna eklenecek ek düğmeler (örn. Bildirim gönder). */
  children?: ReactNode;
}

type Dialog = null | 'suspend' | 'unsuspend' | 'role' | 'delete' | 'verify' | 'reset' | 'revoke';

/**
 * Askıya al / geri aç, rol değiştir, oturum kapat ve hesap sil işlemleri. Hepsi `GuardedDialog`dan geçer:
 * çift tıklamaya karşı kilit + Idempotency-Key; silme/rol için yazılı onay (e-posta) + zorunlu sebep.
 */
export function UserActions({ user, selfId, onDeleted, variant = 'full', children }: Props) {
  const { t, td } = useI18n();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [role, setRole] = useState<Role>(user.role);
  const isSelf = selfId === user.id;
  const deleted = user.status === 'DELETED';

  useEffect(() => setRole(user.role), [user.role]);

  const close = () => setDialog(null);
  const refreshKeys = [qk.users.all, qk.analytics.all];
  const name = user.displayName;

  if (deleted && variant === 'quick') return null;
  if (deleted) {
    return (
      <Card title={t('admin.users.actions.title')}>
        <p className={styles.hint}>{t('admin.users.actions.deletedNote')}</p>
      </Card>
    );
  }

  const suspendButton =
    user.status === 'SUSPENDED' ? (
      <PermissionButton
        permission="users.write"
        variant="secondary"
        leftIcon={<Icon name="check" size={18} />}
        onClick={() => setDialog('unsuspend')}
      >
        {t('admin.users.actions.unsuspend')}
      </PermissionButton>
    ) : (
      <PermissionButton
        permission="users.write"
        variant="dangerOutline"
        leftIcon={<Icon name="alert" size={18} />}
        onClick={() => setDialog('suspend')}
        disabled={isSelf}
      >
        {t('admin.users.actions.suspend')}
      </PermissionButton>
    );

  const dialogs = (
    <>
      <GuardedDialog
        open={dialog === 'suspend'}
        onClose={close}
        title={t('admin.users.actions.suspend.title')}
        message={t('admin.p05.user.suspend.message', { name })}
        confirmLabel={t('admin.users.actions.suspend')}
        danger
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
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
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        successMessage={t('admin.users.actions.verifyEmail.done')}
        invalidateKeys={refreshKeys}
        onConfirm={({ reason, idempotencyKey }) => verifyUserEmail(user.id, { reason, idempotencyKey })}
      />

      <GuardedDialog
        open={dialog === 'reset'}
        onClose={close}
        title={t('admin.users.actions.sendReset')}
        message={t('admin.users.actions.sendReset.message', { name })}
        confirmLabel={t('admin.users.actions.sendReset')}
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        successMessage={t('admin.users.actions.sendReset.done')}
        onConfirm={({ reason, idempotencyKey }) => sendUserReset(user.id, { reason, idempotencyKey })}
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
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
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
    </>
  );

  if (variant === 'quick') {
    return (
      <>
        <ActionBar data-search-anchor="ud-quick">
          {suspendButton}
          {!user.emailVerified && (
            <PermissionButton permission="users.verify" variant="primary" onClick={() => setDialog('verify')}>
              {t('admin.users.actions.verifyEmail')}
            </PermissionButton>
          )}
          {children}
        </ActionBar>
        {dialogs}
      </>
    );
  }

  return (
    <Card title={t('admin.users.actions.title')} data-search-anchor="ud-actions">
      <div className={styles.actions}>
        <p className={styles.hint}>{t('admin.v2p.ud.safeHint')}</p>
        <div className={styles.actionRow}>{suspendButton}</div>

        {!user.emailVerified && (
          <div className={styles.actionRow}>
            <PermissionButton permission="users.verify" variant="primary" onClick={() => setDialog('verify')}>
              {t('admin.users.actions.verifyEmail')}
            </PermissionButton>
          </div>
        )}

        <div className={styles.actionRow}>
          <PermissionButton permission="users.write" variant="secondary" onClick={() => setDialog('reset')}>
            {t('admin.users.actions.sendReset')}
          </PermissionButton>
        </div>

        <div className={styles.actionRow}>
          <PermissionButton permission="users.write" variant="secondary" onClick={() => setDialog('revoke')}>
            {t('admin.users.actions.revoke')}
          </PermissionButton>
        </div>

        <section className={styles.dangerBox} aria-label={t('admin.v2p.ud.dangerTitle')} data-search-anchor="ud-danger">
          <h3 className={styles.dangerTitle}>
            <Icon name="alert" size={18} aria-hidden="true" /> {t('admin.v2p.ud.dangerTitle')}
          </h3>
          <p className={styles.hint}>{t('admin.v2p.ud.dangerHint')}</p>
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
              <PermissionButton
                permission="users.role"
                variant="secondary"
                disabled={isSelf || role === user.role}
                onClick={() => setDialog('role')}
              >
                {t('admin.users.actions.role.change')}
              </PermissionButton>
            </div>
            {isSelf && <p className={styles.hint}>{t('admin.users.actions.role.self')}</p>}
          </div>

          <div className={styles.actionRow}>
            <PermissionButton
              permission="users.delete"
              variant="danger"
              disabled={isSelf}
              onClick={() => setDialog('delete')}
            >
              {t('admin.users.actions.delete')}
            </PermissionButton>
            <p className={styles.hint}>{t('admin.v2p.ud.deleteHint')}</p>
            {isSelf && <p className={styles.hint}>{t('admin.users.actions.delete.self')}</p>}
          </div>
        </section>
      </div>

      {dialogs}
    </Card>
  );
}
