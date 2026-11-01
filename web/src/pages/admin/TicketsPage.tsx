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
  Insight,
  LoadMore,
  PageHeader,
  ResponsiveTable,
  Select,
  StatTile,
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

const STATUSES: TicketStatus[] = ['OPEN', 'ANSWERED', 'CLOSED'];

export default function TicketsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const kit = useKitFormat();
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

  const waiting = rows.filter((r) => r.status === 'OPEN');
  const answered = rows.filter((r) => r.status === 'ANSWERED').length;
  const closed = rows.filter((r) => r.status === 'CLOSED').length;
  const oldestWaiting = waiting.reduce<string | null>((o, r) => (!o || r.updatedAt < o ? r.updatedAt : o), null);

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
    { key: 'category', header: t('admin.tickets.col.category'), render: (r) => t(`admin.tickets.category.${r.category}`) },
    {
      key: 'status',
      header: t('admin.tickets.col.status'),
      card: { priority: 2 },
      render: (r) => <StatusPill tone={toneFor(r.status)}>{t(`admin.tickets.status.${r.status}`)}</StatusPill>,
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
    { key: 'updated', header: t('admin.tickets.col.updated'), render: (r) => formatDateTime(r.updatedAt) },
  ];

  return (
    <>
      <PageHeader
        title={t('admin.tickets.title')}
        description={t('admin.v2m.tickets.desc')}
        actions={
          <CsvButton
            filename={csvName('talepler')}
            fetcher={() => supportAdminApi.exportTicketsCsv({ status, publicOnly })}
          />
        }
      />
      {query.isSuccess && (
        <>
          <div className={v2.tiles} data-search-anchor="tickets-summary">
            <StatTile
              label={t('admin.v2m.tickets.waiting')}
              value={waiting.length}
              icon="lifebuoy"
              caption={t(query.hasNextPage ? 'admin.v2m.tickets.waitingHintMore' : 'admin.v2m.tickets.waitingHint')}
            />
            <StatTile label={t('admin.v2m.tickets.answered')} value={answered} caption={t('admin.v2m.tickets.answeredHint')} />
            <StatTile label={t('admin.v2m.tickets.closed')} value={closed} caption={t('admin.v2m.tickets.closedHint')} />
          </div>
          <Insight
            className={v2.sentence}
            tone={waiting.length > 0 ? 'warn' : 'good'}
            parts={
              waiting.length > 0
                ? [
                    { text: t('admin.v2m.tickets.sentenceWaiting', { n: String(waiting.length) }), tone: 'warn' },
                    ...(oldestWaiting ? [' ', t('admin.v2m.tickets.sentenceOldest', { when: kit.relative(oldestWaiting) })] : []),
                  ]
                : [{ text: t('admin.v2m.tickets.sentenceNone'), tone: 'good' }]
            }
          />
        </>
      )}
      <DataToolbar
        filters={
          <>
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
          <label className={v2.checkRow} data-search-anchor="tickets-public-only" title={t('admin.v2m.tickets.publicOnlyHint')}>
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
