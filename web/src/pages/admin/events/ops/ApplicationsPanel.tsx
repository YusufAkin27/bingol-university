import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  acceptApplication,
  exportEventApplicationsCsv,
  listEventApplications,
  rejectApplication,
  type AdminApplicationRow,
  type ApplicationStatus,
} from '../../../../api/adminEvents';
import { Badge, GuardedAction, LoadMore, Select, type Tone } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { eventErrorMessage } from '../errors';
import { CsvButton, PanelState, opsInvalidate, opsKey } from './opsParts';
import styles from './ops.module.css';

const STATUSES: ApplicationStatus[] = ['PENDING', 'WAITLISTED', 'ACCEPTED', 'REJECTED', 'CANCELLED'];
const TONE: Record<ApplicationStatus, Tone> = {
  PENDING: 'warning',
  WAITLISTED: 'info',
  ACCEPTED: 'success',
  REJECTED: 'danger',
  CANCELLED: 'neutral',
};

/** Başvurular: durum süzgeci, kapasite özeti, zorla kabul/ret (sebep zorunlu; kapasite sunucuda aşılamaz). */
export function ApplicationsPanel({ eventId, eventStatus }: { eventId: number; eventStatus: string }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const [status, setStatus] = useState<ApplicationStatus | ''>('');
  const q = useInfiniteQuery({
    queryKey: opsKey(eventId, 'applications', status),
    queryFn: ({ pageParam }) => listEventApplications(eventId, { status, cursor: pageParam, size: 50 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);
  const s = q.data?.pages[0]?.summary;
  const live = eventStatus === 'ACTIVE';
  const full = s?.seatsLeft === 0;

  function actions(r: AdminApplicationRow) {
    const canAccept = r.status === 'PENDING' || r.status === 'WAITLISTED';
    const canReject = canAccept || r.status === 'ACCEPTED';
    return (
      <div className={styles.actions}>
        {canAccept && (
          <GuardedAction
            size="sm"
            variant="secondary"
            disabled={!live || full}
            title={t('admin.p07.app.accept.title', { name: r.displayName })}
            consequence={t('admin.p07.app.accept.consequence')}
            irreversible={false}
            requireReason
            confirmLabel={t('admin.p07.app.accept.confirm')}
            errorMessage={(e) => eventErrorMessage(i18n, e)}
            successMessage={t('admin.p07.app.accept.done')}
            invalidateKeys={opsInvalidate(eventId)}
            onConfirm={({ reason, idempotencyKey }) =>
              acceptApplication(eventId, r.userId, { reason, idempotencyKey })
            }
          >
            {t('admin.p07.app.accept')}
          </GuardedAction>
        )}
        {canReject && (
          <GuardedAction
            size="sm"
            variant="danger"
            danger
            disabled={!live}
            title={t('admin.p07.app.reject.title', { name: r.displayName })}
            consequence={t(
              r.status === 'ACCEPTED'
                ? 'admin.p07.app.reject.consequenceAccepted'
                : 'admin.p07.app.reject.consequence',
            )}
            irreversible
            requireReason
            confirmLabel={t('admin.p07.app.reject.confirm')}
            errorMessage={(e) => eventErrorMessage(i18n, e)}
            successMessage={t('admin.p07.app.reject.done')}
            invalidateKeys={opsInvalidate(eventId)}
            onConfirm={({ reason, idempotencyKey }) =>
              rejectApplication(eventId, r.userId, { reason, idempotencyKey })
            }
          >
            {t('admin.p07.app.reject')}
          </GuardedAction>
        )}
      </div>
    );
  }

  return (
    <section
      className={styles.panel}
      aria-label={t('admin.p07.tab.applications')}
      data-testid="panel-applications"
    >
      <div className={styles.bar}>
        <label>
          {t('admin.p07.app.filter')}
          <Select value={status} onChange={(e) => setStatus(e.target.value as ApplicationStatus | '')}>
            <option value="">{t('admin.p07.app.all')}</option>
            {STATUSES.map((st) => (
              <option key={st} value={st}>
                {t(`admin.p07.app.status.${st}`)}
              </option>
            ))}
          </Select>
        </label>
        <CsvButton
          fetchCsv={() => exportEventApplicationsCsv(eventId, status)}
          filename={`event-${eventId}-applications.csv`}
        />
      </div>

      {s && (
        <>
          <dl className={styles.chips} data-testid="app-summary">
            <div className={styles.chip}>
              <dt>{t('admin.p07.app.capacity')}</dt>
              <dd>{s.capacity == null ? t('admin.p07.unlimited') : formatNumber(s.capacity)}</dd>
            </div>
            <div className={styles.chip}>
              <dt>{t('admin.p07.app.going')}</dt>
              <dd>{formatNumber(s.goingCount)}</dd>
            </div>
            <div className={styles.chip}>
              <dt>{t('admin.p07.app.seatsLeft')}</dt>
              <dd>{s.seatsLeft == null ? t('admin.p07.unlimited') : formatNumber(s.seatsLeft)}</dd>
            </div>
            {STATUSES.map((st) => (
              <div key={st} className={styles.chip}>
                <dt>{t(`admin.p07.app.status.${st}`)}</dt>
                <dd>{formatNumber(s[st.toLowerCase() as 'pending'])}</dd>
              </div>
            ))}
          </dl>
          {s.mode === 'OPEN' && <p className={styles.muted}>{t('admin.p07.app.openMode')}</p>}
          {!live && <p className={styles.muted}>{t('admin.p07.app.notLive')}</p>}
          {live && full && <p className={styles.muted}>{t('admin.p07.app.full')}</p>}
        </>
      )}

      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={items.length === 0}
        emptyTitle={t('admin.p07.app.empty')}
      >
        <div className={styles.scroll}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>{t('admin.p07.col.person')}</th>
                <th>{t('admin.p07.col.status')}</th>
                <th>{t('admin.p07.app.col.answers')}</th>
                <th>{t('admin.p07.col.date')}</th>
                <th>{t('admin.p07.col.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {items.map((r) => (
                <tr key={r.id} data-testid={`app-${r.userId}`}>
                  <td>
                    <div className={styles.name} dir="auto">
                      {r.displayName}
                    </div>
                    <div className={`${styles.sub} ltr`}>{r.emailMasked ?? '—'}</div>
                    {r.department && <div className={styles.sub}>{r.department}</div>}
                  </td>
                  <td>
                    <Badge tone={TONE[r.status]}>{t(`admin.p07.app.status.${r.status}`)}</Badge>
                    {r.decisionNote && <div className={styles.sub}>{r.decisionNote}</div>}
                  </td>
                  <td>
                    {r.note && (
                      <p className={styles.note} dir="auto">
                        {r.note}
                      </p>
                    )}
                    {r.answers.length > 0 && (
                      <ol className={styles.answers}>
                        {r.answers.map((a, i) => (
                          <li key={i} dir="auto">
                            {a}
                          </li>
                        ))}
                      </ol>
                    )}
                    {!r.note && r.answers.length === 0 && '—'}
                  </td>
                  <td>{formatDateTime(r.createdAt)}</td>
                  <td>{actions(r)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <LoadMore
          hasMore={!!q.hasNextPage}
          loading={q.isFetchingNextPage}
          onLoadMore={() => void q.fetchNextPage()}
        />
      </PanelState>
    </section>
  );
}
