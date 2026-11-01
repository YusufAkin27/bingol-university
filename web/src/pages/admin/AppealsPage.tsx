// SAYFA: İtirazlar (/admin/moderation/appeals)
// API: GET /api/admin/moderation/appeals?status=OPEN|ACCEPTED|REJECTED&cursor=&size= , POST /api/admin/moderation/appeals/{id}/decide {accept, note} (api/moderation.ts).
// Kabul = içerik geri açılır ve ihlal iptal edilir; hata kodları ALREADY_RESOLVED / TARGET_NOT_REVERSIBLE çevrilmiş gösterilir.
// Mod1: bekleyen kuyruk 4 sayfaya kadar okunur (en eski uca ulaşmak için), acil olan üstte; toplu karar + klavye (J/K/X/A/R).
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, moderationApi, qk } from '../../api';
import type { AppealStatus, AppealView } from '../../api/types';
import {
  Badge,
  BulkBar,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  LoadMore,
  Modal,
  PageHeader,
  RankedBars,
  Skeleton,
  StatTile,
  StatusPill,
  Tabs,
  Textarea,
  useKitFormat,
  useToast,
} from '../../components/ui';
import { ReasonField } from '../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../components/admin/guard/match';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import { UserLabel } from './people/UserLabel';
import people from './people/people.module.css';
import styles from './moderation/moderation.module.css';
import { useBatchToast } from './yaptirimMod1/BulkRunDialog';
import { useGt } from './yaptirimMod1/dict';
import { PriorityBadge } from './yaptirimMod1/PriorityBadge';
import { QueueAgePanel } from './yaptirimMod1/QueueAgePanel';
import {
  ageMs,
  countUrgentByAge,
  fetchQueue,
  oldestAgeMs,
  runBatch,
  sortByPriority,
  urgencyOfAge,
} from './yaptirimMod1/queueLogic';
import { ShortcutBar } from './yaptirimMod1/ShortcutBar';
import { useQueueKeys } from './yaptirimMod1/useQueueKeys';
import { waitText } from './yaptirimMod1/waitText';
import q from './yaptirimMod1/yaptirim.module.css';

const STATUSES: AppealStatus[] = ['OPEN', 'ACCEPTED', 'REJECTED'];
const NOTE_MAX = 500;
const PAGE = 25;

interface Deciding {
  items: AppealView[];
  accept: boolean;
}

export default function AppealsPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const gt = useGt();
  const kit = useKitFormat();
  usePageTitle(t('admin.appeals.title'));
  const toast = useToast();
  const batchToast = useBatchToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<AppealStatus>('OPEN');
  const [deciding, setDeciding] = useState<Deciding | null>(null);
  const [note, setNote] = useState('');
  // W1-B (T-013): karar islem gerekcesi ister (X-Admin-Reason); `note` kullaniciya giden istege bagli nottan ayridir.
  const [why, setWhy] = useState('');
  const [selected, setSelected] = useState<ReadonlySet<number>>(new Set());
  const [shown, setShown] = useState(PAGE);

  // Bekleyen kuyruk: 4 sayfaya kadar okunur; böylece en eski kayıt ve yaş dağılımı gerçek uçtan hesaplanır.
  const queue = useQuery({
    queryKey: [...qk.moderation.appeals('OPEN'), 'queue'],
    queryFn: () => fetchQueue((cursor: number | null) => moderationApi.listAppeals({ status: 'OPEN', cursor, size: 50 })),
    retry: false,
  });
  // Kapanmış sekmeler eskisi gibi imleçle sayfalanır
  const closed = useInfiniteQuery({
    queryKey: [...qk.moderation.appeals(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listAppeals({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
    enabled: status !== 'OPEN',
  });

  const now = queue.dataUpdatedAt || Date.now();
  const open = queue.data?.items;
  const truncated = queue.data?.truncated === true;
  const sorted = useMemo(
    () =>
      sortByPriority(open ?? [], (a) => ({
        urgency: urgencyOfAge(ageMs(a.createdAt, now)),
        weight: 0,
        createdAt: a.createdAt,
      })),
    [open, now],
  );
  const dates = useMemo(() => (open ?? []).map((a) => a.createdAt), [open]);
  const openN = open?.length;
  const openLabel = openN === undefined ? '' : truncated ? `${formatNumber(openN)}+` : formatNumber(openN);
  const urgentN = countUrgentByAge(dates, now);
  const typeBars = useMemo(() => {
    const m = new Map<string, number>();
    for (const a of open ?? []) m.set(a.targetType, (m.get(a.targetType) ?? 0) + 1);
    return [...m.entries()].map(([k, v]) => ({ key: k, label: td(`admin.reports.targetType.${k}`, k), value: v }));
  }, [open, td]);

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
  const selectedItems = sorted.filter((a) => selected.has(a.id));
  const allShownSelected = items.length > 0 && items.every((a) => selected.has(a.id));

  const openDecision = (list: AppealView[], accept: boolean) => {
    if (list.length === 0) return;
    setWhy('');
    setDeciding({ items: list, accept });
  };

  const keys = useQueueKeys({
    count: isOpen ? items.length : 0,
    enabled: isOpen && !deciding,
    onToggle: (i) => items[i] && toggle(items[i].id),
    onPrimary: (i) => items[i] && openDecision([items[i]], true),
    onSecondary: (i) => items[i] && openDecision([items[i]], false),
    onClear: clearSelection,
  });
  const activeId = keys.active >= 0 ? items[keys.active]?.id : undefined;
  useEffect(() => {
    if (activeId === undefined) return;
    document.getElementById(`apl-row-${activeId}`)?.scrollIntoView?.({ block: 'nearest' });
  }, [activeId]);

  const decide = useMutation({
    mutationFn: async (v: { items: AppealView[]; accept: boolean; note: string; why: string }) => {
      const send = (a: AppealView) => moderationApi.decideAppeal(a.id, v.accept, v.note.trim(), { reason: v.why });
      if (v.items.length === 1) {
        await send(v.items[0]);
        return null;
      }
      return runBatch(v.items, send);
    },
    onSuccess: (outcome, v) => {
      if (outcome) batchToast(outcome);
      else toast.success(t(v.accept ? 'admin.appeals.toast.accepted' : 'admin.appeals.toast.rejected'));
      setDeciding(null);
      setNote('');
      setWhy('');
      clearSelection();
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setDeciding(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
  });

  const bulkN = deciding?.items.length ?? 0;
  const accepting = deciding?.accept === true;

  return (
    <>
      <PageHeader
        title={t('admin.appeals.title')}
        actions={
          <CsvButton filename={csvName('itirazlar')} fetcher={() => modAdminApi.exportAppealsCsv({ status })} />
        }
      />
      <p className={people.hint} style={{ marginBlockEnd: 'var(--space-3)' }} data-search-anchor="apl-explain">
        {t('admin.v2p.apl.explain')}
      </p>
      <div className={q.twoCols} data-search-anchor="apl-summary">
        <StatTile
          label={gt('admin.mod1.apl.tile.open')}
          value={openN === undefined ? undefined : openLabel}
          icon="flag"
          loading={queue.isLoading}
          error={queue.isError}
          onRetry={() => void queue.refetch()}
          caption={gt('admin.mod1.apl.tile.openHint')}
        />
        <StatTile
          label={gt('admin.mod1.tile.oldest')}
          value={openN === undefined ? undefined : openN === 0 ? '–' : waitText(oldestAgeMs(dates, now), gt, formatNumber)}
          icon="clock"
          loading={queue.isLoading}
          error={queue.isError}
          caption={gt('admin.mod1.apl.tile.oldestHint')}
        />
        <StatTile
          label={gt('admin.mod1.tile.urgent')}
          value={openN === undefined ? undefined : urgentN}
          icon="alert"
          loading={queue.isLoading}
          error={queue.isError}
          caption={gt('admin.mod1.tile.urgentHint')}
        />
      </div>
      <div className={q.twoCols}>
        <QueueAgePanel
          anchor="apl-age"
          title={gt('admin.mod1.apl.age.title')}
          noun={gt('admin.mod1.apl.noun')}
          dates={dates}
          now={now}
          truncated={truncated}
          loading={queue.isLoading}
          error={queue.isError}
          onRetry={() => void queue.refetch()}
        />
        <section className={q.panel} data-search-anchor="apl-types" aria-label={gt('admin.mod1.apl.types.title')}>
          <h2 className={q.panelTitle}>{gt('admin.mod1.apl.types.title')}</h2>
          <p className={q.sub}>{gt('admin.mod1.apl.types.hint')}</p>
          <RankedBars
            items={typeBars}
            limit={5}
            showShare
            loading={queue.isLoading}
            error={queue.isError}
            onRetry={() => void queue.refetch()}
            ariaLabel={gt('admin.mod1.apl.types.title')}
            emptyLabel={gt('admin.mod1.apl.types.empty')}
          />
        </section>
      </div>
      <div data-search-anchor="apl-tabs">
        <Tabs
          label={t('admin.appeals.tabs')}
          value={status}
          onChange={(id) => {
            setStatus(id as AppealStatus);
            clearSelection();
          }}
          tabs={STATUSES.map((s) => ({
            id: s,
            label:
              s === 'OPEN' && openN !== undefined
                ? t('admin.v2p.sus.tabCount', { label: t(`admin.appeals.status.${s}`), n: openLabel })
                : t(`admin.appeals.status.${s}`),
          }))}
        />
      </div>
      {isOpen && items.length > 0 && (
        <ShortcutBar
          anchor="apl-keys"
          items={[
            { keys: 'J / K', label: gt('admin.mod1.keys.move') },
            { keys: 'X', label: gt('admin.mod1.keys.select') },
            { keys: 'A', label: gt('admin.mod1.apl.keys.accept') },
            { keys: 'R', label: gt('admin.mod1.apl.keys.reject') },
            { keys: 'Esc', label: gt('admin.mod1.keys.clear') },
          ]}
        />
      )}
      <div className={styles.stack} data-search-anchor="apl-list">
        {active.isError ? (
          <ErrorState description={adminErrorMessage(i18n, active.error)} onRetry={() => void active.refetch()} />
        ) : active.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="flag" title={t('admin.appeals.empty.title')} description={t('admin.appeals.empty.hint')} />
        ) : (
          <>
            {isOpen && (
              <label className={q.selectRow}>
                <input
                  type="checkbox"
                  checked={allShownSelected}
                  onChange={() =>
                    setSelected(allShownSelected ? new Set() : new Set(items.map((a) => a.id)))
                  }
                />
                <span>{gt('admin.mod1.select.allShown', { n: formatNumber(items.length) })}</span>
              </label>
            )}
            <ul className={styles.rowList}>
              {items.map((a, idx) => {
                const urgency = urgencyOfAge(ageMs(a.createdAt, now));
                const isSel = selected.has(a.id);
                return (
                  <li
                    key={a.id}
                    id={`apl-row-${a.id}`}
                    className={`${styles.item} ${isSel ? q.rowSelected : ''} ${idx === keys.active && isOpen ? q.rowActive : ''}`}
                    aria-current={idx === keys.active && isOpen ? 'true' : undefined}
                  >
                    <div className={styles.itemHead}>
                      {a.status === 'OPEN' && (
                        <label className={q.rowCheck}>
                          <input
                            type="checkbox"
                            checked={isSel}
                            onChange={() => toggle(a.id)}
                            aria-label={gt('admin.mod1.select.row', {
                              name: `${t(`admin.reports.targetType.${a.targetType}`)} #${a.targetId}`,
                            })}
                          />
                        </label>
                      )}
                      {a.status === 'OPEN' && <PriorityBadge urgency={urgency} />}
                      <Badge tone="primary">{t(`admin.reports.targetType.${a.targetType}`)}</Badge>
                      <span className={`${styles.mono} ltr`}>#{a.targetId}</span>
                      <UserLabel userId={a.userId} fallback={t('admin.appeals.user', { id: a.userId })} />
                      <span className={styles.spacer} />
                      {a.status !== 'OPEN' && (
                        <StatusPill tone={a.status === 'ACCEPTED' ? 'success' : 'danger'}>
                          {t(`admin.appeals.status.${a.status}`)}
                        </StatusPill>
                      )}
                    </div>
                    <p className={people.hint}>
                      {t('admin.v2p.apl.about', { type: t(`admin.reports.targetType.${a.targetType}`) })}{' '}
                      <Link to={paths.admin.hiddenContent}>{t('admin.v2p.apl.seeHidden')}</Link>
                    </p>
                    <p className={styles.body} dir="auto">
                      {a.message}
                    </p>
                    <p className={styles.muted}>
                      {a.status === 'OPEN' ? `${t('admin.v2p.sus.waiting', { when: kit.relative(a.createdAt) })} · ` : ''}
                      {t('admin.appeals.createdAt', { at: formatDateTime(a.createdAt) })}
                      {a.decidedAt ? ` · ${t('admin.appeals.decidedAt', { at: formatDateTime(a.decidedAt) })}` : ''}
                    </p>
                    {a.adminNote && (
                      <p className={styles.muted} dir="auto">
                        {t('admin.appeals.adminNote', { note: a.adminNote })}
                      </p>
                    )}
                    {a.status === 'OPEN' && (
                      <div className={styles.actions}>
                        <p className={people.hint} style={{ flex: '1 1 100%' }}>{t('admin.v2p.apl.outcomes')}</p>
                        <Button variant="secondary" onClick={() => openDecision([a], false)}>
                          {t('admin.appeals.reject')}
                        </Button>
                        <Button onClick={() => openDecision([a], true)}>{t('admin.appeals.accept')}</Button>
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
        <div className={q.bulkSticky} data-search-anchor="apl-bulk">
          <BulkBar count={selected.size} onClear={clearSelection}>
            <Button size="sm" variant="secondary" onClick={() => openDecision(selectedItems, false)}>
              {gt('admin.mod1.apl.bulk.reject')}
            </Button>
            <Button size="sm" onClick={() => openDecision(selectedItems, true)}>
              {gt('admin.mod1.apl.bulk.accept')}
            </Button>
          </BulkBar>
        </div>
      )}

      <Modal
        open={!!deciding}
        onClose={() => setDeciding(null)}
        title={
          bulkN > 1
            ? gt(accepting ? 'admin.mod1.apl.bulkAcceptTitle' : 'admin.mod1.apl.bulkRejectTitle', { n: formatNumber(bulkN) })
            : t(accepting ? 'admin.appeals.acceptTitle' : 'admin.appeals.rejectTitle')
        }
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeciding(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant={accepting ? 'primary' : 'danger'}
              loading={decide.isPending}
              disabled={note.length > NOTE_MAX || !isReasonValid(why, ADMIN_REASON_MIN)}
              onClick={() => deciding && decide.mutate({ items: deciding.items, accept: deciding.accept, note, why })}
            >
              {bulkN > 1
                ? gt(accepting ? 'admin.mod1.apl.bulkAcceptBtn' : 'admin.mod1.apl.bulkRejectBtn', { n: formatNumber(bulkN) })
                : t(accepting ? 'admin.appeals.accept' : 'admin.appeals.reject')}
            </Button>
          </>
        }
      >
        <p>
          {bulkN > 1
            ? gt(accepting ? 'admin.mod1.apl.bulkAcceptBody' : 'admin.mod1.apl.bulkRejectBody', { n: formatNumber(bulkN) })
            : t(accepting ? 'admin.appeals.acceptBody' : 'admin.appeals.rejectBody')}
        </p>
        <FormField label={t('admin.appeals.noteLabel')} hint={t('admin.appeals.noteHint', { max: NOTE_MAX })}>
          <Textarea rows={3} dir="auto" value={note} maxLength={NOTE_MAX + 50} onChange={(e) => setNote(e.target.value)} />
        </FormField>
        <ReasonField
          value={why}
          onChange={setWhy}
          minLength={ADMIN_REASON_MIN}
          label={t('admin.wp02.actionReason.label')}
          disabled={decide.isPending}
          focusOnMount
        />
      </Modal>
    </>
  );
}
