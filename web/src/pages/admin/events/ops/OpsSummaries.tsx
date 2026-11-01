// Etkinlik çekmecesi özetleri: başvuru doluluğu ve yoklama oranı sayı kutuları yerine halka + yığın çubuk + tek cümle olarak.
import type { AdminApplicationSummary } from '../../../../api/adminEvents';
import { Insight, ProgressRing } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { StackedBar } from '../../community/Summary';
import { tp } from '../../community/tp';
import { attendanceNotStarted, attendanceRatio, type AttendanceSummary } from '../../community/tpLogic';
import styles from './ops.module.css';

export function ApplicationsSummary({ s }: { s: AdminApplicationSummary }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const x = tp(i18n);
  const nf = formatNumber;
  const unlimited = s.capacity == null;
  const full = !unlimited && (s.seatsLeft ?? 0) <= 0;
  const insight = unlimited
    ? x('admin.tp.apps.insightOpen', { going: nf(s.goingCount), pending: nf(s.pending) })
    : full
      ? x('admin.tp.apps.insightFull', {
          cap: nf(s.capacity as number),
          pending: nf(s.pending),
          wait: nf(s.waitlisted),
        })
      : x('admin.tp.apps.insight', {
          cap: nf(s.capacity as number),
          going: nf(s.goingCount),
          left: nf(s.seatsLeft ?? 0),
          pending: nf(s.pending),
        });
  return (
    <div className={styles.sumBox} data-testid="app-summary">
      <Insight tone={s.pending > 0 ? 'warn' : 'info'} parts={insight} />
      <div className={styles.sumRow}>
        {!unlimited && (
          <ProgressRing
            value={s.goingCount}
            max={s.capacity as number}
            tone={full ? 'warning' : 'info'}
            size={104}
            label={x('admin.tp.apps.ring', { going: nf(s.goingCount), cap: nf(s.capacity as number) })}
          />
        )}
        <div className={styles.sumSide}>
          <StackedBar
            ariaLabel={x('admin.tp.apps.stackAria')}
            parts={[
              { key: 'pending', label: t('admin.p07.app.status.PENDING'), value: s.pending, tone: 'warning' },
              { key: 'accepted', label: t('admin.p07.app.status.ACCEPTED'), value: s.accepted, tone: 'success' },
              { key: 'waitlisted', label: t('admin.p07.app.status.WAITLISTED'), value: s.waitlisted, tone: 'info' },
              { key: 'rejected', label: t('admin.p07.app.status.REJECTED'), value: s.rejected, tone: 'danger' },
              { key: 'cancelled', label: t('admin.p07.app.status.CANCELLED'), value: s.cancelled, tone: 'neutral' },
            ]}
          />
          <p className={styles.sumFact}>
            <span className={styles.muted}>{t('admin.p07.app.seatsLeft')}: </span>
            <strong>{s.seatsLeft == null ? t('admin.p07.unlimited') : nf(s.seatsLeft)}</strong>
          </p>
        </div>
      </div>
    </div>
  );
}

export function AttendanceSummaryView({ sm }: { sm: AttendanceSummary }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const x = tp(i18n);
  const nf = formatNumber;
  const ratio = attendanceRatio(sm);
  const notStarted = attendanceNotStarted(sm);
  const walk = sm.walkIns > 0 ? x('admin.tp.att.insightWalk', { walk: nf(sm.walkIns) }) : '';
  const pct = nf(Math.round((ratio ?? 0) * 100));
  const insight = notStarted
    ? x('admin.tp.att.insightNone', { going: nf(sm.going) }) + walk
    : x('admin.tp.att.insight', {
        going: nf(sm.going),
        present: nf(sm.present),
        pct,
        unmarked: nf(sm.unmarked),
      }) + walk;
  return (
    <div className={styles.sumBox} data-testid="att-summary">
      <Insight tone={!notStarted && sm.unmarked > 0 ? 'warn' : 'info'} parts={insight} />
      <div className={styles.sumRow}>
        <ProgressRing
          value={ratio === null ? null : sm.present}
          max={Math.max(1, sm.going)}
          tone={ratio !== null && ratio >= 0.7 ? 'success' : 'info'}
          size={104}
          label={notStarted ? x('admin.tp.att.ringEmpty') : x('admin.tp.att.ring')}
        />
        <div className={styles.sumSide}>
          <StackedBar
            ariaLabel={x('admin.tp.att.stackAria')}
            parts={[
              { key: 'present', label: t('admin.p07.att.sum.present'), value: sm.present, tone: 'success' },
              { key: 'absent', label: t('admin.p07.att.sum.absent'), value: sm.absent, tone: 'danger' },
              { key: 'unmarked', label: t('admin.p07.att.sum.unmarked'), value: sm.unmarked, tone: 'neutral' },
            ]}
          />
          <p className={styles.sumFact}>
            <span className={styles.muted}>{t('admin.p07.att.sum.going')}: </span>
            <strong>{nf(sm.going)}</strong>
            {sm.walkIns > 0 && (
              <>
                <span className={styles.muted}> · {t('admin.p07.att.sum.walkIns')}: </span>
                <strong>{nf(sm.walkIns)}</strong>
              </>
            )}
          </p>
        </div>
      </div>
    </div>
  );
}
