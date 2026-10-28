// Tüm kulüpler listesi: süzgeç/arama/sıralama/sayfalama + CSV; satıra tıklayınca ayrıntı çekmecesi açılır.
import { useQuery } from '@tanstack/react-query';
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
  Pagination,
  Select,
  StatusPill,
  Table,
  useToast,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { useDebouncedValue } from '../../../lib/hooks';
import { downloadBlob } from '../users/filters';
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

  const columns: Column<ClubRow>[] = [
    {
      key: 'name',
      header: t('admin.p06.col.name'),
      headerLabel: t('admin.p06.col.name'),
      sortable: true,
      render: (c) => (
        <span className={styles.nameCell}>
          <span className={styles.nameMain} dir="auto">
            {c.name}
          </span>
          <span className={`${styles.muted} ltr`}>{c.slug}</span>
        </span>
      ),
    },
    {
      key: 'status',
      header: t('admin.p06.col.status'),
      render: (c) => <StatusPill tone={statusTone(c.status)}>{t(`admin.p06.status.${c.status}`)}</StatusPill>,
    },
    {
      key: 'owner',
      header: t('admin.p06.col.owner'),
      render: (c) => (
        <span className={styles.nameCell}>
          <span dir="auto">{c.ownerName ?? `#${c.ownerId}`}</span>
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
      render: (c) => (
        <span>
          {formatNumber(c.memberCount)}
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
      render: (c) => (c.openReportCount > 0 ? <Badge tone="danger">{formatNumber(c.openReportCount)}</Badge> : '—'),
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
      <div className={styles.filters} role="search" aria-label={t('admin.p06.filters')}>
        <FormField label={t('admin.p06.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as ClubFilters['status'] })}>
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
            type="search"
            value={filters.q}
            placeholder={t('admin.p06.filter.qPlaceholder')}
            onChange={(e) => set({ q: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p06.filter.category')}>
          <Input value={filters.category} onChange={(e) => set({ category: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p06.filter.visibility')}>
          <Select value={filters.visibility} onChange={(e) => set({ visibility: e.target.value as ClubFilters['visibility'] })}>
            <option value="">{t('admin.p06.filter.any')}</option>
            <option value="PUBLIC">{t('admin.p06.visibility.PUBLIC')}</option>
            <option value="PRIVATE">{t('admin.p06.visibility.PRIVATE')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p06.filter.joinPolicy')}>
          <Select value={filters.joinPolicy} onChange={(e) => set({ joinPolicy: e.target.value as ClubFilters['joinPolicy'] })}>
            <option value="">{t('admin.p06.filter.any')}</option>
            <option value="OPEN">{t('admin.p06.joinPolicy.OPEN')}</option>
            <option value="APPROVAL">{t('admin.p06.joinPolicy.APPROVAL')}</option>
          </Select>
        </FormField>
        <div className={styles.checks}>
          <Checkbox
            label={t('admin.p06.filter.reportedOnly')}
            checked={filters.reportedOnly}
            onChange={(e) => set({ reportedOnly: e.target.checked })}
          />
          <Button variant="ghost" size="sm" onClick={() => { setFilters(EMPTY_CLUB_FILTERS); setPage(0); }}>
            {t('admin.p06.filter.reset')}
          </Button>
          <Button
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

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p06.count', { n: formatNumber(data.total) })}
        </p>
      )}
      <div className={styles.tableCard}>
        <Table
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
          empty={<EmptyState icon="community" compact title={t('admin.p06.empty.title')} description={t('admin.p06.empty.hint')} />}
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
