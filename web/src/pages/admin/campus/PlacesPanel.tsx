// "Yerler" sekmesi: arama + kategori/durum süzgeci + sıralama, tablo (telefonda kart), aktif/pasif ve gerekçeli silme.
import type { UseQueryResult } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  campusKeys,
  deleteCampusPlace,
  updateCampusPlace,
  type CampusCategoryInfo,
  type CampusPlace,
} from '../../../api/adminCampus';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FilterPanel,
  FormField,
  GuardedAction,
  Icon,
  Pagination,
  SearchInput,
  Select,
  StatusPill,
  Table,
  useGuardedMutation,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { gt } from './dict';
import {
  categoryLabel,
  EMPTY_FILTERS,
  filterPlaces,
  fmtCoord,
  osmLink,
  placeToInput,
  sortPlaces,
  type PlaceFilters,
  type PlaceSort,
  type StatusFilter,
} from './logic';
import styles from './campus.module.css';

const ERR_SCOPES = ['admin.campus.err', 'admin.err'];
const PAGE_SIZE = 15;
const SORTS: PlaceSort[] = ['sortKey', 'name', 'category', 'updated'];

interface Props {
  query: UseQueryResult<CampusPlace[]>;
  canWrite: boolean;
  categories: CampusCategoryInfo[];
  onEdit: (place: CampusPlace) => void;
  onAdd: () => void;
}

export function PlacesPanel({ query, canWrite, categories, onEdit, onAdd }: Props) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber } = i18n;
  const [filters, setFilters] = useState<PlaceFilters>(EMPTY_FILTERS);
  const [page, setPage] = useState(0);
  const set = (patch: Partial<PlaceFilters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const all = query.data;
  const rows = useMemo(() => (all ? sortPlaces(filterPlaces(all, filters), filters.sort) : undefined), [all, filters]);
  const totalPages = rows ? Math.max(1, Math.ceil(rows.length / PAGE_SIZE)) : 1;
  const safePage = Math.min(page, totalPages - 1);
  const visible = rows?.slice(safePage * PAGE_SIZE, (safePage + 1) * PAGE_SIZE);
  const filtering = Boolean(filters.q || filters.category || filters.status);

  const toggle = useGuardedMutation<unknown, CampusPlace>({
    mutationFn: (p, ctx) => updateCampusPlace(p.id, { ...placeToInput(p), active: !p.active }, ctx),
    successMessage: (_d, p) => t(p.active ? 'admin.campus.toast.deactivated' : 'admin.campus.toast.activated'),
    errorMessage: (e) => adminError(i18n, e, ...ERR_SCOPES),
    invalidateKeys: [campusKeys.all],
  });

  const columns: Column<CampusPlace>[] = [
    {
      key: 'name',
      header: t('admin.campus.col.name'),
      card: { priority: 1 },
      render: (p) => (
        <span className={styles.cellStack}>
          <strong dir="auto">{p.name}</strong>
          <span className={styles.muted}>
            {[
              p.units.length > 0 ? t('admin.campus.units', { n: formatNumber(p.units.length) }) : null,
              p.footprint && p.footprint.length >= 3 ? t('admin.campus.hasFootprint') : null,
            ]
              .filter(Boolean)
              .join(' · ')}
          </span>
        </span>
      ),
    },
    {
      key: 'category',
      header: t('admin.campus.col.category'),
      card: { priority: 2 },
      render: (p) => <Badge>{categoryLabel(categories, p.category)}</Badge>,
    },
    {
      key: 'coords',
      header: t('admin.campus.col.coords'),
      card: { priority: 3 },
      render: (p) => (
        <span className={`${styles.mono} ltr`}>
          {fmtCoord(p.lat)}, {fmtCoord(p.lng)}
        </span>
      ),
    },
    {
      key: 'status',
      header: t('admin.campus.col.status'),
      card: { priority: 2 },
      render: (p) => (
        <StatusPill tone={p.active ? 'success' : 'neutral'}>
          {t(p.active ? 'admin.campus.status.active' : 'admin.campus.status.inactive')}
        </StatusPill>
      ),
    },
    {
      key: 'actions',
      header: t('admin.campus.col.actions'),
      align: 'end',
      card: { actions: true },
      render: (p) => (
        <span className={styles.rowActions}>
          <a
            className={styles.extLink}
            href={osmLink(p.lat, p.lng)}
            target="_blank"
            rel="noopener noreferrer"
          >
            <Icon name="external" size={16} aria-hidden="true" />
            {t('admin.campus.row.openMap')}
            <span className="sr-only"> {t('admin.campus.row.of', { name: p.name })}</span>
          </a>
          {canWrite && (
            <>
              <Button size="sm" variant="secondary" onClick={() => onEdit(p)}>
                {t('admin.campus.row.edit')}
                <span className="sr-only"> {t('admin.campus.row.of', { name: p.name })}</span>
              </Button>
              <Button
                size="sm"
                variant="secondary"
                loading={toggle.isPending}
                onClick={() => void toggle.run(p)}
              >
                {t(p.active ? 'admin.campus.row.deactivate' : 'admin.campus.row.activate')}
                <span className="sr-only"> {t('admin.campus.row.of', { name: p.name })}</span>
              </Button>
              <GuardedAction
                size="sm"
                variant="dangerOutline"
                danger
                permission="campus.write"
                requireReason
                reasonMinLength={5}
                reasonLabel={t('admin.campus.remove.reason')}
                irreversible
                title={t('admin.campus.remove.title')}
                message={t('admin.campus.remove.message', { name: p.name })}
                consequence={t('admin.campus.remove.consequence')}
                confirmLabel={t('admin.campus.row.remove')}
                successMessage={t('admin.campus.toast.removed')}
                errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
                invalidateKeys={[campusKeys.all]}
                onConfirm={({ reason, idempotencyKey }) => deleteCampusPlace(p.id, { reason, idempotencyKey })}
              >
                {t('admin.campus.row.remove')}
                <span className="sr-only"> {t('admin.campus.row.of', { name: p.name })}</span>
              </GuardedAction>
            </>
          )}
        </span>
      ),
    },
  ];

  if (query.isError) {
    return (
      <ErrorState
        subject={t('admin.campus.subject')}
        error={query.error}
        description={adminError(i18n, query.error, ...ERR_SCOPES)}
        onRetry={() => void query.refetch()}
      />
    );
  }

  return (
    <>
      <div role="search" aria-label={t('admin.campus.filters')} className={styles.filterBar} data-search-anchor="campus-filters">
        <SearchInput
          label={t('admin.campus.filter.q')}
          placeholder={t('admin.campus.filter.qPlaceholder')}
          onSearch={(q) => set({ q })}
        />
        <FilterPanel
          activeCount={[filters.category, filters.status].filter(Boolean).length}
          onClear={() => setFilters((f) => ({ ...EMPTY_FILTERS, q: f.q, sort: f.sort }))}
        >
          <div className={styles.filterGrid}>
            <FormField label={t('admin.campus.filter.category')}>
              <Select
                value={filters.category}
                onChange={(e) => set({ category: e.target.value as PlaceFilters['category'] })}
              >
                <option value="">{t('admin.campus.filter.all')}</option>
                {categories.map((c) => (
                  <option key={c.key} value={c.key}>
                    {c.label}
                  </option>
                ))}
              </Select>
            </FormField>
            <FormField label={t('admin.campus.filter.status')}>
              <Select value={filters.status} onChange={(e) => set({ status: e.target.value as StatusFilter })}>
                <option value="">{t('admin.campus.filter.all')}</option>
                <option value="active">{t('admin.campus.status.active')}</option>
                <option value="inactive">{t('admin.campus.status.inactive')}</option>
              </Select>
            </FormField>
            <FormField label={t('admin.campus.filter.sort')}>
              <Select value={filters.sort} onChange={(e) => set({ sort: e.target.value as PlaceSort })}>
                {SORTS.map((s) => (
                  <option key={s} value={s}>
                    {t(`admin.campus.sort.${s}`)}
                  </option>
                ))}
              </Select>
            </FormField>
          </div>
        </FilterPanel>
      </div>

      {rows && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.campus.count', { n: formatNumber(rows.length) })}
        </p>
      )}

      <div data-search-anchor="campus-list">
        <Table
          caption={t('admin.campus.list')}
          columns={columns}
          rows={visible}
          rowKey={(p) => p.id}
          loading={query.isLoading}
          mobile="cards"
          empty={
            filtering ? (
              <EmptyState
                icon="search"
                compact
                title={t('admin.campus.empty.filteredTitle')}
                description={t('admin.campus.empty.filteredHint')}
              />
            ) : (
              <EmptyState
                icon="pin"
                compact
                title={t('admin.campus.empty.title')}
                description={t('admin.campus.empty.hint')}
                action={
                  canWrite ? (
                    <Button onClick={onAdd} leftIcon={<Icon name="plus" size={16} aria-hidden="true" />}>
                      {t('admin.campus.add')}
                    </Button>
                  ) : undefined
                }
              />
            )
          }
        />
      </div>
      {rows && totalPages > 1 && (
        <div className={styles.pager}>
          <Pagination page={safePage} totalPages={totalPages} totalItems={rows.length} onPageChange={setPage} />
        </div>
      )}
    </>
  );
}
