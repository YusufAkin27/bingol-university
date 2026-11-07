// Yedek durum kartları: son başarılı yedek, Google Drive durumu, sunucudaki/Drive'daki yedekler, saklama özeti.
// Durum yalnız renkle değil rozet metniyle de verilir. Bilinmeyen alan null gelir ve "—" gösterilir.
import type { ReactNode } from 'react';
import type { BackupRetention, BackupStatus } from '../../../api/backup';
import { StatusPill, type Tone } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { formatBytes } from '../dataretention/format';
import { gt } from './dict';
import { agoParts, driveState, freshness, type DriveState, type Freshness } from './lib';
import styles from './backup.module.css';

const FRESH_TONE: Record<Freshness, Tone> = { FRESH: 'success', STALE: 'warning', OLD: 'danger', FAILED: 'danger', NONE: 'neutral' };
const DRIVE_TONE: Record<DriveState, Tone> = {
  OK: 'success',
  PENDING: 'info',
  NOT_CONFIGURED: 'warning',
  ERROR: 'danger',
  UNAVAILABLE: 'neutral',
};

export function agoText(i18n: I18n, iso: string | null | undefined, now: number): string {
  const p = agoParts(iso, now);
  if (!p) return '—';
  return gt(i18n)(`admin.gd1.ago.${p.unit}`, { n: i18n.formatNumber(p.n) });
}

function retentionLine(i18n: I18n, d: number | null, w: number | null, m: number | null, remote = false): string {
  const f = (n: number | null) => (n === null || n === undefined ? '—' : i18n.formatNumber(n));
  return gt(i18n)(remote ? 'admin.gd1.retention.lineRemote' : 'admin.gd1.retention.line', { d: f(d), w: f(w), m: f(m) });
}

function Card({
  tone,
  label,
  testId,
  children,
}: {
  tone: Tone;
  label: string;
  testId: string;
  children: ReactNode;
}) {
  return (
    <article className={styles.card} data-tone={tone} data-testid={testId}>
      <h3 className={styles.label}>{label}</h3>
      {children}
    </article>
  );
}

export function StatusCards({ i18n, status, now }: { i18n: I18n; status: BackupStatus | null; now: number }) {
  const t = gt(i18n);
  const known = status !== null;
  const drive = driveState(status);
  const fresh = freshness(status, now);
  const local = status?.local ?? null;
  const remote = status?.remote ?? null;
  const ret: BackupRetention | null = status?.retention ?? null;

  const remoteLines = (() => {
    if (!known || drive === 'UNAVAILABLE') return null;
    if (!remote?.configured) return <p className={styles.muted}>{t('admin.gd1.card.remote.none')}</p>;
    return (
      <>
        <p className={styles.value}>{t('admin.gd1.card.count', { n: remote.count === null ? '—' : i18n.formatNumber(remote.count) })}</p>
        <p className={styles.line}>{formatBytes(remote.bytes)}</p>
      </>
    );
  })();

  return (
    <div className={styles.cards}>
      <Card tone={known ? FRESH_TONE[fresh] : 'neutral'} label={t('admin.gd1.card.last')} testId="gd-last">
        {known && fresh !== 'NONE' ? (
          <>
            <StatusPill tone={FRESH_TONE[fresh]}>{t(`admin.gd1.fresh.${fresh}`)}</StatusPill>
            <p className={styles.value}>{agoText(i18n, status?.lastSuccessAt, now)}</p>
            {status?.lastSuccessAt && <p className={styles.muted}>{i18n.formatDateTime(status.lastSuccessAt)}</p>}
          </>
        ) : (
          <>
            {known && <StatusPill tone={FRESH_TONE[fresh]}>{t(`admin.gd1.fresh.${fresh}`)}</StatusPill>}
            <p className={styles.value}>{known ? t('admin.gd1.card.last.none') : '—'}</p>
          </>
        )}
        {status?.schedule?.cron && (
          <p className={styles.muted}>{t('admin.gd1.card.last.schedule', { cron: status.schedule.cron })}</p>
        )}
        {status?.schedule?.verifyCron && (
          <p className={styles.muted}>{t('admin.gd1.card.last.verify', { cron: status.schedule.verifyCron })}</p>
        )}
        {status?.schedule?.remoteCron && (
          <p className={styles.muted}>{t('admin.gd1.card.last.remoteCron', { cron: status.schedule.remoteCron })}</p>
        )}
      </Card>

      <Card tone={DRIVE_TONE[drive]} label={t('admin.gd1.card.drive')} testId="gd-drive">
        <StatusPill tone={DRIVE_TONE[drive]}>{t(`admin.gd1.drive.${drive}`)}</StatusPill>
        {drive === 'NOT_CONFIGURED' && <p className={styles.line}>{t('admin.gd1.drive.notConfigured')}</p>}
        {remote?.configured && (
          <>
            {remote.name && <p className={styles.line}>{t('admin.gd1.drive.target', { name: remote.name })}</p>}
            {remote.kind && <p className={styles.muted}>{t('admin.gd1.drive.kind', { kind: remote.kind })}</p>}
            {remote.lastSuccessAt && (
              <p className={styles.muted}>{t('admin.gd1.drive.uploaded', { when: i18n.formatDateTime(remote.lastSuccessAt) })}</p>
            )}
            {remote.lastVerifiedAt && (
              <p className={styles.muted}>{t('admin.gd1.drive.verified', { when: i18n.formatDateTime(remote.lastVerifiedAt) })}</p>
            )}
            {remote.lastError && <p className={styles.err}>{t('admin.gd1.drive.lastError', { error: remote.lastError })}</p>}
          </>
        )}
      </Card>

      <Card tone="neutral" label={t('admin.gd1.card.local')} testId="gd-local">
        {local ? (
          <>
            <p className={styles.value}>{t('admin.gd1.card.count', { n: local.count === null ? '—' : i18n.formatNumber(local.count) })}</p>
            <p className={styles.line}>{formatBytes(local.bytes)}</p>
            {local.oldestAt && <p className={styles.muted}>{t('admin.gd1.card.oldest', { when: i18n.formatDateTime(local.oldestAt) })}</p>}
          </>
        ) : (
          <p className={styles.value}>—</p>
        )}
      </Card>

      <Card tone="neutral" label={t('admin.gd1.card.remote')} testId="gd-remote">
        {remoteLines ?? <p className={styles.value}>—</p>}
      </Card>

      <Card tone="neutral" label={t('admin.gd1.card.retention')} testId="gd-retention">
        {ret ? (
          <>
            <p className={styles.line}>
              <strong>{t('admin.gd1.retention.local')}:</strong> {retentionLine(i18n, ret.localDaily, ret.localWeekly, ret.localMonthly)}
            </p>
            <p className={styles.line}>
              <strong>{t('admin.gd1.retention.remote')}:</strong> {retentionLine(i18n, ret.remoteDaily, ret.remoteWeekly, ret.remoteMonthly, true)}
            </p>
          </>
        ) : (
          <p className={styles.value}>—</p>
        )}
      </Card>
    </div>
  );
}
