// SAYFA: Destek talepleri (/admin/support/tickets)
// API: GET /api/admin/support/tickets?status=&cursor=&size= (imeç tabanlı; api/support.ts). Satıra tıklayınca ayrıntı sayfası açılır.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { qk, supportApi } from '../../api';
import type { AdminTicketSummary, TicketStatus } from '../../api/types';
import {
  DataToolbar,
  EmptyState,
  ErrorState,
  LoadMore,
  PageHeader,
  Select,
  StatusPill,
  Table,
  toneFor,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './support/Support.module.css';
import { paths } from '../../paths';

const STATUSES: TicketStatus[] = ['OPEN', 'ANSWERED', 'CLOSED'];

export default function TicketsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.tickets.title'));
  const navigate = useNavigate();
  const [status, setStatus] = useState<TicketStatus | ''>('');

  const query = useInfiniteQuery({
    queryKey: qk.tickets.list(status || undefined),
    queryFn: ({ pageParam }) =>
      supportApi.listTickets({ status: status || undefined, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const rows = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);

  const columns: Column<AdminTicketSummary>[] = [
    {
      key: 'subject',
      header: t('admin.tickets.col.subject'),
      render: (r) => (
        <span style={{ display: 'grid', gap: 2, minWidth: '12rem' }}>
          <strong dir="auto" style={{ overflowWrap: 'anywhere' }}>
            {r.subject}
          </strong>
          <span style={{ color: 'var(--text-faint)', fontSize: 'var(--text-xs)' }}>#{r.id}</span>
        </span>
      ),
    },
    { key: 'category', header: t('admin.tickets.col.category'), render: (r) => t(`admin.tickets.category.${r.category}`) },
    {
      key: 'status',
      header: t('admin.tickets.col.status'),
      render: (r) => <StatusPill tone={toneFor(r.status)}>{t(`admin.tickets.status.${r.status}`)}</StatusPill>,
    },
    { key: 'user', header: t('admin.tickets.col.user'), render: (r) => <span className="ltr">{r.userEmail}</span> },
    { key: 'updated', header: t('admin.tickets.col.updated'), render: (r) => formatDateTime(r.updatedAt) },
  ];

  return (
    <>
      <PageHeader title={t('admin.tickets.title')} description={t('admin.tickets.subtitle')} />
      <DataToolbar
        filters={
          <Select className={styles.filter}
            aria-label={t('admin.tickets.filter.status')}
            value={status}
            onChange={(e) => setStatus(e.target.value as TicketStatus | '')}
          >
            <option value="">{t('admin.tickets.filter.all')}</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.tickets.status.${s}`)}
              </option>
            ))}
          </Select>
        }
      />
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : (
        <>
          <Table
            caption={t('admin.tickets.list')}
            columns={columns}
            rows={rows}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            onRowClick={(r) => navigate(paths.admin.ticket(r.id), { state: { email: r.userEmail, userId: r.userId } })}
            empty={
              <EmptyState
                icon="lifebuoy"
                title={t('admin.tickets.empty.title')}
                description={t('admin.tickets.empty.hint')}
                compact
              />
            }
          />
          <LoadMore
            hasMore={!!query.hasNextPage}
            loading={query.isFetchingNextPage}
            onLoadMore={() => void query.fetchNextPage()}
          />
        </>
      )}
    </>
  );
}
