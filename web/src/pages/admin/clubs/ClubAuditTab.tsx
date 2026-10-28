// Kulüp çekmecesi: Denetim sekmesi — yönetici işlemleri (AuditTrail, hedef COMMUNITY) + kulüp içi denetim kaydı.
import { useInfiniteQuery } from '@tanstack/react-query';
import { listClubAudit } from '../../../api/adminCommunities';
import { AuditTrail } from '../../../components/admin/guard/AuditTrail';
import { EmptyState, ErrorState, LoadMore, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { isKnownAction } from './clubsLogic';
import styles from './clubs.module.css';

export function ClubAuditTab({ communityId }: { communityId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useInfiniteQuery({
    queryKey: ['communities', 'admin', 'club-audit', communityId],
    queryFn: ({ pageParam }) => listClubAudit(communityId, pageParam, 20),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    staleTime: 10_000,
  });
  const rows = q.data?.pages.flatMap((p) => p.items) ?? [];
  return (
    <div className={styles.panel}>
      <AuditTrail targetType="COMMUNITY" targetId={communityId} title={t('admin.p06.audit.adminTrail')} />
      <section aria-label={t('admin.p06.audit.clubTrail')}>
        <h3 className={styles.zoneTitle}>{t('admin.p06.audit.clubTrail')}</h3>
        <p className={styles.zoneText}>{t('admin.p06.audit.clubTrailHint')}</p>
        {q.isError ? (
          <ErrorState description={adminError(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : q.isPending ? (
          <Skeleton height="6rem" width="100%" />
        ) : rows.length === 0 ? (
          <EmptyState icon="list" title={t('admin.p06.audit.empty')} description=" " compact />
        ) : (
          <>
            <ul className={styles.history} data-testid="club-audit-list">
              {rows.map((r) => (
                <li key={r.id} className={styles.historyItem}>
                  <span>{isKnownAction(r.action) ? t(`admin.p06.audit.action.${r.action}`) : r.action}</span>
                  <span className={styles.muted}>
                    {r.actorName ?? t('admin.p06.audit.system')}
                    {r.targetName ? ` → ${r.targetName}` : ''} · {formatDateTime(r.createdAt)}
                  </span>
                  {r.detail && <span className={styles.muted}>{r.detail}</span>}
                </li>
              ))}
            </ul>
            <LoadMore hasMore={!!q.hasNextPage} loading={q.isFetchingNextPage} onLoadMore={() => void q.fetchNextPage()} />
          </>
        )}
      </section>
    </div>
  );
}
