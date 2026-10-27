// SAYFA: Bölüm duyuruları (/admin/academic/announcements)
// API: /api/admin/announcements (liste/POST/PATCH/DELETE, publish|unpublish, audience-count) -> api/academic.ts.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import {
  acdKeys,
  audienceCount,
  createAnnouncement,
  deleteAnnouncement,
  GRADES,
  listAnnouncements,
  setAnnouncementPublished,
  updateAnnouncement,
  type AdminAnnouncement,
  type AnnouncementInput,
  type Audience,
  type Grade,
} from '../../../api/academic';
import {
  Badge,
  Button,
  Checkbox,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Modal,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatusPill,
  Textarea,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../../lib/hooks';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './academic.module.css';
import {
  announcementState,
  emptyToNull,
  endAfterStart,
  isHttps,
  readPercent,
  toDateTimeInput,
  totalPages,
} from './logic';

const PAGE_SIZE = 20;
const FORM_ID = 'acd-ann-form';
const STATUSES = ['all', 'draft', 'scheduled', 'active', 'expired'] as const;

const audienceOf = (a: {
  department: string | null;
  faculty: string | null;
  grade: string | null;
}): Audience => ({
  department: a.department ?? undefined,
  faculty: a.faculty ?? undefined,
  grade: a.grade ?? undefined,
});

export default function AcademicAnnouncementsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.acd.an.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [status, setStatus] = useState<(typeof STATUSES)[number]>('all');
  const [qText, setQText] = useState('');
  const q = useDebouncedValue(qText, 300);
  const [page, setPage] = useState(0);
  const [editing, setEditing] = useState<AdminAnnouncement | 'new' | null>(null);
  const [removing, setRemoving] = useState<AdminAnnouncement | null>(null);

  const params = { page, size: PAGE_SIZE, status, q };
  const list = useQuery({
    queryKey: acdKeys.announcements(params),
    queryFn: () => listAnnouncements(params),
  });

  const refresh = () => void qc.invalidateQueries({ queryKey: acdKeys.all });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const save = useMutation({
    mutationFn: (v: { id: number | null; body: AnnouncementInput }) =>
      v.id === null ? createAnnouncement(v.body) : updateAnnouncement(v.id, v.body),
    onSuccess: () => {
      toast.success(t('admin.acd.saved'));
      setEditing(null);
      refresh();
    },
    onError,
  });
  const toggle = useMutation({
    mutationFn: (a: AdminAnnouncement) => setAnnouncementPublished(a.id, !a.published),
    onSuccess: (_r, a) => {
      toast.success(t(a.published ? 'admin.acd.unpublishedToast' : 'admin.acd.publishedToast'));
      refresh();
    },
    onError,
  });
  const pin = useMutation({
    mutationFn: (a: AdminAnnouncement) => updateAnnouncement(a.id, { pinned: !a.pinned }),
    onSuccess: () => {
      toast.success(t('admin.acd.saved'));
      refresh();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: (a: AdminAnnouncement) => deleteAnnouncement(a.id),
    onSuccess: () => {
      toast.success(t('admin.acd.deleted'));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      onError(e);
      setRemoving(null);
    },
  });

  const targetText = (a: AdminAnnouncement) =>
    [a.faculty, a.department, a.grade ? t(`admin.acd.grade.${a.grade}` as const) : null]
      .filter(Boolean)
      .join(' · ') || t('admin.acd.an.targetAll');

  return (
    <>
      <PageHeader
        title={t('admin.acd.an.title')}
        description={t('admin.acd.an.intro')}
        actions={<Button onClick={() => setEditing('new')}>{t('admin.acd.an.add')}</Button>}
      />
      <div className={styles.stack}>
        <div className={styles.toolbar}>
          <FormField label={t('admin.acd.statusLabel')}>
            <Select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value as (typeof STATUSES)[number]);
                setPage(0);
              }}
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {t(`admin.acd.an.status.${s}` as const)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.search')}>
            <Input
              value={qText}
              maxLength={80}
              dir="auto"
              onChange={(e) => {
                setQText(e.target.value);
                setPage(0);
              }}
            />
          </FormField>
        </div>

        {list.isError ? (
          <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : (list.data?.items.length ?? 0) === 0 ? (
          <EmptyState
            icon="news"
            title={t('admin.acd.an.emptyTitle')}
            description={t('admin.acd.an.emptyHint')}
          />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t('admin.acd.rows')}>
              {list.data!.items.map((a) => {
                const st = announcementState(a);
                return (
                  <li key={a.id} className={styles.item}>
                    <div className={styles.itemHead}>
                      <StatusPill
                        tone={
                          st === 'active'
                            ? 'success'
                            : st === 'scheduled'
                              ? 'info'
                              : st === 'expired'
                                ? 'warning'
                                : 'neutral'
                        }
                      >
                        {t(`admin.acd.an.status.${st}` as const)}
                      </StatusPill>
                      {a.pinned && <Badge tone="primary">{t('admin.acd.an.pinnedBadge')}</Badge>}
                      <span className={styles.spacer} />
                      <div className={styles.actions}>
                        <Button size="sm" variant="secondary" onClick={() => setEditing(a)}>
                          {t('common.edit')}
                        </Button>
                        <Button
                          size="sm"
                          variant="secondary"
                          loading={pin.isPending && pin.variables?.id === a.id}
                          onClick={() => pin.mutate(a)}
                        >
                          {t(a.pinned ? 'admin.acd.an.unpin' : 'admin.acd.an.pin')}
                        </Button>
                        <Button
                          size="sm"
                          variant="secondary"
                          loading={toggle.isPending && toggle.variables?.id === a.id}
                          onClick={() => toggle.mutate(a)}
                        >
                          {t(a.published ? 'admin.acd.unpublish' : 'admin.acd.publish')}
                        </Button>
                        <Button size="sm" variant="danger" onClick={() => setRemoving(a)}>
                          {t('common.delete')}
                        </Button>
                      </div>
                    </div>
                    <h3 className={styles.itemTitle} dir="auto">
                      {a.title}
                    </h3>
                    <p className={styles.body} dir="auto">
                      {a.body.length > 240 ? `${a.body.slice(0, 240)}…` : a.body}
                    </p>
                    <p className={styles.muted} dir="auto">
                      {t('admin.acd.an.targets')}: {targetText(a)}
                      {a.publishAt
                        ? ` · ${t('admin.acd.an.publishAtLine', { when: formatDateTime(a.publishAt) })}`
                        : ''}
                      {a.expiresAt
                        ? ` · ${t('admin.acd.an.expiresAtLine', { when: formatDateTime(a.expiresAt) })}`
                        : ''}
                    </p>
                    <p className={styles.muted}>
                      <ReadStat a={a} />
                      {a.notify
                        ? ` · ${a.notifiedAt ? t('admin.acd.an.notifiedAt', { when: formatDateTime(a.notifiedAt) }) : t('admin.acd.an.notifyPending')}`
                        : ''}
                    </p>
                  </li>
                );
              })}
            </ul>
            <Pagination
              page={page}
              totalPages={totalPages(list.data!.total, PAGE_SIZE)}
              totalItems={list.data!.total}
              onPageChange={setPage}
            />
          </>
        )}
      </div>

      {editing && (
        <AnnouncementFormModal
          key={editing === 'new' ? 'new' : editing.id}
          item={editing === 'new' ? null : editing}
          saving={save.isPending}
          onClose={() => setEditing(null)}
          onSubmit={(body) => save.mutate({ id: editing === 'new' ? null : editing.id, body })}
        />
      )}
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.acd.deleteTitle')}
        message={t('admin.acd.deleteBody')}
        confirmLabel={t('common.delete')}
      />
    </>
  );
}

/** Okunma istatistiği: hedef kitle sayısı varsa yüzde de gösterilir (aynı hedefli duyurular sorguyu paylaşır). */
function ReadStat({ a }: { a: AdminAnnouncement }) {
  const { t, formatNumber } = useI18n();
  const aud = audienceOf(a);
  const total = useQuery({
    queryKey: acdKeys.audience(aud),
    queryFn: () => audienceCount(aud),
    staleTime: 60_000,
  });
  const pct = readPercent(a.readCount, total.data?.count);
  return (
    <span>
      {pct === null
        ? t('admin.acd.an.reads', { n: formatNumber(a.readCount) })
        : t('admin.acd.an.readsPct', {
            n: formatNumber(a.readCount),
            total: formatNumber(total.data!.count),
            pct,
          })}
    </span>
  );
}

function AnnouncementFormModal({
  item,
  saving,
  onClose,
  onSubmit,
}: {
  item: AdminAnnouncement | null;
  saving: boolean;
  onClose: () => void;
  onSubmit: (b: AnnouncementInput) => void;
}) {
  const { t, formatNumber } = useI18n();
  const [title, setTitle] = useState(item?.title ?? '');
  const [body, setBody] = useState(item?.body ?? '');
  const [faculty, setFaculty] = useState(item?.faculty ?? '');
  const [dept, setDept] = useState(item?.department ?? '');
  const [grade, setGrade] = useState<string>(item?.grade ?? '');
  const [pinned, setPinned] = useState(item?.pinned ?? false);
  const [publishAt, setPublishAt] = useState(toDateTimeInput(item?.publishAt));
  const [expiresAt, setExpiresAt] = useState(toDateTimeInput(item?.expiresAt));
  const [url, setUrl] = useState(item?.attachmentUrl ?? '');
  const [published, setPublished] = useState(item?.published ?? true);
  const [notify, setNotify] = useState(item?.notify ?? false);
  const [touched, setTouched] = useState(false);

  const aud = useDebouncedValue<Audience>({ faculty: faculty.trim(), department: dept.trim(), grade }, 400);
  const count = useQuery({ queryKey: acdKeys.audience(aud), queryFn: () => audienceCount(aud) });

  const titleBad = title.trim().length === 0 || title.trim().length > 150;
  const bodyBad = body.trim().length === 0;
  const urlBad = url.trim() !== '' && !isHttps(url);
  const expBad = !endAfterStart(publishAt, expiresAt);

  function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    if (titleBad || bodyBad || urlBad || expBad) return;
    onSubmit({
      title: title.trim(),
      body: body.trim(),
      faculty: emptyToNull(faculty),
      department: emptyToNull(dept),
      grade: (grade || null) as Grade | null,
      pinned,
      publishAt: publishAt || null,
      expiresAt: expiresAt || null,
      attachmentUrl: emptyToNull(url),
      published,
      notify,
    });
  }

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t(item ? 'admin.acd.an.editTitle' : 'admin.acd.an.addTitle')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" form={FORM_ID} loading={saving}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <form id={FORM_ID} className={styles.formGrid} onSubmit={submit} noValidate>
        <div className={styles.wide}>
          <FormField
            label={t('admin.acd.titleLabel')}
            required
            error={touched && titleBad ? t('admin.acd.titleReq', { max: 150 }) : null}
          >
            <Input value={title} maxLength={150} dir="auto" onChange={(e) => setTitle(e.target.value)} />
          </FormField>
        </div>
        <div className={styles.wide}>
          <FormField
            label={t('admin.acd.an.body')}
            required
            error={touched && bodyBad ? t('admin.acd.an.bodyReq') : null}
          >
            <Textarea
              value={body}
              maxLength={4000}
              rows={6}
              dir="auto"
              onChange={(e) => setBody(e.target.value)}
            />
          </FormField>
        </div>
        <FormField label={t('admin.acd.faculty')}>
          <Input value={faculty} maxLength={120} dir="auto" onChange={(e) => setFaculty(e.target.value)} />
        </FormField>
        <FormField label={t('admin.acd.dept')}>
          <Input value={dept} maxLength={120} dir="auto" onChange={(e) => setDept(e.target.value)} />
        </FormField>
        <FormField label={t('admin.acd.grade')}>
          <Select value={grade} onChange={(e) => setGrade(e.target.value)}>
            <option value="">{t('admin.acd.gradeAll')}</option>
            {GRADES.map((g) => (
              <option key={g} value={g}>
                {t(`admin.acd.grade.${g}` as const)}
              </option>
            ))}
          </Select>
        </FormField>
        <div className={styles.wide}>
          <p className={styles.preview} role="status" aria-label={t('admin.acd.an.audience')}>
            {count.isError
              ? t('admin.acd.an.audienceError')
              : count.data
                ? t('admin.acd.an.audienceLine', { count: formatNumber(count.data.count) })
                : t('admin.acd.an.audienceLoading')}
          </p>
        </div>
        <FormField label={t('admin.acd.an.publishAt')} hint={t('admin.acd.tzHint')}>
          <Input type="datetime-local" value={publishAt} onChange={(e) => setPublishAt(e.target.value)} />
        </FormField>
        <FormField
          label={t('admin.acd.an.expiresAt')}
          error={touched && expBad ? t('admin.acd.an.expiresInvalid') : null}
        >
          <Input type="datetime-local" value={expiresAt} onChange={(e) => setExpiresAt(e.target.value)} />
        </FormField>
        <div className={styles.wide}>
          <FormField
            label={t('admin.acd.an.attachment')}
            error={touched && urlBad ? t('admin.acd.an.attachmentInvalid') : null}
          >
            <Input
              type="url"
              value={url}
              maxLength={500}
              dir="ltr"
              onChange={(e) => setUrl(e.target.value)}
            />
          </FormField>
        </div>
        <div className={`${styles.wide} ${styles.checks}`}>
          <Checkbox
            label={t('admin.acd.an.publishNow')}
            checked={published}
            onChange={(e) => setPublished(e.target.checked)}
          />
          <Checkbox
            label={t('admin.acd.an.pinned')}
            checked={pinned}
            onChange={(e) => setPinned(e.target.checked)}
          />
          <Checkbox
            label={t('admin.acd.an.notify')}
            checked={notify}
            onChange={(e) => setNotify(e.target.checked)}
          />
        </div>
        {notify && (
          <p className={`${styles.muted} ${styles.wide}`}>
            {t('admin.acd.an.notifyHint')} {!published && t('admin.acd.an.notifyDraft')}
          </p>
        )}
      </form>
    </Modal>
  );
}
