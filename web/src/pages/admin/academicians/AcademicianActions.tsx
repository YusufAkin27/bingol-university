// Onayla / Reddet / Onayı geri al düğmeleri. Yazma izni (users.write) yoksa hiçbir denetim çizilmez; asıl denetim sunucudadır.
import { approveAcademician, rejectAcademician, revokeAcademician, acadKeys, type AdminAcademician } from '../../../api/adminAcademicians';
import { useCan } from '../../../auth/permissions';
import { GuardedAction, Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { ga } from './dict';
import { canApprove, canReject, canRevoke, nameOf } from './logic';
import styles from './acad.module.css';

export function AcademicianActions({ a, size = 'sm' }: { a: AdminAcademician; size?: 'sm' | 'md' }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const canWrite = useCan('users.write');
  if (!canWrite) return null;
  const name = nameOf(a) || x('admin.acad.noName');
  const common = {
    size,
    invalidateKeys: [[...acadKeys.all]] as unknown[][],
    errorMessage: (e: unknown) => adminError(i18n, e, 'admin.acad.err'),
    permission: 'users.write',
  };
  return (
    <div className={styles.actions}>
      {canReject(a.status) && (
        <GuardedAction
          {...common}
          variant="secondary"
          danger
          title={x('admin.acad.reject.title', { name })}
          consequence={x('admin.acad.reject.consequence')}
          requireReason
          reasonLabel={x('admin.acad.reject.reason')}
          confirmLabel={x('admin.acad.action.reject')}
          successMessage={x('admin.acad.reject.done')}
          onConfirm={({ reason, idempotencyKey }) => rejectAcademician(a.userId, reason, idempotencyKey)}
        >
          {x('admin.acad.action.reject')}
        </GuardedAction>
      )}
      {canApprove(a.status) && (
        <GuardedAction
          {...common}
          leftIcon={<Icon name="check" size={16} />}
          title={x('admin.acad.approve.title', { name })}
          consequence={x('admin.acad.approve.consequence')}
          confirmLabel={x('admin.acad.action.approve')}
          successMessage={x('admin.acad.approve.done')}
          onConfirm={({ idempotencyKey }) => approveAcademician(a.userId, idempotencyKey)}
        >
          {x('admin.acad.action.approve')}
        </GuardedAction>
      )}
      {canRevoke(a.status) && (
        <GuardedAction
          {...common}
          variant="secondary"
          danger
          title={x('admin.acad.revoke.title', { name })}
          consequence={x('admin.acad.revoke.consequence')}
          requireReason
          reasonLabel={x('admin.acad.revoke.reason')}
          confirmLabel={x('admin.acad.action.revoke')}
          successMessage={x('admin.acad.revoke.done')}
          onConfirm={({ reason, idempotencyKey }) => revokeAcademician(a.userId, reason, idempotencyKey)}
        >
          {x('admin.acad.action.revoke')}
        </GuardedAction>
      )}
    </div>
  );
}
