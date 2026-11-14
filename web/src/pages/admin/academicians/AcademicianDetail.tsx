// SAYFA: Akademisyen ayrıntısı (/admin/academicians/:id) - profil, karar geçmişi ve dersler (salt okunur)
// API: GET /api/admin/academicians/{userId}, .../{userId}/courses (api/adminAcademicians.ts); denetim geçmişi: GET /api/admin/audit.
import { useQuery } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { acadKeys, getAcademician, listAcademicianCourses } from '../../../api/adminAcademicians';
import { isApiError } from '../../../api/client';
import { AuditTrail } from '../../../components/admin/guard';
import { ButtonLink, Card, EmptyState, ErrorState, PageHeader, Skeleton, StatusPill, Badge } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { SearchAnchor } from '../../../search/anchor';
import { AcademicianActions } from './AcademicianActions';
import { CoursePanel, limitText } from './CoursePanel';
import { ga } from './dict';
import { ReviewerCell, statusTone } from './AcademiciansList';
import { nameOf } from './logic';
import styles from './acad.module.css';

export default function AcademicianDetail() {
  const i18n = useI18n();
  const { formatDateTime, formatNumber } = i18n;
  const x = ga(i18n);
  const { id } = useParams();
  const userId = Number(id);
  const valid = Number.isInteger(userId) && userId > 0;
  const [params, setParams] = useSearchParams();
  const selectedId = Number(params.get('course')) || null;

  const q = useQuery({ queryKey: acadKeys.detail(userId), queryFn: () => getAcademician(userId), enabled: valid });
  const coursesQ = useQuery({
    queryKey: acadKeys.courses(userId),
    queryFn: () => listAcademicianCourses(userId),
    enabled: valid && q.isSuccess,
  });
  const a = q.data;
  const name = a ? nameOf(a) || x('admin.acad.noName') : x('admin.acad.detail.title');
  usePageTitle(name);

  const crumbs = [{ label: x('admin.acad.title'), to: paths.admin.academicians }, { label: name }];

  if (!valid || q.isError) {
    const notFound = !valid || (isApiError(q.error) && q.error.status === 404);
    return (
      <div>
        <PageHeader title={x('admin.acad.detail.title')} breadcrumbs={crumbs} />
        {notFound ? (
          <EmptyState
            icon="graduation"
            headingLevel={2}
            title={x('admin.acad.detail.notFound')}
            description={x('admin.acad.detail.notFoundHint')}
            action={<ButtonLink to={paths.admin.academicians}>{x('admin.acad.detail.back')}</ButtonLink>}
          />
        ) : (
          <ErrorState description={adminError(i18n, q.error)} onRetry={() => void q.refetch()} />
        )}
      </div>
    );
  }

  if (!a) {
    return (
      <div aria-busy="true">
        <PageHeader title={x('admin.acad.detail.title')} breadcrumbs={crumbs} />
        <Card>
          <Skeleton width="40%" height="1.6em" />
          <Skeleton width="80%" />
          <Skeleton width="60%" />
        </Card>
      </div>
    );
  }

  const courses = coursesQ.data ?? [];
  const selected = courses.find((c) => c.id === selectedId) ?? null;
  const row = (label: string, value: ReactNode) => (
    <div className={styles.dlRow}>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );

  return (
    <div>
      <PageHeader title={<span dir="auto">{name}</span>} breadcrumbs={crumbs} />
      <div className={styles.grid}>
        <SearchAnchor id="acad-profile">
          <Card title={x('admin.acad.profile.title')}>
            <dl className={styles.dl}>
              {row(x('admin.acad.profile.name'), <span dir="auto">{name}</span>)}
              {row(x('admin.acad.profile.titleField'), a.title || '-')}
              {row(x('admin.acad.profile.unit'), a.unit || x('admin.acad.noUnit'))}
              {/* Sunucunun döndürdüğü gibi (maskeli olabilir) */}
              {row(x('admin.acad.profile.email'), <span className={`${styles.email} ltr`}>{a.email ?? x('admin.acad.noEmail')}</span>)}
              {row(
                x('admin.acad.profile.account'),
                <Link to={paths.admin.user(a.userId)}>{x('admin.acad.profile.openAccount', { id: a.userId })}</Link>,
              )}
              {row(x('admin.acad.profile.applied'), formatDateTime(a.createdAt))}
              {row(
                x('admin.acad.profile.decision'),
                <span className={styles.chips}>
                  <StatusPill tone={statusTone(a.status)}>{x(`admin.acad.status.${a.status}`)}</StatusPill>
                  {a.approvalMode && <Badge>{x(`admin.acad.mode.${a.approvalMode}`)}</Badge>}
                </span>,
              )}
              {a.status === 'PENDING' ? (
                row(x('admin.acad.profile.decidedBy'), x('admin.acad.profile.noDecision'))
              ) : (
                <>
                  {row(x('admin.acad.profile.decidedBy'), <ReviewerCell a={a} />)}
                  {row(x('admin.acad.profile.decidedAt'), a.reviewedAt ? formatDateTime(a.reviewedAt) : '-')}
                  {a.rejectReason && row(x('admin.acad.profile.reason'), a.rejectReason)}
                </>
              )}
            </dl>
            <div className={styles.headActions}>
              <AcademicianActions a={a} size="md" />
            </div>
          </Card>
        </SearchAnchor>
        <SearchAnchor id="acad-history">
          <Card title={x('admin.acad.history.title')}>
            <AuditTrail targetType="ACADEMICIAN" targetId={a.userId} />
          </Card>
        </SearchAnchor>
      </div>

      <SearchAnchor id="acad-courses" className={styles.section}>
        <Card title={x('admin.acad.courses.title')}>
          <p className={styles.hint}>{x('admin.acad.courses.readOnly')}</p>
          {coursesQ.isError ? (
            <ErrorState
              title={x('admin.acad.courses.error')}
              description={adminError(i18n, coursesQ.error)}
              onRetry={() => void coursesQ.refetch()}
            />
          ) : coursesQ.isLoading ? (
            <div aria-busy="true">
              <Skeleton width="60%" height="1.4em" />
              <Skeleton width="80%" />
            </div>
          ) : courses.length === 0 ? (
            <EmptyState compact icon="graduation" title={x('admin.acad.courses.empty.title')} description={x('admin.acad.courses.empty.hint')} />
          ) : (
            <>
              <ul className={styles.courseList}>
                {courses.map((c) => (
                  <li key={c.id}>
                    <button
                      type="button"
                      className={styles.courseBtn}
                      aria-pressed={c.id === selected?.id}
                      aria-label={x('admin.acad.course.select', { name: c.name })}
                      onClick={() => {
                        const next = new URLSearchParams(params);
                        next.set('course', String(c.id));
                        next.delete('ctab'); // yeni derste ilk sekme
                        setParams(next, { replace: true });
                      }}
                    >
                      <span className={styles.courseName}>
                        {c.code ? `${c.code} - ` : ''}
                        {c.name}
                      </span>
                      <span className={styles.sub}>
                        {c.term} | {c.department}
                        {c.grade ? ` | ${c.grade}` : ''}
                      </span>
                      <span className={styles.chips}>
                        <Badge>{x(`admin.acad.course.status.${c.status}`)}</Badge>
                        {c.enrolledCount != null && <Badge>{x('admin.acad.course.students', { n: formatNumber(c.enrolledCount) })}</Badge>}
                        {c.sessionCount != null && <Badge>{x('admin.acad.course.sessions', { n: formatNumber(c.sessionCount) })}</Badge>}
                        <Badge>{limitText(c, x)}</Badge>
                        {c.plannedSessions != null && <Badge>{x('admin.acad.course.planned', { n: c.plannedSessions })}</Badge>}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
              {selected ? <CoursePanel key={selected.id} course={selected} /> : <p className={styles.hint}>{x('admin.acad.courses.pick')}</p>}
            </>
          )}
        </Card>
      </SearchAnchor>
    </div>
  );
}
