// Kuyruk sekmesi: GET /api/admin/push/outbox (liste/süzgeç), tek ve toplu yeniden dene/iptal (sebep + etki sayısı onayı).
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import {
  BULK_MAX,
  OUTBOX_STATUSES,
  PUSH_TYPES,
  bulkOutbox,
  listOutbox,
  pushOpsKeys,
  type BulkAction,
  type BulkResult,
  type OutboxFilters,
  type OutboxRow,
  type OutboxStatus,
} from '../../../api/adminPushOps';
import { getPushStats } from '../../../api/ops';
import {
  Badge,
  BulkBar,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  Modal,
  Pagination,
  Select,
  StatCard,
  StatusPill,
  Table,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { OutboxDrawer } from './OutboxDrawer';
import { codeKey, failureCounts, parseCampaignId, STATUS_TONE, validDate } from './lib';
import styles from './pushops.module.css';

interface Filters {
  status: OutboxStatus | '';
  type: string;
  campaign: string;
  from: string;
  to: string;
}
const EMPTY: Filters = { status: '', type: '', campaign: '', from: '', to: '' };
const PAGE_SIZE = 20;

export function QueueTab() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [selected, setSelected] = useState<Set<string | number>>(new Set());
  const [openId, setOpenId] = useState<number | null>(null);
  const [bulkResult, setBulkResult] = useState<BulkResult | null>(null);

  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };
  // Süzgeç/sayfa değişince seçim sıfırlanır: görünmeyen satırlar üzerinde toplu işlem yapılmasın.
  useEffect(() => setSelected(new Set()), [filters, page]);

  const campaignId = parseCampaignId(filters.campaign);
  const campaignBad = filters.campaign.trim() !== '' && campaignId === null;
  const datesOk = validDate(filters.from) && validDate(filters.to) && !(filters.from && filters.to && filters.from > filters.to);
  const params: OutboxFilters = {
    status: filters.status,
    type: filters.type,
    campaignId,
    from: filters.from,
    to: filters.to,
    page,
    size: PAGE_SIZE,
  };

  const stats = useQuery({ queryKey: pushOpsKeys.stats(), queryFn: getPushStats, refetchInterval: 30_000 });
  const list = useQuery({
    queryKey: pushOpsKeys.outbox(params),
    queryFn: () => listOutbox(params),
    enabled: !campaignBad && datesOk,
    placeholderData: keepPreviousData,
  });
  const data = list.data;
  const st = stats.data;

  const bulk =
    (action: BulkAction) =>
    async ({ reason, idempotencyKey }: { reason: string; idempotencyKey: string }) => {
      const res = await bulkOutbox(action, [...selected].map(Number), { reason, idempotencyKey });
      setBulkResult(res);
      setSelected(new Set());
    };
  const overLimit = selected.size > BULK_MAX;

  const columns: Column<OutboxRow>[] = [
    { key: 'id', header: t('admin.p14.queue.col.id'), render: (r) => <span className={styles.muted}>#{r.id}</span> },
    {
      key: 'status',
      header: t('admin.p14.queue.col.status'),
      render: (r) => <StatusPill tone={STATUS_TONE[r.status]}>{t(`admin.p14.status.${r.status}`)}</StatusPill>,
    },
    {
      key: 'type',
      header: t('admin.p14.queue.col.type'),
      render: (r) => (r.type ? <Badge tone="neutral">{r.type}</Badge> : <span className={styles.muted}>—</span>),
    },
    {
      key: 'campaign',
      header: t('admin.p14.queue.col.campaign'),
      render: (r) => (r.campaignId ? <span className="ltr">#{r.campaignId}</span> : <span className={styles.muted}>—</span>),
    },
    {
      key: 'target',
      header: t('admin.p14.queue.col.target'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span className={`${styles.mono} ltr`}>{r.targetRef ?? '—'}</span>
          <span className={`${styles.muted} ltr`}>{r.userRef ?? '—'}</span>
        </span>
      ),
    },
    { key: 'attempts', header: t('admin.p14.queue.col.attempts'), align: 'end', render: (r) => formatNumber(r.attempts) },
    {
      key: 'code',
      header: t('admin.p14.queue.col.code'),
      render: (r) => {
        if (!r.errorCode) return <span className={styles.muted}>—</span>;
        const k = codeKey(r.errorCode);
        return (
          <span className={styles.cellStack}>
            <span className="ltr">{r.errorCode}</span>
            {k && <span className={styles.muted}>{td(k, r.errorCode)}</span>}
          </span>
        );
      },
    },
    {
      key: 'next',
      header: t('admin.p14.queue.col.next'),
      render: (r) =>
        r.nextAttemptAt && (r.status === 'PENDING' || r.status === 'FAILED') ? formatDateTime(r.nextAttemptAt) : '—',
    },
    { key: 'created', header: t('admin.p14.queue.col.created'), render: (r) => formatDateTime(r.createdAt) },
  ];

  return (
    <div>
      <div className={styles.statGrid}>
        <StatCard title={t('admin.p14.queue.stat.pending')} value={st ? formatNumber(st.pending) : '—'} loading={stats.isLoading} />
        <StatCard title={t('admin.p14.queue.stat.sending')} value={st ? formatNumber(st.sending) : '—'} loading={stats.isLoading} />
        <StatCard title={t('admin.p14.queue.stat.failed')} value={st ? formatNumber(st.failed) : '—'} loading={stats.isLoading} />
        <StatCard title={t('admin.p14.queue.stat.dead')} value={st ? formatNumber(st.dead) : '—'} loading={stats.isLoading} invertTone />
        <StatCard title={t('admin.p14.queue.stat.sent24')} value={st ? formatNumber(st.sentLast24h) : '—'} loading={stats.isLoading} />
      </div>

      <div className={styles.filters} role="search" aria-label={t('admin.p14.filters')}>
        <FormField label={t('admin.p14.queue.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as OutboxStatus | '' })}>
            <option value="">{t('admin.p14.filter.all')}</option>
            {OUTBOX_STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.p14.status.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p14.queue.filter.type')}>
          <Select value={filters.type} onChange={(e) => set({ type: e.target.value })}>
            <option value="">{t('admin.p14.filter.all')}</option>
            {PUSH_TYPES.map((x) => (
              <option key={x} value={x}>
                {x}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField
          label={t('admin.p14.queue.filter.campaign')}
          error={campaignBad ? t('admin.p14.queue.filter.campaignBad') : undefined}
        >
          <Input
            inputMode="numeric"
            placeholder={t('admin.p14.queue.filter.campaignPlaceholder')}
            value={filters.campaign}
            onChange={(e) => set({ campaign: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p14.filter.from')}>
          <Input type="date" value={filters.from} max={filters.to || undefined} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p14.filter.to')}>
          <Input type="date" value={filters.to} min={filters.from || undefined} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
        <div>
          <Button variant="ghost" onClick={() => set(EMPTY)}>
            {t('admin.p14.filter.clear')}
          </Button>
        </div>
      </div>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p14.count', { n: formatNumber(data.totalItems) })}
        </p>
      )}
      {list.isError ? (
        <ErrorState onRetry={() => void list.refetch()} description={adminError(i18n, list.error, 'admin.p14.err')} />
      ) : (
        <>
          <Table
            caption={t('admin.p14.queue.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            selectedKeys={selected}
            onSelectionChange={setSelected}
            onRowClick={(r) => setOpenId(r.id)}
            empty={
              <EmptyState icon="bell" title={t('admin.p14.queue.empty.title')} description={t('admin.p14.queue.empty.hint')} compact />
            }
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.totalItems} onPageChange={setPage} />
            </div>
          )}
        </>
      )}

      <BulkBar count={selected.size} onClear={() => setSelected(new Set())}>
        {overLimit && <span className={styles.hint}>{t('admin.p14.bulk.limit', { max: BULK_MAX })}</span>}
        <GuardedAction
          size="sm"
          variant="secondary"
          disabled={overLimit}
          requireReason
          irreversible={false}
          impact={{ count: selected.size, noun: t('admin.p14.bulk.noun') }}
          title={t('admin.p14.bulk.retry.title', { n: selected.size })}
          message={t('admin.p14.bulk.retry.message')}
          consequence={t('admin.p14.bulk.retry.consequence')}
          confirmLabel={t('admin.p14.bulk.retry.confirm')}
          successMessage={false}
          errorMessage={(e) => adminError(i18n, e, 'admin.p14.err')}
          invalidateKeys={[pushOpsKeys.all]}
          onConfirm={bulk('RETRY')}
        >
          {t('admin.p14.bulk.retry')}
        </GuardedAction>
        <GuardedAction
          size="sm"
          variant="danger"
          danger
          disabled={overLimit}
          requireReason
          irreversible={false}
          impact={{ count: selected.size, noun: t('admin.p14.bulk.noun') }}
          title={t('admin.p14.bulk.cancel.title', { n: selected.size })}
          message={t('admin.p14.bulk.cancel.message')}
          consequence={t('admin.p14.bulk.cancel.consequence')}
          confirmLabel={t('admin.p14.bulk.cancel.confirm')}
          successMessage={false}
          errorMessage={(e) => adminError(i18n, e, 'admin.p14.err')}
          invalidateKeys={[pushOpsKeys.all]}
          onConfirm={bulk('CANCEL')}
        >
          {t('admin.p14.bulk.cancel')}
        </GuardedAction>
      </BulkBar>

      {bulkResult && (
        <Modal
          open
          onClose={() => setBulkResult(null)}
          title={t('admin.p14.bulk.result.title')}
          footer={<Button onClick={() => setBulkResult(null)}>{t('admin.p14.bulk.result.close')}</Button>}
        >
          <div data-testid="push-bulk-result">
            <p>
              {t('admin.p14.bulk.result.summary', {
                done: formatNumber(bulkResult.succeeded),
                total: formatNumber(bulkResult.requested),
                failed: formatNumber(bulkResult.failed.length),
              })}
            </p>
            {bulkResult.failed.length > 0 && (
              <ul className={styles.list}>
                {Object.entries(failureCounts(bulkResult.failed)).map(([code, n]) => (
                  <li key={code}>
                    {t('admin.p14.bulk.result.item', {
                      n: formatNumber(n),
                      reason: td(`admin.p14.bulk.code.${code}`, code),
                    })}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </Modal>
      )}

      <OutboxDrawer id={openId} onClose={() => setOpenId(null)} />
    </div>
  );
}
