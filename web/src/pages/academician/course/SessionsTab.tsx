// SEKME: Yoklamalar. Oturum listesi; her oturumun ayrıntısı (dört durum: Var (QR), Var (elle), Silindi, Yok) bir çekmecede açılır
// ve KAPALI oturumlarda da düzenlenebilir (var say / kaldır / geri yükle). "Kayıtlı değil" listesi burada da karara bağlanır.
// API: GET /academician/courses/{id}/sessions, GET /academician/sessions/{id}, GET /academician/courses/{id}/attendance,
// PUT|DELETE /academician/sessions/{id}/records/{studentId}, POST .../close | reopen.
import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import {
  acadKeys,
  closeSession,
  getAttendance,
  getSession,
  listSessions,
  markPresent,
  removeRecord,
  reopenSession,
  type AcSession,
  type Course,
  type Mark,
  type MatrixStudent,
} from '../../../api/academician';
import { Badge, Button, Card, ConfirmDialog, DataToolbar, Drawer, Icon, ResponsiveTable, Select, useToast, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { MarkBadge, isPresent } from '../components/MarkBadge';
import { PendingScans } from '../components/PendingScans';
import { EmptyBlock, LinkButton, LoadingBlock, QueryError } from '../components/common';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtDate, fmtDateTime } from '../format';
import { acadPaths } from '../paths';
import styles from '../academician.module.css';

export function SessionsTab({ course, onStart }: { course: Course; onStart: () => void }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const navigate = useNavigate();
  const sessions = useQuery({ queryKey: acadKeys.sessions(course.id), queryFn: () => listSessions(course.id), refetchInterval: 30_000 });
  const [detail, setDetail] = useState<AcSession | null>(null);
  const [closing, setClosing] = useState<AcSession | null>(null);

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: acadKeys.sessions(course.id) });
    void qc.invalidateQueries({ queryKey: acadKeys.attendance(course.id) });
  };
  const reopen = useMutation({
    mutationFn: (s: AcSession) => reopenSession(s.id),
    onSuccess: (s) => {
      refresh();
      navigate(acadPaths.live(s.id));
    },
    onError: (e) => toast.error(acadError(i18n, e)),
  });
  const close = useMutation({
    mutationFn: (s: AcSession) => closeSession(s.id),
    onSuccess: () => {
      refresh();
      toast.success(t('ac.session.closed'));
      setClosing(null);
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setClosing(null);
    },
  });

  const columns: Column<AcSession>[] = [
    { key: 'date', header: t('ac.sessions.col.date'), render: (s) => fmtDate(s.lessonDate), card: { priority: 1 } },
    { key: 'opened', header: t('ac.sessions.col.opened'), render: (s) => fmtDateTime(s.openedAt) },
    {
      key: 'status',
      header: t('ac.sessions.col.status'),
      render: (s) => (s.status === 'OPEN' ? <Badge tone="info"><Icon name="activity" size={14} aria-hidden="true" /> {t('ac.session.open')}</Badge> : <Badge><Icon name="lock" size={14} aria-hidden="true" /> {t('ac.session.closedLabel')}</Badge>),
    },
    { key: 'count', header: t('ac.sessions.col.count'), render: (s) => `${s.presentCount} / ${s.enrolledCount}` },
    {
      key: 'act',
      header: <span className="sr-only">{t('ac.col.actions')}</span>,
      align: 'end',
      card: { actions: true },
      render: (s) => (
        <span className={styles.rowActions}>
          {s.status === 'OPEN' ? (
            <>
              <LinkButton to={acadPaths.live(s.id)} size="sm" leftIcon={<Icon name="activity" size={16} />}>{t('ac.session.live')}</LinkButton>
              <Button size="sm" variant="secondary" onClick={() => setClosing(s)}>{t('ac.session.close')}</Button>
            </>
          ) : (
            <Button size="sm" variant="secondary" loading={reopen.isPending && reopen.variables?.id === s.id} onClick={() => reopen.mutate(s)}>{t('ac.session.reopen')}</Button>
          )}
          <Button size="sm" variant="ghost" onClick={() => setDetail(s)}>{t('ac.session.detail')}</Button>
        </span>
      ),
    },
  ];

  return (
    <Card
      title={t('ac.sessions.title')}
      actions={
        <Button size="sm" leftIcon={<Icon name="play" size={16} />} disabled={course.status !== 'ACTIVE'} onClick={onStart}>
          {t('ac.course.startAttendance')}
        </Button>
      }
    >
      {sessions.isLoading ? (
        <LoadingBlock rows={3} height="3rem" />
      ) : sessions.isError ? (
        <QueryError subject={t('ac.sessions.subject')} error={sessions.error} onRetry={() => void sessions.refetch()} />
      ) : (sessions.data ?? []).length === 0 ? (
        <EmptyBlock
          icon="clipboard"
          title={t('ac.sessions.empty.title')}
          description={t('ac.sessions.empty.text')}
          action={<Button leftIcon={<Icon name="play" size={16} />} disabled={course.status !== 'ACTIVE'} onClick={onStart}>{t('ac.course.startAttendance')}</Button>}
        />
      ) : (
        <ResponsiveTable columns={columns} rows={sessions.data ?? []} rowKey={(s) => s.id} caption={t('ac.sessions.caption')} />
      )}

      {detail && <SessionDetail course={course} session={detail} onClose={() => setDetail(null)} />}
      <ConfirmDialog
        open={!!closing}
        onClose={() => setClosing(null)}
        onConfirm={() => closing && close.mutate(closing)}
        loading={close.isPending}
        title={t('ac.session.closeTitle')}
        message={t('ac.session.closeText')}
        consequence={t('ac.session.closeConsequence')}
        confirmLabel={t('ac.session.close')}
      />
    </Card>
  );
}

type Filter = 'ALL' | 'PRESENT' | 'REVOKED' | 'ABSENT';

/** Oturum ayrıntısı: kayıtlı her öğrencinin durumu (matristen) + karar bekleyen "Kayıtlı değil" listesi. */
function SessionDetail({ course, session, onClose }: { course: Course; session: AcSession; onClose: () => void }) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const matrix = useQuery({ queryKey: acadKeys.attendance(course.id), queryFn: () => getAttendance(course.id) });
  const fresh = useQuery({ queryKey: acadKeys.session(session.id), queryFn: () => getSession(session.id) });
  const [filter, setFilter] = useState<Filter>('ALL');
  const [q, setQ] = useState('');
  const [removing, setRemoving] = useState<MatrixStudent | null>(null);

  const markOf = (s: MatrixStudent): Mark => s.marks[String(session.id)] ?? 'ABSENT';
  const refresh = () => {
    void qc.invalidateQueries({ queryKey: acadKeys.attendance(course.id) });
    void qc.invalidateQueries({ queryKey: acadKeys.sessions(course.id) });
    void qc.invalidateQueries({ queryKey: acadKeys.session(session.id) });
    void qc.invalidateQueries({ queryKey: acadKeys.enrollments(course.id) });
  };

  const mark = useMutation({
    mutationFn: (s: MatrixStudent) => markPresent(session.id, s.studentId),
    onSuccess: (_r, s) => {
      toast.success(markOf(s) === 'REVOKED' ? t('ac.detail.restored', { name: s.displayName }) : t('ac.detail.marked', { name: s.displayName }));
      refresh();
    },
    onError: (e) => toast.error(acadError(i18n, e)),
  });
  const unmark = useMutation({
    mutationFn: (s: MatrixStudent) => removeRecord(session.id, s.studentId),
    onSuccess: (_r, s) => {
      toast.success(t('ac.detail.removed', { name: s.displayName }));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setRemoving(null);
    },
  });

  const students = useMemo(() => matrix.data?.students ?? [], [matrix.data]);
  const rows = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase('tr');
    return students
      .filter((s) => {
        const m = s.marks[String(session.id)] ?? 'ABSENT';
        return filter === 'ALL' || (filter === 'PRESENT' ? isPresent(m) : m === filter);
      })
      .filter((s) => !needle || `${s.displayName} ${s.studentNo ?? ''}`.toLocaleLowerCase('tr').includes(needle));
  }, [students, filter, q, session.id]);
  const counts = students.reduce(
    (a, s) => {
      const m = s.marks[String(session.id)] ?? 'ABSENT';
      if (isPresent(m)) a.present++;
      else if (m === 'REVOKED') a.revoked++;
      else a.absent++;
      return a;
    },
    { present: 0, revoked: 0, absent: 0 },
  );

  const columns: Column<MatrixStudent>[] = [
    { key: 'name', header: t('ac.students.col.name'), render: (s) => s.displayName, card: { priority: 1 } },
    { key: 'no', header: t('ac.students.col.no'), render: (s) => <span className="ltr">{s.studentNo ?? '—'}</span> },
    { key: 'state', header: t('ac.detail.col.state'), render: (s) => <MarkBadge mark={markOf(s)} /> },
    {
      key: 'act',
      header: <span className="sr-only">{t('ac.col.actions')}</span>,
      align: 'end',
      card: { actions: true },
      render: (s) => {
        const m = markOf(s);
        const busy = mark.isPending && mark.variables?.studentId === s.studentId;
        return (
          <span className={styles.rowActions}>
            {m === 'REVOKED' ? (
              <Button size="sm" variant="secondary" loading={busy} onClick={() => mark.mutate(s)} aria-label={t('ac.detail.restoreAria', { name: s.displayName })}>{t('ac.detail.restore')}</Button>
            ) : !isPresent(m) ? (
              <Button size="sm" loading={busy} onClick={() => mark.mutate(s)} aria-label={t('ac.detail.markAria', { name: s.displayName })}>{t('ac.detail.mark')}</Button>
            ) : (
              <Button size="sm" variant="dangerOutline" onClick={() => setRemoving(s)} aria-label={t('ac.detail.removeAria', { name: s.displayName })}>{t('ac.detail.remove')}</Button>
            )}
          </span>
        );
      },
    },
  ];

  return (
    <Drawer
      open
      onClose={onClose}
      size="lg"
      title={t('ac.detail.title', { date: fmtDate(session.lessonDate) })}
    >
      <div className={styles.formStack}>
        <p className={styles.muted}>
          {session.status === 'OPEN' ? t('ac.detail.openHint') : t('ac.detail.closedHint')} {t('ac.detail.summary', counts)}
        </p>
        <PendingScans
          sessionId={session.id}
          items={fresh.data?.pendingScans ?? []}
          onChanged={refresh}
        />
        <DataToolbar
          onSearch={setQ}
          searchPlaceholder={t('ac.students.search')}
          filters={
            <Select aria-label={t('ac.detail.filter')} value={filter} onChange={(e) => setFilter(e.target.value as Filter)}>
              <option value="ALL">{t('ac.detail.filter.ALL')}</option>
              <option value="PRESENT">{t('ac.detail.filter.PRESENT')}</option>
              <option value="REVOKED">{t('ac.detail.filter.REVOKED')}</option>
              <option value="ABSENT">{t('ac.detail.filter.ABSENT')}</option>
            </Select>
          }
        />
        {matrix.isError ? (
          <QueryError subject={t('ac.detail.subject')} error={matrix.error} onRetry={() => void matrix.refetch()} />
        ) : !matrix.isLoading && students.length === 0 ? (
          <EmptyBlock icon="users" title={t('ac.students.empty.title')} description={t('ac.students.empty.text')} action={<LinkButton to={acadPaths.enroll(course.id)}>{t('ac.students.add')}</LinkButton>} />
        ) : (
          <ResponsiveTable
            columns={columns}
            rows={rows}
            rowKey={(s) => s.studentId}
            loading={matrix.isLoading}
            caption={t('ac.detail.caption')}
            empty={<EmptyBlock icon="search" title={t('ac.noResults.title')} description={t('ac.noResults.text')} action={<Button variant="secondary" onClick={() => { setQ(''); setFilter('ALL'); }}>{t('ac.noResults.clear')}</Button>} />}
          />
        )}
      </div>
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && unmark.mutate(removing)}
        loading={unmark.isPending}
        danger
        role="alertdialog"
        title={t('ac.detail.removeTitle', { name: removing?.displayName ?? '' })}
        message={t('ac.detail.removeText')}
        consequence={t('ac.detail.removeConsequence')}
        confirmLabel={t('ac.detail.remove')}
        initialFocus="cancel"
      />
    </Drawer>
  );
}
