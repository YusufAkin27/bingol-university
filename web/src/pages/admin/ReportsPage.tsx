// SAYFA: Raporlar (/admin/reports)
// API: GET /api/admin/reports?status=&order=priority|desc|asc&targetType=&cursor=&size= (imeç tabanlı; priority modunda imeç = sayfa no),
//      POST /api/admin/reports/{id}/resolve {action,message,reasonCode}, POST /api/admin/reports/bulk-resolve, GET /api/admin/reports/reason-templates (api/reports.ts),
//      GET /api/admin/users/{id} (kullanıcı raporlarında hedef önizlemesi). Askıya alma, resolve eylemiyle (SUSPEND_USER) yapılır.
//      GET /api/admin/reports/{id} (şikâyet bağlamı: mesaj ±10, ekler, ilişkili şikâyetler; chat/ReportContext.tsx).
//      Satırda sunucu önizlemesi (preview), priority, hidden/hiddenBy, openReporters bulunur; görseller AuthImage ile yetkili çekilir.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk, reportsApi, usersApi } from '../../api';
import { useCan } from '../../auth/permissions';
import type {
  ReportOrder,
  ReportReasonCode,
  ReportResolution,
  ReportStatus,
  ReportTargetType,
  ReportView,
} from '../../api/types';
import {
  Badge,
  Card,
  Checkbox,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  Insight,
  LoadMore,
  PageHeader,
  RankedBars,
  Select,
  Skeleton,
  StatTile,
  StatusPill,
  Tabs,
  Textarea,
  toneFor,
  useIsNarrow,
  useKitFormat,
  useToast,
  PermissionButton,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import {
  MAX_MESSAGE,
  RESOLUTIONS,
  buildResolveRequest,
  countByTarget,
  moveSelection,
  targetKey,
  validateDecision,
} from './reports/reportLogic';
import { AuthImage } from './moderation/AuthImage';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import { ReportContextCard } from './chat/ReportContext';
import { TARGET_TYPES, cleanReasonCode, toggleSelected } from './moderation/modLogic';
import modStyles from './moderation/moderation.module.css';
import { BulkBar } from './reports/BulkBar';
import { ReasonFields } from './reports/ReasonFields';
import v2 from './moderation/v2.module.css';
import styles from './reports/Reports.module.css';

/** Öncelik puanı (açık raporlayan x10, gizliyse +100) yerine düz seviye: Acil / Yüksek / Normal. */
function priorityLevel(p: number): 'URGENT' | 'HIGH' | 'NORMAL' {
  return p >= 100 ? 'URGENT' : p >= 30 ? 'HIGH' : 'NORMAL';
}

function isTypingTarget(t: EventTarget | null): boolean {
  const el = t as HTMLElement | null;
  if (!el || !el.tagName) return false;
  return /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || el.isContentEditable;
}

function TargetPreview({ report }: { report: ReportView }) {
  const i18n = useI18n();
  const { t } = i18n;
  const isUser = report.targetType === 'USER';
  const q = useQuery({
    queryKey: qk.users.detail(report.targetId),
    queryFn: () => usersApi.getUser(report.targetId),
    enabled: isUser,
    retry: false,
  });
  const typeLabel = t(`admin.reports.targetType.${report.targetType}`);
  const listLink =
    report.targetType === 'COMMUNITY'
      ? paths.admin.communities
      : report.targetType === 'EVENT'
        ? `${paths.admin.events}?open=${report.targetId}`
        : report.targetType === 'FEED_POST'
          ? `${paths.admin.posts}?open=${report.targetId}`
          : null;

  return (
    <div className={styles.preview}>
      <div className={styles.previewHead}>
        <Badge tone="info">{typeLabel}</Badge>
        <span className={`${styles.mono} ltr`}>#{report.targetId}</span>
      </div>
      {isUser && q.isLoading && <Skeleton width="60%" />}
      {isUser && q.isError && <p className={styles.muted}>{t('admin.reports.preview.missing')}</p>}
      {isUser && q.data && (
        <dl className={styles.facts}>
          <div>
            <dt>{q.data.displayName}</dt>
            <dd className="ltr">{q.data.email}</dd>
          </div>
          <div>
            <dt>{t('admin.reports.preview.status')}</dt>
            <dd>
              <StatusPill tone={toneFor(q.data.status)}>{i18n.td(`admin.users.status.${q.data.status}`, q.data.status)}</StatusPill>
            </dd>
          </div>
          <div>
            <dt>{t('admin.reports.preview.against')}</dt>
            <dd>{q.data.counts.reportsAgainst}</dd>
          </div>
        </dl>
      )}
      {report.preview?.kind === 'IMAGE' && (
        <AuthImage url={report.preview.url} alt={t('admin.reports.preview.image')} />
      )}
      {report.preview?.kind === 'TEXT' && report.preview.text && (
        <p className={modStyles.body} dir="auto">
          {report.preview.text}
        </p>
      )}
      {!isUser && !report.preview && <p className={styles.muted}>{t('admin.reports.preview.none')}</p>}
      <div className={styles.previewLinks}>
        {isUser && (
          <Link to={paths.admin.user(report.targetId)} className={v2.link}>
            {t('admin.reports.preview.openUser')}
          </Link>
        )}
        {listLink && (
          <Link to={listLink} className={v2.link}>
            {t(report.targetType === 'EVENT' ? 'admin.events.openFromReport' : 'admin.reports.preview.openList')}
          </Link>
        )}
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.reports.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [status, setStatus] = useState<ReportStatus>('OPEN');
  const [order, setOrder] = useState<ReportOrder>('priority');
  const [typeFilter, setTypeFilter] = useState<ReportTargetType | ''>('');
  const [reasonCode, setReasonCode] = useState<ReportReasonCode | ''>('');
  const [bulkIds, setBulkIds] = useState<number[]>([]);
  // toplu seçim/işlem moderation.write ister; yalnız okuyabilen profilde (VIEWER) seçim kutuları gizlenir (A3-05)
  const canModerate = useCan('moderation.write');
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [action, setAction] = useState<ReportResolution>('DISMISS');
  const [message, setMessage] = useState('');
  const [touched, setTouched] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const lastIndex = useRef(0);
  // Telefonda ayrıntı tam ekran sayfa olarak açılır (R-1): listeye dön düğmesi + yapışkan karar çubuğu
  const narrow = useIsNarrow(960);
  const [sheetOpen, setSheetOpen] = useState(false);
  const kit = useKitFormat();

  const query = useInfiniteQuery({
    queryKey: qk.reports.list(status, order, typeFilter || null),
    queryFn: ({ pageParam }) =>
      reportsApi.listReports({ status, order, targetType: typeFilter || null, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const items = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);
  const templatesQ = useQuery({ queryKey: qk.reports.templates(), queryFn: reportsApi.reasonTemplates, retry: false });
  const templates = Array.isArray(templatesQ.data) ? templatesQ.data : [];
  const counts = useMemo(() => countByTarget(items), [items]);
  const index = items.findIndex((r) => r.id === selectedId);
  const selected = index >= 0 ? items[index] : null;
  if (index >= 0) lastIndex.current = index;

  // Seçili rapor kuyruktan çıktıysa (çözüldü/yenilendi) aynı sıradaki rapora geç
  useEffect(() => {
    if (query.isLoading || query.isFetching) return;
    if (items.length === 0) {
      if (selectedId !== null) setSelectedId(null);
      return;
    }
    if (!items.some((r) => r.id === selectedId)) {
      setSelectedId(items[Math.min(lastIndex.current, items.length - 1)].id);
    }
  }, [items, selectedId, query.isLoading, query.isFetching]);

  // Seçim değişince karar formu sıfırlanır
  useEffect(() => {
    setAction('DISMISS');
    setMessage('');
    setTouched(false);
    setReasonCode('');
  }, [selectedId, status]);

  const error = validateDecision(action, message);
  const needsMessage = action === 'WARN' || action === 'SUSPEND_USER';

  const resolve = useMutation({
    mutationFn: (r: ReportView) => reportsApi.resolveReport(r.id, buildResolveRequest(action, message, cleanReasonCode(reasonCode))),
    onSuccess: () => {
      toast.success(t('admin.reports.resolvedToast', { action: t(`admin.reports.resolution.${action}`) }));
      setConfirmOpen(false);
      setSheetOpen(false);
      setBulkIds((ids) => ids.filter((x) => x !== selectedId));
      void qc.invalidateQueries({ queryKey: qk.reports.all });
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setConfirmOpen(false);
      void qc.invalidateQueries({ queryKey: qk.reports.all });
    },
  });

  const requestApply = useCallback(() => {
    setTouched(true);
    if (!selected || selected.status !== 'OPEN' || validateDecision(action, message)) return;
    setConfirmOpen(true);
  }, [selected, action, message]);

  // Klavye: j/k gezin, 1-4 karar seç, Ctrl+Enter uygula
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (confirmOpen) return;
      if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        requestApply();
        return;
      }
      if (e.ctrlKey || e.metaKey || e.altKey || isTypingTarget(e.target)) return;
      if (e.key === 'j' || e.key === 'k') {
        e.preventDefault();
        const next = moveSelection(index, e.key === 'j' ? 1 : -1, items.length);
        if (next >= 0) setSelectedId(items[next].id);
      } else if (selected?.status === 'OPEN' && /^[1-4]$/.test(e.key)) {
        setAction(RESOLUTIONS[Number(e.key) - 1]);
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [confirmOpen, index, items, selected, requestApply]);

  useEffect(() => {
    document.getElementById(`report-${selectedId}`)?.scrollIntoView?.({ block: 'nearest' });
  }, [selectedId]);

  function pick(id: number) {
    setSelectedId(id);
    if (narrow) setSheetOpen(true);
  }

  const urgentCount = items.filter((r) => priorityLevel(r.priority ?? 0) === 'URGENT').length;
  const oldestAt = items.reduce<string | null>((o, r) => (!o || r.createdAt < o ? r.createdAt : o), null);
  const typeBars = [...items.reduce((m, r) => m.set(r.targetType, (m.get(r.targetType) ?? 0) + 1), new Map<string, number>())].map(
    ([k, v]) => ({ key: k, label: t(`admin.reports.targetType.${k}` as never), value: v }),
  );
  const queueMore = query.hasNextPage ? '+' : '';

  return (
    <>
      <PageHeader
        title={t('admin.reports.title')}
        actions={
          <span data-search-anchor="reports-csv">
            <CsvButton
              filename={csvName('raporlar')}
              fetcher={() => modAdminApi.exportReportsCsv({ status, targetType: typeFilter })}
            />
          </span>
        }
      />
      {status === 'OPEN' && !query.isLoading && !query.isError && items.length > 0 && (
        <section data-search-anchor="reports-summary" aria-label={t('admin.v2m.reports.summary')}>
          <div className={v2.tiles}>
            <StatTile
              label={t('admin.v2m.reports.waiting')}
              value={`${items.length}${queueMore}`}
              icon="flag"
              caption={t('admin.v2m.reports.waitingHint')}
            />
            <StatTile
              label={t('admin.v2m.reports.urgent')}
              value={urgentCount}
              icon="alert"
              caption={t('admin.v2m.reports.urgentHint')}
            />
            <StatTile
              label={t('admin.v2m.reports.oldest')}
              value={oldestAt ? kit.relative(oldestAt) : '—'}
              caption={t('admin.v2m.reports.oldestHint')}
            />
          </div>
          <Insight
            className={v2.sentence}
            tone={urgentCount > 0 ? 'warn' : 'info'}
            parts={[
              { text: t('admin.v2m.reports.sentenceWaiting', { n: String(items.length) + queueMore }), tone: urgentCount > 0 ? 'warn' : undefined },
              ' ',
              urgentCount > 0 ? t('admin.v2m.reports.sentenceUrgent', { n: String(urgentCount) }) : t('admin.v2m.reports.sentenceCalm'),
            ]}
          />
          {typeBars.length > 1 && (
            <RankedBars items={typeBars} limit={5} ariaLabel={t('admin.v2m.reports.byType')} />
          )}
        </section>
      )}
      <div data-search-anchor="reports-tabs">
      <Tabs
        label={t('admin.reports.tabs')}
        value={status}
        onChange={(id) => {
          setStatus(id as ReportStatus);
          setSelectedId(null);
          lastIndex.current = 0;
        }}
        tabs={[
          { id: 'OPEN', label: t('admin.reports.tab.OPEN') },
          { id: 'RESOLVED', label: t('admin.reports.tab.RESOLVED') },
        ]}
      />
      </div>
      <div className={modStyles.toolbar}>
        <FormField label={t('admin.reports.order.label')}>
          <Select
            data-search-anchor="reports-order"
            value={order}
            onChange={(e) => {
              setOrder(e.target.value as ReportOrder);
              setSelectedId(null);
              lastIndex.current = 0;
            }}
          >
            <option value="priority">{t('admin.reports.order.priority')}</option>
            <option value="desc">{t('admin.reports.order.desc')}</option>
            <option value="asc">{t('admin.reports.order.asc')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.reports.filter.type')}>
          <Select
            data-search-anchor="reports-type"
            value={typeFilter}
            onChange={(e) => {
              setTypeFilter(e.target.value as ReportTargetType | '');
              setSelectedId(null);
              lastIndex.current = 0;
            }}
          >
            <option value="">{t('admin.reports.filter.all')}</option>
            {TARGET_TYPES.map((tt) => (
              <option key={tt} value={tt}>
                {t(`admin.reports.targetType.${tt}`)}
              </option>
            ))}
          </Select>
        </FormField>
      </div>
      {status === 'OPEN' && canModerate && (
        <BulkBar
          ids={bulkIds}
          templates={templates}
          onClear={() => setBulkIds([])}
          onDone={() => {
            setBulkIds([]);
            void qc.invalidateQueries({ queryKey: qk.reports.all });
          }}
        />
      )}

      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : query.isLoading ? (
        <div className={styles.layout}>
          <div className={styles.list}>
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} height="5.5rem" radius="var(--radius-md)" />
            ))}
          </div>
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon="flag"
          title={t(`admin.reports.empty.${status}.title`)}
          description={t(`admin.reports.empty.${status}.hint`)}
        />
      ) : (
        <div className={styles.layout}>
          <div>
            <ul className={styles.list} aria-label={t('admin.reports.queue')} data-search-anchor="reports-queue">
              {items.map((r) => {
                const n = counts.get(targetKey(r)) ?? 1;
                const active = r.id === selectedId;
                return (
                  <li key={r.id} className={status === 'OPEN' ? modStyles.rowWrap : undefined}>
                    {status === 'OPEN' && canModerate && (
                      <Checkbox
                        label={<span className="sr-only">{t('admin.reports.bulk.select', { id: r.id })}</span>}
                        checked={bulkIds.includes(r.id)}
                        onChange={() => setBulkIds((ids) => toggleSelected(ids, r.id))}
                      />
                    )}
                    <button
                      type="button"
                      id={`report-${r.id}`}
                      className={`${styles.card} ${active ? styles.active : ''}`}
                      aria-current={active ? 'true' : undefined}
                      onClick={() => pick(r.id)}
                    >
                      <span className={styles.cardTop}>
                        {active && <Icon name="check" size={16} aria-hidden="true" className={styles.pickMark} />}
                        <Badge tone="info">{t(`admin.reports.targetType.${r.targetType}`)}</Badge>
                        <span className={`${styles.mono} ltr`}>#{r.targetId}</span>
                        <span className={styles.spacer} />
                        {n > 1 && <Badge tone="warning">{t('admin.reports.sameTarget', { n })}</Badge>}
                      </span>
                      <span className={styles.reason}>{t(`admin.reports.reason.${r.reason}`)}</span>
                      {(r.reporter?.displayName || r.reportedUser?.displayName) && (
                        <span className={styles.note} dir="auto" data-testid="report-people">
                          {r.reporter?.displayName ?? '?'} → {r.reportedUser?.displayName ?? '?'}
                        </span>
                      )}
                      {r.note && <span className={styles.note}>{r.note}</span>}
                      {r.preview?.kind === 'TEXT' && r.preview.text && (
                        <span className={styles.note} dir="auto">
                          {r.preview.text}
                        </span>
                      )}
                      <span className={styles.cardMeta}>
                        {(r.priority ?? 0) > 0 && (
                          <Badge tone={priorityLevel(r.priority) === 'URGENT' ? 'danger' : priorityLevel(r.priority) === 'HIGH' ? 'warning' : 'neutral'}>
                            <span title={t('admin.reports.priority', { n: r.priority })}>
                              {priorityLevel(r.priority) === 'URGENT' && <Icon name="alert" size={12} aria-hidden="true" />}{' '}
                              {t(`admin.v2m.reports.level.${priorityLevel(r.priority)}`)}
                            </span>
                          </Badge>
                        )}
                        {(r.openReporters ?? 0) > 0 && (
                          <Badge tone="neutral">{t('admin.v2m.reports.reporters', { n: r.openReporters })}</Badge>
                        )}
                        {r.hidden && (
                          <Badge tone="info">
                            {r.hiddenBy ? t(`admin.reports.hidden.${r.hiddenBy}`) : t('admin.reports.hidden.YES')}
                          </Badge>
                        )}
                        {r.reasonCode && (
                          <Badge tone="neutral">{i18n.td(`admin.reports.reasonCode.${r.reasonCode}`, r.reasonCode)}</Badge>
                        )}
                        {r.status === 'RESOLVED' && r.resolution ? (
                          <StatusPill tone="success">
                            {t(`admin.reports.resolution.${r.resolution}`)}
                          </StatusPill>
                        ) : null}
                        <span>{formatDateTime(r.createdAt)}</span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
            <LoadMore
              hasMore={!!query.hasNextPage}
              loading={query.isFetchingNextPage}
              onLoadMore={() => void query.fetchNextPage()}
            />
          </div>

          {(!narrow || sheetOpen) && (
          <div ref={panelRef} className={`${styles.panel} ${narrow ? styles.sheet : ''}`} data-search-anchor="reports-detail">
            {narrow && (
              <div className={styles.sheetBar}>
                <button type="button" className={styles.backBtn} onClick={() => setSheetOpen(false)}>
                  <Icon name="chevronLeft" size={20} aria-hidden="true" />
                  {t('admin.v2m.reports.back')}
                </button>
                <span className={styles.sheetTitle}>{t('admin.v2m.reports.detailTitle')}</span>
              </div>
            )}
            {selected ? (
              <>
                <Card title={t('admin.reports.preview.title')}>
                  <TargetPreview report={selected} />
                </Card>
                <ReportContextCard key={selected.id} reportId={selected.id} targetType={selected.targetType} />
                <Card title={t(`admin.reports.reason.${selected.reason}`)} data-search-anchor="reports-complaint">
                  <dl className={styles.facts}>
                    <div>
                      <dt>{t('admin.reports.reportedBy')}</dt>
                      <dd>
                        <Link to={paths.admin.user(selected.reporterId)} className={v2.link}>
                          {selected.reporter?.displayName ?? t('admin.reports.reporterId', { id: selected.reporterId })}
                        </Link>
                      </dd>
                    </div>
                    <div>
                      <dt>{t('admin.reports.reportedAt')}</dt>
                      <dd>{formatDateTime(selected.createdAt)}</dd>
                    </div>
                    {(counts.get(targetKey(selected)) ?? 1) > 1 && (
                      <div>
                        <dt>{t('admin.reports.queue')}</dt>
                        <dd>{t('admin.reports.sameTarget', { n: counts.get(targetKey(selected)) ?? 1 })}</dd>
                      </div>
                    )}
                  </dl>
                  <p className={styles.noteLabel}>{t('admin.reports.note')}</p>
                  <p className={styles.noteBody} dir="auto">
                    {selected.note ?? t('admin.reports.noNote')}
                  </p>
                </Card>

                {selected.status === 'OPEN' ? (
                  <Card title={t('admin.reports.decision.title')}>
                    <div role="radiogroup" aria-label={t('admin.reports.decision.label')} className={styles.choices} data-search-anchor="reports-decision">
                      {RESOLUTIONS.map((r, i) => (
                        <button
                          key={r}
                          type="button"
                          role="radio"
                          aria-checked={action === r}
                          className={`${styles.choice} ${action === r ? styles.chosen : ''} ${
                            r === 'SUSPEND_USER' ? styles.severe : ''
                          }`}
                          onClick={() => setAction(r)}
                        >
                          <kbd className={styles.kbd}>{i + 1}</kbd>
                          <span className={styles.choiceText}>
                            <strong>
                              {action === r && <Icon name="check" size={16} aria-hidden="true" />} {t(`admin.reports.resolution.${r}`)}
                            </strong>
                            <small>{t(`admin.reports.decision.hint.${r}`)}</small>
                          </span>
                        </button>
                      ))}
                    </div>
                    <ReasonFields
                      value={reasonCode}
                      onChange={setReasonCode}
                      templates={templates}
                      onTemplateText={needsMessage ? setMessage : undefined}
                    />
                    {needsMessage && (
                      <FormField
                        label={t(`admin.reports.decision.message.${action as 'WARN' | 'SUSPEND_USER'}`)}
                        hint={t(`admin.reports.decision.message.${action as 'WARN' | 'SUSPEND_USER'}.hint`)}
                        required={action === 'SUSPEND_USER'}
                        error={
                          touched && error
                            ? error === 'reasonRequired'
                              ? t('admin.reports.decision.reasonRequired')
                              : t('admin.reports.decision.tooLong')
                            : null
                        }
                      >
                        <Textarea
                          rows={3}
                          value={message}
                          maxLength={MAX_MESSAGE + 50}
                          onChange={(e) => setMessage(e.target.value)}
                          dir="auto"
                        />
                      </FormField>
                    )}
                    <div className={`${styles.applyRow} ${v2.touch}`}>
                      <PermissionButton
                        permission="moderation.write"
                        data-search-anchor="reports-apply"
                        variant={action === 'SUSPEND_USER' ? 'danger' : 'primary'}
                        onClick={requestApply}
                        loading={resolve.isPending}
                      >
                        {t('admin.reports.decision.apply')}
                      </PermissionButton>
                      <p className={styles.shortcuts} aria-label={t('admin.reports.shortcuts')}>
                        <span>
                          <kbd className={styles.kbd}>j</kbd> <kbd className={styles.kbd}>k</kbd>{' '}
                          {t('admin.reports.shortcut.nav')}
                        </span>
                        <span>
                          <kbd className={styles.kbd}>1-4</kbd> {t('admin.reports.shortcut.pick')}
                        </span>
                        <span>
                          <kbd className={styles.kbd}>Ctrl</kbd>+<kbd className={styles.kbd}>Enter</kbd>{' '}
                          {t('admin.reports.shortcut.apply')}
                        </span>
                      </p>
                    </div>
                  </Card>
                ) : (
                  <Card>
                    <StatusPill tone="success">
                      {t('admin.reports.resolvedWith', {
                        action: selected.resolution ? t(`admin.reports.resolution.${selected.resolution}`) : '—',
                      })}
                    </StatusPill>
                  </Card>
                )}
              </>
            ) : (
              <EmptyState compact icon="flag" title={t('admin.reports.select')} description=" " />
            )}
          </div>
          )}
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={() => selected && resolve.mutate(selected)}
        loading={resolve.isPending}
        danger={action === 'SUSPEND_USER' || action === 'HIDE'}
        title={t('admin.reports.confirm.title')}
        confirmLabel={t(`admin.reports.resolution.${action}`)}
        message={
          <>
            {t('admin.v2m.reports.confirmBody', { action: t(`admin.reports.resolution.${action}`) })}
            <br />
            <strong>{t(`admin.v2m.reports.consequence.${action}`)}</strong>
            <br />
            {t('admin.v2m.reports.sameTargetNote')}
            {needsMessage && message.trim() && (
              <>
                <br />
                {t('admin.reports.confirm.bodyWithMessage', { message: message.trim() })}
              </>
            )}
          </>
        }
      />
    </>
  );
}
