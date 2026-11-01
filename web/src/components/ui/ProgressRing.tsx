import { useId, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Skeleton } from './Feedback';
import styles from './Kit.module.css';

export type RingTone = 'primary' | 'success' | 'warning' | 'danger' | 'info' | 'neutral';

export interface ProgressRingProps {
  /** Dolu kısım; `max` ile oranlanır (varsayılan max 100: değer zaten yüzde). */
  value: number | null | undefined;
  max?: number;
  /** Halkanın altındaki düz cümle: "kullanıcı e-postasını doğruladı". */
  label: string;
  /** Halkanın ortasındaki yazı (varsayılan: yüzde). */
  center?: ReactNode;
  tone?: RingTone;
  /** Dış çap (px). Dar ekranda kapsayıcıya sığmazsa küçülür (SVG ölçeklenir). */
  size?: number;
  thickness?: number;
  loading?: boolean;
  className?: string;
}

/** Yüzde halkası: ortada sayı, altında cümle. Renk yalnız süs; anlam sayıda ve cümlede. */
export function ProgressRing({
  value,
  max = 100,
  label,
  center,
  tone = 'primary',
  size = 120,
  thickness = 10,
  loading,
  className,
}: ProgressRingProps) {
  const { t, formatNumber } = useI18n();
  const labelId = useId();
  if (loading) {
    return (
      <div className={`${styles.ring} ${className ?? ''}`} aria-busy="true">
        <Skeleton width={size} height={size} radius="50%" />
        <Skeleton width="12ch" height="0.9rem" />
      </div>
    );
  }
  const known = value !== null && value !== undefined && Number.isFinite(value) && max > 0;
  const ratio = known ? Math.min(1, Math.max(0, (value as number) / max)) : 0;
  const percent = Math.round(ratio * 100);
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  const percentText = known ? formatNumber(percent / 100, { style: 'percent', maximumFractionDigits: 0 }) : '–';
  return (
    <div className={`${styles.ring} ${className ?? ''}`}>
      <div className={styles.ringBox} style={{ inlineSize: size, blockSize: size, maxInlineSize: '100%' }}>
        <svg
          className={styles.ringSvg}
          width="100%"
          height="100%"
          viewBox={`0 0 ${size} ${size}`}
          role="progressbar"
          aria-labelledby={labelId}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={known ? percent : undefined}
          aria-valuetext={known ? t('admin.kit.ring.value', { label, value: formatNumber(percent) }) : label}
          focusable="false"
        >
          <circle className={styles.ringTrack} cx={size / 2} cy={size / 2} r={r} strokeWidth={thickness} />
          {known && (
            <circle
              className={`${styles.ringArc} ${styles[`stroke${tone}`]}`}
              cx={size / 2}
              cy={size / 2}
              r={r}
              strokeWidth={thickness}
              strokeDasharray={c}
              strokeDashoffset={c * (1 - ratio)}
            />
          )}
        </svg>
        <span className={styles.ringCenter} style={{ fontSize: size * 0.24 }} aria-hidden="true">
          {center ?? percentText}
        </span>
      </div>
      <p id={labelId} className={styles.ringLabel}>
        {label}
      </p>
    </div>
  );
}
