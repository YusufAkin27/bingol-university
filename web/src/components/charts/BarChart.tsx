import { Bar, BarChart as RBarChart, CartesianGrid, Legend, Tooltip, XAxis, YAxis } from 'recharts';
import { useI18n } from '../../i18n/I18nProvider';
import { axisProps, CHART_COLORS, ChartFrame, tooltipStyle } from './ChartFrame';
import type { Series } from './LineAreaChart';

export interface BarChartProps<T extends object> {
  data: T[];
  /** Kategori alanı */
  xKey: keyof T & string;
  series: Series[];
  ariaLabel: string;
  height?: number;
  /** horizontal: çubuklar yatay uzar (uzun etiketler için uygun) */
  layout?: 'vertical' | 'horizontal';
  stacked?: boolean;
  emptyLabel?: string;
}

export function BarChart<T extends object>({
  data,
  xKey,
  series,
  ariaLabel,
  height,
  layout = 'vertical',
  stacked,
  emptyLabel,
}: BarChartProps<T>) {
  const { dir, formatNumber } = useI18n();
  const rtl = dir === 'rtl';
  const horizontal = layout === 'horizontal';
  return (
    <ChartFrame ariaLabel={ariaLabel} height={height} empty={data.length === 0} emptyLabel={emptyLabel}>
      <RBarChart
        data={data}
        layout={horizontal ? 'vertical' : 'horizontal'}
        margin={{ top: 8, right: 8, bottom: 0, left: 0 }}
      >
        <CartesianGrid
          stroke="var(--chart-grid)"
          strokeDasharray="3 3"
          horizontal={!horizontal}
          vertical={horizontal}
        />
        {horizontal ? (
          <>
            <XAxis
              type="number"
              reversed={rtl}
              tickFormatter={(v: number) => formatNumber(v)}
              allowDecimals={false}
              {...axisProps}
            />
            <YAxis
              type="category"
              dataKey={xKey}
              orientation={rtl ? 'right' : 'left'}
              width={110}
              {...axisProps}
            />
          </>
        ) : (
          <>
            <XAxis dataKey={xKey} reversed={rtl} {...axisProps} />
            <YAxis
              orientation={rtl ? 'right' : 'left'}
              tickFormatter={(v: number) => formatNumber(v)}
              width={44}
              allowDecimals={false}
              {...axisProps}
            />
          </>
        )}
        <Tooltip
          formatter={(v: number) => formatNumber(v)}
          cursor={{ fill: 'var(--surface-2)' }}
          {...tooltipStyle}
        />
        {series.length > 1 && <Legend />}
        {series.map((s, i) => (
          <Bar
            key={s.key}
            dataKey={s.key}
            name={s.label}
            fill={s.color ?? CHART_COLORS[i % CHART_COLORS.length]}
            stackId={stacked ? 'a' : undefined}
            radius={stacked ? 0 : [4, 4, 0, 0]}
            maxBarSize={36}
          />
        ))}
      </RBarChart>
    </ChartFrame>
  );
}
