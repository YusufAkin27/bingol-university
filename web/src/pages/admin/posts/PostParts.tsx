// Gönderi yönetimi parçaları: medya küçük resmi, durum rozetleri, gizle/sil diyalogları ve eylem düğmeleri.
// API: POST /api/admin/posts/{id}/hide|unhide, PATCH /api/admin/posts/{id} (metin düzenle), DELETE /api/admin/posts/{id} {reason}
// (api/adminPosts.ts). Medya Bearer ile blob olarak alınır. Tüm yazma işlemleri sunucuda denetim kaydına yazılır.
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminPostsApi } from '../../../api';
import type { AdminPostMedia, AdminPostRow } from '../../../api/adminPosts';
import { Badge, Button, FormField, Input, Modal, useToast } from '../../../components/ui';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { ADMIN_REASON_MIN } from '../../../components/admin/guard/match';
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
  const [unhideFor, setUnhideFor] = useState<AdminPostRow | null>(null);
  const [deleteFor, setDeleteFor] = useState<AdminPostRow | null>(null);
  const [editFor, setEditFor] = useState<AdminPostRow | null>(null);
  const [text, setText] = useState('');
  const textError = postTextError(text);
  const refresh = () => void qc.invalidateQueries({ queryKey: ['adminPosts'] });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));
  // Gizle / geri aç / sil: W1-B (T-013) gereği gerekçe (>= 5 karakter) zorunlu; GuardedDialog sebebi `X-Admin-Reason` ile yollar.
  const keys = [['adminPosts']];

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
      <GuardedDialog
        open={hideFor !== null}
        onClose={() => setHideFor(null)}
        title={t('admin.posts.hide.title')}
        message={t('admin.posts.hide.hint')}
        irreversible={false}
        confirmLabel={t('admin.posts.hide.confirm')}
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        reasonLabel={t('admin.posts.hide.reason')}
        successMessage={t('admin.posts.hide.done')}
        invalidateKeys={keys}
        onConfirm={({ reason, idempotencyKey }) => adminPostsApi.hidePost(hideFor!.id, reason, { idempotencyKey })}
      />
      <GuardedDialog
        open={unhideFor !== null}
        onClose={() => setUnhideFor(null)}
        title={t('admin.wp02.posts.unhide.title')}
        message={t('admin.wp02.posts.unhide.hint')}
        irreversible={false}
        confirmLabel={t('admin.wp02.posts.unhide.confirm')}
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        reasonLabel={t('admin.posts.hide.reason')}
        successMessage={t('admin.posts.unhide.done')}
        invalidateKeys={keys}
        onConfirm={({ reason, idempotencyKey }) => adminPostsApi.unhidePost(unhideFor!.id, reason, { idempotencyKey })}
      />
      <GuardedDialog
        open={deleteFor !== null}
        onClose={() => setDeleteFor(null)}
        title={t('admin.posts.delete.title')}
        message={t('admin.posts.delete.message')}
        extra={
          (deleteFor?.openReportCount ?? 0) > 0 ? (
            <p className={styles.reason}>{t('admin.posts.delete.reportsNote', { n: deleteFor?.openReportCount ?? 0 })}</p>
          ) : null
        }
        danger
        confirmLabel={t('admin.posts.delete.confirm')}
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        reasonLabel={t('admin.posts.delete.reason')}
        successMessage={t('admin.posts.delete.done')}
        invalidateKeys={keys}
        onSuccess={() => onDeleted?.(deleteFor!.id)}
        onConfirm={({ reason, idempotencyKey }) => adminPostsApi.deletePost(deleteFor!.id, reason, { idempotencyKey })}
      />
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
    askHide: (p: AdminPostRow) => setHideFor(p),
    askDelete: (p: AdminPostRow) => setDeleteFor(p),
    askEdit: (p: AdminPostRow) => {
      setText(p.text ?? '');
      setEditFor(p);
    },
    // Geri açmak da gerekçe ister (W1-B T-013): düğme diyaloğu açar.
    unhide: (p: AdminPostRow) => setUnhideFor(p),
    busy: false,
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
