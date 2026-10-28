// SAYFA: Topluluklar (/admin/communities) - onay kuyruğu
// API: GET /api/admin/communities?status=&cursor=&size= , POST /api/admin/communities/{id}/approve|reject {reason} (api/approvals.ts)
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AuditTrail } from '../../components/admin/guard';
import { approveCommunity, listCommunities, rejectCommunity } from '../../api/approvals';
import { qk } from '../../api/queryKeys';
import type { CommunityStatus, CommunityView } from '../../api/types';
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  ErrorState,
  Icon,
  LoadMore,
  PageHeader,
  Skeleton,
  StatusPill,
  Tabs,
  toneFor,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { DetailList, RejectDialog } from './community/ReviewParts';
import styles from './community/review.module.css';

const STATUSES: CommunityStatus[] = ['PENDING_REVIEW', 'ACTIVE', 'REJECTED', 'HIDDEN'];

/** `embedded`: Kulüpler sayfasının "Onay kuyruğu" sekmesi içinde; başlığı üst sayfa çizer. */
export default function CommunitiesAdminPage({ embedded = false }: { embedded?: boolean } = {}) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  usePageTitle(t('admin.communities.title'));

  const [params, setParams] = useSearchParams();
  const param = params.get('status') as CommunityStatus | null;
  const status: CommunityStatus = param && STATUSES.includes(param) ? param : 'PENDING_REVIEW';
  const [selected, setSelected] = useState<CommunityView | null>(null);
  const [rejecting, setRejecting] = useState<CommunityView | null>(null);

  const query = useInfiniteQuery({
    queryKey: [...qk.communities.list(status), 'pages'],
    queryFn: ({ pageParam }) => listCommunities({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];

  const done = (msgKey: 'admin.review.toast.approved' | 'admin.review.toast.rejected', name: string) => {
    toast.success(t(msgKey, { name }));
    setSelected(null);
    setRejecting(null);
    void qc.invalidateQueries({ queryKey: qk.communities.all });
  };
  const approve = useMutation({
    mutationFn: (c: CommunityView) => approveCommunity(c.id),
    onSuccess: (_d, c) => done('admin.review.toast.approved', c.name),
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      void qc.invalidateQueries({ queryKey: qk.communities.all });
    },
  });
  const reject = useMutation({
    mutationFn: (v: { c: CommunityView; reason: string }) => rejectCommunity(v.c.id, v.reason || undefined),
    onSuccess: (_d, v) => done('admin.review.toast.rejected', v.c.name),
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRejecting(null);
      void qc.invalidateQueries({ queryKey: qk.communities.all });
    },
  });

  const tabs = STATUSES.map((s) => ({ id: s, label: t(`admin.communities.status.${s}`) }));
  const pending = status === 'PENDING_REVIEW';

  function actionsFor(c: CommunityView, size: 'sm' | 'md') {
    return (
      <>
        <Button
          size={size}
          variant="secondary"
          disabled={approve.isPending}
          onClick={(e) => {
            e.stopPropagation();
            setRejecting(c);
          }}
        >
          {t('admin.review.reject')}
        </Button>
        <Button
          size={size}
          loading={approve.isPending && approve.variables?.id === c.id}
          onClick={(e) => {
            e.stopPropagation();
            approve.mutate(c);
          }}
          leftIcon={<Icon name="check" size={16} />}
        >
          {t('admin.review.approve')}
        </Button>
      </>
    );
  }

  return (
    <div>
      {!embedded && <PageHeader title={t('admin.communities.title')} />}
      <div className={styles.tabsWrap}>
        <Tabs
          tabs={tabs}
          value={status}
          label={t('admin.communities.tabs')}
          onChange={(id) => {
            const next = new URLSearchParams(params);
            if (id === 'PENDING_REVIEW') next.delete('status');
            else next.set('status', id);
            setParams(next, { replace: true });
          }}
        />
      </div>

      {query.isError ? (
        <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
      ) : query.isLoading ? (
        <div className={styles.list} aria-busy="true">
          {[0, 1, 2].map((i) => (
            <div key={i} className={styles.item}>
              <div className={styles.main}>
                <Skeleton width="40%" height="1.4em" />
                <Skeleton width="85%" />
                <Skeleton width="55%" />
              </div>
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon="community"
          title={t(pending ? 'admin.communities.empty.pending.title' : 'admin.communities.empty.title')}
          description={t(pending ? 'admin.communities.empty.pending.hint' : 'admin.communities.empty.hint')}
        />
      ) : (
        <>
          <ul className={styles.list} aria-label={t('admin.communities.title')} style={{ listStyle: 'none', padding: 0 }}>
            {items.map((c) => (
              <li
                key={c.id}
                className={styles.item}
                tabIndex={0}
                onClick={() => setSelected(c)}
                onKeyDown={(e) => {
                  if (e.target === e.currentTarget && (e.key === 'Enter' || e.key === ' ')) {
                    e.preventDefault();
                    setSelected(c);
                  }
                }}
              >
                <div className={styles.main}>
                  <div className={styles.titleRow}>
                    <h2 className={styles.name}>{c.name}</h2>
                    {c.category && <Badge tone="info">{c.category}</Badge>}
                    <Badge>{t(`admin.communities.policy.${c.joinPolicy}`)}</Badge>
                    <Badge tone={c.visibility === 'PRIVATE' ? 'warning' : 'neutral'}>
                      {t(`admin.communities.visibility.${c.visibility}`)}
                    </Badge>
                  </div>
                  {c.description ? (
                    <p className={styles.desc}>{c.description}</p>
                  ) : (
                    <p className={styles.descEmpty}>{t('admin.communities.noDescription')}</p>
                  )}
                  <div className={styles.meta}>
                    <span>
                      {t('admin.communities.owner')}: <span className={`${styles.metaStrong} ltr`}>#{c.ownerId}</span>
                    </span>
                    <span>
                      {t('admin.communities.members')}: {formatNumber(c.memberCount)}
                    </span>
                    <span>{formatDateTime(c.createdAt)}</span>
                  </div>
                </div>
                <div className={styles.actions}>
                  {pending ? (
                    actionsFor(c, 'sm')
                  ) : (
                    <StatusPill tone={toneFor(c.status)}>{t(`admin.communities.status.${c.status}`)}</StatusPill>
                  )}
                </div>
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

      <Drawer
        open={!!selected}
        onClose={() => setSelected(null)}
        title={selected?.name ?? ''}
        footer={
          selected && selected.status === 'PENDING_REVIEW' ? (
            <div className={styles.drawerFoot}>{actionsFor(selected, 'md')}</div>
          ) : undefined
        }
      >
        {selected && (
          <>
            <StatusPill tone={toneFor(selected.status)}>{t(`admin.communities.status.${selected.status}`)}</StatusPill>
            <p className={styles.drawerDesc}>{selected.description || t('admin.communities.noDescription')}</p>
            <DetailList
              items={[
                { label: t('admin.communities.category'), value: selected.category || '—' },
                { label: t('admin.communities.owner'), value: <span className="ltr">#{selected.ownerId}</span> },
                { label: t('admin.communities.policy'), value: t(`admin.communities.policy.${selected.joinPolicy}`) },
                {
                  label: t('admin.communities.visibility'),
                  value: t(`admin.communities.visibility.${selected.visibility}`),
                },
                { label: t('admin.communities.members'), value: formatNumber(selected.memberCount) },
                { label: t('admin.communities.slug'), value: <span className="ltr">{selected.slug}</span> },
                { label: t('admin.communities.created'), value: formatDateTime(selected.createdAt) },
              ]}
            />
            <AuditTrail targetType="COMMUNITY" targetId={selected.id} />
          </>
        )}
      </Drawer>

      {rejecting && (
        <RejectDialog
          open
          name={rejecting.name}
          loading={reject.isPending}
          onClose={() => setRejecting(null)}
          onConfirm={(reason) => reject.mutate({ c: rejecting, reason })}
        />
      )}
    </div>
  );
}
