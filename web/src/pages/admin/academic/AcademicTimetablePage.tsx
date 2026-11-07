// SAYFA: Resmî ders programı (/admin/academic/timetable)
// API: /api/admin/academic/timetable/* (import[dryRun], programs, entries, publish, DELETE programs) -> api/academicTimetable.ts.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type ChangeEvent } from 'react';
import { acdKeys } from '../../../api/academic';
import {
  deleteTimetableProgram,
  importTimetable,
  listTimetableEntries,
  listTimetablePrograms,
  setTimetablePublished,
  ttKeys,
  type TimetableImportResult,
  type TimetableProgram,
} from '../../../api/academicTimetable';
import {
  Badge,
  Button,
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
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../../lib/hooks';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './academic.module.css';

const PAGE_SIZE = 50; // ders saati listesi (pencere)
const LIST_PAGE_SIZE = 20; // program listesi
const PREVIEW_PAGE_SIZE = 10; // önizleme penceresindeki program listesi
const pagesOf = (n: number, size: number) => Math.max(1, Math.ceil(n / size));
const DAY_KEYS = [1, 2, 3, 4, 5, 6, 7] as const;
const TEMPLATE_URL = '/ders-programi-sablonu.xlsx';

export default function AcademicTimetablePage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.acd.tt.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);

  const [term, setTerm] = useState('');
  const [qText, setQText] = useState('');
  const q = useDebouncedValue(qText, 250);
  const [unit, setUnit] = useState('');
  const [page, setPage] = useState(0);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<TimetableImportResult | null>(null);
  const [viewing, setViewing] = useState<TimetableProgram | null>(null);
  const [removing, setRemoving] = useState<TimetableProgram | null>(null);

  const programs = useQuery({ queryKey: ttKeys.programs(term), queryFn: () => listTimetablePrograms(term) });
  const activeTerm = programs.data?.term ?? '';

  const refresh = () => void qc.invalidateQueries({ queryKey: acdKeys.all });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const check = useMutation({
    mutationFn: (f: File) => importTimetable(f, true),
    onSuccess: (r) => setPreview(r),
    onError: (e) => {
      onError(e);
      setFile(null);
    },
  });
  const commit = useMutation({
    mutationFn: (f: File) => importTimetable(f, false),
    onSuccess: (r) => {
      toast.success(t('admin.acd.tt.done', { rows: formatNumber(r.inserted), replaced: formatNumber(r.replacedPrograms) }));
      setPreview(null);
      setFile(null);
      if (r.term) setTerm(r.term);
      refresh();
    },
    onError,
  });
  const toggle = useMutation({
    mutationFn: (x: TimetableProgram) => setTimetablePublished(activeTerm, x.unit, x.program, !x.published),
    onSuccess: (_r, x) => {
      toast.success(t(x.published ? 'admin.acd.unpublishedToast' : 'admin.acd.publishedToast'));
      refresh();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: (x: TimetableProgram) => deleteTimetableProgram(activeTerm, x.unit, x.program),
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

  function pick(e: ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    e.target.value = ''; // aynı dosya yeniden seçilebilsin
    if (!f) return;
    if (!/\.xlsx$/i.test(f.name)) {
      toast.error(t('admin.acd.tt.pickFile'));
      return;
    }
    setFile(f);
    setPreview(null);
    check.mutate(f);
  }

  function closePreview() {
    setPreview(null);
    setFile(null);
  }

  const needle = q.trim().toLocaleLowerCase('tr');
  const all = programs.data?.items ?? [];
  const units = [...new Set(all.map((x) => x.unit))].sort((a, b) => a.localeCompare(b, 'tr'));
  const items = all.filter(
    (x) => (!unit || x.unit === unit) && (!needle || `${x.unit} ${x.program}`.toLocaleLowerCase('tr').includes(needle)),
  );
  const totalSessions = items.reduce((n, x) => n + x.sessions, 0);
  const lastPage = pagesOf(items.length, LIST_PAGE_SIZE) - 1;
  const safePage = Math.min(page, lastPage); // silme/süzgeç sonrası son sayfadan taşmasın
  const pageItems = items.slice(safePage * LIST_PAGE_SIZE, (safePage + 1) * LIST_PAGE_SIZE);

  return (
    <>
      <PageHeader
        title={t('admin.acd.tt.title')}
        description={t('admin.acd.tt.intro')}
        actions={
          <>
            <Button variant="secondary" onClick={() => window.location.assign(TEMPLATE_URL)}>
              {t('admin.acd.tt.template')}
            </Button>
            <input
              ref={fileRef}
              type="file"
              hidden
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              onChange={pick}
              aria-label={t('admin.acd.tt.upload')}
            />
            <Button data-search-anchor="tt-upload" loading={check.isPending} onClick={() => fileRef.current?.click()}>
              {t('admin.acd.tt.upload')}
            </Button>
          </>
        }
      />
      <div className={styles.stack}>
        <div className={styles.toolbar} data-search-anchor="tt-filters">
          <FormField label={t('admin.acd.tt.term')}>
            <Select
              value={activeTerm}
              onChange={(e) => {
                setTerm(e.target.value);
                setUnit('');
                setPage(0);
              }}
              disabled={!programs.data?.terms.length}
            >
              {(programs.data?.terms ?? []).map((x) => (
                <option key={x.term} value={x.term}>
                  {x.term}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.tt.unit')}>
            <Select
              value={unit}
              onChange={(e) => {
                setUnit(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.tt.unitAll')}</option>
              {units.map((u) => (
                <option key={u} value={u}>
                  {u}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.search')}>
            <Input
              value={qText}
              maxLength={80}
              dir="auto"
              placeholder={t('admin.acd.tt.search')}
              onChange={(e) => {
                setQText(e.target.value);
                setPage(0);
              }}
            />
          </FormField>
        </div>

        {programs.isError ? (
          <ErrorState description={adminErrorMessage(i18n, programs.error)} onRetry={() => void programs.refetch()} />
        ) : programs.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : (programs.data?.items.length ?? 0) === 0 ? (
          <EmptyState icon="list" title={t('admin.acd.tt.emptyTitle')} description={t('admin.acd.tt.emptyHint')} />
        ) : (
          <>
            <p className={styles.muted}>
              {t('admin.acd.tt.insight', { programs: formatNumber(items.length), sessions: formatNumber(totalSessions) })}
            </p>
            <ul className={styles.rowList} aria-label={t('admin.acd.rows')}>
              {pageItems.map((x) => (
                <li key={`${x.unit}|${x.program}`} className={styles.item}>
                  <div className={styles.itemHead}>
                    <StatusPill tone={x.published ? 'success' : 'neutral'}>
                      {t(x.published ? 'admin.acd.published' : 'admin.acd.draft')}
                    </StatusPill>
                    {!x.catalogMatched && <Badge tone="warning">{t('admin.acd.tt.catalogNo')}</Badge>}
                  </div>
                  <h3 className={styles.itemTitle} dir="auto">
                    {x.program}
                  </h3>
                  <p className={styles.muted} dir="auto">
                    {x.unit} · {t('admin.acd.tt.colGrades')}: {x.grades.map((g) => t(`admin.acd.grade.${g}` as const)).join(', ')} ·{' '}
                    {t('admin.acd.tt.sessions', { n: formatNumber(x.sessions) })}
                  </p>
                  <div className={styles.actions}>
                    <Button size="sm" variant="secondary" onClick={() => setViewing(x)}>
                      {t('admin.acd.tt.view')}
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      loading={toggle.isPending && toggle.variables?.program === x.program && toggle.variables?.unit === x.unit}
                      onClick={() => toggle.mutate(x)}
                    >
                      {t(x.published ? 'admin.acd.unpublish' : 'admin.acd.publish')}
                    </Button>
                    <span className={styles.spacer} />
                    <Button size="sm" variant="danger" onClick={() => setRemoving(x)}>
                      {t('common.delete')}
                    </Button>
                  </div>
                </li>
              ))}
            </ul>
            {items.length === 0 ? (
              <EmptyState icon="list" title={t('admin.acd.tt.noMatchTitle')} description={t('admin.acd.tt.noMatchHint')} />
            ) : (
              <Pagination
                page={safePage}
                totalPages={pagesOf(items.length, LIST_PAGE_SIZE)}
                totalItems={items.length}
                onPageChange={setPage}
              />
            )}
          </>
        )}
      </div>

      {file && preview && (
        <PreviewModal
          preview={preview}
          fileName={file.name}
          saving={commit.isPending}
          onClose={closePreview}
          onConfirm={() => commit.mutate(file)}
        />
      )}
      {viewing && <EntriesModal term={activeTerm} program={viewing} onClose={() => setViewing(null)} />}
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.acd.tt.deleteTitle')}
        message={t('admin.acd.tt.deleteBody')}
        confirmLabel={t('common.delete')}
      />
    </>
  );
}

function PreviewModal({
  preview,
  fileName,
  saving,
  onClose,
  onConfirm,
}: {
  preview: TimetableImportResult;
  fileName: string;
  saving: boolean;
  onClose: () => void;
  onConfirm: () => void;
}) {
  const { t, formatNumber } = useI18n();
  const blocked = preview.errors.length > 0;
  const [listPage, setListPage] = useState(0);
  const shown = preview.items.slice(listPage * PREVIEW_PAGE_SIZE, (listPage + 1) * PREVIEW_PAGE_SIZE);
  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t('admin.acd.tt.previewTitle')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button disabled={blocked} loading={saving} onClick={onConfirm}>
            {t('admin.acd.tt.confirm')}
          </Button>
        </>
      }
    >
      <p className={styles.muted} dir="auto">
        {fileName}
      </p>
      <p className={styles.muted}>
        {t('admin.acd.tt.previewSummary', {
          rows: formatNumber(preview.rows),
          programs: formatNumber(preview.programs),
          term: preview.term ?? '—',
        })}
      </p>
      {blocked && <p className={styles.warnText}>{t('admin.acd.tt.blocked')}</p>}
      {preview.errors.length > 0 && (
        <section>
          <h3 className={styles.groupHead}>{t('admin.acd.tt.errors', { n: formatNumber(preview.errors.length) })}</h3>
          <ul className={styles.errorList}>
            {preview.errors.map((e, i) => (
              <li key={i} dir="auto">
                {t('admin.acd.tt.row', { row: e.row })}: {e.message}
              </li>
            ))}
          </ul>
        </section>
      )}
      {preview.warnings.length > 0 && (
        <section>
          <h3 className={styles.groupHead}>{t('admin.acd.tt.warnings', { n: formatNumber(preview.warnings.length) })}</h3>
          <ul className={styles.errorList}>
            {preview.warnings.map((e, i) => (
              <li key={i} dir="auto">
                {t('admin.acd.tt.row', { row: e.row })}: {e.message}
              </li>
            ))}
          </ul>
        </section>
      )}
      <section>
        <h3 className={styles.groupHead}>{t('admin.acd.tt.programsInFile')}</h3>
        <ul className={styles.rowList}>
          {shown.map((x) => (
            <li key={`${x.unit}|${x.program}`} className={styles.item}>
              <h4 className={styles.itemTitle} dir="auto">
                {x.program} {!x.catalogMatched && <Badge tone="warning">{t('admin.acd.tt.catalogNo')}</Badge>}
              </h4>
              <p className={styles.muted} dir="auto">
                {x.unit} · {x.grades.map((g) => t(`admin.acd.grade.${g}` as const)).join(', ')} ·{' '}
                {t('admin.acd.tt.sessions', { n: formatNumber(x.sessions) })}
              </p>
            </li>
          ))}
        </ul>
        <Pagination
          page={listPage}
          totalPages={pagesOf(preview.items.length, PREVIEW_PAGE_SIZE)}
          totalItems={preview.items.length}
          onPageChange={setListPage}
        />
      </section>
    </Modal>
  );
}

function EntriesModal({ term, program, onClose }: { term: string; program: TimetableProgram; onClose: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [grade, setGrade] = useState('');
  const [page, setPage] = useState(0);
  const params = { term, unit: program.unit, program: program.program, grade: grade || undefined, page, size: PAGE_SIZE };
  const list = useQuery({ queryKey: ttKeys.entries(params), queryFn: () => listTimetableEntries(params) });
  return (
    <Modal open onClose={onClose} size="lg" title={t('admin.acd.tt.entriesTitle', { program: program.program })}>
      <div className={styles.toolbar}>
        <FormField label={t('admin.acd.grade')}>
          <Select
            value={grade}
            onChange={(e) => {
              setGrade(e.target.value);
              setPage(0);
            }}
          >
            <option value="">{t('admin.acd.gradeAll')}</option>
            {program.grades.map((g) => (
              <option key={g} value={g}>
                {t(`admin.acd.grade.${g}` as const)}
              </option>
            ))}
          </Select>
        </FormField>
      </div>
      {list.isError ? (
        <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <Skeleton height="6rem" width="100%" />
      ) : (
        <>
          <ul className={styles.rowList}>
            {(list.data?.items ?? []).map((x) => (
              <li key={x.id} className={styles.item}>
                <div className={styles.itemHead}>
                  <Badge tone="info">{t(`admin.acd.grade.${x.grade}` as const)}</Badge>
                  <strong>
                    {t(`admin.acd.tt.day.${DAY_KEYS[x.day - 1] ?? 1}` as const)} {x.start}–{x.end}
                  </strong>
                  {x.group && <Badge tone="neutral">{x.group}</Badge>}
                </div>
                <h4 className={styles.itemTitle} dir="auto">
                  {x.code ? `${x.code} · ` : ''}
                  {x.name}
                </h4>
                <p className={styles.muted} dir="auto">
                  {[x.instructor, x.room, x.note].filter(Boolean).join(' · ')}
                </p>
              </li>
            ))}
          </ul>
          <Pagination
            page={page}
            totalPages={Math.max(1, Math.ceil((list.data?.total ?? 0) / PAGE_SIZE))}
            totalItems={list.data?.total ?? 0}
            onPageChange={setPage}
          />
        </>
      )}
    </Modal>
  );
}
