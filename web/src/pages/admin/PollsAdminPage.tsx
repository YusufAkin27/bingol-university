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
  Insight,
  PageHeader,
  Pagination,
  ProgressRing,
  ResponsiveTable,
  Select,
  StatTile,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import './mod2/dict';
import { PollsOverview } from './mod2/PollViz';
import { PollDetailDrawer } from './polls/PollDetail';
import { PollFormModal } from './polls/PollForm';
import { stateTone } from './polls/pollsLogic';
import { FilterFold } from './moderation/v2';
import v2 from './moderation/v2.module.css';
import styles from './polls/polls.module.css';

const STATUSES: PollStatus[] = ['DRAFT', 'OPEN', 'CLOSED', 'CANCELLED'];
const SCOPES: PollScope[] = ['GLOBAL', 'COMMUNITY', 'MENU'];
const PAGE_SIZE = 20;
const BULK_ACTIONS: { action: PollBulkAction; danger: boolean; irreversible: boolean }[] = [
  { action: 'CLOSE', danger: false, irreversible: false },
  { action: 'CANCEL', danger: false, irreversible: true },
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
      card: { priority: 1 },
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
      card: { priority: 2 },
      render: (p) => <Badge tone={stateTone(p.state)}>{i18n.td(`admin.p03.state.${p.state}`, p.state)}</Badge>,
    },
    { key: 'votes', header: t('admin.p03.col.votes'), align: 'end', card: { priority: 3 }, render: (p) => formatNumber(p.totalVotes) },
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
          <Button onClick={() => setForm({ poll: null })} data-testid="poll-new" data-search-anchor="polls-create">
            {t('admin.p03.create')}
          </Button>
        }
      />

      <div data-testid="poll-stats" data-search-anchor="polls-stats">
        <div className={v2.tiles}>
          <StatTile label={t('admin.p03.stats.total')} value={s?.total} loading={stats.isLoading} error={stats.isError} onRetry={() => void stats.refetch()} />
          <StatTile label={t('admin.p03.stats.open')} value={s?.open} icon="check" loading={stats.isLoading} error={stats.isError} caption={t('admin.v2m.polls.openHint')} />
          <StatTile label={t('admin.p03.stats.votes')} value={s?.totalVotes} loading={stats.isLoading} error={stats.isError} />
          <ProgressRing
            value={s?.avgTurnoutPercent ?? null}
            loading={stats.isLoading}
            size={92}
            thickness={9}
            tone="info"
            label={t('admin.p03.stats.turnout')}
          />
        </div>
        {s && <PollsOverview stats={s} />}
      </div>
      {s && (
        <Insight
          className={v2.sentence}
          parts={[
            { text: t('admin.v2m.polls.sentenceOpen', { n: formatNumber(s.open) }) },
            ' ',
            t(s.avgTurnoutPercent == null ? 'admin.v2m.polls.sentenceNoTurnout' : 'admin.v2m.polls.sentenceTurnout', {
              votes: formatNumber(s.totalVotes),
              pct: s.avgTurnoutPercent == null ? '' : formatNumber(Math.round(s.avgTurnoutPercent)),
            }),
          ]}
        />
      )}

      <FilterFold activeCount={[text.trim() !== '', scope !== '', status !== ''].filter(Boolean).length} anchor="polls-filters">
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
          data-search-anchor="polls-menu-ratings"
        >
          {scope === 'MENU' ? '✓ ' : ''}
          {t('admin.p03.menuRatings')}
        </Button>
      </FilterFold>

      <div data-testid="poll-list" data-search-anchor="polls-list">
        <ResponsiveTable
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
        <span className={v2.bulkNote}>{t('admin.v2m.polls.bulkNote')}</span>
        {BULK_ACTIONS.map(({ action, danger, irreversible }) => (
          <GuardedAction
            key={action}
            size="sm"
            permission="content.write"
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
