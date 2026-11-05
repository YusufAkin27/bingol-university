// SAYFA: Forum işlem kayıtları (/admin/forum/actions)
// API: GET /api/admin/forum/actions?action=&targetType=&cursor= (forum_moderation_action: aktör, eylem, hedef, gerekçe, tarih; api/adminForum.ts).
// Salt okunur kayıt defteridir; her moderatör eylemi gerekçesiyle burada ve denetim kaydında tutulur. Okuma `forum.read`.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { forumKeys, listActions, type ForumActionFilters, type ForumActionRow } from '../../../api/adminForum';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  LoadMore,
  PageHeader,
  Select,
  Table,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import styles from '../moderation/moderation.module.css';
import fs from './forum.module.css';
import { ACTION_KEYS } from './shared';
import { forumError, tf } from './tf';

const EMPTY: ForumActionFilters = { action: '', type: '' };
const ACTIONS = ['PIN', 'UNPIN', 'LOCK', 'UNLOCK', 'REMOVE', 'RESTORE'] as const;

export default function ForumActionsPage() {
  const i18n = useI18n();
  const { formatDateTime } = i18n;
  const f = tf(i18n);
  usePageTitle(f('admin.forum.actions.title'));
  const [filters, setFilters] = useState<ForumActionFilters>(EMPTY);
  const set = (p: Partial<ForumActionFilters>) => setFilters((s) => ({ ...s, ...p }));

  const list = useInfiniteQuery({
    queryKey: forumKeys.actions(filters),
    queryFn: ({ pageParam }) => listActions(filters, pageParam),
    initialPageParam: undefined as string | number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);
  const dirty = filters.action !== '' || filters.type !== '';

  const actionLabel = (a: string) => (ACTION_KEYS[a] ? f(ACTION_KEYS[a]) : a);
  const columns: Column<ForumActionRow>[] = [
    {
      key: 'createdAt',
      header: f('admin.forum.actions.col.when'),
      card: { priority: 3 },
      render: (r) => <time dateTime={r.createdAt}>{r.createdAt ? formatDateTime(r.createdAt) : '—'}</time>,
    },
    {
      key: 'actor',
      header: f('admin.forum.actions.col.actor'),
      card: { priority: 2 },
      render: (r) => <span dir="auto">{r.actorName ?? (r.actorId !== null ? `#${r.actorId}` : '—')}</span>,
    },
    {
      key: 'action',
      header: f('admin.forum.actions.col.action'),
      card: { priority: 1 },
      render: (r) => <Badge tone={r.action === 'REMOVE' ? 'danger' : 'neutral'}>{actionLabel(r.action)}</Badge>,
    },
    {
      key: 'target',
      header: f('admin.forum.actions.col.target'),
      card: { priority: 2 },
      render: (r) => (
        <span>
          {f(`admin.forum.type.${r.targetType}`)} <span className="ltr">#{r.targetId}</span>
        </span>
      ),
    },
    {
      key: 'reason',
      header: f('admin.forum.actions.col.reason'),
      render: (r) => <span dir="auto">{r.reason || '—'}</span>,
    },
  ];

  return (
    <>
      <PageHeader title={f('admin.forum.actions.title')} description={f('admin.forum.actions.intro')} />
      <div className={styles.stack}>
        <div className={fs.filters} role="search" aria-label={f('admin.forum.filters')} data-search-anchor="faction-filters">
          <FormField label={f('admin.forum.actions.filter.action')}>
            <Select value={filters.action} onChange={(e) => set({ action: e.target.value })}>
              <option value="">{f('admin.forum.status.all')}</option>
              {ACTIONS.map((a) => (
                <option key={a} value={a}>
                  {actionLabel(a)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={f('admin.forum.actions.filter.type')}>
            <Select value={filters.type} onChange={(e) => set({ type: e.target.value as ForumActionFilters['type'] })}>
              <option value="">{f('admin.forum.status.all')}</option>
              <option value="FORUM_TOPIC">{f('admin.forum.type.FORUM_TOPIC')}</option>
              <option value="FORUM_COMMENT">{f('admin.forum.type.FORUM_COMMENT')}</option>
            </Select>
          </FormField>
          {dirty && (
            <Button variant="ghost" size="sm" onClick={() => setFilters(EMPTY)}>
              {f('admin.forum.clear')}
            </Button>
          )}
        </div>

        {list.isError ? (
          <ErrorState description={forumError(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : !list.isLoading && rows.length === 0 ? (
          <EmptyState
            icon="list"
            title={f(dirty ? 'admin.forum.actions.empty.filtered' : 'admin.forum.actions.empty.title')}
            description={f('admin.forum.actions.empty.hint')}
          />
        ) : (
          <div data-search-anchor="faction-list">
            <Table
              columns={columns}
              rows={list.isLoading ? undefined : rows}
              rowKey={(r) => r.id}
              loading={list.isLoading}
              caption={f('admin.forum.actions.list')}
              mobile="cards"
            />
            <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
          </div>
        )}
      </div>
    </>
  );
}
