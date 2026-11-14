// SEKME: Devamsızlık. Sınır türü (COUNT: ders sayısı, PERCENT: yüzde + isteğe bağlı planlanan ders sayısı), "en fazla N devamsızlık"
// satırı, risk sırasıyla öğrenci tablosu ve oturum matrisi (altı durum + açıklama; sayılmayan ve canlı oturum sütunları soluk).
// Vurgu renge ek olarak simge + metindir. API: GET /academician/courses/{id}/attendance, PATCH /academician/courses/{id}.
import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { acadKeys, getAttendance, patchCourse, type Course, type LimitType, type Mark, type MatrixStudent } from '../../../api/academician';
import { Badge, Button, Card, FormField, Icon, Input, ResponsiveTable, Select, Table, useToast, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { EmptyBlock, LinkButton, LoadingBlock, QueryError } from '../components/common';
import { MarkBadge, MarkLegend, isPresent } from '../components/MarkBadge';
import { useUnsavedGuard } from '../components/unsavedGuard';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtDateShort } from '../format';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';

type LimitChoice = LimitType | 'NONE';

/** Risk sırası: sınırı aşan/sınıra ulaşan -> sınıra bir kala -> en çok devamsız -> ada göre. */
export function riskSort(a: MatrixStudent, b: MatrixStudent): number {
  const rank = (s: MatrixStudent) => (s.overLimit ? 0 : s.atRisk ? 1 : 2);
  return rank(a) - rank(b) || b.absentCount - a.absentCount || a.displayName.localeCompare(b.displayName, 'tr');
}

export function limitError(type: LimitChoice, raw: string): 'range' | null {
  if (type === 'NONE') return null;
  const n = Number(raw);
  const max = type === 'PERCENT' ? 100 : 365;
  return Number.isInteger(n) && n >= 1 && n <= max ? null : 'range';
}

/** Planlanan ders sayısı: boş serbest, doluysa 1..400 tam sayı. */
export function plannedError(raw: string): 'range' | null {
  if (raw.trim() === '') return null;
  const n = Number(raw);
  return Number.isInteger(n) && n >= 1 && n <= 400 ? null : 'range';
}

export function AbsenceTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const matrix = useQuery({ queryKey: acadKeys.attendance(course.id), queryFn: () => getAttendance(course.id) });
  const [type, setType] = useState<LimitChoice>(course.limit.type ?? 'NONE');
  const [value, setValue] = useState(course.limit.value ? String(course.limit.value) : '');
  const [planned, setPlanned] = useState(course.plannedSessions ? String(course.plannedSessions) : '');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    setType(course.limit.type ?? 'NONE');
    setValue(course.limit.value ? String(course.limit.value) : '');
    setPlanned(course.plannedSessions ? String(course.plannedSessions) : '');
  }, [course.limit.type, course.limit.value, course.plannedSessions]);

  const save = useMutation({
    mutationFn: () =>
      patchCourse(
        course.id,
        type === 'NONE'
          ? { absenceLimitType: 'NONE' }
          : { absenceLimitType: type, absenceLimitValue: Number(value), ...(type === 'PERCENT' ? (planned.trim() !== '' ? { plannedSessions: Number(planned) } : course.plannedSessions ? { plannedSessions: 0 } : {}) : {}) },
      ),
    onSuccess: (c) => {
      qc.setQueryData(acadKeys.course(course.id), c);
      void qc.invalidateQueries({ queryKey: acadKeys.attendance(course.id) });
      void qc.invalidateQueries({ queryKey: acadKeys.courses() });
      setTouched(false);
      toast.success(t('ac.absence.saved'));
    },
    // hata: form değerleri korunur
    onError: (e) => setError(acadError(i18n, e)),
  });
  const err = touched ? limitError(type, value) : null;
  const errPlanned = type === 'PERCENT' && touched ? plannedError(planned) : null;
  const dirty =
    type !== (course.limit.type ?? 'NONE') ||
    (type !== 'NONE' && value !== String(course.limit.value ?? '')) ||
    (type === 'PERCENT' && planned !== (course.plannedSessions ? String(course.plannedSessions) : ''));
  useUnsavedGuard(dirty, t('ac.absence.leaveGuard'));

  const rows = useMemo(() => [...(matrix.data?.students ?? [])].sort(riskSort), [matrix.data]);
  const sessions = useMemo(() => matrix.data?.sessions ?? [], [matrix.data]);
  const limit = matrix.data?.limit ?? course.limit;
  const heldCounted = sessions.filter((s) => s.counted !== false && !s.live).length;
  const allowed = limit.allowedAbsences ?? course.limit.allowedAbsences ?? null;

  const stateCell = (s: MatrixStudent) => {
    if (s.overLimit) {
      const reached = limit.type === 'COUNT' && limit.value !== null && s.absentCount === limit.value;
      return (
        <Badge tone={reached ? 'warning' : 'danger'}>
          <Icon name="ban" size={14} aria-hidden="true" /> {reached ? t('ac.absence.reached') : t('ac.absence.over')}
        </Badge>
      );
    }
    if (s.atRisk) {
      return (
        <Badge tone="warning">
          <Icon name="alert" size={14} aria-hidden="true" /> {t('ac.absence.risk')}
        </Badge>
      );
    }
    return (
      <Badge>
        <Icon name="check" size={14} aria-hidden="true" /> {t('ac.absence.ok')}
      </Badge>
    );
  };

  const columns: Column<MatrixStudent>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName, card: { priority: 1 } },
    { key: 'no', header: t('ac.students.col.no'), render: (s) => <span className="ltr">{s.studentNo ?? '—'}</span> },
    {
      key: 'absent',
      header: t('ac.absence.col.absent'),
      align: 'end',
      render: (s) => (limit.type === 'COUNT' && limit.value ? `${s.absentCount} / ${limit.value}` : allowed ? `${s.absentCount} / ${allowed}` : s.absentCount),
    },
    { key: 'present', header: t('ac.absence.col.present'), align: 'end', render: (s) => sessions.filter((x) => isPresent(s.marks[String(x.id)])).length },
    { key: 'excused', header: t('ac.absence.col.excused'), align: 'end', render: (s) => sessions.filter((x) => s.marks[String(x.id)] === 'EXCUSED').length },
    { key: 'revoked', header: t('ac.absence.col.revoked'), align: 'end', render: (s) => sessions.filter((x) => s.marks[String(x.id)] === 'REVOKED').length },
    { key: 'state', header: t('ac.absence.col.state'), render: stateCell },
  ];

  // oturum matrisi: her oturum bir sütun; sayılmayan ve canlı oturum sütunları soluk + etiketli
  const matrixCols: Column<MatrixStudent>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName },
    ...sessions.map<Column<MatrixStudent>>((x) => ({
      key: `s${x.id}`,
      header: (
        <span className={styles.colHead} data-muted={x.counted === false || x.live || undefined}>
          {fmtDateShort(x.lessonDate)}
          {x.counted === false && <small>{t('ac.matrix.uncounted')}</small>}
          {x.live && <small>{t('ac.matrix.live')}</small>}
        </span>
      ),
      headerLabel: `${fmtDateShort(x.lessonDate)}${x.counted === false ? ` ${t('ac.matrix.uncounted')}` : ''}${x.live ? ` ${t('ac.matrix.live')}` : ''}`,
      render: (s) => (
        <span className={styles.cellMuted} data-muted={x.counted === false || x.live || undefined}>
          <MarkBadge mark={(s.marks[String(x.id)] ?? 'ABSENT') as Mark} provisional={!!x.live} />
        </span>
      ),
    })),
  ];

  return (
    <div className={styles.formStack}>
      <Card title={t('ac.absence.limitTitle')}>
        <p className={styles.muted}>{t('ac.absence.limitIntro')}</p>
        {error && (
          <div className={styles.alertBox} role="alert">
            <Icon name="alert" size={18} />
            <span>{error}</span>
          </div>
        )}
        <form
          className={styles.inlineForm}
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            if (save.isPending) return;
            setTouched(true);
            setError(null);
            if (limitError(type, value) || (type === 'PERCENT' && plannedError(planned))) return;
            save.mutate();
          }}
        >
          <FormField label={t('ac.absence.type')}>
            <Select value={type} onChange={(e) => setType(e.target.value as LimitChoice)}>
              <option value="NONE">{t('ac.absence.type.NONE')}</option>
              <option value="COUNT">{t('ac.absence.type.COUNT')}</option>
              <option value="PERCENT">{t('ac.absence.type.PERCENT')}</option>
            </Select>
          </FormField>
          {type !== 'NONE' && (
            <FormField
              label={type === 'COUNT' ? t('ac.absence.value.COUNT') : t('ac.absence.value.PERCENT')}
              error={err ? t(type === 'COUNT' ? 'ac.absence.err.COUNT' : 'ac.absence.err.PERCENT') : null}
              hint={type === 'COUNT' ? t('ac.absence.hint.COUNT') : t('ac.absence.hint.PERCENT')}
            >
              <Input type="number" inputMode="numeric" min={1} max={type === 'PERCENT' ? 100 : 365} value={value} onChange={(e) => setValue(e.target.value)} />
            </FormField>
          )}
          {type === 'PERCENT' && (
            <FormField label={t('ac.absence.planned')} error={errPlanned ? t('ac.absence.err.planned') : null} hint={planned.trim() ? t('ac.absence.plannedHint') : t('ac.absence.plannedNone')}>
              <Input type="number" inputMode="numeric" min={1} max={400} value={planned} onChange={(e) => setPlanned(e.target.value)} />
            </FormField>
          )}
          <Button type="submit" loading={save.isPending} disabled={!dirty}>
            {t('ac.save')}
          </Button>
        </form>
        {allowed !== null && type !== 'NONE' && (
          <p className={styles.allowedLine} role="status">
            <Icon name="info" size={16} aria-hidden="true" /> {t('ac.absence.allowed', { n: allowed })}
          </p>
        )}
      </Card>

      <Card title={t('ac.absence.tableTitle')}>
        {matrix.isLoading ? (
          <LoadingBlock rows={4} height="2.5rem" />
        ) : matrix.isError ? (
          <QueryError subject={t('ac.absence.subject')} error={matrix.error} onRetry={() => void matrix.refetch()} />
        ) : rows.length === 0 ? (
          <EmptyBlock icon="users" title={t('ac.students.empty.title')} description={t('ac.students.empty.text')} action={<LinkButton to={acadPaths.enroll(course.id)}>{t('ac.students.add')}</LinkButton>} />
        ) : (
          <>
            <p className={styles.muted}>{heldCounted === 0 ? t('ac.absence.noSessions') : t('ac.absence.sessionsN', { n: heldCounted })}</p>
            <ResponsiveTable columns={columns} rows={rows} rowKey={(s) => s.studentId} caption={t('ac.absence.caption')} />
          </>
        )}
      </Card>

      {rows.length > 0 && sessions.length > 0 && (
        <Card title={t('ac.matrix.title')}>
          <MarkLegend />
          <p className={styles.muted}>{t('ac.matrix.hint')}</p>
          <Table columns={matrixCols} rows={rows} rowKey={(s) => s.studentId} caption={t('ac.matrix.caption')} mobile="scroll" />
        </Card>
      )}
    </div>
  );
}
