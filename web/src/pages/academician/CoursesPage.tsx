// SAYFA: Derslerim (/akademisyen/dersler). API: GET /academician/courses; oluşturma POST /academician/courses (CourseFormDialog).
// `?yeni=1` oluşturma penceresini açar (panoda "ilk dersini ekle" bağlantısı).
import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { acadKeys, listCourses, type Course } from '../../api/academician';
import { Badge, Button, Checkbox, DataToolbar, Icon, PageHeader } from '../../components/ui';
import { usePageTitle } from '../../lib/hooks';
import { CourseFormDialog } from './components/CourseForm';
import { EmptyBlock, LoadingBlock, QueryError, courseTitle } from './components/common';
import { useT } from './dict';
import { acadPaths } from './paths';
import styles from './academician.module.css';

export function slotSummary(c: Course, dayName: (d: number) => string): string {
  if (c.slots.length === 0) return '';
  return c.slots.map((s) => `${dayName(s.dayOfWeek)} ${s.startTime}–${s.endTime}`).join(', ');
}

export default function CoursesPage() {
  const t = useT();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  usePageTitle(t('ac.courses.title'));
  const courses = useQuery({ queryKey: acadKeys.courses(), queryFn: listCourses });
  const [q, setQ] = useState('');
  const [showArchived, setShowArchived] = useState(false);
  const creating = params.get('yeni') === '1';
  const setCreating = (v: boolean) => {
    const next = new URLSearchParams(params);
    if (v) next.set('yeni', '1');
    else next.delete('yeni');
    setParams(next, { replace: true });
  };

  const rows = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase('tr');
    return (courses.data ?? [])
      .filter((c) => (showArchived ? true : c.status === 'ACTIVE'))
      .filter((c) => !needle || `${c.code ?? ''} ${c.name} ${c.department} ${c.term}`.toLocaleLowerCase('tr').includes(needle));
  }, [courses.data, q, showArchived]);
  const archivedCount = (courses.data ?? []).filter((c) => c.status === 'ARCHIVED').length;
  const dayName = (d: number) => t(`ac.day.${d}.short`);

  return (
    <div className={styles.page}>
      <PageHeader
        title={t('ac.courses.title')}
        description={t('ac.courses.desc')}
        actions={
          <Button leftIcon={<Icon name="plus" size={18} />} onClick={() => setCreating(true)}>
            {t('ac.courses.new')}
          </Button>
        }
      />
      <DataToolbar
        onSearch={setQ}
        searchPlaceholder={t('ac.courses.search')}
        actions={
          archivedCount > 0 ? (
            <Checkbox checked={showArchived} onChange={(e) => setShowArchived(e.target.checked)} label={t('ac.courses.showArchived', { n: archivedCount })} />
          ) : undefined
        }
      />

      {courses.isLoading ? (
        <LoadingBlock rows={3} height="6rem" />
      ) : courses.isError ? (
        <QueryError subject={t('ac.courses.subject')} error={courses.error} onRetry={() => void courses.refetch()} />
      ) : (courses.data ?? []).length === 0 ? (
        <EmptyBlock
          icon="graduation"
          title={t('ac.courses.empty.title')}
          description={t('ac.courses.empty.text')}
          action={
            <Button leftIcon={<Icon name="plus" size={18} />} onClick={() => setCreating(true)}>
              {t('ac.courses.new')}
            </Button>
          }
        />
      ) : rows.length === 0 ? (
        <EmptyBlock
          icon="search"
          title={t('ac.courses.noMatch.title')}
          description={t('ac.courses.noMatch.text')}
          action={
            <Button variant="secondary" onClick={() => { setQ(''); setShowArchived(true); }}>
              {t('ac.courses.noMatch.action')}
            </Button>
          }
        />
      ) : (
        <ul className={styles.cardGrid}>
          {rows.map((c) => (
            <li key={c.id}>
              <Link to={acadPaths.course(c.id)} className={styles.courseCard}>
                <span className={styles.courseHead}>
                  <span className={styles.rowTitle}>{courseTitle(c)}</span>
                  {c.status === 'ARCHIVED' && <Badge>{t('ac.course.archived')}</Badge>}
                </span>
                <span className={styles.muted}>
                  {c.term} · {c.department}
                  {c.grade ? ` · ${c.grade}` : ''}
                </span>
                <span className={styles.muted}>{slotSummary(c, dayName) || t('ac.courses.noSlots')}</span>
                {c.limit.type && (
                  <span className={styles.muted}>
                    {t('ac.courses.limit')}: {c.limit.type === 'COUNT' ? t('ac.limit.countN', { n: c.limit.value ?? 0 }) : t('ac.limit.percentN', { n: c.limit.value ?? 0 })}
                  </span>
                )}
              </Link>
            </li>
          ))}
        </ul>
      )}

      {creating && <CourseFormDialog open onClose={() => setCreating(false)} onSaved={(c) => navigate(acadPaths.course(c.id))} />}
    </div>
  );
}
