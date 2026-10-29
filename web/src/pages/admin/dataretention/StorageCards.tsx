// Depolama doluluk kartları: veritabanı boyutu + en büyük tablolar, veritabanı sunucusu diski (ölçülen / hesaplanan /
// bilinmiyor etiketiyle) ve uygulama disk bölümleri. Durum yalnız renkle değil simge + metinle de gösterilir.
import type { DiskSource, StorageDisk, StorageReport } from '../../../api/dataRetention';
import type { SystemLevel } from '../../../api/system';
import { Icon, type IconName } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes, levelOfPercent } from './format';
import styles from './DataRetention.module.css';

const ICON: Record<SystemLevel, IconName> = { OK: 'check', WARN: 'alert', CRIT: 'x', UNKNOWN: 'help' };

function Progress({ pct, level, name }: { pct: number | null; level: SystemLevel; name: string }) {
  const { t } = useI18n();
  const v = pct === null ? 0 : Math.max(0, Math.min(100, pct));
  return (
    <div
      className={styles.bar}
      role="progressbar"
      aria-label={t('admin.ds1.storage.progress', { name })}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={pct === null ? undefined : Math.round(v)}
      data-status={level}
    >
      <div className={styles.barFill} style={{ inlineSize: `${v}%` }} data-status={level} />
    </div>
  );
}

function Source({ source }: { source: DiskSource }) {
  const { t } = useI18n();
  return (
    <>
      <span className={styles.source} data-source={source} data-testid={`source-${source}`}>
        {t(`admin.ds1.storage.source.${source}`)}
      </span>
      <p className={styles.hint}>{t(`admin.ds1.storage.source.${source}.hint`)}</p>
    </>
  );
}

function DiskCard({ disk, title, testId, thresholds }: { disk: StorageDisk; title: string; testId: string; thresholds: { warn: number; crit: number } }) {
  const { t, formatNumber } = useI18n();
  const level = disk.percent === null ? 'UNKNOWN' : levelOfPercent(disk.percent, thresholds.warn, thresholds.crit);
  return (
    <article className={styles.card} data-status={level} data-testid={testId}>
      <h3 className={styles.cardTitle}>{title}</h3>
      <p className={styles.big}>{disk.percent === null ? '—' : `%${formatNumber(disk.percent)}`}</p>
      <Progress pct={disk.percent} level={level} name={title} />
      <p className={styles.level}>
        <Icon name={ICON[level]} size={16} /> {t(`admin.ds1.storage.level.${level}`)}
      </p>
      {disk.totalBytes !== null && disk.usedBytes !== null && (
        <p className={styles.muted}>
          {t('admin.ds1.storage.used', { used: formatBytes(disk.usedBytes), total: formatBytes(disk.totalBytes) })}
          {disk.freeBytes !== null && <> · {t('admin.ds1.storage.free', { free: formatBytes(disk.freeBytes) })}</>}
        </p>
      )}
      <Source source={disk.source} />
    </article>
  );
}

export function StorageCards({ report }: { report: StorageReport }) {
  const { t, td, formatNumber } = useI18n();
  const th = { warn: report.warnPercent, crit: report.critPercent };
  const dbSize = report.database.sizeBytes;
  const top = report.database.topTables.slice(0, 5);
  return (
    <div className={styles.cards} data-testid="storage-cards">
      <article className={styles.card} data-status="OK" data-testid="card-db-size">
        <h3 className={styles.cardTitle}>{t('admin.ds1.storage.db.size')}</h3>
        <p className={styles.big}>{dbSize === null ? t('admin.ds1.storage.db.unknown') : formatBytes(dbSize)}</p>
        {top.length > 0 && (
          <>
            <p className={styles.muted}>{t('admin.ds1.storage.db.top')}</p>
            <ul className={styles.topList}>
              {top.map((x) => (
                <li key={x.name}>
                  <span className={styles.mono}>{x.name}</span>
                  <span>
                    {formatBytes(x.totalBytes)}
                    {x.estimatedRows !== null && ` · ≈${formatNumber(x.estimatedRows)}`}
                  </span>
                </li>
              ))}
            </ul>
          </>
        )}
      </article>
      <DiskCard disk={report.dbServerDisk} title={t('admin.ds1.storage.dbDisk')} testId="card-db-disk" thresholds={th} />
      {report.appDisks.map((d) => (
        <DiskCard
          key={d.key}
          disk={d}
          title={`${t('admin.ds1.storage.appDisk')}: ${d.roles.map((r) => td(`admin.ds1.storage.role.${r}`, r)).join(' + ')}`}
          testId={`card-${d.key}`}
          thresholds={th}
        />
      ))}
    </div>
  );
}
