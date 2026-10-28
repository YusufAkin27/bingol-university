// Gönderi ayrıntı paneli: tam metin, medya (Lightbox), bu gönderiye yapılan şikâyetler ve moderasyon eylemleri.
// API: GET /api/admin/posts/{id} (gönderi + şikâyetler); eylemler PostParts içinde (düzenle / gizle / sil).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { adminPostsApi, qk } from '../../../api';
import { AuditTrail } from '../../../components/admin/guard';
import { Avatar, Badge, Drawer, ErrorState, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { Lightbox } from '../chat/Lightbox';
import { PostActionButtons, PostMediaThumb, StatusBadges, usePostActions } from './PostParts';
import { mediaToLightbox } from './postsLogic';
import styles from './posts.module.css';

export function PostDetailDrawer({ postId, onClose }: { postId: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({ queryKey: qk.adminPosts.detail(postId), queryFn: () => adminPostsApi.getPost(postId) });
  const actions = usePostActions(() => onClose());
  const [lb, setLb] = useState<number | null>(null);
  const post = q.data?.post;
  const reports = q.data?.reports ?? [];
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
            <span>
              {t('admin.posts.detail.created')}: {formatDateTime(post.createdAt)}
            </span>
            {post.editedAt && (
              <span>
                {t('admin.posts.detail.editedAt')}: {formatDateTime(post.editedAt)}
              </span>
            )}
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
          <h3>{t('admin.posts.reports.title')}</h3>
          {reports.length === 0 ? (
            <p className={styles.note}>{t('admin.posts.reports.empty')}</p>
          ) : (
            <ul className={styles.comments} data-testid="post-reports">
              {reports.map((r) => (
                <li key={r.id} className={styles.comment}>
                  <div className={styles.rowHead}>
                    <Badge tone={r.status === 'OPEN' ? 'danger' : 'neutral'}>
                      {r.status === 'OPEN' ? t('admin.posts.reports.open') : t('admin.posts.reports.resolved')}
                    </Badge>
                    <span>{r.reason}</span>
                    <time className={styles.muted} dateTime={r.createdAt}>
                      {formatDateTime(r.createdAt)}
                    </time>
                  </div>
                  {r.note && (
                    <p className={styles.text} dir="auto">
                      {r.note}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      <AuditTrail targetType="POST" targetId={postId} />
      {actions.dialogs}
      {lb !== null && <Lightbox items={items} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </Drawer>
  );
}
