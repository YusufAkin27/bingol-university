// Tüm kulüpler listesi: süzgeç/arama/sıralama/sayfalama + CSV; satıra tıklayınca ayrıntı çekmecesi açılır.
import { useQuery } from '@tanstack/react-query';
import { communityCategoryKeys, listCommunityCategories } from '../../../api/communityCategories';
import { useMemo, useState } from 'react';
import {
  EMPTY_CLUB_FILTERS,
  exportClubsCsv,
  listClubs,
  type ClubFilters,
  type ClubRow,
  type ClubStatus,
} from '../../../api/adminCommunities';
import {
  Badge,
  Button,
  Checkbox,
  EmptyState,
  FormField,
  Icon,
  Input,
  Insight,
  Pagination,
  ResponsiveTable,
  Select,
  StatusPill,
  useToast,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { useDebouncedValue } from '../../../lib/hooks';
import { downloadBlob } from '../users/filters';
import { CollapsibleFilters, FillBar, StackedBar } from '../community/Summary';
import { CLUB_STATUSES, csvFilename, statusTone } from './clubsLogic';
import styles from './clubs.module.css';

export function ClubList({ onOpen }: { onOpen: (id: number) => void }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const [filters, setFilters] = useState<ClubFilters>(EMPTY_CLUB_FILTERS);
  const [page, setPage] = useState(0);
  const [exporting, setExporting] = useState(false);
  const set = (p: Partial<ClubFilters>) => {
    setFilters((f) => ({ ...f, ...p }));
    setPage(0);
  };
  const q = useDebouncedValue(filters.q, 400);
  const f = useMemo(() => ({ ...filters, q }), [filters, q]);

  const list = useQuery({
    queryKey: ['communities', 'admin', 'list', f, page],
    queryFn: () => listClubs(f, page, 20),
    staleTime: 10_000,
    placeholderData: (prev) => prev,
  });
  const data = list.data;
  const categories = useQuery({
    queryKey: communityCategoryKeys.list(),
    queryFn: listCommunityCategories,
    staleTime: 5 * 60_000,
  });
  const maxMembers = Math.max(1, ...(data?.items ?? []).map((c) => c.memberCount));
  const countBy = (st: ClubStatus) => (data?.items ?? []).filter((c) => c.status === st).length;
  const activeFilters =
    (filters.status ? 1 : 0) +
    (filters.q ? 1 : 0) +
    (filters.category ? 1 : 0) +
    (filters.visibility ? 1 : 0) +
    (filters.joinPolicy ? 1 : 0) +
    (filters.reportedOnly ? 1 : 0);
  const reset = () => {
    setFilters(EMPTY_CLUB_FILTERS);
    setPage(0);
  };

  const columns: Column<ClubRow>[] = [
    {
      key: 'name',
      header: t('admin.p06.col.name'),
      headerLabel: t('admin.p06.col.name'),
      sortable: true,
      card: { priority: 1 },
      render: (c) => (
        <span className={styles.nameCell}>
          <span className={styles.nameMain} dir="auto">
            {c.name}
          </span>
          <span className={`${styles.muted} ${styles.slug} ltr`}>{c.slug}</span>
        </span>
      ),
    },
    {
      key: 'status',
      header: t('admin.p06.col.status'),
      card: { priority: 2 },
      render: (c) => <StatusPill tone={statusTone(c.status)}>{t(`admin.p06.status.${c.status}`)}</StatusPill>,
    },
    {
      key: 'owner',
      header: t('admin.p06.col.owner'),
      render: (c) => (
        <span className={styles.nameCell}>
          <span dir="auto">{c.ownerName ?? t('admin.v2.club.noOwnerName')}</span>
          <span className={`${styles.muted} ltr`}>{c.ownerEmail}</span>
        </span>
      ),
    },
    {
      key: 'memberCount',
      header: t('admin.p06.col.members'),
      headerLabel: t('admin.p06.col.members'),
      sortable: true,
      align: 'end',
      card: { priority: 3 },
      render: (c) => (
        <span className={styles.memberCell}>
          <FillBar
            tone="info"
            value={c.memberCount}
            max={maxMembers}
            label={t('admin.v2.club.members', { n: formatNumber(c.memberCount) })}
          />
          {c.pendingCount > 0 && <Badge tone="warning">{t('admin.p06.col.pending', { n: c.pendingCount })}</Badge>}
        </span>
      ),
    },
    {
      key: 'openReports',
      header: t('admin.p06.col.reports'),
      headerLabel: t('admin.p06.col.reports'),
      sortable: true,
      align: 'end',
      render: (c) =>
        c.openReportCount > 0 ? (
          <Badge tone="danger">{t('admin.v2.club.reports', { n: formatNumber(c.openReportCount) })}</Badge>
        ) : (
          '—'
        ),
    },
    {
      key: 'createdAt',
      header: t('admin.p06.col.created'),
      headerLabel: t('admin.p06.col.created'),
      sortable: true,
      render: (c) => formatDateTime(c.createdAt),
    },
  ];

  async function exportCsv() {
    setExporting(true);
    try {
      downloadBlob(await exportClubsCsv(f), csvFilename());
    } catch (e) {
      toast.error(adminError(i18n, e));
    } finally {
      setExporting(false);
    }
  }

  return (
    <div>
      <CollapsibleFilters label={t('admin.v2.filters.title')} activeCount={activeFilters}>
      <div className={styles.filters} role="search" aria-label={t('admin.p06.filters')}>
        <FormField label={t('admin.p06.filter.status')}>
          <Select data-search-anchor="club-status" value={filters.status} onChange={(e) => set({ status: e.target.value as ClubFilters['status'] })}>
            <option value="">{t('admin.p06.filter.statusDefault')}</option>
            {CLUB_STATUSES.filter((s: ClubStatus) => s !== 'DELETED').map((s) => (
              <option key={s} value={s}>
                {t(`admin.p06.status.${s}`)}
              </option>
            ))}
            <option value="DELETED">{t('admin.p06.status.DELETED')}</option>
            <option value="ALL">{t('admin.p06.filter.statusAll')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p06.filter.q')}>
          <Input
            data-search-anchor="club-search"
            type="search"
            value={filters.q}
            placeholder={t('admin.p06.filter.qPlaceholder')}
            onChange={(e) => set({ q: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p06.filter.category')}>
          {categories.data ? (
            <Select
              data-search-anchor="club-category"
              value={filters.category}
              onChange={(e) => set({ category: e.target.value })}
            >
              <option value="">{t('admin.p06.filter.any')}</option>
              {categories.data.items.map((c) => (
                <option key={c.id} value={c.key}>
                  {c.nameTr}
                </option>
              ))}
            </Select>
          ) : (
            <Input
              data-search-anchor="club-category"
              value={filters.category}
              onChange={(e) => set({ category: e.target.value })}
            />
          )}
        </FormField>
        <FormField label={t('admin.p06.filter.visibility')}>
          <Select data-search-anchor="club-visibility" value={filters.visibility} onChange={(e) => set({ visibility: e.target.value as ClubFilters['visibility'] })}>
            <option value="">{t('admin.p06.filter.any')}</option>
            <option value="PUBLIC">{t('admin.p06.visibility.PUBLIC')}</option>
            <option value="PRIVATE">{t('admin.p06.visibility.PRIVATE')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p06.filter.joinPolicy')}>
          <Select data-search-anchor="club-join" value={filters.joinPolicy} onChange={(e) => set({ joinPolicy: e.target.value as ClubFilters['joinPolicy'] })}>
            <option value="">{t('admin.p06.filter.any')}</option>
            <option value="OPEN">{t('admin.p06.joinPolicy.OPEN')}</option>
            <option value="APPROVAL">{t('admin.p06.joinPolicy.APPROVAL')}</option>
          </Select>
        </FormField>
        <div className={styles.checks}>
          <Checkbox
            data-search-anchor="club-reported"
            label={t('admin.p06.filter.reportedOnly')}
            checked={filters.reportedOnly}
            onChange={(e) => set({ reportedOnly: e.target.checked })}
          />
          <Button variant="ghost" size="sm" data-search-anchor="club-reset" onClick={reset}>
            {t('admin.p06.filter.reset')}
          </Button>
          <Button
            data-search-anchor="club-csv"
            variant="secondary"
            size="sm"
            loading={exporting}
            leftIcon={<Icon name="download" size={16} />}
            onClick={() => void exportCsv()}
          >
            {t('admin.p06.csv')}
          </Button>
        </div>
      </div>
      </CollapsibleFilters>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p06.count', { n: formatNumber(data.total) })}
        </p>
      )}
      {data && data.items.length > 0 && (
        <div className={styles.summary}>
          <Insight
            parts={t('admin.v2.club.insight', {
              n: formatNumber(data.items.length),
              active: formatNumber(countBy('ACTIVE')),
              pending: formatNumber(countBy('PENDING_REVIEW')),
            })}
          />
          <StackedBar
            ariaLabel={t('admin.v2.club.stackAria')}
            parts={(['ACTIVE', 'PENDING_REVIEW', 'HIDDEN', 'REJECTED'] as ClubStatus[]).map((st) => ({
              key: st,
              label: t(`admin.p06.status.${st}`),
              value: countBy(st),
              tone: st === 'ACTIVE' ? 'success' : st === 'PENDING_REVIEW' ? 'warning' : 'danger',
            }))}
          />
        </div>
      )}
      <div className={styles.tableCard}>
        <ResponsiveTable
          caption={t('admin.p06.clubs.title')}
          columns={columns}
          rows={data?.items}
          rowKey={(c) => c.id}
          loading={list.isPending}
          error={list.isError && !data}
          onRetry={() => void list.refetch()}
          sort={{ key: filters.sort, dir: filters.dir }}
          onSortChange={(s) => set({ sort: s.key as ClubFilters['sort'], dir: s.dir })}
          onRowClick={(c) => onOpen(c.id)}
          empty={
            <EmptyState
              icon="community"
              compact
              title={t('admin.p06.empty.title')}
              description={t('admin.p06.empty.hint')}
              action={
                activeFilters > 0 ? (
                  <Button variant="secondary" onClick={reset}>
                    {t('admin.p06.filter.reset')}
                  </Button>
                ) : undefined
              }
            />
          }
        />
        {data && data.totalPages > 1 && (
          <div className={styles.pager}>
            <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
          </div>
        )}
      </div>
    </div>
  );
}
