import { useQuery } from '@tanstack/react-query';
import { getUserSessions, revokeUserSession, userDeepKeys } from '../../../api/adminUsers';
import { Badge, EmptyState, ErrorState, GuardedAction, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import styles from './deep.module.css';

/** Refresh oturumları: yalnız istemci türü, giriş ve bitiş zamanı bilinir (cihaz/IP kaydedilmez). Tek oturum kapatılabilir. */
export function SessionsTab({ userId }: { userId: number }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const q = useQuery({ queryKey: userDeepKeys.sessions(userId), queryFn: () => getUserSessions(userId) });

  if (q.isError) return <ErrorState description={adminError(i18n, q.error, 'admin.p09.err')} onRetry={() => void q.refetch()} />;
  if (!q.data) return <Skeleton height="6rem" width="100%" />;
  const items = q.data.items;

  return (
    <div className={styles.tabBody}>
      <p className={styles.hint}>{t('admin.p09.sessions.note')}</p>
      {items.length === 0 ? (
        <EmptyState compact icon="info" title={t('admin.p09.sessions.empty')} description={t('admin.p09.sessions.emptyHint')} />
      ) : (
        <>
          <p className={styles.hint} aria-live="polite">
            {t('admin.p09.sessions.count', { n: formatNumber(q.data.total) })}
          </p>
          <ul className={styles.rows}>
            {items.map((s) => (
              <li key={s.id} className={styles.row} data-testid="session-row">
                <div className={styles.rowMain}>
                  <span className={styles.badges}>
                    <Badge tone="info">{td(`admin.p09.sessions.client.${s.client}`, s.client)}</Badge>
                    <span className={styles.token}>#{s.id.slice(0, 8)}</span>
                  </span>
                  <span className={styles.rowMeta}>
                    {t('admin.p09.sessions.created')}: {s.createdAt ? formatDateTime(s.createdAt) : '—'} ·{' '}
                    {t('admin.p09.sessions.expires')}: {s.expiresAt ? formatDateTime(s.expiresAt) : '—'}
                  </span>
                </div>
                <GuardedAction
                  size="sm"
                  variant="secondary"
                  danger
                  title={t('admin.p09.sessions.revoke.title')}
                  message={t('admin.p09.sessions.revoke.message')}
                  consequence={t('admin.p09.sessions.revoke.consequence')}
                  irreversible={false}
                  requireReason
                  confirmLabel={t('admin.p09.sessions.revoke.confirm')}
                  successMessage={t('admin.p09.sessions.revoke.done')}
                  errorMessage={(e) => adminError(i18n, e, 'admin.p09.err')}
                  invalidateKeys={[[...userDeepKeys.sessions(userId)]]}
                  onConfirm={({ reason, idempotencyKey }) => revokeUserSession(userId, s.id, { reason, idempotencyKey })}
                >
                  {t('admin.p09.sessions.revoke')}
                </GuardedAction>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
