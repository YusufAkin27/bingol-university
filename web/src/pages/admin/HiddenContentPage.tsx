// SAYFA: Gizlenen içerik (/admin/moderation/hidden)  [P11]
// API: GET /api/admin/moderation/hidden (birleşik liste; tür/gizleyen/tarih süzgeci), POST .../hidden/{type}/{id}/restore {reason}
//      (api/modAdmin.ts). Geri alma yalnız geri alınabilir türlerde; ilgili ihlaller sayılmaz, sahibine bildirim gider.
// Mod1: süzgeçten bağımsız özet (son 100 gizleme: yaş dağılımı, kim gizledi, tür, silinmeye yakın gönderi) ve toplu geri alma.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk } from '../../api';
import type { HiddenRow } from '../../api/modAdmin';
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
  newIdempotencyKey,
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
import { BulkRunDialog, useBatchToast } from './yaptirimMod1/BulkRunDialog';
import { useGt } from './yaptirimMod1/dict';
import { MixBar } from './yaptirimMod1/MixBar';
import { QueueAgePanel } from './yaptirimMod1/QueueAgePanel';
import { ageMs, DAY_MS, oldestAgeMs } from './yaptirimMod1/queueLogic';
import { waitText } from './yaptirimMod1/waitText';
import q from './yaptirimMod1/yaptirim.module.css';

interface Filters {
  targetType: ReportTargetType | '';
  hiddenBy: 'AUTO' | 'ADMIN' | '';
  from: string;
  to: string;
}
const EMPTY: Filters = { targetType: '', hiddenBy: '', from: '', to: '' };
const OVERVIEW_SIZE = 100;
/** Yönetici gizlemesi 30 günü geçen gönderi gece işiyle silinir (docs/ADMIN_API.md); son 7 gün "yakında" sayılır. */
const POST_KEEP_DAYS = 30;
const SOON_DAYS = 7;
const isPostType = (tt: string) => tt === 'POST' || tt === 'FEED_POST';

export default function HiddenContentPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const gt = useGt();
  const qc = useQueryClient();
  const batchToast = useBatchToast();
  usePageTitle(t('admin.p11.hidden.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [selected, setSelected] = useState<ReadonlySet<string | number>>(new Set());
  const [bulkOpen, setBulkOpen] = useState(false);
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
  // Süzgeçten bağımsız özet: son 100 gizleme (sayfadaki 20 kayıttan değil)
  const overview = useQuery({
    queryKey: [...qk.moderation.all, 'hidden-overview'],
    queryFn: () => modAdminApi.listHidden({ page: 0, size: OVERVIEW_SIZE }),
    staleTime: 60_000,
  });
  const now = overview.dataUpdatedAt || Date.now();
  const sample = overview.data?.items;
  const sampleTruncated = (overview.data?.total ?? 0) > OVERVIEW_SIZE;
  const hiddenDates = useMemo(() => (sample ?? []).map((r) => r.hiddenAt), [sample]);
  const byAdmin = (sample ?? []).filter((r) => r.hiddenBy === 'ADMIN').length;
  const byAuto = (sample?.length ?? 0) - byAdmin;
  const soonN = (sample ?? []).filter((r) => {
    const ms = r.hiddenBy === 'ADMIN' && isPostType(r.targetType) ? ageMs(r.hiddenAt, now) : null;
    return ms !== null && ms >= (POST_KEEP_DAYS - SOON_DAYS) * DAY_MS;
  }).length;
  const typeBars = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of sample ?? []) m.set(r.targetType, (m.get(r.targetType) ?? 0) + 1);
    return [...m.entries()].map(([k, v]) => ({ key: k, label: td('admin.reports.targetType.' + k, k), value: v }));
  }, [sample, td]);

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
  const selectedRows = rows.filter((r) => selected.has(`${r.targetType}:${r.targetId}`) && restoreAvailability(r).ok);
  const activeCount = [filters.targetType !== '', filters.hiddenBy !== '', filters.from !== '', filters.to !== ''].filter(Boolean).length;

  return (
    <>
      <PageHeader title={t('admin.p11.hidden.title')} description={t('admin.p11.hidden.desc')} />
      <div className={v2.tiles} data-search-anchor="hidden-summary">
        <StatTile
          label={t('admin.v2m.hidden.tile')}
          value={overview.data ? overview.data.total : data ? data.total : undefined}
          icon="eyeOff"
          loading={overview.isLoading && query.isLoading}
          error={overview.isError && query.isError}
          onRetry={() => void overview.refetch()}
          caption={t('admin.v2m.hidden.tileHint')}
        />
        <StatTile
          label={gt('admin.mod1.hid.tile.soon')}
          value={sample ? soonN : undefined}
          icon="clock"
          loading={overview.isLoading}
          error={overview.isError}
          onRetry={() => void overview.refetch()}
          caption={gt('admin.mod1.hid.tile.soonHint', { days: formatNumber(SOON_DAYS), keep: formatNumber(POST_KEEP_DAYS) })}
        />
        <StatTile
          label={gt('admin.mod1.hid.tile.oldest')}
          value={sample ? (sample.length === 0 ? '–' : waitText(oldestAgeMs(hiddenDates, now), gt, formatNumber)) : undefined}
          icon="eye"
          loading={overview.isLoading}
          error={overview.isError}
          caption={
            sampleTruncated
              ? gt('admin.mod1.hid.sampleNote', { n: formatNumber(OVERVIEW_SIZE) })
              : gt('admin.mod1.hid.tile.oldestHint')
          }
        />
      </div>
      {sample && sample.length > 0 && (
        <Insight
          className={v2.sentence}
          tone={soonN > 0 ? 'warn' : 'info'}
          parts={[
            soonN > 0
              ? gt('admin.mod1.hid.sentenceSoon', { n: formatNumber(soonN), keep: formatNumber(POST_KEEP_DAYS) })
              : t('admin.v2m.hidden.sentence'),
          ]}
        />
      )}
      <div className={q.twoCols}>
        <QueueAgePanel
          anchor="hidden-age"
          variant="plain"
          title={gt('admin.mod1.hid.age.title')}
          noun={gt('admin.mod1.hid.noun')}
          emptyText={gt('admin.mod1.hid.empty')}
          dates={hiddenDates}
          now={now}
          truncated={sampleTruncated}
          loading={overview.isLoading}
          error={overview.isError}
          onRetry={() => void overview.refetch()}
        />
        <section className={q.panel} data-search-anchor="hidden-mix" aria-label={gt('admin.mod1.hid.mix.title')}>
          <h2 className={q.panelTitle}>{gt('admin.mod1.hid.mix.title')}</h2>
          <p className={q.sub}>{gt('admin.mod1.hid.mix.hint')}</p>
          {overview.isError ? (
            <p className={q.muted}>{gt('admin.mod1.age.error')}</p>
          ) : (
            <>
              <MixBar
                ariaLabel={gt('admin.mod1.hid.mix.title')}
                parts={[
                  { key: 'ADMIN', label: t('admin.p11.hidden.by.ADMIN'), value: byAdmin },
                  { key: 'AUTO', label: t('admin.p11.hidden.by.AUTO'), value: byAuto },
                ]}
              />
              <RankedBars
                items={typeBars}
                limit={4}
                loading={overview.isLoading}
                ariaLabel={gt('admin.mod1.hid.types.title')}
                emptyLabel={t('admin.p11.hidden.empty.title')}
              />
            </>
          )}
        </section>
      </div>
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
            selectedKeys={selected}
            onSelectionChange={setSelected}
            selectLabel={(r) =>
              gt('admin.mod1.select.row', { name: td('admin.reports.targetType.' + r.targetType, r.targetType) + ' #' + r.targetId })
            }
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
      <div className={q.bulkSticky} data-search-anchor="hidden-bulk">
        <BulkBar count={selectedRows.length} onClear={() => setSelected(new Set())}>
          <Button size="sm" variant="secondary" onClick={() => setBulkOpen(true)}>
            {gt('admin.mod1.hid.bulk.restore')}
          </Button>
        </BulkBar>
      </div>
      <BulkRunDialog
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        requireReason
        title={gt('admin.mod1.hid.bulkTitle', { n: formatNumber(selectedRows.length) })}
        message={gt('admin.mod1.hid.bulkBody', { n: formatNumber(selectedRows.length) })}
        confirmLabel={gt('admin.mod1.hid.bulkBtn', { n: formatNumber(selectedRows.length) })}
        items={selectedRows}
        runOne={(r, reason) =>
          modAdminApi.restoreHidden(r.targetType, r.targetId, { reason, idempotencyKey: newIdempotencyKey() })
        }
        onDone={(outcome) => {
          batchToast(outcome);
          setBulkOpen(false);
          setSelected(new Set());
          void qc.invalidateQueries({ queryKey: qk.moderation.all });
          void qc.invalidateQueries({ queryKey: qk.reports.all });
        }}
      />
    </>
  );
}
