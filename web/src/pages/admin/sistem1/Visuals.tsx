// Sistem sağlığı ortak görselleri: trafik ışığı (İyi / Dikkat / Acil), bölge ölçeği, yığılmış çubuk.
// Durum yalnız renkle değil simge + kelime + (ölçekte) işaret şekliyle de anlatılır.
import type { ReactNode } from 'react';
import type { SystemLevel } from '../../../api/system';
import { Icon, type IconName } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { s1 } from './dict';
import { verdictOf, type QueueSegment, type Verdict, type ZoneScale } from './logic';
import styles from './sistem1.module.css';

const LAMPS: { verdict: Exclude<Verdict, 'unknown'>; icon: IconName }[] = [
  { verdict: 'good', icon: 'check' },
  { verdict: 'attention', icon: 'alert' },
  { verdict: 'urgent', icon: 'x' },
];

/** Üç lambalı trafik ışığı: yanan lamba durumu söyler, kelimesi altında yazar. */
export function TrafficLight({ i18n, level, compact }: { i18n: I18n; level: SystemLevel; compact?: boolean }) {
  const t = s1(i18n);
  const active = verdictOf(level);
  return (
    <div
      className={styles.lights}
      data-compact={compact || undefined}
      role="img"
      aria-label={t('admin.s1.light.aria', { state: t(`admin.s1.light.${active}`) })}
      data-testid="traffic-light"
      data-active={active}
    >
      {LAMPS.map((l) => (
        <span key={l.verdict} className={styles.lamp} data-verdict={l.verdict} data-on={active === l.verdict || undefined}>
          <span className={styles.lampBulb} aria-hidden="true">
            {active === l.verdict && <Icon name={l.icon} size={compact ? 14 : 20} strokeWidth={2.6} />}
          </span>
          <span className={styles.lampText}>{t(`admin.s1.light.${l.verdict}`)}</span>
        </span>
      ))}
      {active === 'unknown' && <span className={styles.lampUnknown}>{t('admin.s1.light.unknown')}</span>}
    </div>
  );
}

/**
 * Yeşil / sarı / kırmızı bölgeli şerit ve üstünde işaret (üçgen). `label` ekran okuyucuya tam cümledir.
 * Eşik yoksa çizilmez (çağıran null ölçek verirse hiçbir şey göstermez).
 */
export function ZoneGauge({ scale, label, level }: { scale: ZoneScale | null; label: string; level?: SystemLevel }) {
  if (!scale) return null;
  const warn = scale.warnPct ?? scale.critPct ?? 100;
  const crit = scale.critPct ?? 100;
  return (
    <div className={styles.zone} role="img" aria-label={label} data-status={level}>
      <div className={styles.zoneTrack} aria-hidden="true">
        <span className={styles.zoneSeg} data-zone="ok" style={{ inlineSize: `${warn}%` }} />
        <span className={styles.zoneSeg} data-zone="warn" style={{ inlineSize: `${Math.max(0, crit - warn)}%` }} />
        <span className={styles.zoneSeg} data-zone="crit" style={{ inlineSize: `${Math.max(0, 100 - crit)}%` }} />
      </div>
      <span className={styles.zoneMark} style={{ insetInlineStart: `${scale.markPct}%` }} aria-hidden="true" />
    </div>
  );
}

const SEG_TONE: Record<QueueSegment['tone'], string> = {
  success: 'success',
  info: 'info',
  warning: 'warning',
  danger: 'danger',
  neutral: 'neutral',
};

/** Yığılmış çubuk + yanında renk, desen ve sayı içeren açıklama (renk tek başına anlam taşımaz). */
export function StackedBar({
  segments,
  label,
  legend,
}: {
  segments: QueueSegment[];
  label: string;
  /** Her parça için açıklama metni (sayıyı içerir). */
  legend: (s: QueueSegment) => ReactNode;
}) {
  if (segments.length === 0) return null;
  return (
    <div className={styles.stackWrap}>
      <div className={styles.stackBar} role="img" aria-label={label}>
        {segments.map((s) => (
          <span key={s.key} className={styles.stackSeg} data-tone={SEG_TONE[s.tone]} style={{ flexGrow: s.count }} />
        ))}
      </div>
      <ul className={styles.legend}>
        {segments.map((s) => (
          <li key={s.key} className={styles.legendItem}>
            <span className={styles.legendSwatch} data-tone={SEG_TONE[s.tone]} aria-hidden="true" />
            <span>{legend(s)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
