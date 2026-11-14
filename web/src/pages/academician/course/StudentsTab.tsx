// SEKME: Öğrenciler. Derse kayıtlı öğrenci listesi + kaldırma. API: GET /academician/courses/{id}/enrollments,
// DELETE /academician/courses/{id}/enrollments/{studentId}. Ekleme ayrı sayfada (dersler/:id/ogrenciler/ekle).
import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { acadKeys, listEnrollments, removeEnrollment, type Course, type Enrollment } from '../../../api/academician';
import { Button, Card, ConfirmDialog, DataToolbar, Icon, ResponsiveTable, useToast, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { EmptyBlock, LinkButton, QueryError } from '../components/common';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtDateShort } from '../format';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';

export function StudentsTab({ course }: { course: Course }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const list = useQuery({ queryKey: acadKeys.enrollments(course.id), queryFn: () => listEnrollments(course.id) });
  const [q, setQ] = useState('');
  const [target, setTarget] = useState<Enrollment | null>(null);

  const remove = useMutation({
    mutationFn: (s: Enrollment) => removeEnrollment(course.id, s.studentId),
    onSuccess: (_r, s) => {
      void qc.invalidateQueries({ queryKey: acadKeys.enrollments(course.id) });
      void qc.invalidateQueries({ queryKey: acadKeys.attendance(course.id) });
      void qc.invalidateQueries({ queryKey: acadKeys.course(course.id) });
      toast.success(t('ac.students.removed', { name: s.displayName }));
      setTarget(null);
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setTarget(null);
    },
  });

  const rows = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase('tr');
    return (list.data ?? []).filter((s) => !needle || `${s.displayName} ${s.studentNo ?? ''}`.toLocaleLowerCase('tr').includes(needle));
  }, [list.data, q]);

  const columns: Column<Enrollment>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName, card: { priority: 1 } },
    { key: 'no', header: t('ac.students.col.no'), render: (s) => <span className="ltr">{s.studentNo ?? '—'}</span> },
    { key: 'dept', header: t('ac.students.col.dept'), render: (s) => [s.department, s.grade].filter(Boolean).join(' · ') || '—' },
    { key: 'added', header: t('ac.students.col.added'), render: (s) => fmtDateShort(s.addedAt) },
    {
      key: 'act',
      header: <span className="sr-only">{t('ac.col.actions')}</span>,
      align: 'end',
      card: { actions: true },
      render: (s) => (
        <Button size="sm" variant="dangerOutline" onClick={() => setTarget(s)} aria-label={t('ac.students.removeAria', { name: s.displayName })}>
          {t('ac.students.remove')}
        </Button>
      ),
    },
  ];

  return (
    <Card
      title={t('ac.students.title', { n: list.data?.length ?? 0 })}
      actions={
        <LinkButton to={acadPaths.enroll(course.id)} size="sm" leftIcon={<Icon name="plus" size={16} />}>
          {t('ac.students.add')}
        </LinkButton>
      }
    >
      {list.isError ? (
        <QueryError subject={t('ac.students.subject')} error={list.error} onRetry={() => void list.refetch()} />
      ) : !list.isLoading && (list.data ?? []).length === 0 ? (
        <EmptyBlock
          icon="users"
          title={t('ac.students.empty.title')}
          description={t('ac.students.empty.text')}
          action={<LinkButton to={acadPaths.enroll(course.id)} leftIcon={<Icon name="plus" size={16} />}>{t('ac.students.add')}</LinkButton>}
        />
      ) : (
        <>
          <DataToolbar onSearch={setQ} searchPlaceholder={t('ac.students.search')} />
          <ResponsiveTable
            columns={columns}
            rows={rows}
            rowKey={(s) => s.studentId}
            loading={list.isLoading}
            caption={t('ac.students.caption')}
            empty={
              <EmptyBlock icon="search" title={t('ac.noResults.title')} description={t('ac.noResults.text')} action={<Button variant="secondary" onClick={() => setQ('')}>{t('ac.noResults.clear')}</Button>} />
            }
          />
        </>
      )}
      <ConfirmDialog
        open={!!target}
        onClose={() => setTarget(null)}
        onConfirm={() => target && remove.mutate(target)}
        loading={remove.isPending}
        danger
        role="alertdialog"
        title={t('ac.students.removeTitle', { name: target?.displayName ?? '' })}
        message={t('ac.students.removeText')}
        consequence={t('ac.students.removeConsequence')}
        confirmLabel={t('ac.students.remove')}
        initialFocus="cancel"
      />
      <p className={styles.muted}>{t('ac.students.footnote')}</p>
    </Card>
  );
}
