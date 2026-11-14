// SAYFA: Canlı yoklama (/akademisyen/yoklama/:sessionId) — özelliğin kalbi. 5 sn'de bir değişen büyük QR (sunucu saatine göre seçilir),
// katılan/kayıtlı sayaçları, canlı öğrenci listesi (yeniler üstte; QR/elle ayrımı; kaldırma/geri alma yansır), "Kayıtlı değil" listesi,
// elle "var say" araması, kapat/yeniden aç, projeksiyon kipi. Yoklama mantığı: useLiveSession (+ liveCode.ts); bu sayfa grubu `qrcode-generator`ı
// çeker (başka hiçbir parça içe aktarmaz).
// API: GET /academician/sessions/{id}, /live; POST .../close | reopen; PUT|DELETE .../records/{studentId}; .../pending/{studentId}/accept|dismiss.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Navigate, useParams } from 'react-router-dom';
import {
  acadKeys,
  closeSession,
  getCourse,
  getSession,
  listEnrollments,
  markPresent,
  removeRecord,
  reopenSession,
  type AttendanceRecord,
  type LiveCode,
} from '../../../api/academician';
import { Badge, Button, Card, ConfirmDialog, EmptyState, FormField, Icon, IconButton, Input, ProgressBar, useToast } from '../../../components/ui';
import { useFocusTrap } from '../../../components/ui/Overlay';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { PendingScans } from '../components/PendingScans';
import { LinkButton, courseTitle } from '../components/common';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtDate, fmtTime } from '../format';
import { acadPaths } from '../paths';
import styles from './live.module.css';
import { QrPanel } from './QrPanel';
import { qrState } from './liveCode';
import { useLiveSession } from './useLiveSession';

const ANNOUNCE_EVERY_MS = 6000;

/** Ekran okuyucu duyurusu: katılımlar toplanır, en sık 6 sn'de bir tek cümle okunur (kalabalık derste sel olmasın). */
export function useThrottledAnnouncer(format: (names: string[]) => string, everyMs = ANNOUNCE_EVERY_MS) {
  const [message, setMessage] = useState('');
  const queue = useRef<string[]>([]);
  const lastAt = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout>>();
  const fmt = useRef(format);
  fmt.current = format;

  const flush = useCallback(() => {
    timer.current = undefined;
    if (queue.current.length === 0) return;
    const names = queue.current;
    queue.current = [];
    lastAt.current = Date.now();
    setMessage(fmt.current(names));
  }, []);

  const push = useCallback(
    (name: string) => {
      queue.current.push(name);
      if (timer.current) return;
      const wait = Math.max(0, lastAt.current + everyMs - Date.now());
      timer.current = setTimeout(flush, wait);
    },
    [flush, everyMs],
  );

  useEffect(() => () => clearTimeout(timer.current), []);
  return { message, push };
}

export default function LivePage() {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const qc = useQueryClient();
  const { sessionId: raw } = useParams();
  const sessionId = Number(raw);
  const [projector, setProjector] = useState(false);
  const [closing, setClosing] = useState(false);
  const [removing, setRemoving] = useState<AttendanceRecord | null>(null);
  const [search, setSearch] = useState('');

  const announcer = useThrottledAnnouncer((names) => (names.length === 1 ? t('ac.live.announceOne', { name: names[0] }) : t('ac.live.announceMany', { n: names.length })));
  const live = useLiveSession(sessionId, (r) => announcer.push(r.displayName ?? t('ac.live.someone')));

  const session = useQuery({ queryKey: acadKeys.session(sessionId), queryFn: () => getSession(sessionId), enabled: Number.isFinite(sessionId), staleTime: 60_000 });
  const courseId = session.data?.courseId;
  const course = useQuery({ queryKey: acadKeys.course(courseId ?? 0), queryFn: () => getCourse(courseId!), enabled: !!courseId });
  const enrolled = useQuery({ queryKey: acadKeys.enrollments(courseId ?? 0), queryFn: () => listEnrollments(courseId!), enabled: !!courseId });
  usePageTitle(course.data ? t('ac.live.pageTitle', { course: course.data.name }) : t('ac.live.title'));

  const afterChange = useCallback(() => {
    live.refresh();
    if (courseId) {
      void qc.invalidateQueries({ queryKey: acadKeys.enrollments(courseId) });
      void qc.invalidateQueries({ queryKey: acadKeys.course(courseId) });
      void qc.invalidateQueries({ queryKey: acadKeys.attendance(courseId) });
      void qc.invalidateQueries({ queryKey: acadKeys.sessions(courseId) });
    }
  }, [live, qc, courseId]);

  const close = useMutation({
    mutationFn: () => closeSession(sessionId),
    onSuccess: () => {
      toast.success(t('ac.session.closed'));
      setClosing(false);
      afterChange();
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setClosing(false);
    },
  });
  const reopen = useMutation({
    mutationFn: () => reopenSession(sessionId),
    onSuccess: () => {
      toast.success(t('ac.live.reopened'));
      afterChange();
    },
    onError: (e) => toast.error(acadError(i18n, e)),
  });
  const mark = useMutation({
    mutationFn: (studentId: number) => markPresent(sessionId, studentId),
    onSuccess: () => {
      setSearch('');
      afterChange();
    },
    onError: (e) => toast.error(acadError(i18n, e)),
  });
  const unmark = useMutation({
    mutationFn: (r: AttendanceRecord) => removeRecord(sessionId, r.studentId),
    onSuccess: () => {
      setRemoving(null);
      afterChange();
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setRemoving(null);
    },
  });

  // projeksiyon kipi: tarayıcı tam ekranı (varsa) + Esc ile çıkış
  useEffect(() => {
    if (!projector) return;
    void document.documentElement.requestFullscreen?.().catch(() => undefined);
    const onFs = () => {
      if (!document.fullscreenElement) setProjector(false);
    };
    document.addEventListener('fullscreenchange', onFs);
    return () => {
      document.removeEventListener('fullscreenchange', onFs);
      if (document.fullscreenElement) void document.exitFullscreen?.().catch(() => undefined);
    };
  }, [projector]);

  const present = useMemo(
    () => live.records.filter((r) => !r.revoked).sort((a, b) => b.markedAt.localeCompare(a.markedAt) || b.id - a.id),
    [live.records],
  );
  const revoked = useMemo(() => live.records.filter((r) => r.revoked), [live.records]);
  const presentIds = useMemo(() => new Set(present.map((r) => r.studentId)), [present]);

  const matches = useMemo(() => {
    const needle = search.trim().toLocaleLowerCase('tr');
    if (!needle) return [];
    return (enrolled.data ?? [])
      .filter((s) => !presentIds.has(s.studentId) && `${s.displayName} ${s.studentNo ?? ''}`.toLocaleLowerCase('tr').includes(needle))
      .slice(0, 8);
  }, [search, enrolled.data, presentIds]);

  if (!Number.isFinite(sessionId)) return <Navigate to={acadPaths.courses} replace />;
  if (live.notFound || (session.isError && session.error && (session.error as { status?: number }).status === 404)) {
    return (
      <EmptyState
        icon="search"
        title={t('ac.live.notFound.title')}
        description={t('ac.live.notFound.text')}
        action={<LinkButton to={acadPaths.courses}>{t('ac.course.notFound.action')}</LinkButton>}
      />
    );
  }

  const open = live.status === 'OPEN';
  const date = session.data ? fmtDate(session.data.lessonDate) : '';

  const counters = (
    <div className={styles.counters}>
      <p className={styles.counterMain} aria-label={t('ac.live.countersAria', { present: live.presentCount, total: live.enrolledCount })}>
        <span className={styles.counterNumber}>{live.presentCount}</span>
        <span className={styles.counterOf}>/ {live.enrolledCount}</span>
        <span className={styles.counterLabel}>{t('ac.live.present')}</span>
      </p>
      <ProgressBar value={live.presentCount} max={Math.max(1, live.enrolledCount)} label={t('ac.live.progressAria')} tone="neutral" />
    </div>
  );

  return (
    <div className={styles.page}>
      <div className={styles.head}>
        <div>
          {courseId && (
            <Link to={acadPaths.course(courseId, 'yoklamalar')} className={styles.back}>
              <Icon name="chevronLeft" size={16} /> {course.data ? courseTitle(course.data) : t('ac.nav.courses')}
            </Link>
          )}
          <h1 className={styles.title}>
            {t('ac.live.title')} {date && <span className={styles.titleDate}>· {date}</span>}
          </h1>
        </div>
        <div className={styles.headActions}>
          {live.status && (
            <Badge tone={open ? 'info' : 'neutral'}>
              <Icon name={open ? 'activity' : 'lock'} size={14} aria-hidden="true" /> {open ? t('ac.session.open') : t('ac.session.closedLabel')}
            </Badge>
          )}
          <Button variant="secondary" leftIcon={<Icon name="panel" size={16} />} onClick={() => setProjector(true)} disabled={!open}>
            {t('ac.live.projector')}
          </Button>
          {open ? (
            <Button variant="secondary" leftIcon={<Icon name="lock" size={16} />} onClick={() => setClosing(true)}>
              {t('ac.live.closeSession')}
            </Button>
          ) : live.status === 'CLOSED' ? (
            <Button leftIcon={<Icon name="play" size={16} />} loading={reopen.isPending} onClick={() => reopen.mutate()}>
              {t('ac.session.reopen')}
            </Button>
          ) : null}
        </div>
      </div>

      <div className={styles.grid}>
        <section className={styles.qrCard} aria-label={t('ac.live.qrSection')}>
          {!projector && (
            <QrPanel status={live.status} codes={live.codes} offsetMs={live.offsetMs} lastFreshAt={live.lastFreshAt} onReopen={() => reopen.mutate()} reopening={reopen.isPending} />
          )}
          {counters}
          <p className={styles.muted}>{t('ac.live.howTo')}</p>
          {import.meta.env.DEV && <DevCopy codes={live.codes} offsetMs={live.offsetMs} lastFreshAt={live.lastFreshAt} status={live.status} />}
        </section>

        <div className={styles.side}>
          {courseId && <PendingScans sessionId={sessionId} items={live.pending} onChanged={afterChange} headingLevel={2} />}

          <Card title={t('ac.live.manualTitle')}>
            <FormField label={t('ac.live.manualLabel')} hint={t('ac.live.manualHint')}>
              <Input type="search" value={search} autoComplete="off" placeholder={t('ac.live.manualPlaceholder')} onChange={(e) => setSearch(e.target.value)} />
            </FormField>
            {search.trim() !== '' && (
              <ul className={styles.rows} aria-label={t('ac.live.manualResults')}>
                {matches.length === 0 ? (
                  <li className={styles.muted}>{enrolled.isLoading ? t('ac.loading') : t('ac.live.manualNone')}</li>
                ) : (
                  matches.map((s) => (
                    <li key={s.studentId} className={styles.row}>
                      <div className={styles.rowMain}>
                        <span className={styles.rowTitle}>{s.displayName}</span>
                        <span className={styles.muted}>
                          <span className="ltr">{s.studentNo ?? '—'}</span>
                          {revoked.some((r) => r.studentId === s.studentId) ? ` · ${t('ac.live.wasRemoved')}` : ''}
                        </span>
                      </div>
                      <Button size="sm" loading={mark.isPending && mark.variables === s.studentId} onClick={() => mark.mutate(s.studentId)} aria-label={t('ac.detail.markAria', { name: s.displayName })}>
                        {t('ac.detail.mark')}
                      </Button>
                    </li>
                  ))
                )}
              </ul>
            )}
          </Card>

          <Card title={`${t('ac.live.listTitle')} (${present.length})`}>
            {present.length === 0 ? (
              <p className={styles.muted}>{live.lastFreshAt === null ? t('ac.loading') : t('ac.live.listEmpty')}</p>
            ) : (
              <ul className={styles.rows} aria-label={t('ac.live.listTitle')}>
                {present.map((r) => (
                  <li key={r.studentId} className={styles.row}>
                    <div className={styles.rowMain}>
                      <span className={styles.rowTitle}>{r.displayName ?? t('ac.live.someone')}</span>
                      <span className={styles.muted}>
                        <span className="ltr">{r.studentNo ?? '—'}</span> · {fmtTime(r.markedAt)}
                      </span>
                    </div>
                    <Badge tone={r.method === 'QR' ? 'success' : 'neutral'}>
                      <Icon name={r.method === 'QR' ? 'smartphone' : 'pencil'} size={14} aria-hidden="true" /> {r.method === 'QR' ? t('ac.live.viaQr') : t('ac.live.viaManual')}
                    </Badge>
                    <IconButton label={t('ac.detail.removeAria', { name: r.displayName ?? '' })} size="sm" onClick={() => setRemoving(r)}>
                      <Icon name="x" size={16} />
                    </IconButton>
                  </li>
                ))}
              </ul>
            )}
            {revoked.length > 0 && (
              <details className={styles.revoked}>
                <summary>{t('ac.live.revokedSummary', { n: revoked.length })}</summary>
                <ul className={styles.rows}>
                  {revoked.map((r) => (
                    <li key={r.studentId} className={styles.row}>
                      <div className={styles.rowMain}>
                        <span className={styles.rowTitle}>{r.displayName ?? t('ac.live.someone')}</span>
                        <span className={styles.muted}>
                          <span className="ltr">{r.studentNo ?? '—'}</span>
                        </span>
                      </div>
                      <Button size="sm" variant="secondary" loading={mark.isPending && mark.variables === r.studentId} onClick={() => mark.mutate(r.studentId)} aria-label={t('ac.detail.restoreAria', { name: r.displayName ?? '' })}>
                        {t('ac.detail.restore')}
                      </Button>
                    </li>
                  ))}
                </ul>
              </details>
            )}
          </Card>
        </div>
      </div>

      <div className="sr-only" role="status" aria-live="polite" data-testid="live-announcer">
        {announcer.message}
      </div>

      {projector && (
        <Projector onExit={() => setProjector(false)} title={course.data ? courseTitle(course.data) : t('ac.live.title')}>
          <QrPanel large status={live.status} codes={live.codes} offsetMs={live.offsetMs} lastFreshAt={live.lastFreshAt} />
          <div className={styles.projectorCounter}>
            <span className={styles.counterNumber}>{live.presentCount}</span>
            <span className={styles.counterOf}>/ {live.enrolledCount}</span>
            <span className={styles.counterLabel}>{t('ac.live.present')}</span>
          </div>
        </Projector>
      )}

      <ConfirmDialog
        open={closing}
        onClose={() => setClosing(false)}
        onConfirm={() => close.mutate()}
        loading={close.isPending}
        title={t('ac.session.closeTitle')}
        message={t('ac.session.closeText')}
        consequence={t('ac.session.closeConsequence')}
        confirmLabel={t('ac.live.closeSession')}
      />
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
    </div>
  );
}

/** Projeksiyon kipi: tam ekran kaplama; büyük QR + sayaç, yüksek karşıtlık. Esc ya da "Çık" ile kapanır. */
function Projector({ onExit, title, children }: { onExit: () => void; title: string; children: React.ReactNode }) {
  const t = useT();
  const ref = useRef<HTMLDivElement>(null);
  useFocusTrap(ref, true, onExit);
  return (
    <div ref={ref} className={styles.projector} role="dialog" aria-modal="true" aria-label={t('ac.live.projectorAria')} tabIndex={-1}>
      <div className={styles.projectorHead}>
        <span className={styles.projectorTitle}>{title}</span>
        <Button variant="secondary" onClick={onExit} data-autofocus leftIcon={<Icon name="x" size={16} />}>
          {t('ac.live.projectorExit')}
        </Button>
      </div>
      <div className={styles.projectorBody}>{children}</div>
    </div>
  );
}

/** YALNIZ geliştirme derlemesinde: geçerli kodu panoya kopyalar (test eden kişi telefonu terminalden taklit edebilsin). */
function DevCopy({ codes, offsetMs, lastFreshAt, status }: { codes: LiveCode[]; offsetMs: number; lastFreshAt: number | null; status: 'OPEN' | 'CLOSED' | null }) {
  const t = useT();
  const toast = useToast();
  return (
    <Button
      variant="ghost"
      size="sm"
      leftIcon={<Icon name="copy" size={14} />}
      onClick={() => {
        const q = qrState({ status, nowLocalMs: Date.now(), lastFreshLocalMs: lastFreshAt, offsetMs, codes });
        if (!q.code) {
          toast.error(t('ac.live.dev.noCode'));
          return;
        }
        void navigator.clipboard?.writeText(q.code.code).then(() => toast.success(t('ac.live.dev.copied')));
      }}
    >
      {t('ac.live.dev.copy')}
    </Button>
  );
}
