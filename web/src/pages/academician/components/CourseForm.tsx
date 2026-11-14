// Ders oluşturma/düzenleme penceresi. Fakülte/bölüm/sınıf seçenekleri herkese açık katalogdan gelir (GET /api/catalog/academic):
// ders hedef kitlesi (bölüm) toplu kayıtta öğrenci profilindeki bölüm adıyla eşleşir. Sunucu değerleri katalogla doğrular.
import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { acadKeys, createCourse, getCatalog, patchCourse, type Course, type CourseBody } from '../../../api/academician';
import { Button, FormField, Icon, Input, Modal, Select, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT } from '../dict';
import { acadError } from '../errors';
import styles from '../academician.module.css';

export function useCatalog() {
  return useQuery({ queryKey: acadKeys.catalog(), queryFn: getCatalog, staleTime: Infinity });
}

/** Fakülte seçiliyse onun bölümleri, değilse tüm bölümler (ada göre tekil). */
export function departmentOptions(catalog: ReturnType<typeof useCatalog>['data'], faculty: string): string[] {
  if (!catalog) return [];
  if (faculty) return (catalog.faculties.find((f) => f.name === faculty)?.departments ?? []).map((d) => d.name);
  return [...new Set(catalog.faculties.flatMap((f) => f.departments.map((d) => d.name)))].sort((a, b) => a.localeCompare(b, 'tr'));
}

interface Props {
  open: boolean;
  onClose: () => void;
  /** Verilirse düzenleme, yoksa oluşturma. */
  course?: Course;
  onSaved?: (c: Course) => void;
}

export function CourseFormDialog({ open, onClose, course, onSaved }: Props) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const catalog = useCatalog();
  const [code, setCode] = useState(course?.code ?? '');
  const [name, setName] = useState(course?.name ?? '');
  const [term, setTerm] = useState(course?.term ?? defaultTerm());
  const [faculty, setFaculty] = useState(course?.faculty ?? '');
  const [department, setDepartment] = useState(course?.department ?? '');
  const [grade, setGrade] = useState(course?.grade ?? '');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const depts = useMemo(() => departmentOptions(catalog.data, faculty), [catalog.data, faculty]);

  const save = useMutation({
    mutationFn: (b: CourseBody) =>
      course
        ? patchCourse(course.id, { code: b.code ?? '', name: b.name, term: b.term, faculty: b.faculty ?? '', department: b.department, grade: b.grade ?? '' })
        : createCourse(b),
    onSuccess: (c) => {
      void qc.invalidateQueries({ queryKey: acadKeys.courses() });
      if (course) void qc.invalidateQueries({ queryKey: acadKeys.course(course.id) });
      toast.success(course ? t('ac.courseForm.saved') : t('ac.courseForm.created'));
      onSaved?.(c);
      onClose();
    },
    // hata: pencere açık kalır, girdi korunur
    onError: (e) => setError(acadError(i18n, e)),
  });

  const req = t('ac.field.required');
  const errName = touched && !name.trim() ? req : null;
  const errTerm = touched && !term.trim() ? req : null;
  const errDept = touched && !department.trim() ? req : null;

  function submit() {
    setTouched(true);
    setError(null);
    if (!name.trim() || !term.trim() || !department.trim()) return;
    save.mutate({
      code: code.trim() || undefined,
      name: name.trim(),
      term: term.trim(),
      faculty: faculty || undefined,
      department: department.trim(),
      grade: grade || undefined,
    });
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={course ? t('ac.courseForm.editTitle') : t('ac.courseForm.newTitle')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('ac.cancel')}
          </Button>
          <Button loading={save.isPending} onClick={submit}>
            {course ? t('ac.save') : t('ac.courseForm.create')}
          </Button>
        </>
      }
    >
      <form
        className={styles.formStack}
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        {error && (
          <div className={styles.alertBox} role="alert">
            <Icon name="alert" size={18} />
            <span>{error}</span>
          </div>
        )}
        <div className={styles.twoCol}>
          <FormField label={t('ac.courseForm.code')} hint={t('ac.courseForm.codeHint')}>
            <Input value={code} maxLength={30} onChange={(e) => setCode(e.target.value)} />
          </FormField>
          <FormField label={t('ac.courseForm.term')} error={errTerm} hint={t('ac.courseForm.termHint')} required>
            <Input value={term} maxLength={40} onChange={(e) => setTerm(e.target.value)} />
          </FormField>
        </div>
        <FormField label={t('ac.courseForm.name')} error={errName} required>
          <Input value={name} maxLength={200} onChange={(e) => setName(e.target.value)} data-autofocus />
        </FormField>
        <FormField label={t('ac.courseForm.faculty')} hint={t('ac.courseForm.facultyHint')}>
          <Select
            value={faculty}
            onChange={(e) => {
              setFaculty(e.target.value);
              setDepartment('');
            }}
          >
            <option value="">{t('ac.courseForm.anyFaculty')}</option>
            {(catalog.data?.faculties ?? []).map((f) => (
              <option key={f.id} value={f.name}>
                {f.name}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('ac.courseForm.department')} error={errDept} hint={t('ac.courseForm.departmentHint')} required>
          <Select value={department} onChange={(e) => setDepartment(e.target.value)}>
            <option value="">{t('ac.courseForm.pick')}</option>
            {/* düzenlemede katalogda artık olmayan eski değer de seçilebilir kalır */}
            {department && !depts.includes(department) && <option value={department}>{department}</option>}
            {depts.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('ac.courseForm.grade')} hint={t('ac.courseForm.gradeHint')}>
          <Select value={grade} onChange={(e) => setGrade(e.target.value)}>
            <option value="">{t('ac.courseForm.anyGrade')}</option>
            {(catalog.data?.grades ?? []).map((g) => (
              <option key={g.id} value={g.id}>
                {g.name}
              </option>
            ))}
          </Select>
        </FormField>
        {catalog.isError && <p className={styles.muted}>{t('ac.courseForm.catalogError')}</p>}
      </form>
    </Modal>
  );
}

/** "2026-2027 Güz": Ağustos'tan itibaren yeni akademik yıl; Şubat-Temmuz Bahar. */
export function defaultTerm(now: Date = new Date()): string {
  const y = now.getFullYear();
  const m = now.getMonth() + 1;
  if (m >= 8) return `${y}-${y + 1} Güz`;
  if (m === 1) return `${y - 1}-${y} Güz`;
  return `${y - 1}-${y} Bahar`;
}
