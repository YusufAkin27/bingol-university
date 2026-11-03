import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { getBehaviorScreens, type ScreenSort, type ScreenStat, type SortDir } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import { Card, EmptyState, Pagination, ResponsiveTable, type Column, type SortState } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import { formatDuration, formatInt, formatPct, formatPctPoints, heat, screenLabel, type Range } from './format';
import { HeatCell, totalPagesOf } from './shared';

export const SCREEN_PAGE_SIZE = 20;
const SORT_KEYS: ScreenSort[] = ['views', 'users', 'avgDwellMs', 'exitRate', 'bounceRate'];

/** Yeni sütuna geçilince metrikler çoktan aza başlar; aynı sütunda yön değişir. */
export function nextSort(cur: SortState, next: SortState): SortState {
  return cur.key === next.key ? next : { key: next.key, dir: 'desc' };
}

export default function ScreensSection({ range }: { range: Range }) {
  const { t } = useI18n();
  const [sort, setSort] = useState<SortState>({ key: 'views', dir: 'desc' });
  const [page, setPage] = useState(0);
  // aralık değişince ilk sayfaya dön
  useEffect(() => setPage(0), [range.from, range.to]);

  const params = {
    ...range,
    sort: (SORT_KEYS as string[]).includes(sort.key) ? (sort.key as ScreenSort) : 'views',
    dir: sort.dir as SortDir,
    page,
    size: SCREEN_PAGE_SIZE,
  };
  const q = useQuery({
    queryKey: qk.analytics.behavior('screens', params),
    queryFn: () => getBehaviorScreens(params),
    placeholderData: keepPreviousData,
  });
  const items = q.data?.items ?? [];
  const maxViews = Math.max(0, ...items.map((i) => i.views));
  const maxDwell = Math.max(0, ...items.map((i) => i.avgDwellMs));
  const num = (v: string) => <span className={analytics.num}>{v}</span>;

  const columns: Column<ScreenStat>[] = [
    {
      key: 'screen',
      header: t('admin.bh.col.screen'),
      width: '14rem',
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.screenName} title={r.screen}>
          {screenLabel(r.screen)}
          {screenLabel(r.screen) !== r.screen && <code className={`${styles.rawName} ltr`}>{r.screen}</code>}
        </span>
      ),
    },
    {
      key: 'views',
      header: t('admin.bh.col.views'),
      sortable: true,
      align: 'end',
      card: { priority: 2 },
      render: (r) => <HeatCell text={num(formatInt(r.views))} ratio={heat(r.views, maxViews)} />,
    },
    {
      key: 'users',
      header: t('admin.bh.col.users'),
      sortable: true,
      align: 'end',
      card: { priority: 3 },
      render: (r) => num(formatInt(r.users)),
    },
    {
      key: 'avgDwellMs',
      header: t('admin.bh.col.avgDwell'),
      sortable: true,
      align: 'end',
      render: (r) => <HeatCell text={num(formatDuration(r.avgDwellMs))} ratio={heat(r.avgDwellMs, maxDwell)} />,
    },
    { key: 'medianDwellMs', header: t('admin.bh.col.medianDwell'), align: 'end', render: (r) => num(formatDuration(r.medianDwellMs)) },
    { key: 'p90DwellMs', header: t('admin.bh.col.p90Dwell'), align: 'end', render: (r) => num(formatDuration(r.p90DwellMs)) },
    {
      key: 'exitRate',
      header: t('admin.bh.col.exitRate'),
      sortable: true,
      align: 'end',
      render: (r) => <HeatCell text={num(formatPct(r.exitRate))} ratio={r.exitRate} tone="warn" />,
    },
    {
      key: 'bounceRate',
      header: t('admin.bh.col.bounceRate'),
      sortable: true,
      align: 'end',
      render: (r) => <HeatCell text={num(formatPct(r.bounceRate))} ratio={r.bounceRate} tone="warn" />,
    },
    { key: 'sharePct', header: t('admin.bh.col.share'), align: 'end', render: (r) => num(formatPctPoints(r.sharePct)) },
  ];

  const empty = !q.isLoading && !q.isError && q.data && q.data.total === 0;
  return (
    <Card title={t('admin.bh.screens.title')} data-search-anchor="anl-behavior-screens">
      <p className={analytics.muted}>{t('admin.bh.screens.hint')}</p>
      {empty ? (
        <EmptyState icon="chart" title={t('admin.bh.screens.emptyTitle')} description={t('admin.bh.screens.emptyBody')} compact />
      ) : (
        <>
          <ResponsiveTable
            caption={t('admin.bh.screens.title')}
            columns={columns}
            rows={q.data ? items : undefined}
            rowKey={(r) => r.screen}
            loading={q.isLoading}
            error={q.isError && !q.data}
            onRetry={() => void q.refetch()}
            sort={sort}
            onSortChange={(next) => {
              setSort((cur) => nextSort(cur, next));
              setPage(0);
            }}
          />
          {q.data && (
            <Pagination
              page={q.data.page}
              totalPages={totalPagesOf(q.data.total, q.data.size || SCREEN_PAGE_SIZE)}
              totalItems={q.data.total}
              onPageChange={setPage}
            />
          )}
        </>
      )}
    </Card>
  );
}
