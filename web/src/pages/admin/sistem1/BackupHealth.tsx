// Yedekleme sayfasının görsel özeti: trafik ışığı + "yedek ne kadar taze" ölçeği + Google Drive durumu +
// sunucu/Drive yedek sayısı karşılaştırması. Ayrıntılı kartlar (StatusCards) bunun altında katlanır.
import type { BackupStatus } from '../../../api/backup';
import type { SystemLevel } from '../../../api/system';
import { RankedBars, StatusDot, type StatusTone } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { gt } from '../backup/dict';
import { driveState, freshness, type DriveState, type Freshness } from '../backup/lib';
import { agoText } from '../backup/StatusCards';
import { s1 } from './dict';
import { verdictOf, worstLevel, zoneScale } from './logic';
import { TrafficLight, ZoneGauge } from './Visuals';
import styles from './sistem1.module.css';

const FRESH_LEVEL: Record<Freshness, SystemLevel> = { FRESH: 'OK', STALE: 'WARN', OLD: 'CRIT', FAILED: 'CRIT', NONE: 'UNKNOWN' };
const DRIVE_LEVEL: Record<DriveState, SystemLevel> = { OK: 'OK', PENDING: 'WARN', NOT_CONFIGURED: 'WARN', ERROR: 'CRIT', UNAVAILABLE: 'UNKNOWN' };
const TONE: Record<SystemLevel, StatusTone> = { OK: 'success', WARN: 'warning', CRIT: 'danger', UNKNOWN: 'neutral' };

/** Üst özet. Veri yoksa (uç henüz yok) hiçbir şey çizmez: sayfadaki "kullanılamıyor" notu zaten görünür. */
export function BackupHealth({ i18n, status, now }: { i18n: I18n; status: BackupStatus | null; now: number }) {
  const t = s1(i18n);
  const g = gt(i18n);
  if (!status) return null;
  const fresh = freshness(status, now);
  const drive = driveState(status);
  const level = worstLevel([FRESH_LEVEL[fresh], DRIVE_LEVEL[drive]].filter((l) => l !== 'UNKNOWN') as SystemLevel[]);
  const hours = status.lastSuccessAt ? Math.max(0, (now - Date.parse(status.lastSuccessAt)) / 3_600_000) : null;
  const scale = hours !== null && Number.isFinite(hours) ? zoneScale(hours, 3, 24, 48) : null;
  const local = status.local?.count ?? null;
  const remote = status.remote?.configured ? (status.remote.count ?? null) : null;
  const ago = agoText(i18n, status.lastSuccessAt, now);
  return (
    <section className={styles.summary} data-verdict={verdictOf(level)} aria-label={t('admin.s1.backup.title')} data-testid="backup-health" data-search-anchor="backup-freshness">
      <TrafficLight i18n={i18n} level={level} />
      <div className={styles.summaryText}>
        <h3 className={styles.summaryTitle}>{t('admin.s1.backup.title')}</h3>
        <p className={styles.summarySentence}>
          {fresh === 'NONE' ? t('admin.s1.backup.none') : t(`admin.s1.backup.fresh.${fresh}`, { ago })}
        </p>
        {scale && (
          <ZoneGauge scale={scale} level={FRESH_LEVEL[fresh]} label={t('admin.s1.backup.gauge', { ago })} />
        )}
        <div>
          <StatusDot tone={TONE[DRIVE_LEVEL[drive]]}>{g(`admin.gd1.drive.${drive}`)}</StatusDot>
        </div>
        {local !== null && remote !== null && (
          <RankedBars
            ariaLabel={t('admin.s1.backup.counts')}
            items={[
              { key: 'local', label: t('admin.s1.backup.local'), value: local },
              { key: 'remote', label: t('admin.s1.backup.remote'), value: remote },
            ]}
            limit={0}
            formatValue={(n) => t('admin.s1.backup.countValue', { n: i18n.formatNumber(n) })}
          />
        )}
        <p className={styles.note}>{t('admin.s1.backup.scaleNote')}</p>
      </div>
    </section>
  );
}
