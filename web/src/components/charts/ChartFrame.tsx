import type { ReactElement } from 'react';
import { ResponsiveContainer } from 'recharts';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './charts.module.css';

/** Seri renkleri tema değişkenlerinden gelir; koyu temada otomatik değişir. */
export const CHART_COLORS = [
  'var(--chart-1)',
  'var(--chart-2)',
  'var(--chart-3)',
  'var(--chart-4)',
  'var(--chart-5)',
  'var(--chart-6)',
];

export const axisProps = {
  stroke: 'var(--chart-axis)',
  tick: { fill: 'var(--chart-axis)', fontSize: 12 },
  tickLine: false,
  axisLine: { stroke: 'var(--chart-grid)' },
} as const;

export const tooltipStyle = {
  contentStyle: {
    background: 'var(--surface)',
    border: '1px solid var(--border)',
    borderRadius: 8,
    color: 'var(--text)',
    boxShadow: 'var(--shadow-2)',
    fontSize: 13,
  },
  labelStyle: { color: 'var(--text-muted)', fontWeight: 600 },
  itemStyle: { color: 'var(--text)' },
} as const;

interface Props {
  ariaLabel: string;
  height?: number;
  empty?: boolean;
  emptyLabel?: string;
  children: ReactElement;
}

/** Ortak çerçeve: erişilebilir ad (role="img"), boş durum, yeniden boyutlanma. Veriler tabloda da sunulmalıdır. */
export function ChartFrame({ ariaLabel, height = 280, empty, emptyLabel, children }: Props) {
  const { t } = useI18n();
  if (empty) {
    return (
      <div
        className={styles.empty}
        style={{ height }}
        role="img"
        aria-label={`${ariaLabel}: ${emptyLabel ?? t('common.noResults')}`}
      >
        {emptyLabel ?? t('common.noResults')}
      </div>
    );
  }
  return (
    // RTL'de zaman ekseni sağdan sola akar (XAxis reversed) ve değer ekseni sağa geçer; bkz. useChartDir
    <div className={styles.frame} style={{ height }} role="img" aria-label={ariaLabel}>
      <ResponsiveContainer width="100%" height="100%">
        {children}
      </ResponsiveContainer>
    </div>
  );
}
