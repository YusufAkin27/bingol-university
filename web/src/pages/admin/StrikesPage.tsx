// SAYFA: İhlaller (/admin/moderation/strikes)  [P11]
// API: GET /api/admin/moderation/strikes (sayfalı; kullanıcı/tür/durum/tarih süzgeci), POST .../strikes/{id}/forgive {reason}
//      (api/modAdmin.ts). Af: sebep zorunlu, geri alınamaz; sayılan ihlal sayısı düşer, kullanıcıya bildirim gider.
// Mod1: son 100 sayılan ihlalden özet (hafta karşılaştırması + eğri, karar karışımı, askıya yaklaşanlar) ve toplu af.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk } from '../../api';
import type { StrikeFilters, StrikeResolution, StrikeRow, StrikeStatus } from '../../api/modAdmin';
import type { ReportTargetType } from '../../api/types';
import {
  Badge,
  BulkBar,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  Insight,
  PageHeader,
  Pagination,
  RankedBars,
  ResponsiveTable,
  Select,
  StatTile,
  StatusPill,
  percentChange,
  newIdempotencyKey,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { MOD_TARGET_TYPES, canForgive, strikeState } from './moderation/p11Logic';
import { FilterFold } from './moderation/v2';
import v2 from './moderation/v2.module.css';
import styles from './moderation/p11.module.css';
import { BulkRunDialog, useBatchToast } from './yaptirimMod1/BulkRunDialog';
import { useGt } from './yaptirimMod1/dict';
import { MixBar } from './yaptirimMod1/MixBar';
import { dailyCounts, weekOverWeek } from './yaptirimMod1/queueLogic';
import q from './yaptirimMod1/yaptirim.module.css';

const RESOLUTIONS: StrikeResolution[] = ['HIDE', 'WARN', 'SUSPEND_USER'];
/** Askı önerisi eşiğiyle aynı: bu kadar ve üzeri sayılan ihlali olan kişi "askıya yaklaşıyor" sayılır. */
const NEAR_SUSPEND = 3;
const OVERVIEW_SIZE = 100;

interface Filters {
  userId: string;
  status: StrikeStatus;
  targetType: ReportTargetType | '';
  resolution: StrikeResolution | '';
  from: string;
  to: string;
}
const EMPTY: Filters = { userId: '', status: 'ACTIVE', targetType: '', resolution: '', from: '', to: '' };

export default function StrikesPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const gt = useGt();
  const qc = useQueryClient();
  const batchToast = useBatchToast();
  usePageTitle(t('admin.p11.strikes.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [selected, setSelected] = useState<ReadonlySet<string | number>>(new Set());
  const [bulkOpen, setBulkOpen] = useState(false);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const userIdNum = /^\d{1,12}$/.test(filters.userId.trim()) ? Number(filters.userId.trim()) : null;
  const params: StrikeFilters = {
    userId: userIdNum,
    status: filters.status,
    targetType: filters.targetType,
    resolution: filters.resolution,
    from: filters.from,
    to: filters.to,
    page,
    size: 20,
  };
  const query = useQuery({
    queryKey: [...qk.moderation.all, 'strikes', params],
    queryFn: () => modAdminApi.listStrikes(params),
  });
  const data = query.data;
  // Süzgeçten bağımsız özet: sayılan ihlallerin son 100'ü (kuyruğun gerçek durumunu gösterir, sayfa süzgecine bağlı değil)
  const overview = useQuery({
    queryKey: [...qk.moderation.all, 'strikes-overview'],
    queryFn: () => modAdminApi.listStrikes({ status: 'ACTIVE', page: 0, size: OVERVIEW_SIZE }),
    staleTime: 60_000,
  });
  const now = overview.dataUpdatedAt || Date.now();
  const sample = overview.data?.items;
  const sampleTruncated = (overview.data?.total ?? 0) > OVERVIEW_SIZE;
  const daily = useMemo(() => dailyCounts((sample ?? []).map((r) => r.createdAt), now, 14), [sample, now]);
  const wow = weekOverWeek(daily);
  const mix = useMemo(() => {
    const m: Record<string, number> = { HIDE: 0, WARN: 0, SUSPEND_USER: 0, DISMISS: 0 };
    for (const r of sample ?? []) m[r.resolution] = (m[r.resolution] ?? 0) + 1;
    return m;
  }, [sample]);
  const people = useMemo(() => {
    const m = new Map<number, { label: string; n: number }>();
    for (const r of sample ?? []) {
      const cur = m.get(r.userId) ?? { label: r.userName || t('admin.p11.strikes.user', { id: r.userId }), n: 0 };
      cur.n += 1;
      m.set(r.userId, cur);
    }
    return [...m.entries()].map(([id, v]) => ({ id, label: v.label, n: v.n }));
  }, [sample, t]);
  const nearSuspend = people.filter((p) => p.n >= NEAR_SUSPEND);
  const topUsers = people
    .filter((p) => p.n > 1)
    .map((p) => ({ key: String(p.id), label: p.label.length > 26 ? p.label.slice(0, 25) + '…' : p.label, value: p.n }));

  const columns: Column<StrikeRow>[] = [
    {
      key: 'user',
      header: t('admin.p11.strikes.col.user'),
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.cellStack}>
          <Link to={paths.admin.user(r.userId)} dir="auto" className={`${v2.link} ${v2.linkTouch}`}>
            {r.userName || t('admin.p11.strikes.user', { id: r.userId })}
          </Link>
          <span className={`${styles.muted} ltr`}>{r.userEmail ?? `#${r.userId}`}</span>
        </span>
      ),
    },
    {
      key: 'target',
      header: t('admin.p11.strikes.col.target'),
      render: (r) => (
        <span className={styles.cellStack}>
          <Badge tone="primary">{t(`admin.reports.targetType.${r.targetType}`)}</Badge>
          <span className={`${styles.muted} ltr`}>#{r.targetId}</span>
          {r.reportId != null && (
            <span className={styles.muted}>{t('admin.v2m.strikes.fromReport', { id: r.reportId })}</span>
          )}
        </span>
      ),
    },
    {
      key: 'resolution',
      header: t('admin.p11.strikes.col.resolution'),
      card: { priority: 2 },
      render: (r) => t(`admin.p11.strikes.resolution.${r.resolution}`),
    },
    { key: 'createdAt', header: t('admin.p11.strikes.col.date'), render: (r) => formatDateTime(r.createdAt) },
    {
      key: 'state',
      header: t('admin.p11.strikes.col.state'),
      card: { priority: 3 },
      render: (r) => {
        const s = strikeState(r);
        return (
          <span className={styles.cellStack}>
            <StatusPill tone={s === 'ACTIVE' ? 'warning' : s === 'FORGIVEN' ? 'success' : 'neutral'}>
              {t(`admin.p11.strikes.state.${s}`)}
            </StatusPill>
            {r.forgivenReason && (
              <span className={styles.muted} dir="auto">
                {t('admin.p11.strikes.forgivenReason', { reason: r.forgivenReason })}
              </span>
            )}
          </span>
        );
      },
    },
    {
      key: 'actions',
      header: t('admin.p11.col.actions'),
      align: 'end',
      card: { actions: true },
      render: (r) =>
        canForgive(r) ? (
          <GuardedAction
            permission="moderation.write"
            size="sm"
            variant="secondary"
            irreversible
            requireReason
            title={t('admin.p11.strikes.forgive.title')}
            confirmLabel={t('admin.p11.strikes.forgive.button')}
            message={t('admin.p11.strikes.forgive.message', { name: r.userName || `#${r.userId}`, id: r.id })}
            consequence={t('admin.p11.strikes.forgive.consequence')}
            successMessage={t('admin.p11.strikes.forgive.done')}
            errorMessage={(e) => adminError(i18n, e)}
            invalidateKeys={[qk.moderation.all]}
            onConfirm={({ reason, idempotencyKey }) => modAdminApi.forgiveStrike(r.id, { reason, idempotencyKey })}
          >
            {t('admin.p11.strikes.forgive.button')}
          </GuardedAction>
        ) : null,
    },
  ];

  const rows = data?.items ?? [];
  const selectedRows = rows.filter((r) => selected.has(r.id) && canForgive(r));
  const activeCount = [
    filters.userId.trim() !== '',
    filters.status !== 'ACTIVE',
    filters.targetType !== '',
    filters.resolution !== '',
    filters.from !== '',
    filters.to !== '',
  ].filter(Boolean).length;

  return (
    <>
      <PageHeader title={t('admin.p11.strikes.title')} description={t('admin.v2m.strikes.desc')} />
      <div className={v2.tiles} data-search-anchor="strikes-summary">
        <StatTile
          label={t('admin.v2m.strikes.tile')}
          value={data ? data.total : undefined}
          icon="flag"
          loading={query.isLoading}
          error={query.isError}
          onRetry={() => void query.refetch()}
          caption={t(filters.status === 'ACTIVE' ? 'admin.v2m.strikes.tileHintActive' : 'admin.v2m.strikes.tileHintFiltered')}
        />
        <StatTile
          label={gt('admin.mod1.str.tile.week')}
          value={sample ? wow.current : undefined}
          icon="activity"
          spark={sample ? daily : undefined}
          change={sample ? percentChange(wow.current, wow.previous) : null}
          goodWhen="down"
          compareLabel={gt('admin.mod1.str.compare')}
          loading={overview.isLoading}
          error={overview.isError}
          onRetry={() => void overview.refetch()}
          caption={sampleTruncated ? gt('admin.mod1.str.sampleNote', { n: formatNumber(OVERVIEW_SIZE) }) : undefined}
        />
        <StatTile
          label={gt('admin.mod1.str.tile.near')}
          value={sample ? nearSuspend.length : undefined}
          icon="alert"
          loading={overview.isLoading}
          error={overview.isError}
          onRetry={() => void overview.refetch()}
          caption={gt('admin.mod1.str.tile.nearHint', { n: formatNumber(NEAR_SUSPEND) })}
        />
      </div>
      {sample && sample.length > 0 && (
        <Insight
          className={v2.sentence}
          tone={nearSuspend.length > 0 ? 'warn' : 'info'}
          parts={[
            nearSuspend.length > 0
              ? gt('admin.mod1.str.sentenceNear', { n: formatNumber(nearSuspend.length), min: formatNumber(NEAR_SUSPEND) })
              : t('admin.v2m.strikes.sentence'),
            ' ',
            { text: gt('admin.mod1.str.sentenceWeek', { n: formatNumber(wow.current) }), bold: false },
          ]}
        />
      )}
      {sample && sample.length > 0 && (
        <div className={q.twoCols}>
          <section className={q.panel} data-search-anchor="strikes-mix" aria-label={gt('admin.mod1.str.mix.title')}>
            <h2 className={q.panelTitle}>{gt('admin.mod1.str.mix.title')}</h2>
            <p className={q.sub}>{gt('admin.mod1.str.mix.hint')}</p>
            <MixBar
              ariaLabel={gt('admin.mod1.str.mix.title')}
              parts={RESOLUTIONS.map((r) => ({ key: r, label: t(`admin.p11.strikes.resolution.${r}`), value: mix[r] ?? 0 }))}
            />
          </section>
          <section className={q.panel} data-search-anchor="strikes-top" aria-label={t('admin.v2m.strikes.topTitle')}>
            <h2 className={q.panelTitle}>{gt('admin.mod1.str.top.title')}</h2>
            <p className={q.sub}>
              {gt('admin.mod1.str.top.hint')} <Link to={paths.admin.suspensions}>{gt('admin.mod1.str.top.link')}</Link>
            </p>
            <RankedBars
              items={topUsers}
              limit={5}
              ariaLabel={gt('admin.mod1.str.top.title')}
              formatValue={(n) => gt('admin.mod1.str.top.value', { n: formatNumber(n) })}
              emptyLabel={gt('admin.mod1.str.top.empty')}
            />
          </section>
        </div>
      )}
      <FilterFold activeCount={activeCount} anchor="strikes-filters">
        <FormField label={t('admin.p11.strikes.filter.user')}>
          <Input
            inputMode="numeric"
            placeholder={t('admin.p11.strikes.filter.userPlaceholder')}
            value={filters.userId}
            onChange={(e) => set({ userId: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p11.strikes.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as StrikeStatus })}>
            {(['ACTIVE', 'REVOKED', 'ALL'] as StrikeStatus[]).map((s) => (
              <option key={s} value={s}>
                {t(`admin.p11.strikes.filter.status.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p11.strikes.filter.type')}>
          <Select value={filters.targetType} onChange={(e) => set({ targetType: e.target.value as ReportTargetType | '' })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            {MOD_TARGET_TYPES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.reports.targetType.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p11.strikes.filter.resolution')}>
          <Select value={filters.resolution} onChange={(e) => set({ resolution: e.target.value as StrikeResolution | '' })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            {RESOLUTIONS.map((x) => (
              <option key={x} value={x}>
                {t(`admin.p11.strikes.resolution.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p11.filter.from')}>
          <Input type="date" value={filters.from} max={filters.to || undefined} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p11.filter.to')}>
          <Input type="date" value={filters.to} min={filters.from || undefined} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
      </FilterFold>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p11.count', { n: formatNumber(data.total) })}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error)} />
      ) : (
        <>
          <ResponsiveTable
            caption={t('admin.p11.strikes.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            selectedKeys={selected}
            onSelectionChange={setSelected}
            selectLabel={(r) => gt('admin.mod1.select.row', { name: r.userName || `#${r.userId}` })}
            empty={
              <EmptyState
                icon="flag"
                title={t('admin.p11.strikes.empty.title')}
                description={t('admin.p11.strikes.empty.hint')}
                compact
              />
            }
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
            </div>
          )}
        </>
      )}
      <div className={q.bulkSticky} data-search-anchor="strikes-bulk">
        <BulkBar count={selectedRows.length} onClear={() => setSelected(new Set())}>
          <Button size="sm" variant="secondary" onClick={() => setBulkOpen(true)}>
            {gt('admin.mod1.str.bulk.forgive')}
          </Button>
        </BulkBar>
      </div>
      <BulkRunDialog
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        requireReason
        danger
        title={gt('admin.mod1.str.bulkTitle', { n: formatNumber(selectedRows.length) })}
        message={gt('admin.mod1.str.bulkBody', { n: formatNumber(selectedRows.length) })}
        confirmLabel={gt('admin.mod1.str.bulkBtn', { n: formatNumber(selectedRows.length) })}
        items={selectedRows}
        runOne={(r, reason) =>
          modAdminApi.forgiveStrike(r.id, { reason, idempotencyKey: newIdempotencyKey() })
        }
        onDone={(outcome) => {
          batchToast(outcome);
          setBulkOpen(false);
          setSelected(new Set());
          void qc.invalidateQueries({ queryKey: qk.moderation.all });
        }}
      />
    </>
  );
}
