// SAYFA: Derse öğrenci ekle (/akademisyen/dersler/:id/ogrenciler/ekle). Öğrenci rehberinde arama (`q`) + fakülte/bölüm/sınıf süzgeci
// (herkese açık katalogdan), imleçli sayfalama, çoklu seçim, seçilenleri 100'lük parçalarla ekleme; bölüm/sınıfa göre toplu ekleme
// (sayı onaylanır). API: GET /academician/students, POST /academician/courses/{id}/enrollments (<=100), .../enrollments/bulk.
import { useEffect, useMemo, useState } from 'react';
import { useInfiniteQuery, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Navigate, useParams } from 'react-router-dom';
import {
  ENROLL_CHUNK,
  acadKeys,
  PartialEnrollError,
  addEnrollmentsChunked,
  bulkEnroll,
  bulkEnrollCount,
  getCourse,
  listEnrollments,
  searchStudents,
  type DirectoryStudent,
} from '../../api/academician';
import { Badge, BulkBar, Button, ConfirmDialog, DataToolbar, FormField, Icon, LoadMore, PageHeader, ResponsiveTable, Select, useToast, type Column } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { departmentOptions, useCatalog } from './components/CourseForm';
import { EmptyBlock, LoadingBlock, QueryError, courseTitle } from './components/common';
import { useT } from './dict';
import { acadError } from './errors';
import { acadPaths } from './paths';
import styles from './academician.module.css';

/** Toplu ekleme sınırı (sunucu: 500'ü aşan eşleşmede hiçbirini eklemez, 422 AC_BULK_TOO_LARGE). */
export const BULK_CAP = 500;

export default function EnrollPage() {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const { id: rawId } = useParams();
  const id = Number(rawId);
  const course = useQuery({ queryKey: acadKeys.course(id), queryFn: () => getCourse(id), enabled: Number.isFinite(id) });
  const enrolled = useQuery({ queryKey: acadKeys.enrollments(id), queryFn: () => listEnrollments(id), enabled: Number.isFinite(id) });
  const catalog = useCatalog();
  usePageTitle(t('ac.enroll.title'));

  const [q, setQ] = useState('');
  const [faculty, setFaculty] = useState('');
  const [department, setDepartment] = useState('');
  const [grade, setGrade] = useState('');
  const [selected, setSelected] = useState<Map<number, DirectoryStudent>>(new Map());
  const [adding, setAdding] = useState<{ done: number; total: number } | null>(null);
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkDept, setBulkDept] = useState('');
  const [bulkGrade, setBulkGrade] = useState('');
  const [bulkBusy, setBulkBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const filters = { q, faculty, department, grade };
  const hasFilter = !!(q || faculty || department || grade);
  const enrolledIds = useMemo(() => new Set((enrolled.data ?? []).map((e) => e.studentId)), [enrolled.data]);
  const results = useInfiniteQuery({
    queryKey: acadKeys.students(filters),
    queryFn: ({ pageParam }) => searchStudents({ ...filters, cursor: pageParam }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor,
    // süzgeç yokken tüm öğrenci rehberi listelenmez: önce arama/süzgeç istenir
    enabled: Number.isFinite(id) && hasFilter,
  });
  const found = results.data?.pages.flatMap((p) => p.items) ?? [];
  // zaten derste olanlar seçilemez: tabloya alınmaz, ayrı bir notta adlarıyla listelenir (ölü onay kutusu yok)
  const already = found.filter((s) => enrolledIds.has(s.id));
  const students = found.filter((s) => !enrolledIds.has(s.id));
  const depts = useMemo(() => departmentOptions(catalog.data, faculty), [catalog.data, faculty]);

  // kurs yüklenince toplu ekleme varsayılanları dersin hedef kitlesidir
  useEffect(() => {
    if (course.data) {
      setBulkDept((d) => d || course.data!.department);
      setBulkGrade((g) => g || course.data!.grade || '');
    }
  }, [course.data]);

  function onSelect(next: Set<string | number>) {
    setSelected((cur) => {
      const m = new Map(cur);
      // bu görünümdeki satırlar için seçimi eşitle; zaten kayıtlı öğrenci seçilemez
      for (const s of students) {
        if (enrolledIds.has(s.id)) continue;
        if (next.has(s.id)) m.set(s.id, s);
        else m.delete(s.id);
      }
      return m;
    });
  }

  async function addSelected() {
    const ids = [...selected.keys()];
    if (ids.length === 0) return;
    setError(null);
    setAdding({ done: 0, total: ids.length });
    try {
      const added = await addEnrollmentsChunked(id, ids, (done, total) => setAdding({ done, total }));
      toast.success(t('ac.enroll.added', { n: added, skipped: ids.length - added }));
      setSelected(new Map());
    } catch (e) {
      if (e instanceof PartialEnrollError) {
        // bir parça başarısız: önceki parçalar eklendi; kalanlar seçili kalır
        setError(`${t('ac.enroll.partial', { n: e.added, total: ids.length })} ${acadError(i18n, e.cause)}`);
      } else setError(acadError(i18n, e));
    } finally {
      setAdding(null);
      void qc.invalidateQueries({ queryKey: acadKeys.enrollments(id) });
      void qc.invalidateQueries({ queryKey: acadKeys.course(id) });
      void qc.invalidateQueries({ queryKey: acadKeys.attendance(id) });
    }
  }

  const bulkCount = useQuery({
    queryKey: ['academician', 'bulk-count', bulkDept, bulkGrade],
    queryFn: async () => (await bulkEnrollCount(id, bulkDept, bulkGrade)).wouldAdd,
    enabled: bulkOpen && !!bulkDept,
    staleTime: 0,
    gcTime: 0,
    retry: false,
  });
  const count = bulkCount.data;

  async function runBulk() {
    setBulkBusy(true);
    setError(null);
    try {
      const r = await bulkEnroll(id, bulkDept, bulkGrade);
      toast.success(t('ac.enroll.bulkDone', { n: r.added }));
      setBulkOpen(false);
      void qc.invalidateQueries({ queryKey: acadKeys.enrollments(id) });
      void qc.invalidateQueries({ queryKey: acadKeys.course(id) });
      void qc.invalidateQueries({ queryKey: acadKeys.attendance(id) });
    } catch (e) {
      setError(acadError(i18n, e));
      setBulkOpen(false);
    } finally {
      setBulkBusy(false);
    }
  }

  if (!Number.isFinite(id)) return <Navigate to={acadPaths.courses} replace />;

  const columns: Column<DirectoryStudent>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName, card: { priority: 1 } },
    { key: 'no', header: t('ac.students.col.no'), render: (s) => <span className="ltr">{s.studentNo ?? '—'}</span>, card: { priority: 1 } },
    { key: 'dept', header: t('ac.students.col.dept'), render: (s) => [s.faculty, s.department].filter(Boolean).join(' / ') || '—' },
    { key: 'grade', header: t('ac.enroll.col.grade'), render: (s) => s.grade ?? '—' },
    {
      key: 'state',
      header: t('ac.enroll.col.state'),
      render: (s) =>
        enrolledIds.has(s.id) ? (
          <Badge><Icon name="check" size={14} aria-hidden="true" /> {t('ac.enroll.alreadyIn')}</Badge>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
  ];

  const c = course.data;
  return (
    <div className={styles.page}>
      <Link to={acadPaths.course(id, 'ogrenciler')} className={styles.back}>
        <Icon name="chevronLeft" size={16} /> {c ? courseTitle(c) : t('ac.nav.courses')}
      </Link>
      <PageHeader title={t('ac.enroll.title')} description={t('ac.enroll.desc')} />
      {enrolled.isError && <QueryError subject={t('ac.enroll.enrolledSubject')} error={enrolled.error} onRetry={() => void enrolled.refetch()} />}
      {course.isError && <QueryError subject={t('ac.course.subject')} error={course.error} onRetry={() => void course.refetch()} />}
      {error && (
        <div className={styles.alertBox} role="alert">
          <Icon name="alert" size={18} />
          <span>{error}</span>
        </div>
      )}

      <section aria-label={t('ac.enroll.searchTitle')} className={styles.formStack}>
        <DataToolbar
          onSearch={setQ}
          searchPlaceholder={t('ac.enroll.searchPlaceholder')}
          filters={
            <>
              <Select aria-label={t('ac.courseForm.faculty')} value={faculty} onChange={(e) => { setFaculty(e.target.value); setDepartment(''); }}>
                <option value="">{t('ac.enroll.anyFaculty')}</option>
                {(catalog.data?.faculties ?? []).map((f) => (
                  <option key={f.id} value={f.name}>{f.name}</option>
                ))}
              </Select>
              <Select aria-label={t('ac.courseForm.department')} value={department} onChange={(e) => setDepartment(e.target.value)}>
                <option value="">{t('ac.enroll.anyDepartment')}</option>
                {depts.map((d) => (
                  <option key={d} value={d}>{d}</option>
                ))}
              </Select>
              <Select aria-label={t('ac.courseForm.grade')} value={grade} onChange={(e) => setGrade(e.target.value)}>
                <option value="">{t('ac.enroll.anyGrade')}</option>
                {(catalog.data?.grades ?? []).map((g) => (
                  <option key={g.id} value={g.id}>{g.name}</option>
                ))}
              </Select>
            </>
          }
        />
        {!hasFilter ? (
          <EmptyBlock icon="search" title={t('ac.enroll.start.title')} description={t('ac.enroll.start.text')} />
        ) : results.isLoading ? (
          <LoadingBlock rows={4} height="2.5rem" />
        ) : results.isError ? (
          <QueryError subject={t('ac.enroll.subject')} error={results.error} onRetry={() => void results.refetch()} />
        ) : found.length === 0 ? (
          <EmptyBlock
            icon="users"
            title={t('ac.noResults.title')}
            description={t('ac.enroll.noResults')}
            action={<Button variant="secondary" onClick={() => { setQ(''); setFaculty(''); setDepartment(''); setGrade(''); }}>{t('ac.noResults.clear')}</Button>}
          />
        ) : (
          <>
            {already.length > 0 && (
              <p className={styles.muted} role="status">
                {t('ac.enroll.alreadyNote', { n: already.length, names: already.map((s) => s.displayName).join(', ') })}
              </p>
            )}
            <ResponsiveTable
              columns={columns}
              rows={students}
              rowKey={(s) => s.id}
              caption={t('ac.enroll.caption')}
              selectedKeys={new Set(selected.keys())}
              onSelectionChange={onSelect}
              selectLabel={(s) => t('ac.enroll.selectAria', { name: s.displayName })}
            />
            <LoadMore hasMore={!!results.hasNextPage} loading={results.isFetchingNextPage} onLoadMore={() => void results.fetchNextPage()} />
          </>
        )}
      </section>

      {selected.size > 0 && (
        <BulkBar count={selected.size} onClear={() => setSelected(new Map())}>
          <Button loading={!!adding} onClick={() => void addSelected()} leftIcon={<Icon name="plus" size={16} />}>
            {adding ? t('ac.enroll.adding', { done: adding.done, total: adding.total }) : t('ac.enroll.addSelected', { n: selected.size })}
          </Button>
          {selected.size > ENROLL_CHUNK && <span className={styles.muted}>{t('ac.enroll.chunkNote', { n: Math.ceil(selected.size / ENROLL_CHUNK) })}</span>}
        </BulkBar>
      )}

      <section className={styles.bulkBox} aria-labelledby="bulk-h">
        <h2 id="bulk-h" className={styles.subHeading}>{t('ac.enroll.bulkTitle')}</h2>
        <p className={styles.muted}>{t('ac.enroll.bulkText', { max: BULK_CAP })}</p>
        <div className={styles.inlineForm}>
          <FormField label={t('ac.courseForm.department')}>
            <Select value={bulkDept} onChange={(e) => setBulkDept(e.target.value)}>
              <option value="">{t('ac.courseForm.pick')}</option>
              {bulkDept && !departmentOptions(catalog.data, '').includes(bulkDept) && <option value={bulkDept}>{bulkDept}</option>}
              {departmentOptions(catalog.data, '').map((d) => (
                <option key={d} value={d}>{d}</option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('ac.courseForm.grade')}>
            <Select value={bulkGrade} onChange={(e) => setBulkGrade(e.target.value)}>
              <option value="">{t('ac.enroll.anyGrade')}</option>
              {(catalog.data?.grades ?? []).map((g) => (
                <option key={g.id} value={g.id}>{g.name}</option>
              ))}
            </Select>
          </FormField>
          <Button variant="secondary" disabled={!bulkDept} onClick={() => setBulkOpen(true)}>
            {t('ac.enroll.bulkButton')}
          </Button>
        </div>
      </section>

      <ConfirmDialog
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        onConfirm={() => void runBulk()}
        loading={bulkBusy}
        confirmDisabled={bulkCount.isLoading || bulkCount.isError || !count}
        title={t('ac.enroll.bulkConfirmTitle')}
        message={
          bulkCount.isLoading
            ? t('ac.enroll.counting')
            : bulkCount.isError
              ? acadError(i18n, bulkCount.error)
              : count === 0
                ? t('ac.enroll.bulkNone')
                : t('ac.enroll.bulkCount', { n: count ?? 0, dept: bulkDept, grade: bulkGrade || t('ac.enroll.allGrades') })
        }
        consequence={t('ac.enroll.bulkConsequence')}
        confirmLabel={t('ac.enroll.bulkConfirm', { n: count ?? 0 })}
      />
    </div>
  );
}
