// SAYFA: Forum konuları (/admin/forum/topics)
// API: GET /api/admin/forum/topics?q=&status=&categoryId=&page= (sayfa tabanlı), POST .../topics/{id}/moderate {action, reason} (api/adminForum.ts).
// Okuma `forum.read`; sabitle/kilitle/kaldır/geri al `forum.moderate` ve HEP gerekçe ister. Anonim konuda yazar "Anonim" görünür.
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { forumKeys, listCategories, listTopics, type ForumTopicFilters, type ForumTopicRow } from '../../../api/adminForum';
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../../lib/hooks';
import styles from '../moderation/moderation.module.css';
import fs from './forum.module.css';
import { authorLabel, ContentBadges, excerpt, useForumCan, useForumModeration, type ModAction } from './shared';
import { forumError, tf } from './tf';

const EMPTY: ForumTopicFilters = { q: '', status: '', categoryId: '' };

/** Satıra uygun moderatör eylemleri (duruma göre karşıt çift): sabit, kilit, kaldır. */
export function topicActions(t: Pick<ForumTopicRow, 'status' | 'pinned' | 'locked'>): ModAction[] {
  if (t.status === 'REMOVED') return ['RESTORE'];
  return [t.pinned ? 'UNPIN' : 'PIN', t.locked ? 'UNLOCK' : 'LOCK', 'REMOVE'];
}

export default function ForumTopicsPage() {
  const i18n = useI18n();
  const { formatNumber, formatDateTime } = i18n;
  const f = tf(i18n);
  usePageTitle(f('admin.forum.topics.title'));
  const canModerate = useForumCan('forum.moderate');
  const mod = useForumModeration();
  const [filters, setFilters] = useState<ForumTopicFilters>(EMPTY);
  const [page, setPage] = useState(0);
  const [openId, setOpenId] = useState<number | null>(null);
  const set = (p: Partial<ForumTopicFilters>) => {
    setFilters((s) => ({ ...s, ...p }));
    setPage(0);
  };
  const clear = () => {
    setFilters(EMPTY);
    setPage(0);
  };
  const q = useDebouncedValue(filters.q ?? '', 400);
  const applied = useMemo(() => ({ ...filters, q }), [filters, q]);

  const list = useQuery({
    queryKey: forumKeys.topics({ ...applied, page }),
    queryFn: () => listTopics(applied, page),
    placeholderData: (prev) => prev,
  });
  // Kategori süzgeci kategori okuma iznine bağlıdır: alınamazsa (403) süzgeç gizlenir, liste çalışmaya devam eder
  const cats = useQuery({ queryKey: forumKeys.categories(), queryFn: listCategories, retry: false });
  const rows = list.data?.items ?? [];
  const open = rows.find((r) => r.id === openId) ?? null;
  const activeCount = [applied.q?.trim(), applied.status, applied.categoryId].filter(Boolean).length;

  const actionButtons = (row: ForumTopicRow) =>
    canModerate ? (
      <div className={styles.actions}>
        {topicActions(row).map((a) => (
          <Button
            key={a}
            size="sm"
            variant={a === 'REMOVE' ? 'danger' : 'secondary'}
            onClick={() => mod.ask({ type: 'FORUM_TOPIC', id: row.id, title: row.title }, a)}
          >
            {f(`admin.forum.action.${a}`)}
          </Button>
        ))}
      </div>
    ) : null;

  return (
    <>
      <PageHeader title={f('admin.forum.topics.title')} description={f('admin.forum.topics.intro')} />
      <div className={styles.stack}>
        {!canModerate && (
          <p className={styles.muted} role="status">
            {f('admin.forum.readOnly')}
          </p>
        )}
        <div className={fs.filters} role="search" aria-label={f('admin.forum.filters')} data-search-anchor="ftopic-filters">
          <FormField label={f('admin.forum.topics.filter.q')}>
            <Input
              type="search"
              value={filters.q ?? ''}
              placeholder={f('admin.forum.topics.filter.qPlaceholder')}
              onChange={(e) => set({ q: e.target.value })}
            />
          </FormField>
          <FormField label={f('admin.forum.topics.filter.status')}>
            <Select value={filters.status ?? ''} onChange={(e) => set({ status: e.target.value as ForumTopicFilters['status'] })}>
              <option value="">{f('admin.forum.status.all')}</option>
              <option value="ACTIVE">{f('admin.forum.status.ACTIVE')}</option>
              <option value="REMOVED">{f('admin.forum.status.REMOVED')}</option>
            </Select>
          </FormField>
          {cats.data && cats.data.length > 0 && (
            <FormField label={f('admin.forum.topics.filter.category')}>
              <Select value={filters.categoryId ?? ''} onChange={(e) => set({ categoryId: e.target.value })}>
                <option value="">{f('admin.forum.status.all')}</option>
                {cats.data.map((c) => (
                  <option key={c.id} value={String(c.id)}>
                    {c.nameTr}
                    {c.active ? '' : ` (${f('admin.forum.cat.status.archived')})`}
                  </option>
                ))}
              </Select>
            </FormField>
          )}
          {activeCount > 0 && (
            <Button variant="ghost" size="sm" onClick={clear}>
              {f('admin.forum.clear')}
            </Button>
          )}
        </div>

        {list.isError ? (
          <ErrorState description={forumError(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="10rem" width="100%" />
        ) : rows.length === 0 ? (
          <EmptyState
            icon="message"
            title={f(activeCount > 0 ? 'admin.forum.topics.empty.filtered' : 'admin.forum.topics.empty.title')}
            description={f('admin.forum.topics.empty.hint')}
          />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={f('admin.forum.topics.list')} data-search-anchor="ftopic-list">
              {rows.map((row) => (
                <li key={row.id} className={styles.item} data-testid="forum-topic-row">
                  <div className={styles.itemHead}>
                    <h2 className={fs.title} dir="auto">
                      {row.title}
                    </h2>
                    <ContentBadges removed={row.status === 'REMOVED'} pinned={row.pinned} locked={row.locked} anonymous={row.anonymous} />
                    {row.openReportCount > 0 && (
                      <Badge tone="danger">{f('admin.forum.reportsBadge', { n: formatNumber(row.openReportCount) })}</Badge>
                    )}
                  </div>
                  <p className={fs.meta}>
                    {row.categoryName && <span dir="auto">{row.categoryName}</span>}
                    <span dir="auto">{authorLabel(row.authorName, row.anonymous, f('admin.forum.anonymous'))}</span>
                    <time dateTime={row.createdAt}>{row.createdAt ? formatDateTime(row.createdAt) : '—'}</time>
                    <span>{f('admin.forum.comments', { n: formatNumber(row.commentCount) })}</span>
                    <span>{f('admin.forum.likes', { n: formatNumber(row.likeCount) })}</span>
                  </p>
                  <div className={styles.actions}>
                    <Button size="sm" variant="secondary" onClick={() => setOpenId(row.id)}>
                      {f('admin.forum.topics.detail')}
                    </Button>
                  </div>
                  {actionButtons(row)}
                </li>
              ))}
            </ul>
            <Pagination page={page} totalPages={list.data?.totalPages ?? 1} totalItems={list.data?.totalItems} onPageChange={setPage} />
          </>
        )}
      </div>

      <Drawer open={open !== null} onClose={() => setOpenId(null)} title={f('admin.forum.topics.detailTitle')}>
        {open && (
          <div className={fs.detail}>
            <h3 className={fs.title} dir="auto">
              {open.title}
            </h3>
            <div className={styles.chips}>
              <ContentBadges removed={open.status === 'REMOVED'} pinned={open.pinned} locked={open.locked} anonymous={open.anonymous} />
            </div>
            <p className={fs.snippet} dir="auto">
              {excerpt(open.body, 2000) || '—'}
            </p>
            {open.removedReason && (
              <p className={fs.note}>{f('admin.forum.topics.removedReason', { reason: open.removedReason })}</p>
            )}
            <dl className={fs.facts}>
              <div>
                <dt>{f('admin.forum.topics.fact.author')}</dt>
                <dd dir="auto">{authorLabel(open.authorName, open.anonymous, f('admin.forum.anonymous'))}</dd>
              </div>
              <div>
                <dt>{f('admin.forum.topics.fact.category')}</dt>
                <dd dir="auto">{open.categoryName ?? '—'}</dd>
              </div>
              <div>
                <dt>{f('admin.forum.topics.fact.comments')}</dt>
                <dd>{formatNumber(open.commentCount)}</dd>
              </div>
              <div>
                <dt>{f('admin.forum.topics.fact.likes')}</dt>
                <dd>{formatNumber(open.likeCount)}</dd>
              </div>
              <div>
                <dt>{f('admin.forum.topics.fact.reports')}</dt>
                <dd>{formatNumber(open.openReportCount)}</dd>
              </div>
              <div>
                <dt>{f('admin.forum.topics.fact.created')}</dt>
                <dd>{open.createdAt ? formatDateTime(open.createdAt) : '—'}</dd>
              </div>
            </dl>
            {actionButtons(open)}
          </div>
        )}
      </Drawer>
      {mod.dialogs}
    </>
  );
}
