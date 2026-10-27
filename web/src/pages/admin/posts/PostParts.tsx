// Gönderi yönetimi parçaları: medya küçük resmi, durum rozetleri, gizle/sil diyalogları ve eylem düğmeleri.
// API: POST /api/admin/posts/{id}/hide|unhide, DELETE /api/admin/posts/{id} (api/adminPosts.ts). Medya Bearer ile blob olarak alınır.
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminPostsApi } from '../../../api';
import type { AdminPostMedia, AdminPostRow } from '../../../api/adminPosts';
import { Badge, Button, ConfirmDialog, FormField, Modal, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { formatDuration } from '../chat/chatLogic';
import { useBlobUrl } from '../chat/useBlobUrl';
import styles from './posts.module.css';

export function PostMediaThumb({ media, onOpen, large }: { media: AdminPostMedia; onOpen: () => void; large?: boolean }) {
  const { t } = useI18n();
  const { src, failed } = useBlobUrl(media.thumbUrl);
  const label = media.kind === 'VIDEO' ? t('admin.posts.video') : t('admin.posts.image');
  return (
    <button
      type="button"
      className={`${styles.thumbBtn} ${large ? styles.large : ''}`}
      onClick={onOpen}
      aria-label={`${t('admin.posts.mediaOpen')}: ${label}`}
      data-testid="post-media-thumb"
    >
      {src && !failed ? (
        <img src={src} alt={label} className={styles.thumbImg} loading="lazy" />
      ) : (
        <span className={styles.thumbPlaceholder}>{failed ? t('admin.posts.mediaFailed') : label}</span>
      )}
      {media.kind === 'VIDEO' && (
        <span className={styles.play}>▶{media.durationMs != null ? ` ${formatDuration(media.durationMs)}` : ''}</span>
      )}
    </button>
  );
}

export function StatusBadges({ post }: { post: Pick<AdminPostRow, 'hidden' | 'deleted' | 'editedAt'> }) {
  const { t } = useI18n();
  return (
    <>
      {post.deleted && <Badge tone="danger">{t('admin.posts.badge.deleted')}</Badge>}
      {post.hidden && <Badge tone="warning">{t('admin.posts.badge.hidden')}</Badge>}
      {post.editedAt && <Badge tone="neutral">{t('admin.posts.badge.edited')}</Badge>}
    </>
  );
}

/** Gizle (gerekçe diyaloğu) / geri aç / sil (onaylı) eylemlerini ve tepkilerini yönetir. */
export function usePostActions(onDeleted?: (id: number) => void) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [hideFor, setHideFor] = useState<AdminPostRow | null>(null);
  const [deleteFor, setDeleteFor] = useState<AdminPostRow | null>(null);
  const [reason, setReason] = useState('');
  const refresh = () => void qc.invalidateQueries({ queryKey: ['adminPosts'] });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const hide = useMutation({
    mutationFn: (p: { id: number; reason: string }) => adminPostsApi.hidePost(p.id, p.reason),
    onSuccess: () => {
      toast.success(t('admin.posts.hide.done'));
      setHideFor(null);
      setReason('');
      refresh();
    },
    onError,
  });
  const unhide = useMutation({
    mutationFn: (id: number) => adminPostsApi.unhidePost(id),
    onSuccess: () => {
      toast.success(t('admin.posts.unhide.done'));
      refresh();
    },
    onError,
  });
  const del = useMutation({
    mutationFn: (id: number) => adminPostsApi.deletePost(id),
    onSuccess: (_d, id) => {
      toast.success(t('admin.posts.delete.done'));
      setDeleteFor(null);
      onDeleted?.(id);
      refresh();
    },
    onError,
  });

  const dialogs = (
    <>
      <Modal
        open={hideFor !== null}
        onClose={() => setHideFor(null)}
        title={t('admin.posts.hide.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setHideFor(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              loading={hide.isPending}
              onClick={() => hideFor && hide.mutate({ id: hideFor.id, reason })}
              data-testid="hide-confirm"
            >
              {t('admin.posts.hide.confirm')}
            </Button>
          </>
        }
      >
        <p>{t('admin.posts.hide.hint')}</p>
        <FormField label={t('admin.posts.hide.reason')}>
          <Textarea value={reason} maxLength={300} rows={3} onChange={(e) => setReason(e.target.value)} data-autofocus />
        </FormField>
      </Modal>
      <ConfirmDialog
        open={deleteFor !== null}
        onClose={() => setDeleteFor(null)}
        onConfirm={() => deleteFor && del.mutate(deleteFor.id)}
        title={t('admin.posts.delete.title')}
        message={t('admin.posts.delete.message')}
        confirmLabel={t('admin.posts.delete.confirm')}
        danger
        loading={del.isPending}
      />
    </>
  );

  return {
    dialogs,
    askHide: (p: AdminPostRow) => {
      setReason('');
      setHideFor(p);
    },
    askDelete: (p: AdminPostRow) => setDeleteFor(p),
    unhide: (p: AdminPostRow) => unhide.mutate(p.id),
    busy: unhide.isPending,
  };
}

export function PostActionButtons({
  post,
  actions,
}: {
  post: AdminPostRow;
  actions: Pick<ReturnType<typeof usePostActions>, 'askHide' | 'askDelete' | 'unhide' | 'busy'>;
}) {
  const { t } = useI18n();
  if (post.deleted) return null;
  return (
    <div className={styles.actions}>
      {post.hidden ? (
        <Button size="sm" variant="secondary" loading={actions.busy} onClick={() => actions.unhide(post)}>
          {t('admin.posts.action.unhide')}
        </Button>
      ) : (
        <Button size="sm" variant="secondary" onClick={() => actions.askHide(post)}>
          {t('admin.posts.action.hide')}
        </Button>
      )}
      <Button size="sm" variant="danger" onClick={() => actions.askDelete(post)}>
        {t('admin.posts.action.delete')}
      </Button>
    </div>
  );
}
