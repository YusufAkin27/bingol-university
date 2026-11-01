// SAYFA: Destek talepleri (/admin/support/tickets)
// API: GET /api/admin/support/tickets?status=&cursor=&size= (imeç tabanlı; api/support.ts). Satıra tıklayınca ayrıntı sayfası açılır.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { qk, supportAdminApi, supportApi } from '../../api';
import type { TicketRowExtra } from '../../api/supportAdmin';
import type { AdminTicketSummary, TicketStatus } from '../../api/types';
import {
  DataToolbar,
  EmptyState,
  ErrorState,
  Icon,
  LoadMore,
  PageHeader,
  ResponsiveTable,
  Select,
  StatusPill,
  Badge,
  toneFor,
  useKitFormat,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import v2 from './moderation/v2.module.css';
import styles from './support/Support.module.css';
import { paths } from '../../paths';
import { useIl } from './iletisim/il';
import il2 from './iletisim/iletisim.module.css';
import { ageKeyOf, type AgeKey } from './iletisim/logic';
import { TicketsOverview } from './iletisim/TicketsOverview';

const STATUSES: TicketStatus[] = ['OPEN', 'ANSWERED', 'CLOSED'];
/** Bekleyen talebin yaşına göre rozet tonu: ne kadar eskiyse o kadar acil. */
const AGE_TONE: Record<AgeKey, 'neutral' | 'info' | 'warning' | 'danger'> = {
  lt4h: 'neutral',
  lt24h: 'info',
  lt3d: 'warning',
  gt3d: 'danger',
};

export default function TicketsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const kit = useKitFormat();
  const il = useIl();
  usePageTitle(t('admin.tickets.title'));
  const navigate = useNavigate();
  const [status, setStatus] = useState<TicketStatus | ''>('');
  const [publicOnly, setPublicOnly] = useState(false);

  const query = useInfiniteQuery({
    queryKey: qk.tickets.list(status || undefined, publicOnly),
    queryFn: ({ pageParam }) =>
      supportApi.listTickets({ status: status || undefined, publicOnly, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const rows = useMemo(
    () => (query.data?.pages.flatMap((p) => p.items) ?? []) as (AdminTicketSummary & TicketRowExtra)[],
    [query.data],
  );

  const columns: Column<AdminTicketSummary & TicketRowExtra>[] = [
    {
      key: 'subject',
      header: t('admin.tickets.col.subject'),
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.subjectCell}>
          <span className={styles.subjectText}>
            <strong dir="auto" className={styles.subjectStrong}>
              {r.subject}
            </strong>
            <span className={styles.subjectId}>#{r.id}</span>
          </span>
          <Icon name="chevronRight" size={18} aria-hidden="true" />
        </span>
      ),
    },
    {
      key: 'category',
      header: t('admin.tickets.col.category'),
      render: (r) => t(`admin.tickets.category.${r.category}`),
    },
    {
      key: 'status',
      header: t('admin.tickets.col.status'),
      card: { priority: 2 },
      render: (r) => (
        <span className={il2.nowrap}>
          <StatusPill tone={toneFor(r.status)}>{t(`admin.tickets.status.${r.status}`)}</StatusPill>
        </span>
      ),
    },
    {
      key: 'user',
      header: t('admin.tickets.col.user'),
      card: { priority: 3 },
      render: (r) => (
        <span className={styles.userCell}>
          <span className={`ltr ${styles.emailBreak}`}>{r.userEmail}</span>
          {r.publicTicket && <Badge tone="info">{t('admin.tickets.public.badge')}</Badge>}
        </span>
      ),
    },
    {
      key: 'priority',
      header: t('admin.p12.col.priority'),
      render: (r) =>
        r.priority && r.priority !== 'NORMAL' ? (
          <Badge tone={r.priority === 'URGENT' ? 'danger' : r.priority === 'HIGH' ? 'warning' : 'neutral'}>
            {t(`admin.p12.priority.${r.priority}`)}
          </Badge>
        ) : (
          '—'
        ),
    },
    {
      key: 'assignee',
      header: t('admin.p12.col.assignee'),
      render: (r) => (r.assigneeId ? <span className="ltr">#{r.assigneeId}</span> : '—'),
    },
    {
      key: 'wait',
      header: il('admin.il.tk.col.wait'),
      card: { priority: 2 },
      render: (r) =>
        r.status === 'OPEN' ? (
          <Badge tone={AGE_TONE[ageKeyOf(r.updatedAt)]}>{kit.relative(r.updatedAt)}</Badge>
        ) : (
          '—'
        ),
    },
    { key: 'updated', header: t('admin.tickets.col.updated'), render: (r) => formatDateTime(r.updatedAt) },
  ];

  return (
    <>
      <PageHeader
        title={t('admin.tickets.title')}
        description={t('admin.v2m.tickets.desc')}
        actions={
          <span data-search-anchor="tickets-csv">
            <CsvButton
              filename={csvName('talepler')}
              fetcher={() => supportAdminApi.exportTicketsCsv({ status, publicOnly })}
            />
          </span>
        }
      />
      <TicketsOverview status={status} onStatus={setStatus} />
      <DataToolbar
        filters={
          <>
            <Select
              className={styles.filter}
              data-search-anchor="tickets-status"
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
            <label
              className={v2.checkRow}
              data-search-anchor="tickets-public-only"
              title={t('admin.v2m.tickets.publicOnlyHint')}
            >
              <input type="checkbox" checked={publicOnly} onChange={(e) => setPublicOnly(e.target.checked)} />
              {t('admin.v2m.tickets.publicOnly')}
            </label>
          </>
        }
      />
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : (
        <>
          <ResponsiveTable
            caption={t('admin.tickets.list')}
            columns={columns}
            rows={rows}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            onRowClick={(r) =>
              navigate(paths.admin.ticket(r.id), { state: { email: r.userEmail, userId: r.userId } })
            }
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
