import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { getBehaviorUser, type BehaviorSession, type SessionStep } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import { Badge, Drawer, EmptyState, ErrorState, Icon, Skeleton, StatTile } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { paths } from '../../../../paths';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import UserInsightsSection from './UserInsightsSection';
import {
  actionLabel,
  formatClock,
  formatDayShort,
  formatDuration,
  formatInt,
  formatOffset,
  formatPct,
  reasonLabel,
  screenLabel,
  type Range,
} from './format';

/** Tek adım: ekran (süreyle) ya da eylem. */
export function StepRow({ step, start }: { step: SessionStep; start: string }) {
  const { t } = useI18n();
  const isAction = step.type === 'action';
  return (
    <li className={`${styles.step} ${isAction ? styles.stepAction : ''}`}>
      <span className={`${styles.stepTime} ltr`}>
        {formatClock(step.at)} <span className={styles.stepOffset}>{formatOffset(start, step.at)}</span>
      </span>
      <span className={styles.stepDot} aria-hidden="true">
        <Icon name={isAction ? 'check' : 'chart'} size={14} />
      </span>
      <span className={styles.stepBody}>
        {isAction ? (
          <>
            <strong>{actionLabel(step.kind)}</strong>
            {step.screen && <span className={analytics.muted}> · {screenLabel(step.screen)}</span>}
          </>
        ) : (
          <>
            <strong>{screenLabel(step.screen)}</strong>
            <span className={analytics.muted}>
              {' · '}
              {step.dwellMs === null || step.dwellMs === undefined
                ? t('admin.bh.drawer.dwellUnknown')
                : formatDuration(step.dwellMs)}
            </span>
          </>
        )}
      </span>
    </li>
  );
}

/** Oturum satırı: başlık her zaman görünür, adımlar açılınca çizilir (500+ adımlık listeler DOM'u şişirmesin). */
export function SessionItem({ s, defaultOpen }: { s: BehaviorSession; defaultOpen?: boolean }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(!!defaultOpen);
  const screens = s.steps.filter((x) => x.type === 'screen').length;
  const actions = s.steps.length - screens;
  return (
    <li className={styles.session}>
      <details open={open} onToggle={(e) => setOpen((e.currentTarget as HTMLDetailsElement).open)}>
        <summary className={styles.sessionHead}>
          <span className={styles.sessionWhen}>
            <strong>{formatDayShort(s.startedAt)}</strong>{' '}
            <span className="ltr">{formatClock(s.startedAt)}</span>
          </span>
          <span className={styles.sessionDur}>{formatDuration(s.durationMs)}</span>
          <span className={styles.sessionBadges}>
            {s.quickClose && <Badge tone="danger">{t('admin.bh.drawer.quickClose')}</Badge>}
            {s.bounce && <Badge tone="warning">{t('admin.bh.drawer.bounce')}</Badge>}
            <Badge tone="neutral">{reasonLabel(s.reason)}</Badge>
          </span>
          <span className={analytics.muted}>
            {t('admin.bh.drawer.counts', { screens: formatInt(screens), actions: formatInt(actions) })}
          </span>
        </summary>
        {open &&
          (s.steps.length === 0 ? (
            <p className={analytics.muted}>{t('admin.bh.drawer.noSteps')}</p>
          ) : (
            <ol className={styles.steps} aria-label={t('admin.bh.drawer.steps')}>
              {s.steps.map((st, i) => (
                <StepRow key={`${st.at}-${i}`} step={st} start={s.startedAt} />
              ))}
            </ol>
          ))}
      </details>
    </li>
  );
}

export default function UserDrawer({
  userId,
  range,
  onClose,
}: {
  userId: number;
  range: Range;
  onClose: () => void;
}) {
  const { t, formatDateTime } = useI18n();
  const q = useQuery({
    queryKey: qk.analytics.behavior('user', { userId, ...range }),
    queryFn: () => getBehaviorUser(userId, range),
  });
  const d = q.data;

  return (
    <Drawer
      open
      size="lg"
      onClose={onClose}
      title={d ? t('admin.bh.drawer.title', { name: d.user.displayName }) : t('admin.bh.drawer.titleLoading')}
      footer={
        <Link className={styles.profileLink} to={paths.admin.user(userId)}>
          {t('admin.bh.drawer.openProfile')}
        </Link>
      }
    >
      {q.isError && !d ? (
        <ErrorState
          compact
          subject={t('admin.bh.drawer.subject')}
          error={q.error}
          onRetry={() => void q.refetch()}
        />
      ) : !d ? (
        <div aria-busy="true" className={styles.drawerLoading}>
          <Skeleton height="5rem" width="100%" />
          <Skeleton height="3rem" width="100%" />
          <Skeleton height="3rem" width="100%" />
        </div>
      ) : (
        <div className={styles.drawerBody}>
          <p className={analytics.muted}>
            <span className="ltr">{d.user.email}</span>
            {(d.user.department || d.user.grade) && (
              <> · {[d.user.department, d.user.grade].filter(Boolean).join(' · ')}</>
            )}
            {' · '}
            <span className="ltr">
              {range.from} – {range.to}
            </span>
          </p>
          <div className={styles.drawerKpis}>
            <StatTile label={t('admin.bh.col.sessions')} value={formatInt(d.summary.sessions)} />
            <StatTile label={t('admin.bh.col.totalTime')} value={formatDuration(d.summary.totalMs)} />
            <StatTile label={t('admin.bh.col.avgSession')} value={formatDuration(d.summary.avgSessionMs)} />
            <StatTile label={t('admin.bh.col.bounce')} value={formatPct(d.summary.bounceRate)} />
            <StatTile
              label={t('admin.bh.col.quickCloseCount')}
              value={formatInt(d.summary.quickCloseCount)}
            />
            <StatTile
              label={t('admin.bh.col.lastSeen')}
              value={d.summary.lastSeenAt ? formatDateTime(d.summary.lastSeenAt) : '—'}
            />
          </div>
          {d.insights && <UserInsightsSection data={d.insights} />}
          <h3 className={analytics.sub}>{t('admin.bh.drawer.sessions')}</h3>
          {d.sessions.length === 0 ? (
            <EmptyState
              icon="clock"
              compact
              title={t('admin.bh.drawer.emptyTitle')}
              description={t('admin.bh.drawer.emptyBody')}
            />
          ) : (
            <>
              <p className={analytics.muted}>{t('admin.bh.drawer.limit')}</p>
              <ul className={styles.sessionList} aria-label={t('admin.bh.drawer.sessions')}>
                {d.sessions.map((s, i) => (
                  <SessionItem key={s.sid + s.startedAt} s={s} defaultOpen={i === 0} />
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </Drawer>
  );
}
