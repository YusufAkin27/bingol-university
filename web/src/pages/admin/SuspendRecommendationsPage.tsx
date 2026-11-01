// SAYFA: Askı önerileri (/admin/moderation/suspensions)
// API: GET /api/admin/moderation/suspend-recommendations?status=OPEN&cursor=&size= ,
//      POST /api/admin/moderation/suspend-recommendations/{id}/accept (kullanıcıyı askıya alır) | /dismiss (api/moderation.ts).
// Öneri, kısa sürede tekrarlanan ihlallerden (strike) otomatik üretilir; karar yöneticiye aittir.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { moderationApi, qk } from '../../api';
import type { SuspendRecommendation } from '../../api/types';
import {
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  Insight,
  LoadMore,
  PageHeader,
  Skeleton,
  Tabs,
  useKitFormat,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { UserLabel } from './people/UserLabel';
import people from './people/people.module.css';
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
  const [dismissing, setDismissing] = useState<SuspendRecommendation | null>(null);
  const kit = useKitFormat();

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.recommendations(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listSuspendRecommendations({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];
  // Sekmede "Açık (3)": açık önerilerin sayısı (ilk sayfa; sonrası varsa 50+ olabilir)
  const openCount = useQuery({
    queryKey: [...qk.moderation.recommendations('OPEN'), 'count'],
    queryFn: () => moderationApi.listSuspendRecommendations({ status: 'OPEN', size: 50 }),
    retry: false,
  });
  const openN = openCount.data?.items.length;
  // Sayaç yalnız ilk 50 kaydı görür: 50'ye ulaştıysa "50+" yazılır (kesin toplam backend ister)
  const openLabel = openN === undefined ? '' : openN >= 50 ? '50+' : formatNumber(openN);
  const maxStrikes = items.reduce((m, r) => Math.max(m, r.strikeCount), 0);

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
      setDismissing(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
    onError,
  });

  return (
    <>
      <PageHeader title={t('admin.suspend.title')} />
      <p className={people.hint} style={{ marginBlockEnd: 'var(--space-3)' }} data-search-anchor="sus-explain">
        {t('admin.v2p.sus.explain')}
      </p>
      {status === 'OPEN' && items.length > 0 && (
        <Insight
          tone="warn"
          parts={t(query.hasNextPage ? 'admin.v2p.sus.sentenceMore' : 'admin.v2p.sus.sentence', {
            n: formatNumber(items.length),
            max: formatNumber(maxStrikes),
          })}
        />
      )}
      <div data-search-anchor="sus-tabs">
        <Tabs
          label={t('admin.suspend.tabs')}
          value={status}
          onChange={(id) => setStatus(id as Status)}
          tabs={STATUSES.map((s) => ({
            id: s,
            label:
              s === 'OPEN' && openN !== undefined
                ? t('admin.v2p.sus.tabCount', { label: t(`admin.suspend.status.${s}`), n: openLabel })
                : t(`admin.suspend.status.${s}`),
          }))}
        />
      </div>
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
                    <UserLabel userId={r.userId} fallback={t('admin.suspend.user', { id: r.userId })} />
                    <span className={styles.spacer} />
                    <span className={styles.muted} title={formatDateTime(r.createdAt)}>
                      {t('admin.v2p.sus.waiting', { when: kit.relative(r.createdAt) })}
                    </span>
                  </div>
                  <p className={people.strikes}>
                    <span className={people.dots} role="img" aria-label={t('admin.suspend.strikes', { n: formatNumber(r.strikeCount) })}>
                      {Array.from({ length: Math.max(5, r.strikeCount) }, (_, i) => (
                        <span key={i} className={i < r.strikeCount ? people.dotOn : people.dotOff} />
                      ))}
                    </span>
                    <Badge tone="danger">{t('admin.suspend.strikes', { n: formatNumber(r.strikeCount) })}</Badge>
                  </p>
                  {r.status === 'OPEN' && (
                    <div className={styles.actions}>
                      <Button
                        variant="secondary"
                        loading={dismiss.isPending && dismiss.variables?.id === r.id}
                        onClick={() => setDismissing(r)}
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
        open={!!dismissing}
        onClose={() => setDismissing(null)}
        onConfirm={() => dismissing && dismiss.mutate(dismissing)}
        loading={dismiss.isPending}
        title={t('admin.v2p.sus.dismissTitle')}
        message={t('admin.v2p.sus.dismissBody')}
        confirmLabel={t('admin.suspend.dismiss')}
      />
      <ConfirmDialog
        open={!!accepting}
        onClose={() => setAccepting(null)}
        onConfirm={() => accepting && accept.mutate(accepting)}
        loading={accept.isPending}
        danger
        title={t('admin.suspend.confirmTitle')}
        message={`${t('admin.suspend.confirmBody', { id: accepting?.userId ?? '' })} ${t('admin.v2p.sus.acceptConsequence')}`}
        confirmLabel={t('admin.suspend.accept')}
      />
    </>
  );
}
