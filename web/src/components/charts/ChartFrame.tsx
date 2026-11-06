import { createContext, useContext, type ReactElement } from 'react';
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

/** Seri ayrımı yalnız renk tonuyla yapılmaz (monochrome): çok serili çizgilerde sıradaki seriye çizgi stili atanır. */
export const CHART_DASHES: Array<string | undefined> = [undefined, '7 4', '2 3', '9 3 2 3', '1 4', '12 4'];

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
    borderRadius: 'var(--radius-sm)',
    color: 'var(--text)',
    boxShadow: 'var(--shadow-2)',
    fontSize: 13,
  },
  labelStyle: { color: 'var(--text-muted)', fontWeight: 'var(--fw-semibold)' },
  itemStyle: { color: 'var(--text)' },
} as const;

/** ChartPanel, yorum cümlesinin kimliğini buraya yazar; grafik (role="img") onu aria-describedby ile gösterir. */
export const ChartDescriptionContext = createContext<string | undefined>(undefined);

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
  const describedBy = useContext(ChartDescriptionContext);
  if (empty) {
    return (
      <div
        className={styles.empty}
        style={{ height }}
        role="img"
        aria-label={`${ariaLabel}: ${emptyLabel ?? t('common.noResults')}`}
        aria-describedby={describedBy}
      >
        {emptyLabel ?? t('common.noResults')}
      </div>
    );
  }
  return (
    // RTL'de zaman ekseni sağdan sola akar (XAxis reversed) ve değer ekseni sağa geçer; bkz. useChartDir
    <div className={styles.frame} style={{ height }} role="img" aria-label={ariaLabel} aria-describedby={describedBy}>
      <ResponsiveContainer width="100%" height="100%">
        {children}
      </ResponsiveContainer>
    </div>
  );
}
