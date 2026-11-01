// SAYFA: Gizlenen içerik (/admin/moderation/hidden)  [P11]
// API: GET /api/admin/moderation/hidden (birleşik liste; tür/gizleyen/tarih süzgeci), POST .../hidden/{type}/{id}/restore {reason}
//      (api/modAdmin.ts). Geri alma yalnız geri alınabilir türlerde; ilgili ihlaller sayılmaz, sahibine bildirim gider.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk } from '../../api';
import type { HiddenRow } from '../../api/modAdmin';
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
  ResponsiveTable,
  Select,
  StatTile,
  StatusPill,
  useKitFormat,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { AuthImage } from './moderation/AuthImage';
import { MOD_TARGET_TYPES, restoreAvailability } from './moderation/p11Logic';
import { FilterFold } from './moderation/v2';
import v2 from './moderation/v2.module.css';
import styles from './moderation/p11.module.css';

interface Filters {
  targetType: ReportTargetType | '';
  hiddenBy: 'AUTO' | 'ADMIN' | '';
  from: string;
  to: string;
}
const EMPTY: Filters = { targetType: '', hiddenBy: '', from: '', to: '' };

export default function HiddenContentPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.p11.hidden.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const params = { ...filters, page, size: 20 };
  const query = useQuery({
    queryKey: [...qk.moderation.all, 'hidden', params],
    queryFn: () => modAdminApi.listHidden(params),
  });
  const data = query.data;
  const kit = useKitFormat();

  const columns: Column<HiddenRow>[] = [
    {
      key: 'target',
      header: t('admin.p11.hidden.col.content'),
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.cellStack}>
          <Badge tone="primary">{t(`admin.reports.targetType.${r.targetType}`)}</Badge>
          <span className={`${styles.muted} ltr`}>#{r.targetId}</span>
          {!r.exists && <span className={styles.muted}>{t('admin.p11.hidden.gone')}</span>}
        </span>
      ),
    },
    {
      key: 'preview',
      header: t('admin.p11.hidden.col.preview'),
      card: { priority: 2 },
      render: (r) =>
        r.preview?.kind === 'IMAGE' ? (
          <div className={`${styles.preview} ${v2.thumb}`}>
            <AuthImage url={r.preview.thumbnailUrl ?? r.preview.url} alt={t('admin.reports.preview.image')} />
          </div>
        ) : r.preview?.kind === 'TEXT' && r.preview.text ? (
          <p className={`${styles.previewText} ${v2.clamp3}`} dir="auto">
            {r.preview.text}
          </p>
        ) : (
          <span className={styles.muted}>{t('admin.p11.hidden.noPreview')}</span>
        ),
    },
    {
      key: 'owner',
      header: t('admin.p11.hidden.col.owner'),
      render: (r) =>
        r.ownerId ? (
          <Link to={paths.admin.user(r.ownerId)} dir="auto" className={`${v2.link} ${v2.linkTouch}`}>
            {r.ownerName || `#${r.ownerId}`}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'hiddenBy',
      header: t('admin.p11.hidden.col.by'),
      card: { priority: 3 },
      render: (r) => (
        <StatusPill tone={r.hiddenBy === 'ADMIN' ? 'danger' : 'warning'}>{t(`admin.p11.hidden.by.${r.hiddenBy}`)}</StatusPill>
      ),
    },
    { key: 'hiddenAt', header: t('admin.p11.hidden.col.date'), render: (r) => (r.hiddenAt ? formatDateTime(r.hiddenAt) : '—') },
    {
      key: 'actions',
      header: t('admin.p11.col.actions'),
      align: 'end',
      card: { actions: true },
      render: (r) => {
        const av = restoreAvailability(r);
        if (!av.ok) {
          return <span className={styles.why}>{av.why ? td(av.why) : ''}</span>;
        }
        return (
          <GuardedAction
            permission="moderation.write"
            size="sm"
            variant="secondary"
            requireReason
            irreversible={false}
            title={t('admin.p11.hidden.restore.title')}
            confirmLabel={t('admin.p11.hidden.restore.button')}
            message={t('admin.p11.hidden.restore.message', { type: t(`admin.reports.targetType.${r.targetType}`), id: r.targetId })}
            consequence={t('admin.p11.hidden.restore.consequence')}
            successMessage={t('admin.p11.hidden.restore.done')}
            errorMessage={(e) => adminError(i18n, e)}
            invalidateKeys={[qk.moderation.all, qk.reports.all]}
            onConfirm={({ reason, idempotencyKey }) =>
              modAdminApi.restoreHidden(r.targetType, r.targetId, { reason, idempotencyKey })
            }
          >
            {t('admin.p11.hidden.restore.button')}
          </GuardedAction>
        );
      },
    },
  ];

  const rows = data?.items ?? [];
  const byAdmin = rows.filter((r) => r.hiddenBy === 'ADMIN').length;
  const byAuto = rows.length - byAdmin;
  const oldest = rows.reduce<string | null>((o, r) => (r.hiddenAt && (!o || r.hiddenAt < o) ? r.hiddenAt : o), null);
  const activeCount = [filters.targetType !== '', filters.hiddenBy !== '', filters.from !== '', filters.to !== ''].filter(Boolean).length;

  return (
    <>
      <PageHeader title={t('admin.p11.hidden.title')} description={t('admin.p11.hidden.desc')} />
      <div className={v2.tiles} data-search-anchor="hidden-summary">
        <StatTile
          label={t('admin.v2m.hidden.tile')}
          value={data ? data.total : undefined}
          icon="eyeOff"
          loading={query.isLoading}
          error={query.isError}
          onRetry={() => void query.refetch()}
          caption={t('admin.v2m.hidden.tileHint')}
        />
        <StatTile
          label={t('admin.v2m.hidden.byAdmin')}
          value={data ? byAdmin : undefined}
          loading={query.isLoading}
          error={query.isError}
          caption={t('admin.v2m.hidden.byAdminHint')}
        />
        <StatTile
          label={t('admin.v2m.hidden.byAuto')}
          value={data ? byAuto : undefined}
          loading={query.isLoading}
          error={query.isError}
          caption={t('admin.v2m.hidden.byAutoHint')}
        />
      </div>
      {data && data.total > 0 && (
        <Insight
          className={v2.sentence}
          parts={[
            t('admin.v2m.hidden.sentence'),
            ...(oldest ? [' ', { text: t('admin.v2m.hidden.oldest', { when: kit.relative(oldest) }) }] : []),
          ]}
        />
      )}
      <FilterFold activeCount={activeCount} anchor="hidden-filters">
        <FormField label={t('admin.p11.hidden.filter.type')}>
          <Select value={filters.targetType} onChange={(e) => set({ targetType: e.target.value as ReportTargetType | '' })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            {MOD_TARGET_TYPES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.reports.targetType.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p11.hidden.filter.by')}>
          <Select value={filters.hiddenBy} onChange={(e) => set({ hiddenBy: e.target.value as Filters['hiddenBy'] })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            <option value="AUTO">{t('admin.p11.hidden.by.AUTO')}</option>
            <option value="ADMIN">{t('admin.p11.hidden.by.ADMIN')}</option>
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
            caption={t('admin.p11.hidden.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => `${r.targetType}:${r.targetId}`}
            loading={query.isLoading}
            empty={
              <EmptyState
                icon="eyeOff"
                title={t('admin.p11.hidden.empty.title')}
                description={t('admin.p11.hidden.empty.hint')}
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
