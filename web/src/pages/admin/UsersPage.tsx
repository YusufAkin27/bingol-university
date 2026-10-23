// SAYFA: Kullanıcılar (/admin/users)
// API: GET /api/admin/users (filtre/sayfa/sıralama; api/users.ts `listUsers`), GET /api/admin/users/export.csv (`exportUsersCsv`),
//      GET /api/faculties (fakülte filtresi; api/appInfo.ts `getFaculties`).
// Filtre durumu URL'dedir (paylaşılabilir bağlantı): ?q=&status=&role=&faculty=&department=&classYear=&language=&verified=&sort=&page=
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { getFaculties } from '../../api/appInfo';
import { qk } from '../../api/queryKeys';
import type { AdminUserRow } from '../../api/types';
import { exportUsersCsv, listUsers } from '../../api/users';
import {
  Avatar,
  Badge,
  Button,
  EmptyState,
  ErrorState,
  Icon,
  Pagination,
  PageHeader,
  SearchInput,
  Select,
  StatusPill,
  Table,
  toneFor,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { DebouncedInput } from './users/DebouncedInput';
import {
  activeFilterCount,
  downloadBlob,
  EMPTY_FILTERS,
  filtersToApi,
  filtersToSearch,
  PAGE_SIZE,
  parseUserFilters,
  type UserFilters,
} from './users/filters';
import styles from './users/users.module.css';

export default function UsersPage() {
  const i18n = useI18n();
  const { t, td, formatNumber, formatDate, formatDateTime } = i18n;
  usePageTitle(t('admin.users.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const [sp, setSp] = useSearchParams();
  const filters = useMemo(() => parseUserFilters(sp), [sp]);
  const [exporting, setExporting] = useState(false);
  const [searchKey, setSearchKey] = useState(0);

  const update = (patch: Partial<UserFilters>) =>
    setSp(filtersToSearch({ ...filters, page: 0, ...patch }), { replace: !('page' in patch) });

  const faculties = useQuery({ queryKey: qk.faculties, queryFn: getFaculties, staleTime: 5 * 60_000 });

  const apiParams = { ...filtersToApi(filters), page: filters.page, size: PAGE_SIZE };
  const list = useQuery({
    queryKey: qk.users.list(apiParams),
    queryFn: () => listUsers(apiParams),
    placeholderData: keepPreviousData,
  });

  async function onExport() {
    setExporting(true);
    try {
      const blob = await exportUsersCsv(filtersToApi(filters));
      downloadBlob(blob, 'users.csv');
      toast.success(t('admin.users.export.done'));
    } catch (e) {
      toast.error(errorMessage(i18n, e));
    } finally {
      setExporting(false);
    }
  }

  const sortState = (() => {
    const [key, dir] = filters.sort.split(',');
    return { key, dir: dir === 'asc' ? ('asc' as const) : ('desc' as const) };
  })();

  const dash = <span className={styles.muted}>—</span>;
  const columns: Column<AdminUserRow>[] = [
    {
      key: 'displayName',
      header: t('admin.users.col.name'),
      headerLabel: t('admin.users.col.name'),
      sortable: true,
      render: (u) => (
        <div className={styles.person}>
          <Avatar name={u.displayName} src={u.avatarUrl} size={32} />
          <div className={styles.personText}>
            <span className={styles.personName}>{u.displayName}</span>
            <span className={`${styles.personMail} ltr`}>{u.email}</span>
          </div>
        </div>
      ),
    },
    {
      key: 'faculty',
      header: t('admin.users.col.faculty'),
      render: (u) =>
        u.faculty ? (
          <div className={styles.personText}>
            <span>{u.faculty}</span>
            {u.department && <span className={styles.personMail}>{u.department}</span>}
          </div>
        ) : (
          dash
        ),
    },
    {
      key: 'classYear',
      header: t('admin.users.col.classYear'),
      render: (u) => (u.classYear ? formatNumber(u.classYear) : dash),
    },
    {
      key: 'role',
      header: t('admin.users.col.role'),
      render: (u) => (
        <Badge tone={u.role === 'ADMIN' ? 'primary' : 'neutral'}>{td(`admin.users.role.${u.role}`)}</Badge>
      ),
    },
    {
      key: 'status',
      header: t('admin.users.col.status'),
      render: (u) => (
        <div className={styles.badges}>
          <StatusPill tone={toneFor(u.status)}>{td(`admin.users.status.${u.status}`)}</StatusPill>
          {!u.emailVerified && u.status !== 'DELETED' && (
            <Badge tone="warning">{t('admin.users.verified.no')}</Badge>
          )}
        </div>
      ),
    },
    {
      key: 'createdAt',
      header: t('admin.users.col.createdAt'),
      headerLabel: t('admin.users.col.createdAt'),
      sortable: true,
      render: (u) => <span className={styles.nowrap}>{formatDate(u.createdAt)}</span>,
    },
    {
      key: 'lastSeenAt',
      header: t('admin.users.col.lastSeenAt'),
      headerLabel: t('admin.users.col.lastSeenAt'),
      sortable: true,
      render: (u) =>
        u.lastSeenAt ? (
          <span className={styles.nowrap}>{formatDateTime(u.lastSeenAt)}</span>
        ) : (
          <span className={styles.muted}>{t('admin.users.never')}</span>
        ),
    },
  ];

  const facultyList = faculties.data ?? [];
  const activeFilters = activeFilterCount(filters) + (filters.q ? 1 : 0);
  const data = list.data;

  return (
    <div>
      <PageHeader
        title={t('admin.users.title')}
        description={t('admin.users.subtitle')}
        actions={
          <Button
            variant="secondary"
            loading={exporting}
            leftIcon={<Icon name="download" size={18} />}
            onClick={onExport}
          >
            {t('admin.users.export')}
          </Button>
        }
      />

      <div className={styles.topRow}>
        <div className={styles.search}>
          <SearchInput
            key={searchKey}
            defaultValue={filters.q}
            placeholder={t('admin.users.searchPlaceholder')}
            onSearch={(q) => update({ q })}
          />
        </div>
        {activeFilters > 0 && (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setSearchKey((k) => k + 1);
              update({ ...EMPTY_FILTERS, sort: filters.sort });
            }}
          >
            {t('admin.users.filter.clear')}
          </Button>
        )}
      </div>

      <div className={styles.filters} role="group" aria-label={t('admin.users.filters.label')}>
        <Select
          aria-label={t('admin.users.filter.status')}
          value={filters.status}
          onChange={(e) => update({ status: e.target.value as UserFilters['status'] })}
        >
          <option value="">{t('admin.users.filter.status')}: {t('common.all')}</option>
          {(['ACTIVE', 'SUSPENDED', 'DELETED'] as const).map((s) => (
            <option key={s} value={s}>
              {td(`admin.users.status.${s}`)}
            </option>
          ))}
        </Select>
        <Select
          aria-label={t('admin.users.filter.role')}
          value={filters.role}
          onChange={(e) => update({ role: e.target.value as UserFilters['role'] })}
        >
          <option value="">{t('admin.users.filter.role')}: {t('common.all')}</option>
          {(['USER', 'ADMIN'] as const).map((r) => (
            <option key={r} value={r}>
              {td(`admin.users.role.${r}`)}
            </option>
          ))}
        </Select>
        {facultyList.length > 0 ? (
          <Select
            aria-label={t('admin.users.filter.faculty')}
            value={filters.faculty}
            onChange={(e) => update({ faculty: e.target.value })}
          >
            <option value="">{t('admin.users.filter.faculty')}: {t('common.all')}</option>
            {facultyList.map((f) => (
              <option key={f} value={f}>
                {f}
              </option>
            ))}
          </Select>
        ) : (
          <DebouncedInput
            label={t('admin.users.filter.faculty')}
            value={filters.faculty}
            onCommit={(faculty) => update({ faculty })}
          />
        )}
        <DebouncedInput
          label={t('admin.users.filter.department')}
          value={filters.department}
          onCommit={(department) => update({ department })}
        />
        <Select
          aria-label={t('admin.users.filter.classYear')}
          value={filters.classYear}
          onChange={(e) => update({ classYear: e.target.value as UserFilters['classYear'] })}
        >
          <option value="">{t('admin.users.filter.classYear')}: {t('common.all')}</option>
          {[1, 2, 3, 4].map((n) => (
            <option key={n} value={String(n)}>
              {t('admin.users.classYearOption', { n: formatNumber(n) })}
            </option>
          ))}
        </Select>
        <Select
          aria-label={t('admin.users.filter.language')}
          value={filters.language}
          onChange={(e) => update({ language: e.target.value as UserFilters['language'] })}
        >
          <option value="">{t('admin.users.filter.language')}: {t('common.all')}</option>
          {(['tr', 'en', 'ar'] as const).map((l) => (
            <option key={l} value={l}>
              {td(`admin.users.lang.${l}`)}
            </option>
          ))}
        </Select>
        <Select
          aria-label={t('admin.users.filter.verified')}
          value={filters.verified}
          onChange={(e) => update({ verified: e.target.value as UserFilters['verified'] })}
        >
          <option value="">{t('admin.users.filter.verified')}: {t('common.all')}</option>
          <option value="true">{t('admin.users.filter.verified.true')}</option>
          <option value="false">{t('admin.users.filter.verified.false')}</option>
        </Select>
      </div>

      {list.isError && !data ? (
        <ErrorState description={errorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : (
        <>
          {data && (
            <p className={styles.meta} aria-live="polite">
              {t('admin.users.count', { n: formatNumber(data.totalItems) })}
            </p>
          )}
          <div className={styles.tableCard}>
            <Table
              caption={t('admin.users.title')}
              columns={columns}
              rows={data?.items}
              rowKey={(u) => u.id}
              loading={list.isLoading}
              sort={sortState}
              onSortChange={(s) => update({ sort: `${s.key},${s.dir}` })}
              onRowClick={(u) =>
                navigate(paths.admin.user(u.id), { state: { from: `${location.pathname}${location.search}` } })
              }
              empty={
                <EmptyState
                  icon="users"
                  compact
                  title={t('admin.users.empty.title')}
                  description={t('admin.users.empty.hint')}
                />
              }
            />
            {data && data.totalPages > 1 && (
              <div className={styles.pager}>
                <Pagination
                  page={data.page}
                  totalPages={data.totalPages}
                  totalItems={data.totalItems}
                  onPageChange={(page) => update({ page })}
                />
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
