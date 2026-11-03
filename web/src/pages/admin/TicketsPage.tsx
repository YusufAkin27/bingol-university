// SAYFA: Destek talepleri (/admin/support/tickets)
// API: GET /api/admin/support/tickets?status=&publicOnly=&cursor=&size= (imeç tabanlı; api/support.ts).
// Kategori ve arama yüklenen satırlar üzerinde süzülür (sunucu bu iki süzgeci bilmez). Satır, talep ayrıntısına bağlantıdır.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { qk, supportAdminApi, supportApi } from '../../api';
import type { TicketRowExtra } from '../../api/supportAdmin';
import type { AdminTicketSummary, TicketCategory, TicketStatus } from '../../api/types';
import {
  Badge,
  EmptyState,
  ErrorState,
  Icon,
  Insight,
  LoadMore,
  PageHeader,
  SearchInput,
  Select,
  Skeleton,
  StatusPill,
  toneFor,
  useKitFormat,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import v2 from './moderation/v2.module.css';
import { CATEGORIES, filterTickets, rowTone } from './support/ticketsLogic';
import styles from './support/Tickets.module.css';

const STATUSES: TicketStatus[] = ['OPEN', 'ANSWERED', 'CLOSED'];
type Row = AdminTicketSummary & TicketRowExtra;

export default function TicketsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const kit = useKitFormat();
  usePageTitle(t('admin.tickets.title'));
  const [status, setStatus] = useState<TicketStatus | ''>('');
  const [category, setCategory] = useState<TicketCategory | ''>('');
  const [q, setQ] = useState('');
  const [publicOnly, setPublicOnly] = useState(false);

  const query = useInfiniteQuery({
    queryKey: qk.tickets.list(status || undefined, publicOnly),
    queryFn: ({ pageParam }) =>
      supportApi.listTickets({ status: status || undefined, publicOnly, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const loaded = useMemo(() => (query.data?.pages.flatMap((p) => p.items) ?? []) as Row[], [query.data]);
  const rows = useMemo(() => filterTickets(loaded, { category, q }), [loaded, category, q]);
  const clientFiltered = !!category || !!q;

  const waiting = loaded.filter((r) => r.status === 'OPEN');
  const answered = loaded.filter((r) => r.status === 'ANSWERED').length;
  const closed = loaded.filter((r) => r.status === 'CLOSED').length;
  const oldestWaiting = waiting.reduce<string | null>((o, r) => (!o || r.updatedAt < o ? r.updatedAt : o), null);

  return (
    <>
      <PageHeader
        title={t('admin.tickets.title')}
        description={t('admin.v2m.tickets.desc')}
        actions={
          <span data-search-anchor="tickets-csv">
            <CsvButton
              filename={csvName('talepler')}
              fetcher={() => supportAdminApi.exportTicketsCsv({ status, category, publicOnly })}
            />
          </span>
        }
      />

      {query.isSuccess && (
        <>
          <div
            className={styles.summary}
            data-search-anchor="tickets-summary"
            title={t(query.hasNextPage ? 'admin.v2m.tickets.waitingHintMore' : 'admin.v2m.tickets.waitingHint')}
          >
            <span className={`${styles.sum} ${waiting.length > 0 ? styles.sumWarn : ''}`}>
              <span className={styles.sumNum}>{waiting.length}</span>
              <span className={styles.sumLabel}>{t('admin.v2m.tickets.waiting')}</span>
            </span>
            <span className={styles.sum}>
              <span className={styles.sumNum}>{answered}</span>
              <span className={styles.sumLabel}>{t('admin.v2m.tickets.answered')}</span>
            </span>
            <span className={styles.sum}>
              <span className={styles.sumNum}>{closed}</span>
              <span className={styles.sumLabel}>{t('admin.v2m.tickets.closed')}</span>
            </span>
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

      <div className={styles.toolbar}>
        <div
          className={styles.seg}
          role="group"
          aria-label={t('admin.tickets.filter.status')}
          data-search-anchor="tickets-status"
        >
          <button type="button" className={styles.segBtn} aria-pressed={status === ''} onClick={() => setStatus('')}>
            {t('admin.support.list.all')}
          </button>
          {STATUSES.map((s) => (
            <button key={s} type="button" className={styles.segBtn} aria-pressed={status === s} onClick={() => setStatus(s)}>
              {t(`admin.tickets.status.${s}`)}
            </button>
          ))}
        </div>
        <Select
          aria-label={t('admin.tickets.col.category')}
          value={category}
          onChange={(e) => setCategory(e.target.value as TicketCategory | '')}
        >
          <option value="">{t('admin.support.list.allCategories')}</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {t(`admin.tickets.category.${c}`)}
            </option>
          ))}
        </Select>
        <div className={styles.search}>
          <SearchInput
            onSearch={setQ}
            placeholder={t('admin.support.list.searchPlaceholder')}
            label={t('admin.support.list.search')}
          />
        </div>
        <label className={v2.checkRow} data-search-anchor="tickets-public-only" title={t('admin.v2m.tickets.publicOnlyHint')}>
          <input type="checkbox" checked={publicOnly} onChange={(e) => setPublicOnly(e.target.checked)} />
          {t('admin.v2m.tickets.publicOnly')}
        </label>
      </div>
      {clientFiltered && query.isSuccess && (
        <p className={styles.filterNote} role="status">
          {t('admin.support.list.clientNote', { shown: String(rows.length), loaded: String(loaded.length) })}
        </p>
      )}

      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : query.isLoading ? (
        <div className={styles.list} aria-busy="true" aria-label={t('admin.tickets.list')}>
          {[0, 1, 2, 3, 4].map((i) => (
            <div key={i} className={styles.skel}>
              <Skeleton width="55%" height="1.1rem" />
              <Skeleton width="80%" height="0.9rem" />
            </div>
          ))}
        </div>
      ) : rows.length === 0 ? (
        <EmptyState
          icon="lifebuoy"
          title={t(clientFiltered ? 'admin.support.list.noMatch' : 'admin.tickets.empty.title')}
          description={t(clientFiltered && query.hasNextPage ? 'admin.support.list.noMatchMore' : 'admin.tickets.empty.hint')}
          compact
        />
      ) : (
        <ul className={styles.list} aria-label={t('admin.tickets.list')}>
          {rows.map((r) => {
            const files = r.attachmentCount ?? 0;
            return (
              <li key={r.id} className={`${styles.item} ${r.status === 'OPEN' ? styles.unread : ''}`}>
                <Link
                  to={paths.admin.ticket(r.id)}
                  state={{ email: r.userEmail, userId: r.userId }}
                  className={`${styles.row} ${styles[rowTone(r.status)] ?? ''}`}
                >
                  <span className={styles.main}>
                    <span className={styles.top}>
                      <strong dir="auto" className={styles.subject}>
                        {r.subject}
                      </strong>
                      <span className={styles.id}>#{r.id}</span>
                    </span>
                    <span className={styles.meta}>
                      <span className={styles.cat}>{t(`admin.tickets.category.${r.category}`)}</span>
                      {r.userEmail && <span className={`ltr ${styles.email}`}>{r.userEmail}</span>}
                      {r.publicTicket && <Badge tone="info">{t('admin.support.list.guest')}</Badge>}
                      {r.priority && r.priority !== 'NORMAL' && (
                        <Badge tone={r.priority === 'URGENT' ? 'danger' : r.priority === 'HIGH' ? 'warning' : 'neutral'}>
                          {t(`admin.p12.priority.${r.priority}`)}
                        </Badge>
                      )}
                      {r.assigneeId ? (
                        <span className="ltr">{t('admin.support.list.assignee', { id: String(r.assigneeId) })}</span>
                      ) : null}
                    </span>
                  </span>
                  <span className={styles.side}>
                    <StatusPill tone={toneFor(r.status)}>{t(`admin.tickets.status.${r.status}`)}</StatusPill>
                    <span className={styles.when}>
                      {files > 0 && (
                        <span className={styles.clip} title={t('admin.support.list.attachments', { n: String(files) })}>
                          <Icon name="paperclip" size={14} />
                          <span aria-hidden="true">{files}</span>
                          <span className="sr-only">{t('admin.support.list.attachments', { n: String(files) })}</span>
                        </span>
                      )}
                      <time dateTime={r.updatedAt} title={formatDateTime(r.updatedAt)}>
                        {kit.relative(r.updatedAt)}
                      </time>
                    </span>
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
      {!query.isError && (
        <div className={styles.more}>
          <LoadMore
            hasMore={!!query.hasNextPage}
            loading={query.isFetchingNextPage}
            onLoadMore={() => void query.fetchNextPage()}
          />
        </div>
      )}
    </>
  );
}
