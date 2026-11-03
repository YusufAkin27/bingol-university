import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { getBehaviorUsers, type BehaviorUserRow, type SortDir, type UserSort } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import {
  Badge,
  Card,
  EmptyState,
  Pagination,
  ResponsiveTable,
  SearchInput,
  type Column,
  type SortState,
} from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import { drawerDays, formatDuration, formatInt, formatPct, screenLabel, type Range } from './format';
import { totalPagesOf } from './shared';
import { nextSort } from './ScreensSection';
import UserDrawer from './UserDrawer';

export const USER_PAGE_SIZE = 20;
const SORT_KEYS: UserSort[] = ['sessions', 'totalMs', 'avgSessionMs', 'bounceRate', 'quickCloseCount', 'lastSeenAt'];

export default function UsersSection({ range }: { range: Range }) {
  const { t, formatDateTime } = useI18n();
  const [sp, setSp] = useSearchParams();
  const uidParam = Number(sp.get('uid'));
  const selected = Number.isInteger(uidParam) && uidParam > 0 ? uidParam : null;
  const [q, setQ] = useState('');
  const [sort, setSort] = useState<SortState>({ key: 'totalMs', dir: 'desc' });
  const [page, setPage] = useState(0);
  useEffect(() => setPage(0), [range.from, range.to]);

  const params = {
    ...range,
    q,
    sort: (SORT_KEYS as string[]).includes(sort.key) ? (sort.key as UserSort) : 'totalMs',
    dir: sort.dir as SortDir,
    page,
    size: USER_PAGE_SIZE,
  };
  const query = useQuery({
    queryKey: qk.analytics.behavior('users', params),
    queryFn: () => getBehaviorUsers(params),
    placeholderData: keepPreviousData,
  });
  const num = (v: string) => <span className={analytics.num}>{v}</span>;

  const open = (id: number | null) => {
    const next = new URLSearchParams(sp);
    if (id === null) next.delete('uid');
    else next.set('uid', String(id));
    setSp(next, { replace: true });
  };

  const columns: Column<BehaviorUserRow>[] = [
    {
      key: 'user',
      header: t('admin.bh.col.user'),
      width: '17rem',
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.userCell}>
          <strong>{r.displayName}</strong>
          <span className={analytics.muted}>
            <span className="ltr">{r.email}</span>
            {(r.department || r.grade) && <> · {[r.department, r.grade].filter(Boolean).join(' · ')}</>}
          </span>
        </span>
      ),
    },
    { key: 'sessions', header: t('admin.bh.col.sessions'), sortable: true, align: 'end', card: { priority: 2 }, render: (r) => num(formatInt(r.sessions)) },
    { key: 'totalMs', header: t('admin.bh.col.totalTime'), sortable: true, align: 'end', card: { priority: 3 }, render: (r) => num(formatDuration(r.totalMs)) },
    { key: 'avgSessionMs', header: t('admin.bh.col.avgSession'), sortable: true, align: 'end', render: (r) => num(formatDuration(r.avgSessionMs)) },
    { key: 'bounceRate', header: t('admin.bh.col.bounce'), sortable: true, align: 'end', render: (r) => num(formatPct(r.bounceRate)) },
    { key: 'quickCloseCount', header: t('admin.bh.col.quickCloseCount'), sortable: true, align: 'end', render: (r) => num(formatInt(r.quickCloseCount)) },
    {
      key: 'lastSeenAt',
      header: t('admin.bh.col.lastSeen'),
      sortable: true,
      render: (r) => (r.lastSeenAt ? formatDateTime(r.lastSeenAt) : '—'),
    },
    {
      key: 'topScreens',
      header: t('admin.bh.col.topScreens'),
      width: '15rem',
      render: (r) =>
        r.topScreens.length === 0 ? (
          <span className={analytics.muted}>—</span>
        ) : (
          <ul className={styles.chipList} aria-label={t('admin.bh.col.topScreens')}>
            {r.topScreens.map((s) => (
              <li key={s.screen} className={styles.chip}>
                {screenLabel(s.screen)} <strong>{formatDuration(s.ms)}</strong>
              </li>
            ))}
          </ul>
        ),
    },
  ];

  const empty = !query.isLoading && !query.isError && query.data && query.data.total === 0;
  return (
    <>
      <Card
        title={t('admin.bh.users.title')}
        data-search-anchor="anl-behavior-users"
        actions={<Badge tone="info">{t('admin.bh.users.audited')}</Badge>}
      >
        <p className={analytics.muted}>{t('admin.bh.users.hint')}</p>
        <div className={styles.userSearch}>
          <SearchInput
            label={t('admin.bh.users.searchLabel')}
            placeholder={t('admin.bh.users.searchPlaceholder')}
            defaultValue={q}
            onSearch={(v) => {
              setQ(v);
              setPage(0);
            }}
          />
        </div>
        {empty ? (
          <EmptyState
            icon="search"
            title={t('admin.bh.users.emptyTitle')}
            description={q ? t('admin.bh.users.emptySearch') : t('admin.bh.users.emptyBody')}
            compact
          />
        ) : (
          <>
            <ResponsiveTable
              caption={t('admin.bh.users.title')}
              columns={columns}
              rows={query.data ? query.data.items : undefined}
              rowKey={(r) => r.userId}
              loading={query.isLoading}
              error={query.isError && !query.data}
              onRetry={() => void query.refetch()}
              sort={sort}
              onSortChange={(next) => {
                setSort((cur) => nextSort(cur, next));
                setPage(0);
              }}
              onRowClick={(r) => open(r.userId)}
            />
            {query.data && (
              <Pagination
                page={query.data.page}
                totalPages={totalPagesOf(query.data.total, query.data.size || USER_PAGE_SIZE)}
                totalItems={query.data.total}
                onPageChange={setPage}
              />
            )}
          </>
        )}
      </Card>
      {selected !== null && <UserDrawer userId={selected} days={drawerDays(range)} onClose={() => open(null)} />}
    </>
  );
}
