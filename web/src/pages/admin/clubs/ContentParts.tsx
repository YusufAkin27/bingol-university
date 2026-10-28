// Kulüp gönderisi + duyurusu moderasyon parçaları: satır, eylem diyalogları (gizle / geri al / düzenle / sil).
// Yıkıcı eylem (sil) GuardedDialog: sebep zorunlu + geri alınamaz uyarısı; gizleme geri alınabilir (sebep isteğe bağlı).
import { useQuery } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import {
  deleteContent,
  editContent,
  getContent,
  hideContent,
  unhideContent,
  type ContentRow,
} from '../../../api/adminCommunities';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { useGuardedMutation } from '../../../components/admin/guard/useGuardedMutation';
import { Avatar, Badge, Button, ErrorState, FormField, Modal, Spinner, StatusPill, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { canEditContent, excerpt } from './clubsLogic';
import styles from './clubs.module.css';

export const CONTENT_KEYS = [['communities']] as const;
const TEXT_MAX = 2000;

type Action = 'hide' | 'unhide' | 'edit' | 'delete';
interface Pending {
  action: Action;
  row: ContentRow;
}

/** Eylem diyaloglarını yöneten kanca: `request(action,row)` ile açılır, `dialogs` sayfaya konur. */
export function useContentActions() {
  const { t } = useI18n();
  const [pending, setPending] = useState<Pending | null>(null);
  const close = () => setPending(null);
  const keys = CONTENT_KEYS.map((k) => [...k]);
  const row = pending?.row ?? null;
  const what = row ? t(row.kind === 'ANNOUNCEMENT' ? 'admin.p06.content.kind.ANNOUNCEMENT' : 'admin.p06.content.kind.POST') : '';

  const dialogs: ReactNode = (
    <>
      <GuardedDialog
        open={pending?.action === 'hide'}
        onClose={close}
        title={t('admin.p06.content.hide.title', { what })}
        message={t('admin.p06.content.hide.message')}
        consequence={t('admin.p06.content.hide.consequence')}
        irreversible={false}
        confirmLabel={t('admin.p06.content.hide')}
        optionalReason
        reasonLabel={t('admin.p06.content.hide.reason')}
        successMessage={t('admin.p06.content.hide.done')}
        invalidateKeys={keys}
        onConfirm={({ reason, idempotencyKey }) => hideContent(row!.id, { reason, idempotencyKey })}
      />
      <GuardedDialog
        open={pending?.action === 'unhide'}
        onClose={close}
        title={t('admin.p06.content.unhide.title', { what })}
        message={t('admin.p06.content.unhide.message')}
        irreversible={false}
        confirmLabel={t('admin.p06.content.unhide')}
        successMessage={t('admin.p06.content.unhide.done')}
        invalidateKeys={keys}
        onConfirm={({ reason, idempotencyKey }) => unhideContent(row!.id, { reason, idempotencyKey })}
      />
      <GuardedDialog
        open={pending?.action === 'delete'}
        onClose={close}
        title={t('admin.p06.content.delete.title', { what })}
        message={t('admin.p06.content.delete.message')}
        consequence={t('admin.p06.content.delete.consequence')}
        irreversible
        danger
        confirmLabel={t('admin.p06.content.delete')}
        requireReason
        reasonLabel={t('admin.p06.content.delete.reason')}
        successMessage={t('admin.p06.content.delete.done')}
        invalidateKeys={keys}
        onConfirm={({ reason, idempotencyKey }) => deleteContent(row!.id, { reason, idempotencyKey })}
      />
      {pending?.action === 'edit' && <EditContentDialog row={pending.row} onClose={close} />}
    </>
  );

  return { request: (action: Action, r: ContentRow) => setPending({ action, row: r }), dialogs };
}

/** Metin düzenleme: küfür süzgeci yönetici için atlanır; yazara bildirim gider. */
function EditContentDialog({ row, onClose }: { row: ContentRow; onClose: () => void }) {
  const { t } = useI18n();
  const [text, setText] = useState(row.text);
  const g = useGuardedMutation({
    mutationFn: (v: string, ctx) => editContent(row.id, v, { idempotencyKey: ctx.idempotencyKey }),
    successMessage: t('admin.p06.content.edit.done'),
    invalidateKeys: CONTENT_KEYS.map((k) => [...k]),
  });
  const clean = text.trim();
  const invalid = clean.length === 0 || clean.length > TEXT_MAX;
  const unchanged = clean === row.text.trim();
  async function save() {
    if (invalid || unchanged) return;
    const res = await g.run(clean);
    if (res.ok) onClose();
  }
  return (
    <Modal
      open
      onClose={() => {
        if (!g.isPending) onClose();
      }}
      title={t('admin.p06.content.edit.title')}
      size="md"
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={g.isPending}>
            {t('common.cancel')}
          </Button>
          <Button loading={g.isPending} disabled={invalid || unchanged} onClick={() => void save()}>
            {t('admin.p06.content.edit.save')}
          </Button>
        </>
      }
    >
      <FormField
        label={t('admin.p06.content.edit.label')}
        hint={t('admin.p06.content.edit.hint')}
        error={clean.length > TEXT_MAX ? t('admin.p06.content.edit.tooLong', { max: TEXT_MAX }) : undefined}
      >
        <Textarea rows={6} value={text} maxLength={TEXT_MAX + 100} onChange={(e) => setText(e.target.value)} data-autofocus />
      </FormField>
    </Modal>
  );
}

/** Tek içerik satırı. `showClub` = birleşik listede kulüp adı + kulübü aç düğmesi. */
export function ContentRowItem({
  row,
  actions,
  showClub,
  onOpenClub,
}: {
  row: ContentRow;
  actions: ReturnType<typeof useContentActions>;
  showClub?: boolean;
  onOpenClub?: (communityId: number) => void;
}) {
  const { t, formatDateTime } = useI18n();
  const [expanded, setExpanded] = useState(false);
  const name = row.author.displayName ?? `#${row.author.id}`;
  return (
    <li className={styles.row} data-testid="content-row">
      <div className={styles.rowHead}>
        <span className={styles.person}>
          <Avatar name={name} src={row.author.avatarUrl} size={32} />
          <span className={styles.personName} dir="auto">
            {name}
          </span>
          <span className={`${styles.muted} ltr`}>{row.author.email}</span>
        </span>
        <span className={styles.badges}>
          <Badge tone={row.kind === 'ANNOUNCEMENT' ? 'info' : 'neutral'}>{t(`admin.p06.content.kind.${row.kind}`)}</Badge>
          <StatusPill tone={row.state === 'VISIBLE' ? 'success' : row.state === 'HIDDEN' ? 'warning' : 'danger'}>
            {t(`admin.p06.content.state.${row.state}`)}
          </StatusPill>
          {row.openReportCount > 0 && (
            <Badge tone="danger">{t('admin.p06.content.reports', { n: row.openReportCount })}</Badge>
          )}
          {row.pinned && <Badge tone="primary">{t('admin.p06.content.pinned')}</Badge>}
        </span>
        <span className={styles.spacer} />
        <time className={styles.muted} dateTime={row.createdAt}>
          {formatDateTime(row.createdAt)}
        </time>
      </div>
      {showClub && (
        <div className={styles.muted}>
          {t('admin.p06.content.club')}:{' '}
          {onOpenClub ? (
            <Button size="sm" variant="ghost" onClick={() => onOpenClub(row.communityId)}>
              {row.communityName}
            </Button>
          ) : (
            row.communityName
          )}
        </div>
      )}
      <p className={styles.text} dir="auto">
        {excerpt(row.text, 600)}
      </p>
      {row.imageUrl && <p className={styles.muted}>{t('admin.p06.content.hasImage')}</p>}
      {row.state === 'HIDDEN' && row.hiddenReason && (
        <p className={styles.reason}>{t('admin.p06.content.hiddenReason', { reason: row.hiddenReason })}</p>
      )}
      {row.editedAt && <p className={styles.reason}>{t('admin.p06.content.edited', { at: formatDateTime(row.editedAt) })}</p>}
      <div className={styles.actions}>
        <Button size="sm" variant="ghost" aria-expanded={expanded} onClick={() => setExpanded((v) => !v)}>
          {t(expanded ? 'admin.p06.content.hideDetail' : 'admin.p06.content.detail')}
        </Button>
        <span className={styles.spacer} />
        {canEditContent(row) && (
          <>
            <Button size="sm" variant="secondary" onClick={() => actions.request('edit', row)}>
              {t('admin.p06.content.edit')}
            </Button>
            {row.state === 'HIDDEN' ? (
              <Button size="sm" variant="secondary" onClick={() => actions.request('unhide', row)}>
                {t('admin.p06.content.unhide')}
              </Button>
            ) : (
              <Button size="sm" variant="secondary" onClick={() => actions.request('hide', row)}>
                {t('admin.p06.content.hide')}
              </Button>
            )}
            <Button size="sm" variant="danger" onClick={() => actions.request('delete', row)}>
              {t('admin.p06.content.delete')}
            </Button>
          </>
        )}
      </div>
      {expanded && <ContentDetailInline id={row.id} />}
    </li>
  );
}

/** Açık/kapalı şikâyetler (gönderi ayrıntısı). */
function ContentDetailInline({ id }: { id: number }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({ queryKey: ['communities', 'admin', 'content', id], queryFn: () => getContent(id) });
  if (q.isPending) return <Spinner size="sm" />;
  if (q.isError) return <ErrorState description={adminError(i18n, q.error)} onRetry={() => void q.refetch()} />;
  const reports = q.data.reports;
  return (
    <section aria-label={t('admin.p06.content.reportsTitle')}>
      <h4 className={styles.zoneTitle}>{t('admin.p06.content.reportsTitle')}</h4>
      {reports.length === 0 ? (
        <p className={styles.muted}>{t('admin.p06.content.noReports')}</p>
      ) : (
        <ul className={styles.history}>
          {reports.map((r) => (
            <li key={r.id} className={styles.historyItem}>
              <span>
                <Badge tone={r.status === 'OPEN' ? 'warning' : 'neutral'}>{r.status}</Badge> {r.reason}
              </span>
              {r.note && <span className={styles.muted}>{r.note}</span>}
              <span className={styles.muted}>{formatDateTime(r.createdAt)}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
