// Sistem durumu: gösterge kartı (sorunlu), kompakt satır (normal), eşikli çubuk, halka, hero.
import { Link } from 'react-router-dom';
import { levelOf, type SystemIndicator, type SystemLevel } from '../../../api/system';
import { Icon, ProgressRing, type IconName, type RingTone } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import {
  aboutOf,
  campaignParts,
  isRing,
  meterOf,
  nameOf,
  thresholdText,
  valueText,
} from './indicators';
import styles from './systemstatus.module.css';

export const LEVEL_ICON: Record<SystemLevel, IconName> = { OK: 'check', WARN: 'alert', CRIT: 'x', UNKNOWN: 'help' };
const RING_TONE: Record<SystemLevel, RingTone> = { OK: 'success', WARN: 'warning', CRIT: 'danger', UNKNOWN: 'neutral' };

/** Renk + simge + kelime: durum yalnız renkle anlatılmaz. */
export function LevelBadge({ i18n, level }: { i18n: I18n; level: SystemLevel }) {
  return (
    <span className={styles.badge} data-status={level}>
      <Icon name={LEVEL_ICON[level]} size={16} aria-hidden="true" />
      {i18n.t(`admin.system.status.${level}` as 'admin.system.status.OK')}
    </span>
  );
}

/** Eşikli çubuk: dolgu değeri, işaretler uyarı ve kritik sınırını gösterir. */
function Meter({ id, ind, level }: { id: string; ind: SystemIndicator; level: SystemLevel }) {
  const m = meterOf(id, ind);
  if (!m) return null;
  const pos = (n: number) => `${Math.min(100, Math.max(0, (n / m.max) * 100))}%`;
  return (
    <div className={styles.meter} data-status={level} aria-hidden="true" data-testid={`meter-${id}`}>
      <div className={styles.meterFill} style={{ inlineSize: pos(m.value) }} />
      <span className={styles.meterTick} data-kind="warn" style={{ insetInlineStart: pos(m.warn) }} />
      {m.crit !== null && <span className={styles.meterTick} data-kind="crit" style={{ insetInlineStart: pos(m.crit) }} />}
    </div>
  );
}

/** Kampanya durumları: tek yığılmış çubuk (sayılar zaten cümlede yazılı). */
function StackedCampaigns({ i18n, value }: { i18n: I18n; value: Record<string, unknown> }) {
  const parts = campaignParts(i18n, value);
  const total = parts.reduce((s, p) => s + p.n, 0);
  if (total === 0) return null;
  const tone = (k: string) => (k === 'FAILED' ? 'danger' : k === 'SENT' ? 'success' : k === 'SENDING' ? 'info' : 'neutral');
  return (
    <div className={styles.stacked} aria-hidden="true">
      {parts.map((p) => (
        <span key={p.key} className={styles.stackSeg} data-tone={tone(p.key)} style={{ flexGrow: p.n }} />
      ))}
    </div>
  );
}

/** Dolgun kart: sorunlu/bilinmeyen göstergeler ve halka/çubuk gerektirenler. */
export function IndicatorCard({ i18n, id, ind }: { i18n: I18n; id: string; ind: SystemIndicator }) {
  const level = levelOf(ind.status);
  const th = thresholdText(i18n, id, ind.threshold);
  const about = aboutOf(i18n, id);
  const ring = isRing(id, ind);
  const objectValue = ind.value !== null && typeof ind.value === 'object' ? (ind.value as Record<string, unknown>) : null;
  const storageLink = id === 'storage' || id === 'disk.storage';
  return (
    <article id={`ind-${id}`} tabIndex={-1} className={styles.card} data-status={level} data-testid={`ind-${id}`}>
      <LevelBadge i18n={i18n} level={level} />
      <h3 className={styles.label}>{nameOf(i18n, id)}</h3>
      {ring ? (
        <ProgressRing
          value={ind.value as number}
          label={i18n.t('admin.v2n.sys.ringLabel')}
          center={i18n.t('admin.system.unit.percent', { n: i18n.formatNumber(Math.round(ind.value as number)) })}
          tone={RING_TONE[level]}
          size={104}
          thickness={11}
        />
      ) : (
        <p className={styles.value}>{valueText(i18n, id, ind)}</p>
      )}
      {ring && !ind.message && <p className={styles.valueSm}>{valueText(i18n, id, ind)}</p>}
      {objectValue && id === 'campaign.counts' && <StackedCampaigns i18n={i18n} value={objectValue} />}
      {!ring && <Meter id={id} ind={ind} level={level} />}
      {ind.message && <p className={styles.message}>{ind.message}</p>}
      {about && <p className={styles.muted}>{about}</p>}
      {th && <p className={styles.muted}>{th}</p>}
      {storageLink && (
        <Link className={styles.link} to={paths.admin.dataRetention}>
          {i18n.t('admin.v2n.sys.goRetention')}
        </Link>
      )}
    </article>
  );
}

/** Normal çalışan gösterge: tek satır (ad · değer · onay işareti). */
export function CompactRow({ i18n, id, ind }: { i18n: I18n; id: string; ind: SystemIndicator }) {
  const level = levelOf(ind.status);
  const about = aboutOf(i18n, id);
  const th = thresholdText(i18n, id, ind.threshold);
  return (
    <li className={styles.row} data-status={level} data-testid={`ind-${id}`} title={about || undefined}>
      <span className={styles.rowIcon} data-status={level}>
        <Icon name={LEVEL_ICON[level]} size={14} aria-hidden="true" />
        <span className="sr-only">{i18n.t(`admin.system.status.${level}` as 'admin.system.status.OK')}:</span>
      </span>
      <span className={styles.rowName}>{nameOf(i18n, id)}</span>
      <span className={styles.rowValue}>{valueText(i18n, id, ind)}</span>
      {th && <span className="sr-only">{th}</span>}
    </li>
  );
}
