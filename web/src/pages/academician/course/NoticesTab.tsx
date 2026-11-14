// SEKME: Duyurular. Yedi sabit türden biri (serbest metin yok): her türde YALNIZ izin verilen alanlar gösterilir
// (noticeRules.ts). EXAM/ASSIGNMENT/MATERIAL dosya taşıyabilir (NoticeFiles). Liste: ekler + indirme + silme.
// API: POST/GET /academician/courses/{id}/notices, DELETE /academician/notices/{id}, dosya: notice-files (bkz. NoticeFiles.tsx),
// indirme: GET /academician/notices/{noticeId}/files/{fileId}.
import { useState } from 'react';
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  NOTICE_TYPES,
  acadKeys,
  createNotice,
  deleteNotice,
  downloadNoticeFile,
  listNotices,
  type Course,
  type Notice,
  type NoticeFile,
  type NoticeType,
} from '../../../api/academician';
import { Badge, Button, Card, ConfirmDialog, FormField, Icon, Input, LoadMore, Select, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { downloadBlob } from '../../admin/users/filters';
import { EmptyBlock, LoadingBlock, QueryError } from '../components/common';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtDateTime, fmtSize, localInputToIso } from '../format';
import styles from '../academician.module.css';
import { useUnsavedGuard } from '../components/unsavedGuard';
import { NOTICE_SPECS, validateNotice } from './noticeRules';
import { NoticeFilesField, useNoticeFiles } from './NoticeFiles';

export function NoticesTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const [type, setType] = useState<NoticeType>('LESSON_STARTED');
  const [title, setTitle] = useState('');
  const [note, setNote] = useState('');
  const [eventAt, setEventAt] = useState('');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<Notice | null>(null);
  const fileState = useNoticeFiles(course.id);
  const spec = NOTICE_SPECS[type];
  const [switchTo, setSwitchTo] = useState<NoticeType | null>(null);
  // taslak ya da süren/biten yükleme varken sayfadan ayrılma onay ister
  const dirty = !!(title.trim() || note.trim() || eventAt || fileState.files.some((f) => !f.rejected));
  useUnsavedGuard(dirty || fileState.uploading, t('ac.notices.leaveGuard'));

  const list = useInfiniteQuery({
    queryKey: acadKeys.notices(course.id),
    queryFn: ({ pageParam }) => listNotices(course.id, pageParam),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor,
  });
  const notices = list.data?.pages.flatMap((p) => p.items) ?? [];

  const send = useMutation({
    mutationFn: () =>
      createNotice(course.id, {
        type,
        title: spec.title ? title.trim() : undefined,
        note: spec.note && note.trim() ? note.trim() : undefined,
        eventAt: spec.event !== 'none' ? localInputToIso(eventAt) : undefined,
        fileIds: spec.files && fileState.serverIds.length ? fileState.serverIds : undefined,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: acadKeys.notices(course.id) });
      toast.success(t('ac.notices.sent', { n: course.enrolledCount ?? 0 }));
      setTitle('');
      setNote('');
      setEventAt('');
      setTouched(false);
      setError(null);
      fileState.clearAttached();
    },
    // hata: form girdisi ve yüklenen dosyalar korunur
    onError: (e) => setError(acadError(i18n, e)),
  });

  const remove = useMutation({
    mutationFn: (n: Notice) => deleteNotice(n.id),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: acadKeys.notices(course.id) });
      toast.success(t('ac.notices.deleted'));
      setDeleting(null);
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setDeleting(null);
    },
  });

  /** Tür değişince kaybolacak bir şey (yüklenmiş dosya, doldurulmuş alan) varsa önce onay ister. */
  function requestType(next: NoticeType) {
    const n = NOTICE_SPECS[next];
    const lost =
      (!n.files && fileState.files.some((f) => !f.rejected)) ||
      (!n.title && !!title.trim()) ||
      (!n.note && !!note.trim()) ||
      (n.event === 'none' && !!eventAt);
    if (lost) setSwitchTo(next);
    else changeType(next);
  }
  function changeType(next: NoticeType) {
    setType(next);
    setTouched(false);
    setError(null);
    if (!NOTICE_SPECS[next].files) fileState.discardAll();
    if (!NOTICE_SPECS[next].title) setTitle('');
    if (!NOTICE_SPECS[next].note) setNote('');
    if (NOTICE_SPECS[next].event === 'none') setEventAt('');
  }

  const bad = new Set(validateNotice(type, { title, note, eventAt }));
  const req = t('ac.field.required');

  function submit() {
    if (send.isPending) return;
    setTouched(true);
    setError(null);
    if (bad.size > 0) return;
    if (fileState.uploading) {
      setError(t('ac.notices.waitUploads'));
      return;
    }
    if (spec.files && fileState.failed) {
      setError(t('ac.notices.fixFiles'));
      return;
    }
    send.mutate();
  }

  const titleLabel = type === 'ROOM_CHANGED' ? t('ac.notices.field.room') : t('ac.notices.field.title');
  const eventLabel = t(`ac.notices.event.${type}`);

  return (
    <div className={styles.formStack}>
      <Card title={t('ac.notices.newTitle')}>
        <form
          className={styles.formStack}
          noValidate
          aria-busy={send.isPending || undefined}
          onSubmit={(e) => {
            e.preventDefault();
            submit();
          }}
        >
          <p className={styles.muted}>{t('ac.notices.intro', { n: course.enrolledCount ?? 0 })}</p>
          {error && (
            <div className={styles.alertBox} role="alert">
              <Icon name="alert" size={18} />
              <span>{error}</span>
            </div>
          )}
          <FormField label={t('ac.notices.field.type')} hint={t(`ac.notices.typeHint.${type}`)}>
            <Select value={type} onChange={(e) => requestType(e.target.value as NoticeType)}>
              {NOTICE_TYPES.map((k) => (
                <option key={k} value={k}>
                  {t(`ac.notice.type.${k}`)}
                </option>
              ))}
            </Select>
          </FormField>
          {spec.title && (
            <FormField label={titleLabel} error={touched && bad.has('title') ? req : null} required>
              <Input value={title} maxLength={spec.title.max} onChange={(e) => setTitle(e.target.value)} />
            </FormField>
          )}
          {spec.event !== 'none' && (
            <FormField label={eventLabel} error={touched && bad.has('eventAt') ? req : null} required={spec.event === 'required'}>
              <Input type="datetime-local" value={eventAt} onChange={(e) => setEventAt(e.target.value)} />
            </FormField>
          )}
          {spec.note && (
            <FormField label={t('ac.notices.field.note')} hint={t('ac.notices.noteCount', { n: note.length, max: spec.note.max })} error={touched && bad.has('note') ? t('ac.notices.noteTooLong', { max: spec.note.max }) : null}>
              <Textarea rows={3} value={note} onChange={(e) => setNote(e.target.value)} />
            </FormField>
          )}
          {!spec.title && !spec.note && spec.event === 'none' && <p className={styles.muted}>{t('ac.notices.noFields')}</p>}
          {spec.files && <NoticeFilesField state={fileState} disabled={send.isPending} />}
          {spec.files && fileState.rejected > 0 && (
            <p className={styles.muted} role="status">
              {t('ac.notices.rejectedNote', { n: fileState.rejected })}{' '}
              <Button type="button" size="sm" variant="ghost" onClick={fileState.dropRejected}>
                {t('ac.notices.dropRejected')}
              </Button>
            </p>
          )}
          <div className={styles.actionsRow}>
            <Button type="submit" loading={send.isPending} leftIcon={<Icon name="megaphone" size={16} />}>
              {t('ac.notices.send')}
            </Button>
          </div>
        </form>
      </Card>

      <Card title={t('ac.notices.listTitle')}>
        {list.isLoading ? (
          <LoadingBlock rows={3} height="4rem" />
        ) : list.isError ? (
          <QueryError subject={t('ac.notices.subject')} error={list.error} onRetry={() => void list.refetch()} />
        ) : notices.length === 0 ? (
          <EmptyBlock icon="megaphone" title={t('ac.notices.empty.title')} description={t('ac.notices.empty.text')} />
        ) : (
          <>
            <ul className={styles.rows}>
              {notices.map((n) => (
                <NoticeItem key={n.id} n={n} onDelete={() => setDeleting(n)} />
              ))}
            </ul>
            <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
          </>
        )}
      </Card>

      <ConfirmDialog
        open={!!switchTo}
        onClose={() => setSwitchTo(null)}
        onConfirm={() => {
          if (switchTo) changeType(switchTo);
          setSwitchTo(null);
        }}
        title={t('ac.notices.switchTitle')}
        message={t('ac.notices.switchText')}
        consequence={t('ac.notices.switchConsequence')}
        confirmLabel={t('ac.notices.switchConfirm')}
        initialFocus="cancel"
      />
      <ConfirmDialog
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={() => deleting && remove.mutate(deleting)}
        loading={remove.isPending}
        danger
        role="alertdialog"
        title={t('ac.notices.deleteTitle')}
        message={deleting ? `${t(`ac.notice.type.${deleting.type}`)}${deleting.title ? ` · ${deleting.title}` : ''}` : undefined}
        consequence={t('ac.notices.deleteConsequence')}
        confirmLabel={t('ac.delete')}
        initialFocus="cancel"
      />
    </div>
  );
}

function NoticeItem({ n, onDelete }: { n: Notice; onDelete: () => void }) {
  const t = useT();
  return (
    <li className={`${styles.row} ${styles.noticeRow}`}>
      <div className={styles.rowMain}>
        <span className={styles.chips}>
          <Badge>{t(`ac.notice.type.${n.type}`)}</Badge>
          {n.title && <span className={styles.rowTitle}>{n.title}</span>}
        </span>
        {n.eventAt && (
          <span className={styles.muted}>
            {t(`ac.notices.event.${n.type}`)}: {fmtDateTime(n.eventAt)}
          </span>
        )}
        {n.note && <p className={styles.noteText}>{n.note}</p>}
        {n.files.length > 0 && (
          <ul className={styles.attachList} aria-label={t('ac.notices.attachments')}>
            {n.files.map((f) => (
              <li key={f.id}>
                <FileDownload noticeId={n.id} file={f} />
              </li>
            ))}
          </ul>
        )}
        <span className={styles.muted}>{t('ac.notices.sentAt', { at: fmtDateTime(n.createdAt) })}</span>
      </div>
      <Button size="sm" variant="dangerOutline" onClick={onDelete} aria-label={t('ac.notices.deleteAria', { name: n.title ?? t(`ac.notice.type.${n.type}`) })}>
        {t('ac.delete')}
      </Button>
    </li>
  );
}

/** Ek indirme: Authorization başlığı gerektiğinden `apiBlob` ile alınır, tarayıcıda dosya olarak kaydedilir. */
function FileDownload({ noticeId, file }: { noticeId: number; file: NoticeFile }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  async function go() {
    setBusy(true);
    try {
      downloadBlob(await downloadNoticeFile(noticeId, file.id), file.name);
    } catch (e) {
      toast.error(acadError(i18n, e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Button size="sm" variant="secondary" loading={busy} leftIcon={<Icon name="download" size={14} />} onClick={() => void go()} aria-label={t('ac.notices.downloadAria', { name: file.name })}>
      {file.name} <span className={styles.muted}>({fmtSize(file.sizeBytes)})</span>
    </Button>
  );
}
