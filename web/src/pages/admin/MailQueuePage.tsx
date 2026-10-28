// SAYFA: Mail kuyruğu (/admin/mail/queue)  [P13]
// API: GET /api/admin/mail/outbox (+ /{id}), POST .../{id}/retry|cancel, POST .../bulk, GET /api/admin/mail/quota
// (api/adminMailOps.ts). Alıcı HER ZAMAN maskeli; posta İÇERİĞİ ve değişkenleri (kod/jeton olabilir) hiçbir yerde yoktur.
// Yeniden deneme yalnız DEAD/SKIPPED; içerik gizlilik gereği silindiyse ya da eski kod postasıysa sunucu reddeder.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  bulkOutbox,
  cancelOutbox,
  getOutbox,
  listOutbox,
  mailOpsKeys,
  OUTBOX_STATUSES,
  OUTBOX_TEMPLATES,
  retryOutbox,
  type BulkAction,
  type BulkResult,
  type MailCategory,
  type OutboxFilters,
  type OutboxRow,
  type OutboxStatus,
  type OutboxTemplate,
} from '../../api/adminMailOps';
import {
  Badge,
  BulkBar,
  Button,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  StatusPill,
  Table,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { MailQuotaCard } from './mail/MailQuotaCard';
import { bulkEligibility, statusTone, summarizeBulk } from './mail/mailOpsLogic';
import styles from './mail/mailops.module.css';

const ERR_SCOPES = ['admin.p13.err', 'admin.err'];

interface Filters {
  status: OutboxStatus | '';
  template: OutboxTemplate | '';
  category: MailCategory | '';
  q: string;
  from: string;
  to: string;
}
const EMPTY: Filters = { status: '', template: '', category: '', q: '', from: '', to: '' };

export default function MailQueuePage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.p13.queue.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [openId, setOpenId] = useState<number | null>(null);
  const [selected, setSelected] = useState<Set<string | number>>(new Set());
  const [bulkResult, setBulkResult] = useState<BulkResult | null>(null);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
    setSelected(new Set());
  };

  const params: OutboxFilters = { ...filters, page, size: 20 };
  const query = useQuery({
    queryKey: [...mailOpsKeys.outbox, 'list', params],
    queryFn: () => listOutbox(params),
  });
  const data = query.data;
  const eligible = bulkEligibility(data?.items ?? [], selected);
  const idsFor = (action: BulkAction) =>
    (data?.items ?? []).filter((r) => selected.has(r.id) && (action === 'RETRY' ? r.retryable : r.cancellable)).map((r) => r.id);

  const columns: Column<OutboxRow>[] = [
    { key: 'id', header: t('admin.p13.queue.col.id'), render: (r) => <span className="ltr">#{r.id}</span> },
    {
      key: 'to',
      header: t('admin.p13.queue.col.to'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span className="ltr">{r.toMasked}</span>
          <span className={styles.muted}>{r.lang.toUpperCase()}</span>
        </span>
      ),
    },
    {
      key: 'template',
      header: t('admin.p13.queue.col.template'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span>{t(`admin.p13.tpl.${r.template}`)}</span>
          <Badge>{t(`admin.p13.category.${r.category}`)}</Badge>
        </span>
      ),
    },
    {
      key: 'status',
      header: t('admin.p13.queue.col.status'),
      render: (r) => (
        <span className={styles.cellStack}>
          <StatusPill tone={statusTone(r.status)}>{t(`admin.p13.status.${r.status}`)}</StatusPill>
          <span className={styles.muted}>{t('admin.p13.queue.attempts', { n: r.attempts })}</span>
        </span>
      ),
    },
    {
      key: 'dates',
      header: t('admin.p13.queue.col.dates'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span>{formatDateTime(r.createdAt)}</span>
          {(r.status === 'PENDING' || r.status === 'FAILED') && r.nextAttemptAt && (
            <span className={styles.muted}>{t('admin.p13.queue.next', { at: formatDateTime(r.nextAttemptAt) })}</span>
          )}
        </span>
      ),
    },
    {
      key: 'error',
      header: t('admin.p13.queue.col.error'),
      render: (r) => (r.lastError ? <span className={styles.error}>{r.lastError}</span> : <span className={styles.muted}>—</span>),
    },
    {
      key: 'actions',
      header: t('admin.p13.col.actions'),
      align: 'end',
      render: (r) => (
        <Button size="sm" variant="secondary" onClick={() => setOpenId(r.id)}>
          {t('admin.p13.queue.detail.open')}
          <span className="sr-only"> #{r.id}</span>
        </Button>
      ),
    },
  ];

  const runBulk = (action: BulkAction) => async ({ reason, idempotencyKey }: { reason: string; idempotencyKey: string }) => {
    const res = await bulkOutbox(action, idsFor(action), { reason, idempotencyKey });
    setBulkResult(res);
    setSelected(new Set());
    return res;
  };

  return (
    <>
      <PageHeader title={t('admin.p13.queue.title')} description={t('admin.p13.queue.desc')} />
      <MailQuotaCard />

      <div className={styles.filters} role="search" aria-label={t('admin.p13.filters')}>
        <div className={styles.searchField}>
          <SearchInput label={t('admin.p13.filter.q')} placeholder={t('admin.p13.queue.filter.qPlaceholder')} onSearch={(q) => set({ q })} />
          <span className={styles.muted}>{t('admin.p13.queue.filter.qHint')}</span>
        </div>
        <FormField label={t('admin.p13.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as OutboxStatus | '' })}>
            <option value="">{t('admin.p13.filter.all')}</option>
            {OUTBOX_STATUSES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.p13.status.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p13.filter.template')}>
          <Select value={filters.template} onChange={(e) => set({ template: e.target.value as OutboxTemplate | '' })}>
            <option value="">{t('admin.p13.filter.all')}</option>
            {OUTBOX_TEMPLATES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.p13.tpl.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p13.filter.category')}>
          <Select value={filters.category} onChange={(e) => set({ category: e.target.value as MailCategory | '' })}>
            <option value="">{t('admin.p13.filter.all')}</option>
            <option value="TRANSACTIONAL">{t('admin.p13.category.TRANSACTIONAL')}</option>
            <option value="ANNOUNCEMENT">{t('admin.p13.category.ANNOUNCEMENT')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p13.filter.from')}>
          <Input type="date" value={filters.from} max={filters.to || undefined} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p13.filter.to')}>
          <Input type="date" value={filters.to} min={filters.from || undefined} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
      </div>

      {bulkResult && <BulkResultNotice res={bulkResult} onClose={() => setBulkResult(null)} />}

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p13.count', { n: formatNumber(data.total) })}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : (
        <>
          <Table
            caption={t('admin.p13.queue.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            selectedKeys={selected}
            onSelectionChange={setSelected}
            empty={<EmptyState icon="mail" title={t('admin.p13.queue.empty.title')} description={t('admin.p13.queue.empty.hint')} compact />}
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination
                page={data.page}
                totalPages={data.totalPages}
                totalItems={data.total}
                onPageChange={(p) => {
                  setPage(p);
                  setSelected(new Set());
                }}
              />
            </div>
          )}
        </>
      )}

      <BulkBar count={selected.size} onClear={() => setSelected(new Set())}>
        <p className={styles.muted}>
          {t('admin.p13.bulk.eligibility', { retry: eligible.retryable, cancel: eligible.cancellable })}
        </p>
        <GuardedAction
          size="sm"
          variant="secondary"
          requireReason
          disabled={eligible.retryable === 0}
          impact={{ count: eligible.retryable, noun: t('admin.p13.bulk.noun') }}
          irreversible={false}
          title={t('admin.p13.bulk.retry.title')}
          confirmLabel={t('admin.p13.bulk.retry.button')}
          message={t('admin.p13.bulk.retry.message', { n: eligible.retryable })}
          consequence={t('admin.p13.bulk.retry.consequence')}
          successMessage={t('admin.p13.bulk.done')}
          errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
          invalidateKeys={[mailOpsKeys.outbox, mailOpsKeys.quota]}
          onConfirm={runBulk('RETRY')}
        >
          {t('admin.p13.bulk.retry.button')}
        </GuardedAction>
        <GuardedAction
          size="sm"
          variant="danger"
          danger
          requireReason
          disabled={eligible.cancellable === 0}
          impact={{ count: eligible.cancellable, noun: t('admin.p13.bulk.noun') }}
          irreversible
          title={t('admin.p13.bulk.cancel.title')}
          confirmLabel={t('admin.p13.bulk.cancel.button')}
          message={t('admin.p13.bulk.cancel.message', { n: eligible.cancellable })}
          consequence={t('admin.p13.bulk.cancel.consequence')}
          successMessage={t('admin.p13.bulk.done')}
          errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
          invalidateKeys={[mailOpsKeys.outbox, mailOpsKeys.quota]}
          onConfirm={runBulk('CANCEL')}
        >
          {t('admin.p13.bulk.cancel.button')}
        </GuardedAction>
      </BulkBar>

      {openId !== null && <OutboxDrawer id={openId} onClose={() => setOpenId(null)} />}
    </>
  );
}

function BulkResultNotice({ res, onClose }: { res: BulkResult; onClose: () => void }) {
  const { t, td } = useI18n();
  const reasons = summarizeBulk(res);
  return (
    <div className={`${styles.callout} ${res.failed.length ? styles.calloutWarn : ''}`} role="status">
      <p>
        <strong>{t(`admin.p13.bulk.result.${res.action}`)}</strong>{' '}
        {t('admin.p13.bulk.result.summary', { ok: res.succeeded, total: res.requested, failed: res.failed.length })}
      </p>
      {reasons.length > 0 && (
        <ul>
          {reasons.map((r) => (
            <li key={r.code}>
              {r.count} × {td(`admin.p13.err.${r.code}`, r.code)}
            </li>
          ))}
        </ul>
      )}
      <Button size="sm" variant="ghost" onClick={onClose}>
        {t('admin.p13.bulk.result.close')}
      </Button>
    </div>
  );
}

function OutboxDrawer({ id, onClose }: { id: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, td, formatDateTime } = i18n;
  const query = useQuery({
    queryKey: [...mailOpsKeys.outbox, 'detail', id],
    queryFn: () => getOutbox(id),
    staleTime: 0,
  });
  const d = query.data;
  const keys = [mailOpsKeys.outbox, mailOpsKeys.quota];

  return (
    <Drawer open onClose={onClose} title={t('admin.p13.queue.detail.title', { id })} size="md">
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : !d ? (
        <p className={styles.muted} role="status">
          {t('admin.p13.loading')}
        </p>
      ) : (
        <>
          <p className={styles.callout} role="note">
            {t('admin.p13.queue.detail.noContent')}
          </p>
          {d.warnings.map((w) => (
            <p key={w} className={`${styles.callout} ${styles.calloutWarn}`} role="note">
              {td(`admin.p13.queue.warn.${w}`, w)}
            </p>
          ))}
          <dl className={styles.facts}>
            <dt>{t('admin.p13.queue.col.to')}</dt>
            <dd className="ltr">{d.toMasked}</dd>
            <dt>{t('admin.p13.queue.col.template')}</dt>
            <dd>
              {t(`admin.p13.tpl.${d.template}`)} <Badge>{t(`admin.p13.category.${d.category}`)}</Badge>
            </dd>
            <dt>{t('admin.p13.queue.col.status')}</dt>
            <dd>
              <StatusPill tone={statusTone(d.status)}>{t(`admin.p13.status.${d.status}`)}</StatusPill>
            </dd>
            <dt>{t('admin.p13.queue.detail.attempts')}</dt>
            <dd>{d.attempts}</dd>
            <dt>{t('admin.p13.queue.detail.lang')}</dt>
            <dd>{d.lang.toUpperCase()}</dd>
            <dt>{t('admin.p13.queue.detail.createdAt')}</dt>
            <dd>{formatDateTime(d.createdAt)}</dd>
            {d.nextAttemptAt && (d.status === 'PENDING' || d.status === 'FAILED') && (
              <>
                <dt>{t('admin.p13.queue.detail.nextAttempt')}</dt>
                <dd>{formatDateTime(d.nextAttemptAt)}</dd>
              </>
            )}
            {d.sentAt && (
              <>
                <dt>{t('admin.p13.queue.detail.sentAt')}</dt>
                <dd>{formatDateTime(d.sentAt)}</dd>
              </>
            )}
            <dt>{t('admin.p13.queue.col.error')}</dt>
            <dd className={styles.error}>{d.lastError ?? '—'}</dd>
          </dl>

          <h3>{t('admin.p13.queue.detail.timeline')}</h3>
          <ol className={styles.timeline}>
            {d.timeline.map((e, i) => (
              <li key={`${e.event}-${i}`} className={styles.timelineItem}>
                <span className={styles.muted}>{e.at ? formatDateTime(e.at) : '—'}</span>
                <span>
                  {td(`admin.p13.tl.${e.event}`, e.event)}
                  {e.detail ? <span className={styles.muted}> — {e.detail}</span> : null}
                </span>
              </li>
            ))}
          </ol>

          {(d.status === 'DEAD' || d.status === 'SKIPPED') && d.retryBlockedCode && (
            <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
              {td(`admin.p13.err.${d.retryBlockedCode}`, d.retryBlockedCode)}
            </p>
          )}
          <div className={styles.dangerZone}>
            <div className={styles.actionsRow}>
              {(d.status === 'DEAD' || d.status === 'SKIPPED') && (
                <GuardedAction
                  variant="secondary"
                  requireReason
                  reasonMinLength={5}
                  disabled={!d.retryable}
                  irreversible={false}
                  title={t('admin.p13.queue.retry.title')}
                  confirmLabel={t('admin.p13.queue.retry.button')}
                  message={t('admin.p13.queue.retry.message')}
                  consequence={t('admin.p13.queue.retry.consequence')}
                  successMessage={t('admin.p13.queue.retry.done')}
                  errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
                  invalidateKeys={keys}
                  onConfirm={({ reason, idempotencyKey }) => retryOutbox(d.id, { reason, idempotencyKey })}
                >
                  {t('admin.p13.queue.retry.button')}
                </GuardedAction>
              )}
              {d.cancellable && (
                <GuardedAction
                  danger
                  variant="danger"
                  irreversible
                  requireReason
                  reasonMinLength={5}
                  title={t('admin.p13.queue.cancel.title')}
                  confirmLabel={t('admin.p13.queue.cancel.button')}
                  message={t('admin.p13.queue.cancel.message')}
                  consequence={t('admin.p13.queue.cancel.consequence')}
                  successMessage={t('admin.p13.queue.cancel.done')}
                  errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
                  invalidateKeys={keys}
                  onConfirm={({ reason, idempotencyKey }) => cancelOutbox(d.id, { reason, idempotencyKey })}
                  onSuccess={onClose}
                >
                  {t('admin.p13.queue.cancel.button')}
                </GuardedAction>
              )}
            </div>
          </div>
        </>
      )}
    </Drawer>
  );
}
