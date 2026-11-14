// SAYFA: Akademisyenler (/admin/academicians) - başvuru kuyruğu
// API: GET /api/admin/academicians?status=&approvalMode=&cursor=&size= (api/adminAcademicians.ts). Sayfalama imeç ile;
// sunucuda metin araması yoktur: arama kutusu yalnız yüklenmiş kayıtları süzer.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { acadKeys, listAcademicians, type AdminAcademician } from '../../../api/adminAcademicians';
import {
  EmptyState,
  Insight,
  LoadMore,
  PageHeader,
  ResponsiveTable,
  SearchInput,
  StatusPill,
  Tabs,
  type Column,
  type Tone,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { SearchAnchor, useSearchReveal } from '../../../search/anchor';
import { AcademicianActions } from './AcademicianActions';
import { ga } from './dict';
import { ACAD_TABS, matchesFilter, nameOf, paramsForTab, type AcadTab } from './logic';
import styles from './acad.module.css';

const PAGE_SIZE = 20;

export function statusTone(s: AdminAcademician['status']): Tone {
  if (s === 'APPROVED') return 'success';
  if (s === 'PENDING') return 'warning';
  return 'danger';
}

export function ReviewerCell({ a }: { a: AdminAcademician }) {
  const x = ga(useI18n());
  if (a.reviewedBy != null) {
    return (
      <Link to={paths.admin.user(a.reviewedBy)}>{x('admin.acad.reviewer.user', { id: a.reviewedBy })}</Link>
    );
  }
  if (a.status !== 'PENDING' && a.approvalMode === 'AUTO') return <>{x('admin.acad.reviewer.system')}</>;
  return <>{x('admin.acad.reviewer.none')}</>;
}

export default function AcademiciansList() {
  const i18n = useI18n();
  const { formatDateTime } = i18n;
  const x = ga(i18n);
  usePageTitle(x('admin.acad.title'));

  const [params, setParams] = useSearchParams();
  const param = params.get('tab') as AcadTab | null;
  const tab: AcadTab = param && ACAD_TABS.includes(param) ? param : 'pending';
  const [filter, setFilter] = useState('');
  // Arama derin bağlantısı: otomatik onay açıklaması yalnız o sekmede vardır
  useSearchReveal((anchor) => {
    if (anchor === 'acad-auto') setParams({ tab: 'auto' }, { replace: true });
  });
  const sv = paramsForTab(tab);

  const query = useInfiniteQuery({
    queryKey: [...acadKeys.list(tab, sv.approvalMode ?? ''), 'pages'],
    queryFn: ({ pageParam }) => listAcademicians({ ...sv, cursor: pageParam, size: PAGE_SIZE }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const loaded = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);
  const rows = useMemo(() => loaded.filter((a) => matchesFilter(a, filter)), [loaded, filter]);

  const tabs = ACAD_TABS.map((id) => ({ id, label: x(`admin.acad.tab.${id}`) }));
  const showDecision = tab !== 'pending';

  const columns: Column<AdminAcademician>[] = [
    {
      key: 'person',
      header: x('admin.acad.col.person'),
      headerLabel: x('admin.acad.col.person'),
      card: { priority: 1 },
      render: (a) => {
        const name = nameOf(a) || x('admin.acad.noName');
        return (
          <div className={styles.person}>
            <Link
              className={styles.personName}
              to={paths.admin.academician(a.userId)}
              aria-label={x('admin.acad.openDetailOf', { name })}
            >
              {a.title ? `${a.title} ` : ''}
              {name}
            </Link>
            <span className={styles.sub}>{a.unit || x('admin.acad.noUnit')}</span>
          </div>
        );
      },
    },
    {
      key: 'email',
      header: x('admin.acad.col.email'),
      headerLabel: x('admin.acad.col.email'),
      card: { priority: 2 },
      // Sunucunun döndürdüğü gibi: maskeliyse maskeli kalır, istemci açmaz.
      render: (a) => <span className={`${styles.email} ltr`}>{a.email ?? x('admin.acad.noEmail')}</span>,
    },
    {
      key: 'status',
      header: x('admin.acad.col.status'),
      headerLabel: x('admin.acad.col.status'),
      card: { priority: 3 },
      render: (a) => <StatusPill tone={statusTone(a.status)}>{x(`admin.acad.status.${a.status}`)}</StatusPill>,
    },
    {
      key: 'mode',
      header: x('admin.acad.col.mode'),
      headerLabel: x('admin.acad.col.mode'),
      render: (a) => (a.approvalMode ? x(`admin.acad.mode.${a.approvalMode}`) : x('admin.acad.mode.none')),
    },
    {
      key: 'applied',
      header: x('admin.acad.col.applied'),
      headerLabel: x('admin.acad.col.applied'),
      render: (a) => formatDateTime(a.createdAt),
    },
    {
      key: 'reviewer',
      header: x('admin.acad.col.reviewer'),
      headerLabel: x('admin.acad.col.reviewer'),
      render: (a) => <ReviewerCell a={a} />,
    },
    ...(showDecision
      ? ([
          {
            key: 'reviewedAt',
            header: x('admin.acad.col.reviewedAt'),
            headerLabel: x('admin.acad.col.reviewedAt'),
            render: (a) => (a.reviewedAt ? formatDateTime(a.reviewedAt) : '-'),
          },
        ] as Column<AdminAcademician>[])
      : []),
    ...(tab === 'rejected'
      ? ([
          {
            key: 'reason',
            header: x('admin.acad.col.reason'),
            headerLabel: x('admin.acad.col.reason'),
            render: (a) => <span className={styles.reason}>{a.rejectReason || '-'}</span>,
          },
        ] as Column<AdminAcademician>[])
      : []),
    {
      key: 'actions',
      header: <span className="sr-only">{x('admin.acad.col.actions')}</span>,
      headerLabel: x('admin.acad.col.actions'),
      align: 'end',
      card: { actions: true },
      render: (a) => <AcademicianActions a={a} />,
    },
  ];

  const pending = tab === 'pending';
  const emptyTitle = x(pending ? 'admin.acad.empty.pending.title' : 'admin.acad.empty.title');
  const emptyHint = x(pending ? 'admin.acad.empty.pending.hint' : 'admin.acad.empty.hint');

  return (
    <div>
      <PageHeader title={x('admin.acad.title')} description={x('admin.acad.description')} />
      <SearchAnchor id="acad-tabs" className={styles.tabsWrap}>
        <Tabs
          tabs={tabs}
          value={tab}
          label={x('admin.acad.tabs')}
          onChange={(id) => {
            const next = new URLSearchParams(params);
            if (id === 'pending') next.delete('tab');
            else next.set('tab', id);
            setParams(next, { replace: true });
          }}
        />
      </SearchAnchor>

      {tab === 'auto' && (
        <SearchAnchor id="acad-auto" className={styles.insightWrap}>
          <Insight tone="info" parts={[x('admin.acad.autoNote')]} />
        </SearchAnchor>
      )}

      <SearchAnchor id="acad-filter" className={styles.toolbar}>
        <div className={styles.search}>
          <SearchInput
            key={tab}
            onSearch={setFilter}
            delay={150}
            label={x('admin.acad.filter.label')}
            placeholder={x('admin.acad.filter.placeholder')}
          />
        </div>
      </SearchAnchor>

      <SearchAnchor id="acad-list">
        <ResponsiveTable<AdminAcademician>
          caption={x('admin.acad.title')}
          columns={columns}
          rows={rows}
          rowKey={(a) => a.userId}
          loading={query.isLoading}
          error={query.isError}
          onRetry={() => void query.refetch()}
          empty={
            loaded.length > 0 && rows.length === 0 ? (
              <EmptyState icon="search" title={x('admin.acad.filter.noMatch')} description={x('admin.acad.filter.hint')} />
            ) : (
              <EmptyState icon="graduation" title={emptyTitle} description={emptyHint} />
            )
          }
        />
        {query.isError && <p className={styles.hint}>{adminError(i18n, query.error)}</p>}
        <LoadMore
          hasMore={!!query.hasNextPage}
          loading={query.isFetchingNextPage}
          onLoadMore={() => void query.fetchNextPage()}
        />
      </SearchAnchor>
    </div>
  );
}
