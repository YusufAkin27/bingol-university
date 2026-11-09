// Cihaz sayıları kartı: tekil cihaz, aktif (7/30 gün), push alabilen, güncel sürüm yüzdesi, platform kırılımı.
// Her sayının yanında "i" ile hesaplama açıklaması. Yalnız toplulaştırılmış sayılar gelir (kimlik/jeton yok).
import type { DeviceSummary } from '../../../api/appVersions';
import { Card, Tooltip } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './appVersions.module.css';

function Info({ text, label }: { text: string; label: string }) {
  return (
    <Tooltip text={text}>
      <button type="button" className={styles.infoBtn} aria-label={label}>
        i
      </button>
    </Tooltip>
  );
}

function Tile({ id, label, value, info, hint }: { id: string; label: string; value: string; info: string; hint?: string }) {
  return (
    <div className={styles.stat} data-testid={`dev-${id}`}>
      <span className={styles.statLabel}>
        {label} <Info text={info} label={label} />
      </span>
      <span className={styles.statValue}>{value}</span>
      {hint && <span className={styles.statHint}>{hint}</span>}
    </div>
  );
}

export function DeviceCounts({ devices: d }: { devices: DeviceSummary }) {
  const { t, formatNumber } = useI18n();
  const n = formatNumber;
  return (
    <Card as="section" aria-label={t('admin.uv.dev.title')} data-testid="uv-devices">
      <h2 className={styles.devTitle}>{t('admin.uv.dev.title')}</h2>
      <div className={styles.stats}>
        <Tile
          id="total"
          label={t('admin.uv.dev.total')}
          value={n(d.totalUnique)}
          info={t('admin.uv.dev.total.info', { n: d.retentionDays })}
        />
        <Tile
          id="active30"
          label={t('admin.uv.dev.active30')}
          value={n(d.active30)}
          info={t('admin.uv.dev.active30.info', { n: d.active30Days })}
        />
        <Tile
          id="active7"
          label={t('admin.uv.dev.active7')}
          value={n(d.active7)}
          info={t('admin.uv.dev.active7.info', { n: d.active7Days })}
        />
        <Tile
          id="push"
          label={t('admin.uv.dev.push')}
          value={n(d.pushCapable)}
          info={t('admin.uv.dev.push.info', { n: d.pushDays })}
        />
        <Tile
          id="latest"
          label={t('admin.uv.dev.latest')}
          value={`%${n(d.latestPercent)}`}
          info={t('admin.uv.dev.latest.info')}
        />
        <Tile
          id="unknown"
          label={t('admin.uv.dev.unknown')}
          value={n(d.unknownVersion30)}
          info={t('admin.uv.dev.unknown.info')}
        />
      </div>
      <table className={styles.devTable} aria-label={t('admin.uv.dev.byPlatform')}>
        <caption className="sr-only">{t('admin.uv.dev.byPlatform')}</caption>
        <thead>
          <tr>
            <th scope="col">{t('admin.uv.dev.col.platform')}</th>
            <th scope="col">{t('admin.uv.dev.total')}</th>
            <th scope="col">{t('admin.uv.dev.active30')}</th>
            <th scope="col">{t('admin.uv.dev.col.push')}</th>
          </tr>
        </thead>
        <tbody>
          {d.platforms.map((p) => (
            <tr key={p.platform} data-testid={`dev-row-${p.platform}`}>
              <th scope="row">{t(`admin.uv.dev.platform.${p.platform}`)}</th>
              <td>{n(p.total)}</td>
              <td>{n(p.active30)}</td>
              <td>{n(p.pushCapable)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {d.unidentified30 > 0 && (
        <p className={styles.muted}>{t('admin.uv.dev.unidentified', { n: n(d.unidentified30) })}</p>
      )}
      <p className={styles.muted}>{t('admin.uv.dev.pushNote')}</p>
    </Card>
  );
}
