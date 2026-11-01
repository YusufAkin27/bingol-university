// SAYFA: İhlaller (/admin/moderation/strikes)  [P11]
// API: GET /api/admin/moderation/strikes (sayfalı; kullanıcı/tür/durum/tarih süzgeci), POST .../strikes/{id}/forgive {reason}
//      (api/modAdmin.ts). Af: sebep zorunlu, geri alınamaz; sayılan ihlal sayısı düşer, kullanıcıya bildirim gider.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk } from '../../api';
import type { StrikeFilters, StrikeResolution, StrikeRow, StrikeStatus } from '../../api/modAdmin';
import type { ReportTargetType } from '../../api/types';
import {
  Badge,
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

const RESOLUTIONS: StrikeResolution[] = ['HIDE', 'WARN', 'SUSPEND_USER'];

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
  usePageTitle(t('admin.p11.strikes.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
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

  const columns: Column<StrikeRow>[] = [
    {
      key: 'user',
      header: t('admin.p11.strikes.col.user'),
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.cellStack}>
          <Link to={paths.admin.user(r.userId)} dir="auto" className={v2.link}>
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
  const topUsers = (() => {
    const m = new Map<number, { label: string; n: number }>();
    for (const r of rows) {
      if (!r.active) continue;
      const cur = m.get(r.userId) ?? { label: r.userName || t('admin.p11.strikes.user', { id: r.userId }), n: 0 };
      cur.n += 1;
      m.set(r.userId, cur);
    }
    return [...m.entries()].map(([id, v]) => ({ key: String(id), label: v.label, value: v.n }));
  })();
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
      </div>
      <Insight className={v2.sentence} tone="info" parts={[t('admin.v2m.strikes.sentence')]} />
      {topUsers.length > 1 && (
        <div data-search-anchor="strikes-top">
          <h2 className={v2.hint}>{t('admin.v2m.strikes.topTitle')}</h2>
          <RankedBars items={topUsers} limit={5} ariaLabel={t('admin.v2m.strikes.topTitle')} />
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
    </>
  );
}
