// SAYFA: Resmi sınav programı (/admin/academic/exams)
// API: /api/admin/academic/exams (liste/POST/PATCH/DELETE, publish|unpublish) -> api/academic.ts.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import {
  acdKeys,
  createExam,
  deleteExam,
  EXAM_TYPES,
  GRADES,
  listExams,
  setExamPublished,
  updateExam,
  type ExamSchedule,
  type ExamScheduleInput,
  type ExamType,
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
import { emptyToNull, endAfterStart, toDateTimeInput, totalPages } from './logic';

const PAGE_SIZE = 20;
const FORM_ID = 'acd-exam-form';

export default function AcademicExamsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.acd.ex.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [type, setType] = useState('');
  const [grade, setGrade] = useState('');
  const [status, setStatus] = useState('');
  const [deptText, setDeptText] = useState('');
  const department = useDebouncedValue(deptText, 300);
  const [qText, setQText] = useState('');
  const q = useDebouncedValue(qText, 300);
  const [page, setPage] = useState(0);
  const [editing, setEditing] = useState<ExamSchedule | 'new' | null>(null);
  const [removing, setRemoving] = useState<ExamSchedule | null>(null);

  const published = status === '' ? undefined : status === 'true';
  const params = { page, size: PAGE_SIZE, q, type, grade, department, published };
  const list = useQuery({ queryKey: acdKeys.exams(params), queryFn: () => listExams(params) });

  const refresh = () => void qc.invalidateQueries({ queryKey: acdKeys.all });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const save = useMutation({
    mutationFn: (v: { id: number | null; body: ExamScheduleInput }) =>
      v.id === null ? createExam(v.body) : updateExam(v.id, v.body),
    onSuccess: () => {
      toast.success(t('admin.acd.saved'));
      setEditing(null);
      refresh();
    },
    onError,
  });
  const toggle = useMutation({
    mutationFn: (x: ExamSchedule) => setExamPublished(x.id, !x.published),
    onSuccess: (_r, x) => {
      toast.success(t(x.published ? 'admin.acd.unpublishedToast' : 'admin.acd.publishedToast'));
      refresh();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: (x: ExamSchedule) => deleteExam(x.id),
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

  // Sunucu süzgeçleri yoksayarsa diye sayfa içi güvence (aynı koşul; idempotent).
  const items = (list.data?.items ?? []).filter(
    (x) =>
      (!type || x.type === type) &&
      (!grade || x.grade === grade) &&
      (!department ||
        (x.department ?? '').toLocaleLowerCase().includes(department.trim().toLocaleLowerCase())),
  );

  return (
    <>
      <PageHeader
        title={t('admin.acd.ex.title')}
        description={t('admin.acd.ex.intro')}
        actions={<Button onClick={() => setEditing('new')}>{t('admin.acd.ex.add')}</Button>}
      />
      <div className={styles.stack}>
        <div className={styles.toolbar}>
          <FormField label={t('admin.acd.ex.type')}>
            <Select
              value={type}
              onChange={(e) => {
                setType(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.ex.typeAll')}</option>
              {EXAM_TYPES.map((x) => (
                <option key={x} value={x}>
                  {t(`admin.acd.ex.type.${x}` as const)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.grade')}>
            <Select
              value={grade}
              onChange={(e) => {
                setGrade(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.gradeAll')}</option>
              {GRADES.map((g) => (
                <option key={g} value={g}>
                  {t(`admin.acd.grade.${g}` as const)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.ex.deptFilter')}>
            <Input
              value={deptText}
              maxLength={120}
              dir="auto"
              onChange={(e) => {
                setDeptText(e.target.value);
                setPage(0);
              }}
            />
          </FormField>
          <FormField label={t('admin.acd.statusLabel')}>
            <Select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.statusAll')}</option>
              <option value="true">{t('admin.acd.published')}</option>
              <option value="false">{t('admin.acd.draft')}</option>
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
        ) : items.length === 0 ? (
          <EmptyState
            icon="list"
            title={t('admin.acd.ex.emptyTitle')}
            description={t('admin.acd.ex.emptyHint')}
          />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t('admin.acd.rows')}>
              {items.map((x) => (
                <li key={x.id} className={styles.item}>
                  <div className={styles.itemHead}>
                    <Badge tone="info">{t(`admin.acd.ex.type.${x.type}` as const)}</Badge>
                    <StatusPill tone={x.published ? 'success' : 'neutral'}>
                      {t(x.published ? 'admin.acd.published' : 'admin.acd.draft')}
                    </StatusPill>
                    <span className={styles.spacer} />
                    <div className={styles.actions}>
                      <Button size="sm" variant="secondary" onClick={() => setEditing(x)}>
                        {t('common.edit')}
                      </Button>
                      <Button
                        size="sm"
                        variant="secondary"
                        loading={toggle.isPending && toggle.variables?.id === x.id}
                        onClick={() => toggle.mutate(x)}
                      >
                        {t(x.published ? 'admin.acd.unpublish' : 'admin.acd.publish')}
                      </Button>
                      <Button size="sm" variant="danger" onClick={() => setRemoving(x)}>
                        {t('common.delete')}
                      </Button>
                    </div>
                  </div>
                  <h3 className={styles.itemTitle} dir="auto">
                    {x.courseCode ? `${x.courseCode} · ` : ''}
                    {x.title}
                  </h3>
                  <p className={styles.muted}>
                    {formatDateTime(x.startsAt)}
                    {x.endsAt ? ` – ${formatDateTime(x.endsAt)}` : ''}
                    {x.room ? ` · ${x.room}` : ''}
                  </p>
                  <p className={styles.muted} dir="auto">
                    {[
                      x.term,
                      x.faculty,
                      x.department,
                      x.grade ? t(`admin.acd.grade.${x.grade}` as const) : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                  {x.note && (
                    <p className={styles.body} dir="auto">
                      {x.note}
                    </p>
                  )}
                </li>
              ))}
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
        <ExamFormModal
          key={editing === 'new' ? 'new' : editing.id}
          exam={editing === 'new' ? null : editing}
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

function ExamFormModal({
  exam,
  saving,
  onClose,
  onSubmit,
}: {
  exam: ExamSchedule | null;
  saving: boolean;
  onClose: () => void;
  onSubmit: (b: ExamScheduleInput) => void;
}) {
  const { t } = useI18n();
  const [title, setTitle] = useState(exam?.title ?? '');
  const [type, setType] = useState<ExamType>(exam?.type ?? 'VIZE');
  const [term, setTerm] = useState(exam?.term ?? '');
  const [course, setCourse] = useState(exam?.courseCode ?? '');
  const [faculty, setFaculty] = useState(exam?.faculty ?? '');
  const [dept, setDept] = useState(exam?.department ?? '');
  const [grade, setGrade] = useState<string>(exam?.grade ?? '');
  const [start, setStart] = useState(toDateTimeInput(exam?.startsAt));
  const [end, setEnd] = useState(toDateTimeInput(exam?.endsAt));
  const [room, setRoom] = useState(exam?.room ?? '');
  const [note, setNote] = useState(exam?.note ?? '');
  const [published, setPublished] = useState(exam?.published ?? false);
  const [touched, setTouched] = useState(false);

  const titleBad = title.trim().length === 0 || title.trim().length > 150;
  const termBad = term.trim().length === 0;
  const startBad = !start;
  const endBad = !endAfterStart(start, end);

  function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    if (titleBad || termBad || startBad || endBad) return;
    onSubmit({
      title: title.trim(),
      type,
      term: term.trim(),
      courseCode: emptyToNull(course),
      faculty: emptyToNull(faculty),
      department: emptyToNull(dept),
      grade: (grade || null) as Grade | null,
      startsAt: start,
      endsAt: end || null,
      room: emptyToNull(room),
      note: emptyToNull(note),
      published,
    });
  }

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t(exam ? 'admin.acd.ex.editTitle' : 'admin.acd.ex.addTitle')}
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
        <FormField label={t('admin.acd.ex.type')} required>
          <Select value={type} onChange={(e) => setType(e.target.value as ExamType)}>
            {EXAM_TYPES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.acd.ex.type.${x}` as const)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField
          label={t('admin.acd.ex.term')}
          required
          hint={t('admin.acd.ex.termHint')}
          error={touched && termBad ? t('admin.acd.ex.termReq') : null}
        >
          <Input value={term} maxLength={60} dir="auto" onChange={(e) => setTerm(e.target.value)} />
        </FormField>
        <FormField label={t('admin.acd.ex.course')}>
          <Input value={course} maxLength={20} dir="auto" onChange={(e) => setCourse(e.target.value)} />
        </FormField>
        <FormField label={t('admin.acd.ex.room')}>
          <Input value={room} maxLength={60} dir="auto" onChange={(e) => setRoom(e.target.value)} />
        </FormField>
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
        <FormField
          label={t('admin.acd.ex.start')}
          required
          hint={t('admin.acd.tzHint')}
          error={touched && startBad ? t('admin.acd.startReq') : null}
        >
          <Input type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} />
        </FormField>
        <FormField label={t('admin.acd.ex.end')} error={touched && endBad ? t('admin.acd.endBefore') : null}>
          <Input type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} />
        </FormField>
        <div className={styles.wide}>
          <FormField label={t('admin.acd.note')}>
            <Textarea
              value={note}
              maxLength={500}
              rows={3}
              dir="auto"
              onChange={(e) => setNote(e.target.value)}
            />
          </FormField>
        </div>
        <div className={styles.wide}>
          <Checkbox
            label={t('admin.acd.published')}
            checked={published}
            onChange={(e) => setPublished(e.target.checked)}
          />
        </div>
      </form>
    </Modal>
  );
}
