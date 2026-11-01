import type { CSSProperties, ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Kit.module.css';

export type LegendPattern = 'solid' | 'stripe' | 'dots' | 'cross' | 'hollow';

/** Seri renkleri (grafik kiti ile aynı tema değişkenleri). */
export const LEGEND_COLORS = [
  'var(--chart-1)',
  'var(--chart-2)',
  'var(--chart-3)',
  'var(--chart-4)',
  'var(--chart-5)',
  'var(--chart-6)',
];

/** Sıradaki seriye atanan desenler: renk ayırt edilemese bile işaret ayırt edilir. */
export const LEGEND_PATTERNS: LegendPattern[] = ['solid', 'stripe', 'dots', 'cross', 'hollow', 'solid'];

export interface LegendItem {
  key: string;
  label: string;
  /** Verilmezse sıraya göre tema renk değişkeni atanır. */
  color?: string;
  pattern?: LegendPattern;
  /** Metnin yanında kalın yazılan değer ("120 kişi"). */
  value?: ReactNode;
}

const PATTERN_CLASS: Record<LegendPattern, string> = {
  solid: styles.patternSolid,
  stripe: styles.patternStripe,
  dots: styles.patternDots,
  cross: styles.patternCross,
  hollow: styles.patternHollow,
};

export interface ChartLegendProps {
  items: LegendItem[];
  /** Liste için erişilebilir ad (varsayılan: "Renk açıklaması"). */
  ariaLabel?: string;
  className?: string;
}

/** Grafik açıklaması: renk + desen + metin. Renk görmeyenler de serileri ayırt eder. */
export function ChartLegend({ items, ariaLabel, className }: ChartLegendProps) {
  const { t } = useI18n();
  if (items.length === 0) return null;
  return (
    <ul className={`${styles.legend} ${className ?? ''}`} aria-label={ariaLabel ?? t('admin.kit.legend.label')}>
      {items.map((it, i) => {
        const pattern = it.pattern ?? LEGEND_PATTERNS[i % LEGEND_PATTERNS.length];
        const color = it.color ?? LEGEND_COLORS[i % LEGEND_COLORS.length];
        return (
          <li key={it.key} className={styles.legendItem} data-pattern={pattern}>
            <span
              className={`${styles.swatch} ${PATTERN_CLASS[pattern]}`}
              style={{ '--swatch': color } as CSSProperties}
              aria-hidden="true"
            />
            <span>{it.label}</span>
            {it.value !== undefined && <span className={styles.legendValue}>{it.value}</span>}
          </li>
        );
      })}
    </ul>
  );
}
