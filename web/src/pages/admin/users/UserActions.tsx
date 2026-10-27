import { useMutation, useQueryClient } from '@tanstack/react-query';
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
import {
  Button,
  Card,
  ConfirmDialog,
  FormField,
  Input,
  Modal,
  Select,
  Textarea,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import styles from './users.module.css';

interface Props {
  user: AdminUserDetail;
  /** Oturum açmış yöneticinin kimliği: kendi hesabında rol/silme devre dışıdır. */
  selfId: number | null | undefined;
  onDeleted?: () => void;
}

type Dialog = null | 'suspend' | 'unsuspend' | 'role' | 'delete' | 'verify' | 'reset' | 'revoke';

/** Askıya al / geri aç, rol değiştir ve hesap sil işlemleri; hepsi onay penceresinden geçer. */
export function UserActions({ user, selfId, onDeleted }: Props) {
  const i18n = useI18n();
  const { t, td } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [reason, setReason] = useState('');
  const [reasonError, setReasonError] = useState<string | null>(null);
  const [role, setRole] = useState<Role>(user.role);
  const [typedEmail, setTypedEmail] = useState('');
  const isSelf = selfId === user.id;
  const deleted = user.status === 'DELETED';

  useEffect(() => setRole(user.role), [user.role]);

  function close() {
    setDialog(null);
    setReason('');
    setReasonError(null);
    setTypedEmail('');
  }

  function refresh() {
    void qc.invalidateQueries({ queryKey: qk.users.all });
    void qc.invalidateQueries({ queryKey: qk.analytics.all });
  }

  const onError = (e: unknown) => {
    toast.error(errorMessage(i18n, e));
    close();
  };

  const suspend = useMutation({
    mutationFn: () => suspendUser(user.id, reason.trim()),
    onSuccess: () => {
      toast.success(t('admin.users.actions.suspend.done'));
      close();
      refresh();
    },
    onError,
  });
  const unsuspend = useMutation({
    mutationFn: () => unsuspendUser(user.id),
    onSuccess: () => {
      toast.success(t('admin.users.actions.unsuspend.done'));
      close();
      refresh();
    },
    onError,
  });
  const changeRole = useMutation({
    mutationFn: () => setUserRole(user.id, role),
    onSuccess: () => {
      toast.success(t('admin.users.actions.role.done'));
      close();
      refresh();
    },
    onError: (e) => {
      setRole(user.role);
      onError(e);
    },
  });
  const verifyEmail = useMutation({
    mutationFn: () => verifyUserEmail(user.id),
    onSuccess: () => {
      toast.success(t('admin.users.actions.verifyEmail.done'));
      close();
      refresh();
    },
    onError,
  });
  const sendReset = useMutation({
    mutationFn: () => sendUserReset(user.id),
    onSuccess: () => {
      toast.success(t('admin.users.actions.sendReset.done'));
      close();
    },
    onError,
  });
  const revoke = useMutation({
    mutationFn: () => revokeUserSessions(user.id),
    onSuccess: () => {
      toast.success(t('admin.users.actions.revoke.done'));
      close();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: () => deleteUser(user.id),
    onSuccess: () => {
      toast.success(t('admin.users.actions.delete.done'));
      close();
      refresh();
      onDeleted?.();
    },
    onError,
  });

  function submitSuspend() {
    if (!reason.trim()) {
      setReasonError(t('admin.users.actions.suspend.reasonRequired'));
      return;
    }
    suspend.mutate();
  }

  const emailMatches = typedEmail.trim().toLowerCase() === user.email.toLowerCase();

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

      <Modal
        open={dialog === 'suspend'}
        onClose={close}
        title={t('admin.users.actions.suspend.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={close}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={suspend.isPending} onClick={submitSuspend}>
              {t('admin.users.actions.suspend')}
            </Button>
          </>
        }
      >
        <div className={styles.modalForm}>
          <FormField
            label={t('admin.users.actions.suspend.reason')}
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

      <ConfirmDialog
        open={dialog === 'unsuspend'}
        onClose={close}
        onConfirm={() => unsuspend.mutate()}
        loading={unsuspend.isPending}
        title={t('admin.users.actions.unsuspend')}
        message={t('admin.users.actions.unsuspend.message', { name: user.displayName })}
        confirmLabel={t('admin.users.actions.unsuspend')}
      />

      <ConfirmDialog
        open={dialog === 'verify'}
        onClose={close}
        onConfirm={() => verifyEmail.mutate()}
        loading={verifyEmail.isPending}
        title={t('admin.users.actions.verifyEmail')}
        message={t('admin.users.actions.verifyEmail.message', { name: user.displayName })}
        confirmLabel={t('admin.users.actions.verifyEmail')}
      />
      <ConfirmDialog
        open={dialog === 'reset'}
        onClose={close}
        onConfirm={() => sendReset.mutate()}
        loading={sendReset.isPending}
        title={t('admin.users.actions.sendReset')}
        message={t('admin.users.actions.sendReset.message', { name: user.displayName })}
        confirmLabel={t('admin.users.actions.sendReset')}
      />
      <ConfirmDialog
        open={dialog === 'revoke'}
        onClose={close}
        onConfirm={() => revoke.mutate()}
        loading={revoke.isPending}
        danger
        title={t('admin.users.actions.revoke')}
        message={t('admin.users.actions.revoke.message', { name: user.displayName })}
        confirmLabel={t('admin.users.actions.revoke')}
      />

      <ConfirmDialog
        open={dialog === 'role'}
        onClose={close}
        onConfirm={() => changeRole.mutate()}
        loading={changeRole.isPending}
        title={t('admin.users.actions.role.change')}
        message={t('admin.users.actions.role.message', {
          name: user.displayName,
          role: td(`admin.users.role.${role}`),
        })}
        danger={role === 'USER'}
      />

      <Modal
        open={dialog === 'delete'}
        onClose={close}
        title={t('admin.users.actions.delete.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={close}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="danger"
              disabled={!emailMatches}
              loading={remove.isPending}
              onClick={() => remove.mutate()}
            >
              {t('admin.users.actions.delete')}
            </Button>
          </>
        }
      >
        <div className={styles.modalForm}>
          <p>{t('admin.users.actions.delete.warning')}</p>
          <p className="ltr">
            <strong>{user.email}</strong>
          </p>
          <FormField label={t('admin.users.actions.delete.typeEmail')}>
            <Input
              data-autofocus
              className="ltr"
              autoComplete="off"
              value={typedEmail}
              onChange={(e) => setTypedEmail(e.target.value)}
            />
          </FormField>
        </div>
      </Modal>
    </Card>
  );
}
