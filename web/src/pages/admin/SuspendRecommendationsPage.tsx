// SAYFA: Askı önerileri (/admin/moderation/suspensions)
// API: GET /api/admin/moderation/suspend-recommendations?status=OPEN&cursor=&size= ,
//      POST /api/admin/moderation/suspend-recommendations/{id}/accept (kullanıcıyı askıya alır) | /dismiss (api/moderation.ts).
// Öneri, kısa sürede tekrarlanan ihlallerden (strike) otomatik üretilir; karar yöneticiye aittir.
// Mod1: bekleyen kuyruk yaş + ihlal sayısına göre sıralanır (acil üstte); toplu yoksay/askıya al + klavye (J/K/X/A/R).
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { moderationApi, qk } from '../../api';
import type { SuspendRecommendation } from '../../api/types';
import {
  Badge,
  BulkBar,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  LoadMore,
  PageHeader,
  RankedBars,
  Skeleton,
  StatTile,
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
import { BulkRunDialog, useBatchToast } from './yaptirimMod1/BulkRunDialog';
import { useGt } from './yaptirimMod1/dict';
import { PriorityBadge } from './yaptirimMod1/PriorityBadge';
import { QueueAgePanel } from './yaptirimMod1/QueueAgePanel';
import {
  ageMs,
  countUrgentByAge,
  fetchQueue,
  maxUrgency,
  oldestAgeMs,
  sortByPriority,
  urgencyOfAge,
  urgencyOfStrikes,
  urgencyRank,
  type Urgency,
} from './yaptirimMod1/queueLogic';
import { ShortcutBar } from './yaptirimMod1/ShortcutBar';
import { useQueueKeys } from './yaptirimMod1/useQueueKeys';
import { waitText } from './yaptirimMod1/waitText';
import q from './yaptirimMod1/yaptirim.module.css';

type Status = SuspendRecommendation['status'];
const STATUSES: Status[] = ['OPEN', 'ACCEPTED', 'DISMISSED'];
const PAGE = 25;
/** Askı kabulü saatte en çok 20 (yıkıcı işlem sınırı, docs/ADMIN_API.md): toplu kabul bu kadarla sınırlıdır. */
const ACCEPT_BULK_MAX = 20;

/** Öncelik: bekleme süresi ile ihlal sayısından hangisi daha aciliyse o. */
const urgencyOfRec = (r: SuspendRecommendation, now: number): Urgency =>
  maxUrgency(urgencyOfAge(ageMs(r.createdAt, now)), urgencyOfStrikes(r.strikeCount));

export default function SuspendRecommendationsPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const gt = useGt();
  usePageTitle(t('admin.suspend.title'));
  const toast = useToast();
  const batchToast = useBatchToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<Status>('OPEN');
  const [accepting, setAccepting] = useState<SuspendRecommendation | null>(null);
  const [dismissing, setDismissing] = useState<SuspendRecommendation | null>(null);
  const [bulk, setBulk] = useState<'accept' | 'dismiss' | null>(null);
  const [selected, setSelected] = useState<ReadonlySet<number>>(new Set());
  const [shown, setShown] = useState(PAGE);
  const kit = useKitFormat();

  const queue = useQuery({
    queryKey: [...qk.moderation.recommendations('OPEN'), 'queue'],
    queryFn: () =>
      fetchQueue((cursor: number | null) => moderationApi.listSuspendRecommendations({ status: 'OPEN', cursor, size: 50 })),
    retry: false,
  });
  const closed = useInfiniteQuery({
    queryKey: [...qk.moderation.recommendations(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listSuspendRecommendations({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
    enabled: status !== 'OPEN',
  });

  const now = queue.dataUpdatedAt || Date.now();
  const open = queue.data?.items;
  const truncated = queue.data?.truncated === true;
  const urgencyOf = (r: SuspendRecommendation): Urgency => urgencyOfRec(r, now);
  const sorted = useMemo(
    () => sortByPriority(open ?? [], (r) => ({ urgency: urgencyOfRec(r, now), weight: r.strikeCount, createdAt: r.createdAt })),
    [open, now],
  );
  const dates = useMemo(() => (open ?? []).map((r) => r.createdAt), [open]);
  const openN = open?.length;
  const openLabel = openN === undefined ? '' : truncated ? `${formatNumber(openN)}+` : formatNumber(openN);
  const maxStrikes = (open ?? []).reduce((m, r) => Math.max(m, r.strikeCount), 0);
  const urgentN = (open ?? []).filter((r) => urgencyRank(urgencyOf(r)) === 2).length;
  const strikeBars = useMemo(() => {
    const m = new Map<number, number>();
    for (const r of open ?? []) m.set(r.strikeCount, (m.get(r.strikeCount) ?? 0) + 1);
    return [...m.entries()]
      .sort((a, b) => b[0] - a[0])
      .map(([k, v]) => ({ key: String(k), label: gt('admin.mod1.sus.strikeLabel', { n: formatNumber(k) }), value: v }));
  }, [open, gt, formatNumber]);

  const isOpen = status === 'OPEN';
  const items = isOpen ? sorted.slice(0, shown) : (closed.data?.pages.flatMap((p) => p.items) ?? []);
  const active = isOpen ? queue : closed;

  const toggle = (id: number) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });
  const clearSelection = () => setSelected(new Set());
  const selectedItems = sorted.filter((r) => selected.has(r.id));
  const acceptItems = selectedItems.slice(0, ACCEPT_BULK_MAX);
  const allShownSelected = items.length > 0 && items.every((r) => selected.has(r.id));

  const keys = useQueueKeys({
    count: isOpen ? items.length : 0,
    enabled: isOpen && !accepting && !dismissing && !bulk,
    onToggle: (i) => items[i] && toggle(items[i].id),
    onPrimary: (i) => items[i] && setAccepting(items[i]),
    onSecondary: (i) => items[i] && setDismissing(items[i]),
    onClear: clearSelection,
  });
  const activeId = keys.active >= 0 ? items[keys.active]?.id : undefined;
  useEffect(() => {
    if (activeId === undefined) return;
    document.getElementById(`sus-row-${activeId}`)?.scrollIntoView?.({ block: 'nearest' });
  }, [activeId]);

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

  const bulkItems = bulk === 'accept' ? acceptItems : selectedItems;

  return (
    <>
      <PageHeader title={t('admin.suspend.title')} />
      <p className={people.hint} style={{ marginBlockEnd: 'var(--space-3)' }} data-search-anchor="sus-explain">
        {t('admin.v2p.sus.explain')}
      </p>
      <div className={q.twoCols} data-search-anchor="sus-summary">
        <StatTile
          label={gt('admin.mod1.sus.tile.open')}
          value={openN === undefined ? undefined : openLabel}
          icon="lock"
          loading={queue.isLoading}
          error={queue.isError}
          onRetry={() => void queue.refetch()}
          caption={gt('admin.mod1.sus.tile.openHint')}
        />
        <StatTile
          label={gt('admin.mod1.sus.tile.max')}
          value={openN === undefined ? undefined : openN === 0 ? '–' : maxStrikes}
          unit={openN ? gt('admin.mod1.sus.unit') : undefined}
          icon="alert"
          loading={queue.isLoading}
          error={queue.isError}
          caption={gt('admin.mod1.sus.tile.maxHint')}
        />
        <StatTile
          label={gt('admin.mod1.tile.urgent')}
          value={openN === undefined ? undefined : urgentN}
          icon="clock"
          loading={queue.isLoading}
          error={queue.isError}
          caption={gt('admin.mod1.sus.tile.urgentHint', {
            oldest: waitText(oldestAgeMs(dates, now), gt, formatNumber),
            n: formatNumber(countUrgentByAge(dates, now)),
          })}
        />
      </div>
      <div className={q.twoCols}>
        <QueueAgePanel
          anchor="sus-age"
          title={gt('admin.mod1.sus.age.title')}
          noun={gt('admin.mod1.sus.noun')}
          dates={dates}
          now={now}
          truncated={truncated}
          loading={queue.isLoading}
          error={queue.isError}
          onRetry={() => void queue.refetch()}
        />
        <section className={q.panel} data-search-anchor="sus-strikes" aria-label={gt('admin.mod1.sus.strikes.title')}>
          <h2 className={q.panelTitle}>{gt('admin.mod1.sus.strikes.title')}</h2>
          <p className={q.sub}>{gt('admin.mod1.sus.strikes.hint')}</p>
          <RankedBars
            items={strikeBars}
            limit={5}
            order="desc"
            loading={queue.isLoading}
            error={queue.isError}
            onRetry={() => void queue.refetch()}
            ariaLabel={gt('admin.mod1.sus.strikes.title')}
            formatValue={(n) => gt('admin.mod1.sus.persons', { n: formatNumber(n) })}
            emptyLabel={gt('admin.mod1.sus.strikes.empty')}
          />
        </section>
      </div>
      <div data-search-anchor="sus-tabs">
        <Tabs
          label={t('admin.suspend.tabs')}
          value={status}
          onChange={(id) => {
            setStatus(id as Status);
            clearSelection();
          }}
          tabs={STATUSES.map((s) => ({
            id: s,
            label:
              s === 'OPEN' && openN !== undefined
                ? t('admin.v2p.sus.tabCount', { label: t(`admin.suspend.status.${s}`), n: openLabel })
                : t(`admin.suspend.status.${s}`),
          }))}
        />
      </div>
      {isOpen && items.length > 0 && (
        <ShortcutBar
          anchor="sus-keys"
          items={[
            { keys: 'J / K', label: gt('admin.mod1.keys.move') },
            { keys: 'X', label: gt('admin.mod1.keys.select') },
            { keys: 'A', label: gt('admin.mod1.sus.keys.accept') },
            { keys: 'R', label: gt('admin.mod1.sus.keys.dismiss') },
            { keys: 'Esc', label: gt('admin.mod1.keys.clear') },
          ]}
        />
      )}
      <div className={styles.stack} data-search-anchor="sus-list">
        {active.isError ? (
          <ErrorState description={adminErrorMessage(i18n, active.error)} onRetry={() => void active.refetch()} />
        ) : active.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="shield" title={t('admin.suspend.empty.title')} description={t('admin.suspend.empty.hint')} />
        ) : (
          <>
            {isOpen && (
              <label className={q.selectRow}>
                <input
                  type="checkbox"
                  checked={allShownSelected}
                  onChange={() => setSelected(allShownSelected ? new Set() : new Set(items.map((r) => r.id)))}
                />
                <span>{gt('admin.mod1.select.allShown', { n: formatNumber(items.length) })}</span>
              </label>
            )}
            <ul className={styles.rowList}>
              {items.map((r, idx) => {
                const isSel = selected.has(r.id);
                return (
                  <li
                    key={r.id}
                    id={`sus-row-${r.id}`}
                    className={`${styles.item} ${isSel ? q.rowSelected : ''} ${idx === keys.active && isOpen ? q.rowActive : ''}`}
                    aria-current={idx === keys.active && isOpen ? 'true' : undefined}
                  >
                    <div className={styles.itemHead}>
                      {r.status === 'OPEN' && (
                        <label className={q.rowCheck}>
                          <input
                            type="checkbox"
                            checked={isSel}
                            onChange={() => toggle(r.id)}
                            aria-label={gt('admin.mod1.select.row', { name: t('admin.suspend.user', { id: r.userId }) })}
                          />
                        </label>
                      )}
                      {r.status === 'OPEN' && <PriorityBadge urgency={urgencyOf(r)} />}
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
                );
              })}
            </ul>
            {isOpen ? (
              sorted.length > shown && (
                <div className={q.moreWrap}>
                  <Button variant="secondary" onClick={() => setShown((n) => n + PAGE)}>
                    {gt('admin.mod1.list.showMore', { n: formatNumber(sorted.length - shown) })}
                  </Button>
                </div>
              )
            ) : (
              <LoadMore
                hasMore={!!closed.hasNextPage}
                loading={closed.isFetchingNextPage}
                onLoadMore={() => void closed.fetchNextPage()}
              />
            )}
          </>
        )}
      </div>
      {isOpen && (
        <div className={q.bulkSticky} data-search-anchor="sus-bulk">
          <BulkBar count={selected.size} onClear={clearSelection}>
            <Button size="sm" variant="secondary" onClick={() => setBulk('dismiss')}>
              {gt('admin.mod1.sus.bulk.dismiss')}
            </Button>
            <Button size="sm" variant="danger" onClick={() => setBulk('accept')}>
              {gt('admin.mod1.sus.bulk.accept')}
            </Button>
          </BulkBar>
        </div>
      )}
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
      <BulkRunDialog
        open={bulk !== null}
        onClose={() => setBulk(null)}
        danger={bulk === 'accept'}
        title={gt(bulk === 'accept' ? 'admin.mod1.sus.bulkAcceptTitle' : 'admin.mod1.sus.bulkDismissTitle', {
          n: formatNumber(bulkItems.length),
        })}
        message={
          bulk === 'accept'
            ? `${gt('admin.mod1.sus.bulkAcceptBody', { n: formatNumber(bulkItems.length) })} ${
                selectedItems.length > ACCEPT_BULK_MAX
                  ? gt('admin.mod1.sus.bulkAcceptCap', { max: formatNumber(ACCEPT_BULK_MAX) })
                  : ''
              }`
            : gt('admin.mod1.sus.bulkDismissBody', { n: formatNumber(bulkItems.length) })
        }
        confirmLabel={gt(bulk === 'accept' ? 'admin.mod1.sus.bulkAcceptBtn' : 'admin.mod1.sus.bulkDismissBtn', {
          n: formatNumber(bulkItems.length),
        })}
        items={bulkItems}
        runOne={(r) =>
          bulk === 'accept' ? moderationApi.acceptRecommendation(r.id) : moderationApi.dismissRecommendation(r.id)
        }
        onDone={(outcome) => {
          batchToast(outcome);
          setBulk(null);
          clearSelection();
          void qc.invalidateQueries({ queryKey: qk.moderation.all });
          if (bulk === 'accept') void qc.invalidateQueries({ queryKey: qk.users.all });
        }}
      />
    </>
  );
}
