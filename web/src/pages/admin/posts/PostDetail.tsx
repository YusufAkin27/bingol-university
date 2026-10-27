// Gönderi ayrıntı paneli: tam metin, medya (Lightbox), yorum listesi ve yorum gizle/geri aç/sil.
// API: GET /api/admin/posts/{id}, /posts/{id}/comments; POST /comments/{id}/hide|unhide; DELETE /comments/{id}.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { adminPostsApi, qk } from '../../../api';
import type { AdminPostCommentRow } from '../../../api/adminPosts';
import {
  Avatar,
  Badge,
  Button,
  ConfirmDialog,
  Drawer,
  EmptyState,
  ErrorState,
  LoadMore,
  Skeleton,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { Lightbox } from '../chat/Lightbox';
import { PostActionButtons, PostMediaThumb, StatusBadges, usePostActions } from './PostParts';
import { mediaToLightbox } from './postsLogic';
import styles from './posts.module.css';

function CommentItem({ c, onChanged }: { c: AdminPostCommentRow; onChanged: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const toast = useToast();
  const [confirmDelete, setConfirmDelete] = useState(false);
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));
  const hide = useMutation({
    mutationFn: () => (c.hidden ? adminPostsApi.unhideComment(c.id) : adminPostsApi.hideComment(c.id)),
    onSuccess: () => {
      toast.success(c.hidden ? t('admin.posts.comments.unhiddenDone') : t('admin.posts.comments.hiddenDone'));
      onChanged();
    },
    onError,
  });
  const del = useMutation({
    mutationFn: () => adminPostsApi.deleteComment(c.id),
    onSuccess: () => {
      toast.success(t('admin.posts.comments.deletedDone'));
      setConfirmDelete(false);
      onChanged();
    },
    onError,
  });
  const name = c.author.displayName ?? `#${c.author.id}`;
  return (
    <li className={`${styles.comment} ${c.depth > 0 ? styles.reply : ''} ${c.deleted ? styles.dim : ''}`} data-testid="post-comment">
      <div className={styles.rowHead}>
        <span className={styles.author}>
          <Avatar name={name} src={c.author.avatarUrl} size={24} />
          <span className={styles.authorName} dir="auto">
            {name}
          </span>
        </span>
        {c.depth > 0 && <Badge tone="neutral">{t('admin.posts.comments.reply')}</Badge>}
        {c.deleted && <Badge tone="danger">{t('admin.posts.badge.deleted')}</Badge>}
        {c.hidden && <Badge tone="warning">{t('admin.posts.badge.hidden')}</Badge>}
        <time className={styles.muted} dateTime={c.createdAt}>
          {formatDateTime(c.createdAt)}
        </time>
      </div>
      <p className={styles.text} dir="auto">
        {c.text ?? t('admin.posts.comments.deletedBody')}
      </p>
      {!c.deleted && (
        <div className={styles.actions}>
          <Button size="sm" variant="secondary" loading={hide.isPending} onClick={() => hide.mutate()}>
            {c.hidden ? t('admin.posts.comments.unhide') : t('admin.posts.comments.hide')}
          </Button>
          <Button size="sm" variant="danger" onClick={() => setConfirmDelete(true)}>
            {t('admin.posts.comments.delete')}
          </Button>
        </div>
      )}
      <ConfirmDialog
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        onConfirm={() => del.mutate()}
        title={t('admin.posts.comments.deleteTitle')}
        message={t('admin.posts.comments.deleteMessage')}
        confirmLabel={t('admin.posts.comments.delete')}
        danger
        loading={del.isPending}
      />
    </li>
  );
}

function CommentList({ postId }: { postId: number }) {
  const i18n = useI18n();
  const { t } = i18n;
  const qc = useQueryClient();
  const q = useInfiniteQuery({
    queryKey: qk.adminPosts.comments(postId),
    queryFn: ({ pageParam }) => adminPostsApi.listPostComments(postId, pageParam, 30),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);
  const changed = () => void qc.invalidateQueries({ queryKey: ['adminPosts'] });
  if (q.isError) return <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />;
  if (q.isLoading) return <Skeleton height="6rem" width="100%" />;
  if (items.length === 0) return <EmptyState compact icon="message" title={t('admin.posts.comments.empty')} description=" " />;
  return (
    <>
      <ul className={styles.comments} data-testid="post-comments">
        {items.map((c) => (
          <CommentItem key={c.id} c={c} onChanged={changed} />
        ))}
      </ul>
      <LoadMore hasMore={!!q.hasNextPage} loading={q.isFetchingNextPage} onLoadMore={() => void q.fetchNextPage()} />
    </>
  );
}

export function PostDetailDrawer({ postId, onClose }: { postId: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({ queryKey: qk.adminPosts.detail(postId), queryFn: () => adminPostsApi.getPost(postId) });
  const actions = usePostActions(() => onClose());
  const [lb, setLb] = useState<number | null>(null);
  const post = q.data?.post;
  const items = useMemo(() => (post ? mediaToLightbox(post) : []), [post]);
  const name = post?.author.displayName ?? (post ? `#${post.author.id}` : '');

  return (
    <Drawer open onClose={onClose} title={t('admin.posts.detail.title', { id: postId })} size="lg">
      {q.isError ? (
        <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading || !post ? (
        <Skeleton height="10rem" width="100%" />
      ) : (
        <div className={styles.detail} data-testid="post-detail">
          <div className={styles.rowHead}>
            <span className={styles.author}>
              <Avatar name={name} src={post.author.avatarUrl} size={32} />
              <span className={styles.authorName} dir="auto">
                {name}
              </span>
              <span className={`${styles.muted} ltr`}>{post.author.email}</span>
            </span>
            <StatusBadges post={post} />
          </div>
          <p className={styles.text} dir="auto" data-testid="post-detail-text">
            {post.text ?? t('admin.posts.noText')}
          </p>
          {post.media.length > 0 && (
            <div className={styles.thumbs} aria-label={t('admin.posts.media')}>
              {post.media.map((m, i) => (
                <PostMediaThumb key={m.id} media={m} large onOpen={() => setLb(i)} />
              ))}
            </div>
          )}
          <div className={styles.meta}>
            <span>{t('admin.posts.likes', { n: post.likeCount })}</span>
            <span>{t('admin.posts.comments', { n: post.commentCount })}</span>
            <span>
              {t('admin.posts.detail.created')}: {formatDateTime(post.createdAt)}
            </span>
            {post.hiddenAt && (
              <span>
                {t('admin.posts.detail.hiddenAt')}: {formatDateTime(post.hiddenAt)}
              </span>
            )}
            {post.deletedAt && (
              <span>
                {t('admin.posts.detail.deletedAt')}: {formatDateTime(post.deletedAt)}
              </span>
            )}
          </div>
          {post.hiddenReason && <p className={styles.reason}>{t('admin.posts.reasonShown', { reason: post.hiddenReason })}</p>}
          <PostActionButtons post={post} actions={actions} />
          <h3>{t('admin.posts.comments.title')}</h3>
          <CommentList postId={postId} />
        </div>
      )}
      {actions.dialogs}
      {lb !== null && <Lightbox items={items} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </Drawer>
  );
}
