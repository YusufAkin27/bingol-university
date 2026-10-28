import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { getUserNotifications, userDeepKeys } from '../../../api/adminUsers';
import { Badge, Checkbox, EmptyState, ErrorState, Pagination, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import styles from './deep.module.css';

/** Bildirim kutusu geçmişi (salt okunur). İçerik kişisel veri olabilir: görüntüleme sunucuda denetim kaydına yazılır. */
export function NotificationsTab({ userId }: { userId: number }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const [unread, setUnread] = useState(false);
  const [page, setPage] = useState(0);
  const q = useQuery({
    queryKey: userDeepKeys.notifications(userId, unread, page),
    queryFn: () => getUserNotifications(userId, { unread, page }),
    placeholderData: keepPreviousData,
  });

  return (
    <div className={styles.tabBody}>
      <p className={styles.hint}>{t('admin.p09.notifs.note')}</p>
      <Checkbox
        label={t('admin.p09.notifs.unreadOnly')}
        checked={unread}
        onChange={(e) => {
          setUnread(e.target.checked);
          setPage(0);
        }}
      />
      {q.isError && !q.data ? (
        <ErrorState description={adminError(i18n, q.error, 'admin.p09.err')} onRetry={() => void q.refetch()} />
      ) : !q.data ? (
        <Skeleton height="6rem" width="100%" />
      ) : q.data.items.length === 0 ? (
        <EmptyState compact icon="info" title={t('admin.p09.notifs.empty')} description={t('admin.p09.notifs.emptyHint')} />
      ) : (
        <>
          <p className={styles.hint} aria-live="polite">
            {t('admin.p09.notifs.count', { n: formatNumber(q.data.totalItems) })}
          </p>
          <ul className={styles.rows}>
            {q.data.items.map((n) => (
              <li key={n.id} className={styles.row} data-testid="notif-row">
                <div className={styles.rowMain}>
                  <span className={styles.rowTitle}>{n.title}</span>
                  {n.body && <p className={styles.notifBody}>{n.body}</p>}
                  <span className={styles.rowMeta}>{n.createdAt ? formatDateTime(n.createdAt) : '—'}</span>
                </div>
                <span className={styles.badges}>
                  <Badge tone="neutral">{td(`admin.p09.notifs.type.${n.type}`, n.type)}</Badge>
                  <Badge tone={n.read ? 'success' : 'warning'}>
                    {n.read ? t('admin.p09.notifs.read') : t('admin.p09.notifs.unread')}
                  </Badge>
                </span>
              </li>
            ))}
          </ul>
          {q.data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination
                page={q.data.page}
                totalPages={q.data.totalPages}
                totalItems={q.data.totalItems}
                onPageChange={setPage}
              />
            </div>
          )}
        </>
      )}
    </div>
  );
}
