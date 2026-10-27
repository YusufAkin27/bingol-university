// SAYFA: Etkinlikler (/admin/events) - onay kuyruğu
// API: GET /api/admin/events?status=&cursor=&size= , POST /api/admin/events/{id}/approve|reject {reason} (api/approvals.ts)
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { approveEvent, listEvents, rejectEvent } from '../../api/approvals';
import { qk } from '../../api/queryKeys';
import type { EventStatus, EventView } from '../../api/types';
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
import { eventTiming, relativeStart } from './events/lib';

const STATUSES: EventStatus[] = ['PENDING_REVIEW', 'ACTIVE', 'REJECTED', 'CANCELLED', 'HIDDEN'];

export default function EventsAdminPage() {
  const i18n = useI18n();
  const { t, locale, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  usePageTitle(t('admin.events.title'));

  const [params, setParams] = useSearchParams();
  const param = params.get('status') as EventStatus | null;
  const status: EventStatus = param && STATUSES.includes(param) ? param : 'PENDING_REVIEW';
  const [selected, setSelected] = useState<EventView | null>(null);
  const [rejecting, setRejecting] = useState<EventView | null>(null);

  const query = useInfiniteQuery({
    queryKey: [...qk.events.list(status), 'pages'],
    queryFn: ({ pageParam }) => listEvents({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];

  const done = (key: 'admin.review.toast.approved' | 'admin.review.toast.rejected', name: string) => {
    toast.success(t(key, { name }));
    setSelected(null);
    setRejecting(null);
    void qc.invalidateQueries({ queryKey: qk.events.all });
  };
  const approve = useMutation({
    mutationFn: (e: EventView) => approveEvent(e.id),
    onSuccess: (_d, e) => done('admin.review.toast.approved', e.title),
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      void qc.invalidateQueries({ queryKey: qk.events.all });
    },
  });
  const reject = useMutation({
    mutationFn: (v: { e: EventView; reason: string }) => rejectEvent(v.e.id, v.reason || undefined),
    onSuccess: (_d, v) => done('admin.review.toast.rejected', v.e.title),
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRejecting(null);
      void qc.invalidateQueries({ queryKey: qk.events.all });
    },
  });

  const tabs = STATUSES.map((s) => ({ id: s, label: t(`admin.events.status.${s}`) }));
  const pending = status === 'PENDING_REVIEW';
  const now = new Date();

  function actionsFor(ev: EventView, size: 'sm' | 'md') {
    return (
      <>
        <Button
          size={size}
          variant="secondary"
          disabled={approve.isPending}
          onClick={(e) => {
            e.stopPropagation();
            setRejecting(ev);
          }}
        >
          {t('admin.review.reject')}
        </Button>
        <Button
          size={size}
          loading={approve.isPending && approve.variables?.id === ev.id}
          onClick={(e) => {
            e.stopPropagation();
            approve.mutate(ev);
          }}
          leftIcon={<Icon name="check" size={16} />}
        >
          {t('admin.review.approve')}
        </Button>
      </>
    );
  }

  function timingBadge(ev: EventView) {
    if (ev.status !== 'PENDING_REVIEW' && ev.status !== 'ACTIVE') return null;
    const timing = eventTiming(ev.startsAt, now);
    if (timing === 'past') return <Badge tone="danger">{t('admin.events.timing.past')}</Badge>;
    if (timing === 'soon')
      return <Badge tone="warning">{t('admin.events.timing.soon', { when: relativeStart(ev.startsAt, locale, now) })}</Badge>;
    return null;
  }

  return (
    <div>
      <PageHeader title={t('admin.events.title')} />
      <div className={styles.tabsWrap}>
        <Tabs
          tabs={tabs}
          value={status}
          label={t('admin.events.tabs')}
          onChange={(id) => setParams(id === 'PENDING_REVIEW' ? {} : { status: id }, { replace: true })}
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
          icon="calendar"
          title={t(pending ? 'admin.events.empty.pending.title' : 'admin.events.empty.title')}
          description={t(pending ? 'admin.events.empty.pending.hint' : 'admin.events.empty.hint')}
        />
      ) : (
        <>
          <ul className={styles.list} aria-label={t('admin.events.title')} style={{ listStyle: 'none', padding: 0 }}>
            {items.map((ev) => {
              const timing = ev.status === 'PENDING_REVIEW' || ev.status === 'ACTIVE' ? eventTiming(ev.startsAt, now) : 'later';
              return (
                <li
                  key={ev.id}
                  className={`${styles.item} ${timing === 'past' ? styles.danger : timing === 'soon' ? styles.warn : ''}`}
                  tabIndex={0}
                  onClick={() => setSelected(ev)}
                  onKeyDown={(e) => {
                    if (e.target === e.currentTarget && (e.key === 'Enter' || e.key === ' ')) {
                      e.preventDefault();
                      setSelected(ev);
                    }
                  }}
                >
                  <div className={styles.main}>
                    <div className={styles.titleRow}>
                      <h2 className={styles.name}>{ev.title}</h2>
                      {timingBadge(ev)}
                      {ev.communityName && <Badge tone="info">{ev.communityName}</Badge>}
                    </div>
                    {ev.description ? (
                      <p className={styles.desc}>{ev.description}</p>
                    ) : (
                      <p className={styles.descEmpty}>{t('admin.events.noDescription')}</p>
                    )}
                    <div className={styles.meta}>
                      <span className={styles.metaStrong}>
                        <Icon name="calendar" size={14} />
                        {formatDateTime(ev.startsAt)}
                      </span>
                      <span>
                        <Icon name="pin" size={14} />
                        {ev.location || t('admin.events.noLocation')}
                      </span>
                      <span>
                        {t('admin.events.capacity')}:{' '}
                        {ev.capacity === null ? t('admin.events.unlimited') : formatNumber(ev.capacity)}
                      </span>
                      <span>
                        {t('admin.events.organizer')}: {ev.organizerName || `#${ev.createdBy}`}
                      </span>
                    </div>
                  </div>
                  <div className={styles.actions}>
                    {pending ? (
                      actionsFor(ev, 'sm')
                    ) : (
                      <StatusPill tone={toneFor(ev.status)}>{t(`admin.events.status.${ev.status}`)}</StatusPill>
                    )}
                  </div>
                </li>
              );
            })}
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
        title={selected?.title ?? ''}
        footer={
          selected && selected.status === 'PENDING_REVIEW' ? (
            <div className={styles.drawerFoot}>{actionsFor(selected, 'md')}</div>
          ) : undefined
        }
      >
        {selected && (
          <>
            <div className={styles.titleRow}>
              <StatusPill tone={toneFor(selected.status)}>{t(`admin.events.status.${selected.status}`)}</StatusPill>
              {timingBadge(selected)}
            </div>
            <p className={styles.drawerDesc}>{selected.description || t('admin.events.noDescription')}</p>
            <DetailList
              items={[
                { label: t('admin.events.starts'), value: formatDateTime(selected.startsAt) },
                { label: t('admin.events.ends'), value: formatDateTime(selected.endsAt) },
                { label: t('admin.events.location'), value: selected.location || '—' },
                {
                  label: t('admin.events.capacity'),
                  value: selected.capacity === null ? t('admin.events.unlimited') : formatNumber(selected.capacity),
                },
                { label: t('admin.events.organizer'), value: selected.organizerName || `#${selected.createdBy}` },
                { label: t('admin.events.community'), value: selected.communityName || '—' },
                { label: t('admin.events.going'), value: formatNumber(selected.goingCount) },
                { label: t('admin.events.created'), value: formatDateTime(selected.createdAt) },
              ]}
            />
          </>
        )}
      </Drawer>

      {rejecting && (
        <RejectDialog
          open
          name={rejecting.title}
          loading={reject.isPending}
          onClose={() => setRejecting(null)}
          onConfirm={(reason) => reject.mutate({ e: rejecting, reason })}
        />
      )}
    </div>
  );
}
