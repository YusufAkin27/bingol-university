// SAYFA: Askı önerileri (/admin/moderation/suspensions)
// API: GET /api/admin/moderation/suspend-recommendations?status=OPEN&cursor=&size= ,
//      POST /api/admin/moderation/suspend-recommendations/{id}/accept (kullanıcıyı askıya alır) | /dismiss (api/moderation.ts).
// Öneri, kısa sürede tekrarlanan ihlallerden (strike) otomatik üretilir; karar yöneticiye aittir.
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { moderationApi, qk } from '../../api';
import type { SuspendRecommendation } from '../../api/types';
import {
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  LoadMore,
  PageHeader,
  Skeleton,
  Tabs,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import styles from './moderation/moderation.module.css';

type Status = SuspendRecommendation['status'];
const STATUSES: Status[] = ['OPEN', 'ACCEPTED', 'DISMISSED'];

export default function SuspendRecommendationsPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.suspend.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<Status>('OPEN');
  const [accepting, setAccepting] = useState<SuspendRecommendation | null>(null);

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.recommendations(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listSuspendRecommendations({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];

  const onError = (e: unknown) => {
    toast.error(adminErrorMessage(i18n, e));
    setAccepting(null);
    void qc.invalidateQueries({ queryKey: qk.moderation.all });
  };
  const accept = useMutation({
    mutationFn: (r: SuspendRecommendation) => moderationApi.acceptRecommendation(r.id),
    onSuccess: () => {
      toast.success(t('admin.suspend.toast.accepted'));
      setAccepting(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
      void qc.invalidateQueries({ queryKey: qk.users.all });
    },
    onError,
  });
  const dismiss = useMutation({
    mutationFn: (r: SuspendRecommendation) => moderationApi.dismissRecommendation(r.id),
    onSuccess: () => {
      toast.success(t('admin.suspend.toast.dismissed'));
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
    onError,
  });

  return (
    <>
      <PageHeader title={t('admin.suspend.title')} />
      <Tabs
        label={t('admin.suspend.tabs')}
        value={status}
        onChange={(id) => setStatus(id as Status)}
        tabs={STATUSES.map((s) => ({ id: s, label: t(`admin.suspend.status.${s}`) }))}
      />
      <div className={styles.stack}>
        {query.isError ? (
          <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
        ) : query.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="shield" title={t('admin.suspend.empty.title')} description={t('admin.suspend.empty.hint')} />
        ) : (
          <>
            <ul className={styles.rowList}>
              {items.map((r) => (
                <li key={r.id} className={styles.item}>
                  <div className={styles.itemHead}>
                    <Link to={paths.admin.user(r.userId)}>{t('admin.suspend.user', { id: r.userId })}</Link>
                    <Badge tone="danger">{t('admin.suspend.strikes', { n: formatNumber(r.strikeCount) })}</Badge>
                    <span className={styles.spacer} />
                    <span className={styles.muted}>{formatDateTime(r.createdAt)}</span>
                  </div>
                  {r.status === 'OPEN' && (
                    <div className={styles.actions}>
                      <Button
                        variant="secondary"
                        loading={dismiss.isPending && dismiss.variables?.id === r.id}
                        onClick={() => dismiss.mutate(r)}
                      >
                        {t('admin.suspend.dismiss')}
                      </Button>
                      <Button variant="danger" onClick={() => setAccepting(r)}>
                        {t('admin.suspend.accept')}
                      </Button>
                    </div>
                  )}
                </li>
              ))}
            </ul>
            <LoadMore
              hasMore={!!query.hasNextPage}
              loading={query.isFetchingNextPage}
              onLoadMore={() => void query.fetchNextPage()}
            />
          </>
        )}
      </div>
      <ConfirmDialog
        open={!!accepting}
        onClose={() => setAccepting(null)}
        onConfirm={() => accepting && accept.mutate(accepting)}
        loading={accept.isPending}
        danger
        title={t('admin.suspend.confirmTitle')}
        message={t('admin.suspend.confirmBody', { id: accepting?.userId ?? '' })}
        confirmLabel={t('admin.suspend.accept')}
      />
    </>
  );
}
