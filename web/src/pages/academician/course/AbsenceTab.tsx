// SEKME: Devamsızlık. Sınır türü (COUNT: ders sayısı, PERCENT: yüzde) + değer; öğrenciler risk sırasıyla (sınırı aşan, sınıra bir kala,
// diğerleri). Vurgu renge ek olarak simge + metindir. API: GET /academician/courses/{id}/attendance, PATCH /academician/courses/{id}.
import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { acadKeys, getAttendance, patchCourse, type Course, type LimitType, type MatrixStudent } from '../../../api/academician';
import { Badge, Button, Card, FormField, Icon, Input, ResponsiveTable, Select, useToast, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { EmptyBlock, LinkButton, LoadingBlock, QueryError } from '../components/common';
import { isPresent } from '../components/MarkBadge';
import { useT } from '../dict';
import { acadError } from '../errors';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';

type LimitChoice = LimitType | 'NONE';

/** Risk sırası: sınırı aşan -> sınıra bir kala -> en çok devamsız -> ada göre. */
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

export function AbsenceTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const matrix = useQuery({ queryKey: acadKeys.attendance(course.id), queryFn: () => getAttendance(course.id) });
  const [type, setType] = useState<LimitChoice>(course.limit.type ?? 'NONE');
  const [value, setValue] = useState(course.limit.value ? String(course.limit.value) : '');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    setType(course.limit.type ?? 'NONE');
    setValue(course.limit.value ? String(course.limit.value) : '');
  }, [course.limit.type, course.limit.value]);

  const save = useMutation({
    mutationFn: () => patchCourse(course.id, type === 'NONE' ? { absenceLimitType: 'NONE' } : { absenceLimitType: type, absenceLimitValue: Number(value) }),
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
  const dirty = type !== (course.limit.type ?? 'NONE') || (type !== 'NONE' && value !== String(course.limit.value ?? ''));

  const rows = useMemo(() => [...(matrix.data?.students ?? [])].sort(riskSort), [matrix.data]);
  const sessionIds = (matrix.data?.sessions ?? []).map((s) => String(s.id));
  const limit = matrix.data?.limit ?? course.limit;
  const total = sessionIds.length;

  const columns: Column<MatrixStudent>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName, card: { priority: 1 } },
    { key: 'no', header: t('ac.students.col.no'), render: (s) => <span className="ltr">{s.studentNo ?? '—'}</span> },
    {
      key: 'absent',
      header: t('ac.absence.col.absent'),
      align: 'end',
      render: (s) => (limit.type === 'COUNT' && limit.value ? `${s.absentCount} / ${limit.value}` : limit.type === 'PERCENT' && total > 0 ? `${s.absentCount} (%${Math.round((s.absentCount / total) * 100)})` : s.absentCount),
    },
    {
      key: 'present',
      header: t('ac.absence.col.present'),
      align: 'end',
      render: (s) => sessionIds.filter((id) => isPresent(s.marks[id])).length,
    },
    {
      key: 'revoked',
      header: t('ac.absence.col.revoked'),
      align: 'end',
      render: (s) => sessionIds.filter((id) => s.marks[id] === 'REVOKED').length,
    },
    {
      key: 'state',
      header: t('ac.absence.col.state'),
      render: (s) =>
        s.overLimit ? (
          <Badge tone="danger"><Icon name="ban" size={14} aria-hidden="true" /> {t('ac.absence.over')}</Badge>
        ) : s.atRisk ? (
          <Badge tone="warning"><Icon name="alert" size={14} aria-hidden="true" /> {t('ac.absence.risk')}</Badge>
        ) : (
          <Badge><Icon name="check" size={14} aria-hidden="true" /> {t('ac.absence.ok')}</Badge>
        ),
    },
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
            setTouched(true);
            setError(null);
            if (limitError(type, value)) return;
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
            <FormField label={type === 'COUNT' ? t('ac.absence.value.COUNT') : t('ac.absence.value.PERCENT')} error={err ? t(type === 'COUNT' ? 'ac.absence.err.COUNT' : 'ac.absence.err.PERCENT') : null} hint={type === 'COUNT' ? t('ac.absence.hint.COUNT') : t('ac.absence.hint.PERCENT')}>
              <Input type="number" inputMode="numeric" min={1} max={type === 'PERCENT' ? 100 : 365} value={value} onChange={(e) => setValue(e.target.value)} />
            </FormField>
          )}
          <Button type="submit" loading={save.isPending} disabled={!dirty}>
            {t('ac.save')}
          </Button>
        </form>
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
            <p className={styles.muted}>{total === 0 ? t('ac.absence.noSessions') : t('ac.absence.sessionsN', { n: total })}</p>
            <ResponsiveTable columns={columns} rows={rows} rowKey={(s) => s.studentId} caption={t('ac.absence.caption')} />
          </>
        )}
      </Card>
    </div>
  );
}
