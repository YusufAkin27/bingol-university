// SAYFA: Anketler (/admin/polls) — sayfalı liste + süzgeç + istatistik, ayrıntı/sonuç, kapat/iptal/sil, toplu işlem, CSV.
// API (api/adminPolls.ts, backend `poll` paketiyle birebir): GET /api/admin/polls (sayfalı: {items,page,size,total}; süzgeç
//      status/scope/q), GET /stats, GET /{id}, POST /{id}/close|cancel, DELETE /{id}, POST /bulk, GET /{id}/export.csv.
//      Oluşturma/düzenleme: POST /api/polls ve PATCH /api/polls/{id} (ADMIN JWT). Menü puanlamaları: kapsam=MENU süzgeci.
// Gizli oy: oy verenin kimliği hiçbir uçta/ekranda/CSV'de yoktur; yalnız toplamlar gösterilir.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { adminPollsApi, qk } from '../../api';
import type { AdminPollRow, PollBulkAction, PollDetail, PollScope, PollStatus } from '../../api/adminPolls';
import {
  Badge,
  BulkBar,
  Button,
  FormField,
  GuardedAction,
  Input,
  PageHeader,
  Pagination,
  Select,
  StatCard,
  Table,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import { PollDetailDrawer } from './polls/PollDetail';
import { PollFormModal } from './polls/PollForm';
import { stateTone } from './polls/pollsLogic';
import styles from './polls/polls.module.css';

const STATUSES: PollStatus[] = ['DRAFT', 'OPEN', 'CLOSED', 'CANCELLED'];
const SCOPES: PollScope[] = ['GLOBAL', 'COMMUNITY', 'MENU'];
const PAGE_SIZE = 20;
const BULK_ACTIONS: { action: PollBulkAction; danger: boolean; irreversible: boolean }[] = [
  { action: 'CLOSE', danger: false, irreversible: false },
  { action: 'CANCEL', danger: true, irreversible: true },
  { action: 'DELETE', danger: true, irreversible: true },
];

export default function PollsAdminPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.polls.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<PollStatus | ''>('');
  const [scope, setScope] = useState<PollScope | ''>('');
  const [text, setText] = useState('');
  const [page, setPage] = useState(0);
  const [selected, setSelected] = useState<Set<string | number>>(new Set());
  const [openId, setOpenId] = useState<number | null>(null);
  const [form, setForm] = useState<{ poll: PollDetail | null } | null>(null);
  const q = useDebouncedValue(text, 400);
  const f = useMemo(() => ({ status, scope, q }), [status, scope, q]);

  const stats = useQuery({ queryKey: qk.adminPolls.stats(), queryFn: adminPollsApi.pollStats, staleTime: 30_000 });
  const list = useQuery({
    queryKey: qk.adminPolls.list(f, page),
    queryFn: () => adminPollsApi.listPolls(f, page, PAGE_SIZE),
    staleTime: 15_000,
    placeholderData: (prev) => prev,
  });
  const rows = list.data?.items;
  const total = list.data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / (list.data?.size || PAGE_SIZE)));
  const s = stats.data;
  const n = (v: number | undefined) => (v === undefined ? '—' : formatNumber(v));

  function change(fn: () => void) {
    fn();
    setPage(0);
    setSelected(new Set());
  }

  const ids = useMemo(() => [...selected].map(Number), [selected]);

  const columns: Column<AdminPollRow>[] = [
    {
      key: 'title',
      header: t('admin.p03.col.title'),
      headerLabel: t('admin.p03.col.title'),
      render: (p) => (
        <div className={styles.titleCell}>
          <button type="button" className={styles.linkBtn} dir="auto" onClick={() => setOpenId(p.id)}>
            {p.title}
          </button>
          {p.anonymous && <Badge tone="info">{t('admin.p03.anonymous')}</Badge>}
        </div>
      ),
    },
    { key: 'scope', header: t('admin.p03.col.scope'), render: (p) => i18n.td(`admin.p03.scope.${p.scope}`, p.scope) },
    { key: 'type', header: t('admin.p03.col.type'), render: (p) => i18n.td(`admin.p03.type.${p.type}`, p.type) },
    {
      key: 'state',
      header: t('admin.p03.col.state'),
      render: (p) => <Badge tone={stateTone(p.state)}>{i18n.td(`admin.p03.state.${p.state}`, p.state)}</Badge>,
    },
    { key: 'votes', header: t('admin.p03.col.votes'), align: 'end', render: (p) => formatNumber(p.totalVotes) },
    {
      key: 'closesAt',
      header: t('admin.p03.col.closesAt'),
      render: (p) => (p.closesAt ? formatDateTime(p.closesAt) : '—'),
    },
  ];

  return (
    <>
      <PageHeader
        title={t('admin.polls.title')}
        description={t('admin.p03.subtitle')}
        actions={
          <Button onClick={() => setForm({ poll: null })} data-testid="poll-new">
            {t('admin.p03.create')}
          </Button>
        }
      />

      <div className={styles.statGrid} data-testid="poll-stats">
        <StatCard title={t('admin.p03.stats.total')} value={n(s?.total)} loading={stats.isLoading} />
        <StatCard title={t('admin.p03.stats.open')} value={n(s?.open)} loading={stats.isLoading} />
        <StatCard title={t('admin.p03.stats.closed')} value={n(s?.closed)} loading={stats.isLoading} />
        <StatCard title={t('admin.p03.stats.draft')} value={n(s?.draft)} loading={stats.isLoading} />
        <StatCard title={t('admin.p03.stats.cancelled')} value={n(s?.cancelled)} loading={stats.isLoading} />
        <StatCard title={t('admin.p03.stats.votes')} value={n(s?.totalVotes)} loading={stats.isLoading} />
        <StatCard
          title={t('admin.p03.stats.turnout')}
          value={s ? (s.avgTurnoutPercent == null ? '—' : `${formatNumber(s.avgTurnoutPercent)}%`) : '—'}
          loading={stats.isLoading}
        />
      </div>

      <div className={styles.filters} role="search" aria-label={t('admin.p03.filters')}>
        <FormField label={t('admin.p03.filter.q')}>
          <Input
            type="search"
            value={text}
            placeholder={t('admin.p03.filter.qPlaceholder')}
            onChange={(e) => change(() => setText(e.target.value))}
          />
        </FormField>
        <FormField label={t('admin.p03.filter.scope')}>
          <Select value={scope} onChange={(e) => change(() => setScope(e.target.value as PollScope | ''))}>
            <option value="">{t('admin.p03.filter.all')}</option>
            {SCOPES.map((x) => (
              <option key={x} value={x}>
                {i18n.td(`admin.p03.scope.${x}`, x)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p03.filter.status')}>
          <Select value={status} onChange={(e) => change(() => setStatus(e.target.value as PollStatus | ''))}>
            <option value="">{t('admin.p03.filter.all')}</option>
            {STATUSES.map((x) => (
              <option key={x} value={x}>
                {i18n.td(`admin.p03.status.${x}`, x)}
              </option>
            ))}
          </Select>
        </FormField>
        <Button
          variant={scope === 'MENU' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => change(() => setScope(scope === 'MENU' ? '' : 'MENU'))}
          aria-pressed={scope === 'MENU'}
        >
          {t('admin.p03.menuRatings')}
        </Button>
      </div>

      <div data-testid="poll-list">
        <Table
          caption={t('admin.polls.title')}
          columns={columns}
          rows={rows}
          rowKey={(p) => p.id}
          loading={list.isLoading}
          error={list.isError}
          onRetry={() => void list.refetch()}
          empty={t('admin.p03.empty')}
          selectedKeys={selected}
          onSelectionChange={setSelected}
          comfortable
        />
      </div>
      <BulkBar count={selected.size} onClear={() => setSelected(new Set())}>
        {BULK_ACTIONS.map(({ action, danger, irreversible }) => (
          <GuardedAction
            key={action}
            size="sm"
            variant={danger ? 'danger' : 'secondary'}
            danger={danger}
            irreversible={irreversible}
            title={i18n.td(`admin.p03.bulk.${action}.title`, action)}
            message={i18n.td(`admin.p03.bulk.${action}.message`, action)}
            consequence={i18n.td(`admin.p03.bulk.${action}.consequence`, action)}
            requireReason
            typeToConfirm={action === 'DELETE' ? t('admin.p03.delete.confirmWord') : undefined}
            impact={{ count: ids.length, threshold: 10, noun: t('admin.p03.bulk.noun') }}
            confirmLabel={i18n.td(`admin.p03.bulk.${action}.confirm`, action)}
            successMessage={false}
            invalidateKeys={[['adminPolls']]}
            onConfirm={async ({ reason, idempotencyKey }) => {
              const r = await adminPollsApi.bulkPolls(ids, action, { reason, idempotencyKey });
              toast.success(t('admin.p03.bulk.result', { done: formatNumber(r.done), skipped: formatNumber(r.skipped) }));
              setSelected(new Set());
              void qc.invalidateQueries({ queryKey: ['adminPolls'] });
            }}
          >
            {i18n.td(`admin.p03.bulk.${action}.button`, action)}
          </GuardedAction>
        ))}
      </BulkBar>
      <Pagination page={page} totalPages={totalPages} totalItems={total} onPageChange={(p) => {
          setPage(p);
          setSelected(new Set());
        }} />

      {openId !== null && (
        <PollDetailDrawer
          id={openId}
          onClose={() => setOpenId(null)}
          onEdit={(poll) => {
            setOpenId(null);
            setForm({ poll });
          }}
        />
      )}
      {form && <PollFormModal poll={form.poll} onClose={() => setForm(null)} />}
    </>
  );
}
