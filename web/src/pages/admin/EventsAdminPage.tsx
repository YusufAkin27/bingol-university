// SAYFA: Etkinlikler (/admin/events) - onay kuyruğu + moderasyon
// API: GET /api/admin/events?status=&q=&standalone=&joinPolicy=&from=&to=&cursor=&size= (SUNUCU tarafı süzme),
//      GET/PATCH /{id}, POST /{id}/approve|reject|hide|unhide|cancel, DELETE /{id}?reason= (api/adminEvents.ts, api/approvals.ts).
// Derin bağlantı: ?open=<id> ayrıntı çekmecesini açar (rapor kuyruğundan "Etkinliği aç").
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { listAdminEvents, type EventStatusFilter } from '../../api/adminEvents';
import { approveEvent, rejectEvent } from '../../api/approvals';
import { qk } from '../../api/queryKeys';
import type { EventJoinPolicy, EventView } from '../../api/types';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  Icon,
  Input,
  LoadMore,
  PageHeader,
  SearchInput,
  Select,
  Skeleton,
  StatusPill,
  Tabs,
  toneFor,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { Callout } from './campaigns/shared';
import { RejectDialog } from './community/ReviewParts';
import styles from './community/review.module.css';
import { EventDetailDrawer } from './events/EventDetailDrawer';
import { eventErrorMessage } from './events/errors';
import evStyles from './events/events.module.css';
import { EVENT_STATUS_TABS, dayBoundIso, eventTiming, relativeStart } from './events/lib';

type Scope = 'all' | 'standalone';

export default function EventsAdminPage() {
  const i18n = useI18n();
  const { t, locale, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  usePageTitle(t('admin.events.title'));

  const [params, setParams] = useSearchParams();
  const openParam = Number(params.get('open'));
  const openId = Number.isInteger(openParam) && openParam > 0 ? openParam : null;
  const statusParam = params.get('status') as EventStatusFilter | null;
  const status: EventStatusFilter =
    statusParam && EVENT_STATUS_TABS.includes(statusParam) ? statusParam : 'PENDING_REVIEW';
  const scope: Scope = params.get('scope') === 'standalone' ? 'standalone' : 'all';
  const joinParam = params.get('join');
  const joinPolicy: EventJoinPolicy | '' = joinParam === 'OPEN' || joinParam === 'APPROVAL' ? joinParam : '';
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  const [q, setQ] = useState('');
  const [rejecting, setRejecting] = useState<EventView | null>(null);

  const setView = (next: Record<string, string>) => {
    const cur: Record<string, string> = {};
    if (status !== 'PENDING_REVIEW') cur.status = status;
    if (scope !== 'all') cur.scope = scope;
    if (joinPolicy) cur.join = joinPolicy;
    if (from) cur.from = from;
    if (to) cur.to = to;
    const merged = { ...cur, ...next };
    for (const k of Object.keys(merged)) if (!merged[k]) delete merged[k];
    if (merged.status === 'PENDING_REVIEW') delete merged.status;
    if (merged.scope === 'all') delete merged.scope;
    setParams(merged, { replace: true });
  };
  const setOpen = (id: number | null) => {
    const next = new URLSearchParams(params);
    if (id === null) next.delete('open');
    else next.set('open', String(id));
    setParams(next, { replace: true });
  };

  const filters = useMemo(
    () => ({ q: q.trim(), standalone: scope === 'standalone', joinPolicy, from: dayBoundIso(from, false), to: dayBoundIso(to, true) }),
    [q, scope, joinPolicy, from, to],
  );
  const query = useInfiniteQuery({
    queryKey: [...qk.events.all, 'list', status, filters, 'pages'],
    queryFn: ({ pageParam }) =>
      listAdminEvents({
        status,
        q: filters.q,
        standalone: filters.standalone,
        joinPolicy: filters.joinPolicy || undefined,
        from: filters.from,
        to: filters.to,
        cursor: pageParam,
        size: 20,
      }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);

  const done = (key: 'admin.review.toast.approved' | 'admin.review.toast.rejected', name: string) => {
    toast.success(t(key, { name }));
    setRejecting(null);
    void qc.invalidateQueries({ queryKey: qk.events.all });
  };
  const approve = useMutation({
    mutationFn: (e: EventView) => approveEvent(e.id),
    onSuccess: (_d, e) => done('admin.review.toast.approved', e.title),
    onError: (e) => {
      toast.error(eventErrorMessage(i18n, e));
      void qc.invalidateQueries({ queryKey: qk.events.all });
    },
  });
  const reject = useMutation({
    mutationFn: (v: { e: EventView; reason: string }) => rejectEvent(v.e.id, v.reason || undefined),
    onSuccess: (_d, v) => done('admin.review.toast.rejected', v.e.title),
    onError: (e) => {
      toast.error(eventErrorMessage(i18n, e));
      setRejecting(null);
      void qc.invalidateQueries({ queryKey: qk.events.all });
    },
  });

  const tabs = EVENT_STATUS_TABS.map((s) => ({ id: s, label: t(`admin.events.status.${s}`) }));
  const scopes = (['all', 'standalone'] as const).map((k) => ({ id: k, label: t(`admin.events.scope.${k}`) }));
  const pending = status === 'PENDING_REVIEW';
  const now = new Date();

  function actionsFor(ev: EventView) {
    return (
      <>
        <Button
          size="sm"
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
          size="sm"
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
        <Tabs tabs={tabs} value={status} label={t('admin.events.tabs')} onChange={(id) => setView({ status: id })} />
      </div>
      <div className={styles.toolbar}>
        <Tabs tabs={scopes} value={scope} label={t('admin.events.scope.label')} onChange={(id) => setView({ scope: id })} />
        <SearchInput label={t('admin.events.search')} placeholder={t('admin.events.search')} onSearch={setQ} />
      </div>
      <div className={evStyles.filters}>
        <label className={evStyles.filterField}>
          {t('admin.events.filter.joinPolicy')}
          <Select value={joinPolicy} onChange={(e) => setView({ join: e.target.value })}>
            <option value="">{t('admin.events.filter.all')}</option>
            <option value="OPEN">{t('admin.events.join.OPEN')}</option>
            <option value="APPROVAL">{t('admin.events.join.APPROVAL')}</option>
          </Select>
        </label>
        <label className={evStyles.filterField}>
          {t('admin.events.filter.from')}
          <Input type="date" className="ltr" value={from} onChange={(e) => setView({ from: e.target.value })} />
        </label>
        <label className={evStyles.filterField}>
          {t('admin.events.filter.to')}
          <Input type="date" className="ltr" value={to} onChange={(e) => setView({ to: e.target.value })} />
        </label>
      </div>
      <Callout tone="info">{t('admin.events.clubRule')}</Callout>

      {query.isError ? (
        <ErrorState description={eventErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
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
                  onClick={() => setOpen(ev.id)}
                  onKeyDown={(e) => {
                    if (e.target === e.currentTarget && (e.key === 'Enter' || e.key === ' ')) {
                      e.preventDefault();
                      setOpen(ev.id);
                    }
                  }}
                >
                  <div className={styles.main}>
                    <div className={styles.titleRow}>
                      <h2 className={styles.name}>{ev.title}</h2>
                      {timingBadge(ev)}
                      {ev.communityName ? (
                        <Badge tone="info">{ev.communityName}</Badge>
                      ) : (
                        <Badge>{t('admin.events.standalone')}</Badge>
                      )}
                      {ev.joinPolicy === 'APPROVAL' && <Badge tone="warning">{t('admin.events.join.APPROVAL')}</Badge>}
                      {!!ev.pendingCount && (
                        <Badge tone="warning">{t('admin.events.pendingRequests', { n: formatNumber(ev.pendingCount) })}</Badge>
                      )}
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
                        {t('admin.events.organizer')}: {ev.organizerName || ev.organizer?.displayName || `#${ev.createdBy}`}
                      </span>
                    </div>
                  </div>
                  <div className={styles.actions}>
                    {ev.status === 'PENDING_REVIEW' ? (
                      actionsFor(ev)
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

      <EventDetailDrawer id={openId} onClose={() => setOpen(null)} />

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
