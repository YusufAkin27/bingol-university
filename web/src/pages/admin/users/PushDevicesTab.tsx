import { useQuery } from '@tanstack/react-query';
import { deleteUserPushDevice, getUserPushDevices, userDeepKeys } from '../../../api/adminUsers';
import { Badge, EmptyState, ErrorState, GuardedAction, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import styles from './deep.module.css';

/** FCM cihaz kayıtları: token ASLA tam gösterilmez (son karakterler). Silme sebep + onay ister. */
export function PushDevicesTab({ userId }: { userId: number }) {
  const i18n = useI18n();
  const { t, td, formatDateTime } = i18n;
  const q = useQuery({ queryKey: userDeepKeys.pushDevices(userId), queryFn: () => getUserPushDevices(userId) });

  if (q.isError) return <ErrorState description={adminError(i18n, q.error, 'admin.p09.err')} onRetry={() => void q.refetch()} />;
  if (!q.data) return <Skeleton height="6rem" width="100%" />;

  return (
    <div className={styles.tabBody}>
      <p className={styles.hint}>{t('admin.p09.devices.note')}</p>
      {q.data.length === 0 ? (
        <EmptyState compact icon="info" title={t('admin.p09.devices.empty')} description={t('admin.p09.devices.emptyHint')} />
      ) : (
        <ul className={styles.rows}>
          {q.data.map((d) => (
            <li key={d.id} className={styles.row} data-testid="push-device-row">
              <div className={styles.rowMain}>
                <span className={styles.badges}>
                  <Badge tone="info">{td(`admin.users.platform.${d.platform}`, d.platform)}</Badge>
                  {d.appVersion && <span className={styles.rowMeta}>v{d.appVersion}</span>}
                  <span className={`${styles.token} ltr`} data-testid="token-tail">
                    {t('admin.p09.devices.token')}: …{d.tokenTail}
                  </span>
                </span>
                <span className={styles.rowMeta}>
                  {t('admin.p09.devices.lastSeen')}: {d.lastSeenAt ? formatDateTime(d.lastSeenAt) : '—'}
                </span>
              </div>
              <GuardedAction
                size="sm"
                variant="secondary"
                danger
                title={t('admin.p09.devices.delete.title')}
                message={t('admin.p09.devices.delete.message', { tail: d.tokenTail })}
                consequence={t('admin.p09.devices.delete.consequence')}
                irreversible={false}
                requireReason
                confirmLabel={t('admin.p09.devices.delete.confirm')}
                successMessage={t('admin.p09.devices.delete.done')}
                errorMessage={(e) => adminError(i18n, e, 'admin.p09.err')}
                invalidateKeys={[[...userDeepKeys.pushDevices(userId)]]}
                onConfirm={({ reason, idempotencyKey }) => deleteUserPushDevice(userId, d.id, { reason, idempotencyKey })}
              >
                {t('admin.p09.devices.delete')}
              </GuardedAction>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
