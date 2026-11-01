import { useId } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Kit.module.css';

export type BarTone = 'auto' | 'info' | 'success' | 'warning' | 'danger' | 'neutral';

export interface ProgressBarProps {
  /** Dolu kısım; `max` ile oranlanır (varsayılan max 100). */
  value: number | null | undefined;
  max?: number;
  /** Çubuğun anlamı ("Gönderilen bildirim"); ekran okuyucu için zorunlu, `showLabel` ile görünür de olur. */
  label: string;
  /**
   * Renk. `auto` (varsayılan): bitince yeşil, sürerken mavi; kırmızı YALNIZ `danger` (hata/başarısız) ile gelir.
   * Marka kırmızısı (primary) bilerek yoktur: "%100 tamamlandı" kırmızı görünürse hata sanılır.
   */
  tone?: BarTone;
  /** Etiketi ve yüzdeyi çubuğun üstünde göster. */
  showLabel?: boolean;
  className?: string;
}

/** Yatay ilerleme çubuğu: sayı + metin + renk birlikte; renk durumdan türer, süs değildir. */
export function ProgressBar({ value, max = 100, label, tone = 'auto', showLabel, className }: ProgressBarProps) {
  const { t, formatNumber } = useI18n();
  const labelId = useId();
  const known = value !== null && value !== undefined && Number.isFinite(value) && max > 0;
  const ratio = known ? Math.min(1, Math.max(0, (value as number) / max)) : 0;
  const percent = Math.round(ratio * 100);
  const resolved = tone === 'auto' ? (ratio >= 1 ? 'success' : 'info') : tone;
  const percentText = known ? formatNumber(ratio, { style: 'percent', maximumFractionDigits: 0 }) : '–';
  return (
    <div className={`${styles.bar} ${className ?? ''}`}>
      {showLabel && (
        <div className={styles.barHead}>
          <span id={labelId}>{label}</span>
          <span className={styles.barPercent}>{percentText}</span>
        </div>
      )}
      <div
        className={styles.barTrack}
        role="progressbar"
        aria-label={showLabel ? undefined : label}
        aria-labelledby={showLabel ? labelId : undefined}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={known ? percent : undefined}
        aria-valuetext={known ? t('admin.kit.ring.value', { label, value: formatNumber(percent) }) : label}
      >
        <div className={`${styles.barFill} ${styles[`bar${resolved}`]}`} style={{ inlineSize: `${percent}%` }} />
      </div>
    </div>
  );
}
