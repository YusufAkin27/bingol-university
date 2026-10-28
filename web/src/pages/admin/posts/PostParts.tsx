// Gönderi yönetimi parçaları: medya küçük resmi, durum rozetleri, gizle/sil diyalogları ve eylem düğmeleri.
// API: POST /api/admin/posts/{id}/hide|unhide, PATCH /api/admin/posts/{id} (metin düzenle), DELETE /api/admin/posts/{id} {reason}
// (api/adminPosts.ts). Medya Bearer ile blob olarak alınır. Tüm yazma işlemleri sunucuda denetim kaydına yazılır.
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminPostsApi } from '../../../api';
import type { AdminPostMedia, AdminPostRow } from '../../../api/adminPosts';
import { Badge, Button, FormField, Input, Modal, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { formatDuration } from '../chat/chatLogic';
import { useBlobUrl } from '../chat/useBlobUrl';
import { POST_MAX_CHARS, postTextError } from './postsLogic';
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

export function StatusBadges({ post }: { post: Pick<AdminPostRow, 'hidden' | 'deleted' | 'editedAt'> & { openReportCount?: number } }) {
  const { t } = useI18n();
  return (
    <>
      {(post.openReportCount ?? 0) > 0 && (
        <Badge tone="danger">{t('admin.posts.badge.reports', { n: post.openReportCount ?? 0 })}</Badge>
      )}
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
  const [editFor, setEditFor] = useState<AdminPostRow | null>(null);
  const [reason, setReason] = useState('');
  const [deleteReason, setDeleteReason] = useState('');
  const [text, setText] = useState('');
  const textError = postTextError(text);
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
    mutationFn: (p: { id: number; reason: string }) => adminPostsApi.deletePost(p.id, p.reason),
    onSuccess: (_d, p) => {
      toast.success(t('admin.posts.delete.done'));
      setDeleteFor(null);
      setDeleteReason('');
      onDeleted?.(p.id);
      refresh();
    },
    onError,
  });
  const edit = useMutation({
    mutationFn: (p: { id: number; text: string }) => adminPostsApi.editPost(p.id, p.text),
    onSuccess: () => {
      toast.success(t('admin.posts.edit.done'));
      setEditFor(null);
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
      <Modal
        open={deleteFor !== null}
        onClose={() => setDeleteFor(null)}
        title={t('admin.posts.delete.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleteFor(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="danger"
              loading={del.isPending}
              onClick={() => deleteFor && del.mutate({ id: deleteFor.id, reason: deleteReason })}
              data-testid="delete-confirm"
            >
              {t('admin.posts.delete.confirm')}
            </Button>
          </>
        }
      >
        <p>{t('admin.posts.delete.message')}</p>
        {(deleteFor?.openReportCount ?? 0) > 0 && (
          <p className={styles.reason}>{t('admin.posts.delete.reportsNote', { n: deleteFor?.openReportCount ?? 0 })}</p>
        )}
        <FormField label={t('admin.posts.delete.reason')} hint={t('admin.posts.delete.reasonHint')}>
          <Textarea value={deleteReason} maxLength={300} rows={3} onChange={(e) => setDeleteReason(e.target.value)} data-autofocus />
        </FormField>
      </Modal>
      <Modal
        open={editFor !== null}
        onClose={() => setEditFor(null)}
        title={t('admin.posts.edit.title')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditFor(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              loading={edit.isPending}
              disabled={textError !== null}
              onClick={() => editFor && edit.mutate({ id: editFor.id, text })}
              data-testid="edit-confirm"
            >
              {t('admin.posts.edit.confirm')}
            </Button>
          </>
        }
      >
        <p>{t('admin.posts.edit.hint')}</p>
        <FormField
          label={t('admin.posts.edit.text')}
          error={textError ? t(textError === 'newline' ? 'admin.posts.edit.errNewline' : 'admin.posts.edit.errTooLong') : undefined}
        >
          <Input value={text} maxLength={POST_MAX_CHARS + 20} dir="auto" onChange={(e) => setText(e.target.value)} data-autofocus />
        </FormField>
      </Modal>
    </>
  );

  return {
    dialogs,
    askHide: (p: AdminPostRow) => {
      setReason('');
      setHideFor(p);
    },
    askDelete: (p: AdminPostRow) => {
      setDeleteReason('');
      setDeleteFor(p);
    },
    askEdit: (p: AdminPostRow) => {
      setText(p.text ?? '');
      setEditFor(p);
    },
    unhide: (p: AdminPostRow) => unhide.mutate(p.id),
    busy: unhide.isPending,
  };
}

export function PostActionButtons({
  post,
  actions,
}: {
  post: AdminPostRow;
  actions: Pick<ReturnType<typeof usePostActions>, 'askHide' | 'askDelete' | 'askEdit' | 'unhide' | 'busy'>;
}) {
  const { t } = useI18n();
  if (post.deleted) return null;
  return (
    <div className={styles.actions}>
      <Button size="sm" variant="secondary" onClick={() => actions.askEdit(post)}>
        {t('admin.posts.action.edit')}
      </Button>
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
