// SAYFA: Akademisyen paneli ana sayfası (/akademisyen). Bugünün dersleri (haftalık programdan) + "Yoklama başlat", açık
// oturumlar, devamsızlık riski olan öğrenci sayıları, son duyurular. API: GET /academician/courses, ardından her aktif ders için
// sessions, attendance ve notices (en çok 12 ders; sonuncular ayrı ayrı yüklenir, biri hata verirse diğerleri görünür).
import { useMemo, useState } from 'react';
import { useQueries, useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { acadKeys, getAttendance, listCourses, listNotices, listSessions, type Course, type Slot } from '../../api/academician';
import { Badge, Button, Card, Icon, PageHeader, StatTile } from '../../components/ui';
import { usePageTitle } from '../../lib/hooks';
import { useAcadAuth } from './auth/AcadAuth';
import { EmptyBlock, LinkButton, LoadingBlock, QueryError, StartSessionDialog, courseTitle } from './components/common';
import { useT } from './dict';
import { fmtDateTime, isoDay, todayLocal, toMinutes } from './format';
import { acadPaths } from './paths';
import styles from './academician.module.css';

const MAX_FANOUT = 12;

interface Lesson {
  course: Course;
  slot: Slot;
}

export default function DashboardPage() {
  const t = useT();
  const { me } = useAcadAuth();
  usePageTitle(t('ac.dash.title'));
  const courses = useQuery({ queryKey: acadKeys.courses(), queryFn: listCourses });
  const [start, setStart] = useState<Lesson | null>(null);

  const allActive = useMemo(() => (courses.data ?? []).filter((c) => c.status === 'ACTIVE'), [courses.data]);
  const active = useMemo(() => allActive.slice(0, MAX_FANOUT), [allActive]);
  const sessions = useQueries({ queries: active.map((c) => ({ queryKey: acadKeys.sessions(c.id), queryFn: () => listSessions(c.id), refetchInterval: 60_000 })) });
  const matrices = useQueries({ queries: active.map((c) => ({ queryKey: acadKeys.attendance(c.id), queryFn: () => getAttendance(c.id) })) });
  const notices = useQueries({ queries: active.map((c) => ({ queryKey: [...acadKeys.notices(c.id), 'recent'], queryFn: () => listNotices(c.id, null, 3) })) });

  const today = isoDay(new Date());
  const lessons: Lesson[] = useMemo(
    () =>
      active
        .flatMap((course) => course.slots.filter((s) => s.dayOfWeek === today).map((slot) => ({ course, slot })))
        .sort((a, b) => toMinutes(a.slot.startTime) - toMinutes(b.slot.startTime)),
    [active, today],
  );

  const openSessions = active.flatMap((c, i) => (sessions[i]?.data ?? []).filter((s) => s.status === 'OPEN').map((s) => ({ course: c, session: s })));
  const dateToday = todayLocal();

  let atRisk = 0;
  let overLimit = 0;
  const riskByCourse: { course: Course; atRisk: number; overLimit: number }[] = [];
  active.forEach((c, i) => {
    const m = matrices[i]?.data;
    if (!m) return;
    const r = m.students.filter((s) => s.atRisk && !s.overLimit).length;
    const o = m.students.filter((s) => s.overLimit).length;
    atRisk += r;
    overLimit += o;
    if (r + o > 0) riskByCourse.push({ course: c, atRisk: r, overLimit: o });
  });
  const matricesLoading = matrices.some((q) => q.isLoading);

  const recent = active
    .flatMap((c, i) => (notices[i]?.data?.items ?? []).map((n) => ({ course: c, notice: n })))
    .sort((a, b) => b.notice.createdAt.localeCompare(a.notice.createdAt))
    .slice(0, 5);

  const greeting = [me?.title, me?.lastName].filter(Boolean).join(' ');

  return (
    <div className={styles.page}>
      <PageHeader
        title={greeting ? t('ac.dash.hello', { name: greeting }) : t('ac.dash.title')}
        description={t('ac.dash.desc')}
        actions={<LinkButton to={acadPaths.courses} variant="secondary" leftIcon={<Icon name="graduation" size={18} />}>{t('ac.nav.courses')}</LinkButton>}
      />

      {courses.isLoading ? (
        <LoadingBlock rows={3} height="7rem" />
      ) : courses.isError ? (
        <QueryError subject={t('ac.courses.subject')} error={courses.error} onRetry={() => void courses.refetch()} />
      ) : (courses.data ?? []).length === 0 ? (
        <EmptyBlock
          icon="graduation"
          title={t('ac.dash.noCourses.title')}
          description={t('ac.dash.noCourses.text')}
          action={<LinkButton to={`${acadPaths.courses}?yeni=1`} leftIcon={<Icon name="plus" size={18} />}>{t('ac.courses.new')}</LinkButton>}
        />
      ) : (
        <>
          {allActive.length > MAX_FANOUT && (
            <div className={styles.warnBox} role="note">
              <Icon name="info" size={18} />
              <span>
                {t('ac.dash.truncated', { n: MAX_FANOUT, total: allActive.length })} <Link to={acadPaths.courses}>{t('ac.dash.truncatedLink')}</Link>
              </span>
            </div>
          )}
          <div className={styles.tiles}>
            <StatTile label={t('ac.dash.tile.today')} value={lessons.length} icon="calendar" />
            <StatTile label={t('ac.dash.tile.open')} value={openSessions.length} icon="activity" />
            <StatTile label={t('ac.dash.tile.atRisk')} value={matricesLoading ? null : atRisk} icon="alert" loading={matricesLoading} caption={t('ac.dash.tile.atRiskHint')} />
            <StatTile label={t('ac.dash.tile.over')} value={matricesLoading ? null : overLimit} icon="ban" loading={matricesLoading} caption={t('ac.dash.tile.overHint')} />
          </div>

          <div className={styles.split}>
            <Card title={t('ac.dash.lessons')}>
              {lessons.length === 0 ? (
                <p className={styles.muted}>{t('ac.dash.noLessons')}</p>
              ) : (
                <ul className={styles.rows}>
                  {lessons.map(({ course, slot }) => {
                    const idx = active.findIndex((c) => c.id === course.id);
                    const running = (sessions[idx]?.data ?? []).find((s) => s.status === 'OPEN' && s.lessonDate === dateToday);
                    return (
                      <li key={`${course.id}-${slot.id}`} className={styles.row}>
                        <div className={styles.rowMain}>
                          <Link to={acadPaths.course(course.id)} className={styles.rowTitle}>
                            {courseTitle(course)}
                          </Link>
                          <span className={styles.muted}>
                            {slot.startTime}–{slot.endTime}
                            {slot.room ? ` · ${slot.room}` : ''}
                          </span>
                        </div>
                        {running ? (
                          <LinkButton to={acadPaths.live(running.id)} variant="secondary" size="sm" leftIcon={<Icon name="activity" size={16} />}>
                            {t('ac.dash.goLive')}
                          </LinkButton>
                        ) : (
                          <Button size="sm" leftIcon={<Icon name="play" size={16} />} onClick={() => setStart({ course, slot })}>
                            {t('ac.dash.startAttendance')}
                          </Button>
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}
            </Card>

            <Card title={t('ac.dash.openSessions')}>
              {openSessions.length === 0 ? (
                <p className={styles.muted}>{t('ac.dash.noOpen')}</p>
              ) : (
                <ul className={styles.rows}>
                  {openSessions.map(({ course, session }) => (
                    <li key={session.id} className={styles.row}>
                      <div className={styles.rowMain}>
                        <span className={styles.rowTitle}>{courseTitle(course)}</span>
                        <span className={styles.muted}>
                          {t('ac.dash.presentOf', { present: session.presentCount, total: session.enrolledCount })}
                          {(session.pendingCount ?? 0) > 0 ? ` · ${t('ac.dash.pendingN', { n: session.pendingCount ?? 0 })}` : ''}
                        </span>
                      </div>
                      <LinkButton to={acadPaths.live(session.id)} size="sm" leftIcon={<Icon name="activity" size={16} />}>
                        {t('ac.dash.goLive')}
                      </LinkButton>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>

          <div className={styles.split}>
            <Card title={t('ac.dash.risk')}>
              {matricesLoading ? (
                <LoadingBlock rows={2} height="2.5rem" />
              ) : riskByCourse.length === 0 ? (
                <p className={styles.muted}>{t('ac.dash.noRisk')}</p>
              ) : (
                <ul className={styles.rows}>
                  {riskByCourse.map(({ course, atRisk: r, overLimit: o }) => (
                    <li key={course.id} className={styles.row}>
                      <Link to={acadPaths.course(course.id, 'devamsizlik')} className={styles.rowTitle}>
                        {courseTitle(course)}
                      </Link>
                      <span className={styles.chips}>
                        {o > 0 && (
                          <Badge tone="danger">
                            <Icon name="ban" size={14} /> {t('ac.dash.overN', { n: o })}
                          </Badge>
                        )}
                        {r > 0 && (
                          <Badge tone="warning">
                            <Icon name="alert" size={14} /> {t('ac.dash.atRiskN', { n: r })}
                          </Badge>
                        )}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </Card>

            <Card title={t('ac.dash.notices')}>
              {recent.length === 0 ? (
                <p className={styles.muted}>{t('ac.dash.noNotices')}</p>
              ) : (
                <ul className={styles.rows}>
                  {recent.map(({ course, notice }) => (
                    <li key={notice.id} className={styles.row}>
                      <div className={styles.rowMain}>
                        <Link to={acadPaths.course(course.id, 'duyurular')} className={styles.rowTitle}>
                          {t(`ac.notice.type.${notice.type}`)}
                          {notice.title ? ` · ${notice.title}` : ''}
                        </Link>
                        <span className={styles.muted}>
                          {course.name} · {fmtDateTime(notice.createdAt)}
                        </span>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>
        </>
      )}

      {start && <StartSessionDialog open course={start.course} slotId={start.slot.id} onClose={() => setStart(null)} />}
    </div>
  );
}
