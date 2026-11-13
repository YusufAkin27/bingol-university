// SAYFA: Gönderiler (/admin/posts) — Keşfet akışındaki gönderilerin moderasyonu.
// API: GET /api/admin/posts (süzgeçler: q, status, authorId, minReports, from/to; + /stats, /{id}), PATCH /{id} (metin düzenle),
// POST /{id}/hide|unhide, DELETE /{id} (api/adminPosts.ts). Önceden onay yok: gönderiler yayınlanır, yönetici sonradan denetler.
// Medya küçük resimleri yetkili uçtan (Bearer) blob olarak alınır; düzenleme/gizleme/silme denetim kaydına yazılır.
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
  Insight,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
  StatTile,
} from '../../components/ui';
import { useCan } from '../../auth/permissions';
import { Icon } from '../../components/ui/Icon';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { Lightbox } from './chat/Lightbox';
import { CreatePostModal } from './posts/CreatePostModal';
import { PostDetailDrawer } from './posts/PostDetail';
import { PostActionButtons, PostMediaThumb, StatusBadges, usePostActions } from './posts/PostParts';
import { EMPTY_POST_FILTERS, excerpt, mediaToLightbox, type PostFilterState } from './posts/postsLogic';
import type { AdminPostStatus } from '../../api/adminPosts';
import { PostGrid, PostStateChart, PostViewSwitch, type PostView } from './mod2/PostParts2';
import './mod2/dict';
import mod2 from './mod2/mod2.module.css';
import { useSearchReveal } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
import { FilterFold } from './moderation/v2';
import v2 from './moderation/v2.module.css';
import styles from './posts/posts.module.css';

const VIEWS = ['list', 'grid'] as const;

const STATUS_OPTIONS: AdminPostStatus[] = ['ALL', 'VISIBLE', 'HIDDEN', 'DELETED'];

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
          <span className={styles.authorText}>
            <span className={styles.authorName} dir="auto">
              {name}
            </span>
            <span className={`${styles.muted} ${styles.email} ltr`}>{post.author.email}</span>
          </span>
        </span>
        <time className={styles.muted} dateTime={post.createdAt}>
          {formatDateTime(post.createdAt)}
        </time>
      </div>
      <div className={styles.badgeRow}>
        <StatusBadges post={post} />
      </div>
      <p className={styles.text} dir="auto">
        {excerpt(post.text) || t('admin.posts.noText')}
      </p>
      {post.hiddenReason && (
        <p className={styles.reason}>{t('admin.posts.reasonShown', { reason: post.hiddenReason })}</p>
      )}
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
        </span>
        <span className={styles.spacer} />
        <Button size="sm" variant="secondary" onClick={onOpen}>
          {t('admin.posts.open')}
        </Button>
      </div>
      <PostActionButtons post={post} actions={actions} />
    </li>
  );
}

function PostsTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const [params, setParams] = useSearchParams();
  const openParam = Number(params.get('open'));
  const [openId, setOpenId] = useState<number | null>(
    Number.isInteger(openParam) && openParam > 0 ? openParam : null,
  );
  const [filters, setFilters] = useState<PostFilterState>(EMPTY_POST_FILTERS);
  const set = (p: Partial<PostFilterState>) => setFilters((f) => ({ ...f, ...p }));
  const q = useDebouncedValue(filters.q, 400);
  const f = useMemo(() => ({ ...filters, q }), [filters, q]);
  const [lb, setLb] = useState<{ post: AdminPostRow; index: number } | null>(null);
  const actions = usePostActions();
  const [view, setView] = useUrlTab<PostView>(VIEWS, 'list', 'view');
  // Arama "Gönderi listesi" / "Izgara" bölümüne giderken doğru görünümü açar (yan etkisiz, tekrar çağrılabilir)
  useSearchReveal((anchor) => {
    if (anchor === 'posts-list') setView('list');
    else if (anchor === 'posts-grid') setView('grid');
  });

  const stats = useQuery({
    queryKey: qk.adminPosts.stats(),
    queryFn: adminPostsApi.postStats,
    staleTime: 60_000,
  });
  const list = useInfiniteQuery({
    queryKey: qk.adminPosts.list(f),
    queryFn: ({ pageParam }) => adminPostsApi.listPosts(f, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    staleTime: 15_000,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);
  const s = stats.data;
  const activeCount = [
    filters.status !== 'ALL',
    filters.q.trim() !== '',
    filters.authorId !== '',
    filters.minReports !== '',
    filters.from !== '',
    filters.to !== '',
    filters.hasMedia,
  ].filter(Boolean).length;

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
      <p className={styles.note} data-search-anchor="posts-audit-note">
        {t('admin.posts.auditNote')}
      </p>
      <div className={v2.tiles} data-testid="post-stats" data-search-anchor="posts-stats">
        <StatTile
          label={t('admin.posts.stats.posts')}
          value={s ? s.postCount : undefined}
          loading={stats.isLoading}
          error={stats.isError}
          onRetry={() => void stats.refetch()}
          caption={s ? t('admin.posts.stats.last24h', { n: formatNumber(s.last24h.postCount) }) : undefined}
        />
        <StatTile
          label={t('admin.posts.stats.reported')}
          value={s ? s.openReportedCount : undefined}
          icon="alert"
          loading={stats.isLoading}
          error={stats.isError}
          caption={t('admin.v2m.posts.reportedHint')}
        />
        <StatTile
          label={t('admin.posts.stats.hidden')}
          value={s ? s.hiddenCount : undefined}
          loading={stats.isLoading}
          error={stats.isError}
          caption={t('admin.v2m.posts.hiddenHint')}
        />
      </div>
      {s && (
        <div className={mod2.chartGrid}>
          <PostStateChart stats={s} />
        </div>
      )}
      {s && (
        <Insight
          className={v2.sentence}
          tone={s.openReportedCount > 0 ? 'warn' : 'good'}
          parts={
            s.openReportedCount > 0
              ? [
                  {
                    text: t('admin.v2m.posts.sentenceReported', { n: formatNumber(s.openReportedCount) }),
                    tone: 'warn',
                  },
                  ' ',
                  t('admin.v2m.posts.sentenceNew', { n: formatNumber(s.last24h.postCount) }),
                ]
              : [
                  { text: t('admin.v2m.posts.sentenceClean'), tone: 'good' },
                  ' ',
                  t('admin.v2m.posts.sentenceNew', { n: formatNumber(s.last24h.postCount) }),
                ]
          }
        />
      )}
      {s && s.openReportedCount > 0 && filters.minReports !== '1' && (
        <div className={v2.touch}>
          <Button variant="secondary" size="sm" onClick={() => set({ minReports: '1', status: 'ALL' })}>
            {t('admin.v2m.posts.showReported')}
          </Button>
        </div>
      )}

      <div className={mod2.toolbar}>
        <PostViewSwitch value={view} onChange={setView} />
      </div>
      <FilterFold activeCount={activeCount} anchor="posts-filters">
        <FormField label={t('admin.posts.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as AdminPostStatus })}>
            {STATUS_OPTIONS.map((st) => (
              <option key={st} value={st}>
                {t(`admin.posts.status.${st}` as const)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.posts.filter.q')}>
          <Input
            type="search"
            value={filters.q}
            placeholder={t('admin.posts.filter.qPlaceholder')}
            onChange={(e) => set({ q: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.posts.filter.authorId')}>
          <Input
            type="text"
            inputMode="numeric"
            value={filters.authorId}
            onChange={(e) => set({ authorId: e.target.value.replace(/\D/g, '') })}
          />
        </FormField>
        <FormField label={t('admin.posts.filter.minReports')}>
          <Input
            type="text"
            inputMode="numeric"
            value={filters.minReports}
            onChange={(e) => set({ minReports: e.target.value.replace(/\D/g, '') })}
          />
        </FormField>
        <FormField label={t('admin.posts.filter.from')}>
          <Input type="date" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.posts.filter.to')}>
          <Input type="date" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
        <div className={`${styles.checks} ${v2.touch}`}>
          <Checkbox
            label={t('admin.posts.filter.hasMedia')}
            checked={filters.hasMedia}
            onChange={(e) => set({ hasMedia: e.target.checked })}
          />
          <Button variant="ghost" size="sm" onClick={() => setFilters(EMPTY_POST_FILTERS)}>
            {t('admin.posts.filter.reset')}
          </Button>
        </div>
      </FilterFold>

      {list.isError ? (
        <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <Skeleton height="14rem" width="100%" />
      ) : rows.length === 0 ? (
        <EmptyState icon="list" title={t('admin.posts.empty')} description=" " />
      ) : (
        <>
          {view === 'grid' ? (
            <PostGrid rows={rows} onOpen={openDetail} />
          ) : (
            <ul className={styles.list} data-testid="post-list" data-search-anchor="posts-list">
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
          )}
          <LoadMore
            hasMore={!!list.hasNextPage}
            loading={list.isFetchingNextPage}
            onLoadMore={() => void list.fetchNextPage()}
          />
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

export default function PostsAdminPage() {
  const { t } = useI18n();
  usePageTitle(t('admin.posts.title'));
  const [createOpen, setCreateOpen] = useState(false);
  const canCreate = useCan('content.write');
  return (
    <>
      <PageHeader
        title={t('admin.posts.title')}
        description={t('admin.posts.subtitle')}
        actions={
          canCreate ? (
            <Button
              leftIcon={<Icon name="plus" size={18} />}
              onClick={() => setCreateOpen(true)}
              data-testid="post-create-open"
            >
              Gönderi oluştur
            </Button>
          ) : undefined
        }
      />
      <CreatePostModal open={createOpen} onClose={() => setCreateOpen(false)} />
      <PostsTab />
    </>
  );
}
