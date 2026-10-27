// SAYFA: Gönderiler (/admin/posts) — Keşfet akışındaki gönderilerin moderasyonu.
// API: GET /api/admin/posts (+ /stats, /{id}, /{id}/comments), POST /{id}/hide|unhide, DELETE /{id} (api/adminPosts.ts).
// Medya küçük resimleri yetkili uçtan (Bearer) blob olarak alınır; gizleme/silme denetim kaydına yazılır.
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { adminPostsApi, qk } from '../../api';
import type { AdminPostRow } from '../../api/adminPosts';
import {
  Avatar,
  Button,
  Checkbox,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  PageHeader,
  Skeleton,
  StatCard,
  Tabs,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { Lightbox } from './chat/Lightbox';
import { PostDetailDrawer } from './posts/PostDetail';
import { StoriesTab, TagsTab } from './posts/SocialTabs';
import { PostActionButtons, PostMediaThumb, StatusBadges, usePostActions } from './posts/PostParts';
import { EMPTY_POST_FILTERS, excerpt, mediaToLightbox, type PostFilterState } from './posts/postsLogic';
import styles from './posts/posts.module.css';

function PostRowItem({
  post,
  onOpen,
  onMedia,
  actions,
}: {
  post: AdminPostRow;
  onOpen: () => void;
  onMedia: (index: number) => void;
  actions: ReturnType<typeof usePostActions>;
}) {
  const { t, formatDateTime } = useI18n();
  const name = post.author.displayName ?? `#${post.author.id}`;
  return (
    <li className={styles.row} data-testid="post-row">
      <div className={styles.rowHead}>
        <span className={styles.author}>
          <Avatar name={name} src={post.author.avatarUrl} size={32} />
          <span className={styles.authorName} dir="auto">
            {name}
          </span>
          <span className={`${styles.muted} ltr`}>{post.author.email}</span>
        </span>
        <StatusBadges post={post} />
        <span className={styles.spacer} />
        <time className={styles.muted} dateTime={post.createdAt}>
          {formatDateTime(post.createdAt)}
        </time>
      </div>
      <p className={styles.text} dir="auto">
        {excerpt(post.text) || t('admin.posts.noText')}
      </p>
      {post.hiddenReason && <p className={styles.reason}>{t('admin.posts.reasonShown', { reason: post.hiddenReason })}</p>}
      {post.media.length > 0 && (
        <div className={styles.thumbs}>
          {post.media.slice(0, 6).map((m, i) => (
            <PostMediaThumb key={m.id} media={m} onOpen={() => onMedia(i)} />
          ))}
          {post.media.length > 6 && <span className={styles.muted}>+{post.media.length - 6}</span>}
        </div>
      )}
      <div className={styles.rowHead}>
        <span className={styles.meta}>
          <span>{t('admin.posts.likes', { n: post.likeCount })}</span>
          <span>{t('admin.posts.comments', { n: post.commentCount })}</span>
        </span>
        <span className={styles.spacer} />
        <Button size="sm" variant="ghost" onClick={onOpen}>
          {t('admin.posts.open')}
        </Button>
        <PostActionButtons post={post} actions={actions} />
      </div>
    </li>
  );
}

function PostsTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const [params, setParams] = useSearchParams();
  const openParam = Number(params.get('open'));
  const [openId, setOpenId] = useState<number | null>(Number.isInteger(openParam) && openParam > 0 ? openParam : null);
  const [filters, setFilters] = useState<PostFilterState>(EMPTY_POST_FILTERS);
  const set = (p: Partial<PostFilterState>) => setFilters((f) => ({ ...f, ...p }));
  const q = useDebouncedValue(filters.q, 400);
  const f = useMemo(() => ({ ...filters, q }), [filters, q]);
  const [lb, setLb] = useState<{ post: AdminPostRow; index: number } | null>(null);
  const actions = usePostActions();

  const stats = useQuery({ queryKey: qk.adminPosts.stats(), queryFn: adminPostsApi.postStats, staleTime: 60_000 });
  const list = useInfiniteQuery({
    queryKey: qk.adminPosts.list(f),
    queryFn: ({ pageParam }) => adminPostsApi.listPosts(f, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    staleTime: 15_000,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);
  const s = stats.data;
  const n = (v: number | undefined) => (v === undefined ? '—' : formatNumber(v));

  function openDetail(id: number | null) {
    setOpenId(id);
    if (id === null && params.has('open')) {
      const next = new URLSearchParams(params);
      next.delete('open');
      setParams(next, { replace: true });
    }
  }

  return (
    <>
      <p className={styles.note}>{t('admin.posts.auditNote')}</p>
      <div className={styles.statGrid} data-testid="post-stats">
        <StatCard title={t('admin.posts.stats.posts')} value={n(s?.postCount)} loading={stats.isLoading}
          hint={s ? t('admin.posts.stats.last24h', { n: formatNumber(s.last24h.postCount) }) : undefined} />
        <StatCard title={t('admin.posts.stats.comments')} value={n(s?.commentCount)} loading={stats.isLoading} />
        <StatCard title={t('admin.posts.stats.likes')} value={n(s?.likeCount)} loading={stats.isLoading} />
        <StatCard title={t('admin.posts.stats.media')} value={n(s?.mediaCount)} loading={stats.isLoading} />
        <StatCard title={t('admin.posts.stats.hidden')} value={n(s?.hiddenCount)} loading={stats.isLoading} />
      </div>

      <div className={styles.filters} role="search" aria-label={t('admin.posts.filters')}>
        <FormField label={t('admin.posts.filter.q')}>
          <Input
            type="search"
            value={filters.q}
            placeholder={t('admin.posts.filter.qPlaceholder')}
            onChange={(e) => set({ q: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.posts.filter.from')}>
          <Input type="date" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.posts.filter.to')}>
          <Input type="date" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
        <div className={styles.checks}>
          <Checkbox label={t('admin.posts.filter.hidden')} checked={filters.hidden} onChange={(e) => set({ hidden: e.target.checked })} />
          <Checkbox label={t('admin.posts.filter.deleted')} checked={filters.deleted} onChange={(e) => set({ deleted: e.target.checked })} />
          <Checkbox label={t('admin.posts.filter.hasMedia')} checked={filters.hasMedia} onChange={(e) => set({ hasMedia: e.target.checked })} />
          <Button variant="ghost" size="sm" onClick={() => setFilters(EMPTY_POST_FILTERS)}>
            {t('admin.posts.filter.reset')}
          </Button>
        </div>
      </div>

      {list.isError ? (
        <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <Skeleton height="14rem" width="100%" />
      ) : rows.length === 0 ? (
        <EmptyState icon="list" title={t('admin.posts.empty')} description=" " />
      ) : (
        <>
          <ul className={styles.list} data-testid="post-list">
            {rows.map((p) => (
              <PostRowItem
                key={p.id}
                post={p}
                actions={actions}
                onOpen={() => openDetail(p.id)}
                onMedia={(index) => setLb({ post: p, index })}
              />
            ))}
          </ul>
          <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
        </>
      )}

      {openId !== null && <PostDetailDrawer postId={openId} onClose={() => openDetail(null)} />}
      {lb && (
        <Lightbox
          items={mediaToLightbox(lb.post)}
          index={lb.index}
          onIndex={(index) => setLb({ post: lb.post, index })}
          onClose={() => setLb(null)}
        />
      )}
      {actions.dialogs}
    </>
  );
}

type SocialTab = 'posts' | 'stories' | 'tags';

export default function PostsAdminPage() {
  const { t } = useI18n();
  usePageTitle(t('admin.posts.title'));
  const [tab, setTab] = useState<SocialTab>('posts');
  return (
    <>
      <PageHeader title={t('admin.posts.title')} description={t('admin.posts.subtitle')} />
      <Tabs
        label={t('admin.social.tabs')}
        value={tab}
        onChange={(id) => setTab(id as SocialTab)}
        tabs={[
          { id: 'posts', label: t('admin.social.tab.posts') },
          { id: 'stories', label: t('admin.social.tab.stories') },
          { id: 'tags', label: t('admin.social.tab.tags') },
        ]}
      >
        {tab === 'posts' ? <PostsTab /> : tab === 'stories' ? <StoriesTab /> : <TagsTab />}
      </Tabs>
    </>
  );
}
