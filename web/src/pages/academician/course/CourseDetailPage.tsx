// SAYFA: Ders ayrıntısı (/akademisyen/dersler/:id?sekme=...). Sekmeler: Program, Öğrenciler, Yoklamalar, Devamsızlık,
// Duyurular, Dışa aktar. API: GET/PATCH/DELETE /academician/courses/{id}; sekmeler kendi uçlarını kullanır.
import { useState, type ReactNode } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Navigate, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { acadKeys, deleteCourse, getCourse, patchCourse } from '../../../api/academician';
import { isApiError } from '../../../api/client';
import { Badge, Button, ConfirmDialog, EmptyState, Icon, PageHeader, Tabs, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { CourseFormDialog } from '../components/CourseForm';
import { LinkButton, LoadingBlock, QueryError, StartSessionDialog, courseTitle } from '../components/common';
import { useT } from '../dict';
import { acadError } from '../errors';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';
import { AbsenceTab } from './AbsenceTab';
import { ExportTab } from './ExportTab';
import { NoticesTab } from './NoticesTab';
import { ProgramTab } from './ProgramTab';
import { SessionsTab } from './SessionsTab';
import { StudentsTab } from './StudentsTab';

export const COURSE_TABS = ['program', 'ogrenciler', 'yoklamalar', 'devamsizlik', 'duyurular', 'disa-aktar'] as const;
type TabId = (typeof COURSE_TABS)[number];
const TAB_KEY: Record<TabId, string> = {
  program: 'ac.tab.program',
  ogrenciler: 'ac.tab.students',
  yoklamalar: 'ac.tab.sessions',
  devamsizlik: 'ac.tab.absence',
  duyurular: 'ac.tab.notices',
  'disa-aktar': 'ac.tab.export',
};

export default function CourseDetailPage() {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { id: rawId } = useParams();
  const id = Number(rawId);
  const [params, setParams] = useSearchParams();
  const requested = params.get('sekme');
  const tab: TabId = (COURSE_TABS as readonly string[]).includes(requested ?? '') ? (requested as TabId) : 'program';
  const [editing, setEditing] = useState(false);
  const [starting, setStarting] = useState(false);
  const [confirm, setConfirm] = useState<null | 'delete' | 'archive'>(null);

  const course = useQuery({ queryKey: acadKeys.course(id), queryFn: () => getCourse(id), enabled: Number.isFinite(id) });
  usePageTitle(course.data ? courseTitle(course.data) : t('ac.nav.courses'));

  const archive = useMutation({
    mutationFn: () => patchCourse(id, { status: course.data?.status === 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE' }),
    onSuccess: (c) => {
      qc.setQueryData(acadKeys.course(id), c);
      void qc.invalidateQueries({ queryKey: acadKeys.courses() });
      toast.success(c.status === 'ARCHIVED' ? t('ac.course.archivedDone') : t('ac.course.activatedDone'));
      setConfirm(null);
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setConfirm(null);
    },
  });
  const remove = useMutation({
    mutationFn: () => deleteCourse(id),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: acadKeys.courses() });
      qc.removeQueries({ queryKey: acadKeys.course(id) });
      toast.success(t('ac.course.deleted'));
      navigate(acadPaths.courses, { replace: true });
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setConfirm(null);
    },
  });

  if (!Number.isFinite(id)) return <Navigate to={acadPaths.courses} replace />;
  if (course.isLoading) return <LoadingBlock rows={3} height="6rem" />;
  if (course.isError) {
    if (isApiError(course.error) && course.error.status === 404) {
      return (
        <EmptyState
          icon="search"
          title={t('ac.course.notFound.title')}
          description={t('ac.course.notFound.text')}
          action={<LinkButton to={acadPaths.courses}>{t('ac.course.notFound.action')}</LinkButton>}
        />
      );
    }
    return <QueryError subject={t('ac.course.subject')} error={course.error} onRetry={() => void course.refetch()} />;
  }
  const c = course.data!;
  const archived = c.status === 'ARCHIVED';

  return (
    <div className={styles.page}>
      <Link to={acadPaths.courses} className={styles.back}>
        <Icon name="chevronLeft" size={16} /> {t('ac.nav.courses')}
      </Link>
      <PageHeader
        title={
          <>
            {courseTitle(c)} {archived && <Badge>{t('ac.course.archived')}</Badge>}
          </>
        }
        description={`${c.term} · ${c.department}${c.grade ? ` · ${c.grade}` : ''}${c.enrolledCount !== null ? ` · ${t('ac.course.enrolledN', { n: c.enrolledCount })}` : ''}`}
        actions={
          <>
            <Button leftIcon={<Icon name="play" size={16} />} disabled={archived} title={archived ? t('ac.course.archivedHint') : undefined} onClick={() => setStarting(true)}>
              {t('ac.course.startAttendance')}
            </Button>
            <Button variant="secondary" leftIcon={<Icon name="pencil" size={16} />} onClick={() => setEditing(true)}>
              {t('ac.edit')}
            </Button>
            <Button variant="secondary" onClick={() => (archived ? archive.mutate() : setConfirm('archive'))} loading={archive.isPending && !confirm}>
              {archived ? t('ac.course.activate') : t('ac.course.archive')}
            </Button>
            <Button variant="dangerOutline" onClick={() => setConfirm('delete')}>
              {t('ac.delete')}
            </Button>
          </>
        }
      />

      <Tabs
        label={t('ac.tab.aria')}
        value={tab}
        onChange={(v) => {
          const next = new URLSearchParams(params);
          next.set('sekme', v);
          setParams(next, { replace: true });
        }}
        tabs={COURSE_TABS.map((k) => ({ id: k, label: t(TAB_KEY[k]) }))}
      >
        {/* Sekmeler bir kez açılınca BAĞLI kalır, yalnız gizlenir: sekme değiştirmek taslağı, süren yüklemeyi ve kaydedilmemiş
            düzenlemeleri kaybettirmez. */}
        <KeepTab id="program" tab={tab}><ProgramTab course={c} /></KeepTab>
        <KeepTab id="ogrenciler" tab={tab}><StudentsTab course={c} /></KeepTab>
        <KeepTab id="yoklamalar" tab={tab}><SessionsTab course={c} onStart={() => setStarting(true)} /></KeepTab>
        <KeepTab id="devamsizlik" tab={tab}><AbsenceTab course={c} /></KeepTab>
        <KeepTab id="duyurular" tab={tab}><NoticesTab course={c} /></KeepTab>
        <KeepTab id="disa-aktar" tab={tab}><ExportTab course={c} /></KeepTab>
      </Tabs>

      {editing && <CourseFormDialog open course={c} onClose={() => setEditing(false)} />}
      {starting && <StartSessionDialog open course={c} onClose={() => setStarting(false)} />}
      <ConfirmDialog
        open={confirm === 'archive'}
        onClose={() => setConfirm(null)}
        onConfirm={() => archive.mutate()}
        loading={archive.isPending}
        title={t('ac.course.archiveTitle')}
        message={t('ac.course.archiveText')}
        confirmLabel={t('ac.course.archive')}
      />
      <ConfirmDialog
        open={confirm === 'delete'}
        onClose={() => setConfirm(null)}
        onConfirm={() => remove.mutate()}
        loading={remove.isPending}
        danger
        role="alertdialog"
        title={t('ac.course.deleteTitle', { name: c.name })}
        message={t('ac.course.deleteText')}
        irreversible
        consequence={t('ac.course.deleteConsequence')}
        confirmLabel={t('ac.course.deleteConfirm')}
        initialFocus="cancel"
      />
    </div>
  );
}

/** Sekme içeriği: ilk açılışta bağlanır, sonra gizlenip gösterilir (durum korunur). */
function KeepTab({ id, tab, children }: { id: TabId; tab: TabId; children: ReactNode }) {
  const [seen, setSeen] = useState(id === tab);
  if (tab === id && !seen) setSeen(true);
  if (!seen && tab !== id) return null;
  return <div hidden={tab !== id}>{children}</div>;
}
