// Seçili dersin salt okunur görünümleri: haftalık program, öğrenciler, yoklama matrisi, duyurular (ekli dosya indirme), oturumlar.
// Yönetici uçlarında ayrı öğrenci/oturum listesi yoktur: ikisi de yoklama matrisinden türetilir (GET .../courses/{id}/attendance).
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import {
  acadKeys,
  downloadNoticeFile,
  getCourseAttendance,
  listCourseNotices,
  type AcademicianCourse,
  type AttendanceMark,
  type AttendanceMatrix,
  type CourseNotice,
  type NoticeFile,
} from '../../../api/adminAcademicians';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  Icon,
  LoadMore,
  Skeleton,
  StatusPill,
  Table,
  Tabs,
  useToast,
  type Column,
  type IconName,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { downloadBlob } from '../users/filters';
import { ga, type GA } from './dict';
import { ACAD_MARKS, formatBytes, hhmm, limitStatus, sessionSummary } from './logic';
import styles from './acad.module.css';

type CourseTab = 'slots' | 'students' | 'attendance' | 'notices' | 'sessions';
const COURSE_TABS: CourseTab[] = ['slots', 'students', 'attendance', 'notices', 'sessions'];

const MARK_ICON: Record<AttendanceMark, IconName> = {
  PRESENT_QR: 'check',
  PRESENT_MANUAL: 'pencil',
  REVOKED: 'ban',
  ABSENT: 'x',
};

/** Yoklama durumu: simge + metin + çizgi biçimi (renk tek başına anlam taşımaz). */
export function MarkChip({ mark, x }: { mark: AttendanceMark; x: GA }) {
  return (
    <span className={`${styles.mark} ${styles[`mark${mark}`] ?? ''}`}>
      <Icon name={MARK_ICON[mark]} size={14} />
      {x(`admin.acad.att.mark.${mark}`)}
    </span>
  );
}

export function limitText(course: Pick<AcademicianCourse, 'limit'>, x: GA): string {
  const l = course.limit;
  if (!l || l.value == null) return x('admin.acad.course.limit.none');
  return x(`admin.acad.course.limit.${l.type}`, { n: l.value });
}

function useMatrix(courseId: number) {
  return useQuery({ queryKey: acadKeys.attendance(courseId), queryFn: () => getCourseAttendance(courseId) });
}

function Loading() {
  return (
    <div aria-busy="true">
      <Skeleton width="50%" height="1.4em" />
      <Skeleton width="90%" />
      <Skeleton width="70%" />
    </div>
  );
}

function SlotsView({ course }: { course: AcademicianCourse }) {
  const x = ga(useI18n());
  if (course.slots.length === 0) {
    return <EmptyState compact icon="calendar" title={x('admin.acad.slots.empty.title')} description={x('admin.acad.slots.empty.hint')} />;
  }
  const columns: Column<AcademicianCourse['slots'][number]>[] = [
    { key: 'day', header: x('admin.acad.slots.day'), render: (s) => x(`admin.acad.day.${s.dayOfWeek}`) },
    { key: 'time', header: x('admin.acad.slots.time'), render: (s) => `${hhmm(s.startTime)} - ${hhmm(s.endTime)}` },
    { key: 'room', header: x('admin.acad.slots.room'), render: (s) => s.room || '-' },
  ];
  return <Table caption={x('admin.acad.course.tab.slots')} columns={columns} rows={course.slots} rowKey={(s) => s.id} />;
}

function QueryGate({
  q,
  errorKey,
  children,
}: {
  q: { isLoading: boolean; isError: boolean; error: unknown; refetch: () => unknown };
  errorKey: string;
  children: ReactNode;
}) {
  const i18n = useI18n();
  const x = ga(i18n);
  if (q.isLoading) return <Loading />;
  if (q.isError) {
    return <ErrorState title={x(errorKey)} description={adminError(i18n, q.error)} onRetry={() => void q.refetch()} />;
  }
  return <>{children}</>;
}

function StatusOf({ m, s, x }: { m: AttendanceMatrix; s: AttendanceMatrix['students'][number]; x: GA }) {
  const st = limitStatus(m.limit, s);
  const tone = st === 'over' ? 'danger' : st === 'atRisk' ? 'warning' : st === 'ok' ? 'success' : 'neutral';
  return <StatusPill tone={tone}>{x(`admin.acad.limitStatus.${st}`)}</StatusPill>;
}

function StudentsView({ courseId }: { courseId: number }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const q = useMatrix(courseId);
  const m = q.data;
  return (
    <QueryGate q={q} errorKey="admin.acad.att.error">
      {m && m.students.length === 0 ? (
        <EmptyState compact icon="users" title={x('admin.acad.students.empty.title')} description={x('admin.acad.students.empty.hint')} />
      ) : (
        m && (
          <Table
            caption={x('admin.acad.course.tab.students')}
            rowKey={(s) => s.studentId}
            rows={m.students}
            columns={[
              {
                key: 'name',
                header: x('admin.acad.students.name'),
                render: (s) => s.displayName || x('admin.acad.noStudentName'),
              },
              { key: 'no', header: x('admin.acad.students.no'), render: (s) => <span className="ltr">{s.studentNo ?? '-'}</span> },
              { key: 'absent', header: x('admin.acad.students.absent'), align: 'end', render: (s) => i18n.formatNumber(s.absentCount) },
              { key: 'limit', header: x('admin.acad.students.limitStatus'), render: (s) => <StatusOf m={m} s={s} x={x} /> },
            ]}
          />
        )
      )}
    </QueryGate>
  );
}

function AttendanceView({ courseId }: { courseId: number }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const q = useMatrix(courseId);
  const m = q.data;
  return (
    <QueryGate q={q} errorKey="admin.acad.att.error">
      {m && (m.sessions.length === 0 || m.students.length === 0) ? (
        <EmptyState
          compact
          icon="clipboard"
          title={m.students.length === 0 ? x('admin.acad.students.empty.title') : x('admin.acad.att.empty.title')}
          description={m.students.length === 0 ? x('admin.acad.students.empty.hint') : x('admin.acad.att.empty.hint')}
        />
      ) : (
        m && (
          <>
            <ul className={styles.legend} aria-label={x('admin.acad.att.legendTitle')}>
              {ACAD_MARKS.map((k) => (
                <li key={k}>
                  <MarkChip mark={k} x={x} />
                  <span>{x(`admin.acad.att.markDesc.${k}`)}</span>
                </li>
              ))}
            </ul>
            <Table
              caption={x('admin.acad.att.matrix')}
              rowKey={(s) => s.studentId}
              rows={m.students}
              columns={[
                {
                  key: 'name',
                  header: x('admin.acad.students.name'),
                  render: (s) => (
                    <span className={styles.person}>
                      <span>{s.displayName || x('admin.acad.noStudentName')}</span>
                      <span className={`${styles.sub} ltr`}>{s.studentNo ?? ''}</span>
                    </span>
                  ),
                },
                ...m.sessions.map(
                  (sess): Column<AttendanceMatrix['students'][number]> => ({
                    key: `s${sess.id}`,
                    header: <span className={styles.dateHead}>{i18n.formatDate(sess.lessonDate)}</span>,
                    headerLabel: i18n.formatDate(sess.lessonDate),
                    render: (s) => <MarkChip mark={s.marks[String(sess.id)] ?? 'ABSENT'} x={x} />,
                  }),
                ),
                { key: 'absent', header: x('admin.acad.students.absent'), align: 'end', render: (s) => i18n.formatNumber(s.absentCount) },
                { key: 'limit', header: x('admin.acad.students.limitStatus'), render: (s) => <StatusOf m={m} s={s} x={x} /> },
              ]}
            />
          </>
        )
      )}
    </QueryGate>
  );
}

function SessionsView({ courseId }: { courseId: number }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const q = useMatrix(courseId);
  const m = q.data;
  return (
    <QueryGate q={q} errorKey="admin.acad.att.error">
      {m && m.sessions.length === 0 ? (
        <EmptyState compact icon="clipboard" title={x('admin.acad.sessions.empty.title')} description={x('admin.acad.sessions.empty.hint')} />
      ) : (
        m && (
          <Table
            caption={x('admin.acad.course.tab.sessions')}
            rowKey={(s) => s.id}
            rows={m.sessions}
            columns={[
              { key: 'date', header: x('admin.acad.sessions.date'), render: (s) => i18n.formatDate(s.lessonDate) },
              { key: 'present', header: x('admin.acad.sessions.present'), align: 'end', render: (s) => i18n.formatNumber(sessionSummary(s.id, m.students).present) },
              { key: 'revoked', header: x('admin.acad.sessions.revoked'), align: 'end', render: (s) => i18n.formatNumber(sessionSummary(s.id, m.students).revoked) },
              { key: 'absent', header: x('admin.acad.sessions.absent'), align: 'end', render: (s) => i18n.formatNumber(sessionSummary(s.id, m.students).absent) },
              { key: 'total', header: x('admin.acad.sessions.total'), align: 'end', render: (s) => i18n.formatNumber(sessionSummary(s.id, m.students).total) },
            ]}
          />
        )
      )}
    </QueryGate>
  );
}

function FileButton({ notice, file, x }: { notice: CourseNotice; file: NoticeFile; x: GA }) {
  const i18n = useI18n();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const size = formatBytes(file.sizeBytes);
  async function download() {
    setBusy(true);
    try {
      downloadBlob(await downloadNoticeFile(notice.id, file.id), file.name);
    } catch (e) {
      toast.error(`${x('admin.acad.notices.downloadError')}: ${adminError(i18n, e)}`);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Button
      size="sm"
      variant="secondary"
      loading={busy}
      leftIcon={<Icon name="download" size={16} />}
      aria-label={x('admin.acad.notices.downloadFile', { name: file.name })}
      onClick={() => void download()}
    >
      {file.name} ({x(size.key, { n: size.n })})
    </Button>
  );
}

function NoticesView({ courseId }: { courseId: number }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const q = useInfiniteQuery({
    queryKey: [...acadKeys.notices(courseId), 'pages'],
    queryFn: ({ pageParam }) => listCourseNotices(courseId, { cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = q.data?.pages.flatMap((p) => p.items) ?? [];
  return (
    <QueryGate q={q} errorKey="admin.acad.notices.error">
      {items.length === 0 ? (
        <EmptyState compact icon="megaphone" title={x('admin.acad.notices.empty.title')} description={x('admin.acad.notices.empty.hint')} />
      ) : (
        <>
          <p className={styles.hint}>{x('admin.acad.notices.downloadNote')}</p>
          <ul className={styles.noticeList}>
            {items.map((n) => (
              <li key={n.id} className={styles.notice}>
                <div className={styles.noticeHead}>
                  <Badge>{x(`admin.acad.notice.type.${n.type}`)}</Badge>
                  {n.title && <span className={styles.noticeTitle}>{n.title}</span>}
                  <span className={styles.sub}>
                    {x('admin.acad.notices.sentAt')}: {i18n.formatDateTime(n.createdAt)}
                  </span>
                  {n.eventAt && (
                    <span className={styles.sub}>
                      {x('admin.acad.notices.eventAt')}: {i18n.formatDateTime(n.eventAt)}
                    </span>
                  )}
                </div>
                {n.note && <p className={styles.noticeNote}>{n.note}</p>}
                {n.files.length > 0 && (
                  <ul className={styles.files} aria-label={x('admin.acad.notices.files')}>
                    {n.files.map((f) => (
                      <li key={f.id}>
                        <FileButton notice={n} file={f} x={x} />
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ul>
          <LoadMore hasMore={!!q.hasNextPage} loading={q.isFetchingNextPage} onLoadMore={() => void q.fetchNextPage()} />
        </>
      )}
    </QueryGate>
  );
}

export function CoursePanel({ course }: { course: AcademicianCourse }) {
  const i18n = useI18n();
  const x = ga(i18n);
  const [tab, setTab] = useState<CourseTab>('slots');
  const tabs = COURSE_TABS.map((id) => ({ id, label: x(`admin.acad.course.tab.${id}`) }));
  return (
    <section aria-label={course.name}>
      <div className={styles.panelHead}>
        <h3 className={styles.sectionTitle}>
          {course.code ? `${course.code} - ` : ''}
          {course.name}
        </h3>
        <div className={styles.chips}>
          <Badge>{course.term}</Badge>
          <Badge>{limitText(course, x)}</Badge>
        </div>
      </div>
      <Tabs tabs={tabs} value={tab} onChange={(id) => setTab(id as CourseTab)} label={x('admin.acad.course.tabs')} />
      <div className={styles.panelBody}>
        {tab === 'slots' && <SlotsView course={course} />}
        {tab === 'students' && <StudentsView courseId={course.id} />}
        {tab === 'attendance' && <AttendanceView courseId={course.id} />}
        {tab === 'notices' && <NoticesView courseId={course.id} />}
        {tab === 'sessions' && <SessionsView courseId={course.id} />}
      </div>
    </section>
  );
}
